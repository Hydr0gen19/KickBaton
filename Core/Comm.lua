local _, ns = ...

local L = ns.L
local Comm = ns:NewModule("Comm")

local PREFIX = "KICKER"
local MAX_MESSAGE = 255

local SUCCESS = (Enum and Enum.SendAddonMessageResult and Enum.SendAddonMessageResult.Success) or 0
local INSTANCE_CATEGORY = LE_PARTY_CATEGORY_INSTANCE or 2

-- Wire format
--
--   A|BEGIN|<revision>|<squadCount>|<force>
--   A|S|<index>|<markers csv>|<members csv>
--   A|END|<revision>
--   K|<cooldownSeconds>
--   Q                                    request a push from whoever leads
--
-- `force` separates the two kinds of push. Automatic ones (a member joining,
-- a sync request) defer to the revision counter so they cannot clobber newer
-- data. A deliberate "Push to group" sets force and always wins: if someone
-- else takes lead their revision may well be lower than what is already in
-- circulation, and a push that silently does nothing is worse than useless.
--
-- A full push is 2 framing messages + one per squad. With at most 8 squads that
-- is 10 messages, exactly the per-prefix burst allowance, so a push never
-- queues behind the 1/second refill.

local function ChannelForGroup()
	if IsInGroup(INSTANCE_CATEGORY) then return "INSTANCE_CHAT" end
	if IsInRaid() then return "RAID" end
	if IsInGroup() then return "PARTY" end
	return nil
end

local function SenderIsAuthorised(sender)
	local okLeader, isLeader = pcall(UnitIsGroupLeader, sender)
	local okAssist, isAssist = pcall(UnitIsGroupAssistant, sender)

	if okLeader and isLeader then return true end
	if okAssist and isAssist then return true end
	if okLeader and okAssist then return false end

	-- Name could not be resolved to a unit; let the revision check arbitrate
	-- rather than dropping what is probably a legitimate push.
	return true
end

function Comm:CanPush()
	if not IsInGroup() then return false end
	return UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
end

function Comm:Send(message)
	local channel = ChannelForGroup()
	if not channel then return false end

	if #message > MAX_MESSAGE then
		ns:Print("Message too long to send (%d chars) - shorten your squads.", #message)
		return false
	end

	local result = C_ChatInfo.SendAddonMessage(PREFIX, message, channel)
	return result == nil or result == true or result == SUCCESS
end

-- `auto` marks the background pushes: quiet, and deferential to the revision
-- counter. A user-initiated push is neither.
function Comm:PushSquads(auto)
	if not ChannelForGroup() then
		if not auto then ns:Print(L["COMM_NO_GROUP"]) end
		return false
	end
	if not self:CanPush() then
		if not auto then ns:Print(L["COMM_NOT_LEADER"]) end
		return false
	end

	local squads = ns.Squads:GetAll()
	local revision = ns.Squads:Revision()
	local force = auto and 0 or 1

	self:Send(string.format("A|BEGIN|%d|%d|%d", revision, #squads, force))
	for i = 1, #squads do
		self:Send(string.format("A|S|%d|%s", i, ns.Squads:EncodeSquad(squads[i])))
	end
	self:Send(string.format("A|END|%d", revision))

	if not auto then ns:Print(L["COMM_PUSHED"], #squads) end
	return true
end

function Comm:BroadcastKick(cooldownSeconds)
	self:Send(string.format("K|%d", math.floor((cooldownSeconds or 0) + 0.5)))
end

function Comm:RequestSync()
	self:Send("Q")
end

--------------------------------------------------------------------------------
-- Receiving
--
-- Squad lines accumulate in a per-sender buffer and are only committed on a
-- well-formed END, so a push that gets truncated mid-flight leaves the local
-- configuration untouched instead of half-overwritten.
--------------------------------------------------------------------------------

local buffers = {}

local function HandleAssignment(payload, sender)
	local subtype, rest = payload:match("^([^|]+)|?(.*)$")

	if subtype == "BEGIN" then
		local revision, count, force = rest:match("^(%d+)|(%d+)|(%d+)$")
		if not revision then
			-- Tolerate the unforced form in case of a version mismatch.
			revision, count = rest:match("^(%d+)|(%d+)$")
			force = "0"
		end
		if not revision then return end

		if not SenderIsAuthorised(sender) then return end
		if force ~= "1" and tonumber(revision) <= ns.Squads:Revision() then return end

		buffers[sender] = {
			revision = tonumber(revision),
			expected = tonumber(count),
			squads = {},
		}

	elseif subtype == "S" then
		local buffer = buffers[sender]
		if not buffer then return end

		local index, squadPayload = rest:match("^(%d+)|(.*)$")
		if not index then return end

		local squad = ns.Squads:DecodeSquad(squadPayload)
		if squad then
			buffer.squads[tonumber(index)] = squad
		end

	elseif subtype == "END" then
		local buffer = buffers[sender]
		buffers[sender] = nil
		if not buffer then return end

		local revision = tonumber(rest:match("^(%d+)$") or "")
		if revision ~= buffer.revision then return end

		-- Squad lines are keyed by index, so count them explicitly: a gap would
		-- otherwise slip past a plain length check.
		local received = 0
		local ordered = {}
		for i = 1, buffer.expected do
			if buffer.squads[i] then
				received = received + 1
				ordered[#ordered + 1] = buffer.squads[i]
			end
		end

		if received ~= buffer.expected then
			ns:Print(L["COMM_TRUNCATED"], ns.Roster:Display(sender))
			return
		end

		ns.Squads:ReplaceAll(ordered, buffer.revision)
		ns:Print(L["COMM_RECEIVED"], ns.Roster:Display(sender))
	end
end

function Comm:OnEnable()
	if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
		C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
	end

	ns:RegisterEvent("CHAT_MSG_ADDON", function(_, prefix, message, _, sender)
		if prefix ~= PREFIX then return end
		if ns.Roster:IsPlayer(sender) then return end

		local kind, payload = message:match("^([^|]+)|?(.*)$")
		if not kind then return end

		if kind == "A" then
			HandleAssignment(payload, sender)

		elseif kind == "K" then
			-- The sender is the whole story: their squad supplies the turn
			-- order, and the marker never enters into it.
			ns.Rotation:RegisterKick(sender, tonumber(payload) or 0)

		elseif kind == "Q" then
			if Comm:CanPush() and ns.Squads:Count() > 0 then
				Comm:PushSquads(true)
			end
		end
	end)

	-- Someone joining mid-session should not have to ask for the assignments.
	local pushTimer
	ns:RegisterEvent("GROUP_ROSTER_UPDATE", function()
		wipe(buffers)
		if not Comm:CanPush() then return end

		if pushTimer then pushTimer:Cancel() end
		pushTimer = C_Timer.NewTimer(3, function()
			pushTimer = nil
			if Comm:CanPush() and ns.Squads:Count() > 0 then
				Comm:PushSquads(true)
			end
		end)
	end)

	-- And joining an existing group should pull them without waiting for the
	-- leader to notice.
	C_Timer.After(5, function()
		if ChannelForGroup() and not Comm:CanPush() then
			Comm:RequestSync()
		end
	end)
end
