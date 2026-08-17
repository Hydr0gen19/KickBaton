local _, ns = ...

local L = ns.L
local Config = ns:NewModule("Config")

local WINDOW_WIDTH = 380
local MARKER_SIZE = 26
local ROW_HEIGHT = 20
local BLOCK_GAP = 10
local INNER_PAD = 12

local window
local blocks = {}

--------------------------------------------------------------------------------
-- Small builders
--
-- Each one degrades to something plain if a Blizzard template is missing, so a
-- template that gets retired in a future patch costs a control rather than the
-- whole window.
--------------------------------------------------------------------------------

local function MakeButton(parent, text, width, height)
	local ok, button = pcall(CreateFrame, "Button", nil, parent, "UIPanelButtonTemplate")
	if not ok or not button then
		button = CreateFrame("Button", nil, parent)
		local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		label:SetAllPoints()
		-- Registering the fontstring keeps SetText working on the fallback too,
		-- which matters for buttons whose label changes with state.
		button:SetFontString(label)
		button:SetText(text)
	else
		button:SetText(text)
	end
	button:SetSize(width, height)
	return button
end

local function MakeCheckbox(parent, text)
	local ok, check = pcall(CreateFrame, "CheckButton", nil, parent, "UICheckButtonTemplate")
	if not ok or not check then
		check = CreateFrame("CheckButton", nil, parent)
		check:SetSize(24, 24)
	end
	check:SetSize(24, 24)

	-- Label built by hand rather than reaching into the template's internals,
	-- which have moved more than once between expansions.
	local label = check:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	label:SetPoint("LEFT", check, "RIGHT", 4, 0)
	label:SetText(text)
	check.label = label

	return check
end

local function ShowMenu(owner, entries)
	if MenuUtil and MenuUtil.CreateContextMenu then
		MenuUtil.CreateContextMenu(owner, function(_, root)
			for i = 1, #entries do
				local entry = entries[i]
				root:CreateButton(entry.text, entry.func)
			end
		end)
		return true
	end
	return false
end

--------------------------------------------------------------------------------
-- Squad block
--------------------------------------------------------------------------------

local function CreateMemberRow(block, index)
	local row = block.memberRows[index]
	if row then return row end

	row = CreateFrame("Frame", nil, block)
	row:SetHeight(ROW_HEIGHT)

	row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	row.name:SetPoint("LEFT", row, "LEFT", 8, 0)
	row.name:SetJustifyH("LEFT")

	row.remove = MakeButton(row, "X", 22, 18)
	row.remove:SetPoint("RIGHT", row, "RIGHT", -4, 0)

	row.down = MakeButton(row, "v", 22, 18)
	row.down:SetPoint("RIGHT", row.remove, "LEFT", -2, 0)

	row.up = MakeButton(row, "^", 22, 18)
	row.up:SetPoint("RIGHT", row.down, "LEFT", -2, 0)

	block.memberRows[index] = row
	return row
end

local function CreateBlock(index)
	local block = blocks[index]
	if block then return block end

	block = CreateFrame("Frame", nil, window)
	block:SetWidth(WINDOW_WIDTH - INNER_PAD * 2)

	local bg = block:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(1, 1, 1, 0.05)

	block.title = block:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	block.title:SetPoint("TOPLEFT", block, "TOPLEFT", 8, -6)

	block.delete = MakeButton(block, L["CONFIG_DELETE_SQUAD"], 110, 18)
	block.delete:SetPoint("TOPRIGHT", block, "TOPRIGHT", -6, -6)

	block.markerButtons = {}
	for marker = 1, ns.Data.MARKER_COUNT do
		local button = CreateFrame("Button", nil, block)
		button:SetSize(MARKER_SIZE, MARKER_SIZE)
		button:SetPoint("TOPLEFT", block, "TOPLEFT",
			8 + (marker - 1) * (MARKER_SIZE + 4), -28)

		button.selection = button:CreateTexture(nil, "BACKGROUND")
		button.selection:SetAllPoints()
		button.selection:SetColorTexture(1, 0.82, 0, 0.45)
		button.selection:Hide()

		button.icon = button:CreateTexture(nil, "ARTWORK")
		button.icon:SetPoint("TOPLEFT", 2, -2)
		button.icon:SetPoint("BOTTOMRIGHT", -2, 2)
		button.icon:SetTexture(ns.Data:MarkerTexturePath(marker))

		button.marker = marker
		block.markerButtons[marker] = button
	end

	block.membersLabel = block:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	block.membersLabel:SetPoint("TOPLEFT", block, "TOPLEFT", 8, -62)
	block.membersLabel:SetText(L["CONFIG_MEMBERS"])

	block.memberRows = {}

	block.entry = CreateFrame("EditBox", nil, block, "InputBoxTemplate")
	block.entry:SetSize(140, 20)
	block.entry:SetAutoFocus(false)

	block.add = MakeButton(block, L["CONFIG_ADD_MEMBER"], 60, 20)
	block.fromGroup = MakeButton(block, L["CONFIG_ADD_FROM_GROUP"], 120, 20)

	blocks[index] = block
	return block
end

local function LayoutBlock(block, squadIndex, squad)
	block.title:SetText(L["CONFIG_SQUAD_N"]:format(squadIndex))

	block.delete:SetScript("OnClick", function()
		ns.Squads:Delete(squadIndex)
	end)

	for marker = 1, ns.Data.MARKER_COUNT do
		local button = block.markerButtons[marker]
		local owner = ns.Squads:MarkerOwner(marker, squadIndex)

		local selected = false
		for i = 1, #squad.markers do
			if squad.markers[i] == marker then selected = true break end
		end

		button.selection:SetShown(selected)
		button.icon:SetDesaturated(not selected and owner ~= nil)
		button:SetAlpha(owner and not selected and 0.3 or 1)
		button:SetEnabled(owner == nil or selected)

		button:SetScript("OnClick", function()
			local ok, err = ns.Squads:ToggleMarker(squadIndex, marker)
			if not ok and err then ns:Print(err) end
		end)

		button:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(ns.Data:MarkerName(marker))
			if owner and not selected then
				GameTooltip:AddLine(L["CONFIG_MARKER_TAKEN"]:format(owner), 1, 0.3, 0.3)
			end
			GameTooltip:Show()
		end)
		button:SetScript("OnLeave", function() GameTooltip:Hide() end)
	end

	local offset = 80
	for memberIndex = 1, #squad.members do
		local row = CreateMemberRow(block, memberIndex)
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", block, "TOPLEFT", 0, -offset)
		row:SetPoint("TOPRIGHT", block, "TOPRIGHT", 0, -offset)

		local name = squad.members[memberIndex]
		row.name:SetText(string.format("%d. %s", memberIndex, ns.Roster:ColorName(name)))

		row.up:SetEnabled(memberIndex > 1)
		row.down:SetEnabled(memberIndex < #squad.members)

		row.up:SetScript("OnClick", function() ns.Squads:MoveMember(squadIndex, memberIndex, -1) end)
		row.down:SetScript("OnClick", function() ns.Squads:MoveMember(squadIndex, memberIndex, 1) end)
		row.remove:SetScript("OnClick", function() ns.Squads:RemoveMember(squadIndex, memberIndex) end)

		row:Show()
		offset = offset + ROW_HEIGHT
	end

	for memberIndex = #squad.members + 1, #block.memberRows do
		block.memberRows[memberIndex]:Hide()
	end

	offset = offset + 4
	block.entry:ClearAllPoints()
	block.entry:SetPoint("TOPLEFT", block, "TOPLEFT", 12, -offset)

	block.add:ClearAllPoints()
	block.add:SetPoint("LEFT", block.entry, "RIGHT", 8, 0)

	block.fromGroup:ClearAllPoints()
	block.fromGroup:SetPoint("LEFT", block.add, "RIGHT", 6, 0)

	local function commit()
		local text = block.entry:GetText()
		local ok, err = ns.Squads:AddMember(squadIndex, text)
		if ok then
			block.entry:SetText("")
			block.entry:ClearFocus()
		elseif err then
			ns:Print(err)
		end
	end

	block.entry:SetScript("OnEnterPressed", commit)
	block.add:SetScript("OnClick", commit)

	block.fromGroup:SetScript("OnClick", function(self)
		local entries = {}
		for _, name in ipairs(ns.Roster:GetGroupMembers()) do
			if not ns.Squads:FindSquadOf(name) then
				entries[#entries + 1] = {
					text = ns.Roster:Display(name),
					func = function()
						local ok, err = ns.Squads:AddMember(squadIndex, name)
						if not ok and err then ns:Print(err) end
					end,
				}
			end
		end
		if #entries == 0 then
			ns:Print(L["CONFIG_NOBODY_TO_ADD"])
			return
		end
		if not ShowMenu(self, entries) then
			-- No menu API available: add the first unassigned member so the
			-- button still does something predictable.
			entries[1].func()
		end
	end)

	block:SetHeight(offset + 30)
	block:Show()
	return block:GetHeight()
end

--------------------------------------------------------------------------------
-- Window
--------------------------------------------------------------------------------

local function CreateWindow()
	local templated = true
	local ok, frame = pcall(CreateFrame, "Frame", "KickBatonConfigFrame", UIParent,
		"BasicFrameTemplateWithInset")
	if not ok or not frame then
		templated = false
		frame = CreateFrame("Frame", "KickBatonConfigFrame", UIParent)
		local bg = frame:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		bg:SetColorTexture(0, 0, 0, 0.9)

		local close = MakeButton(frame, "X", 24, 20)
		close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
		close:SetScript("OnClick", function() frame:Hide() end)
	end

	frame:SetSize(WINDOW_WIDTH, 400)
	frame:SetPoint("CENTER")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetClampedToScreen(true)
	frame:Hide()

	if templated and frame.TitleText then
		frame.TitleText:SetText(L["CONFIG_TITLE"])
	end

	frame.intro = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	frame.intro:SetPoint("TOPLEFT", frame, "TOPLEFT", INNER_PAD, -32)
	frame.intro:SetWidth(WINDOW_WIDTH - INNER_PAD * 2)
	frame.intro:SetJustifyH("LEFT")
	frame.intro:SetText(L["CONFIG_INTRO"])

	frame.empty = frame:CreateFontString(nil, "ARTWORK", "GameFontDisable")
	frame.empty:SetPoint("TOPLEFT", frame, "TOPLEFT", INNER_PAD, -70)
	frame.empty:SetText(L["CONFIG_NO_SQUADS"])

	frame.newSquad = MakeButton(frame, L["CONFIG_ADD_SQUAD"], 110, 22)
	frame.newSquad:SetScript("OnClick", function() ns.Squads:Create() end)

	frame.push = MakeButton(frame, L["CONFIG_PUSH"], 120, 22)
	frame.push:SetScript("OnClick", function() ns.Comm:PushSquads() end)

	frame.export = MakeButton(frame, L["TRANSFER_EXPORT"], 110, 22)
	frame.export:SetScript("OnClick", function() ns.TransferUI:Show("export") end)

	frame.import = MakeButton(frame, L["TRANSFER_IMPORT"], 110, 22)
	frame.import:SetScript("OnClick", function() ns.TransferUI:Show("import") end)

	frame.macro = MakeButton(frame, L["MACRO_BUTTON"], 110, 22)
	frame.macro:SetScript("OnClick", function() ns.MacroUI:Toggle() end)

	frame.toggleBoard = MakeButton(frame, L["CONFIG_HIDE_BOARD"], 110, 22)
	frame.toggleBoard:SetScript("OnClick", function()
		ns.Board:SetHidden(not ns.db.ui.hidden)
		Config:Rebuild()
	end)

	frame.profile = MakeButton(frame, L["CONFIG_PROFILE"], 100, 22)
	frame.profile:SetScript("OnClick", function(self)
		local entries = {}
		for _, name in ipairs(ns.Profiles:List()) do
			entries[#entries + 1] = {
				text = name,
				func = function() ns.Profiles:Switch(name) end,
			}
		end
		ShowMenu(self, entries)
	end)

	tinsert(UISpecialFrames, "KickBatonConfigFrame")
	return frame
end

function Config:Rebuild()
	if not window then return end

	local squads = ns.Squads:GetAll()
	local top = 62

	for index = 1, #squads do
		local block = CreateBlock(index)
		block:ClearAllPoints()
		block:SetPoint("TOPLEFT", window, "TOPLEFT", INNER_PAD, -top)
		top = top + LayoutBlock(block, index, squads[index]) + BLOCK_GAP
	end

	for index = #squads + 1, #blocks do
		blocks[index]:Hide()
	end

	window.empty:SetShown(#squads == 0)
	if #squads == 0 then
		top = top + 24
	end

	window.newSquad:ClearAllPoints()
	window.newSquad:SetPoint("TOPLEFT", window, "TOPLEFT", INNER_PAD, -top)

	window.push:ClearAllPoints()
	window.push:SetPoint("LEFT", window.newSquad, "RIGHT", 6, 0)

	window.profile:ClearAllPoints()
	window.profile:SetPoint("LEFT", window.push, "RIGHT", 6, 0)

	-- Second row: three buttons already fill the window's width.
	window.export:ClearAllPoints()
	window.export:SetPoint("TOPLEFT", window.newSquad, "BOTTOMLEFT", 0, -6)

	window.import:ClearAllPoints()
	window.import:SetPoint("LEFT", window.export, "RIGHT", 6, 0)

	window.toggleBoard:ClearAllPoints()
	window.toggleBoard:SetPoint("LEFT", window.import, "RIGHT", 6, 0)
	window.toggleBoard:SetText(ns.db.ui.hidden and L["CONFIG_SHOW_BOARD"] or L["CONFIG_HIDE_BOARD"])

	-- Third row: two rows of three already fill the window's width.
	window.macro:ClearAllPoints()
	window.macro:SetPoint("TOPLEFT", window.export, "BOTTOMLEFT", 0, -6)

	window:SetHeight(top + 102)
end

function Config:Toggle()
	if not window then
		window = CreateWindow()
	end
	if window:IsShown() then
		window:Hide()
	else
		self:Rebuild()
		window:Show()
	end
end

--------------------------------------------------------------------------------
-- Settings panel
--------------------------------------------------------------------------------

local function BuildOptionsPanel()
	if not (Settings and Settings.RegisterCanvasLayoutCategory) then return end

	local panel = CreateFrame("Frame")
	panel.name = L["OPT_TITLE"]

	local heading = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	heading:SetPoint("TOPLEFT", 16, -16)
	heading:SetText(L["OPT_TITLE"])

	local offset = -50
	local function AddToggle(text, tooltip, get, set)
		local check = MakeCheckbox(panel, text)
		check:SetPoint("TOPLEFT", 16, offset)
		check:SetChecked(get())
		check:SetScript("OnClick", function(self)
			set(self:GetChecked() and true or false)
		end)
		if tooltip then
			check:SetScript("OnEnter", function(self)
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				GameTooltip:SetText(text)
				GameTooltip:AddLine(tooltip, 1, 1, 1, true)
				GameTooltip:Show()
			end)
			check:SetScript("OnLeave", function() GameTooltip:Hide() end)
		end
		offset = offset - 28
		return check
	end

	AddToggle(L["OPT_SHOW_BOARD"], L["OPT_SHOW_BOARD_TIP"],
		function() return not ns.db.ui.hidden end,
		function(value) ns.Board:SetHidden(not value) end)

	AddToggle(L["OPT_LOCK"], L["OPT_LOCK_TIP"],
		function() return ns.db.ui.locked end,
		function(value) ns.Board:SetLocked(value) end)

	AddToggle(L["OPT_HIDE_SOLO"], nil,
		function() return ns.db.ui.hideOutOfGroup end,
		function(value)
			ns.db.ui.hideOutOfGroup = value
			ns.Board:UpdateVisibility()
		end)

	AddToggle(L["OPT_SOUND"], nil,
		function() return ns.db.alert.sound end,
		function(value) ns.db.alert.sound = value end)

	AddToggle(L["OPT_FLASH"], nil,
		function() return ns.db.alert.flash end,
		function(value) ns.db.alert.flash = value end)

	AddToggle(L["OPT_SELFREPORT"], L["OPT_SELFREPORT_TIP"],
		function() return ns.db.selfReport end,
		function(value) ns.db.selfReport = value end)

	-- pcall returns (false, message) on failure, and a message string is truthy,
	-- so the success flag has to be checked explicitly rather than the value.
	local sliderOK, slider = pcall(CreateFrame, "Slider", nil, panel, "OptionsSliderTemplate")
	if sliderOK and slider then
		slider:SetPoint("TOPLEFT", 20, offset - 16)
		slider:SetWidth(200)
		slider:SetMinMaxValues(0.5, 3.0)
		slider:SetValueStep(0.05)
		slider:SetObeyStepOnDrag(true)
		slider:SetValue(ns.db.ui.scale or 1)
		if slider.Low then slider.Low:SetText("50%") end
		if slider.High then slider.High:SetText("300%") end

		local function label(value)
			if slider.Text then
				slider.Text:SetFormattedText("%s: %d%%", L["OPT_SCALE"], value * 100)
			end
		end
		label(ns.db.ui.scale or 1)

		slider:SetScript("OnValueChanged", function(_, value)
			ns.Board:SetScale(value)
			label(value)
		end)
		offset = offset - 60
	end

	local open = MakeButton(panel, L["OPT_OPEN_EDITOR"], 180, 22)
	open:SetPoint("TOPLEFT", 16, offset - 10)
	open:SetScript("OnClick", function() Config:Toggle() end)

	local category = Settings.RegisterCanvasLayoutCategory(panel, L["OPT_TITLE"])
	category.ID = L["OPT_TITLE"]
	Settings.RegisterAddOnCategory(category)
end

function Config:OnEnable()
	ns:On("SQUADS_CHANGED", function()
		if window and window:IsShown() then Config:Rebuild() end
	end)
	ns:On("PROFILE_CHANGED", function()
		if window and window:IsShown() then Config:Rebuild() end
	end)

	pcall(BuildOptionsPanel)
end
