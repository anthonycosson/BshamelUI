-- =========================================================================
--  Bshamel UI — Modules/CombatLog.lua
--  Lancer la journalisation de combat à la porte d'une instance.
--
--  La journalisation détaillée est une CVar : sans elle, le journal produit ne
--  porte ni positions ni ressources, et les sites d'analyse n'en tirent presque
--  rien. Elle est relevée avant d'être changée et reposée à l'extinction, comme
--  toutes les CVar de l'addon.
--
--  Le réglage vivait dans *Outils de raid*, qui en tenait quatre. Un palier de
--  migration (`Core/DB.lua`) déplace celui de ceux qui l'avaient changé.
--
--  Réversibilité (règle 6) : la journalisation s'arrête si c'est nous qui
--  l'avions allumée — et seulement dans ce cas —, et la CVar retrouve sa valeur.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local U    = BUI.Util
local L    = ns.L

local MODULE = "CombatLog"

local CVAR_ADVANCED = "advancedCombatLogging"

--- Avons-nous allumé la journalisation nous-mêmes ? On n'éteint que dans ce
--- cas : couper une journalisation lancée à la main serait défaire le geste de
--- quelqu'un d'autre.
local loggingStarted = false
local savedAdvanced

--- Avons-nous déjà signalé qu'une journalisation étrangère était en cours ? Les
--- événements de zone arrivent par deux ou trois à l'entrée d'un raid, et la même
--- remarque répétée trois fois se lit comme un bug.
local toldForeign = false

--- Type de l'instance courante, ou `nil` en extérieur.
---@return string|nil
local function instanceType()
    if not GetInstanceInfo then return nil end
    local _, kind = GetInstanceInfo()
    if kind == "none" then return nil end
    return kind
end

--- Applique l'état voulu, et **dit ce qu'il a fait**.
---
--- Le fichier de journal est destiné à être déposé sur un site d'analyse : ce
--- qui compte pour qui l'envoie n'est pas que la journalisation soit lancée,
--- c'est de le **savoir**. Chaque bascule laisse donc une ligne dans le chat.
---@param mod table
---@return boolean spoke  a-t-on écrit quelque chose ?
local function applyLogging(mod)
    -- **Le seuil est la porte de l'instance**, pas le départ de la clé. Une clé
    -- se pose après être entré, et souvent après un premier pack : tout ce qui
    -- précède manquait au fichier. Le type d'instance suffit donc à décider —
    -- « raid » ou « party » —, et il est vrai dès le chargement de la zone.
    local kind = instanceType()
    local want = mod:Get("autoCombatLog") and (kind == "raid" or kind == "party")

    if want then
        if loggingStarted then return false end

        -- Déjà allumée à la main : on la laisse telle quelle, et surtout on ne
        -- s'en déclare pas propriétaire. Sans ce test, `loggingStarted` passait à
        -- vrai pour une journalisation qu'on n'avait pas lancée — et on la
        -- coupait en sortant du raid, défaisant le geste de quelqu'un d'autre.
        --
        -- On le dit quand même : ne rien afficher laisserait croire que le
        -- réglage n'a pas pris, alors que le combat s'enregistre bel et bien.
        if LoggingCombat and LoggingCombat() then
            if toldForeign then return false end
            toldForeign = true
            mod:Print(L["Combat log already on"])
            return true
        end

        if savedAdvanced == nil then savedAdvanced = U.GetCVar(CVAR_ADVANCED) end
        U.SetCVar(CVAR_ADVANCED, "1")

        if LoggingCombat then LoggingCombat(true) end
        loggingStarted = true
        mod:Print(L["Combat log started"])
        return true
    end

    toldForeign = false

    if not loggingStarted then return false end
    if LoggingCombat then LoggingCombat(false) end
    if savedAdvanced ~= nil then
        U.SetCVar(CVAR_ADVANCED, savedAdvanced)
        savedAdvanced = nil
    end
    loggingStarted = false
    mod:Print(L["Combat log stopped"])
    return true
end

--- Bascule du réglage lui-même. Il se coche presque toujours **hors** raid, là
--- où `applyLogging` n'a rien à faire et donc rien à dire : sans cette ligne, le
--- joueur coche une case et n'obtient aucune réponse, ce qui est exactement le
--- doute qu'on cherche à lever.
---@param mod table
local function toggleLogging(mod)
    if applyLogging(mod) then return end
    mod:Print(mod:Get("autoCombatLog") and L["Combat log armed"] or L["Combat log off"])
end

-- =========================================================================
--  Déclaration du module
-- =========================================================================

BUI:RegisterModule(MODULE, {
    title    = L["Logging"],
    category = "MythicRaid",
    order    = 30,

    defaults = {
        autoCombatLog = false,
    },

    options = {
        {
            type    = "toggle",
            key     = "autoCombatLog",
            text    = L["Auto combat logging"],
            tooltip = L["Auto combat logging tip"],
        },
    },

    OnEnable = function(self)
        applyLogging(self)

        -- Ce qui décide de la journalisation change au passage d'une frontière
        -- d'instance, et nulle part ailleurs.
        local zoned = function() applyLogging(self) end
        self:RegisterEvent("PLAYER_ENTERING_WORLD",    zoned)
        self:RegisterEvent("ZONE_CHANGED_NEW_AREA",    zoned)
        self:RegisterEvent("CHALLENGE_MODE_START",     zoned)
        self:RegisterEvent("CHALLENGE_MODE_COMPLETED", zoned)
        self:RegisterEvent("CHALLENGE_MODE_RESET",     zoned)
    end,

    OnDisable = function()
        if not loggingStarted then return end

        if LoggingCombat then LoggingCombat(false) end
        if savedAdvanced ~= nil then
            U.SetCVar(CVAR_ADVANCED, savedAdvanced)
            savedAdvanced = nil
        end
        loggingStarted = false
    end,

    OnSettingChanged = function(self)
        toggleLogging(self)
    end,
})
