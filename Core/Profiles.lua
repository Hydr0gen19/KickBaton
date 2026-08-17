local _, ns = ...

local L = ns.L
local Profiles = ns:NewModule("Profiles")

local function NewProfile()
	return { squads = {}, revision = 0 }
end

function Profiles:OnInitialize()
	local db = ns.db

	db.profiles = db.profiles or {}
	if type(db.activeProfile) ~= "string" or db.activeProfile == "" then
		db.activeProfile = "Default"
	end
	if not db.profiles[db.activeProfile] then
		db.profiles[db.activeProfile] = NewProfile()
	end

	-- Repair any profile written by an older version.
	for _, profile in pairs(db.profiles) do
		profile.squads = profile.squads or {}
		profile.revision = profile.revision or 0
	end
end

function Profiles:Current()
	local db = ns.db
	local profile = db.profiles[db.activeProfile]
	if not profile then
		profile = NewProfile()
		db.profiles[db.activeProfile] = profile
	end
	return profile
end

function Profiles:CurrentName()
	return ns.db.activeProfile
end

function Profiles:List()
	local names = {}
	for name in pairs(ns.db.profiles) do
		names[#names + 1] = name
	end
	table.sort(names)
	return names
end

function Profiles:Exists(name)
	return ns.db.profiles[name] ~= nil
end

function Profiles:Switch(name)
	if type(name) ~= "string" or name == "" then return false end

	if not ns.db.profiles[name] then
		ns.db.profiles[name] = NewProfile()
	end
	ns.db.activeProfile = name

	ns:Fire("PROFILE_CHANGED", name)
	ns:Fire("SQUADS_CHANGED")
	ns:Print("%s: %s", L["CONFIG_PROFILE"], name)
	return true
end

function Profiles:Delete(name)
	if not ns.db.profiles[name] then return false end
	if name == ns.db.activeProfile then return false end

	ns.db.profiles[name] = nil
	ns:Fire("PROFILE_CHANGED", ns.db.activeProfile)
	return true
end
