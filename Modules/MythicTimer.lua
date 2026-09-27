-- =========================================================================
--  Bshamel UI — Modules/MythicTimer.lua
--  Chrono mythique+ : ce que le client ne dit pas.
--
--  Le client affiche le temps restant, le niveau de la clé, une barre qui se vide
--  et un compteur de morts. Ce module lui ajoute ce qu'on calculait de tête en
--  courant — où tombent les paliers, ce que les morts coûtent — et un mode aperçu
--  pour régler tout cela sans attendre d'être en donjon.
--
--  **Rien n'est redit.** Un panneau à nous a vécu ici : il réaffichait le temps
--  restant à côté de celui du client, soit deux chronos pour une clé dont un seul
--  est le vrai, et il fallait de surcroît le placer. Tout se pose désormais sur le
--  bloc du client (voir `UI/Widgets/KeyThresholds.lua`).
--
--  **Rien ne se compte, rien ne se mémorise.** Les temps de passage des boss ont
--  vécu ici aussi : horodatés sur événement, rangés par personnage, comparés à la
--  meilleure clé du même niveau. Retirés — leur affichage réécrivait les lignes
--  du suivi d'objectifs, et une passe du suivi qui meurt en combat ne se
--  reprogramme plus de la session : boss et troupes gelés jusqu'au `/reload`
--  (voir `dev/docs/API_NOTES.md`, « Le suivi d'objectifs ne se répare pas »).
--  La fonctionnalité valait moins que ce risque-là. Ce qui reste ne touche
--  qu'au bloc de chrono, jamais aux lignes.
--
--  Réversibilité : chaque pièce se cache, et l'aperçu rend au bloc l'état où le
--  client l'avait laissé.
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
--- Les boss et le décompte de troupes ne montrent rien : ils donnent au bloc la
--- silhouette d'un vrai suivi de clé, sans quoi l'aperçu flotterait au-dessus de
--- rien.
---
--- Le niveau et le chrono ne servent que de repli : l'aperçu emprunte un vrai donjon
--- de la saison quand le client en publie un.
local PREVIEW = {
    level  = 12,
    limit  = 1800,
    SPENT  = 0.5,
    BOSSES = 3,

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

-- =========================================================================
--  Ce que le client publie
-- =========================================================================

---@return number|nil
local function activeMapID()
    if not (C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID) then return nil end
    return C_ChallengeMode.GetActiveChallengeMapID()
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
    for i = 1, PREVIEW.BOSSES do
        bosses[i]      = bosses[i] or {}
        bosses[i].name = L["Preview boss"]:format(i)
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
        })
        if not marker then return end
    end

    marker:SetThresholds(mod:Get("thresholds") == true)
    marker:SetDeaths(mod:Get("deaths") == true)
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
        previewMode = false,
    },

    options = {
        { type = "header", text = L["Display"] },

        -- L'aperçu vient **en premier**, avant ce qu'il sert à montrer : on
        -- l'allume, puis on règle les deux cases suivantes en voyant ce qu'elles
        -- font. Rangé en dernier, on découvrait son existence après avoir coché à
        -- l'aveugle.
        {
            type    = "toggle",
            key     = "previewMode",
            edit    = "preview",
            text    = L["Timer preview"],
            tooltip = L["Timer preview tip"],
        },
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
    },

    OnEnable = function(self)
        apply(self)

        -- Les trois moments où ce que dit le client change : le départ d'une clé
        -- éteint l'aperçu, sa remise à zéro et l'entrée en zone le rendent si sa
        -- case l'est encore. Les trois se contentent de refaire passer `apply`,
        -- qui regarde l'état du client. Aucune passe du suivi d'objectifs n'est
        -- redemandée ici — voir l'en-tête.
        local refresh = function() apply(self) end
        self:RegisterEvent("CHALLENGE_MODE_START",   refresh)
        self:RegisterEvent("CHALLENGE_MODE_RESET",   refresh)
        self:RegisterEvent("PLAYER_ENTERING_WORLD",  refresh)
    end,

    OnDisable = function()
        if marker then marker:Stop() end
    end,

    OnSettingChanged = function(self)
        apply(self)
    end,
})
