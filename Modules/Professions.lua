-- =========================================================================
--  Bshamel UI — Modules/Professions.lua
--  Métiers : les suivis de récolte éteints, dits par leur propre icône.
--
--  *Forever* seulement (sa ligne du `.toc` l'écarte de retail, voir
--  `CLAUDE.md` §1). Rien ici ne dépend pourtant du client : le mécanisme est
--  la liste des suivis de minicarte, que retail publie exactement pareil. La
--  page a été demandée pour Forever, elle s'y tient — retirer la directive du
--  `.toc` est le seul geste qui la livrerait ailleurs.
--
--  ## Ce que le module regarde
--
--  Un herboriste a « Recherche de plantes » dans le menu de suivi de la
--  minicarte, un mineur « Recherche de minerais ». Les deux s'éteignent sans
--  rien dire — au relogin, en cochant autre chose, en changeant de personnage —
--  et rien à l'écran ne le signale. On s'en aperçoit une zone plus loin, à la
--  quantité de nœuds qu'on n'a pas vus.
--
--  ## Un cadre, et rien dedans qu'une icône
--
--  **Une case, un cadre, et ce cadre n'écrit rien.** Il montre l'icône du
--  suivi qui manque — celle-là même que le menu de la minicarte affiche —, les
--  deux côte à côte quand les deux manquent, et il disparaît quand il n'y a
--  rien à dire. Une phrase aurait dit deux fois ce que l'image dit une : ce
--  qu'il y a à savoir de plus se lit au survol.
--
--  L'icône se clique et coche le suivi. C'est le geste du joueur, pas le
--  nôtre : l'addon ne coche **jamais** de lui-même — ce serait agir à sa place,
--  ce que la promesse interdit (règle 4), et un suivi éteint l'est parfois
--  exprès. On rapproche seulement la case de l'endroit qui dit qu'elle manque.
--
--  **Le joueur qui n'a pas le métier ne voit jamais son icône** : le sort
--  absent de la liste du client, il n'y a rien à lui dire.
--
--  **Le cadre ne se cache pas en combat**, et ce n'est pas un oubli. Il l'a
--  fait un temps : les deux bornes du combat le rangeaient et le rendaient. En
--  jeu, il restait affiché quand même, sans qu'aucune des deux questions
--  posées — `InCombatLockdown`, `UnitAffectingCombat` — n'explique pourquoi.
--  Retiré le 27 septembre 2026 plutôt que laissé à moitié : un code qui promet
--  quelque chose qu'il ne tient pas est pire que pas de code du tout, et ce
--  cadre est une icône dans un coin, pas une fenêtre au milieu de l'écran.
--
--  Le module ne dessine rien : `UI/Widgets/IconBadge.lua` pose le cadre.
--
--  Réversibilité (règle 6) : le cadre se cache, les abonnements tombent. Rien
--  n'est modifié ailleurs — le suivi du client n'est que lu, jusqu'au clic.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local U    = BUI.Util
local W    = BUI.Widgets
local L    = ns.L

local MODULE = "Professions"

-- =========================================================================
--  Ce que le client publie
-- =========================================================================

--- Les sorts de suivi, par métier.
---
--- **Deux identifiants chacun, et c'est le client qui le dit** : sa table
--- `TRACKING_SPELL_OVERRIDE_ATLAS` (`Blizzard_Minimap/Mainline/Minimap.lua`)
--- nomme « Find Herbs 1 » et « Find Herbs 2 », « Find Minerals 1 » et
--- « Find Minerals 2 » — le second rang est celui d'un métier monté. Ne
--- chercher que le premier aurait fait disparaître l'icône au moment précis où
--- le joueur progresse, ce qui est la pire façon de se taire.
---
--- Un identifiant de sort n'est pas un test de version : il ne se périme pas
--- au patch suivant, et le module échoue proprement si le client en changeait —
--- le sort ne serait pas trouvé, donc aucune icône, jamais une fausse.
local TRACKING_SPELLS = {
    herb    = { [2383] = true, [8387] = true },
    mineral = { [2580] = true, [8388] = true },
}

--- L'état du suivi d'un métier, tel que le client le publie.
---
--- **L'indice est rendu et jamais retenu.** Oublier ou apprendre un sort
--- décale la liste : un indice gardé d'une passe sur l'autre finirait par
--- désigner le suivi d'à côté, et le clic cocherait autre chose.
---@param spells table<number, boolean>
---@return boolean known   le sort est dans la liste : le joueur a le métier
---@return boolean active
---@return number|nil index
---@return any texture     la vignette du client, telle que son menu la pose
local function trackingState(spells)
    if not (C_Minimap and C_Minimap.GetNumTrackingTypes
            and C_Minimap.GetTrackingInfo) then
        return false, false
    end

    for index = 1, C_Minimap.GetNumTrackingTypes() do
        local info  = C_Minimap.GetTrackingInfo(index)
        local spell = info and info.spellID

        -- Un secret ne sert pas de clé : l'indexer lèverait, et conclure à
        -- partir de ce que le client refuse de dire serait plus faux que de
        -- passer son chemin (voir `U.IsSecret`).
        if type(spell) == "number" and not U.IsSecret(spell) and spells[spell] then
            return true, U.IsTrue(info.active), index, info.texture
        end
    end

    return false, false
end

-- =========================================================================
--  Le cadre
-- =========================================================================

--- Un métier : la clé de sa liste de sorts, et les clés de locale de son
--- infobulle. Les deux entrées sont identiques à leurs noms près — c'est ce
--- qui garantit que les deux icônes se lisent et se cliquent pareil.
local JOBS = {
    { key = "herb",    title = "Herb tracking off" },
    { key = "mineral", title = "Mineral tracking off" },
}

local badge

---@param mod table
---@param job table
---@return boolean
local function jobShown(mod, job)
    if mod:Get("preview") then return true end

    local known, active = trackingState(TRACKING_SPELLS[job.key])
    return known and not active
end

--- La vignette du suivi, prise **au client** : c'est celle que son menu
--- affiche pour cette ligne-là, donc exactement celle que le joueur cherchera
--- des yeux en allant cocher. Rien n'est embarqué de notre côté, et rien ne se
--- périme.
---
--- Sans métier, pas de vignette — et pas de case : le widget saute celle qui
--- n'a pas d'image. C'est ce qui fait que l'aperçu d'un personnage sans métier
--- ne montre rien plutôt qu'un carré vide.
---@param job table
---@return any
local function jobIcon(job)
    local _, _, _, texture = trackingState(TRACKING_SPELLS[job.key])
    return texture
end

--- Coche le suivi. **Le seul geste de la page qui touche au jeu**, et il part
--- d'un clic sur l'icône.
---
--- Rien à faire quand le suivi est déjà allumé : l'icône n'est alors pas à
--- l'écran, sauf en aperçu — d'où la relecture plutôt qu'un état retenu.
---@param job table
local function enableTracking(job)
    local known, active, index = trackingState(TRACKING_SPELLS[job.key])
    if not known or active or not index then return end
    if type(C_Minimap.SetTracking) ~= "function" then return end

    C_Minimap.SetTracking(index, true)
end

---@param mod table
local function apply(mod)
    if not mod:Get("showBadge") then
        if badge then badge:Stop() end
        return
    end

    if not badge then
        local slots = {}

        for i = 1, #JOBS do
            local job = JOBS[i]
            slots[i] = {
                shown   = function() return jobShown(mod, job) end,
                icon    = function() return jobIcon(job) end,
                title   = L[job.title],
                tip     = L["Turn tracking on tip"],
                onClick = function() enableTracking(job) end,
            }
        end

        badge = W.IconBadge({
            slots    = slots,
            isLocked = function() return mod:Get("lockBadge") == true end,
            getPos   = function() return mod:Get("badgeX"), mod:Get("badgeY") end,
            setPos   = function(x, y)
                mod:Set("badgeX", x)
                mod:Set("badgeY", y)
            end,
            getScale = function() return mod:Get("badgeScale") end,
            setScale = function(scale) mod:Set("badgeScale", scale) end,
        })
        if not badge then return end
    end

    badge:ApplyScale()
    badge:ApplyLock()
    badge:ApplyPosition()
    badge:Refresh()
end

--- La même passe, groupée. `SPELLS_CHANGED` arrive en rafale à la connexion :
--- relire la liste des suivis à chaque fois en ferait dix pour un seul état
--- (règle 7).
local queueRefresh = U.Debounce(T.TIMING.TRACKING_SETTLE, function()
    local mod = BUI.Modules:Get(MODULE)
    if mod and mod:IsEnabled() then apply(mod) end
end)

-- =========================================================================
--  Déclaration du module
-- =========================================================================

--- Grise une ligne tant que l'interrupteur qui la commande est éteint.
---@param key string
---@return fun(): boolean
local function requires(key)
    return function()
        local mod = BUI.Modules:Get(MODULE)
        return not (mod and mod:Get(key))
    end
end

BUI:RegisterModule(MODULE, {
    title    = L["Professions"],
    category = "QoL",
    -- Juste sous le chat, qui est à 40.
    order    = 45,

    defaults = {
        showBadge = false,
        preview   = false,
        lockBadge = false,
        -- Position du cadre, en décalage de centre à centre, et son échelle.
        -- Réglages sans contrôle dans la page : ils se changent en faisant
        -- glisser le cadre, ou en tirant son coin.
        badgeX     = 0,
        badgeY     = 0,
        badgeScale = 1,
    },

    options = {
        { type = "header", text = L["Gathering"] },
        {
            type    = "toggle",
            key     = "showBadge",
            text    = L["Missing tracking"],
            tooltip = L["Missing tracking tip"],
        },
        {
            type     = "toggle",
            key      = "preview",
            edit     = "preview",
            text     = L["Missing tracking preview"],
            tooltip  = L["Missing tracking preview tip"],
            disabled = requires("showBadge"),
        },
        {
            type     = "toggle",
            key      = "lockBadge",
            edit     = "lock",
            text     = L["Lock missing tracking"],
            tooltip  = L["Lock missing tracking tip"],
            disabled = requires("showBadge"),
        },
    },

    OnEnable = function(self)
        apply(self)

        -- Le client annonce chaque changement de suivi : c'est l'événement qui
        -- allume et éteint les icônes.
        self:RegisterEvent("MINIMAP_UPDATE_TRACKING", queueRefresh)

        -- Le métier appris, oublié, ou simplement rendu par le serveur à la
        -- connexion : la liste des suivis change avec lui.
        self:RegisterEvent("SPELLS_CHANGED", queueRefresh)

        -- La liste n'est pas remplie avant l'entrée en jeu, et un rechargement
        -- à chaud passe par là lui aussi.
        self:RegisterEvent("PLAYER_ENTERING_WORLD", queueRefresh)

    end,

    OnDisable = function()
        if badge then badge:Stop() end
    end,

    OnSettingChanged = function(self)
        apply(self)
    end,
})
