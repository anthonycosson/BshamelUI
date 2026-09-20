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

--- Valeur de la CVar relevée avant qu'on y touche. `nil` veut dire « on n'a rien
--- changé », ce qui n'est pas la même chose que « elle était vide ».
local savedAdvanced

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
---
--- **On compare à l'état réel du client**, et non à un souvenir de ce qu'on a
--- fait. La version précédente ne coupait que ce qu'elle avait elle-même
--- allumé, pour ne pas défaire un geste manuel — sauf que ce souvenir ne
--- survit ni à une reconnexion ni à un `/reload` : entré en donjon puis
--- rechargé, on ressortait avec la journalisation toujours en cours, et rien ne
--- le disait. Le réglage promet « en donjon, oui ; dehors, non » : il ne peut
--- pas le tenir en s'interdisant de couper.
---@param mod table
---@return boolean spoke  a-t-on écrit quelque chose ?
local function applyLogging(mod)
    if not LoggingCombat then return false end

    -- **Le seuil est la porte de l'instance**, pas le départ de la clé. Une clé
    -- se pose après être entré, et souvent après un premier pack : tout ce qui
    -- précède manquait au fichier. Le type d'instance suffit donc à décider —
    -- « raid » ou « party » —, et il est vrai dès le chargement de la zone.
    local kind = instanceType()
    local want = mod:Get("autoCombatLog") and (kind == "raid" or kind == "party")
    local on   = LoggingCombat() and true or false

    if want == on then return false end

    if want then
        if savedAdvanced == nil then savedAdvanced = U.GetCVar(CVAR_ADVANCED) end
        U.SetCVar(CVAR_ADVANCED, "1")

        LoggingCombat(true)
        mod:Print(L["Combat log started"])
        return true
    end

    LoggingCombat(false)
    if savedAdvanced ~= nil then
        U.SetCVar(CVAR_ADVANCED, savedAdvanced)
        savedAdvanced = nil
    end
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

    -- Éteindre le module rend la CVar, et coupe la journalisation si elle tourne
    -- encore : tant qu'il était allumé, c'est lui qui en décidait.
    OnDisable = function()
        if LoggingCombat and LoggingCombat() then LoggingCombat(false) end
        if savedAdvanced ~= nil then
            U.SetCVar(CVAR_ADVANCED, savedAdvanced)
            savedAdvanced = nil
        end
    end,

    --- `key` est `nil` quand ce n'est pas le joueur qui vient de cocher : le
    --- core rejoue alors l'état des modules après un changement de profil — ou
    --- après une restauration de configuration, qui arrive à la connexion. Il
    --- n'y a personne à rassurer dans ce cas-là, seulement une ligne de plus
    --- dans un chat déjà chargé.
    ---@param key string|nil
    OnSettingChanged = function(self, key)
        if key == nil then
            applyLogging(self)
            return
        end
        toggleLogging(self)
    end,
})
