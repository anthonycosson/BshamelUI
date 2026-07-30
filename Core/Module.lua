-- =========================================================================
--  Bshamel UI — Core/Module.lua
--  Registre des modules et cycle de vie.
--
--  Un module est une **table déclarative**. Il ne crée pas de frame, ne lit pas
--  le SavedVariables et ne connaît aucun autre module. Il déclare ce qu'il
--  règle, et ce qu'il fait quand on l'active.
--
--      BUI:RegisterModule("Quest", {
--          title    = L["Quest"],
--          category = "QoL",
--          defaults = { autoAccept = false },
--          options  = { { type = "toggle", key = "autoAccept", text = ... } },
--          OnEnable = function(self)
--              self:RegisterEvent("QUEST_DETAIL", function() ... end)
--          end,
--      })
--
--  Réversibilité : tout ce qu'un module abonne via `self:RegisterEvent` est
--  désabonné automatiquement par `OnDisable`. `OnDisable` n'a donc à s'occuper
--  que de ce qu'il a *modifié* (une frame déplacée, une texture cachée), pas de
--  ce qu'il a *écouté*.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local L   = ns.L

local Modules = {}
BUI.Modules = Modules

--- Catégories de la barre latérale, dans l'ordre d'affichage.
--- Ajouter une catégorie ici et nulle part ailleurs.
---
--- Aucune catégorie ne porte le nom d'un de ses modules : un intitulé répété
--- juste sous lui-même donne une navigation qui a l'air cassée.
BUI.CATEGORIES = {
    { key = "Game",       label = "Game" },
    { key = "Interface",  label = "Interface" },
    { key = "QoL",        label = "QoL" },
    { key = "MythicRaid", label = "Mythic+ / Raid" },
}

--- name -> définition
local registry = {}
--- ordre d'enregistrement, pour un tri stable à `order` égal
local registrationIndex = 0
--- modules dont l'activation attend la sortie de combat
local pendingCombat = {}

local started = false

-- =========================================================================
--  Méthodes injectées dans chaque module
-- =========================================================================

local ModuleMixin = {}

---@param key string
---@return any
function ModuleMixin:Get(key)
    return BUI.DB:Get(self.name, key)
end

---@param key string
---@param value any
function ModuleMixin:Set(key, value)
    BUI.DB:Set(self.name, key, value)
end

---@return boolean
function ModuleMixin:IsEnabled()
    return self._active == true
end

--- Abonnement à un événement du client, révoqué automatiquement à la
--- désactivation du module.
---@param event string
---@param fn fun(event: string, ...: any)
function ModuleMixin:RegisterEvent(event, fn)
    self._events = self._events or {}
    self._events[#self._events + 1] = { event = event, fn = fn }
    BUI:RegisterEvent(event, fn)
end

--- Abonnement à un message interne, révoqué automatiquement lui aussi.
---@param message string
---@param fn fun(message: string, ...: any)
function ModuleMixin:RegisterMessage(message, fn)
    self._messages = self._messages or {}
    self._messages[#self._messages + 1] = { message = message, fn = fn }
    BUI:RegisterMessage(message, fn)
end

function ModuleMixin:Print(...)
    BUI:Print("[" .. self.name .. "]", ...)
end

local function releaseSubscriptions(mod)
    if mod._events then
        for i = 1, #mod._events do
            local sub = mod._events[i]
            BUI:UnregisterEvent(sub.event, sub.fn)
        end
        mod._events = nil
    end
    if mod._messages then
        for i = 1, #mod._messages do
            local sub = mod._messages[i]
            BUI:UnregisterMessage(sub.message, sub.fn)
        end
        mod._messages = nil
    end
end

-- =========================================================================
--  Enregistrement
-- =========================================================================

---@param name string        identifiant stable, sert de clé en base — ne jamais le renommer
---@param definition table
function BUI:RegisterModule(name, definition)
    if type(name) ~= "string" or type(definition) ~= "table" then
        BUI:Warn("RegisterModule: arguments invalides")
        return
    end
    if registry[name] then
        BUI:Warn("RegisterModule: " .. name .. " est déjà enregistré")
        return
    end

    registrationIndex = registrationIndex + 1

    local mod = definition
    mod.name      = name
    mod.category  = mod.category or "Game"
    mod.title     = mod.title or name
    mod.order     = mod.order or 100
    mod._index    = registrationIndex
    mod._active   = false

    for key, fn in pairs(ModuleMixin) do
        if mod[key] == nil then mod[key] = fn end
    end

    -- Tout module est activable/désactivable : le core possède cette clé.
    mod.defaults = mod.defaults or {}
    if mod.defaults.enabled == nil then mod.defaults.enabled = true end

    -- `preview` : le module annonce une fonctionnalité qui n'est pas encore
    -- écrite. Il occupe sa place dans la navigation et montre les réglages
    -- qu'il proposera, mais il ne s'allume jamais — ni au démarrage, ni depuis
    -- la base d'un joueur, ni par un clic. Le forçage est ici, à l'écriture des
    -- défauts, et pas seulement dans l'interface : un réglage qui n'existe pas
    -- ne doit pas pouvoir s'allumer par un autre chemin que celui qu'on a prévu.
    if mod.preview then mod.defaults.enabled = false end

    registry[name] = mod
    BUI.DB:RegisterDefaults(name, mod.defaults)

    -- Enregistrement tardif (après PLAYER_LOGIN) : on démarre tout de suite.
    if started and mod:Get("enabled") then
        BUI:EnableModule(name)
    end
end

---@param name string
---@return table|nil
function Modules:Get(name)
    return registry[name]
end

--- Modules d'une catégorie, triés par `order` puis par ordre d'enregistrement.
---@param category string
---@return table[]
function Modules:GetByCategory(category)
    local out = {}
    for _, mod in pairs(registry) do
        if mod.category == category then out[#out + 1] = mod end
    end
    table.sort(out, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a._index < b._index
    end)
    return out
end

---@return table<string, table>
function Modules:GetAll()
    return registry
end

-- =========================================================================
--  Activation / désactivation
-- =========================================================================

---@param name string
function BUI:EnableModule(name)
    local mod = registry[name]
    if not mod or mod._active then return end
    if mod.preview then return end

    if mod.secure and InCombatLockdown() then
        pendingCombat[name] = true
        return
    end
    pendingCombat[name] = nil

    mod._active = true
    if mod.OnEnable then BUI.safecall(mod.OnEnable, mod) end
    BUI:SendMessage(BUI.MESSAGES.MODULE_STATE, name, true)
end

---@param name string
function BUI:DisableModule(name)
    local mod = registry[name]
    if not mod or not mod._active then return end

    if mod.secure and InCombatLockdown() then
        pendingCombat[name] = true
        return
    end
    pendingCombat[name] = nil

    mod._active = false
    if mod.OnDisable then BUI.safecall(mod.OnDisable, mod) end
    releaseSubscriptions(mod)
    BUI:SendMessage(BUI.MESSAGES.MODULE_STATE, name, false)
end

-- =========================================================================
--  Démarrage
-- =========================================================================

BUI:RegisterEvent("ADDON_LOADED", function(_, addonName)
    if addonName ~= BUI.ADDON then return end
    BUI.DB:Initialize()
end)

BUI:RegisterEventOnce("PLAYER_LOGIN", function()
    -- Filet de sécurité : si ADDON_LOADED a été manqué (rechargement à chaud
    -- d'un profil de dev), la base est quand même prête.
    BUI.DB:Initialize()

    started = true
    for name, mod in pairs(registry) do
        if mod:Get("enabled") then BUI:EnableModule(name) end
    end
end)

BUI:RegisterEvent("PLAYER_REGEN_ENABLED", function()
    if not next(pendingCombat) then return end
    for name in pairs(pendingCombat) do
        local mod = registry[name]
        if mod then
            if mod:Get("enabled") then BUI:EnableModule(name) else BUI:DisableModule(name) end
        end
    end
    wipe(pendingCombat)
end)

-- Un changement de `enabled` bascule le module ; tout autre changement est
-- transmis au module concerné.
BUI:RegisterMessage(BUI.MESSAGES.SETTING_CHANGED, function(_, moduleName, key, value)
    local mod = registry[moduleName]
    if not mod then return end

    if key == "enabled" then
        if value then BUI:EnableModule(moduleName) else BUI:DisableModule(moduleName) end
        return
    end

    if mod._active and mod.OnSettingChanged then
        BUI.safecall(mod.OnSettingChanged, mod, key, value)
    end
end)

-- Un changement de profil rejoue l'état voulu de chaque module.
BUI:RegisterMessage(BUI.MESSAGES.PROFILE_CHANGED, function()
    for name, mod in pairs(registry) do
        local shouldRun = mod:Get("enabled") and true or false
        if shouldRun and not mod._active then
            BUI:EnableModule(name)
        elseif not shouldRun and mod._active then
            BUI:DisableModule(name)
        elseif shouldRun and mod._active and mod.OnSettingChanged then
            BUI.safecall(mod.OnSettingChanged, mod, nil, nil)
        end
    end
end)

-- =========================================================================
--  Ligne de commande
-- =========================================================================

SLASH_BSHAMELUI1 = "/bui"
SLASH_BSHAMELUI2 = "/bshamelui"

SlashCmdList["BSHAMELUI"] = function(msg)
    local arg = strlower(strtrim(msg or ""))

    if arg == "version" then
        BUI:Print(L["Version"], BUI.VERSION)
        return
    end


    if BUI.Config and BUI.Config.Toggle then
        BUI.Config:Toggle()
    else
        BUI:Warn("interface d'options indisponible")
    end
end

--- Icône du compartiment d'addons (menu de la minicarte).
--- Deuxième et dernier global autorisé, imposé par `## AddonCompartmentFunc`.
function BshamelUI_OnAddonCompartmentClick()
    if BUI.Config and BUI.Config.Toggle then BUI.Config:Toggle() end
end
