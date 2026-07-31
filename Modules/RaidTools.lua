-- =========================================================================
--  Bshamel UI — Modules/RaidTools.lua
--  Ce dont on a besoin pendant un raid ou une clé mythique.
--
--  Quatre outils, une seule page : ils se cherchent tous au même moment — juste
--  avant un pull — et les éclater en quatre pages rendrait chacun introuvable.
--
--  Le module ne dessine rien. Il dit *quoi* compter et *quoi* annoncer ; le
--  suivi des résurrections (`UI/Widgets/BattleRes.lua`) et le panneau d'outils
--  de groupe (`UI/Widgets/MarkerBar.lua`) savent l'afficher. C'est la même
--  séparation que partout ailleurs dans l'addon.
--
--  `secure = true` : la barre de marqueurs est faite de boutons d'action
--  sécurisés — poser un marqueur au sol est une action protégée, refusée au code
--  Lua ordinaire. Le core diffère donc l'activation à la sortie de combat.
--
--  Réversibilité (règle 6) : les deux panneaux se cachent, le panneau de contrôle
--  du client retrouve son parent, la journalisation s'arrête si c'est nous qui
--  l'avions allumée, et la CVar de journalisation détaillée est reposée à sa
--  valeur d'origine.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local U    = BUI.Util
local W    = BUI.Widgets
local L    = ns.L

local MODULE = "RaidTools"

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
--  Instances
-- =========================================================================

--- Type de l'instance courante, ou `nil` en extérieur.
---@return string|nil
local function instanceType()
    if not GetInstanceInfo then return nil end
    local _, kind = GetInstanceInfo()
    if kind == "none" then return nil end
    return kind
end

---@return boolean
local function inChallenge()
    return C_ChallengeMode ~= nil
        and C_ChallengeMode.IsChallengeModeActive ~= nil
        and C_ChallengeMode.IsChallengeModeActive() == true
end

-- =========================================================================
--  Suivi des résurrections de combat
-- =========================================================================
-- Le client tient un compteur de résurrections **partagé par le groupe** dans
-- les instances qui en limitent l'usage, et il le publie sous les charges du
-- sort de Rétablissement du druide — pour tout le monde, druide ou non. C'est le
-- seul chemin publié ; voir `dev/docs/API_NOTES.md`.

local BATTLE_RES_SPELL = 20484

local tracker
--- Relevés rendus au widget. Réutilisés : ils sont relus plusieurs fois par
--- seconde, et un chemin qui bat n'alloue pas (règle 7).
local resInfo = {}
local rawRes  = {}

---@return table|nil
local function readBattleRes()
    if C_Spell and C_Spell.GetSpellCharges then
        local info = C_Spell.GetSpellCharges(BATTLE_RES_SPELL)
        if not info then return nil end

        rawRes.charges  = info.currentCharges
        rawRes.max      = info.maxCharges
        rawRes.start    = info.cooldownStartTime
        rawRes.duration = info.cooldownDuration
        return rawRes
    end

    if GetSpellCharges then
        local charges, max, start, duration = GetSpellCharges(BATTLE_RES_SPELL)
        if not charges then return nil end

        rawRes.charges  = charges
        rawRes.max      = max
        rawRes.start    = start
        rawRes.duration = duration
        return rawRes
    end

    return nil
end

--- Relevé d'exemple du mode aperçu. L'icône ne s'affiche que là où il y a une
--- réserve à compter — c'est-à-dire nulle part au moment précis où l'on cherche
--- où la poser. Même parti pris que le chrono mythique+ (`Modules/MythicTimer.lua`).
local PREVIEW = { charges = 1, maxCharges = 1, remaining = 90, duration = 600 }

---@param mod table
---@return BUI.BattleResInfo|nil
local function battleResSource(mod)
    -- Hors instance, ou seul, il n'y a pas de réserve partagée à suivre : l'icône
    -- n'a rien à dire et se cache d'elle-même.
    local kind = instanceType()
    local live = (kind == "raid" or kind == "party" or inChallenge()) and IsInGroup()

    if not live then
        if mod:Get("battleResPreview") then return PREVIEW end
        return nil
    end

    local raw = readBattleRes()
    if not (raw and raw.max and raw.max > 0) then
        if mod:Get("battleResPreview") then return PREVIEW end
        return nil
    end

    resInfo.charges   = raw.charges or 0
    resInfo.maxCharges = raw.max
    resInfo.remaining = nil
    resInfo.duration  = nil

    if raw.start and raw.start > 0 and raw.duration and raw.duration > 0 then
        local remaining = raw.start + raw.duration - GetTime()
        if remaining > 0 then
            resInfo.remaining = remaining
            resInfo.duration  = raw.duration
        end
    end

    return resInfo
end

--- Icône du suivi : celle du sort lui-même, demandée au client.
---@return number|string|nil
local function battleResIcon()
    if C_Spell and C_Spell.GetSpellTexture then
        return C_Spell.GetSpellTexture(BATTLE_RES_SPELL)
    end
    return nil
end

---@param mod table
local function applyBattleRes(mod)
    if not mod:Get("battleResTracker") then
        if tracker then tracker:Stop() end
        return
    end

    if not tracker then
        tracker = W.BattleResTracker({
            source = function() return battleResSource(mod) end,
            isLocked = function() return mod:Get("lockBattleRes") == true end,
            getPos = function() return mod:Get("battleResX"), mod:Get("battleResY") end,
            setPos = function(x, y)
                mod:Set("battleResX", x)
                mod:Set("battleResY", y)
            end,
        })
        if not tracker then return end
        tracker:SetIcon(battleResIcon())
    end

    tracker:SetIconSize(mod:Get("battleResSize"))
    -- Le contour sombre est **son** réglage, pas celui du mode sombre général :
    -- cette icône vit au milieu de l'écran d'un combat de raid, et le choix de
    -- l'y détourer ou non n'a rien à voir avec celui d'assombrir les barres
    -- d'action. Elle se règle donc là où on l'allume.
    tracker:SetShaded(mod:Get("battleResShaded") == true)
    tracker:ApplyPosition()
    tracker:Start()
end

-- =========================================================================
--  Panneau d'outils de groupe
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
--  Panneau de contrôle du client
-- =========================================================================
-- Le gestionnaire de cadres de raid porte les mêmes outils que notre barre, dans
-- un onglet qui pousse le bord de l'écran. On ne le cache pas : on le **range**
-- sous un parent masqué (`W.Hidden`), ce qui le rend indétectable sans lui
-- disputer sa logique d'affichage, et lui rendre son parent le remet exactement
-- où il était (voir `dev/docs/API_NOTES.md`).

local savedManagerParent

---@param mod table
local function applyHideManager(mod)
    local frame = CompactRaidFrameManager
    if not (frame and frame.SetParent) then return end

    -- Cadre protégé : reparenter en combat lève une erreur d'action bloquée.
    -- La sortie de combat rappelle cette fonction (voir `OnEnable`).
    if InCombatLockdown() then return end

    if mod:Get("hideBlizzardPanel") then
        if not savedManagerParent then savedManagerParent = frame:GetParent() end
        frame:SetParent(W.Hidden())
    elseif savedManagerParent then
        frame:SetParent(savedManagerParent)
        savedManagerParent = nil
    end
end

-- =========================================================================
--  Journalisation automatique
-- =========================================================================
-- La journalisation détaillée est une CVar : sans elle, le journal produit ne
-- porte ni positions ni ressources, et les sites d'analyse n'en tirent presque
-- rien. Elle est relevée avant d'être changée et reposée à l'extinction, comme
-- toutes les CVar de l'addon.

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
--  Application d'ensemble
-- =========================================================================

---@param mod table
local function applyAll(mod)
    applyBattleRes(mod)
    applyMarkerBar(mod)
    applyHideManager(mod)
    applyLogging(mod)
end

local APPLIERS = {
    battleResTracker  = applyBattleRes,
    battleResSize     = applyBattleRes,
    battleResShaded   = applyBattleRes,
    battleResPreview  = applyBattleRes,
    lockBattleRes     = applyBattleRes,
    worldMarkers      = applyMarkerBar,
    lockMarkers       = applyMarkerBar,
    markersOnHover    = applyMarkerBar,
    pullTimer         = applyMarkerBar,
    hideBlizzardPanel = applyHideManager,
    autoCombatLog     = toggleLogging,
}

-- =========================================================================
--  Déclaration du module
-- =========================================================================

BUI:RegisterModule(MODULE, {
    title    = L["Raid tools"],
    category = "MythicRaid",
    order    = 20,
    secure   = true,

    defaults = {
        battleResTracker = false,
        battleResShaded  = false,
        battleResPreview = false,
        lockBattleRes    = false,
        battleResSize    = T.SIZE.BATTLE_RES_ICON,
        -- Position de l'icône, en décalage de centre à centre. Réglages sans
        -- contrôle : ils se changent en la déplaçant à la souris.
        battleResX = 0,
        battleResY = 0,

        worldMarkers = false,
        markerX      = 0,
        markerY      = -220,
        -- Échelle du panneau, elle aussi sans contrôle : elle se change en
        -- tirant le coin. Sa disposition, elle, ne se règle pas.
        markerScale    = 1,
        lockMarkers    = false,
        markersOnHover = false,
        pullTimer      = 8,

        -- Allumé par défaut, seul réglage du module dans ce cas : le panneau de
        -- contrôle du client porte les mêmes outils que le nôtre, et les deux
        -- côte à côte ne servent qu'à se demander lequel on regarde. Qui préfère
        -- le sien l'éteint ici.
        hideBlizzardPanel = true,

        autoCombatLog = false,
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
            type     = "slider",
            key      = "battleResSize",
            text     = L["Battle res size"],
            tooltip  = L["Battle res size tip"],
            min      = T.SIZE.BATTLE_RES_MIN,
            max      = T.SIZE.BATTLE_RES_MAX,
            step     = 2,
            disabled = requires("battleResTracker"),
        },
        {
            type     = "toggle",
            key      = "battleResShaded",
            text     = L["Battle res shaded"],
            tooltip  = L["Battle res shaded tip"],
            disabled = requires("battleResTracker"),
        },
        {
            type     = "toggle",
            key      = "lockBattleRes",
            text     = L["Lock battle res"],
            tooltip  = L["Lock battle res tip"],
            disabled = requires("battleResTracker"),
        },
        {
            type     = "toggle",
            key      = "battleResPreview",
            text     = L["Battle res preview"],
            tooltip  = L["Battle res preview tip"],
            disabled = requires("battleResTracker"),
        },

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
        {
            type    = "toggle",
            key     = "hideBlizzardPanel",
            text    = L["Hide raid manager"],
            tooltip = L["Hide raid manager tip"],
        },
        { type = "description", text = L["Group tools notice"] },

        { type = "header", text = L["Logging"] },
        {
            type    = "toggle",
            key     = "autoCombatLog",
            text    = L["Auto combat logging"],
            tooltip = L["Auto combat logging tip"],
        },
    },

    OnEnable = function(self)
        applyAll(self)

        -- Ce qui décide de la journalisation et de l'affichage du suivi change
        -- au passage d'une frontière d'instance, et nulle part ailleurs.
        local zoned = function()
            applyLogging(self)
            applyBattleRes(self)
        end
        self:RegisterEvent("PLAYER_ENTERING_WORLD",  zoned)
        self:RegisterEvent("ZONE_CHANGED_NEW_AREA",  zoned)
        self:RegisterEvent("CHALLENGE_MODE_START",   zoned)
        self:RegisterEvent("CHALLENGE_MODE_COMPLETED", zoned)
        self:RegisterEvent("CHALLENGE_MODE_RESET",   zoned)

        -- Un cadre protégé ne se reparente pas en combat, et une barre de
        -- boutons sécurisés ne se montre ni ne se cache : ce que le combat a
        -- refusé est rattrapé ici.
        self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
            applyHideManager(self)
            applyMarkerBar(self)
        end)
    end,

    OnDisable = function()
        if tracker then tracker:Stop() end
        if markerBar then markerBar:SetShownOutOfCombat(false) end

        -- Le panneau du client revient, quoi que dise le réglage : désactiver un
        -- module doit le rendre indétectable (règle 6).
        local frame = CompactRaidFrameManager
        if savedManagerParent and frame and not InCombatLockdown() then
            frame:SetParent(savedManagerParent)
            savedManagerParent = nil
        end

        if loggingStarted then
            if LoggingCombat then LoggingCombat(false) end
            if savedAdvanced ~= nil then
                U.SetCVar(CVAR_ADVANCED, savedAdvanced)
                savedAdvanced = nil
            end
            loggingStarted = false
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
