-- =========================================================================
--  Bshamel UI — Core/DB.lua
--  Réglages persistants.
--
--  Forme du SavedVariables (compte) :
--      BshamelUIDB = {
--          schema   = 1,
--          profiles = { ["Default"] = { modules = { Quest = { autoAccept = true } } } },
--      }
--
--  Forme du SavedVariables (personnage) :
--      BshamelUICharDB = {
--          profile = "Default",
--          data    = { Chat = { history = { ... } } },   -- voir DB:CharData
--      }
--
--  Deux invariants tenus par ce fichier :
--    1. Les valeurs par défaut ne sont **jamais** écrites sur le disque. Elles
--       sont fusionnées en mémoire à la connexion et retirées à la déconnexion.
--       Le fichier ne contient donc que les choix explicites de l'utilisateur,
--       et changer un défaut dans le code change le comportement de tout le
--       monde sans migration.
--    2. Un module lit et écrit toujours via ce fichier, jamais directement dans
--       le global.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local U   = BUI.Util

local DB = {}
BUI.DB = DB

local SCHEMA_VERSION   = 1
local DEFAULT_PROFILE  = "Default"

--- moduleName -> table de défauts (référence, pas une copie)
local defaultsRegistry = {}

local initialized = false

-- =========================================================================
--  Accès interne
-- =========================================================================

local function profileName()
    return (BshamelUICharDB and BshamelUICharDB.profile) or DEFAULT_PROFILE
end

local function profileTable()
    local name = profileName()
    local profiles = BshamelUIDB.profiles
    if not profiles[name] then
        profiles[name] = { modules = {} }
    elseif not profiles[name].modules then
        profiles[name].modules = {}
    end
    return profiles[name]
end

local function moduleTable(moduleName)
    local modules = profileTable().modules
    if not modules[moduleName] then modules[moduleName] = {} end
    return modules[moduleName]
end

--- (Re)fusionne les défauts de tous les modules connus dans le profil actif.
local function applyAllDefaults()
    for moduleName, defaults in pairs(defaultsRegistry) do
        U.MergeDefaults(moduleTable(moduleName), defaults)
    end
end

-- =========================================================================
--  Cycle de vie
-- =========================================================================

--- Appelé sur ADDON_LOADED de notre addon, donc avant PLAYER_LOGIN.
function DB:Initialize()
    if initialized then return end

    BshamelUIDB     = BshamelUIDB     or {}
    BshamelUICharDB = BshamelUICharDB or {}

    BshamelUIDB.profiles = BshamelUIDB.profiles or {}
    BshamelUIDB.schema   = BshamelUIDB.schema   or SCHEMA_VERSION

    if not BshamelUICharDB.profile then
        BshamelUICharDB.profile = DEFAULT_PROFILE
    end

    self:RunMigrations()
    applyAllDefaults()

    initialized = true
end

--- Point d'entrée unique des migrations de schéma.
--- Chaque palier est idempotent et fait progresser `schema` d'exactement un.
--- Ne jamais modifier un palier déjà publié : en ajouter un nouveau.
function DB:RunMigrations()
    local from = BshamelUIDB.schema or SCHEMA_VERSION

    -- if from < 2 then
    --     ... transformation ...
    --     from = 2
    -- end

    BshamelUIDB.schema = math.max(from, SCHEMA_VERSION)
end

--- Retire les valeurs égales aux défauts juste avant l'écriture du fichier.
local function onLogout()
    if not initialized then return end
    for _, profile in pairs(BshamelUIDB.profiles) do
        if profile.modules then
            for moduleName, settings in pairs(profile.modules) do
                local defaults = defaultsRegistry[moduleName]
                if defaults then U.StripDefaults(settings, defaults) end
                if not next(settings) then profile.modules[moduleName] = nil end
            end
        end
    end
end

BUI:RegisterEvent("PLAYER_LOGOUT", onLogout)

-- =========================================================================
--  Défauts
-- =========================================================================

--- Déclare les défauts d'un module. Appelé par Core/Module.lua ; un module ne
--- l'appelle pas lui-même.
---@param moduleName string
---@param defaults table
function DB:RegisterDefaults(moduleName, defaults)
    defaultsRegistry[moduleName] = defaults
    if initialized then
        U.MergeDefaults(moduleTable(moduleName), defaults)
    end
end

---@param moduleName string
---@return table|nil
function DB:GetDefaults(moduleName)
    return defaultsRegistry[moduleName]
end

-- =========================================================================
--  Lecture / écriture
-- =========================================================================

--- Table de réglages d'un module dans le profil actif.
---@param moduleName string
---@return table
function DB:Module(moduleName)
    return moduleTable(moduleName)
end

---@param moduleName string
---@param key string
---@return any
function DB:Get(moduleName, key)
    return moduleTable(moduleName)[key]
end

--- Écrit un réglage et notifie. C'est le seul chemin d'écriture autorisé :
--- il garantit que l'UI et le module concerné sont prévenus.
---@param moduleName string
---@param key string
---@param value any
function DB:Set(moduleName, key, value)
    local settings = moduleTable(moduleName)
    if settings[key] == value then return end
    settings[key] = value
    BUI:SendMessage(BUI.MESSAGES.SETTING_CHANGED, moduleName, key, value)
end

--- Remet un module à ses défauts.
---@param moduleName string
function DB:ResetModule(moduleName)
    local settings = moduleTable(moduleName)
    wipe(settings)
    local defaults = defaultsRegistry[moduleName]
    if defaults then U.MergeDefaults(settings, defaults) end
    BUI:SendMessage(BUI.MESSAGES.SETTING_CHANGED, moduleName, nil, nil)
end

-- =========================================================================
--  Données de module
-- =========================================================================

--- Espace de rangement d'un module pour ce qui **n'est pas un réglage** : une
--- donnée qui n'a ni défaut, ni contrôle, ni raison de voyager d'un personnage
--- à l'autre. L'historique de chat en est le premier cas.
---
--- Trois différences avec un réglage, et elles justifient le chemin séparé :
--- ces données vivent dans le SavedVariables du **personnage** et non dans un
--- profil partagé ; elles ne passent pas par le mécanisme de défauts, donc rien
--- ne leur est retiré à la déconnexion ; et les écrire n'émet aucun message,
--- puisque personne n'a à s'en rafraîchir.
---
--- La table est rendue par référence : le module y écrit directement. C'est la
--- seule exception à « un module n'écrit que par `Set` » (CLAUDE.md règle 4), et
--- elle vaut pour ce qui s'écrit ligne à ligne — passer par `Set` émettrait un
--- message par message de chat reçu.
---@param moduleName string
---@return table
function DB:CharData(moduleName)
    BshamelUICharDB = BshamelUICharDB or {}
    BshamelUICharDB.data = BshamelUICharDB.data or {}

    local data = BshamelUICharDB.data
    if not data[moduleName] then data[moduleName] = {} end
    return data[moduleName]
end

-- =========================================================================
--  Profils
-- =========================================================================

---@return string
function DB:GetProfileName()
    return profileName()
end

---@return string[]
function DB:ListProfiles()
    return U.SortedKeys(BshamelUIDB.profiles)
end

--- Bascule le personnage courant sur un profil (créé s'il n'existe pas).
---@param name string
function DB:SetProfile(name)
    if type(name) ~= "string" or name == "" then return end
    if not BshamelUIDB.profiles[name] then
        BshamelUIDB.profiles[name] = { modules = {} }
    end
    BshamelUICharDB.profile = name
    applyAllDefaults()
    BUI:SendMessage(BUI.MESSAGES.PROFILE_CHANGED, name)
end

--- Duplique le profil actif sous un nouveau nom, sans y basculer.
---@param name string
---@return boolean created
function DB:CopyProfileTo(name)
    if type(name) ~= "string" or name == "" then return false end
    if BshamelUIDB.profiles[name] then return false end
    BshamelUIDB.profiles[name] = U.DeepCopy(profileTable())
    return true
end

---@param name string
---@return boolean deleted
function DB:DeleteProfile(name)
    if name == profileName() then return false end          -- jamais le profil actif
    if not BshamelUIDB.profiles[name] then return false end
    BshamelUIDB.profiles[name] = nil
    return true
end
