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
    "dev/",
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
    "strjoin", "strtrim", "strlower", "strupper", "strsplit", "strfind",
    "tostringall", "wipe", "tinsert", "tremove", "unpack", "select",
    "format", "date", "time",

    -- Frames et interface
    "CreateFrame", "UIParent", "GameTooltip", "GameFontNormal",
    "GameTooltip_SetTitle", "GameTooltip_AddNormalLine", "GameTooltip_AddErrorLine",
    "StaticPopup_Show", "HideUIPanel", "PlaySound", "SOUNDKIT",
    "CreateColor", "ITEM_QUALITY_COLORS", "NORMAL_FONT_COLOR", "HIGHLIGHT_FONT_COLOR",
    "DISABLED_FONT_COLOR", "WHITE_FONT_COLOR", "RED_FONT_COLOR", "GREEN_FONT_COLOR",
    "ORANGE_FONT_COLOR",
    "SettingsPanel", "Settings", "Menu", "NineSliceUtil",

    -- Espaces de noms
    "C_AddOns", "C_Timer", "C_Texture", "C_XMLUtil", "C_QuestLog", "C_GossipInfo",
    "C_CVar", "C_AuctionHouse", "C_CurrencyInfo", "C_NamePlate", "Enum",
    "C_Item", "C_TooltipInfo", "TooltipUtil", "ItemLocation",

    -- Minicarte, curseur et écran
    "Minimap", "GetCursorPosition", "IsMouseButtonDown",
    "GetScreenWidth", "GetScreenHeight",

    -- Réglages du client
    "GetCVar", "SetCVar",

    -- Équipement du personnage. `GetItemStats` et `GetItemGem` ont migré dans
    -- `C_Item` ; les globales existent encore et servent de repli.
    "GetInventoryItemLink", "GetInventorySlotInfo", "GetItemStats", "GetItemGem",
    "GetDetailedItemLevelInfo",

    -- Conteneurs (sacs, banque, banque de bataillon)
    "C_Container", "ContainerFrameCombinedBags", "BankFrame",
    "ToggleBackpack", "ToggleBag", "ToggleAllBags", "OpenAllBags",

    -- Marchands et réparation
    "CanMerchantRepair", "GetRepairAllCost", "CanGuildBankRepair", "RepairAllItems",
    "GetMoney", "GetCoinTextureString",

    -- Files d'attente
    "GetMaxBattlefieldID", "GetBattlefieldStatus", "GetBattlefieldPortExpiration",
    "LFGDungeonReadyPopup", "LFGDungeonReadyDialog", "PVPReadyDialog",

    -- Cadres du client dont on teste la présence avant de s'en servir : une
    -- globale absente vaut `nil`, ce qui est exactement le test de capacité
    -- voulu (CLAUDE.md règle 1).
    "GameMenuFrame", "AuctionHouseFrame", "TargetFrame", "FocusFrame", "PersonalFriendlyBuffFrame",
    "CharacterFrame",
    "CinematicFrame_CancelCinematic", "GameMovieFinished",
    "TalkingHeadFrame", "TalkingHeadFrame_CloseImmediately",

    -- Chat
    "NUM_CHAT_WINDOWS", "ChatTypeInfo", "ChangeChatColor",
    "FCF_SavePositionAndDimensions", "GENERAL_CHAT_DOCK",

    -- Divers moteur
    "GetLocale", "GetTime", "GetBuildInfo", "InCombatLockdown",
    "IsShiftKeyDown", "IsControlKeyDown", "IsAltKeyDown", "IsModifierKeyDown",
    "hooksecurefunc", "geterrorhandler", "CallErrorHandler", "securecallfunction", "issecretvalue",
    "debugstack", "issecurevariable",

    -- Cadres d'unités
    "TargetFrameToT", "FocusFrameToT", "PartyFrame",
    "UnitFrameHealthBar_Update", "UnitFramePortrait_Update",
    "UnitExists", "UnitIsPlayer", "UnitIsUnit", "UnitClass", "UnitGUID",
    "RAID_CLASS_COLORS", "C_ClassColor",

    -- Spécialisations. Le chemin `C_SpecializationInfo` est le récent, les
    -- globales sont celles qu'on essaie ensuite : on cite les deux parce qu'on
    -- teste les deux.
    "C_SpecializationInfo", "GetSpecialization", "GetSpecializationInfo",
    "GetSpecializationInfoByID",
    -- La spécialisation d'un autre joueur se lit dans son infobulle, par classe :
    -- voir `dev/docs/API_NOTES.md`.
    "GetNumSpecializationsForClassID", "GetSpecializationInfoForClassID",

    -- API de quête
    "AcceptQuest", "ConfirmAcceptQuest", "CloseQuest", "CompleteQuest",
    "GetQuestReward", "GetQuestID", "QuestGetAutoAccept", "IsQuestCompletable",
    "GetNumQuestChoices", "GetNumActiveQuests", "GetNumAvailableQuests",
    "GetActiveTitle", "SelectActiveQuest", "SelectAvailableQuest",
    "IsActiveQuestTrivial", "IsAvailableQuestTrivial",
}
