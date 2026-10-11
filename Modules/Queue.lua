-- =========================================================================
--  Bshamel UI — Modules/Queue.lua
--  Le temps qu'il reste pour prendre ce qu'on a attendu.
--
--  La fenêtre qui annonce une instance ou un champ de bataille se referme
--  toute seule et ne dit jamais quand. Elle se referme sur qui regardait
--  ailleurs, et on reprend la file depuis le début. Un nombre au milieu de la
--  fenêtre suffit à régler ça.
--
--  ## Pourquoi un module à lui
--
--  Il a d'abord vécu dans *Général*, faute de page où le mettre, puis dans
--  *Recherche de groupe*, qui était la bonne page sur retail — et seulement
--  sur retail. Ce module-là ne charge pas sur *Forever* : il est bâti autour
--  de la recherche personnalisée et de ses trois onglets, que ce client n'a
--  pas. Le minuteur y est parti avec lui, alors que **ce qu'il surveille
--  existe sur les deux clients**.
--
--  D'où cette page, chargée partout, qui ne porte que lui. C'est le troisième
--  déménagement du même réglage, et le dernier : un palier de migration
--  (`Core/DB.lua`) emmène le réglage de ceux qui l'avaient coché.
--
--  ## Les deux fenêtres ne se valent pas sur Forever
--
--  La proposition de **donjon** s'affiche dans `LFGDungeonReadyDialog`, défini
--  par `Blizzard_GroupFinder`, dont le `.toc` porte `ExcludeLoadGameType:
--  camelot` : sur *Forever*, ce cadre n'existe pas, et le minuteur de donjon
--  n'a rien à décorer. La fenêtre de **champ de bataille** (`PVPReadyDialog`)
--  vient de `Blizzard_LFGUtil`, chargé pour la famille `mainline` — donc là.
--
--  Rien de tout ça n'est testé par un `if` sur le client : les deux chemins
--  cherchent leur cadre et s'abstiennent s'il manque (CLAUDE.md §1). Le même
--  fichier marche sur les deux, et marchera encore le jour où Blizzard livre
--  la recherche de donjon à *Forever*.
--
--  Réversibilité (règle 6) : le module ne pose qu'un nombre sur une fenêtre du
--  client, et l'éteindre l'arrête et le cache.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local W    = BUI.Widgets
local L    = ns.L

local MODULE = "Queue"

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

--- Cadre sur lequel poser le décompte : l'**icône du rôle** quand la fenêtre en
--- porte une, la fenêtre elle-même sinon.
---
--- C'est le seul repère qui tienne dans les deux cas. Le centre de la fenêtre
--- tombe entre le nom de l'instance et l'icône, donc sur rien ; l'icône, elle,
--- est un disque vide au milieu, exactement de la taille d'un nombre.
---
--- Deux chemins, du plus général au plus ancien, et aucun n'est un pari : un
--- champ absent ou un nom inconnu rend `nil`, et on retombe sur la fenêtre.
---@param dialog table
---@return table
local function countdownAnchor(dialog)
    local icon = dialog.roleIcon

    if not icon then
        local name = dialog.GetName and dialog:GetName()
        icon = name and _G[name .. "RoleIcon"] or nil
    end

    if icon and icon.GetCenter and icon:GetCenter() then return icon end
    return dialog
end

---@param parent table
---@param source fun(): number|nil
---@param total number  durée pleine, qui donne sa couleur au décompte
local function watch(parent, source, total)
    local countdown = countdowns[parent]
    if not countdown then
        countdown = W.Countdown(parent)
        if not countdown then return end
        countdown:SetPoint("CENTER", countdownAnchor(parent), "CENTER",
            0, T.SIZE.COUNTDOWN_Y)
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
    --
    -- Absent sur *Forever* : voir l'en-tête du fichier. On s'abstient, et le
    -- minuteur de champ de bataille continue de servir.
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
--  Déclaration du module
-- =========================================================================

BUI:RegisterModule(MODULE, {
    title    = L["Queues"],
    category = "QoL",
    -- Juste après la recherche de groupe sur retail, où les deux pages parlent
    -- du même moment de la soirée. Sur *Forever*, cette page-là n'existe pas et
    -- celle-ci prend sa place dans la liste.
    order    = 65,

    defaults = {
        -- La clé garde son nom de l'époque où elle vivait sous un autre module :
        -- un palier de migration la déplace telle quelle, et la renommer en même
        -- temps aurait doublé ce qu'il y a à se tromper pour rien.
        queueTimer = false,
    },

    options = {
        { type = "header", text = L["Queues"] },
        {
            type    = "toggle",
            key     = "queueTimer",
            text    = L["Queue popup timer"],
            tooltip = L["Queue popup timer tip"],
        },
    },

    OnEnable = function(self)
        -- Un événement que le client a retiré se refuse bruyamment : on demande
        -- avant de s'abonner. `LFG_PROPOSAL_SHOW` n'a pas de raison connue de
        -- manquer sur *Forever* — c'est un événement du moteur, pas de la
        -- fenêtre absente —, mais c'est la fenêtre qui manque déjà, et une
        -- hypothèse de moins ne coûte qu'une ligne.
        local valid = not (C_EventUtils and C_EventUtils.IsEventValid)
                      or C_EventUtils.IsEventValid("LFG_PROPOSAL_SHOW")
        if valid then
            self:RegisterEvent("LFG_PROPOSAL_SHOW", function() watchProposal(self) end)
        end

        self:RegisterEvent("UPDATE_BATTLEFIELD_STATUS", function() watchBattlefield(self) end)
    end,

    OnDisable = function()
        stopCountdowns()
    end,

    OnSettingChanged = function(self, key)
        -- Décocher le minuteur pendant qu'une fenêtre de file est ouverte doit
        -- le faire disparaître tout de suite, pas à la fenêtre suivante.
        if key == nil or key == "queueTimer" then
            if not self:Get("queueTimer") then stopCountdowns() end
        end
    end,
})
