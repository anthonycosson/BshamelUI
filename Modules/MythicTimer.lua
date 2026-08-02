-- =========================================================================
--  Bshamel UI — Modules/MythicTimer.lua
--  Chrono mythique+ : ce que le client ne dit pas.
--
--  Le client affiche le temps restant, le niveau de la clé, une barre qui se vide
--  et un compteur de morts. Ce module lui ajoute les quatre choses qu'on calculait
--  de tête en courant — les paliers, ce que les morts coûtent, l'heure à laquelle
--  chaque boss est tombé, l'écart avec la dernière clé réussie —, et un fond sombre
--  pour que tout cela se lise sur le décor d'un donjon.
--
--  **Rien n'est redit.** Un panneau à nous a vécu ici : il réaffichait le temps
--  restant à côté de celui du client, soit deux chronos pour une clé dont un seul
--  est le vrai, et il fallait de surcroît le placer. Tout se pose désormais sur le
--  bloc du client (voir `UI/Widgets/KeyThresholds.lua`).
--
--  **Le temps écoulé se demande au client, il ne se compte pas.** Un chrono qu'on
--  démarre soi-même est faux dès qu'on recharge l'interface au milieu d'une clé —
--  c'est-à-dire précisément quand on en a besoin. L'affichage du temps restant est
--  celui du client ; ce module ne lit son chrono de zone que pour **horodater** un
--  boss qui tombe, ce que le client ne retient nulle part.
--
--  **Les temps de passage, eux, se mémorisent.** C'est la seule mémoire de
--  l'addon : le client ne garde d'une clé réussie que sa durée totale, pas ses
--  temps de passage, donc il n'y a ici aucune seconde source de vérité à créer —
--  il n'y en a pas de première. Ils vivent dans les données du personnage
--  (`self:CharData()`), pas dans ses réglages : ce ne sont ni un défaut, ni un
--  contrôle, et ils n'ont pas à voyager d'un profil à l'autre.
--
--  Réversibilité : chaque pièce se cache, et le suivi d'objectifs réécrit ses
--  lignes sans nous à la passe suivante.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local W    = BUI.Widgets
local L    = ns.L

local MODULE = "MythicTimer"

--- Ce que montre le mode aperçu.
---
--- `SPENT` est la part du chrono déjà dépensée, et la moitié n'est pas un chiffre
--- rond choisi au hasard : c'est ce qui met le remplissage de la barre **au-dessus
--- des deux repères**, donc les trois temps à l'écran en même temps. Plus tard dans
--- le chrono, un palier serait perdu et son nombre retiré.
---
--- Les trois boss sont donnés en **fractions du chrono** et non en secondes : le
--- donjon emprunté à la saison n'a pas le chrono de notre repli, et des temps de
--- passage figés y paraîtraient tous groupés au début ou tous après l'échéance.
---
--- Leurs écarts couvrent les trois états que le comparatif peut prendre : devant,
--- derrière, et pas de référence du tout — c'est le cas d'un boss qu'on n'a jamais
--- passé sur une clé réussie, et il faut le voir aussi.
---
--- Le niveau et le chrono ne servent que de repli : l'aperçu emprunte un vrai donjon
--- de la saison quand le client en publie un.
local PREVIEW = {
    level = 12,
    limit = 1800,
    SPENT = 0.5,

    bosses = {
        { at = 0.14, delta = -18 },
        { at = 0.29, delta =  42 },
        { at = 0.44 },
    },

    forces = 84.76,

    -- Trois morts et les quinze secondes qu'elles coûtent. Non nul : le client cache
    -- son compteur de morts à zéro mort, et un aperçu qui ne le montre pas laisse
    -- croire qu'on l'a perdu.
    deaths = { count = 3, lost = 15 },
}

--- Lignes de boss rendues au widget, réutilisées plutôt que reconstruites (règle 7).
local bosses = {}

--- Décompte des troupes rendu au widget, pour la même raison.
local forces = {}

--- Les ajouts posés sur le bloc du client, construits au premier besoin.
local marker

--- Relevé d'aperçu rendu au widget, réutilisé plutôt que reconstruit (règle 7).
local sample = {}

--- La clé en cours.
---
--- `mapID` et `level` sont **retenus** : à la fin d'une clé, le client ne dit plus
--- laquelle était active, et c'est justement le moment où l'on veut ranger ses temps
--- de passage.
local state = {
    mapID     = nil,
    level     = 0,
    timerID   = nil,
    splits    = {},   -- criteriaID -> secondes écoulées quand il est tombé
    reference = nil,  -- les mêmes, relevés sur la clé de référence
}

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

--- Secondes perdues par les morts, telles que le client les compte.
---@return number|nil
local function deathTimeLost()
    if not (C_ChallengeMode and C_ChallengeMode.GetDeathCount) then return nil end
    local _, timeLost = C_ChallengeMode.GetDeathCount()
    return timeLost
end

--- Identifiant du chrono de zone que le client tient pour la clé en cours.
---
--- Relevé sur événement et retenu : `GetWorldElapsedTimers` est variadique, et
--- l'énumérer à chaque boss coûterait des appels pour une valeur qui ne change
--- qu'au départ de la clé (règle 7).
local function resolveTimer()
    state.timerID = nil

    if not (GetWorldElapsedTimers and GetWorldElapsedTime) then return end

    local wanted = Enum and Enum.WorldElapsedTimerTypes
                   and Enum.WorldElapsedTimerTypes.ChallengeMode

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

--- Secondes écoulées depuis le départ de la clé, selon le client.
---@return number|nil
local function elapsedSeconds()
    if not (state.timerID and GetWorldElapsedTime) then return nil end

    local _, elapsed = GetWorldElapsedTime(state.timerID)
    if elapsed and elapsed > 0 then return elapsed end
    return nil
end

--- Relevé du critère n° `index` de l'étape en cours.
---@param index number
---@return table|nil
local function criteria(index)
    if type(index) ~= "number" then return nil end
    if not (C_ScenarioInfo and C_ScenarioInfo.GetCriteriaInfo) then return nil end
    return C_ScenarioInfo.GetCriteriaInfo(index)
end

---@return number
local function criteriaCount()
    if not (C_Scenario and C_Scenario.GetStepInfo) then return 0 end
    local count = select(3, C_Scenario.GetStepInfo())
    return count or 0
end

-- =========================================================================
--  Les temps de passage
-- =========================================================================

--- Historique des clés réussies de ce personnage : `[mapID][level]`.
---@param mod table
---@return table
local function history(mod)
    local data = mod:CharData()
    data.runs = data.runs or {}
    return data.runs
end

--- Horodate les critères qui viennent d'être remplis.
---
--- **Le client ne les horodate pas.** Un critère dit s'il est rempli, jamais quand
--- il l'a été : c'est donc à nous de relever le chrono au moment où il bascule, et
--- c'est la seule chose que ce module compte — encore le compte-t-il en demandant
--- l'heure au client plutôt qu'en la tenant.
---
--- L'identifiant du critère sert de clé, pas son rang : un rang se réordonne d'un
--- patch à l'autre, et l'historique rangé par rang comparerait alors le troisième
--- boss d'aujourd'hui au deuxième d'hier.
---@return boolean stamped  un critère au moins vient d'être horodaté
local function stampCriteria()
    if not state.mapID then return false end

    local at = elapsedSeconds()
    if not at then return false end

    local stamped = false
    for i = 1, criteriaCount() do
        local info = criteria(i)
        if info and info.criteriaID and info.completed
           and state.splits[info.criteriaID] == nil then
            state.splits[info.criteriaID] = at
            stamped = true
        end
    end

    return stamped
end

--- Temps du boss n° `index`, et son écart avec la clé de référence.
---
--- Rend deux nombres au widget, jamais du texte ni une couleur : c'est lui qui
--- décide de quoi un écart a l'air (règle 2).
---@param index number
---@return number|nil at, number|nil delta
local function splitFor(index)
    local info = criteria(index)
    if not (info and info.completed and info.criteriaID) then return nil end

    local at = state.splits[info.criteriaID]
    if not at then return nil end

    local reference = state.reference and state.reference[info.criteriaID]
    if not reference then return at, nil end

    return at, at - reference
end

--- Relève les temps de passage de la clé de référence : la **meilleure** clé de ce
--- donjon et de ce niveau déjà réussie dans le chrono.
---
--- La meilleure et non la dernière : un écart sert à savoir si on est en avance, et
--- on est en avance sur ce qu'on sait faire, pas sur ce qu'on a fait la dernière
--- fois. Rien si aucune clé de ce niveau n'a été réussie — un écart avec une clé
--- ratée ne voudrait rien dire.
---@param mod table
local function loadReference(mod)
    state.reference = nil
    if not (state.mapID and state.level and state.level > 0) then return end

    local byMap = history(mod)[state.mapID]
    local kept  = byMap and byMap[state.level]
    if kept then state.reference = kept.splits end
end

--- Range les temps de passage de la clé qui vient d'être réussie.
---@param mod table
local function recordRun(mod)
    if not (C_ChallengeMode and C_ChallengeMode.GetChallengeCompletionInfo) then return end

    local info = C_ChallengeMode.GetChallengeCompletionInfo()
    if type(info) ~= "table" or info.onTime ~= true then return end

    local mapID = info.mapChallengeModeID or state.mapID
    local level = info.level or state.level
    local total = (info.time and info.time > 0) and (info.time / 1000) or nil

    if not (mapID and level and level > 0 and total and next(state.splits)) then return end

    local runs = history(mod)
    runs[mapID] = runs[mapID] or {}

    -- On ne garde qu'une clé par niveau, la plus rapide. Un historique complet
    -- grossirait sans fin pour ne servir qu'à en extraire cette seule ligne.
    local kept = runs[mapID][level]
    if kept and kept.total and kept.total <= total then return end

    local splits = {}
    for criteriaID, at in pairs(state.splits) do splits[criteriaID] = at end

    runs[mapID][level] = { total = total, splits = splits }
end

-- =========================================================================
--  Suivi de la clé
-- =========================================================================

---@param mod table
local function onStart(mod)
    state.mapID   = activeMapID()
    state.level   = activeLevel()
    state.timerID = nil
    wipe(state.splits)

    resolveTimer()
    loadReference(mod)
end

local function onReset()
    state.mapID   = nil
    state.level   = 0
    state.timerID = nil
    state.reference = nil
    wipe(state.splits)
end

--- Reprise après un rechargement d'interface : rien ne l'annonce, il n'y a que
--- l'entrée en zone pour s'apercevoir qu'une clé tourne déjà.
---
--- Les temps de passage des boss déjà tombés sont perdus — ils n'étaient qu'en
--- mémoire, et les écrire à chaque boss pour ce seul cas aurait fait payer un
--- accès disque à toutes les clés. Ceux qui tombent ensuite sont horodatés
--- normalement.
---@param mod table
local function onResync(mod)
    local mapID = activeMapID()
    if not mapID then
        onReset()
        return
    end

    if state.mapID ~= mapID then
        state.mapID = mapID
        state.level = activeLevel()
        wipe(state.splits)
        loadReference(mod)
    end

    resolveTimer()
end

-- =========================================================================
--  Le relevé d'aperçu
-- =========================================================================

--- Relevé montré par le mode aperçu, ou `nil` quand il n'a pas lieu d'être : le
--- mode est éteint, ou une clé tourne pour de vrai — et alors c'est le vrai chrono
--- qu'on regarde, pas un exemple.
---@param mod table
---@return BUI.KeySample|nil
local function previewSample(mod)
    if not mod:Get("previewMode") then return nil end
    if activeMapID() then return nil end

    -- Le premier donjon que le client connaît : un vrai nom et un vrai chrono se
    -- placent comme ils se placeront en donjon, un intitulé de démonstration non.
    local maps = C_ChallengeMode and C_ChallengeMode.GetMapTable
                 and C_ChallengeMode.GetMapTable()
    local map  = maps and maps[1]

    local name, limit
    if map then name, limit = mapInfo(map) end

    sample.name    = name or L["Preview dungeon"]
    sample.level   = PREVIEW.level
    sample.limit   = (limit and limit > 0) and limit or PREVIEW.limit
    sample.elapsed = sample.limit * PREVIEW.SPENT

    -- Les boss d'exemple sont numérotés et non nommés : les vrais noms viennent du
    -- scénario en cours, et il n'y en a pas hors donjon. En inventer serait écrire
    -- des noms qui n'existent pas dans le jeu.
    for i = 1, #PREVIEW.bosses do
        bosses[i]       = bosses[i] or {}
        bosses[i].name  = L["Preview boss"]:format(i)
        bosses[i].at    = sample.limit * PREVIEW.bosses[i].at
        bosses[i].delta = PREVIEW.bosses[i].delta
    end
    sample.bosses = bosses

    forces.name    = L["Preview forces"]
    forces.percent = PREVIEW.forces
    sample.forces  = forces

    sample.deaths = PREVIEW.deaths

    return sample
end

-- =========================================================================
--  Application
-- =========================================================================

---@param mod table
local function apply(mod)
    if not marker then
        -- Au premier passage seulement : le bloc du client peut ne pas encore être
        -- là, et un module qui a renoncé une fois ne réessaierait jamais.
        marker = W.KeyThresholds({
            deaths = deathTimeLost,
            split  = splitFor,
        })
        if not marker then return end
    end

    marker:SetThresholds(mod:Get("thresholds") == true)
    marker:SetDeaths(mod:Get("deaths") == true)
    marker:SetSplits(mod:Get("splits") == true)
    marker:SetPreview(previewSample(mod))
end

-- =========================================================================
--  Déclaration du module
-- =========================================================================

BUI:RegisterModule(MODULE, {
    title    = L["Mythic+ timer"],
    category = "Interface",
    order    = 40,

    defaults = {
        thresholds  = false,
        deaths      = false,
        splits      = false,
        previewMode = false,
    },

    options = {
        { type = "header", text = L["Display"] },
        {
            type    = "toggle",
            key     = "thresholds",
            text    = L["Show key thresholds"],
            tooltip = L["Show key thresholds tip"],
        },
        {
            type    = "toggle",
            key     = "deaths",
            text    = L["Show death time"],
            tooltip = L["Show death time tip"],
        },
        {
            type    = "toggle",
            key     = "splits",
            text    = L["Show boss times"],
            tooltip = L["Show boss times tip"],
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
        apply(self)

        self:RegisterEvent("CHALLENGE_MODE_START", function()
            onStart(self)
            apply(self)
        end)

        self:RegisterEvent("CHALLENGE_MODE_COMPLETED", function()
            -- Le dernier boss tombe **avec** la fin de la clé : on horodate avant
            -- de ranger, sans quoi la ligne qui compte le plus manquerait.
            stampCriteria()
            recordRun(self)
            apply(self)
            if marker then marker:Refresh() end
        end)

        self:RegisterEvent("CHALLENGE_MODE_RESET", function()
            onReset()
            apply(self)
        end)

        self:RegisterEvent("PLAYER_ENTERING_WORLD", function()
            onResync(self)
            apply(self)
        end)

        self:RegisterEvent("WORLD_STATE_TIMER_START", resolveTimer)

        -- Un critère qui bascule : on l'horodate, puis on redemande une passe au
        -- suivi. On ne compte pas sur la sienne — rien ne garantit l'ordre dans
        -- lequel deux cadres reçoivent le même événement, et un boss horodaté
        -- après le passage du suivi ne s'afficherait qu'au suivant.
        local onCriteria = function()
            if stampCriteria() and marker then marker:Refresh() end
        end
        self:RegisterEvent("SCENARIO_CRITERIA_UPDATE", onCriteria)
        self:RegisterEvent("SCENARIO_UPDATE",          onCriteria)
    end,

    OnDisable = function()
        if marker then marker:Stop() end
    end,

    OnSettingChanged = function(self)
        apply(self)
    end,
})
