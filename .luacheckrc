-- =========================================================================
--  Configuration luacheck — Bshamel UI
--
--  Le client World of Warcraft expose son API sous forme de globals. Sans cette
--  liste, luacheck signale des centaines de faux positifs et devient inutile.
--
--  Règle d'entretien : n'ajouter un nom ici qu'au moment où on l'utilise
--  réellement. Une liste exhaustive copiée d'ailleurs masquerait les vraies
--  fautes de frappe sur des noms d'API.
-- =========================================================================

std = "lua51"
max_line_length = 120
codes = true

exclude_files = {
    ".release/",
}

ignore = {
    "212/self",   -- paramètre `self` non utilisé : normal sur une méthode
    "212/_.*",    -- paramètre volontairement ignoré, préfixé `_`
    "542",        -- bloc `if` vide : utilisé comme garde explicite
}

-- Globals que l'addon a le droit de définir.
globals = {
    "BshamelUI",
    "BshamelUIDB",
    "BshamelUICharDB",
    "BshamelUI_OnAddonCompartmentClick",
    "SLASH_BSHAMELUI1",
    "SLASH_BSHAMELUI2",
    "SlashCmdList",
    "StaticPopupDialogs",
    "UISpecialFrames",
}

-- API du client : lecture seule.
read_globals = {
    -- Lua étendu par le client
    "strjoin", "strtrim", "strlower", "strupper", "strsplit",
    "tostringall", "wipe", "tinsert", "tremove", "unpack", "select",
    "format", "date", "time",

    -- Frames et interface
    "CreateFrame", "UIParent", "GameTooltip", "GameFontNormal",
    "GameTooltip_SetTitle", "GameTooltip_AddNormalLine", "GameTooltip_AddErrorLine",
    "StaticPopup_Show", "HideUIPanel", "PlaySound", "SOUNDKIT",
    "CreateColor", "NORMAL_FONT_COLOR", "HIGHLIGHT_FONT_COLOR",
    "DISABLED_FONT_COLOR", "WHITE_FONT_COLOR", "RED_FONT_COLOR", "GREEN_FONT_COLOR",
    "SettingsPanel", "Settings", "Menu", "NineSliceUtil",

    -- Espaces de noms
    "C_AddOns", "C_Timer", "C_Texture", "C_XMLUtil", "C_QuestLog", "C_GossipInfo",

    -- Divers moteur
    "GetLocale", "GetTime", "GetBuildInfo", "InCombatLockdown",
    "IsShiftKeyDown", "IsControlKeyDown", "IsAltKeyDown", "IsModifierKeyDown",
    "hooksecurefunc", "geterrorhandler", "CallErrorHandler", "securecallfunction",
    "debugstack", "issecurevariable",

    -- API de quête
    "AcceptQuest", "ConfirmAcceptQuest", "CloseQuest", "CompleteQuest",
    "GetQuestReward", "GetQuestID", "QuestGetAutoAccept", "IsQuestCompletable",
    "GetNumQuestChoices", "GetNumActiveQuests", "GetNumAvailableQuests",
    "GetActiveTitle", "SelectActiveQuest", "SelectAvailableQuest",
    "IsActiveQuestTrivial", "IsAvailableQuestTrivial",
}
