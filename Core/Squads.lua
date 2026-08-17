local _, ns = ...

local L = ns.L
local Squads = ns:NewModule("Squads")

-- A squad is: a set of markers + an ordered member list + one shared turn.
--
-- Two invariants hold the whole design up, and both are enforced here rather
-- than only in the UI:
--
--   1. a marker belongs to at most one squad
--   2. a character belongs to at most one squad
--
-- (2) is the load-bearing one. Midnight forbids reading which marker an enemy
-- carries, so when a kick arrives all we know is WHO cast it. If a character
-- could sit in two squads there would be no way to tell which turn order to
-- advance, and the ambiguity would be unresolvable rather than merely awkward.

function Squads:GetAll()
	return ns.Profiles:Current().squads
end

function Squads:Count()
	return #self:GetAll()
end

function Squads:Get(index)
	return self:GetAll()[index]
end

function Squads:Touch()
	local profile = ns.Profiles:Current()
	profile.revision = (profile.revision or 0) + 1
	ns:Fire("SQUADS_CHANGED")
end

function Squads:Revision()
	return ns.Profiles:Current().revision or 0
end

--------------------------------------------------------------------------------
-- Lookups
--------------------------------------------------------------------------------

-- Returns the index of the squad owning `marker`, ignoring `exceptIndex`.
function Squads:MarkerOwner(marker, exceptIndex)
	local squads = self:GetAll()
	for i = 1, #squads do
		if i ~= exceptIndex then
			local markers = squads[i].markers
			for j = 1, #markers do
				if markers[j] == marker then
					return i
				end
			end
		end
	end
	return nil
end

-- The hinge of the whole runtime: turns "who sent this message" into
-- "which turn order to advance".
function Squads:FindSquadOf(name, exceptIndex)
	local key = ns.Roster:Key(name)
	if not key then return nil end

	local squads = self:GetAll()
	for i = 1, #squads do
		if i ~= exceptIndex then
			local members = squads[i].members
			for j = 1, #members do
				if ns.Roster:Key(members[j]) == key then
					return i, j
				end
			end
		end
	end
	return nil
end

function Squads:MySquadIndex()
	return (self:FindSquadOf(GetUnitName("player", true)))
end

--------------------------------------------------------------------------------
-- Mutations
--------------------------------------------------------------------------------

function Squads:Create()
	local squads = self:GetAll()
	squads[#squads + 1] = { markers = {}, members = {} }
	self:Touch()
	return #squads
end

function Squads:Delete(index)
	local squads = self:GetAll()
	if not squads[index] then return false end
	table.remove(squads, index)
	self:Touch()
	return true
end

function Squads:ToggleMarker(index, marker)
	local squad = self:Get(index)
	if not squad then return false, L["ERR_NO_SQUAD"]:format(tostring(index)) end
	if type(marker) ~= "number" or marker < 1 or marker > ns.Data.MARKER_COUNT then
		return false, L["ERR_MARKER_RANGE"]
	end

	for i = 1, #squad.markers do
		if squad.markers[i] == marker then
			table.remove(squad.markers, i)
			self:Touch()
			return true
		end
	end

	local owner = self:MarkerOwner(marker, index)
	if owner then
		return false, L["ERR_MARKER_TAKEN"]:format(ns.Data:MarkerName(marker), owner)
	end

	squad.markers[#squad.markers + 1] = marker
	table.sort(squad.markers)
	self:Touch()
	return true
end

function Squads:AddMember(index, name)
	local squad = self:Get(index)
	if not squad then return false, L["ERR_NO_SQUAD"]:format(tostring(index)) end

	local normalized = ns.Roster:Normalize(name)
	if not normalized then return false, L["ERR_EMPTY_NAME"] end

	local key = ns.Roster:Key(normalized)
	for i = 1, #squad.members do
		if ns.Roster:Key(squad.members[i]) == key then
			return false, L["ERR_MEMBER_DUPLICATE"]:format(ns.Roster:Display(normalized))
		end
	end

	local otherSquad = self:FindSquadOf(normalized, index)
	if otherSquad then
		return false, L["ERR_MEMBER_TAKEN"]:format(ns.Roster:Display(normalized), otherSquad)
	end

	squad.members[#squad.members + 1] = normalized
	self:Touch()
	return true
end

function Squads:RemoveMember(index, memberIndex)
	local squad = self:Get(index)
	if not squad or not squad.members[memberIndex] then return false end
	table.remove(squad.members, memberIndex)
	self:Touch()
	return true
end

function Squads:MoveMember(index, memberIndex, delta)
	local squad = self:Get(index)
	if not squad then return false end

	local target = memberIndex + delta
	local members = squad.members
	if not members[memberIndex] or not members[target] then return false end

	members[memberIndex], members[target] = members[target], members[memberIndex]
	self:Touch()
	return true
end

-- Checks a squad list that did not come from our own editor - an imported
-- string, or anything hand-edited. The editor enforces the two invariants as
-- you type, but data arriving from outside has never been through it, and a set
-- that breaks them would leave the rotation permanently ambiguous.
function Squads:ValidateSet(squads)
	local markerOwner, memberOwner = {}, {}

	for i = 1, #squads do
		for _, marker in ipairs(squads[i].markers) do
			if type(marker) ~= "number" or marker < 1 or marker > ns.Data.MARKER_COUNT then
				return false, L["ERR_MARKER_RANGE"]
			end
			if markerOwner[marker] then
				return false, L["ERR_MARKER_TAKEN"]:format(ns.Data:MarkerName(marker), markerOwner[marker])
			end
			markerOwner[marker] = i
		end

		for _, member in ipairs(squads[i].members) do
			local key = ns.Roster:Key(member)
			if key then
				if memberOwner[key] then
					return false, L["ERR_MEMBER_TAKEN"]:format(ns.Roster:Display(member), memberOwner[key])
				end
				memberOwner[key] = i
			end
		end
	end

	return true
end

--------------------------------------------------------------------------------
-- Bulk replace (used by Comm when a leader pushes)
--
-- Takes the sender's revision verbatim instead of bumping our own, so the
-- group converges on one number rather than racing upwards.
--------------------------------------------------------------------------------

function Squads:ReplaceAll(squads, revision)
	local profile = ns.Profiles:Current()

	local clean = {}
	for i = 1, #squads do
		local source = squads[i]
		local markers, members = {}, {}

		for j = 1, #(source.markers or {}) do
			local marker = tonumber(source.markers[j])
			if marker and marker >= 1 and marker <= ns.Data.MARKER_COUNT then
				markers[#markers + 1] = marker
			end
		end
		for j = 1, #(source.members or {}) do
			local normalized = ns.Roster:Normalize(source.members[j])
			if normalized then
				members[#members + 1] = normalized
			end
		end

		table.sort(markers)
		clean[#clean + 1] = { markers = markers, members = members }
	end

	profile.squads = clean
	profile.revision = revision or ((profile.revision or 0) + 1)
	ns:Fire("SQUADS_CHANGED")
end

--------------------------------------------------------------------------------
-- Serialisation
--
-- Deliberately hand-rolled and line-oriented: the payload has to survive the
-- 255-character cap per addon message, and one line per squad keeps a whole
-- push inside the 10-message burst allowance.
--------------------------------------------------------------------------------

function Squads:EncodeSquad(squad)
	return table.concat(squad.markers, ",") .. "|" .. table.concat(squad.members, ",")
end

function Squads:DecodeSquad(payload)
	local markerPart, memberPart = payload:match("^([^|]*)|(.*)$")
	if not markerPart then return nil end

	local squad = { markers = {}, members = {} }
	for value in markerPart:gmatch("[^,]+") do
		local marker = tonumber(value)
		if marker then squad.markers[#squad.markers + 1] = marker end
	end
	for value in memberPart:gmatch("[^,]+") do
		squad.members[#squad.members + 1] = value
	end
	return squad
end
