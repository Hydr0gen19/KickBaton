-- enUS is the base locale. Every string the addon shows lives here first;
-- other locales overwrite individual keys and leave the rest in English.
local _, ns = ...

local L = {}
ns.L = L

-- Chat / general
L["ADDON_LOADED_HINT"]   = "loaded. Type /kickbaton to open the squad editor."
L["CMD_UNKNOWN"]         = "Unknown command '%s'. Try /kickbaton help."
L["CMD_HELP_HEADER"]     = "Commands:"
L["CMD_HELP_CONFIG"]     = "/kickbaton - open the squad editor"
L["CMD_HELP_PUSH"]       = "/kickbaton push - send squads to the group (leader/assist only)"
L["CMD_HELP_SHOW"]       = "/kickbaton show | hide - toggle the board"
L["CMD_HELP_LOCK"]       = "/kickbaton lock | unlock - stop or allow dragging the board"
L["CMD_HELP_RESET"]      = "/kickbaton reset - move the board back to the centre"
L["CMD_HELP_SCALE"]      = "/kickbaton scale <0.5-3.0> - resize the board"
L["BOARD_SCALE_SET"]     = "Board scale set to %.2f."
L["BOARD_SCALE_HELP"]    = "Usage: /kickbaton scale 0.5 to 3.0 (currently %.2f)."
L["CMD_HELP_ADVANCE"]    = "/kickbaton next - advance your squad's turn manually"
L["CMD_HELP_PROFILE"]    = "/kickbaton profile <name> - switch profile (creates it if new)"
L["CMD_HELP_PROFILE_DELETE"] = "/kickbaton profile delete <name> - delete a profile you are not using"
L["CMD_HELP_EXPORT"]     = "/kickbaton export | import - share squads as a string"
L["CMD_HELP_MACRO"]      = "/kickbaton macro - focus and marking macros for your marker"

-- Macros
L["MACRO_TITLE"]         = "KickBaton - Macros"
L["MACRO_BUTTON"]        = "Macros"
L["MACRO_YOUR_MARKER"]   = "Your marker"
L["MACRO_SET_LABEL"]     = "Focus and mark"
L["MACRO_CLEAR_LABEL"]   = "Clear mark and focus"
L["MACRO_HINT"]          = "Click a box to select it, Ctrl+C, then paste into a new macro. Marking works for anyone in a party; in a raid it needs lead or assist."
L["MACRO_MARKER_FROM_SQUAD"] = "Using %s, the first marker of your squad. Pick another to override."
L["MACRO_MARKER_CHOSEN"] = "Using %s, chosen by you."
L["MACRO_USE_SQUAD"]     = "Follow my squad"
L["CMD_HELP_STATUS"]     = "/kickbaton status - report what the addon can and cannot do here"

-- Export / import
L["TRANSFER_EXPORT"]     = "Export"
L["TRANSFER_IMPORT"]     = "Import"
L["TRANSFER_IMPORT_BUTTON"] = "Import"
L["TRANSFER_CLOSE"]      = "Close"
L["TRANSFER_EXPORT_TITLE"] = "Export squads"
L["TRANSFER_IMPORT_TITLE"] = "Import squads"
L["TRANSFER_EXPORT_HINT"] = "Ctrl+C to copy. The profile name travels with it, so importing recreates it on the other side."
L["TRANSFER_IMPORT_HINT"] = "Ctrl+V to paste, then Import. Nothing changes unless the whole string checks out."
L["TRANSFER_IMPORTED"]   = "Imported %d squad(s) into profile '%s'."
L["TRANSFER_ERR_EMPTY"]  = "Nothing to import - paste a string first."
L["TRANSFER_ERR_FORMAT"] = "That does not look like a KickBaton string."
L["TRANSFER_ERR_VERSION"] = "That string uses format %s, which this version does not understand."
L["TRANSFER_ERR_TRUNCATED"] = "That string is incomplete: it says %d squads but only %d arrived. Copy it again."

-- Profiles
L["PROFILE_DELETED"]     = "Profile '%s' deleted."
L["PROFILE_DELETE_ACTIVE"] = "You cannot delete the profile you are using. Switch to another one first."
L["PROFILE_DELETE_MISSING"] = "Profile '%s' does not exist."

-- Board
L["BOARD_TITLE"]         = "KickBaton"
L["BOARD_EMPTY"]         = "No squads yet - /kickbaton"
L["BOARD_UNLOCKED"]      = "Board unlocked - drag to move it."
L["BOARD_LOCKED"]        = "Board locked."
L["BOARD_RESET"]         = "Board moved back to the centre of the screen."

-- Config window
L["CONFIG_TITLE"]        = "KickBaton - Squads"
L["CONFIG_INTRO"]        = "A squad covers one or more markers and shares a single turn order."
L["CONFIG_ADD_SQUAD"]    = "New squad"
L["CONFIG_DELETE_SQUAD"] = "Delete squad"
L["CONFIG_SQUAD_N"]      = "Squad %d"
L["CONFIG_MEMBERS"]      = "Members (in turn order)"
L["CONFIG_ADD_MEMBER"]   = "Add"
L["CONFIG_ADD_FROM_GROUP"] = "Add from group"
L["CONFIG_MEMBER_PLACEHOLDER"] = "Character name"
L["CONFIG_PUSH"]         = "Push to group"
L["CONFIG_PROFILE"]      = "Profile"
L["CONFIG_MOVE_UP"]      = "Move up"
L["CONFIG_MOVE_DOWN"]    = "Move down"
L["CONFIG_REMOVE"]       = "Remove"
L["CONFIG_MARKER_TAKEN"] = "Already used by squad %d"
L["CONFIG_NO_SQUADS"]    = "No squads yet. Create one to get started."
L["CONFIG_NOBODY_TO_ADD"] = "Nobody left to add - everyone in the group already has a squad."

-- Validation
L["ERR_MARKER_RANGE"]    = "Marker must be between 1 and 8."
L["ERR_MARKER_TAKEN"]    = "Marker %s already belongs to squad %d."
L["ERR_MEMBER_TAKEN"]    = "%s is already in squad %d. A character can only be in one squad."
L["ERR_MEMBER_DUPLICATE"] = "%s is already in this squad."
L["ERR_NO_SQUAD"]        = "Squad %s does not exist."
L["ERR_EMPTY_NAME"]      = "Enter a character name first."

-- Comm
L["COMM_PUSHED"]         = "Sent %d squad(s) to the group."
L["COMM_RECEIVED"]       = "Squads updated by %s."
L["COMM_NOT_LEADER"]     = "Only the party leader or an assist can push squads."
L["COMM_NO_GROUP"]       = "You are not in a group."
L["COMM_TRUNCATED"]      = "Discarded an incomplete squad update from %s."
L["COMM_BLOCKED"]        = "The game is blocking addon messages right now, so turns are not syncing between you. This is a Midnight restriction during active keys, not a fault in the addon - the board still shows your squads and their order."
L["COMM_SEND_FAILED"]    = "Could not send to the group (%s)."
L["BOARD_NO_SYNC"]       = "not syncing"

-- Rotation
L["ROT_YOUR_TURN"]       = "Your turn"
L["ROT_ADVANCED"]        = "Turn advanced to %s."
L["ROT_NOT_IN_SQUAD"]    = "You are not in any squad, so there is no turn to advance."

-- Status report
L["STATUS_HEADER"]       = "Status:"
L["STATUS_SELFREPORT_ON"]  = "Automatic kick detection: ON"
L["STATUS_SELFREPORT_OFF"] = "Automatic kick detection: OFF (use the keybind to advance manually)"
L["STATUS_SPELLS"]       = "Watching %d interrupt spell(s) for your spec."
L["STATUS_NO_SPELLS"]    = "No known interrupt for your class/spec - manual mode only."
L["STATUS_SQUAD"]        = "You are in squad %d."
L["STATUS_NO_SQUAD"]     = "You are not in any squad."
L["STATUS_BOARD_SHOWN"]  = "Board: on screen (/kickbaton reset if you cannot find it)"
L["STATUS_BOARD_EMPTY"]  = "Board: hidden because no squads are configured"
L["STATUS_BOARD_MANUAL"] = "Board: hidden by you (/kickbaton show)"
L["STATUS_BOARD_SOLO"]   = "Board: hidden because you are not in a group"
L["STATUS_CHAT_BLOCKED"] = "Addon messages: BLOCKED by the game right now, so turns will not sync"
L["STATUS_CHAT_OK"]      = "Addon messages: allowed"
L["STATUS_CHAT_UNKNOWN"] = "Addon messages: this client cannot say (older API)"
L["STATUS_KEYSTONE"]     = "You are in an active keystone, which is when the game applies that restriction."

-- Keybindings
L["BINDING_HEADER"]      = "KickBaton"
L["BINDING_ADVANCE"]     = "Advance my squad's turn"
L["BINDING_CONFIG"]      = "Open the squad editor"
L["BINDING_TOGGLE"]      = "Show/hide the board"

-- Options panel
L["OPT_TITLE"]           = "KickBaton"
L["OPT_SHOW_BOARD"]      = "Show the board"
L["OPT_SHOW_BOARD_TIP"]  = "Turns the board off entirely. It stays hidden anyway while no squads are configured."
L["CONFIG_SHOW_BOARD"]   = "Show board"
L["CONFIG_HIDE_BOARD"]   = "Hide board"
L["OPT_LOCK"]            = "Lock the board in place"
L["OPT_LOCK_TIP"]        = "Stops the board being dragged by accident during a pull."
L["OPT_HIDE_SOLO"]       = "Hide the board when not in a group"
L["OPT_SCALE"]           = "Board scale"
L["OPT_SOUND"]           = "Play a sound when it is your turn"
L["OPT_FLASH"]           = "Flash the board when it is your turn"
L["OPT_SELFREPORT"]      = "Detect my own kicks automatically"
L["OPT_SELFREPORT_TIP"]  = "Watches only your own casts and tells the group. Turn this off to advance the turn purely by keybind."
L["OPT_OPEN_EDITOR"]     = "Open the squad editor"
