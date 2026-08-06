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
    -- Arrondi à la grille de l'écran : c'est lui qui garantit qu'un filet d'un
    -- pixel en fasse un (voir `T.SetPixelHeight`).
    "PixelUtil",

    -- Espaces de noms
    "C_AddOns", "C_Timer", "C_Texture", "C_XMLUtil", "C_QuestLog", "C_GossipInfo",
    "C_CVar", "C_AuctionHouse", "C_CurrencyInfo", "C_NamePlate", "Enum",
    "C_Item", "C_TooltipInfo", "TooltipUtil", "ItemLocation",

    -- Minicarte, curseur et écran. Les deux porteurs de boutons autour de la
    -- minicarte sont cités parce qu'on teste leur présence : le client a déplacé
    -- les siens d'une extension à l'autre.
    "Minimap", "MinimapBackdrop", "MinimapCluster",
    "GetCursorPosition", "IsMouseButtonDown",
    "GetScreenWidth", "GetScreenHeight",

    -- Jouets, objets et sorts du menu de téléportation. `C_ChallengeMode` donne
    -- la rotation de donjons de la saison en cours, et la téléportation de
    -- chacun quand le client la publie.
    "C_ToyBox", "PlayerHasToy", "C_Spell", "GetSpellInfo",
    "IsSpellKnown", "IsPlayerSpell", "C_ChallengeMode",
    -- Le grimoire : c'est là que se trouvent les téléportations de donjon hors
    -- saison, que le client ne publie nulle part ailleurs. Elles y sont rangées
    -- par extension dans des **tiroirs**, d'où les deux fonctions de flyout —
    -- citées sous leur ancien nom, qui sert de repli.
    "C_SpellBook", "GetFlyoutInfo", "GetFlyoutSlotInfo",

    -- Macro qui ouvre le menu depuis une barre d'action, et cadre survolé au
    -- moment du clic — c'est lui qui dit où poser le menu.
    "CreateMacro", "EditMacro", "GetMacroIndexByName",
    "GetMouseFoci", "GetMouseFocus", "WorldFrame",
    -- Le client publie ses extensions dans l'ordre, sous `EXPANSION_NAME0`,
    -- `EXPANSION_NAME1`… : c'est ce qui date un tiroir sans le nommer.
    "GetNumExpansions",

    -- Vente de la camelote et confirmation de destruction
    "C_MerchantFrame", "DELETE_ITEM_CONFIRM_STRING", "STATICPOPUP_NUMDIALOGS",

    -- Réglages du client
    "GetCVar", "SetCVar",

    -- Équipement du personnage. `GetItemStats` et `GetItemGem` ont migré dans
    -- `C_Item` ; les globales existent encore et servent de repli.
    "GetInventoryItemLink", "GetInventorySlotInfo", "GetItemStats", "GetItemGem",
    "GetDetailedItemLevelInfo", "GetItemIcon", "GetAverageItemLevel",
    -- Temps de recharge d'un objet — donc aussi d'un jouet. La fonction a migré
    -- dans `C_Item` ; la globale sert de repli, comme partout ailleurs.
    "GetItemCooldown",

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
    "CharacterFrame", "InspectFrame",
    -- Le grimoire actuel, chargé à la demande : absent tant que le joueur ne
    -- l'a pas ouvert, ce qui est exactement le test de capacité voulu.
    "PlayerSpellsFrame",
    -- Cinématiques. Trois choses distinctes s'y cachent et ne s'arrêtent pas
    -- pareil : le film, la vraie cinématique et la **scène en jeu**, dont
    -- l'annulation est conditionnée à un geste matériel (voir
    -- `dev/docs/API_NOTES.md`). D'où quatre fonctions et deux cadres.
    "CinematicFrame_CancelCinematic", "GameMovieFinished",
    "CinematicFrame", "MovieFrame", "StopCinematic", "CanCancelScene", "CancelScene",
    "TalkingHeadFrame", "TalkingHeadFrame_CloseImmediately",

    -- Chat
    "NUM_CHAT_WINDOWS", "ChatTypeInfo", "ChangeChatColor",
    "FCF_SavePositionAndDimensions", "GENERAL_CHAT_DOCK",

    -- Divers moteur
    "GetLocale", "GetTime", "GetBuildInfo", "InCombatLockdown",
    "IsShiftKeyDown", "IsControlKeyDown", "IsAltKeyDown", "IsModifierKeyDown",
    "IsInInstance",
    "hooksecurefunc", "geterrorhandler", "CallErrorHandler", "securecallfunction", "issecretvalue",
    "debugstack", "issecurevariable",

    -- Cadres d'unités
    "TargetFrameToT", "FocusFrameToT", "PartyFrame",
    "UnitFrameHealthBar_Update", "UnitFramePortrait_Update",
    -- `UnitFramePortrait_Update` est **coiffée, jamais appelée** : elle teste un
    -- booléen secret (`UnitIsUnit`) et lève dans le code du client dès qu'on
    -- l'appelle depuis chez nous. Les trois noms qui suivent sont ce avec quoi on
    -- refait son travail sans y entrer (voir `dev/docs/API_NOTES.md`).
    "UnitIsHumanPlayer", "GetClassAtlas", "SetPortraitTexture",
    "UnitExists", "UnitIsPlayer", "UnitIsUnit", "UnitClass", "UnitGUID",
    "RAID_CLASS_COLORS", "C_ClassColor",

    -- Barres d'infos. Les deux fonctions de cadre compact sont les deux passages
    -- obligés qu'on coiffe pour repeindre au moment où le client peint.
    --
    -- `NamePlateDriverFrame` ne figure **pas** ici, et c'est délibéré : on
    -- n'appelle pas le pilote de barres d'infos, sa mise en page manipule des
    -- valeurs secrètes qui ne survivent pas à un appel teinté (voir
    -- `dev/docs/API_NOTES.md`).
    -- Table des mesures que le client donne à ses barres d'infos : hauteur de
    -- barre, côté d'une aura, corps des polices. On les **lit** au lieu de les
    -- recopier — c'est la seule façon qu'un exemple reste fidèle après un patch.
    "NamePlateConstants",
    "CompactUnitFrame_UpdateHealthColor", "CompactUnitFrame_UpdateName",
    "UnitSelectionColor", "UnitClassification", "UnitLevel", "UnitEffectiveLevel",
    "UnitClassBase", "UnitIsBossMob", "UnitCanAttack", "UnitIsFriend",
    -- Ressource de classe. `PowerBarColor` est la table où le client range la
    -- teinte de chacune : on la lit plutôt que d'en recopier sept (règle 2).
    "UnitPower", "UnitPowerMax", "PowerBarColor",
    "UnitThreatSituation", "GetSpecializationRole",

    -- Sélecteur de couleur du client. On n'en écrit pas : il en a un, et il a
    -- changé d'interface — les deux chemins sont essayés (règle 1).
    "ColorPickerFrame",

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

    -- Groupe et raid
    "IsInGroup", "IsInRaid", "GetNumGroupMembers", "UnitName", "UnitIsConnected",
    "UnitIsGroupLeader", "UnitIsGroupAssistant", "SendChatMessage",
    "DoReadyCheck", "C_PartyInfo", "LE_PARTY_CATEGORY_INSTANCE",
    -- Le panneau de contrôle des cadres de raid : on teste sa présence avant de
    -- le ranger, comme les autres cadres du client.
    "CompactRaidFrameManager",

    -- Rangées d'auras du joueur : on y cherche le débuff d'interdiction de Furie
    -- sanguinaire pour le masquer, par tous les chemins que le client publie.
    "DebuffFrame", "BuffFrame",

    -- Validité d'un événement. Sert à ne pas s'abonner à un événement que le
    -- client a retiré, ce qu'il refuserait bruyamment.
    "C_EventUtils",

    -- Nombre de cadres de sacs. Une borne du client, avec repli écrit en dur.
    "NUM_CONTAINER_FRAMES",

    -- Fabrique d'objets de police. Le décompte des files est la seule police que
    -- l'addon construit, faute d'objet du client au corps qu'il faut.
    "CreateFont",

    -- Journal de combat. Les drapeaux disent à qui appartient une unité ; `bit`
    -- est la bibliothèque de manipulation de bits du client, absente du Lua 5.1
    -- standard sur lequel se base l'analyse.
    "CombatLogGetCurrentEventInfo", "bit",
    "COMBATLOG_OBJECT_TYPE_PLAYER", "COMBATLOG_OBJECT_AFFILIATION_MINE",
    "COMBATLOG_OBJECT_AFFILIATION_PARTY", "COMBATLOG_OBJECT_AFFILIATION_RAID",
    "LoggingCombat",

    -- Auras, charges de sort et enchantements d'arme
    "C_DurationUtil", "C_UnitAuras", "GetSpellCharges", "GetWeaponEnchantInfo",

    -- Clés mythiques et chrono de donjon. Le chrono affiché est celui du client :
    -- `ScenarioObjectiveTracker` est le module de son suivi d'objectifs qui porte le
    -- bloc, et `CHALLENGE_MODE_POWER_LEVEL` l'intitulé du niveau de clé. Les deux
    -- fonctions de chrono de zone ne servent qu'à **horodater** un boss qui tombe :
    -- le client dit qu'un critère est rempli, jamais quand il l'a été.
    "C_ChallengeMode", "C_MythicPlus", "NUM_BAG_SLOTS",
    "GetCursorInfo", "ClearCursor",
    "ScenarioObjectiveTracker", "CHALLENGE_MODE_POWER_LEVEL",
    "GetWorldElapsedTimers", "GetWorldElapsedTime",
    "C_Scenario", "C_ScenarioInfo",
    -- Style de tiret et jeu de teintes d'une ligne du suivi d'objectifs : les
    -- lignes d'exemple de l'aperçu passent par la fabrique de lignes du client, et
    -- doivent donc lui parler dans son vocabulaire.
    "OBJECTIVE_DASH_STYLE_HIDE", "OBJECTIVE_TRACKER_COLOR",

    -- Recherche de groupe
    "C_LFGList", "LFGListApplicationDialog", "CompleteLFGRoleCheck",
    "AcceptGroup", "StaticPopup_Hide", "C_SpellBook",
    -- Fenêtre de demande de rôles, du nom récent au plus ancien : c'est un test
    -- de capacité, les deux ne coexistent jamais.
    "LFGRoleCheckPopup", "LFDRoleCheckPopup",

    -- Instances
    "GetInstanceInfo",
}
