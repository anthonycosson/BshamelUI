-- =========================================================================
--  Bshamel UI — Modules/Beta.lua
--  Les bugs de la bêta de *Forever* que l'addon rattrape en attendant que
--  Blizzard les corrige.
--
--  *Forever* seulement (sa ligne du `.toc` l'écarte de retail, voir
--  `CLAUDE.md` §1). Ce module n'ajoute **aucune** fonctionnalité : il ne
--  répare que ce que le client casse, et chaque correctif est destiné à
--  disparaître d'ici la sortie. C'est pour cela qu'ils vivent ensemble ici
--  plutôt que dispersés dans les modules qu'ils concernent : le jour où
--  Blizzard corrige, on retire une entrée, pas une couture.
--
--  **Ses cases sont cochées à la livraison** (`@default-on`), et c'est la
--  seconde exception de l'addon après le bouton de minicarte. Le motif est
--  écrit au-dessus de chacune : un correctif de plantage n'est pas un réglage
--  de confort. La promesse « installer l'addon ne change rien au jeu » vaut
--  pour ce que le jeu fait ; elle ne peut pas s'étendre à ce qu'il **rate** —
--  une fiche de personnage qui lève une erreur Lua à chaque survol n'est pas
--  un état qu'on protège. La case reste là pour qu'on puisse revenir en
--  arrière et constater le bug d'origine.
--
--  Réversibilité (règle 6) : chaque correctif défait exactement ce qu'il a
--  posé, et l'extinction rend le bug tel qu'il était.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local U    = BUI.Util
local L    = ns.L

local MODULE = "Beta"

-- =========================================================================
--  Infobulles des caractéristiques de la fiche de personnage
-- =========================================================================
-- **Le bug** (bêta 1.60.1, `Blizzard_UIPanels_Game/Camelot/PaperDollFrameStats.lua`) :
--
--     local classStatText = _G[strupper(classFileName).."_"..strupper(statName).."_".."TOOLTIP"]
--
-- `statName` est le nom **traduit** de la caractéristique (`SPELL_STAT1_NAME`,
-- « Force » en français). La clé cherchée devient donc `SHAMAN_FORCE_TOOLTIP`,
-- qui n'existe que sous sa forme anglaise, `SHAMAN_STRENGTH_TOOLTIP`. Le repli
-- `DEFAULT_FORCE_TOOLTIP` est absent pour la même raison, et le `string.format`
-- qui suit reçoit `nil` : erreur Lua à chaque ouverture de la fiche.
--
-- Le client anglais ne le voit pas ; tous les autres l'ont à chaque survol.
--
-- **Ce qu'on fait** : on pose les clés traduites qui manquent, en les faisant
-- pointer sur les textes anglais déjà chargés — dont la **valeur** est, elle,
-- bien traduite. Blizzard trouve alors sa chaîne, et l'infobulle s'affiche dans
-- la langue du joueur.
--
-- On n'écrit que des clés **absentes** : si le client se corrige, ou si une
-- autre langue a déjà la sienne, on ne touche à rien.
--
-- **Le prix, connu et accepté : une erreur Lua à l'ouverture de la fiche.**
-- Une globale écrite par un addon est teintée pour la session, définitivement.
-- Le client relit celle-ci à l'ouverture de la fiche — `SetStatTooltip2` est
-- appelée pendant `RefreshRightPane`, pas au survol — et la suite de son
-- `OnShow` hérite de la teinte. Quatre lignes plus loin, il affiche les points
-- de vie du joueur en chiffres, qui sont des valeurs secrètes, et lève
-- « attempt to compare a secret number value ».
--
-- **Il n'existe aucune version propre de ce correctif** : un addon ne peut pas
-- écrire une globale sans la teindre, et la clé manquante ne se fournit que
-- par une globale. Le choix est donc entre deux bugs, et il a été fait le
-- 20 septembre 2026 : garder les infobulles lisibles, masquer l'erreur. Ne pas
-- « réparer » ce compromis sans le rouvrir — le retirer ramène simplement
-- l'autre erreur.

--- Les cinq caractéristiques, par l'indice que le client leur donne, avec le
--- nom anglais que portent ses chaînes.
local STATS = {
    [1] = "STRENGTH",
    [2] = "AGILITY",
    [3] = "STAMINA",
    [4] = "INTELLECT",
    [5] = "SPIRIT",
}

--- Clés qu'on a posées, pour pouvoir les retirer : clé -> vrai.
local posted = {}

--- Les deux préfixes que le client essaie, dans l'ordre : la classe du
--- personnage, puis le repli commun.
---@return string[]
local function prefixes()
    local list = { "DEFAULT" }

    local _, class = UnitClass("player")
    if type(class) == "string" and not U.IsSecret(class) then
        list[#list + 1] = strupper(class)
    end
    return list
end

local function applyStatTooltips()
    for index, english in pairs(STATS) do
        -- Le nom traduit vient du client : c'est exactement celui que son code
        -- réutilisera pour composer la clé.
        local localized = _G["SPELL_STAT" .. index .. "_NAME"]

        if type(localized) == "string" and not U.IsSecret(localized) then
            for _, prefix in ipairs(prefixes()) do
                local key    = prefix .. "_" .. strupper(localized) .. "_TOOLTIP"
                local source = _G[prefix .. "_" .. english .. "_TOOLTIP"]

                if _G[key] == nil and type(source) == "string" then
                    _G[key] = source
                    posted[key] = true
                end
            end
        end
    end
end

--- Retire ce qu'on a posé : le bug redevient exactement ce qu'il était.
local function restoreStatTooltips()
    for key in pairs(posted) do
        _G[key] = nil
    end
    wipe(posted)
end

-- =========================================================================
--  Application d'ensemble
-- =========================================================================

---@param mod table
local function applyAll(mod)
    if mod:IsEnabled() and mod:Get("fixStatTooltips") then
        applyStatTooltips()
    else
        restoreStatTooltips()
    end
end

-- =========================================================================
--  Déclaration du module
-- =========================================================================

BUI:RegisterModule(MODULE, {
    title    = L["Beta fixes"],
    category = "Beta",
    order    = 90,

    defaults = {
        -- Sans ce correctif, ouvrir la fiche de personnage lève une erreur Lua
        -- sur tout client qui n'est pas anglais, et l'infobulle de la
        -- caractéristique ne s'affiche pas. Réparer un plantage du client n'est
        -- pas « changer le jeu » : c'est lui rendre ce qu'il annonce. Décocher
        -- la case redonne le bug, pour qui veut le constater.
        fixStatTooltips = true,  -- @default-on
    },

    options = {
        { type = "header", text = L["Client bugs"] },
        {
            type    = "toggle",
            key     = "fixStatTooltips",
            text    = L["Fix stat tooltips"],
            tooltip = L["Fix stat tooltips tip"],
        },
    },

    OnEnable = function(self)
        applyAll(self)

        -- Les chaînes du client sont là dès le chargement ; cet abonnement ne
        -- sert qu'au cas où la fiche s'ouvre avant nous (module différé hors
        -- combat, rechargement à chaud).
        self:RegisterEvent("PLAYER_ENTERING_WORLD", function() applyAll(self) end)
    end,

    OnDisable = restoreStatTooltips,

    OnSettingChanged = function(self)
        applyAll(self)
    end,
})
