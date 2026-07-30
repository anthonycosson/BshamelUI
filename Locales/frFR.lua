-- =========================================================================
--  Bshamel UI — Locales/frFR.lua
--  Une clé absente ici retombe sur enUS. Mettre `true` pour « identique à
--  l'anglais » plutôt que de recopier la chaîne.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI

BUI:RegisterLocale("frFR", {
    -- Fenêtre d'options
    ["Bshamel UI"]              = true,
    ["General"]                 = "Général",
    ["QoL"]                     = true,
    ["Mythic+ / Raid"]          = "Mythique+ / Raid",
    ["Search..."]               = "Rechercher...",
    ["Enable this module"]      = "Activer ce module",
    ["Reset this page"]         = "Réinitialiser cette page",
    ["Reset page confirm"]      = "Remettre tous les réglages de cette page à leur valeur par défaut ?",
    ["Yes"]                     = "Oui",
    ["Cancel"]                  = "Annuler",
    ["Open Bshamel UI"]         = "Ouvrir Bshamel UI",
    ["Cannot open in combat"]   = "La fenêtre d'options ne peut pas être ouverte en combat.",
    ["Module disabled tooltip"] = "Ce module est désactivé.",
    ["Version"]                 = true,

    -- Module Quest
    ["Quest"]                   = "Quête",
    ["Automation"]              = "Automatisation",
    ["Auto-accept quests"]      = "Accepter automatiquement les quêtes",
    ["Auto-accept quests tip"]  = "Accepte automatiquement les quêtes proposées par les PNJ et les objets de quête.",
    ["Auto-turn-in quests"]     = "Rendre automatiquement les quêtes",
    ["Auto-turn-in quests tip"] = "Termine la quête et prend la récompense automatiquement lorsqu'il n'y en a qu'une.",
    ["Filters"]                 = "Filtres",
    ["Skip trivial quests"]     = "Ignorer les quêtes de bas niveau",
    ["Skip trivial quests tip"] = "Ne touche pas aux quêtes grises (triviales).",
    ["Bypass modifier"]         = "Maintenir pour ignorer",
    ["Bypass modifier tip"]     = "Maintenez cette touche pour suspendre temporairement l'automatisation.",
    ["None"]                    = "Aucune",
    ["Shift"]                   = "Maj",
    ["Ctrl"]                    = true,
    ["Alt"]                     = true,
})
