-- =========================================================================
--  Bshamel UI — Locales/enUS.lua
--  Locale de base. Toute clé utilisée dans le code doit exister ici.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI

BUI:RegisterLocale("enUS", {
    -- Fenêtre d'options
    ["Bshamel UI"]              = "Bshamel UI",
    ["General"]                 = "General",
    ["QoL"]                     = "QoL",
    ["Mythic+ / Raid"]          = "Mythic+ / Raid",
    ["Search..."]               = "Search...",
    ["Enable this module"]      = "Enable this module",
    ["Reset this page"]         = "Reset this page",
    ["Reset page confirm"]      = "Reset every setting on this page to its default value?",
    ["Yes"]                     = "Yes",
    ["Cancel"]                  = "Cancel",
    ["Open Bshamel UI"]         = "Open Bshamel UI",
    ["Cannot open in combat"]   = "The options window cannot be opened during combat.",
    ["Module disabled tooltip"] = "This module is disabled.",
    ["Version"]                 = "Version",

    -- Module Quest
    ["Quest"]                   = "Quest",
    ["Automation"]              = "Automation",
    ["Auto-accept quests"]      = "Auto-accept quests",
    ["Auto-accept quests tip"]  = "Automatically accepts quests offered by NPCs and quest items.",
    ["Auto-turn-in quests"]     = "Auto-turn-in quests",
    ["Auto-turn-in quests tip"] = "Automatically completes quests and takes the reward when there is only one.",
    ["Filters"]                 = "Filters",
    ["Skip trivial quests"]     = "Skip low-level quests",
    ["Skip trivial quests tip"] = "Leave grey (trivial) quests alone.",
    ["Bypass modifier"]         = "Hold to bypass",
    ["Bypass modifier tip"]     = "Hold this key to temporarily suspend the automation.",
    ["None"]                    = "None",
    ["Shift"]                   = "Shift",
    ["Ctrl"]                    = "Ctrl",
    ["Alt"]                     = "Alt",
})
