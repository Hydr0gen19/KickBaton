local _, ns = ...

local L = ns.L
local SelfReport = ns:NewModule("SelfReport")

-- The only module that watches combat at all, and it watches exactly one
-- player: you.
--
-- RegisterUnitEvent is scoped to "player" and "pet" and nothing else. We never
-- ask the game about anyone else's casts or cooldowns - the rest of the group
-- learns about your kick because you tell them, not because their client read
-- your state. That is what keeps the rotation working under the 12.1 change
-- that disabled friendly cooldown tracking.

SelfReport.available = false
SelfReport.interrupts = {}
SelfReport.spellCount = 0
SelfReport.primarySpellID = nil

local frame = CreateFrame("Frame")

function SelfReport:RefreshSpells()
	local map, count = ns.Data:GetPlayerInterruptMap()
	self.interrupts = map
	self.spellCount = count

	self.primarySpellID = nil
	local bestCooldown
	for spellID, cooldown in pairs(map) do
		if not bestCooldown or cooldown < bestCooldown then
			bestCooldown, self.primarySpellID = cooldown, spellID
		end
	end
end

-- Reading our OWN cooldown is allowed, but the value can still arrive as a
-- secret depending on context - and any comparison against a secret raises an
-- error rather than returning false. Hence the pcall around the comparison
-- itself, not just the lookup. The table baseline is a fine fallback: modern
-- interrupt cooldowns are fixed and neither haste nor talents move them.
function SelfReport:GetOwnCooldown(spellID)
	spellID = spellID or self.primarySpellID
	if not spellID then return 0 end

	local baseline = self.interrupts[spellID] or 0

	local function readLive()
		if C_Spell and C_Spell.GetSpellCooldownDuration then
			local duration = C_Spell.GetSpellCooldownDuration(spellID)
			if type(duration) == "number" and duration > 0 then
				return duration
			end
		end
		if C_Spell and C_Spell.GetSpellCooldown then
			local info = C_Spell.GetSpellCooldown(spellID)
			if type(info) == "table" and type(info.duration) == "number" and info.duration > 0 then
				return info.duration
			end
		end
		return nil
	end

	local ok, live = pcall(readLive)
	if ok and live then return live end
	return baseline
end

function SelfReport:IsEnabled()
	return self.available and ns.db.selfReport ~= false
end

local function OnCastSucceeded(_, _, spellID)
	if not SelfReport:IsEnabled() then return end

	local cooldown = SelfReport.interrupts[spellID]
	if not cooldown then return end

	local actual = SelfReport:GetOwnCooldown(spellID)

	-- Tell the group first, then apply locally, so both sides of the rotation
	-- move from the same event.
	if ns.Comm then
		ns.Comm:BroadcastKick(actual)
	end
	ns.Rotation:RegisterKick(GetUnitName("player", true), actual)
end

function SelfReport:OnEnable()
	self:RefreshSpells()

	-- If a future patch closes this event off, registration is where it will
	-- fail. Catch it here and drop to manual mode instead of erroring at the
	-- worst possible moment, mid-pull.
	local ok = pcall(function()
		frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "pet")
	end)

	if not ok then
		self.available = false
		ns:Print(L["STATUS_SELFREPORT_OFF"])
		return
	end

	self.available = true
	frame:SetScript("OnEvent", function(_, _, unit, castGUID, spellID)
		OnCastSucceeded(unit, castGUID, spellID)
	end)

	for _, event in ipairs({
		"PLAYER_SPECIALIZATION_CHANGED",
		"PLAYER_TALENT_UPDATE",
		"PLAYER_ENTERING_WORLD",
	}) do
		ns:RegisterEvent(event, function()
			SelfReport:RefreshSpells()
		end)
	end
end

--------------------------------------------------------------------------------
-- /kickbaton status
--
-- Exists so that "is it actually working?" has an answer that does not involve
-- guessing, which matters more than usual given how much of this addon is
-- built around restrictions that may move.
--------------------------------------------------------------------------------

function ns.Status()
	ns:Print(L["STATUS_HEADER"])

	local chat = DEFAULT_CHAT_FRAME or ChatFrame1
	local function line(text)
		if chat then chat:AddMessage("  |cffaaaaaa" .. text .. "|r") end
	end

	if SelfReport:IsEnabled() then
		line(L["STATUS_SELFREPORT_ON"])
	else
		line(L["STATUS_SELFREPORT_OFF"])
	end

	if SelfReport.spellCount > 0 then
		line(L["STATUS_SPELLS"]:format(SelfReport.spellCount))
	else
		line(L["STATUS_NO_SPELLS"])
	end

	local squadIndex = ns.Squads:FindSquadOf(GetUnitName("player", true))
	if squadIndex then
		line(L["STATUS_SQUAD"]:format(squadIndex))
	else
		line(L["STATUS_NO_SQUAD"])
	end

	local state = ns.Board:VisibilityState()
	if state == "shown" then
		line(L["STATUS_BOARD_SHOWN"])
	elseif state == "empty" then
		line(L["STATUS_BOARD_EMPTY"])
	elseif state == "manual" then
		line(L["STATUS_BOARD_MANUAL"])
	elseif state == "solo" then
		line(L["STATUS_BOARD_SOLO"])
	end
end
