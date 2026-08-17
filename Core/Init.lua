--[[
KickBaton - interrupt rotation assignments by raid marker
Copyright (C) 2026 Luca Vitale

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program. If not, see <https://www.gnu.org/licenses/>.
]]

local addonName, ns = ...

-- A missing locale key resolves to the key itself rather than nil, so a typo
-- shows up as visible text instead of silently blanking a label.
setmetatable(ns.L, { __index = function(_, key) return key end })

local L = ns.L

ns.ADDON_NAME = addonName
ns.VERSION = (C_AddOns and C_AddOns.GetAddOnMetadata
	and C_AddOns.GetAddOnMetadata(addonName, "Version")) or "0.1.0"

local CHAT_PREFIX = "|cff33ff99KickBaton|r: "

function ns:Print(msg, ...)
	if select("#", ...) > 0 then
		msg = string.format(msg, ...)
	end
	local frame = DEFAULT_CHAT_FRAME or ChatFrame1
	if frame then
		frame:AddMessage(CHAT_PREFIX .. tostring(msg))
	end
end

--------------------------------------------------------------------------------
-- Modules
--
-- Files are listed in load order in the TOC, so appending here gives a
-- deterministic init order and lets later modules depend on earlier ones.
--------------------------------------------------------------------------------

ns.modules = {}

function ns:NewModule(name)
	local module = { moduleName = name }
	ns[name] = module
	ns.modules[#ns.modules + 1] = module
	return module
end

--------------------------------------------------------------------------------
-- Events
--
-- One frame for the whole addon. Note that unit events are deliberately NOT
-- routed through here: SelfReport owns its own frame so it can use
-- RegisterUnitEvent and stay narrowly scoped to the player.
--------------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
local handlers = {}

function ns:RegisterEvent(event, handler)
	local list = handlers[event]
	if not list then
		list = {}
		handlers[event] = list
		eventFrame:RegisterEvent(event)
	end
	list[#list + 1] = handler
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
	local list = handlers[event]
	if not list then return end
	for i = 1, #list do
		list[i](event, ...)
	end
end)

--------------------------------------------------------------------------------
-- Internal message bus
--
-- Keeps the data modules from having to know the UI exists.
--------------------------------------------------------------------------------

local listeners = {}

function ns:On(message, callback)
	local list = listeners[message]
	if not list then
		list = {}
		listeners[message] = list
	end
	list[#list + 1] = callback
end

function ns:Fire(message, ...)
	local list = listeners[message]
	if not list then return end
	for i = 1, #list do
		list[i](...)
	end
end

--------------------------------------------------------------------------------
-- Saved variables
--------------------------------------------------------------------------------

local defaults = {
	activeProfile = "Default",
	profiles = {},
	ui = {
		point = "CENTER",
		relPoint = "CENTER",
		x = 0,
		-- Clear of the editor window, which is centred and much taller.
		y = -250,
		scale = 1.0,
		locked = false,
		hidden = false,
		hideOutOfGroup = false,
	},
	alert = {
		sound = true,
		flash = true,
	},
	selfReport = true,
	-- Which marker each character personally marks, keyed by character. A squad
	-- can cover more than one, so this is a choice rather than something we can
	-- derive.
	macroMarker = {},
}

local function CopyDefaults(src, dst)
	if type(dst) ~= "table" then
		dst = {}
	end
	for key, value in pairs(src) do
		if type(value) == "table" then
			dst[key] = CopyDefaults(value, dst[key])
		elseif dst[key] == nil then
			dst[key] = value
		end
	end
	return dst
end

ns:RegisterEvent("ADDON_LOADED", function(_, loadedAddon)
	if loadedAddon ~= addonName then return end

	KickBatonDB = CopyDefaults(defaults, KickBatonDB)
	ns.db = KickBatonDB

	for i = 1, #ns.modules do
		local module = ns.modules[i]
		if module.OnInitialize then
			module:OnInitialize()
		end
	end
	ns.initialized = true
end)

ns:RegisterEvent("PLAYER_LOGIN", function()
	for i = 1, #ns.modules do
		local module = ns.modules[i]
		if module.OnEnable then
			module:OnEnable()
		end
	end
	ns:Print(L["ADDON_LOADED_HINT"])
end)

--------------------------------------------------------------------------------
-- Slash commands
--------------------------------------------------------------------------------

local function PrintHelp()
	ns:Print(L["CMD_HELP_HEADER"])
	local frame = DEFAULT_CHAT_FRAME or ChatFrame1
	if not frame then return end
	for _, key in ipairs({
		"CMD_HELP_CONFIG", "CMD_HELP_PUSH", "CMD_HELP_SHOW", "CMD_HELP_LOCK",
		"CMD_HELP_RESET", "CMD_HELP_SCALE", "CMD_HELP_ADVANCE", "CMD_HELP_PROFILE",
		"CMD_HELP_PROFILE_DELETE", "CMD_HELP_EXPORT", "CMD_HELP_MACRO",
		"CMD_HELP_STATUS",
	}) do
		frame:AddMessage("  |cffaaaaaa" .. L[key] .. "|r")
	end
end

SLASH_KICKBATON1 = "/kickbaton"
SLASH_KICKBATON2 = "/kbt"

SlashCmdList["KICKBATON"] = function(input)
	input = (input or ""):gsub("^%s+", ""):gsub("%s+$", "")
	local command, argument = input:match("^(%S*)%s*(.-)$")
	command = (command or ""):lower()

	if command == "" then
		if ns.Config then ns.Config:Toggle() end
	elseif command == "help" then
		PrintHelp()
	elseif command == "push" then
		if ns.Comm then ns.Comm:PushSquads() end
	elseif command == "show" then
		if ns.Board then ns.Board:SetHidden(false) end
	elseif command == "hide" then
		if ns.Board then ns.Board:SetHidden(true) end
	elseif command == "lock" then
		if ns.Board then ns.Board:SetLocked(true) end
	elseif command == "unlock" then
		if ns.Board then ns.Board:SetLocked(false) end
	elseif command == "reset" then
		if ns.Board then ns.Board:ResetPosition() end
	elseif command == "scale" then
		local value = tonumber(argument)
		if value and value >= 0.5 and value <= 3.0 then
			ns.Board:SetScale(value)
			ns:Print(L["BOARD_SCALE_SET"], value)
		else
			ns:Print(L["BOARD_SCALE_HELP"], ns.db.ui.scale or 1)
		end
	elseif command == "next" then
		if ns.Rotation then ns.Rotation:AdvanceManual() end
	elseif command == "macro" then
		if ns.MacroUI then ns.MacroUI:Toggle() end
	elseif command == "export" then
		if ns.TransferUI then ns.TransferUI:Show("export") end
	elseif command == "import" then
		if ns.TransferUI then ns.TransferUI:Show("import") end
	elseif command == "profile" then
		local subcommand, name = argument:match("^(%S*)%s*(.-)$")
		if subcommand:lower() == "delete" and name ~= "" then
			if not ns.Profiles:Exists(name) then
				ns:Print(L["PROFILE_DELETE_MISSING"], name)
			elseif name == ns.Profiles:CurrentName() then
				ns:Print(L["PROFILE_DELETE_ACTIVE"])
			elseif ns.Profiles:Delete(name) then
				ns:Print(L["PROFILE_DELETED"], name)
			end
		elseif argument ~= "" then
			-- Pass the whole argument, not just the first word: profile names
			-- are allowed to contain spaces.
			ns.Profiles:Switch(argument)
		else
			ns:Print("%s: %s", L["CONFIG_PROFILE"], ns.db.activeProfile)
		end
	elseif command == "status" then
		if ns.Status then ns.Status() end
	else
		ns:Print(L["CMD_UNKNOWN"], command)
	end
end

--------------------------------------------------------------------------------
-- Globals needed by Bindings.xml and the addon compartment
--------------------------------------------------------------------------------

-- Bindings.xml refers to both a header and a category; each needs its own
-- global or the keybinding panel files these under a raw token.
BINDING_HEADER_KICKBATON = L["BINDING_HEADER"]
BINDING_CATEGORY_KICKBATON = L["BINDING_HEADER"]
BINDING_NAME_KICKBATON_ADVANCE = L["BINDING_ADVANCE"]
BINDING_NAME_KICKBATON_CONFIG = L["BINDING_CONFIG"]
BINDING_NAME_KICKBATON_TOGGLE = L["BINDING_TOGGLE"]

function KickBaton_AdvanceTurn()
	if ns.Rotation then ns.Rotation:AdvanceManual() end
end

function KickBaton_ToggleConfig()
	if ns.Config then ns.Config:Toggle() end
end

function KickBaton_ToggleBoard()
	if ns.Board then ns.Board:SetHidden(not ns.db.ui.hidden) end
end

function KickBaton_OnCompartmentClick()
	if ns.Config then ns.Config:Toggle() end
end
