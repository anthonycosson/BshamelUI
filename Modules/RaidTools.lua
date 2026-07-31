-- =========================================================================
--  Bshamel UI — Modules/RaidTools.lua
--  Ce dont on a besoin pendant un raid ou une clé mythique.
--
--  Six outils, une seule page : ils se cherchent tous au même moment — juste
--  avant un pull — et les éclater en six pages rendrait chacun introuvable.
--
--  Le module ne dessine rien. Il dit *quoi* compter et *quoi* annoncer ; le
--  suivi des résurrections (`UI/Widgets/BattleRes.lua`) et la barre de marqueurs
--  (`UI/Widgets/MarkerBar.lua`) savent l'afficher. C'est la même séparation que
--  partout ailleurs dans l'addon.
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

--- Unités du groupe, personnage compris. Table de travail réutilisée : la liste
--- se reconstruit à chaque vérification de présence (règle 7).
local units = {}

---@return string[]
local function groupUnits()
    wipe(units)

    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            units[#units + 1] = "raid" .. i
        end
        return units
    end

    units[1] = "player"
    for i = 1, GetNumGroupMembers() - 1 do
        units[#units + 1] = "party" .. i
    end
    return units
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
--  Annonce des morts
-- =========================================================================
-- Le journal de combat est le seul endroit où la mort d'un membre du groupe est
-- annoncée pour tout le monde : `UNIT_HEALTH` ne parle que des unités affichées,
-- et un raid de vingt personnes n'en affiche pas vingt.

--- Noms accumulés depuis la dernière annonce. Table de travail : le journal de
--- combat est un chemin chaud, on n'y alloue rien (règle 7).
local deaths = {}

--- La mort concerne-t-elle un joueur de notre groupe ?
---
--- On lit les **drapeaux** du journal plutôt que de comparer des noms : un nom
--- de joueur d'un autre royaume porte un suffixe, et la comparaison échouerait
--- précisément sur les groupes formés par la recherche de groupe.
---@param flags number
---@return boolean
local function isGroupPlayer(flags)
    if not (bit and flags) then return false end

    local isPlayer = bit.band(flags, COMBATLOG_OBJECT_TYPE_PLAYER or 0) ~= 0
    if not isPlayer then return false end

    local mine = (COMBATLOG_OBJECT_AFFILIATION_MINE  or 0)
    local party = (COMBATLOG_OBJECT_AFFILIATION_PARTY or 0)
    local raid  = (COMBATLOG_OBJECT_AFFILIATION_RAID  or 0)

    return bit.band(flags, mine + party + raid) ~= 0
end

---@param mod table
local function flushDeaths(mod)
    if #deaths == 0 then return end

    local channel = groupChannel()
    if channel then
        SendChatMessage(string.format(L["Death announce"], table.concat(deaths, ", ")), channel)
    end

    -- Un seul son pour la rafale, comme il n'y a qu'un seul message : vingt
    -- alertes en une seconde ne sont plus une alerte.
    if mod:Get("deathSound") and PlaySound and SOUNDKIT and SOUNDKIT.RAID_WARNING then
        PlaySound(SOUNDKIT.RAID_WARNING)
    end

    wipe(deaths)
end

---@param mod table
---@param settle function
local function onCombatLog(mod, settle)
    if not mod:Get("announceDeaths") then return end

    local _, subevent, _, _, _, _, _, _, destName, destFlags = CombatLogGetCurrentEventInfo()
    if subevent ~= "UNIT_DIED" then return end
    if not (destName and isGroupPlayer(destFlags)) then return end

    -- Le journal renvoie plusieurs fois la même mort dans certains cas (un
    -- joueur qui meurt sous un effet à retardement) : on ne nomme personne deux
    -- fois dans la même rafale.
    for i = 1, #deaths do
        if deaths[i] == destName then return end
    end

    deaths[#deaths + 1] = destName
    settle()
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

---@return BUI.BattleResInfo|nil
local function battleResSource()
    -- Hors instance, ou seul, il n'y a pas de réserve partagée à suivre : le
    -- panneau n'a rien à dire et se cache de lui-même.
    local kind = instanceType()
    if not (kind == "raid" or kind == "party" or inChallenge()) then return nil end
    if not IsInGroup() then return nil end

    local raw = readBattleRes()
    if not (raw and raw.max and raw.max > 0) then return nil end

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

--- Le mode sombre est un réglage de **Général**, et un module n'appelle jamais
--- un autre module : on lit la valeur en base, et le message de changement de
--- réglage nous en avertit (voir `OnEnable`). Le suivi porte alors le même
--- contour sombre que les icônes d'auras.
---@return boolean
local function darkModeOn()
    return BUI.DB:Get("General", "darkMode") == true
end

---@param mod table
local function applyBattleRes(mod)
    if not mod:Get("battleResTracker") then
        if tracker then tracker:Stop() end
        return
    end

    if not tracker then
        tracker = W.BattleResTracker({
            source = battleResSource,
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
    tracker:SetShaded(darkModeOn())
    tracker:ApplyPosition()
    tracker:Start()
end

-- =========================================================================
--  Barre de marqueurs, vérification de présence et pull
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
            markerLabel = L["World marker number"],
            markerTip   = L["World marker tip"],
            clearLabel  = L["Clear markers"],
            clearTip    = L["Clear markers tip"],
            readyLabel  = L["Ready check"],
            readyTip    = L["Ready check tip"],
            pullLabel   = L["Pull"],
            pullTip     = L["Pull tip"],
            onReadyCheck = function() startReadyCheck(mod) end,
            onPull       = function() startPull(mod) end,
        })
        if not markerBar then return end
    end

    markerBar:SetPullLabel(string.format(L["Pull seconds"], mod:Get("pullTimer")))
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
--  Contrôle des buffs à la vérification de présence
-- =========================================================================
-- Ce que le client publie et ce qu'il ne publie pas décide de ce qui est
-- vérifiable :
--
--   · les **auras** d'un membre du groupe se lisent (`C_UnitAuras`), donc la
--     nourriture et le flacon se vérifient pour tout le monde ;
--   · un **enchantement d'arme** ne se lit que sur soi (`GetWeaponEnchantInfo`).
--     Le contrôle ne porte donc que sur le personnage, et c'est une limite du
--     client, pas un choix.
--
-- La reconnaissance passe par le **nom** de l'aura, isolé dans les fichiers de
-- locale : aucun identifiant stable n'existe côté aura, et une liste
-- d'identifiants serait fausse à la première extension. Une locale dont
-- l'intitulé est faux signale tout le monde comme non buffé — c'est le seul
-- risque, et il se corrige à un seul endroit (même parti pris que le noyau du
-- vide dans `Modules/Character.lua`).

--- L'aura porte-t-elle ce mot ? Comparaison insensible à la casse, sur le nom
--- rendu par le client — donc déjà dans la langue du joueur.
---@param name string
---@param marker string
---@return boolean
local function auraMatches(name, marker)
    if not (name and marker and marker ~= "") then return false end
    return string.find(string.lower(name), string.lower(marker), 1, true) ~= nil
end

--- Relevé d'une unité : a-t-elle sa nourriture, son flacon, et pour combien de
--- temps ? Table de travail réutilisée.
local status = {}

---@param unit string
---@return table
local function readBuffs(unit)
    status.food  = false
    status.flask = false
    status.flaskExpires = nil

    if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return status end

    for i = 1, 40 do
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
        if not aura then break end

        local name = aura.name
        if type(name) == "string" and not U.IsSecret(name) then
            if auraMatches(name, L["Well fed aura"]) then
                status.food = true
            elseif auraMatches(name, L["Flask aura"]) or auraMatches(name, L["Phial aura"]) then
                status.flask = true
                status.flaskExpires = aura.expirationTime
            end
        end
    end

    return status
end

--- Listes de noms à signaler. Réutilisées d'une vérification à l'autre.
local missingFood, missingFlask, shortFlask = {}, {}, {}

---@param mod table
---@param list string[]
---@param message string
local function report(mod, list, message)
    if #list == 0 then return end
    mod:Print(string.format(message, table.concat(list, ", ")))
end

--- Enchantement d'arme du personnage. Deux réponses possibles : absent, ou sur
--- le point d'expirer.
---@param mod table
local function reportWeaponEnchant(mod)
    if not (mod:Get("checkWeaponEnchant") and GetWeaponEnchantInfo) then return end

    local hasMain, mainExpires = GetWeaponEnchantInfo()
    if not hasMain then
        mod:Print(L["Weapon enchant missing"])
        return
    end

    -- Le client rend des **millisecondes** ; le réglage est en minutes.
    local minutes = (mainExpires or 0) / 60000
    if minutes < mod:Get("expiryWarning") then
        mod:Print(string.format(L["Weapon enchant expiring"], math.floor(minutes)))
    end
end

---@param mod table
local function checkGroupBuffs(mod)
    if not mod:Get("readyCheckBuffs") then return end

    wipe(missingFood)
    wipe(missingFlask)
    wipe(shortFlask)

    local warning = mod:Get("expiryWarning") * 60
    local list    = groupUnits()

    for i = 1, #list do
        local unit = list[i]

        -- Un joueur déconnecté n'a pas d'auras à lire : le signaler comme non
        -- buffé serait faux, et le nom apparaîtrait dans les trois listes.
        if UnitExists(unit) and (not UnitIsConnected or UnitIsConnected(unit)) then
            local name  = UnitName(unit) or unit
            local buffs = readBuffs(unit)

            if mod:Get("checkFood") and not buffs.food then
                missingFood[#missingFood + 1] = name
            end

            if mod:Get("checkFlask") then
                if not buffs.flask then
                    missingFlask[#missingFlask + 1] = name
                elseif buffs.flaskExpires and buffs.flaskExpires > 0
                       and (buffs.flaskExpires - GetTime()) < warning then
                    shortFlask[#shortFlask + 1] = name
                end
            end
        end
    end

    report(mod, missingFood,  L["Missing food"])
    report(mod, missingFlask, L["Missing flask"])
    report(mod, shortFlask,   L["Flask expiring"])

    reportWeaponEnchant(mod)
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

---@param mod table
local function applyLogging(mod)
    local want = mod:Get("autoCombatLog")
                 and (instanceType() == "raid" or inChallenge())

    if want then
        if loggingStarted then return end
        if savedAdvanced == nil then savedAdvanced = U.GetCVar(CVAR_ADVANCED) end
        U.SetCVar(CVAR_ADVANCED, "1")

        if LoggingCombat and not LoggingCombat() then LoggingCombat(true) end
        loggingStarted = true
        mod:Print(L["Combat log started"])
        return
    end

    if not loggingStarted then return end
    if LoggingCombat then LoggingCombat(false) end
    if savedAdvanced ~= nil then
        U.SetCVar(CVAR_ADVANCED, savedAdvanced)
        savedAdvanced = nil
    end
    loggingStarted = false
    mod:Print(L["Combat log stopped"])
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
    worldMarkers      = applyMarkerBar,
    pullTimer         = applyMarkerBar,
    hideBlizzardPanel = applyHideManager,
    autoCombatLog     = applyLogging,
}

-- =========================================================================
--  Déclaration du module
-- =========================================================================

BUI:RegisterModule(MODULE, {
    title    = L["Raid tools"],
    category = "MythicRaid",
    order    = 20,
    secure   = true,

    -- En avant-première : le code est écrit, il n'a pas encore été vérifié en
    -- jeu (CLAUDE.md règle 10, points 3 à 5). Tant que cette ligne est là, le
    -- core refuse d'allumer le module — la retirer est le seul geste qui livre
    -- la page.
    preview  = true,

    defaults = {
        battleResTracker = false,
        battleResSize    = T.SIZE.BATTLE_RES_ICON,
        -- Position du panneau, en décalage de centre à centre. Réglages sans
        -- contrôle : ils se changent en déplaçant le panneau à la souris.
        battleResX = 0,
        battleResY = 0,

        worldMarkers = false,
        markerX      = 0,
        markerY      = -220,
        pullTimer    = 8,
        hideBlizzardPanel = false,

        readyCheckBuffs    = false,
        checkFood          = true,
        checkFlask         = true,
        checkWeaponEnchant = true,
        expiryWarning      = 30,

        announceDeaths = false,
        deathSound     = false,

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

        { type = "header", text = L["Group tools"] },
        {
            type    = "toggle",
            key     = "worldMarkers",
            text    = L["World markers"],
            tooltip = L["World markers tip"],
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

        { type = "header", text = L["Buffs"] },
        {
            type    = "toggle",
            key     = "readyCheckBuffs",
            text    = L["Ready check buffs"],
            tooltip = L["Ready check buffs tip"],
        },
        {
            type     = "toggle",
            key      = "checkFood",
            text     = L["Check food"],
            tooltip  = L["Check food tip"],
            disabled = requires("readyCheckBuffs"),
        },
        {
            type     = "toggle",
            key      = "checkFlask",
            text     = L["Check flask"],
            tooltip  = L["Check flask tip"],
            disabled = requires("readyCheckBuffs"),
        },
        {
            type     = "toggle",
            key      = "checkWeaponEnchant",
            text     = L["Check weapon enchant"],
            tooltip  = L["Check weapon enchant tip"],
            disabled = requires("readyCheckBuffs"),
        },
        {
            type     = "slider",
            key      = "expiryWarning",
            text     = L["Expiry warning"],
            tooltip  = L["Expiry warning tip"],
            min      = 5,
            max      = 60,
            step     = 5,
            disabled = requires("readyCheckBuffs"),
        },

        { type = "header", text = L["Announcements"] },
        {
            type    = "toggle",
            key     = "announceDeaths",
            text    = L["Announce group deaths"],
            tooltip = L["Announce group deaths tip"],
        },
        {
            type     = "toggle",
            key      = "deathSound",
            text     = L["Death sound alert"],
            tooltip  = L["Death sound alert tip"],
            disabled = requires("announceDeaths"),
        },

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

        local settle = U.Debounce(T.TIMING.DEATH_SETTLE, function() flushDeaths(self) end)
        self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", function()
            onCombatLog(self, settle)
        end)

        self:RegisterEvent("READY_CHECK", function() checkGroupBuffs(self) end)

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

        -- Le mode sombre appartient à **Général** : on n'appelle pas ce
        -- module-là, on écoute le message que le core émet quand un réglage
        -- change (voir `Core/Init.lua`).
        self:RegisterMessage(BUI.MESSAGES.SETTING_CHANGED, function(_, moduleName, key)
            if moduleName == "General" and (key == "darkMode" or key == nil) then
                if tracker then tracker:SetShaded(darkModeOn()) end
            end
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

        wipe(deaths)
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
