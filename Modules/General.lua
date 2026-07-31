-- =========================================================================
--  Bshamel UI — Modules/General.lua
--  Les réglages qui n'appartiennent à aucune fenêtre en particulier.
--
--  Neuf comportements, un seul module : ce sont tous des réglages que le joueur
--  cherche « quelque part dans les options », et les éclater en neuf pages
--  rendrait chacun introuvable.
--
--  Ce qui se voit sur la minicarte n'est plus ici : le bouton de l'addon a
--  rejoint **Minicarte** le jour où cette page a existé, avec le tiroir de
--  boutons d'addons et le menu de téléportation (voir le palier de migration
--  dans `Core/DB.lua`).
--
--  Réversibilité (CLAUDE.md règle 6) : chaque comportement relève l'état du
--  client **avant** de le changer, et `OnDisable` le repose. Les CVar sont
--  restituées à leur valeur d'origine, l'échelle du menu à la sienne, le mode
--  sombre rend chaque texture, et la fonction de recherche de l'hôtel des ventes
--  retrouve son corps d'origine. Rien n'est laissé derrière.
--
--  `secure = true` : le module touche aux textures des barres d'action et des
--  cadres d'unités. Teinter une texture n'est pas une action protégée, mais la
--  règle est de le déclarer dès qu'on touche à ces cadres — le core diffère
--  alors l'activation à la sortie de combat, ce qui ne coûte rien ici.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local U    = BUI.Util
local W    = BUI.Widgets
local L    = ns.L

local MODULE = "General"

--- Grise une ligne tant que l'interrupteur qui la commande est éteint.
---@param key string
---@return fun(): boolean
local function requires(key)
    return function()
        local mod = BUI.Modules:Get(MODULE)
        return not (mod and mod:Get(key))
    end
end

-- =========================================================================
--  CVar
-- =========================================================================
-- Trois réglages du client se pilotent par CVar. On passe par `C_CVar` quand il
-- est là, par les globales sinon : les deux chemins existent, aucun des deux
-- n'est garanti pour toujours.

---@param name string
---@return string|nil
local function getCVar(name)
    if C_CVar and C_CVar.GetCVar then return C_CVar.GetCVar(name) end
    return GetCVar and GetCVar(name) or nil
end

---@param name string
---@param value any
local function setCVar(name, value)
    if C_CVar and C_CVar.SetCVar then
        C_CVar.SetCVar(name, value)
    elseif SetCVar then
        SetCVar(name, value)
    end
end

--- Valeurs relevées avant modification. `nil` signifie « on n'a rien changé »,
--- ce qui n'est pas la même chose que « la valeur d'origine était vide ».
local saved = {}

---@param name string
---@param value any   valeur à poser, ou `nil` pour rendre l'originale
local function overrideCVar(name, value)
    if value ~= nil then
        if saved[name] == nil then saved[name] = getCVar(name) end
        setCVar(name, value)
    elseif saved[name] ~= nil then
        setCVar(name, saved[name])
        saved[name] = nil
    end
end

local CVAR_ZOOM   = "cameraDistanceMaxZoomFactor"
local CVAR_ERRORS = "scriptErrors"

-- =========================================================================
--  Mode sombre
-- =========================================================================

--- Clé de réglage -> élément du moteur d'assombrissement, dans l'ordre où les
--- lignes se lisent sur la page.
local DARK_ELEMENTS = {
    { key = "darkUnitFrames",      element = "unitFrames" },
    { key = "darkActionBars",      element = "actionBars" },
    { key = "darkCastBar",         element = "castBar" },
    { key = "darkAuras",           element = "auras" },
    { key = "darkCooldownManager", element = "cooldownManager" },
    { key = "darkTooltip",         element = "tooltip" },
}

---@param mod table
local function applyDarkMode(mod)
    local shade = BUI.Shade
    if not shade then return end

    local on = mod:Get("darkMode")

    for i = 1, #DARK_ELEMENTS do
        local entry = DARK_ELEMENTS[i]

        -- Chaque élément est traité pour lui seul. Sans cela, un unique cadre
        -- récalcitrant sur le premier élément emporte tous les suivants dans sa
        -- chute, et le symptôme — « seule la barre d'action réagit » — ne
        -- ressemble en rien à sa cause.
        if on and mod:Get(entry.key) then
            BUI.safecall(shade.Apply, shade, entry.element, T.SHADE_FACTOR)
        else
            BUI.safecall(shade.Restore, shade, entry.element)
        end
    end
end

--- Repasse la teinte sur un élément, en groupant les rafales (règle 7).
--- Beaucoup de cadres n'existent pas au moment où le réglage est posé : les
--- auras se recréent sans arrêt, le cadre de focus se rhabille quand le focus
--- change, et une frontière de zone reconstruit une partie de l'interface.
---@param element? string
---@param now? boolean  repasser aussi tout de suite, sans attendre
---@return function
local function refresher(element, now)
    local settle = U.Debounce(T.TIMING.SHADE_SETTLE, function()
        if BUI.Shade then BUI.Shade:Refresh(element) end
    end)

    if not now then return settle end

    local function pass()
        if BUI.Shade then BUI.Shade:Refresh(element) end
    end

    -- Trois passages, et chacun couvre ce que les autres manquent. Le premier
    -- assombrit à l'instant du clic. Le deuxième, cinq centièmes plus tard,
    -- rattrape le rhabillage que le client fait **après** avoir annoncé le
    -- changement de cible — c'est lui qui supprime le contour qui « met un temps
    -- à charger ». Le troisième est le filet : il repasse une fois la rafale
    -- retombée, quoi qu'il se soit produit entre-temps.
    return function(...)
        pass()
        C_Timer.After(T.TIMING.SHADE_QUICK, pass)
        settle(...)
    end
end

local refreshAuras      = refresher("auras")
local refreshUnitFrames = refresher("unitFrames", true)

local refreshBars       = refresher("actionBars")
local refreshShade      = refresher(nil)

-- Groupé, et non traité cadre par cadre comme les auras : `RefreshLayout`
-- reconstruit l'ensemble d'un coup, et un passage complet sur quatre
-- visionneuses reste bon marché. Surtout, `Refresh` **remplace** la liste des
-- textures teintes là où `ApplyTo` y ajoute — à cette fréquence-là, ajouter
-- ferait grossir la liste sans fin (règle 7).
local refreshCooldowns  = refresher("cooldownManager")

--- S'accroche à la reconstruction des auras d'un cadre d'unité.
---
--- C'est le seul moyen d'être à l'heure. Les auras de la cible sortent d'un pool
--- que le client remplit dans `UpdateAuras`, **sans émettre d'événement** : rien
--- n'annonce leur arrivée. Repasser à intervalles après un changement de cible
--- ne fait que parier sur le moment où il s'y mettra, et ce pari se perd — d'où
--- un contour qui mettait plusieurs secondes, jusqu'à ce qu'une aura batte
--- quelque part et déclenche `UNIT_AURA`.
---
--- `U.GuardedHook` est le seul motif de hook autorisé (CLAUDE.md règle 6) : posé
--- une fois, il devient inerte quand le module s'éteint.
---
--- Le corps traite **les auras de ce cadre-là, et tout de suite**. Un
--- rafraîchissement groupé de tout l'élément serait à la fois trop cher pour
--- être immédiat et trop lent pour être invisible ; à cette granularité-là, la
--- question ne se pose pas.
---@param mod table
local function hookAuraUpdates(mod)
    local guard = function() return mod:IsEnabled() end

    local function styleAuras(frame)
        local shade = BUI.Shade
        local pools = frame and frame.auraPools
        if not (shade and pools and pools.EnumerateActive) then return end

        for aura in pools:EnumerateActive() do
            shade:ApplyTo("auras", aura)
        end
    end

    local frames = { TargetFrame, FocusFrame }
    for i = 1, #frames do
        local frame = frames[i]
        if frame and type(frame.UpdateAuras) == "function" then
            U.GuardedHook(frame, "UpdateAuras", styleAuras, guard)
        end
    end
end

--- Visionneuses du gestionnaire de temps de recharge, par nom global.
---
--- La liste double celle de `UI/Shade.lua`, et c'est assumé : là-bas elle dit
--- *quoi teinter*, ici *quand y revenir*. Les deux se remplissent en regardant le
--- même client, mais rien n'oblige la seconde à couvrir la première — une
--- visionneuse qui ne reconstruit jamais rien n'aurait pas sa place ici.
local COOLDOWN_VIEWERS = {
    "EssentialCooldownViewer", "UtilityCooldownViewer",
    "BuffIconCooldownViewer", "BuffBarCooldownViewer",
}

--- S'accroche à la reconstruction des visionneuses de temps de recharge.
---
--- Même piège que pour les auras de la cible, et il coûte plus cher ici parce
--- qu'il est plus discret. Les visionneuses sortent leurs emplacements d'un
--- pool, et **un pool crée ses cadres au moment où il en a besoin** : ceux du
--- suivi des améliorations apparaissent quand une amélioration monte, donc bien
--- après la connexion. Un cadre qui n'existe pas encore n'est l'enfant de
--- personne, aucun parcours ne peut le trouver, et rien n'annonce sa naissance.
---
--- Les visionneuses à liste fixe — essentielle, utilitaire — masquaient le
--- défaut : leurs cadres existent tous dès la connexion, donc le passage de
--- `PLAYER_ENTERING_WORLD` les attrapait et tout semblait fonctionner.
---
--- `RefreshLayout` et non `RefreshData` : la première ne s'exécute que lorsque
--- l'ensemble affiché change, la seconde à chaque tic de temps de recharge. On
--- se raccroche à ce qui bouge, pas à ce qui bat.
---@param mod table
local function hookCooldownViewers(mod)
    local guard = function() return mod:IsEnabled() end

    for i = 1, #COOLDOWN_VIEWERS do
        local viewer = _G[COOLDOWN_VIEWERS[i]]
        if viewer and type(viewer.RefreshLayout) == "function" then
            U.GuardedHook(viewer, "RefreshLayout", refreshCooldowns, guard)
        end
    end
end

-- =========================================================================
--  Caméra
-- =========================================================================

---@param mod table
local function applyCamera(mod)
    if mod:Get("maxCameraDistance") then
        overrideCVar(CVAR_ZOOM, mod:Get("cameraZoomFactor"))
    else
        overrideCVar(CVAR_ZOOM, nil)
    end
end

-- =========================================================================
--  Erreurs Lua
-- =========================================================================
-- On coupe l'affichage par la CVar du client plutôt qu'en remplaçant le
-- gestionnaire d'erreurs : les erreurs continuent d'arriver aux gestionnaires
-- installés (BugSack et consorts), seule la fenêtre de Blizzard se tait. C'est
-- exactement ce que promet l'infobulle, et c'est réversible.

---@param mod table
local function applyLuaErrors(mod)
    overrideCVar(CVAR_ERRORS, mod:Get("hideLuaErrors") and "0" or nil)
end

-- =========================================================================
--  Menu du jeu
-- =========================================================================

local savedMenuScale

---@param mod table
local function applyGameMenu(mod)
    local frame = GameMenuFrame
    if not (frame and frame.SetScale) then return end

    -- Le menu porte des boutons sécurisés : on ne le redimensionne pas en
    -- combat. La sortie de combat rappelle cette fonction (voir `OnEnable`).
    if InCombatLockdown() then return end

    if mod:Get("compactGameMenu") then
        if not savedMenuScale then savedMenuScale = frame:GetScale() end
        frame:SetScale(mod:Get("gameMenuScale") / 100)
    elseif savedMenuScale then
        frame:SetScale(savedMenuScale)
        savedMenuScale = nil
    end
end

-- =========================================================================
--  Réparation automatique
-- =========================================================================

---@param mod table
local function repairAtMerchant(mod)
    if not mod:Get("autoRepair") then return end
    if not (CanMerchantRepair and CanMerchantRepair()) then return end

    local cost, canRepair = GetRepairAllCost()
    if not canRepair or not cost or cost <= 0 then return end

    -- Fonds de guilde d'abord. Le client ne dit pas si le paiement a abouti :
    -- on redemande le coût, qui retombe à zéro quand la guilde a payé.
    if CanGuildBankRepair and CanGuildBankRepair() then
        RepairAllItems(true)
        local remaining = GetRepairAllCost()
        if not remaining or remaining <= 0 then
            mod:Print(string.format(L["Repaired from guild"], U.Money(cost)))
            return
        end
        cost = remaining
    end

    if GetMoney() < cost then
        mod:Print(string.format(L["Repair too expensive"], U.Money(cost)))
        return
    end

    RepairAllItems(false)
    mod:Print(string.format(L["Repaired from purse"], U.Money(cost)))
end

-- =========================================================================
--  Hôtel des ventes : extension actuelle uniquement
-- =========================================================================
-- Le filtre existe déjà dans le client (`Enum.AuctionHouseFilter`), il n'est
-- simplement pas mémorisé d'une recherche à l'autre. On enveloppe l'envoi de la
-- requête pour le rajouter à chaque fois.
--
-- Une enveloppe et non un `hooksecurefunc` : un hook sécurisé s'exécute *après*
-- la fonction et ne peut donc rien changer à la requête. L'enveloppe, elle, est
-- réversible — on garde le corps d'origine et on le repose à la désactivation.

--- Avons-nous coché le filtre nous-mêmes ? On ne décoche que dans ce cas : si le
--- joueur l'avait mis à la main, le décocher à la désactivation serait défaire
--- son geste et non le nôtre.
local auctionFilterSet = false

---@return number|nil
local function currentExpansionFilter()
    return Enum and Enum.AuctionHouseFilter and Enum.AuctionHouseFilter.CurrentExpansionOnly
end

--- Bouton de filtre de la barre de recherche, ou `nil` tant que l'hôtel des
--- ventes n'est pas monté.
---@return table|nil
local function auctionFilterButton()
    local frame = AuctionHouseFrame
    local bar   = frame and frame.SearchBar
    local button = bar and bar.FilterButton
    if button and type(button.filters) == "table" then return button end
    return nil
end

--- Coche (ou décoche) le filtre du client.
---
--- On ne touche pas à la requête de recherche : le filtre existe déjà dans
--- l'interface, il n'est simplement pas mémorisé d'une ouverture à l'autre.
--- Cocher **sa** case laisse le client faire le reste, et l'état affiché reste
--- vrai — envelopper l'envoi de la requête filtrerait les résultats en laissant
--- la case décochée, ce qui donnerait une fenêtre qui ment.
---
--- `filters` est un **ensemble** indexé par la valeur d'énumération, pas une
--- liste : on écrit à cet index, on n'empile pas.
---@param on boolean
---@return boolean applied
local function setAuctionFilter(on)
    local button = auctionFilterButton()
    local filter = currentExpansionFilter()
    if not (button and filter) then return false end

    button.filters[filter] = on or nil

    local bar = AuctionHouseFrame.SearchBar
    if bar.UpdateClearFiltersButton then bar:UpdateClearFiltersButton() end
    return true
end

---@param mod table
local function applyAuctionFilter(mod)
    if not mod:Get("auctionCurrentXP") then
        if auctionFilterSet and setAuctionFilter(false) then auctionFilterSet = false end
        return
    end

    -- Le bouton n'est construit qu'après l'événement d'ouverture : on laisse
    -- passer une image avant d'aller le chercher.
    C_Timer.After(0, function()
        if not mod:Get("auctionCurrentXP") then return end
        if setAuctionFilter(true) then auctionFilterSet = true end
    end)
end

-- =========================================================================
--  Nuisances : cinématiques et têtes parlantes
-- =========================================================================

---@param mod table
local function skipCinematic(mod)
    if not mod:Get("skipCinematics") then return end
    if CinematicFrame_CancelCinematic then CinematicFrame_CancelCinematic() end
end

---@param mod table
local function skipMovie(mod)
    if not mod:Get("skipCinematics") then return end
    if GameMovieFinished then GameMovieFinished() end
end

---@param mod table
local function hideTalkingHead(mod)
    if not mod:Get("hideTalkingHead") then return end

    -- La fenêtre est montée après l'événement, et son addon peut n'être chargé
    -- qu'à cet instant : on la ferme au tour suivant, pas tout de suite.
    C_Timer.After(0, function()
        if TalkingHeadFrame_CloseImmediately then
            TalkingHeadFrame_CloseImmediately()
            return
        end
        local frame = TalkingHeadFrame
        if frame and frame.Hide then frame:Hide() end
    end)
end

-- =========================================================================
--  Minuteur des fenêtres de file d'attente
-- =========================================================================

--- Durée d'une proposition de groupe, en secondes.
---
--- Le client publie l'échéance des invitations de champ de bataille
--- (`GetBattlefieldPortExpiration`) mais **rien** pour une proposition de
--- donjon : ni fonction, ni constante. Ce nombre est donc le délai que le client
--- applique, mesuré et non déduit — voir `dev/docs/API_NOTES.md`. S'il change un
--- jour, c'est ici et nulle part ailleurs.
local PROPOSAL_SECONDS = 40

--- fenêtre du client -> décompte qu'on lui a posé
local countdowns = {}

---@param parent table
---@param source fun(): number|nil
---@param total number  durée pleine, qui donne sa couleur au décompte
local function watch(parent, source, total)
    local countdown = countdowns[parent]
    if not countdown then
        countdown = W.Countdown(parent)
        if not countdown then return end
        -- Au centre de la fenêtre : c'est là que le regard est déjà, et c'est la
        -- seule position qui vaille pour les deux fenêtres, qui n'ont ni la même
        -- taille ni la même disposition.
        countdown:SetPoint("CENTER", parent, "CENTER")
        countdowns[parent] = countdown
    end
    countdown:Watch(source, total)
end

local function stopCountdowns()
    for _, countdown in pairs(countdowns) do
        countdown:Stop()
    end
end

---@param mod table
local function watchProposal(mod)
    if not mod:Get("queueTimer") then return end

    -- Le cadre qui s'affiche est le **dialogue**, pas le popup qui le porte :
    -- coiffer le second poserait le décompte sur un conteneur invisible.
    local dialog = LFGDungeonReadyDialog or LFGDungeonReadyPopup
    if not dialog then return end

    local total    = PROPOSAL_SECONDS
    local deadline = GetTime() + total

    watch(dialog, function()
        local remaining = deadline - GetTime()
        if remaining <= 0 then return nil end
        return remaining
    end, total)
end

--- Secondes restantes pour accepter une entrée en champ de bataille ou en
--- arène, prises sur le client lui-même.
---@return number|nil
local function portExpiration()
    if not (GetMaxBattlefieldID and GetBattlefieldStatus and GetBattlefieldPortExpiration) then
        return nil
    end
    for i = 1, GetMaxBattlefieldID() do
        if GetBattlefieldStatus(i) == "confirm" then
            local remaining = GetBattlefieldPortExpiration(i)
            if remaining and remaining > 0 then return remaining end
        end
    end
    return nil
end

---@param mod table
local function watchBattlefield(mod)
    if not mod:Get("queueTimer") then return end

    local dialog = PVPReadyDialog
    if not (dialog and dialog:IsShown()) then return end

    -- La durée pleine est ce qui reste au moment où la fenêtre s'ouvre : le
    -- client ne publie que le temps restant, jamais le délai qu'il a accordé.
    local remaining = portExpiration()
    if not remaining then return end

    watch(dialog, portExpiration, remaining)
end

-- =========================================================================
--  Application d'ensemble
-- =========================================================================

---@param mod table
local function applyAll(mod)
    applyDarkMode(mod)
    applyCamera(mod)
    applyLuaErrors(mod)
    applyGameMenu(mod)
    applyAuctionFilter(mod)
end

--- Réglage -> fonction qui le pose. Les réglages absents de cette table ne
--- s'appliquent pas : ils se lisent au moment où l'événement arrive.
local APPLIERS = {
    darkMode          = applyDarkMode,
    maxCameraDistance = applyCamera,
    cameraZoomFactor  = applyCamera,
    hideLuaErrors     = applyLuaErrors,
    compactGameMenu   = applyGameMenu,
    gameMenuScale     = applyGameMenu,
    auctionCurrentXP  = applyAuctionFilter,

    -- Décocher le minuteur pendant qu'une fenêtre de file est ouverte doit le
    -- faire disparaître tout de suite, pas à la fenêtre suivante.
    queueTimer        = function(mod)
        if not mod:Get("queueTimer") then stopCountdowns() end
    end,
}

for i = 1, #DARK_ELEMENTS do
    APPLIERS[DARK_ELEMENTS[i].key] = applyDarkMode
end

-- =========================================================================
--  Déclaration du module
-- =========================================================================

BUI:RegisterModule(MODULE, {
    title    = L["General"],
    category = "Game",
    order    = 10,
    secure   = true,

    defaults = {
        -- Le mode sombre est éteint, mais la liste de ce qu'il assombrit est
        -- cochée d'avance : l'allumer doit produire un effet visible tout de
        -- suite, décocher ensuite ce qu'on veut garder clair est le geste rare.
        -- Il n'y a pas de dosage — c'est la liste qui se règle, pas la
        -- profondeur du noir (voir `T.SHADE_FACTOR`).
        darkMode            = false,
        darkUnitFrames      = true,
        darkActionBars      = true,
        darkCastBar         = true,
        darkAuras           = true,
        darkCooldownManager = true,
        darkTooltip         = true,

        maxCameraDistance = false,
        cameraZoomFactor  = 2.9,

        compactGameMenu = false,
        gameMenuScale   = 75,

        queueTimer = false,

        autoRepair       = false,
        auctionCurrentXP = false,

        skipCinematics  = false,
        hideTalkingHead = false,
        hideLuaErrors   = false,
    },

    options = {
        { type = "header", text = L["Dark mode"] },
        {
            type    = "toggle",
            key     = "darkMode",
            text    = L["Enable dark mode"],
            tooltip = L["Dark mode tip"],
        },
        {
            type     = "toggle",
            key      = "darkUnitFrames",
            text     = L["Unit frames"],
            tooltip  = L["Dark unit frames tip"],
            disabled = requires("darkMode"),
        },
        {
            type     = "toggle",
            key      = "darkActionBars",
            text     = L["Action bars"],
            tooltip  = L["Dark action bars tip"],
            disabled = requires("darkMode"),
        },
        {
            type     = "toggle",
            key      = "darkCastBar",
            text     = L["Cast bar"],
            tooltip  = L["Dark cast bar tip"],
            disabled = requires("darkMode"),
        },
        {
            type     = "toggle",
            key      = "darkAuras",
            text     = L["Buffs and debuffs"],
            tooltip  = L["Dark auras tip"],
            disabled = requires("darkMode"),
        },
        {
            type     = "toggle",
            key      = "darkCooldownManager",
            text     = L["Cooldown manager"],
            tooltip  = L["Dark cooldown manager tip"],
            disabled = requires("darkMode"),
        },
        {
            type     = "toggle",
            key      = "darkTooltip",
            text     = L["Tooltip"],
            tooltip  = L["Dark tooltip tip"],
            disabled = requires("darkMode"),
        },

        { type = "header", text = L["Camera"] },
        {
            type    = "toggle",
            key     = "maxCameraDistance",
            text    = L["Max camera distance"],
            tooltip = L["Max camera distance tip"],
        },
        {
            type     = "slider",
            key      = "cameraZoomFactor",
            text     = L["Camera zoom factor"],
            tooltip  = L["Camera zoom factor tip"],
            min      = 1,
            max      = 2.9,
            step     = 0.1,
            decimals = 1,
            disabled = requires("maxCameraDistance"),
        },

        { type = "header", text = L["Game menu"] },
        {
            type    = "toggle",
            key     = "compactGameMenu",
            text    = L["Compact game menu"],
            tooltip = L["Compact game menu tip"],
        },
        {
            type     = "slider",
            key      = "gameMenuScale",
            text     = L["Game menu scale"],
            tooltip  = L["Game menu scale tip"],
            min      = 50,
            max      = 100,
            step     = 5,
            disabled = requires("compactGameMenu"),
        },

        { type = "header", text = L["Queues"] },
        {
            type    = "toggle",
            key     = "queueTimer",
            text    = L["Queue popup timer"],
            tooltip = L["Queue popup timer tip"],
        },

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

    OnEnable = function(self)
        applyAll(self)
        hookAuraUpdates(self)
        hookCooldownViewers(self)

        self:RegisterEvent("MERCHANT_SHOW",    function() repairAtMerchant(self) end)
        self:RegisterEvent("CINEMATIC_START",  function() skipCinematic(self) end)
        self:RegisterEvent("PLAY_MOVIE",       function() skipMovie(self) end)
        self:RegisterEvent("TALKINGHEAD_REQUESTED", function() hideTalkingHead(self) end)

        self:RegisterEvent("LFG_PROPOSAL_SHOW",         function() watchProposal(self) end)
        self:RegisterEvent("UPDATE_BATTLEFIELD_STATUS", function() watchBattlefield(self) end)

        -- Le cadre de l'hôtel des ventes se charge à la demande : c'est ici, et
        -- pas à l'activation du module, qu'il devient enveloppable.
        self:RegisterEvent("AUCTION_HOUSE_SHOW", function() applyAuctionFilter(self) end)

        -- Le mode sombre se repose sur ce qui apparaît après lui : les auras se
        -- recréent sans cesse, les fenêtres chargées à la demande arrivent en
        -- cours de session, et une frontière de zone reconstruit une partie de
        -- l'interface.
        self:RegisterEvent("UNIT_AURA",             refreshAuras)
        -- Les auras posées sous le personnage apparaissent avec la barre de nom
        -- du joueur, pas avec le joueur : elles arrivent donc par cet
        -- événement-là et par aucun autre.
        self:RegisterEvent("NAME_PLATE_UNIT_ADDED", refreshAuras)
        self:RegisterEvent("ADDON_LOADED",          refreshShade)
        self:RegisterEvent("PLAYER_ENTERING_WORLD", refreshShade)

        self:RegisterEvent("PLAYER_TARGET_CHANGED", refreshUnitFrames)
        self:RegisterEvent("PLAYER_FOCUS_CHANGED",  refreshUnitFrames)
        self:RegisterEvent("UNIT_PET",              refreshUnitFrames)

        -- Les auras de la cible ne sont pas rafraîchies ici : `hookAuraUpdates`
        -- les traite au moment exact où le client les reconstruit, une par une.
        -- Un passage de plus sur le changement de cible ne ferait que repasser
        -- derrière lui.

        self:RegisterEvent("ACTIONBAR_PAGE_CHANGED",  refreshBars)
        self:RegisterEvent("ACTIONBAR_SLOT_CHANGED",  refreshBars)
        self:RegisterEvent("UPDATE_SHAPESHIFT_FORMS", refreshBars)


        -- L'échelle du menu ne se pose pas en combat : ce qui a été refusé
        -- pendant le combat est rattrapé ici.
        self:RegisterEvent("PLAYER_REGEN_ENABLED", function() applyGameMenu(self) end)
    end,

    OnDisable = function()
        if BUI.Shade then BUI.Shade:RestoreAll() end

        overrideCVar(CVAR_ZOOM, nil)
        overrideCVar(CVAR_ERRORS, nil)

        local frame = GameMenuFrame
        if savedMenuScale and frame and frame.SetScale then
            frame:SetScale(savedMenuScale)
            savedMenuScale = nil
        end

        if auctionFilterSet and setAuctionFilter(false) then auctionFilterSet = false end

        stopCountdowns()
    end,

    OnSettingChanged = function(self, key)
        if key == nil then
            applyAll(self)
            return
        end

        local apply = APPLIERS[key]
        if apply then apply(self) end
    end,
})
