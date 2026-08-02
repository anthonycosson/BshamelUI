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

local SCHEMA_VERSION   = 10
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

    -- Palier 2 — le bouton de la minicarte quitte « Général » pour « Minicarte »,
    -- la page créée avec le tiroir de boutons d'addons et le menu de
    -- téléportation. Le nom d'un module est une clé de base de données : déplacer
    -- un réglage d'un module à l'autre se migre.
    --
    -- Tous les profils, pas seulement l'actif : un profil qu'on ne rouvrira que
    -- dans six mois doit trouver son réglage à la bonne place. Et seulement ce
    -- qui est écrit — les défauts sont retirés du fichier à la déconnexion, donc
    -- l'absence d'une clé signifie « jamais touchée » et n'a rien à migrer.
    if from < 2 then
        for _, profile in pairs(BshamelUIDB.profiles) do
            local modules = profile.modules
            local general = modules and modules.General

            if general then
                local moved = modules.Minimap or {}

                if general.minimapButton ~= nil and moved.button == nil then
                    moved.button = general.minimapButton
                end
                if general.minimapAngle ~= nil and moved.angle == nil then
                    moved.angle = general.minimapAngle
                end
                general.minimapButton = nil
                general.minimapAngle  = nil

                if next(moved) then modules.Minimap = moved end
            end
        end
        from = 2
    end

    -- Palier 3 — l'intensité des fenêtres de l'addon n'existe plus. Un réglage
    -- retiré du code n'est plus dans les défauts, donc plus rien ne le retire du
    -- fichier à la déconnexion : il y resterait indéfiniment, sans effet et sans
    -- explication. On l'efface une fois.
    if from < 3 then
        for _, profile in pairs(BshamelUIDB.profiles) do
            local general = profile.modules and profile.modules.General
            if general then general.windowIntensity = nil end
        end
        from = 3
    end

    -- Palier 4 — le chrono mythique+ n'est plus un panneau à nous : ce sont deux
    -- repères posés sur le chrono du client. Le réglage qui l'allumait change donc
    -- de nom pour dire ce qu'il fait, et sa position n'a plus d'objet.
    --
    -- Le nom est repris et non oublié : un joueur qui avait allumé le panneau
    -- voulait voir ses paliers, et c'est toujours ce que la case fait. Retirer la
    -- clé sans la reprendre aurait éteint son réglage sans le lui dire.
    if from < 4 then
        for _, profile in pairs(BshamelUIDB.profiles) do
            local timer = profile.modules and profile.modules.MythicTimer
            if timer then
                if timer.timer ~= nil and timer.thresholds == nil then
                    timer.thresholds = timer.timer
                end
                timer.timer  = nil
                timer.timerX = nil
                timer.timerY = nil
            end
        end
        from = 4
    end

    -- Palier 5 — la page « Minicarte » n'existe plus. Elle tenait trois choses
    -- qui n'avaient en commun que l'endroit où elles se posent, et l'endroit
    -- n'est pas un sujet de réglage : le menu de téléportation est devenu la page
    -- *Téléportations*, tandis que le bouton de l'addon et le tiroir de boutons
    -- d'addons sont retournés dans *Général*, d'où le palier 2 avait sorti le
    -- premier. Ces deux-là ne se séparent pas : le tiroir s'ouvre sur le bouton.
    --
    -- Deux destinations pour une source : c'est le seul palier qui éclate un
    -- module, et c'est pour cela qu'il ne peut pas être un renommage.
    if from < 5 then
        for _, profile in pairs(BshamelUIDB.profiles) do
            local modules = profile.modules
            local minimap = modules and modules.Minimap

            if minimap then
                local function into(name)
                    modules[name] = modules[name] or {}
                    return modules[name]
                end

                --- Ne déplace que ce qui est **écrit**. Les défauts sont retirés
                --- du fichier à la déconnexion : l'absence d'une clé signifie
                --- « jamais touchée » et n'a rien à migrer.
                local function move(target, key)
                    if minimap[key] == nil then return end
                    local dest = into(target)
                    if dest[key] == nil then dest[key] = minimap[key] end
                end

                move("General",   "button")
                move("General",   "angle")
                move("General",   "tray")
                move("Teleports", "teleport")
                move("Teleports", "teleportAngle")
                move("Teleports", "hearthstone")

                -- La page éteinte éteignait les trois d'un coup. Le menu de
                -- téléportation est devenu un module et hérite donc de son
                -- interrupteur ; les deux autres ne sont plus que des cases de
                -- *Général*, page qu'on ne peut pas éteindre sans éteindre le
                -- reste avec — ce sont donc les cases qui prennent l'extinction.
                if minimap.enabled == false then
                    into("Teleports").enabled = false
                    into("General").button    = false
                    into("General").tray      = false
                end

                modules.Minimap = nil
            end
        end
        from = 5
    end

    -- Palier 6 — le mode sombre quitte « Général » pour sa propre page. Sept
    -- réglages sur une page qui en comptait quinze : il en occupait le haut
    -- entier, et on descendait la moitié de la colonne pour atteindre le
    -- premier réglage qui n'était pas lui.
    if from < 6 then
        local KEYS = {
            "darkMode", "darkUnitFrames", "darkActionBars", "darkCastBar",
            "darkAuras", "darkCooldownManager", "darkTooltip",
        }

        for _, profile in pairs(BshamelUIDB.profiles) do
            local modules = profile.modules
            local general = modules and modules.General

            if general then
                local moved = modules.DarkMode or {}

                for i = 1, #KEYS do
                    local key = KEYS[i]
                    if general[key] ~= nil and moved[key] == nil then
                        moved[key] = general[key]
                    end
                    general[key] = nil
                end

                -- « Général » éteint éteignait le mode sombre avec le reste. Le
                -- nouveau module hérite donc de son interrupteur : sans cela, une
                -- page éteinte depuis des mois rallumerait le mode sombre au
                -- premier `/reload` qui suit la mise à jour.
                if general.enabled == false then moved.enabled = false end

                if next(moved) then modules.DarkMode = moved end
            end
        end
        from = 6
    end

    -- Palier 7 — le minuteur des fenêtres de file quitte « Général » pour
    -- « Recherche de groupe ». Il était dans Général faute de page où le mettre ;
    -- celle-ci existe, et c'est le seul endroit où on pense à le chercher.
    if from < 7 then
        for _, profile in pairs(BshamelUIDB.profiles) do
            local modules = profile.modules
            local general = modules and modules.General

            if general and general.queueTimer ~= nil then
                local moved = modules.GroupFinder or {}

                -- « Général » éteint tenait le minuteur éteint : on ne le rallume
                -- pas en le déplaçant sur une page qui, elle, est allumée.
                if moved.queueTimer == nil then
                    moved.queueTimer = general.enabled ~= false and general.queueTimer or false
                end
                general.queueTimer = nil

                if next(moved) then modules.GroupFinder = moved end
            end
        end
        from = 7
    end

    -- Palier 8 — « Outils de raid » tenait quatre outils que rien ne rassemblait
    -- qu'un même moment de la soirée, et le module disparaît entièrement. Les deux
    -- suivis de réserve vont dans *BL & Résurrections* ; la barre d'outils de
    -- groupe rejoint le panneau de contrôle du client dans *Panneau de contrôle*,
    -- parce que c'est le même sujet — l'un remplace l'autre ; la journalisation a
    -- sa page.
    if from < 8 then
        local MOVED = {
            RaidCooldowns = {
                "battleResTracker", "battleResShaded", "battleResPreview",
                "lockBattleRes", "battleResSize", "battleResX", "battleResY",
            },
            RaidPanel = {
                "hideBlizzardPanel",
                "worldMarkers", "markerX", "markerY", "markerScale",
                "lockMarkers", "markersOnHover", "pullTimer",
            },
            CombatLog = { "autoCombatLog" },
        }

        for _, profile in pairs(BshamelUIDB.profiles) do
            local modules = profile.modules
            local tools   = modules and modules.RaidTools

            if tools then
                for target, keys in pairs(MOVED) do
                    local moved = modules[target] or {}

                    for i = 1, #keys do
                        local key = keys[i]
                        if tools[key] ~= nil and moved[key] == nil then
                            moved[key] = tools[key]
                        end
                        tools[key] = nil
                    end

                    -- La page éteinte éteignait les quatre d'un coup : chacune de
                    -- celles qui en sortent hérite de son interrupteur.
                    if tools.enabled == false then moved.enabled = false end

                    if next(moved) then modules[target] = moved end
                end

                -- Plus rien ne vit sous ce nom : le laisser en base y ferait
                -- traîner un `enabled` que plus aucun module ne réclame.
                modules.RaidTools = nil
            end
        end
        from = 8
    end

    -- Palier 9 — « Général » servait de fourre-tout, et la catégorie « Jeu » ne
    -- tenait plus que lui et la fiche de personnage. Chaque réglage rejoint la
    -- page où on le cherche : la **réparation automatique** chez le marchand,
    -- donc dans *Sacs & Réparations* ; le filtre de l'**hôtel des ventes** dans sa
    -- page ; les **nuisances** dans la leur. La fiche de personnage ne change que
    -- de catégorie, ce qui ne se migre pas.
    if from < 9 then
        local MOVED = {
            Bags         = { "autoRepair" },
            AuctionHouse = { "auctionCurrentXP" },
            Annoyances   = { "skipCinematics", "hideTalkingHead", "hideLuaErrors" },
        }

        for _, profile in pairs(BshamelUIDB.profiles) do
            local modules = profile.modules
            local general = modules and modules.General

            if general then
                for target, keys in pairs(MOVED) do
                    local moved = modules[target] or {}

                    for i = 1, #keys do
                        local key = keys[i]
                        if general[key] ~= nil and moved[key] == nil then
                            moved[key] = general[key]
                        end
                        general[key] = nil
                    end

                    -- « Général » éteint tenait tout cela éteint. Les deux
                    -- nouveaux modules en héritent ; *Sacs*, lui, existait déjà et
                    -- a son propre interrupteur — c'est donc la case de la
                    -- réparation qui prend l'extinction, sans quoi on éteindrait
                    -- au passage la vente de la camelote.
                    if general.enabled == false then
                        if target == "Bags" then
                            moved.autoRepair = false
                        else
                            moved.enabled = false
                        end
                    end

                    if next(moved) then modules[target] = moved end
                end
            end
        end
        from = 9
    end

    -- Palier 10 — le masquage du panneau de contrôle du client était le **seul**
    -- réglage allumé par défaut. Installer l'addon faisait donc disparaître un
    -- morceau de l'interface du jeu sans que personne l'ait demandé, et le motif
    -- ne tenait pas : il était censé remplacer ce panneau par le nôtre, lui-même
    -- éteint sur une installation neuve. Il passe à `false`.
    --
    -- Ce palier existe pour ceux qui étaient déjà là. Un défaut n'est jamais
    -- écrit sur le disque (voir l'en-tête de ce fichier) : sans cette ligne, le
    -- panneau réapparaîtrait chez tous ceux qui n'avaient jamais touché à la
    -- case — c'est-à-dire chez tous ceux à qui il convenait. On écrit donc
    -- explicitement ce qu'ils avaient.
    --
    -- Les profils traversés ici sont **forcément** antérieurs au changement : une
    -- installation neuve part au schéma courant, et aucun palier ne s'exécute.
    if from < 10 then
        for _, profile in pairs(BshamelUIDB.profiles) do
            local modules = profile.modules
            if modules then
                local panel = modules.RaidPanel or {}
                if panel.hideBlizzardPanel == nil then
                    panel.hideBlizzardPanel = true
                    modules.RaidPanel = panel
                end
            end
        end
        from = 10
    end

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
