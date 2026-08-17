local _, ns = ...

local L = ns.L
local Transfer = ns:NewModule("Transfer")

-- Shareable strings, the WeakAuras way.
--
-- This covers what the addon-message sync cannot: it works when the group is
-- not assembled, when the person configuring does not hold lead, and over
-- Discord the night before. The wire protocol is for keeping an assembled group
-- in step; this is for getting the assignments to people in the first place.
--
--   Kicker:1:Mitica:2!8,1=Luca-Nemesis,Marco-Pozzo!7=Anna-Nemesis,Giulio-Pozzo
--   ^magic ^ver ^profile ^count ^ one chunk per squad, markers=members
--
-- Deliberately plain text rather than serialise+compress+base64. The payload is
-- a handful of names, so compression buys nothing, and a format you can read at
-- a glance is one you can debug from a Discord paste.
--
-- The squad count in the header exists to catch truncation: a chat client that
-- clips a long string would otherwise produce a shorter but perfectly valid
-- assignment set, and import it silently.

local MAGIC = "Kicker"
local FORMAT_VERSION = 1

-- Profile names are user-typed, so keep the delimiters out of them.
local function SanitiseName(name)
	return (tostring(name or ""):gsub("[:!=,]", ""))
end

function Transfer:Export()
	local squads = ns.Squads:GetAll()

	local chunks = {}
	for i = 1, #squads do
		chunks[#chunks + 1] = table.concat(squads[i].markers, ",")
			.. "=" .. table.concat(squads[i].members, ",")
	end

	return string.format("%s:%d:%s:%d!%s",
		MAGIC,
		FORMAT_VERSION,
		SanitiseName(ns.Profiles:CurrentName()),
		#squads,
		table.concat(chunks, "!"))
end

-- Returns ok, errorOrProfileName, squadCount. Nothing is written unless every
-- check passes, so a bad paste leaves the current setup untouched.
function Transfer:Import(input)
	if type(input) ~= "string" then
		return false, L["TRANSFER_ERR_EMPTY"]
	end

	-- Names never contain whitespace, so stripping it makes the parse immune to
	-- the line wrapping that chat clients insert.
	input = input:gsub("%s+", "")
	if input == "" then
		return false, L["TRANSFER_ERR_EMPTY"]
	end

	local magic, version, profileName, count, body =
		input:match("^(%a+):(%d+):([^:!]*):(%d+)!(.*)$")

	if magic ~= MAGIC then
		return false, L["TRANSFER_ERR_FORMAT"]
	end
	if tonumber(version) ~= FORMAT_VERSION then
		return false, L["TRANSFER_ERR_VERSION"]:format(version)
	end

	local squads = {}
	for chunk in body:gmatch("[^!]+") do
		local markerPart, memberPart = chunk:match("^([^=]*)=(.*)$")
		if not markerPart then
			return false, L["TRANSFER_ERR_FORMAT"]
		end

		local squad = { markers = {}, members = {} }
		for value in markerPart:gmatch("[^,]+") do
			local marker = tonumber(value)
			if not marker then
				return false, L["TRANSFER_ERR_FORMAT"]
			end
			squad.markers[#squad.markers + 1] = marker
		end
		for value in memberPart:gmatch("[^,]+") do
			squad.members[#squad.members + 1] = value
		end

		table.sort(squad.markers)
		squads[#squads + 1] = squad
	end

	if #squads ~= tonumber(count) then
		return false, L["TRANSFER_ERR_TRUNCATED"]:format(tonumber(count), #squads)
	end

	local valid, reason = ns.Squads:ValidateSet(squads)
	if not valid then
		return false, reason
	end

	-- Land in the profile the string names, creating it if needed, so importing
	-- never quietly overwrites whatever you happened to have open.
	local target = profileName ~= "" and profileName or ns.Profiles:CurrentName()
	ns.Profiles:Switch(target)
	ns.Squads:ReplaceAll(squads)

	return true, target, #squads
end
