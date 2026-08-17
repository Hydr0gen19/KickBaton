local _, ns = ...

local L = ns.L
local TransferUI = ns:NewModule("TransferUI")

local WIDTH, HEIGHT = 430, 250
local dialog

local function CreateDialog()
	local templated = true
	local ok, frame = pcall(CreateFrame, "Frame", "KickerTransferFrame", UIParent,
		"BasicFrameTemplateWithInset")
	if not ok or not frame then
		templated = false
		frame = CreateFrame("Frame", "KickerTransferFrame", UIParent)
		local background = frame:CreateTexture(nil, "BACKGROUND")
		background:SetAllPoints()
		background:SetColorTexture(0, 0, 0, 0.92)
	end

	frame:SetSize(WIDTH, HEIGHT)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetClampedToScreen(true)
	frame:Hide()

	frame.title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	frame.title:SetPoint("TOPLEFT", 14, -32)

	frame.hint = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	frame.hint:SetPoint("TOPLEFT", 14, -52)
	frame.hint:SetWidth(WIDTH - 28)
	frame.hint:SetJustifyH("LEFT")

	if templated and frame.TitleText then
		frame.TitleText:SetText("Kicker")
	end

	-- A plain bordered EditBox rather than a scrolling one: the payload is a
	-- couple of lines, and this drops a template dependency that has been
	-- renamed more than once.
	local box = CreateFrame("Frame", nil, frame)
	box:SetPoint("TOPLEFT", 14, -76)
	box:SetPoint("BOTTOMRIGHT", -14, 44)

	local boxBackground = box:CreateTexture(nil, "BACKGROUND")
	boxBackground:SetAllPoints()
	boxBackground:SetColorTexture(0, 0, 0, 0.6)

	local edit = CreateFrame("EditBox", nil, box)
	edit:SetAllPoints()
	edit:SetMultiLine(true)
	edit:SetFontObject("ChatFontNormal")
	edit:SetAutoFocus(false)
	edit:SetTextInsets(6, 6, 6, 6)
	edit:SetScript("OnEscapePressed", function() frame:Hide() end)

	-- In export mode the box is a display, not an input: silently restore the
	-- payload if it gets typed over, so a stray keypress cannot hand someone a
	-- corrupted string that still looks copyable.
	edit:SetScript("OnTextChanged", function(self, userInput)
		if userInput and dialog and dialog.mode == "export" and dialog.payload then
			self:SetText(dialog.payload)
			self:HighlightText()
		end
	end)
	frame.edit = edit

	frame.importButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.importButton:SetSize(110, 22)
	frame.importButton:SetPoint("BOTTOMLEFT", 14, 14)
	frame.importButton:SetText(L["TRANSFER_IMPORT_BUTTON"])
	frame.importButton:SetScript("OnClick", function()
		local success, result, count = ns.Transfer:Import(frame.edit:GetText())
		if success then
			ns:Print(L["TRANSFER_IMPORTED"], count, result)
			frame:Hide()
			if ns.Config then ns.Config:Rebuild() end
		else
			ns:Print(result)
		end
	end)

	frame.closeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.closeButton:SetSize(110, 22)
	frame.closeButton:SetPoint("BOTTOMRIGHT", -14, 14)
	frame.closeButton:SetText(L["TRANSFER_CLOSE"])
	frame.closeButton:SetScript("OnClick", function() frame:Hide() end)

	tinsert(UISpecialFrames, "KickerTransferFrame")
	return frame
end

function TransferUI:Show(mode)
	if not dialog then
		dialog = CreateDialog()
	end
	dialog.mode = mode

	if mode == "export" then
		dialog.payload = ns.Transfer:Export()
		dialog.title:SetText(L["TRANSFER_EXPORT_TITLE"])
		dialog.hint:SetText(L["TRANSFER_EXPORT_HINT"])
		dialog.importButton:Hide()
		dialog:Show()
		dialog.edit:SetText(dialog.payload)
		dialog.edit:SetFocus()
		dialog.edit:HighlightText()
	else
		dialog.payload = nil
		dialog.title:SetText(L["TRANSFER_IMPORT_TITLE"])
		dialog.hint:SetText(L["TRANSFER_IMPORT_HINT"])
		dialog.importButton:Show()
		dialog:Show()
		dialog.edit:SetText("")
		dialog.edit:SetFocus()
	end
end
