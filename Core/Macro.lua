local _, ns = ...

local Macro = ns:NewModule("Macro")

-- Marking macros for Midnight.
--
-- The old approach is dead on both lines:
--
--   /run if not GetRaidTargetIndex('focus') then SetRaidTarget('focus',1) end
--
-- SetRaidTarget became Protected in 12.0 (callable only from secure code, so
-- not from /run), and GetRaidTargetIndex on an enemy is restricted - the read
-- returns a secret, and `if not <secret>` raises an error rather than
-- evaluating to false.
--
-- The replacement is entirely native, and better: /tm takes secure command
-- options, and a ~ prefix means "apply this marker unless someone else already
-- marked the unit" - which is what the Lua conditional was hand-rolling.
--
-- The addon only ever *shows* this text. It never runs it: RunMacroText is
-- protected too, and nothing here is worth pretending otherwise.

function Macro:GetMarker()
	local override = ns.db.macroMarker[ns.Roster:OwnKey() or ""]
	if override then return override end

	-- Sensible default: the first marker of whatever squad you are in.
	local squadIndex = ns.Squads:FindSquadOf(GetUnitName("player", true))
	local squad = squadIndex and ns.Squads:Get(squadIndex)
	if squad and squad.markers[1] then
		return squad.markers[1]
	end

	return 1
end

function Macro:SetMarker(marker)
	local key = ns.Roster:OwnKey()
	if not key then return false end
	if type(marker) ~= "number" or marker < 1 or marker > ns.Data.MARKER_COUNT then
		return false
	end

	ns.db.macroMarker[key] = marker
	ns:Fire("MACRO_MARKER_CHANGED", marker)
	return true
end

-- Whether the pick is explicit or inherited from the squad, which the picker
-- shows so you can tell "I chose this" from "this is just where I am".
function Macro:HasOverride()
	return ns.db.macroMarker[ns.Roster:OwnKey() or ""] ~= nil
end

function Macro:ClearOverride()
	ns.db.macroMarker[ns.Roster:OwnKey() or ""] = nil
	ns:Fire("MACRO_MARKER_CHANGED", self:GetMarker())
end

function Macro:BuildSet(marker)
	marker = marker or self:GetMarker()
	return table.concat({
		"#showtooltip",
		"/focus [@mouseover,harm,exists][]",
		"/tm [@focus] ~" .. marker,
	}, "\n")
end

-- Marker first, focus second: clearing the focus first would leave @focus
-- pointing at nothing and the mark would stay on the mob.
function Macro:BuildClear()
	return table.concat({
		"/tm [@focus] 0",
		"/clearfocus",
	}, "\n")
end
