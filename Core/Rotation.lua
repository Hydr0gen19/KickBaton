local _, ns = ...

local L = ns.L
local Rotation = ns:NewModule("Rotation")

-- Runtime only, never saved: whose turn it is per squad, and when each player's
-- interrupt frees up again.
--
-- Every number in here is ours: cooldown expiries are built from GetTime() plus
-- a duration the kicker told us over comms. We never read another player's
-- cooldown, so nothing in this file can touch a secret value.

Rotation.turn = {}
Rotation.cooldowns = {}

function Rotation:TurnIndex(squadIndex)
	return self.turn[squadIndex] or 1
end

function Rotation:CurrentPlayer(squadIndex)
	local squad = ns.Squads:Get(squadIndex)
	if not squad then return nil end
	return squad.members[self:TurnIndex(squadIndex)]
end

function Rotation:CooldownRemaining(name)
	local key = ns.Roster:Key(name)
	if not key then return 0 end

	local expiry = self.cooldowns[key]
	if not expiry then return 0 end

	local remaining = expiry - GetTime()
	if remaining <= 0 then
		self.cooldowns[key] = nil
		return 0
	end
	return remaining
end

function Rotation:IsMyTurn()
	local squadIndex, memberIndex = ns.Squads:FindSquadOf(GetUnitName("player", true))
	if not squadIndex then return false end
	return self:TurnIndex(squadIndex) == memberIndex, squadIndex
end

-- Move the pointer to the first member after `memberIndex` who is off cooldown.
-- If the whole squad is down, park on whoever comes back soonest so the board
-- still shows something useful instead of an arbitrary name.
function Rotation:AdvancePast(squadIndex, memberIndex)
	local squad = ns.Squads:Get(squadIndex)
	if not squad then return end

	local count = #squad.members
	if count == 0 then return end

	local fallbackIndex, fallbackRemaining

	for offset = 1, count do
		local candidate = ((memberIndex - 1 + offset) % count) + 1
		local remaining = self:CooldownRemaining(squad.members[candidate])

		if remaining <= 0 then
			self.turn[squadIndex] = candidate
			ns:Fire("ROTATION_CHANGED")
			return
		end

		if not fallbackRemaining or remaining < fallbackRemaining then
			fallbackRemaining, fallbackIndex = remaining, candidate
		end
	end

	self.turn[squadIndex] = fallbackIndex or 1
	ns:Fire("ROTATION_CHANGED")
end

-- Called both for our own kick and for every kick reported by a group member.
-- `playerName` is all we need: the squad lookup supplies the rest, and the
-- marker never enters the calculation.
function Rotation:RegisterKick(playerName, cooldownSeconds)
	local squadIndex, memberIndex = ns.Squads:FindSquadOf(playerName)
	if not squadIndex then return false end

	local key = ns.Roster:Key(playerName)
	if key and cooldownSeconds and cooldownSeconds > 0 then
		self.cooldowns[key] = GetTime() + cooldownSeconds
	end

	self:AdvancePast(squadIndex, memberIndex)
	return true
end

-- Keybind path. Pressing it means "I just kicked", so it broadcasts exactly
-- like an auto-detected cast - which is what keeps the fallback honest if
-- self-report is ever switched off or blocked.
function Rotation:AdvanceManual()
	local name = GetUnitName("player", true)
	local squadIndex = ns.Squads:FindSquadOf(name)
	if not squadIndex then
		ns:Print(L["ROT_NOT_IN_SQUAD"])
		return
	end

	local cooldown = ns.SelfReport and ns.SelfReport:GetOwnCooldown() or 0

	if ns.Comm then
		ns.Comm:BroadcastKick(cooldown)
	end
	self:RegisterKick(name, cooldown)

	local nextPlayer = self:CurrentPlayer(squadIndex)
	if nextPlayer then
		ns:Print(L["ROT_ADVANCED"], ns.Roster:Display(nextPlayer))
	end
end

function Rotation:Reset()
	wipe(self.turn)
	ns:Fire("ROTATION_CHANGED")
end

function Rotation:OnEnable()
	-- Each pull starts from the top of every squad, so the order is predictable
	-- rather than inherited from wherever the last pack happened to end.
	ns:RegisterEvent("PLAYER_REGEN_ENABLED", function()
		Rotation:Reset()
	end)

	-- Squad indices shift when the roster is edited or a leader pushes, so any
	-- pointer we were holding is meaningless afterwards.
	ns:On("SQUADS_CHANGED", function()
		wipe(Rotation.turn)
	end)
end
