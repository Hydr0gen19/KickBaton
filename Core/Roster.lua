local _, ns = ...

local Roster = ns:NewModule("Roster")

-- Every comparison in the addon goes through Key(): assignments are stored as
-- typed by the user, but matched case-insensitively and realm-qualified, so
-- "luca" typed in the editor still matches "Luca-Nemesis" arriving over comms.

local ownRealm
local ownKey
local classCache = {}

local function OwnRealm()
	if ownRealm then return ownRealm end
	if GetNormalizedRealmName then
		local realm = GetNormalizedRealmName()
		if realm and realm ~= "" then
			ownRealm = realm
			return ownRealm
		end
	end
	local _, realm = UnitFullName("player")
	if realm and realm ~= "" then
		ownRealm = realm
	end
	return ownRealm
end

function Roster:Normalize(name)
	if type(name) ~= "string" then return nil end
	name = name:gsub("^%s+", ""):gsub("%s+$", "")
	if name == "" then return nil end
	if name:find("-", 1, true) then return name end

	local realm = OwnRealm()
	if not realm then return name end
	return name .. "-" .. realm
end

function Roster:Key(name)
	local normalized = self:Normalize(name)
	if not normalized then return nil end
	return normalized:lower()
end

-- Board rows are tight, and inside a five-man premade first names are unique,
-- so the realm is dropped for display only - never for matching.
function Roster:Display(name)
	if type(name) ~= "string" then return "" end
	return name:match("^([^%-]+)") or name
end

function Roster:OwnKey()
	if not ownKey then
		ownKey = self:Key(GetUnitName("player", true))
	end
	return ownKey
end

function Roster:IsPlayer(name)
	local key = self:Key(name)
	return key ~= nil and key == self:OwnKey()
end

local function EachGroupUnit(callback)
	callback("player")
	if IsInRaid() then
		for i = 1, GetNumGroupMembers() do
			callback("raid" .. i)
		end
	else
		for i = 1, GetNumSubgroupMembers() do
			callback("party" .. i)
		end
	end
end

function Roster:GetGroupMembers()
	local members, seen = {}, {}
	EachGroupUnit(function(unit)
		if not UnitExists(unit) then return end
		local name = GetUnitName(unit, true)
		local normalized = name and self:Normalize(name)
		if normalized then
			local key = normalized:lower()
			if not seen[key] then
				seen[key] = true
				members[#members + 1] = normalized
			end
		end
	end)
	return members
end

-- Class tokens are read only for party/raid members, which stay non-secret
-- under Midnight's restrictions. Enemy units are never touched.
function Roster:RefreshClasses()
	wipe(classCache)
	EachGroupUnit(function(unit)
		if not UnitExists(unit) then return end
		local name = GetUnitName(unit, true)
		local key = name and self:Key(name)
		if not key then return end
		local _, class = UnitClass(unit)
		if class then
			classCache[key] = class
		end
	end)
end

function Roster:ClassOf(name)
	local key = self:Key(name)
	if not key then return nil end
	return classCache[key]
end

-- `dim` scales the class colour towards black (0.45 is a good "present but not
-- your problem right now"). Passing nil gives the full colour.
function Roster:ColorName(name, dim)
	local display = self:Display(name)
	local class = self:ClassOf(name)
	local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]

	if not color then
		-- Unknown class: offline, or not in the group yet.
		return dim and ("|cff6e6e6e" .. display .. "|r") or display
	end

	local r, g, b = color.r, color.g, color.b
	if dim then
		r, g, b = r * dim, g * dim, b * dim
	end

	return string.format("|cff%02x%02x%02x%s|r",
		math.floor(r * 255 + 0.5),
		math.floor(g * 255 + 0.5),
		math.floor(b * 255 + 0.5),
		display)
end

function Roster:OnEnable()
	ownKey = nil
	self:OwnKey()
	self:RefreshClasses()

	ns:RegisterEvent("GROUP_ROSTER_UPDATE", function()
		Roster:RefreshClasses()
		ns:Fire("ROSTER_CHANGED")
	end)
end
