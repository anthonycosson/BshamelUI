-- =========================================================================
--  Bshamel UI — Modules/MythicTimer.lua
--  Chrono mythique+ : les paliers, et ce qu'on avait mis la dernière fois.
--
--  Le client affiche le temps restant, et rien d'autre. Or personne ne court
--  après le chrono : on court après **+2** et **+3**, qui tombent à 80 % et 60 %
--  du chrono, et qu'il faut sinon calculer de tête en courant.
--
--  Le comparatif ne tient aucune mémoire : le meilleur temps de la saison est
--  une donnée du client (`C_MythicPlus.GetSeasonBestForMap`). Écrire nos propres
--  temps de passage aurait créé une seconde source de vérité à côté de la
--  sienne, et deux sources de vérité divergent toujours (voir
--  `dev/docs/API_NOTES.md`, à propos du gestionnaire de temps de recharge).
--
--  **Le temps écoulé se demande au client, il ne se compte pas.** Un chrono
--  qu'on démarre soi-même est faux dès qu'on recharge l'interface au milieu
--  d'une clé — c'est-à-dire précisément quand on en a besoin. Le client publie
--  un chrono de zone (`GetWorldElapsedTime`), et c'est celui-là qu'on lit ; le
--  comptage maison ne sert que de repli.
--
--  Réversibilité : le panneau se cache, et le module n'a modifié aucune frame du
--  client.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local W    = BUI.Widgets
local L    = ns.L

local MODULE = "MythicTimer"

--- Chrono et niveau montrés par le mode aperçu. Des valeurs plausibles : le
--- panneau doit se placer tel qu'on le verra en donjon, pas plus petit.
local PREVIEW = { level = 12, limit = 1800, elapsed = 754, best = 1607, bestLevel = 11 }

local panel

--- État de la clé en cours. `mapID` est retenu : à la fin d'une clé, le client
--- ne dit plus laquelle était active, et c'est justement le moment où l'on veut
--- lire le comparatif.
local state = { mapID = nil, startTime = nil, timerID = nil, done = false, finalTime = nil }

--- Relevé rendu au widget, réutilisé : il est relu dix fois par seconde.
local data = {}

-- =========================================================================
--  Ce que le client publie
-- =========================================================================

---@return number|nil
local function activeMapID()
    if not (C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID) then return nil end
    return C_ChallengeMode.GetActiveChallengeMapID()
end

---@return number
local function activeLevel()
    if C_ChallengeMode and C_ChallengeMode.GetActiveKeystoneInfo then
        local level = C_ChallengeMode.GetActiveKeystoneInfo()
        if level then return level end
    end
    return 0
end

--- Nom du donjon et chrono qui lui est accordé, en secondes.
---@param mapID number
---@return string|nil name, number|nil limit
local function mapInfo(mapID)
    if not (C_ChallengeMode and C_ChallengeMode.GetMapUIInfo) then return nil end
    local name, _, limit = C_ChallengeMode.GetMapUIInfo(mapID)
    return name, limit
end

--- Identifiant du chrono de zone que le client tient pour la clé en cours.
---
--- Il est relevé sur événement et retenu : l'énumérer à chaque image coûterait
--- un appel variadique dix fois par seconde pour une valeur qui ne change qu'au
--- départ de la clé (règle 7).
local function resolveTimer()
    state.timerID = nil

    if not (GetWorldElapsedTimers and GetWorldElapsedTime) then return end

    local wanted = Enum and Enum.WorldElapsedTimerType
                   and Enum.WorldElapsedTimerType.ChallengeMode

    local count = select("#", GetWorldElapsedTimers())
    for i = 1, count do
        local timerID = select(i, GetWorldElapsedTimers())
        if timerID then
            local kind = GetWorldElapsedTime(timerID)
            -- Sans énumération pour comparer, on prend le premier chrono
            -- disponible : en donjon mythique+, il n'y en a pas d'autre.
            if wanted == nil or kind == wanted then
                state.timerID = timerID
                return
            end
        end
    end
end

---@return number
local function elapsedSeconds()
    if state.timerID and GetWorldElapsedTime then
        local _, elapsed = GetWorldElapsedTime(state.timerID)
        if elapsed and elapsed > 0 then return elapsed end
    end

    if state.startTime then return GetTime() - state.startTime end
    return 0
end

--- Meilleur temps de la saison sur ce donjon, dans le chrono.
---@param mapID number
---@return number|nil duration, number|nil level
local function seasonBest(mapID)
    if not (C_MythicPlus and C_MythicPlus.GetSeasonBestForMap) then return nil end

    local intime = C_MythicPlus.GetSeasonBestForMap(mapID)
    if type(intime) ~= "table" then return nil end
    return intime.durationSec, intime.level
end

-- =========================================================================
--  Le relevé
-- =========================================================================

---@param mod table
---@return BUI.KeyTimerData|nil
local function buildData(mod)
    local mapID = activeMapID() or state.mapID

    if not mapID then
        if not mod:Get("previewMode") then return nil end

        -- Le mode aperçu emprunte le premier donjon que le client connaît :
        -- un vrai nom se place comme un vrai nom, un intitulé de démonstration
        -- non.
        local maps = C_ChallengeMode and C_ChallengeMode.GetMapTable
                     and C_ChallengeMode.GetMapTable()
        local sample = maps and maps[1]

        data.name      = (sample and mapInfo(sample)) or L["Preview dungeon"]
        data.level     = PREVIEW.level
        data.limit     = (sample and select(2, mapInfo(sample))) or PREVIEW.limit
        data.elapsed   = PREVIEW.elapsed
        data.done      = false
        data.best      = PREVIEW.best
        data.bestLevel = PREVIEW.bestLevel
        return data
    end

    local name, limit = mapInfo(mapID)
    if not (name and limit and limit > 0) then return nil end

    data.name    = name
    data.level   = activeLevel()
    data.limit   = limit
    data.elapsed = state.done and (state.finalTime or 0) or elapsedSeconds()
    data.done    = state.done
    data.best, data.bestLevel = seasonBest(mapID)

    return data
end

-- =========================================================================
--  Suivi de la clé
-- =========================================================================

local function onStart()
    state.mapID     = activeMapID()
    state.startTime = GetTime()
    state.done      = false
    state.finalTime = nil
    resolveTimer()
end

local function onCompleted()
    state.done = true

    if C_ChallengeMode and C_ChallengeMode.GetCompletionInfo then
        local _, _, milliseconds = C_ChallengeMode.GetCompletionInfo()
        if milliseconds and milliseconds > 0 then
            state.finalTime = milliseconds / 1000
            return
        end
    end

    state.finalTime = elapsedSeconds()
end

local function onReset()
    state.mapID     = nil
    state.startTime = nil
    state.timerID   = nil
    state.done      = false
    state.finalTime = nil
end

-- =========================================================================
--  Application
-- =========================================================================

---@param mod table
local function applyTimer(mod)
    if not (mod:Get("timer") or mod:Get("previewMode")) then
        if panel then panel:Stop() end
        return
    end

    if not panel then
        panel = W.KeyTimer({
            bestLabel = L["Season best"],
            source    = function() return buildData(mod) end,
            getPos    = function() return mod:Get("timerX"), mod:Get("timerY") end,
            setPos    = function(x, y)
                mod:Set("timerX", x)
                mod:Set("timerY", y)
            end,
        })
        if not panel then return end
    end

    panel:ApplyPosition()
    panel:Start()
end

-- =========================================================================
--  Déclaration du module
-- =========================================================================

BUI:RegisterModule(MODULE, {
    title    = L["Mythic+ timer"],
    category = "MythicRaid",
    order    = 30,

    -- En avant-première : le code est écrit, il n'a pas encore été vérifié en
    -- jeu (CLAUDE.md règle 10, points 3 à 5). Tant que cette ligne est là, le
    -- core refuse d'allumer le module — la retirer est le seul geste qui livre
    -- la page.
    preview  = true,

    defaults = {
        timer       = false,
        previewMode = false,

        -- Position du panneau, en décalage de centre à centre. Réglage sans
        -- contrôle : il se change en déplaçant le panneau à la souris, ce que
        -- le mode aperçu permet de faire hors donjon.
        timerX = 0,
        timerY = 120,
    },

    options = {
        { type = "header", text = L["Display"] },
        {
            type    = "toggle",
            key     = "timer",
            text    = L["Show mythic timer"],
            tooltip = L["Show mythic timer tip"],
        },
        {
            type    = "toggle",
            key     = "previewMode",
            text    = L["Timer preview"],
            tooltip = L["Timer preview tip"],
        },
        { type = "description", text = L["Mythic timer notice"] },
    },

    OnEnable = function(self)
        applyTimer(self)

        self:RegisterEvent("CHALLENGE_MODE_START",     function()
            onStart()
            applyTimer(self)
        end)
        self:RegisterEvent("CHALLENGE_MODE_COMPLETED", onCompleted)
        self:RegisterEvent("CHALLENGE_MODE_RESET",     onReset)

        -- Une clé reprise après un rechargement d'interface : rien ne l'annonce,
        -- il n'y a que l'entrée en zone pour rattraper le chrono du client.
        self:RegisterEvent("PLAYER_ENTERING_WORLD", function()
            if activeMapID() then
                state.mapID = activeMapID()
                state.startTime = state.startTime or GetTime()
                resolveTimer()
            else
                onReset()
            end
            applyTimer(self)
        end)

        self:RegisterEvent("WORLD_STATE_TIMER_START", resolveTimer)

        -- Les meilleurs temps de la saison ne sont pas chargés à la connexion :
        -- ils se demandent, et le client répond quand il répond.
        if C_MythicPlus and C_MythicPlus.RequestMapInfo then
            C_MythicPlus.RequestMapInfo()
        end
    end,

    OnDisable = function()
        if panel then panel:Stop() end
    end,

    OnSettingChanged = function(self)
        applyTimer(self)
    end,
})
