local _, ns = ...

local L = ns.L
local MacroUI = ns:NewModule("MacroUI")

local WIDTH = 400
local MARKER_SIZE = 28
local window

-- A click-to-select box. Read-only in spirit: typing into it restores the
-- generated text, so nobody walks away with a half-edited macro.
local function CreateCopyBox(parent, height)
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetHeight(height)

	local background = holder:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints()
	background:SetColorTexture(0, 0, 0, 0.6)

	local edit = CreateFrame("EditBox", nil, holder)
	edit:SetAllPoints()
	edit:SetMultiLine(true)
	edit:SetFontObject("ChatFontNormal")
	edit:SetAutoFocus(false)
	edit:SetTextInsets(6, 6, 4, 4)
	edit:SetScript("OnEscapePressed", function() window:Hide() end)
	edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
	edit:SetScript("OnTextChanged", function(self, userInput)
		if userInput and holder.payload then
			self:SetText(holder.payload)
			self:HighlightText()
		end
	end)

	holder.edit = edit
	function holder:SetPayload(text)
		self.payload = text
		self.edit:SetText(text)
	end

	return holder
end

local function CreateWindow()
	local templated = true
	local ok, frame = pcall(CreateFrame, "Frame", "KickerMacroFrame", UIParent,
		"BasicFrameTemplateWithInset")
	if not ok or not frame then
		templated = false
		frame = CreateFrame("Frame", "KickerMacroFrame", UIParent)
		local background = frame:CreateTexture(nil, "BACKGROUND")
		background:SetAllPoints()
		background:SetColorTexture(0, 0, 0, 0.92)
	end

	frame:SetSize(WIDTH, 360)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetClampedToScreen(true)
	frame:Hide()

	if templated and frame.TitleText then
		frame.TitleText:SetText(L["MACRO_TITLE"])
	end

	frame.markerLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	frame.markerLabel:SetPoint("TOPLEFT", 14, -34)
	frame.markerLabel:SetText(L["MACRO_YOUR_MARKER"])

	frame.markerButtons = {}
	for marker = 1, ns.Data.MARKER_COUNT do
		local button = CreateFrame("Button", nil, frame)
		button:SetSize(MARKER_SIZE, MARKER_SIZE)
		button:SetPoint("TOPLEFT", 14 + (marker - 1) * (MARKER_SIZE + 6), -54)

		button.selection = button:CreateTexture(nil, "BACKGROUND")
		button.selection:SetAllPoints()
		button.selection:SetColorTexture(1, 0.82, 0, 0.45)
		button.selection:Hide()

		button.icon = button:CreateTexture(nil, "ARTWORK")
		button.icon:SetPoint("TOPLEFT", 2, -2)
		button.icon:SetPoint("BOTTOMRIGHT", -2, 2)
		button.icon:SetTexture(ns.Data:MarkerTexturePath(marker))

		button:SetScript("OnClick", function()
			ns.Macro:SetMarker(marker)
			MacroUI:Refresh()
		end)
		button:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(ns.Data:MarkerName(marker))
			GameTooltip:Show()
		end)
		button:SetScript("OnLeave", function() GameTooltip:Hide() end)

		frame.markerButtons[marker] = button
	end

	frame.markerHint = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	frame.markerHint:SetPoint("TOPLEFT", 14, -90)
	frame.markerHint:SetWidth(WIDTH - 28)
	frame.markerHint:SetJustifyH("LEFT")

	frame.setLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	frame.setLabel:SetPoint("TOPLEFT", 14, -112)
	frame.setLabel:SetText(L["MACRO_SET_LABEL"])

	frame.setBox = CreateCopyBox(frame, 58)
	frame.setBox:SetPoint("TOPLEFT", 14, -128)
	frame.setBox:SetPoint("RIGHT", frame, "RIGHT", -14, 0)

	frame.clearLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	frame.clearLabel:SetPoint("TOPLEFT", 14, -196)
	frame.clearLabel:SetText(L["MACRO_CLEAR_LABEL"])

	frame.clearBox = CreateCopyBox(frame, 42)
	frame.clearBox:SetPoint("TOPLEFT", 14, -212)
	frame.clearBox:SetPoint("RIGHT", frame, "RIGHT", -14, 0)

	frame.hint = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	frame.hint:SetPoint("TOPLEFT", 14, -262)
	frame.hint:SetWidth(WIDTH - 28)
	frame.hint:SetJustifyH("LEFT")
	frame.hint:SetText(L["MACRO_HINT"])

	frame.useSquad = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.useSquad:SetSize(150, 22)
	frame.useSquad:SetPoint("BOTTOMLEFT", 14, 14)
	frame.useSquad:SetText(L["MACRO_USE_SQUAD"])
	frame.useSquad:SetScript("OnClick", function()
		ns.Macro:ClearOverride()
		MacroUI:Refresh()
	end)

	frame.close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.close:SetSize(110, 22)
	frame.close:SetPoint("BOTTOMRIGHT", -14, 14)
	frame.close:SetText(L["TRANSFER_CLOSE"])
	frame.close:SetScript("OnClick", function() frame:Hide() end)

	tinsert(UISpecialFrames, "KickerMacroFrame")
	return frame
end

function MacroUI:Refresh()
	if not window then return end

	local marker = ns.Macro:GetMarker()
	for index = 1, ns.Data.MARKER_COUNT do
		window.markerButtons[index].selection:SetShown(index == marker)
	end

	window.markerHint:SetText(ns.Macro:HasOverride()
		and L["MACRO_MARKER_CHOSEN"]:format(ns.Data:MarkerName(marker))
		or L["MACRO_MARKER_FROM_SQUAD"]:format(ns.Data:MarkerName(marker)))

	window.useSquad:SetEnabled(ns.Macro:HasOverride())

	window.setBox:SetPayload(ns.Macro:BuildSet(marker))
	window.clearBox:SetPayload(ns.Macro:BuildClear())
end

function MacroUI:Toggle()
	if not window then
		window = CreateWindow()
	end
	if window:IsShown() then
		window:Hide()
	else
		self:Refresh()
		window:Show()
	end
end

function MacroUI:OnEnable()
	ns:On("SQUADS_CHANGED", function()
		if window and window:IsShown() then MacroUI:Refresh() end
	end)
end
