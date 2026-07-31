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
--  Interface
-- =========================================================================

BUI:RegisterModule("ActionBars", {
    title    = L["Action bars"],
    category = "Interface",
    order    = 10,
    preview  = true,
    -- Les barres d'action sont des frames sécurisées : le jour où ce module
    -- aura du code, il devra déclarer `secure = true`.

    defaults = {},

    -- Le mode sombre des barres d'action est passé dans Général, avec le reste
    -- de l'interface : un même effet réglé à deux endroits finit par se
    -- contredire. La page reste annoncée, ses réglages propres viendront avec
    -- son code.
    options = {
        { type = "description", text = L["Dark mode moved"] },
    },
})

-- Le module Chat est écrit : il vit dans `Modules/Chat.lua`.

BUI:RegisterModule("Bags", {
    title    = L["Bags"],
    category = "Interface",
    order    = 40,
    preview  = true,

    defaults = {
        autoSellJunk    = false,
        fillDeleteInput = false,
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

        -- Le niveau d'objet sur l'équipement rangé n'est plus annoncé ici : il
        -- est écrit, et il vit dans **Fiche de personnage**, avec l'autre
        -- affichage du même nombre. Deux pages pour un seul geste de lecture
        -- obligeraient à le régler à deux endroits.
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

        -- Annoncer les morts était rangé dans Général tant que Général n'était
        -- qu'une maquette. C'est un outil de groupe : sa place est ici, avec le
        -- reste de ce qui parle au raid.
        announceDeaths   = false,
        deathSound       = false,
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

        { type = "header", text = L["Logging"] },
        {
            type    = "toggle",
            key     = "autoCombatLog",
            text    = L["Auto combat logging"],
            tooltip = L["Auto combat logging tip"],
        },
    },
})
