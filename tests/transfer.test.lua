-- Runs the real Core/Squads.lua and Core/Transfer.lua against stubs for the
-- WoW API surface they touch, so the export/import round trip and its rejection
-- paths are exercised as written rather than as imagined.

local ADDON_ROOT = ...

local ns = {}
ns.modules = {}

-- Locale stub: every key resolves to itself, so assertions can name the exact
-- error the code chose without depending on wording.
ns.L = setmetatable({}, { __index = function(_, key) return key end })

function ns:NewModule(name)
	local module = { moduleName = name }
	self[name] = module
	self.modules[#self.modules + 1] = module
	return module
end

function ns:Fire() end
function ns:Print() end

ns.Data = {
	MARKER_COUNT = 8,
	MarkerName = function(_, index) return "Marker" .. index end,
}

ns.Roster = {
	Normalize = function(_, name)
		if type(name) ~= "string" then return nil end
		name = name:gsub("^%s+", ""):gsub("%s+$", "")
		if name == "" then return nil end
		if name:find("-", 1, true) then return name end
		return name .. "-TestRealm"
	end,
	Display = function(_, name)
		return (name or ""):match("^([^%-]+)") or name
	end,
}
function ns.Roster:Key(name)
	local normalized = self:Normalize(name)
	return normalized and normalized:lower() or nil
end

local activeName = "Default"
local profiles = { Default = { squads = {}, revision = 0 } }

ns.Profiles = {
	Current = function() return profiles[activeName] end,
	CurrentName = function() return activeName end,
	Exists = function(_, name) return profiles[name] ~= nil end,
	Switch = function(_, name)
		if not profiles[name] then profiles[name] = { squads = {}, revision = 0 } end
		activeName = name
		return true
	end,
}

local function loadModule(relative)
	local chunk, err = loadfile(ADDON_ROOT .. "/" .. relative)
	if not chunk then error("could not load " .. relative .. ": " .. tostring(err)) end
	chunk("Kicker", ns)
end

loadModule("Core/Squads.lua")
loadModule("Core/Transfer.lua")

--------------------------------------------------------------------------------

local failures = 0
local function check(label, condition, detail)
	if condition then
		print("  ok    " .. label)
	else
		failures = failures + 1
		print("  FAIL  " .. label .. (detail and ("  -> " .. tostring(detail)) or ""))
	end
end

local function setSquads(name, squads)
	ns.Profiles:Switch(name)
	profiles[name].squads = squads
end

--------------------------------------------------------------------------------
print("round trip")

setSquads("Mitica", {
	{ markers = { 1, 8 }, members = { "Luca-Nemesis", "Marco-Pozzo" } },
	{ markers = { 7 },    members = { "Anna-Nemesis", "Giulio-Pozzo" } },
})

local exported = ns.Transfer:Export()
print("  string: " .. exported)

setSquads("Default", {})

local ok, target, count = ns.Transfer:Import(exported)
check("import succeeds", ok, target)
check("lands in the exported profile", target == "Mitica", target)
check("squad count preserved", count == 2, count)

local imported = profiles["Mitica"].squads
check("first squad keeps both markers",
	imported[1] and #imported[1].markers == 2 and imported[1].markers[1] == 1 and imported[1].markers[2] == 8)
check("first squad keeps member order",
	imported[1] and imported[1].members[1] == "Luca-Nemesis" and imported[1].members[2] == "Marco-Pozzo")
check("second squad intact",
	imported[2] and imported[2].markers[1] == 7 and imported[2].members[2] == "Giulio-Pozzo")

--------------------------------------------------------------------------------
print("survives chat mangling")

local wrapped = exported:sub(1, 20) .. "\n   " .. exported:sub(21)
check("newlines and spaces ignored", (ns.Transfer:Import(wrapped)) == true)

--------------------------------------------------------------------------------
print("rejects bad input")

local okEmpty, errEmpty = ns.Transfer:Import("")
check("empty string rejected", okEmpty == false and errEmpty == "TRANSFER_ERR_EMPTY", errEmpty)

local okJunk, errJunk = ns.Transfer:Import("just some text a friend pasted")
check("garbage rejected", okJunk == false and errJunk == "TRANSFER_ERR_FORMAT", errJunk)

local okVersion, errVersion = ns.Transfer:Import("Kicker:99:X:0!")
check("future format rejected", okVersion == false and errVersion == "TRANSFER_ERR_VERSION", errVersion)

-- The case the count header exists for: a clipped string that would otherwise
-- parse cleanly as a smaller, valid assignment set.
local truncated = "Kicker:1:Mitica:2!1,8=Luca-Nemesis,Marco-Pozzo"
local okTrunc, errTrunc = ns.Transfer:Import(truncated)
check("truncation caught", okTrunc == false and errTrunc == "TRANSFER_ERR_TRUNCATED", errTrunc)

--------------------------------------------------------------------------------
print("enforces the invariants")

local dupeMarker = "Kicker:1:Bad:2!8=Luca-Nemesis!8=Anna-Nemesis"
local okMarker, errMarker = ns.Transfer:Import(dupeMarker)
check("same marker in two squads rejected",
	okMarker == false and errMarker == "ERR_MARKER_TAKEN", errMarker)

local dupeMember = "Kicker:1:Bad:2!8=Luca-Nemesis!7=Luca-Nemesis"
local okMember, errMember = ns.Transfer:Import(dupeMember)
check("same character in two squads rejected",
	okMember == false and errMember == "ERR_MEMBER_TAKEN", errMember)

local badMarker = "Kicker:1:Bad:1!9=Luca-Nemesis"
local okRange, errRange = ns.Transfer:Import(badMarker)
check("marker out of range rejected",
	okRange == false and errRange == "ERR_MARKER_RANGE", errRange)

--------------------------------------------------------------------------------
print("nothing is written when import fails")

setSquads("Keep", { { markers = { 3 }, members = { "Sara-Nemesis" } } })
ns.Transfer:Import("Kicker:1:Keep:5!3=Sara-Nemesis")
check("existing squads untouched after a rejected import",
	#profiles["Keep"].squads == 1 and profiles["Keep"].squads[1].markers[1] == 3)

--------------------------------------------------------------------------------
print("edge cases")

setSquads("Empty", {})
local emptyString = ns.Transfer:Export()
local okZero, targetZero, countZero = ns.Transfer:Import(emptyString)
check("zero squads round trips", okZero == true and countZero == 0, emptyString)

setSquads("NoMembers", { { markers = { 2 }, members = {} } })
local sparse = ns.Transfer:Export()
setSquads("Default", {})
local okSparse = ns.Transfer:Import(sparse)
check("squad with markers but no members round trips",
	okSparse == true and #profiles["NoMembers"].squads == 1, sparse)

--------------------------------------------------------------------------------
print("")
if failures == 0 then
	print("All transfer tests passed.")
else
	print(failures .. " test(s) failed.")
end
return failures
