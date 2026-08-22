local _, ns = ...

local Data = ns:NewModule("Data")

Data.MARKER_COUNT = 8

-- Blizzard ships localised names in RAID_TARGET_1..8, but fall back to English
-- so a missing global can never produce a nameless marker.
local FALLBACK_MARKER_NAMES = {
	"Star", "Circle", "Diamond", "Triangle", "Moon", "Square", "Cross", "Skull",
}

function Data:MarkerName(index)
	return _G["RAID_TARGET_" .. index] or FALLBACK_MARKER_NAMES[index] or tostring(index)
end

function Data:MarkerTexturePath(index)
	return "Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. index
end

-- Inline texture escape, for use inside FontStrings.
function Data:MarkerIcon(index, size)
	return string.format("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%d:%d|t",
		index, size or 0)
end

function Data:MarkerIcons(markers, size)
	if not markers or #markers == 0 then return "" end
	local parts = {}
	for i = 1, #markers do
		parts[#parts + 1] = self:MarkerIcon(markers[i], size)
	end
	return table.concat(parts)
end

--------------------------------------------------------------------------------
-- Interrupt spells
--
-- Only ever used to recognise the LOCAL player's own cast. We never look these
-- up for anyone else - other players report their own kicks over addon comms.
--
-- `cd` is the baseline cooldown and is only a fallback: when the client can
-- read its own cooldown it broadcasts the real number instead, which already
-- accounts for talents and haste.
--
-- Spell IDs age faster than anything else in this addon. Verify with
--   /dump C_Spell.GetSpellInfo(<id>)
-- and check the live watch list with /kickbaton status.
--------------------------------------------------------------------------------

ns.INTERRUPTS = {
	DEATHKNIGHT = {
		{ spellID = 47528,  cd = 15 },                              -- Mind Freeze
	},
	DEMONHUNTER = {
		{ spellID = 183752, cd = 15 },                              -- Disrupt
	},
	DRUID = {
		{ spellID = 78675,  cd = 60, specs = { [102] = true } },    -- Solar Beam (Balance)
		{ spellID = 106839, cd = 15, specs = { [103] = true, [104] = true } }, -- Skull Bash
	},
	EVOKER = {
		{ spellID = 351338, cd = 40 },                              -- Quell
	},
	HUNTER = {
		{ spellID = 187707, cd = 15, specs = { [255] = true } },    -- Muzzle (Survival)
		{ spellID = 147362, cd = 24, specs = { [253] = true, [254] = true } }, -- Counter Shot
	},
	MAGE = {
		{ spellID = 2139,   cd = 24 },                              -- Counterspell
	},
	MONK = {
		{ spellID = 116705, cd = 15 },                              -- Spear Hand Strike
	},
	PALADIN = {
		{ spellID = 96231,  cd = 15 },                              -- Rebuke
	},
	PRIEST = {
		{ spellID = 15487,  cd = 45, specs = { [258] = true } },    -- Silence (Shadow)
	},
	ROGUE = {
		{ spellID = 1766,   cd = 15 },                              -- Kick
	},
	SHAMAN = {
		{ spellID = 57994,  cd = 12 },                              -- Wind Shear
	},
	WARLOCK = {
		-- Pet abilities: these arrive on the "pet" unit, which is why
		-- SelfReport registers pet as well as player.
		{ spellID = 19647,  cd = 24, pet = true },                  -- Spell Lock (Felhunter)
		{ spellID = 89766,  cd = 30, pet = true },                  -- Axe Toss (Felguard)
	},
	WARRIOR = {
		{ spellID = 6552,   cd = 15 },                              -- Pummel
	},
}

-- The spec API has moved around between expansions; try the modern namespace
-- first and degrade to nil rather than erroring.
local function GetActiveSpecID()
	local index
	if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
		local ok, result = pcall(C_SpecializationInfo.GetSpecialization)
		if ok then index = result end
	end
	if not index and GetSpecialization then
		local ok, result = pcall(GetSpecialization)
		if ok then index = result end
	end
	if not index then return nil end

	local getInfo = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo)
		or GetSpecializationInfo
	if not getInfo then return nil end

	local ok, specID = pcall(getInfo, index)
	if not ok then return nil end
	return specID
end

Data.GetActiveSpecID = function() return GetActiveSpecID() end

-- Returns spellID -> baseline cooldown for everything this character might use
-- as an interrupt. A superset is fine and deliberate: watching an extra spell
-- that the character cannot cast costs nothing, whereas missing the real one
-- would silently break the rotation. When the spec cannot be resolved we
-- include every candidate for the class.
function Data:GetPlayerInterruptMap()
	local _, class = UnitClass("player")
	local candidates = ns.INTERRUPTS[class]
	if not candidates then return {}, 0 end

	local specID = GetActiveSpecID()
	local map, count = {}, 0

	for i = 1, #candidates do
		local entry = candidates[i]
		if not entry.specs or not specID or entry.specs[specID] then
			map[entry.spellID] = entry.cd
			count = count + 1
		end
	end

	return map, count
end

-- Every interrupt in the game, keyed by spell ID.
--
-- Used to recognise a PARTY MEMBER's interrupt from a unit event. We do not
-- know or care which class they are: if the spell they just landed is in this
-- set, it was a kick. That keeps the check to one table lookup and stays
-- correct even if our class/spec mapping is wrong somewhere.
function Data:GetAllInterruptSpells()
	if self.allInterrupts then return self.allInterrupts end

	local all = {}
	for _, candidates in pairs(ns.INTERRUPTS) do
		for i = 1, #candidates do
			all[candidates[i].spellID] = candidates[i].cd
		end
	end

	self.allInterrupts = all
	return all
end
