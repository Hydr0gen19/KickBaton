local _, ns = ...

local L = ns.L
local Board = ns:NewModule("Board")

-- The board draws configuration, not game state. It reads squads, a turn index
-- and locally-computed timers - nothing that Midnight protects - which is why
-- it keeps working regardless of what happens to the detection layer.

local PADDING = 6
local ROW_HEIGHT = 18
local MARKER_GAP = 6
local MIN_WIDTH = 150
local REFRESH_INTERVAL = 0.25

-- Stay inside Latin-1. WoW's fonts cover very little beyond it, and anything
-- they lack is drawn as a missing-glyph box - which is exactly what U+25B6 (the
-- obvious choice for a turn arrow) does here.
local TURN_GLYPH = "|cffffd100\194\187|r"              -- U+00BB right double angle

-- A literal pipe has to be doubled: a single one starts a colour or texture
-- escape and would swallow what follows.
local SEPARATOR = "|cff707070 || |r"

local board = CreateFrame("Frame", "KickBatonBoard", UIParent)
board:SetSize(MIN_WIDTH, ROW_HEIGHT)
board:SetClampedToScreen(true)

-- This is a combat readout, so it outranks ordinary windows. Without this the
-- editor - also centred, and far taller - simply covers it, which looks exactly
-- like the board failing to appear.
board:SetFrameStrata("HIGH")
board:SetMovable(true)
board:EnableMouse(true)
board:RegisterForDrag("LeftButton")
board:Hide()

local background = board:CreateTexture(nil, "BACKGROUND")
background:SetAllPoints()
background:SetColorTexture(0, 0, 0, 0.55)

local title = board:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
title:SetPoint("TOPLEFT", board, "TOPLEFT", PADDING, -3)
title:SetText(L["BOARD_TITLE"])

-- Shown only while the game is refusing to carry addon messages. Without it a
-- frozen turn pointer looks exactly like a working one, which is how this went
-- unnoticed through a whole key.
local notice = board:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
notice:SetTextColor(1, 0.5, 0.2)
notice:Hide()

local flash = board:CreateTexture(nil, "OVERLAY")
flash:SetAllPoints()
flash:SetColorTexture(1, 0.82, 0, 0.35)
flash:SetAlpha(0)

local flashAnim = flash:CreateAnimationGroup()
local flashIn = flashAnim:CreateAnimation("Alpha")
flashIn:SetFromAlpha(0)
flashIn:SetToAlpha(1)
flashIn:SetDuration(0.10)
flashIn:SetOrder(1)
local flashOut = flashAnim:CreateAnimation("Alpha")
flashOut:SetFromAlpha(1)
flashOut:SetToAlpha(0)
flashOut:SetDuration(0.45)
flashOut:SetOrder(2)

local rows = {}

-- nil means "not measured yet". Starting at false would make the very first
-- refresh look like a transition into your turn and fire an alert on every
-- login or /reload.
local wasMyTurn = nil

local function GetRow(index)
	local row = rows[index]
	if row then return row end

	row = CreateFrame("Frame", nil, board)
	row:SetHeight(ROW_HEIGHT)

	row.highlight = row:CreateTexture(nil, "BACKGROUND")
	row.highlight:SetAllPoints()
	row.highlight:SetColorTexture(1, 1, 1, 0.07)
	row.highlight:Hide()

	row.markers = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	row.markers:SetPoint("LEFT", row, "LEFT", PADDING, 0)

	row.members = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	row.members:SetPoint("LEFT", row.markers, "RIGHT", MARKER_GAP, 0)
	row.members:SetJustifyH("LEFT")

	rows[index] = row
	return row
end

-- Three states, deliberately distinct at a glance mid-pull: whoever is up next
-- carries full class colour, everyone else ready is dimmed to stay readable
-- without competing for attention, and anyone on cooldown greys out with the
-- seconds left.
local DIM_FACTOR = 0.45

local function FormatMember(name, isTurn, remaining)
	local text
	if remaining > 0 then
		text = string.format("|cff707070%s|r|cff505050 %d|r",
			ns.Roster:Display(name), math.ceil(remaining))
	elseif isTurn then
		text = ns.Roster:ColorName(name)
	else
		text = ns.Roster:ColorName(name, DIM_FACTOR)
	end

	-- The glyph stays even when the whole squad is on cooldown, so the board
	-- never stops saying who is up next.
	if isTurn then
		text = TURN_GLYPH .. " " .. text
	end
	return text
end

function Board:Alert()
	if ns.db.alert.sound then
		local sound = SOUNDKIT and (SOUNDKIT.READY_CHECK or SOUNDKIT.RAID_WARNING)
		if sound then
			pcall(PlaySound, sound, "Master")
		end
	end
	if ns.db.alert.flash then
		flashAnim:Stop()
		flashAnim:Play()
	end
end

function Board:Refresh()
	if not ns.initialized then return end

	local squads = ns.Squads:GetAll()
	local widest = MIN_WIDTH
	local showTitle = not ns.db.ui.locked
	local top = showTitle and -(ROW_HEIGHT) or -PADDING

	title:SetShown(showTitle)

	for index = 1, #squads do
		local squad = squads[index]
		local row = GetRow(index)

		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", board, "TOPLEFT", 0, top - (index - 1) * ROW_HEIGHT)
		row:SetPoint("TOPRIGHT", board, "TOPRIGHT", 0, top - (index - 1) * ROW_HEIGHT)

		row.markers:SetText(ns.Data:MarkerIcons(squad.markers, 14))

		local turnIndex = ns.Rotation:TurnIndex(index)
		local parts = {}
		for memberIndex = 1, #squad.members do
			local name = squad.members[memberIndex]
			parts[#parts + 1] = FormatMember(
				name,
				memberIndex == turnIndex,
				ns.Rotation:CooldownRemaining(name))
		end
		row.members:SetText(table.concat(parts, SEPARATOR))

		row.highlight:SetShown(ns.Squads:FindSquadOf(GetUnitName("player", true)) == index)
		row:Show()

		-- GetStringWidth is not reliable for a string made only of inline
		-- texture escapes, so floor it at the space the icons actually need.
		local markerWidth = math.max(row.markers:GetStringWidth(), #squad.markers * 16)
		local width = PADDING * 2 + MARKER_GAP + markerWidth + row.members:GetStringWidth()
		if width > widest then widest = width end
	end

	for index = #squads + 1, #rows do
		rows[index]:Hide()
	end

	-- nil means the client cannot tell; only a definite true is worth alarming
	-- anyone about - and not even then if party kicks are coming through
	-- directly, because the turn is syncing after all.
	local blocked = ns.Restrictions:ChatBlocked() == true
		and not ns.SelfReport.partyWatch
	notice:SetShown(blocked)

	local noticeHeight = 0
	if blocked then
		notice:SetText("|cffff8033! " .. L["BOARD_NO_SYNC"] .. "|r")
		notice:ClearAllPoints()
		notice:SetPoint("TOPLEFT", board, "TOPLEFT", PADDING,
			top - #squads * ROW_HEIGHT - 2)
		noticeHeight = ROW_HEIGHT
		local width = PADDING * 2 + notice:GetStringWidth()
		if width > widest then widest = width end
	end

	local height = (showTitle and ROW_HEIGHT or PADDING)
		+ #squads * ROW_HEIGHT + noticeHeight + PADDING
	board:SetSize(math.ceil(widest), math.max(height, ROW_HEIGHT))

	local isMyTurn = ns.Rotation:IsMyTurn()
	if isMyTurn and wasMyTurn == false then
		self:Alert()
	end
	wasMyTurn = isMyTurn
end

-- Why the board is or isn't on screen, as a single value. Exposed so
-- /kickbaton status can answer "where is it?" instead of leaving you to guess.
function Board:VisibilityState()
	local ui = ns.db.ui
	if ui.hidden then return "manual" end
	if ns.Squads:Count() == 0 then return "empty" end
	if ui.hideOutOfGroup and not IsInGroup() then return "solo" end
	return "shown"
end

function Board:UpdateVisibility()
	if self:VisibilityState() ~= "shown" then
		board:Hide()
		return
	end

	board:Show()
	self:Refresh()
end

function Board:SavePosition()
	local point, _, relativePoint, x, y = board:GetPoint()
	local ui = ns.db.ui
	ui.point, ui.relPoint, ui.x, ui.y = point, relativePoint, x, y
end

function Board:RestorePosition()
	local ui = ns.db.ui
	board:ClearAllPoints()
	board:SetPoint(ui.point or "CENTER", UIParent, ui.relPoint or "CENTER", ui.x or 0, ui.y or -250)
	board:SetScale(ui.scale or 1)
end

function Board:ResetPosition()
	local ui = ns.db.ui
	ui.point, ui.relPoint, ui.x, ui.y = "CENTER", "CENTER", 0, -250
	self:RestorePosition()
	ns:Print(L["BOARD_RESET"])
end

function Board:SetLocked(locked)
	ns.db.ui.locked = locked and true or false
	ns:Print(locked and L["BOARD_LOCKED"] or L["BOARD_UNLOCKED"])
	self:UpdateVisibility()
end

function Board:SetHidden(hidden)
	ns.db.ui.hidden = hidden and true or false
	self:UpdateVisibility()

	-- Switching it back on while something else is still holding it off looks
	-- like the toggle is broken, so name the actual reason.
	if not hidden then
		local state = self:VisibilityState()
		if state == "empty" then
			ns:Print(L["STATUS_BOARD_EMPTY"])
		elseif state == "solo" then
			ns:Print(L["STATUS_BOARD_SOLO"])
		end
	end
end

function Board:SetScale(scale)
	ns.db.ui.scale = scale
	board:SetScale(scale)
end

board:SetScript("OnDragStart", function(self)
	if not ns.db.ui.locked then
		self:StartMoving()
	end
end)

board:SetScript("OnDragStop", function(self)
	self:StopMovingOrSizing()
	Board:SavePosition()
end)

-- Right-click opens the editor, so the board is its own entry point.
board:SetScript("OnMouseUp", function(_, button)
	if button == "RightButton" and ns.Config then
		ns.Config:Toggle()
	end
end)

local elapsed = 0
board:SetScript("OnUpdate", function(_, delta)
	elapsed = elapsed + delta
	if elapsed < REFRESH_INTERVAL then return end
	elapsed = 0
	Board:Refresh()
end)

function Board:OnEnable()
	self:RestorePosition()
	self:UpdateVisibility()

	local function refresh()
		Board:UpdateVisibility()
	end

	ns:On("SQUADS_CHANGED", refresh)
	ns:On("RESTRICTIONS_CHANGED", refresh)
	ns:On("ROTATION_CHANGED", refresh)
	ns:On("ROSTER_CHANGED", refresh)
	ns:On("PROFILE_CHANGED", refresh)
	ns:RegisterEvent("GROUP_ROSTER_UPDATE", refresh)
end
