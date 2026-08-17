-- Italian locale. Only the keys listed here are overwritten; anything missing
-- falls back to the English string from enUS.lua.
local _, ns = ...

if GetLocale() ~= "itIT" then return end

local L = ns.L

-- Chat / generale
L["ADDON_LOADED_HINT"]   = "caricato. Scrivi /kickbaton per aprire l'editor delle squadre."
L["CMD_UNKNOWN"]         = "Comando '%s' sconosciuto. Prova /kickbaton help."
L["CMD_HELP_HEADER"]     = "Comandi:"
L["CMD_HELP_CONFIG"]     = "/kickbaton - apre l'editor delle squadre"
L["CMD_HELP_PUSH"]       = "/kickbaton push - manda le squadre al gruppo (solo leader/assist)"
L["CMD_HELP_SHOW"]       = "/kickbaton show | hide - mostra o nasconde il tabellone"
L["CMD_HELP_LOCK"]       = "/kickbaton lock | unlock - blocca o sblocca il trascinamento"
L["CMD_HELP_RESET"]      = "/kickbaton reset - riporta il tabellone al centro"
L["CMD_HELP_SCALE"]      = "/kickbaton scale <0.5-3.0> - ridimensiona il tabellone"
L["BOARD_SCALE_SET"]     = "Scala del tabellone impostata a %.2f."
L["BOARD_SCALE_HELP"]    = "Uso: /kickbaton scale da 0.5 a 3.0 (adesso %.2f)."
L["CMD_HELP_ADVANCE"]    = "/kickbaton next - avanza a mano il turno della tua squadra"
L["CMD_HELP_PROFILE"]    = "/kickbaton profile <nome> - cambia profilo (lo crea se non esiste)"
L["CMD_HELP_PROFILE_DELETE"] = "/kickbaton profile delete <nome> - cancella un profilo che non stai usando"
L["CMD_HELP_EXPORT"]     = "/kickbaton export | import - condivide le squadre come stringa"
L["CMD_HELP_MACRO"]      = "/kickbaton macro - macro di focus e marker per il tuo simbolo"

-- Macro
L["MACRO_TITLE"]         = "KickBaton - Macro"
L["MACRO_BUTTON"]        = "Macro"
L["MACRO_YOUR_MARKER"]   = "Il tuo marker"
L["MACRO_SET_LABEL"]     = "Focus e marca"
L["MACRO_CLEAR_LABEL"]   = "Togli marker e focus"
L["MACRO_HINT"]          = "Clicca in un riquadro per selezionarlo, Ctrl+C, poi incolla in una macro nuova. In party possono marcare tutti; in raid servono lead o assist."
L["MACRO_MARKER_FROM_SQUAD"] = "Sto usando %s, il primo marker della tua squadra. Scegline un altro per cambiare."
L["MACRO_MARKER_CHOSEN"] = "Sto usando %s, scelto da te."
L["MACRO_USE_SQUAD"]     = "Segui la squadra"
L["CMD_HELP_STATUS"]     = "/kickbaton status - dice cosa l'addon riesce e non riesce a fare qui"

-- Export / import
L["TRANSFER_EXPORT"]     = "Esporta"
L["TRANSFER_IMPORT"]     = "Importa"
L["TRANSFER_IMPORT_BUTTON"] = "Importa"
L["TRANSFER_CLOSE"]      = "Chiudi"
L["TRANSFER_EXPORT_TITLE"] = "Esporta le squadre"
L["TRANSFER_IMPORT_TITLE"] = "Importa le squadre"
L["TRANSFER_EXPORT_HINT"] = "Ctrl+C per copiare. Il nome del profilo viaggia con la stringa, quindi l'import lo ricrea dall'altra parte."
L["TRANSFER_IMPORT_HINT"] = "Ctrl+V per incollare, poi Importa. Non cambia niente se la stringa non torna per intero."
L["TRANSFER_IMPORTED"]   = "Importate %d squadre nel profilo '%s'."
L["TRANSFER_ERR_EMPTY"]  = "Niente da importare - incolla prima una stringa."
L["TRANSFER_ERR_FORMAT"] = "Questa non sembra una stringa di KickBaton."
L["TRANSFER_ERR_VERSION"] = "Quella stringa usa il formato %s, che questa versione non capisce."
L["TRANSFER_ERR_TRUNCATED"] = "Stringa incompleta: dice %d squadre ma ne sono arrivate %d. Ricopiala."

-- Profili
L["PROFILE_DELETED"]     = "Profilo '%s' cancellato."
L["PROFILE_DELETE_ACTIVE"] = "Non puoi cancellare il profilo che stai usando. Passa prima a un altro."
L["PROFILE_DELETE_MISSING"] = "Il profilo '%s' non esiste."

-- Tabellone
L["BOARD_TITLE"]         = "KickBaton"
L["BOARD_EMPTY"]         = "Nessuna squadra - /kickbaton"
L["BOARD_UNLOCKED"]      = "Tabellone sbloccato - trascinalo dove vuoi."
L["BOARD_LOCKED"]        = "Tabellone bloccato."
L["BOARD_RESET"]         = "Tabellone riportato al centro dello schermo."

-- Finestra di configurazione
L["CONFIG_TITLE"]        = "KickBaton - Squadre"
L["CONFIG_INTRO"]        = "Una squadra copre uno o più marker e condivide un solo ordine di turno."
L["CONFIG_ADD_SQUAD"]    = "Nuova squadra"
L["CONFIG_DELETE_SQUAD"] = "Elimina squadra"
L["CONFIG_SQUAD_N"]      = "Squadra %d"
L["CONFIG_MEMBERS"]      = "Membri (in ordine di turno)"
L["CONFIG_ADD_MEMBER"]   = "Aggiungi"
L["CONFIG_ADD_FROM_GROUP"] = "Aggiungi dal gruppo"
L["CONFIG_MEMBER_PLACEHOLDER"] = "Nome del personaggio"
L["CONFIG_PUSH"]         = "Manda al gruppo"
L["CONFIG_PROFILE"]      = "Profilo"
L["CONFIG_MOVE_UP"]      = "Sposta su"
L["CONFIG_MOVE_DOWN"]    = "Sposta giù"
L["CONFIG_REMOVE"]       = "Rimuovi"
L["CONFIG_MARKER_TAKEN"] = "Già usato dalla squadra %d"
L["CONFIG_NO_SQUADS"]    = "Nessuna squadra. Creane una per iniziare."
L["CONFIG_NOBODY_TO_ADD"] = "Nessuno da aggiungere - tutti nel gruppo hanno già una squadra."

-- Validazione
L["ERR_MARKER_RANGE"]    = "Il marker deve essere tra 1 e 8."
L["ERR_MARKER_TAKEN"]    = "Il marker %s appartiene già alla squadra %d."
L["ERR_MEMBER_TAKEN"]    = "%s è già nella squadra %d. Un personaggio può stare in una sola squadra."
L["ERR_MEMBER_DUPLICATE"] = "%s è già in questa squadra."
L["ERR_NO_SQUAD"]        = "La squadra %s non esiste."
L["ERR_EMPTY_NAME"]      = "Scrivi prima il nome di un personaggio."

-- Comunicazione
L["COMM_PUSHED"]         = "Mandate %d squadre al gruppo."
L["COMM_RECEIVED"]       = "Squadre aggiornate da %s."
L["COMM_NOT_LEADER"]     = "Solo il leader o un assist possono mandare le squadre."
L["COMM_NO_GROUP"]       = "Non sei in gruppo."
L["COMM_TRUNCATED"]      = "Scartato un aggiornamento incompleto da %s."

-- Rotation
L["ROT_YOUR_TURN"]       = "Tocca a te"
L["ROT_ADVANCED"]        = "Turno passato a %s."
L["ROT_NOT_IN_SQUAD"]    = "Non sei in nessuna squadra, non c'è nessun turno da avanzare."

-- Stato
L["STATUS_HEADER"]       = "Stato:"
L["STATUS_SELFREPORT_ON"]  = "Rilevamento automatico dei kick: ATTIVO"
L["STATUS_SELFREPORT_OFF"] = "Rilevamento automatico dei kick: SPENTO (usa la keybind per avanzare a mano)"
L["STATUS_SPELLS"]       = "Sto osservando %d spell di interrupt per la tua spec."
L["STATUS_NO_SPELLS"]    = "Nessun interrupt noto per la tua classe/spec - solo modalità manuale."
L["STATUS_SQUAD"]        = "Sei nella squadra %d."
L["STATUS_NO_SQUAD"]     = "Non sei in nessuna squadra."
L["STATUS_BOARD_SHOWN"]  = "Tabellone: sullo schermo (/kickbaton reset se non lo trovi)"
L["STATUS_BOARD_EMPTY"]  = "Tabellone: nascosto perché non ci sono squadre configurate"
L["STATUS_BOARD_MANUAL"] = "Tabellone: nascosto da te (/kickbaton show)"
L["STATUS_BOARD_SOLO"]   = "Tabellone: nascosto perché non sei in gruppo"

-- Keybinding
L["BINDING_HEADER"]      = "KickBaton"
L["BINDING_ADVANCE"]     = "Avanza il turno della mia squadra"
L["BINDING_CONFIG"]      = "Apri l'editor delle squadre"
L["BINDING_TOGGLE"]      = "Mostra/nascondi il tabellone"

-- Pannello opzioni
L["OPT_TITLE"]           = "KickBaton"
L["OPT_SHOW_BOARD"]      = "Mostra il tabellone"
L["OPT_SHOW_BOARD_TIP"]  = "Spegne del tutto il tabellone. Resta comunque nascosto finché non ci sono squadre configurate."
L["CONFIG_SHOW_BOARD"]   = "Mostra tabellone"
L["CONFIG_HIDE_BOARD"]   = "Nascondi tabellone"
L["OPT_LOCK"]            = "Blocca il tabellone"
L["OPT_LOCK_TIP"]        = "Evita di trascinarlo per sbaglio durante una pull."
L["OPT_HIDE_SOLO"]       = "Nascondi il tabellone fuori dal gruppo"
L["OPT_SCALE"]           = "Scala del tabellone"
L["OPT_SOUND"]           = "Suono quando tocca a te"
L["OPT_FLASH"]           = "Lampeggio quando tocca a te"
L["OPT_SELFREPORT"]      = "Rileva automaticamente i miei kick"
L["OPT_SELFREPORT_TIP"]  = "Osserva solo i tuoi cast e lo comunica al gruppo. Spegnilo per avanzare il turno solo con la keybind."
L["OPT_OPEN_EDITOR"]     = "Apri l'editor delle squadre"
