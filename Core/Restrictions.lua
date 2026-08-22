local _, ns = ...

local Restrictions = ns:NewModule("Restrictions")

-- Midnight can switch addon communications off underneath us, and the game is
-- the only thing that knows for sure. Rather than infer it from the map or the
-- keystone state, ask:
--
--   Enum.AddOnRestrictionType.ChallengeMode (2)
--     "the player is in an active and incomplete challenge mode or mythic
--      keystone dungeon"
--   Enum.AddOnRestrictionType.Chat (5)
--     "the player is in a state where addon chat communications are restricted"
--
-- Every probe is defensive. C_RestrictedActions arrived in 12.0 and may move
-- again; a missing API has to degrade to "cannot tell", never to an error in
-- the middle of a pull. Hence the three-state answer: true, false, or nil.

local function ResolveType(name, fallback)
	if Enum and Enum.AddOnRestrictionType and Enum.AddOnRestrictionType[name] ~= nil then
		return Enum.AddOnRestrictionType[name]
	end
	return fallback
end

function Restrictions:IsActive(name, fallback)
	local query = C_RestrictedActions and C_RestrictedActions.IsAddOnRestrictionActive
	if not query then return nil end

	local kind = ResolveType(name, fallback)
	if kind == nil then return nil end

	local ok, active = pcall(query, kind)
	if not ok then return nil end
	return active and true or false
end

-- nil means the client could not answer, which is different from "not blocked"
-- and must never be reported as if it were.
function Restrictions:ChatBlocked()
	return self:IsActive("Chat", 5)
end

function Restrictions:InKeystone()
	return self:IsActive("ChallengeMode", 2)
end

function Restrictions:OnEnable()
	-- The state changes mid-run when a key starts or ends, so react rather than
	-- polling: the board needs to stop claiming a turn it can no longer sync.
	for _, event in ipairs({
		"ADDON_RESTRICTION_STATE_CHANGED",
		"CHALLENGE_MODE_START",
		"CHALLENGE_MODE_COMPLETED",
		"PLAYER_ENTERING_WORLD",
	}) do
		pcall(function()
			ns:RegisterEvent(event, function()
				ns:Fire("RESTRICTIONS_CHANGED")
			end)
		end)
	end
end
