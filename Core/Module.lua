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
--- La catégorie « Jeu » a disparu : chacun de ses modules a rejoint la page où on
--- le cherche, et une catégorie ne se garde pas pour son nom.
BUI.CATEGORIES = {
    { key = "Interface",  label = "Interface" },
    { key = "QoL",        label = "Quality of life" },
    -- La clé reste `MythicRaid` : elle ne sert qu'à regrouper, et la renommer
    -- toucherait cinq modules pour changer un intitulé.
    { key = "MythicRaid", label = "Tools" },

    -- Les réglages **des réglages** : profils, sauvegarde, partage. Rien ici ne
    -- touche au jeu — la catégorie porte donc le nom du geste, pas d'une page :
    -- aucune catégorie ne porte le nom d'un de ses modules (voir plus haut).
    { key = "Sharing",    label = "Import / export" },

    -- Ce qui ne répare que la bêta de *Forever*, et qui disparaîtra avec elle.
    -- Sa propre catégorie parce que ces pages ne se rangent nulle part
    -- ailleurs : elles ne règlent rien, elles rattrapent. Vide sur retail, où
    -- aucun module ne s'y déclare — la barre latérale saute alors la catégorie.
    { key = "Beta",       label = "Beta" },

    -- En dernier, et c'est sa place : on ne descend pas jusqu'ici en cherchant
    -- un réglage, on y descend en ayant fini de chercher. Ce qui s'y range ne
    -- rend rien plus lisible ni plus rapide — c'est le seul endroit de l'addon
    -- où l'utilité n'est pas le critère, et l'intitulé l'annonce franchement.
    { key = "Fun",        label = "Useless but essential" },
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
    -- Une option que ce client n'a pas vaut son défaut, quoi que la base
    -- contienne (voir `Core/Forever.lua`). Le module n'a rien à savoir.
    if self._withdrawn and self._withdrawn[key] then
        return self.defaults[key]
    end
    return BUI.DB:Get(self.name, key)
end

---@param key string
---@param value any
function ModuleMixin:Set(key, value)
    if self._withdrawn and self._withdrawn[key] then return end
    BUI.DB:Set(self.name, key, value)
end

---@return boolean
function ModuleMixin:IsEnabled()
    return self._active == true
end

--- Espace de rangement du module pour ce qui n'est pas un réglage : propre au
--- personnage, hors du mécanisme de défauts, écrit directement (voir
--- `DB:CharData`, qui explique pourquoi ce chemin est séparé de `Get`/`Set`).
---@return table
function ModuleMixin:CharData()
    return BUI.DB:CharData(self.name)
end

--- Le même espace, **au compte** : pour la donnée que tous les personnages
--- doivent voir (voir `DB:AccountData`, qui explique pourquoi elle vit hors
--- des profils).
---@return table
function ModuleMixin:AccountData()
    return BUI.DB:AccountData(self.name)
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
    -- Repli sur la première catégorie déclarée : un module sans catégorie doit
    -- s'afficher quelque part, et un nom écrit ici en dur deviendrait faux le jour
    -- où cette catégorie-là disparaîtrait — c'est précisément ce qui est arrivé à
    -- « Jeu ».
    mod.category  = mod.category or BUI.CATEGORIES[1].key
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
    -- Un module que ce client annonce sans le livrer encore (voir
    -- `Core/Forever.lua`) : même traitement qu'un module en avant-première.
    if ns.PREVIEW and ns.PREVIEW[name] then mod.preview = true end
    if mod.preview then mod.defaults.enabled = false end

    -- Les options que ce client n'a pas sortent de la page — et donc de la
    -- recherche, qui lit la même liste. La liste n'existe que sur les clients
    -- dont le `.toc` charge `Core/Forever.lua` ; ailleurs, rien ne bouge.
    local withdrawn = ns.WITHDRAWN and ns.WITHDRAWN[name]
    if withdrawn and type(mod.options) == "table" then
        mod._withdrawn = withdrawn
        local kept = {}
        for i = 1, #mod.options do
            local descriptor = mod.options[i]
            if not (descriptor.key and withdrawn[descriptor.key]) then
                kept[#kept + 1] = descriptor
            end
        end
        mod.options = kept
    end

    -- Les avertissements que ce client pose sous une option, en rouge. Même
    -- source et même règle que ci-dessus : absents ailleurs.
    local notes = ns.NOTES and ns.NOTES[name]
    if notes and type(mod.options) == "table" then
        local with = {}
        for i = 1, #mod.options do
            local descriptor = mod.options[i]
            with[#with + 1] = descriptor
            for j = 1, #notes do
                if descriptor.key and notes[j].after == descriptor.key then
                    with[#with + 1] = { type = "alert", text = L[notes[j].text], indent = true }
                end
            end
        end
        mod.options = with
    end

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
--  Mode édition
-- =========================================================================
-- **Un interrupteur pour tout poser d'un coup.** Chaque cadre que l'addon pose
-- à même l'écran a son aperçu et son verrou ; les allumer un par un demande
-- d'ouvrir sept pages pour cocher dix-huit cases, puis de refaire le tour en
-- sens inverse. Le mode édition coche les aperçus, ouvre les verrous, et l'écran
-- montre d'un coup tout ce qu'il y a à placer.
--
-- **Il ne devine rien.** C'est le descripteur d'option qui se déclare :
-- `edit = "preview"` ou `edit = "lock"` (voir `UI/Config/PageBuilder.lua`).
-- Reconnaître une case à son nom aurait marché — jusqu'à `lootPreview` et
-- `battleResPreview`, qui ne commencent pas par « preview », et jusqu'au jour
-- où un réglage se serait appelé ainsi sans en être un. Une case oubliée ne
-- s'allume pas, ce qui se voit ; une case emportée par erreur décide à la
-- place du joueur, ce qui ne se voit pas.
--
-- **La sortie ne se contente pas de défaire.** Les aperçus s'éteignent, quoi
-- qu'ils aient valu avant : un aperçu est un état qu'on tient allumé le temps
-- de regarder, pas un réglage qu'on garde. Les verrous, eux, sont un vrai
-- choix, et ils sont rendus tels qu'ils étaient. C'est ce qui fait qu'un
-- `/reload` en plein mode édition se rattrape d'un aller-retour sur le bouton :
-- l'état retenu est perdu, la sortie nettoie quand même.

local editMode = false

--- nom de module -> clé -> valeur d'avant. Les verrous seuls : eux seuls se
--- rendent.
local lockedBefore = {}

--- Parcourt les options qu'un module a marquées pour le mode édition.
---@param mod table
---@param fn fun(descriptor: table)
local function eachEditOption(mod, fn)
    local options = mod.options
    if type(options) ~= "table" then return end

    for i = 1, #options do
        local descriptor = options[i]
        if type(descriptor) == "table" and descriptor.edit and descriptor.key then
            fn(descriptor)
        end
    end
end

---@return boolean
function BUI:IsEditMode()
    return editMode
end

--- Allume ou éteint le mode édition.
---
--- Tout passe par `mod:Set`, donc par le chemin ordinaire d'un clic : chaque
--- module reçoit son `OnSettingChanged`, la page ouverte se rafraîchit, et il
--- n'y a rien de particulier à prévoir nulle part.
---@param on boolean
function BUI:SetEditMode(on)
    on = on and true or false
    if editMode == on then return end
    editMode = on

    for name, mod in pairs(registry) do
        eachEditOption(mod, function(descriptor)
            local key = descriptor.key

            if descriptor.edit == "preview" then
                mod:Set(key, on)
                return
            end

            if on then
                local memory = lockedBefore[name] or {}
                lockedBefore[name] = memory
                memory[key] = mod:Get(key) and true or false
                mod:Set(key, false)
            else
                local memory = lockedBefore[name]
                if memory and memory[key] ~= nil then mod:Set(key, memory[key]) end
            end
        end)
    end

    if not on then wipe(lockedBefore) end
end

--- Bascule, pour le bouton qui n'a qu'un état à inverser.
function BUI:ToggleEditMode()
    self:SetEditMode(not editMode)
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

    -- **Avant d'allumer quoi que ce soit.** Le nom du personnage n'existe pas à
    -- `ADDON_LOADED` : c'est ici que la base apprend quel profil ce personnage
    -- utilise, et un module allumé avant lirait les réglages du mauvais.
    BUI.DB:BindCharacter()

    started = true
    for name, mod in pairs(registry) do
        if mod:Get("enabled") then BUI:EnableModule(name) end
    end

    -- **Une ligne, et la seule que l'addon écrive de lui-même.** Un addon dont
    -- tout est éteint à l'installation ne se manifeste nulle part : rien ne
    -- change à l'écran, et le joueur qui vient de le télécharger n'a aucun moyen
    -- de deviner par où l'ouvrir. Cette ligne est le seul endroit où le dire.
    --
    -- **Elle se tait dès que la fenêtre a été ouverte une fois.** Un rappel qui
    -- revient à chaque connexion pendant six mois n'informe plus personne, il
    -- agace — et il n'y a rien à rappeler à qui sait déjà. Pas de case à cocher
    -- pour autant : un réglage pour éteindre un message d'une ligne coûterait
    -- plus d'attention qu'il n'en fait gagner.
    --
    -- Après le démarrage des modules, pour qu'elle arrive après ce qu'ils
    -- auraient à dire eux-mêmes, et non au milieu.
    if not BUI.DB:Seen(BUI.DB.HINT_LOGIN) then
        BUI:Print(L["Login hint"])
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

    -- `/bui auras` : le diagnostic des barres d'infos, écrit dans le chat par
    -- le module lui-même. Le core cite le module par son nom, ce qui est permis :
    -- ce nom est une clé de base de données, donc stable par la règle 4.
    if arg == "auras" then
        local mod = registry["Nameplates"]
        if mod and mod._active and mod.DiagnoseAuras then
            BUI.safecall(mod.DiagnoseAuras, mod)
        else
            BUI:Print(L["Aura diagnostic unavailable"])
        end
        return
    end

    -- `/bui noms` : pourquoi le nom du joueur ciblé porte la couleur qu'il
    -- porte. Même porte d'entrée que ci-dessus, et même motif : ce qui décide
    -- est invisible depuis le jeu.
    if arg == "noms" or arg == "names" then
        local mod = registry["Nameplates"]
        if mod and mod._active and mod.DiagnoseNames then
            BUI.safecall(mod.DiagnoseNames, mod)
        else
            BUI:Print(L["Aura diagnostic unavailable"])
        end
        return
    end

    -- `/bui emote` : écrit le texte brut de chaque emote reçu. Ce que le module
    -- des emotes reconnaît est une **phrase**, tirée des fichiers de locale
    -- faute d'API qui la publie — et une phrase mal orthographiée ne lève pas,
    -- elle rend le module muet. C'est le seul moyen de lire ce que le client
    -- écrit vraiment.
    if arg == "emote" or arg == "emotes" then
        local mod = registry["Emotes"]
        if mod and mod._active and mod.ToggleWatch then
            BUI:Print(L["Emote watch"], mod:ToggleWatch() and L["On"] or L["Off"])
        else
            BUI:Print(L["Emote module unavailable"])
        end
        return
    end

    -- `/bui fiche` : pourquoi l'icône d'enchantement d'un emplacement porte
    -- l'image qu'elle porte. L'étoile de rang n'est pas choisie, elle est
    -- récupérée dans une chaîne d'infobulle — et quatre choses peuvent manquer
    -- en chemin sans que rien ne lève.
    if arg == "fiche" or arg == "sheet" then
        local mod = registry["Character"]
        if mod and mod._active and mod.DiagnoseSheet then
            BUI.safecall(mod.DiagnoseSheet, mod)
        else
            BUI:Print(L["Sheet diagnostic unavailable"])
        end
        return
    end

    -- `/bui cadres` : pourquoi la barre de la cible ou du focus n'a pas la
    -- couleur de sa classe. Trois causes qui donnent la même barre verte.
    if arg == "cadres" or arg == "frames" then
        local mod = registry["UnitFrames"]
        if mod and mod._active and mod.DiagnoseFrames then
            BUI.safecall(mod.DiagnoseFrames, mod)
        else
            BUI:Print(L["Frame diagnostic unavailable"])
        end
        return
    end

    -- `/bui vol` : pourquoi le temps de vol restant ne s'est pas affiché.
    -- Quatre lectures peuvent se taire sans qu'aucune ne lève, et le symptôme
    -- est le même pour les quatre — un cadre qui ne vient pas.
    if arg == "vol" or arg == "flight" then
        local mod = registry["Timers"]
        if mod and mod._active and mod.DiagnoseFlight then
            BUI.safecall(mod.DiagnoseFlight, mod)
        else
            BUI:Print(L["Flight diagnostic unavailable"])
        end
        return
    end

    -- `/bui glow` : ce que le mode sombre a fait au cadre sous le curseur. Le
    -- moteur est hors des modules, comme celui de la minicarte : on l'appelle
    -- donc directement, sans passer par le registre.
    if arg == "glow" then
        if BUI.Shade and BUI.Shade.Diagnose then
            BUI.safecall(BUI.Shade.Diagnose, BUI.Shade)
        end
        return
    end

    -- `/bui blocked` : écrit dans le chat le nom de chaque action refusée par le
    -- client. La fenêtre « action réservée à l'IU de Blizzard » ne le dit pas, et
    -- sans lui il n'y a rien à chercher (voir `BUI:ToggleActionWatch`).
    if arg == "blocked" then
        local watching = BUI:ToggleActionWatch()
        BUI:Print(L["Blocked action watch"], watching and L["On"] or L["Off"])

        -- La veille allume l'affichage des erreurs, sans quoi le client
        -- n'émettrait rien à écouter. On le dit : le joueur voit un réglage
        -- changer, il doit savoir par qui et jusqu'à quand.
        if watching then BUI:Print(L["Blocked action needs errors"]) end
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
