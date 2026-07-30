-- =========================================================================
--  Bshamel UI — Modules/Upcoming.lua
--  Modules annoncés, pas encore écrits.
--
--  Chacun déclare `preview = true` : il occupe sa place dans la navigation et
--  montre les réglages qu'il proposera, mais le core refuse de l'allumer et le
--  moteur de pages grise la page jusqu'à son interrupteur. Aucun `OnEnable`,
--  donc aucun comportement — c'est une maquette qui vit dans l'interface réelle
--  plutôt que dans un document qui divergerait du code au premier commit.
--
--  Un fichier unique et non sept fichiers presque vides : ce n'est pas la forme
--  définitive du code, c'est un échafaudage. Quand un module est écrit, il part
--  dans son propre fichier avec son `OnEnable`, et sa déclaration disparaît
--  d'ici. Le nom (`"Bags"`, `"Chat"`…) est déjà la clé de base de données
--  définitive : c'est la seule chose qu'on ne pourra plus changer, elle est donc
--  choisie maintenant.
--
--  Les libellés et les clés de réglage décrivent une intention, pas une
--  implémentation. Écrire le module reste le moment de vérifier que l'API du
--  client permet ce qui est promis ici.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local L   = ns.L

-- =========================================================================
--  Jeu
-- =========================================================================

BUI:RegisterModule("General", {
    title    = L["General"],
    category = "Game",
    order    = 10,
    preview  = true,

    defaults = {
        autoRepair       = false,
        auctionCurrentXP = false,
        announceDeaths   = false,
        deathSound       = false,
        skipCinematics   = false,
        hideTalkingHead  = false,
        hideLuaErrors    = false,
    },

    options = {
        { type = "header", text = L["Automation"] },
        {
            type    = "toggle",
            key     = "autoRepair",
            text    = L["Auto-repair"],
            tooltip = L["Auto-repair tip"],
        },
        {
            type    = "toggle",
            key     = "auctionCurrentXP",
            text    = L["Auction current expansion"],
            tooltip = L["Auction current expansion tip"],
        },

        { type = "header", text = L["Announcements"] },
        {
            type    = "toggle",
            key     = "announceDeaths",
            text    = L["Announce group deaths"],
            tooltip = L["Announce group deaths tip"],
        },
        {
            type    = "toggle",
            key     = "deathSound",
            text    = L["Death sound alert"],
            tooltip = L["Death sound alert tip"],
        },

        { type = "header", text = L["Annoyances"] },
        {
            type    = "toggle",
            key     = "skipCinematics",
            text    = L["Skip cinematics"],
            tooltip = L["Skip cinematics tip"],
        },
        {
            type    = "toggle",
            key     = "hideTalkingHead",
            text    = L["Hide talking heads"],
            tooltip = L["Hide talking heads tip"],
        },
        {
            type    = "toggle",
            key     = "hideLuaErrors",
            text    = L["Hide Lua errors"],
            tooltip = L["Hide Lua errors tip"],
        },
    },
})

BUI:RegisterModule("Character", {
    title    = L["Character sheet"],
    category = "Game",
    order    = 20,
    preview  = true,

    defaults = {
        showUpgradeLevel = false,
        showEnchants     = false,
        showGems         = false,
        showVoidCore     = false,
    },

    options = {
        { type = "header", text = L["Item details"] },
        {
            type    = "toggle",
            key     = "showUpgradeLevel",
            text    = L["Show upgrade level"],
            tooltip = L["Show upgrade level tip"],
        },
        {
            type    = "toggle",
            key     = "showEnchants",
            text    = L["Show enchants"],
            tooltip = L["Show enchants tip"],
        },
        {
            type    = "toggle",
            key     = "showGems",
            text    = L["Show gems"],
            tooltip = L["Show gems tip"],
        },
        {
            type    = "toggle",
            key     = "showVoidCore",
            text    = L["Show void core"],
            tooltip = L["Show void core tip"],
        },
    },
})

-- =========================================================================
--  Interface
-- =========================================================================

BUI:RegisterModule("ActionBars", {
    title    = L["Action bars"],
    category = "Interface",
    order    = 10,
    preview  = true,
    -- Les barres d'action sont des frames sécurisées : le jour où ce module
    -- aura du code, il devra déclarer `secure = true`.

    defaults = {
        darkMode = false,
    },

    options = {
        { type = "header", text = L["Appearance"] },
        {
            type    = "toggle",
            key     = "darkMode",
            text    = L["Dark mode"],
            tooltip = L["Dark mode tip"],
        },
    },
})

BUI:RegisterModule("UnitFrames", {
    title    = L["Unit frames"],
    category = "Interface",
    order    = 20,
    preview  = true,
    -- Idem : frames sécurisées.

    defaults = {
        classColorHealth = false,
        darkMode         = false,
    },

    options = {
        { type = "header", text = L["Appearance"] },
        {
            type    = "toggle",
            key     = "classColorHealth",
            text    = L["Class-colored health"],
            tooltip = L["Class-colored health tip"],
        },
        {
            type    = "toggle",
            key     = "darkMode",
            text    = L["Dark mode"],
            tooltip = L["Dark mode tip"],
        },
    },
})

BUI:RegisterModule("Chat", {
    title    = L["Chat"],
    category = "Interface",
    order    = 30,
    preview  = true,

    defaults = {
        keepHistory  = false,
        dragToResize = false,
    },

    options = {
        { type = "header", text = L["History"] },
        {
            type    = "toggle",
            key     = "keepHistory",
            text    = L["Keep history"],
            tooltip = L["Keep history tip"],
        },

        { type = "header", text = L["Appearance"] },
        {
            type    = "toggle",
            key     = "dragToResize",
            text    = L["Drag to resize"],
            tooltip = L["Drag to resize tip"],
        },
    },
})

BUI:RegisterModule("Bags", {
    title    = L["Bags"],
    category = "Interface",
    order    = 40,
    preview  = true,

    defaults = {
        autoSellJunk    = false,
        fillDeleteInput = false,
        showItemLevel   = false,
    },

    options = {
        { type = "header", text = L["Merchants"] },
        {
            type    = "toggle",
            key     = "autoSellJunk",
            text    = L["Auto-sell junk"],
            tooltip = L["Auto-sell junk tip"],
        },

        { type = "header", text = L["Confirmations"] },
        {
            type    = "toggle",
            key     = "fillDeleteInput",
            text    = L["Fill delete confirmation"],
            tooltip = L["Fill delete confirmation tip"],
        },

        { type = "header", text = L["Display"] },
        {
            type    = "toggle",
            key     = "showItemLevel",
            text    = L["Show item level"],
            tooltip = L["Show item level tip"],
        },
    },
})

-- =========================================================================
--  Mythique+ / Raid
-- =========================================================================

BUI:RegisterModule("Keystones", {
    title    = L["Keystones"],
    category = "MythicRaid",
    order    = 10,
    preview  = true,

    defaults = {
        answerKeysRequest = false,
    },

    options = {
        { type = "header", text = L["Automation"] },
        {
            type    = "toggle",
            key     = "answerKeysRequest",
            text    = L["Answer keys request"],
            tooltip = L["Answer keys request tip"],
        },
    },
})

BUI:RegisterModule("RaidTools", {
    title    = L["Raid tools"],
    category = "MythicRaid",
    order    = 20,
    preview  = true,

    defaults = {
        battleResTracker = false,
        readyCheckBuffs  = false,
        worldMarkers     = false,
        autoCombatLog    = false,
    },

    options = {
        { type = "header", text = L["Combat"] },
        {
            type    = "toggle",
            key     = "battleResTracker",
            text    = L["Battle res tracker"],
            tooltip = L["Battle res tracker tip"],
        },
        {
            type    = "toggle",
            key     = "readyCheckBuffs",
            text    = L["Ready check buffs"],
            tooltip = L["Ready check buffs tip"],
        },
        {
            type    = "toggle",
            key     = "worldMarkers",
            text    = L["World markers"],
            tooltip = L["World markers tip"],
        },

        { type = "header", text = L["Logging"] },
        {
            type    = "toggle",
            key     = "autoCombatLog",
            text    = L["Auto combat logging"],
            tooltip = L["Auto combat logging tip"],
        },
    },
})
