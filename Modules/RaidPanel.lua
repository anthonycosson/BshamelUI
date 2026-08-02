-- =========================================================================
--  Bshamel UI — Modules/RaidPanel.lua
--  Le panneau d'outils de groupe, et celui du client qu'il remplace.
--
--  Les deux sont le même sujet, et c'est pour cela qu'ils sont sur la même page :
--  le gestionnaire de cadres de raid du client porte exactement les mêmes outils
--  que notre barre — marqueurs, vérification de présence, décompte — dans un
--  onglet qui pousse le bord gauche de l'écran. Allumer l'un et masquer l'autre
--  est un seul geste, et les séparer laissait deux pages dont aucune ne disait
--  qu'on choisit entre elles.
--
--  Le module ne dessine rien : `UI/Widgets/MarkerBar.lua` sait afficher le
--  panneau, ce fichier dit quoi y mettre et ce que chaque bouton annonce.
--
--  Le panneau du client n'est pas caché mais **rangé** sous un parent masqué
--  (`W.Hidden`), ce qui le rend indétectable sans lui disputer sa logique
--  d'affichage : lui rendre son parent le remet exactement où il était (voir
--  `dev/docs/API_NOTES.md`).
--
--  Ces réglages vivaient dans *Outils de raid*, qui en tenait quatre sans rapport
--  entre eux. Un palier de migration (`Core/DB.lua`) les suit.
--
--  `secure = true` : la barre est faite de boutons d'action sécurisés — poser un
--  marqueur au sol est une action protégée —, et le panneau du client est un
--  cadre protégé, que reparenter en combat lève. Le core diffère donc
--  l'activation à la sortie de combat.
--
--  Réversibilité (règle 6) : notre panneau se cache, celui du client retrouve son
--  parent donc sa place.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local W    = BUI.Widgets
local L    = ns.L

local MODULE = "RaidPanel"

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
--  Le groupe
-- =========================================================================

--- Canal de discussion du groupe, ou `nil` si le personnage est seul.
---
--- L'ordre compte : un groupe d'instance formé par la recherche de groupe parle
--- sur son propre canal, et un message envoyé à « RAID » n'y arriverait pas.
---@return string|nil
local function groupChannel()
    local instance = (Enum and Enum.PartyCategory and Enum.PartyCategory.Instance)
                     or LE_PARTY_CATEGORY_INSTANCE
    if instance and IsInGroup(instance) then return "INSTANCE_CHAT" end
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
    return nil
end

--- Le personnage peut-il donner un ordre au groupe ? Le client refuse une
--- vérification de présence ou un décompte à qui n'est ni chef ni promu, et il
--- le refuse en silence : mieux vaut le dire.
---@return boolean
local function canLead()
    if not IsInGroup() then return false end
    return (UnitIsGroupLeader and UnitIsGroupLeader("player"))
        or (UnitIsGroupAssistant and UnitIsGroupAssistant("player"))
        or false
end

-- =========================================================================
--  Notre panneau
-- =========================================================================

local markerBar

---@param mod table
local function startPull(mod)
    if not canLead() then
        mod:Print(L["Need lead"])
        return
    end

    local seconds = mod:Get("pullTimer")

    -- Le décompte du client d'abord : il s'affiche chez tout le monde, y compris
    -- chez ceux qui n'ont aucun addon, et les outils de raid des autres
    -- l'écoutent. On n'en dessine pas un second (« emprunter avant de créer »).
    if C_PartyInfo and C_PartyInfo.DoCountdown then
        C_PartyInfo.DoCountdown(seconds)
    end

    local channel = groupChannel()
    if channel then
        SendChatMessage(string.format(L["Pull announce"], seconds), channel)
    end
end

---@param mod table
local function startReadyCheck(mod)
    if not canLead() then
        mod:Print(L["Need lead"])
        return
    end
    if DoReadyCheck then DoReadyCheck() end
end

---@param mod table
local function applyMarkerBar(mod)
    if not mod:Get("worldMarkers") then
        if markerBar then markerBar:SetShownOutOfCombat(false) end
        return
    end

    if not markerBar then
        markerBar = W.MarkerBar({
            getPos      = function() return mod:Get("markerX"), mod:Get("markerY") end,
            setPos      = function(x, y)
                mod:Set("markerX", x)
                mod:Set("markerY", y)
            end,
            getScale    = function() return mod:Get("markerScale") end,
            setScale    = function(scale) mod:Set("markerScale", scale) end,
            isLocked    = function() return mod:Get("lockMarkers") == true end,
            markerLabel = L["World marker number"],
            markerTip   = L["World marker tip"],
            clearLabel  = L["Clear markers"],
            clearTip    = L["Clear markers tip"],
            readyLabel  = L["Ready"],
            readyTip    = L["Ready check tip"],
            pullLabel   = L["Pull"],
            pullTip     = L["Pull tip"],
            onReadyCheck = function() startReadyCheck(mod) end,
            onPull       = function() startPull(mod) end,
        })
        if not markerBar then return end
    end

    markerBar:SetPullLabel(string.format(L["Pull seconds"], mod:Get("pullTimer")))
    markerBar:SetRevealOnHover(mod:Get("markersOnHover") == true)
    markerBar:ApplyScale()
    markerBar:ApplyLock()
    markerBar:ApplyPosition()
    markerBar:SetShownOutOfCombat(true)
end

-- =========================================================================
--  Le panneau du client
-- =========================================================================

local savedParent

---@param mod table
local function applyHideManager(mod)
    local frame = CompactRaidFrameManager
    if not (frame and frame.SetParent) then return end

    -- Cadre protégé : reparenter en combat lève une erreur d'action bloquée.
    -- La sortie de combat rappelle cette fonction (voir `OnEnable`).
    if InCombatLockdown() then return end

    if mod:Get("hideBlizzardPanel") then
        if not savedParent then savedParent = frame:GetParent() end
        frame:SetParent(W.Hidden())
    elseif savedParent then
        frame:SetParent(savedParent)
        savedParent = nil
    end
end

-- =========================================================================
--  Application d'ensemble
-- =========================================================================

---@param mod table
local function applyAll(mod)
    applyMarkerBar(mod)
    applyHideManager(mod)
end

local APPLIERS = {
    worldMarkers      = applyMarkerBar,
    lockMarkers       = applyMarkerBar,
    markersOnHover    = applyMarkerBar,
    pullTimer         = applyMarkerBar,
    hideBlizzardPanel = applyHideManager,
}

-- =========================================================================
--  Déclaration du module
-- =========================================================================

BUI:RegisterModule(MODULE, {
    title    = L["Raid manager"],
    category = "MythicRaid",
    order    = 10,
    secure   = true,

    defaults = {
        worldMarkers = false,
        markerX      = 0,
        markerY      = -220,
        -- Échelle du panneau, sans contrôle : elle se change en tirant le coin.
        -- Sa disposition, elle, ne se règle pas.
        markerScale    = 1,
        lockMarkers    = false,
        markersOnHover = false,
        pullTimer      = 8,

        -- Éteint, comme **tout** le reste de l'addon. Il a été allumé par défaut
        -- un temps, au motif que ce panneau fait double emploi avec le nôtre —
        -- sauf que le nôtre est éteint lui aussi sur une installation neuve. Le
        -- réglage ne remplaçait donc rien : il faisait disparaître un morceau de
        -- l'interface du jeu au premier lancement, sans que personne l'ait
        -- demandé. Installer Bshamel UI ne doit rien changer tant qu'on n'a rien
        -- coché.
        hideBlizzardPanel = false,
    },

    options = {
        { type = "header", text = L["Group tools"] },
        {
            type    = "toggle",
            key     = "worldMarkers",
            text    = L["World markers"],
            tooltip = L["World markers tip"],
        },
        {
            type     = "toggle",
            key      = "lockMarkers",
            text     = L["Lock group tools"],
            tooltip  = L["Lock group tools tip"],
            disabled = requires("worldMarkers"),
        },
        {
            type     = "toggle",
            key      = "markersOnHover",
            text     = L["Group tools on hover"],
            tooltip  = L["Group tools on hover tip"],
            disabled = requires("worldMarkers"),
        },
        {
            type     = "slider",
            key      = "pullTimer",
            text     = L["Pull timer"],
            tooltip  = L["Pull timer tip"],
            min      = 3,
            max      = 20,
            step     = 1,
            disabled = requires("worldMarkers"),
        },
        { type = "description", text = L["Group tools notice"] },

        { type = "header", text = L["Blizzard panel"] },
        {
            type    = "toggle",
            key     = "hideBlizzardPanel",
            text    = L["Hide raid manager"],
            tooltip = L["Hide raid manager tip"],
        },
        { type = "description", text = L["Raid manager notice"] },
    },

    OnEnable = function(self)
        applyAll(self)

        -- Un cadre protégé ne se reparente pas en combat, et une barre de boutons
        -- sécurisés ne se montre ni ne se cache : ce qui a été refusé pendant le
        -- combat est rattrapé ici.
        self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
            applyHideManager(self)
            applyMarkerBar(self)
        end)
    end,

    OnDisable = function()
        if markerBar then markerBar:SetShownOutOfCombat(false) end

        -- Le panneau du client revient, quoi que dise le réglage : désactiver un
        -- module doit le rendre indétectable (règle 6).
        local frame = CompactRaidFrameManager
        if savedParent and frame and not InCombatLockdown() then
            frame:SetParent(savedParent)
            savedParent = nil
        end
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
