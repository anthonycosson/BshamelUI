-- =========================================================================
--  Bshamel UI — Modules/CooldownManager.lua
--  Le gestionnaire de temps de recharge du client, repris là où sa disposition
--  laisse des trous.
--
--  Le module ne dessine rien et ne masque rien : il repose les emplacements que
--  le client vient de poser, quelques pixels plus loin. Il ne mémorise rien non
--  plus — la grille du client se **calcule**, ce qui permet aussi bien de la
--  retasser que de la rendre telle quelle quand le module s'éteint (règle 6).
--
--  `secure = true` : les emplacements portent des sorts. Les reposer n'est pas
--  une action protégée, mais la règle est de le déclarer dès qu'on touche à ces
--  cadres — le core diffère alors l'activation à la sortie de combat, ce qui ne
--  coûte rien ici.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local U    = BUI.Util
local L    = ns.L

local MODULE = "CooldownManager"

-- =========================================================================
--  Suivi des améliorations : une rangée sans trous
-- =========================================================================
-- Le client réserve **une place par amélioration suivie**, et il les garde
-- toutes : quand une amélioration tombe, sa place reste vide et les autres
-- restent écartées de part et d'autre du trou. Deux améliorations actives sur
-- cinq suivies s'affichent donc aux deux bouts, à trois places l'une de l'autre.
--
-- Ce n'est pas un décalage de la rangée — elle est déjà centrée, et la déplacer
-- ne changerait rien. Ce qu'il faut, c'est **retasser** les améliorations
-- affichées les unes contre les autres, au milieu de la grille.
--
-- La grille se relève entièrement sur des cadres qu'on ne touche jamais : le
-- conteneur, dont la boîte couvre exactement les places réservées, et la liste
-- des emplacements, qui les donne dans l'ordre. Rien n'est mémorisé d'un
-- passage à l'autre, et c'est la propriété qui compte : une mémoire de
-- positions se désynchronise du client tôt ou tard, et le calcul dérive alors
-- sans jamais se remettre d'aplomb.

--- Visionneuse du suivi des améliorations, par nom global. C'est la seule des
--- quatre dont le nombre d'entrées **affichées** varie : les visionneuses
--- essentielle et utilitaire montrent tous leurs sorts en permanence, donc leur
--- rangée n'a jamais de trou.
local VIEWER = "BuffIconCooldownViewer"

--- Méthodes après lesquelles la disposition a pu changer.
---
--- `RefreshLayout` et `Layout` sont les deux façons dont le client recalcule
--- ses positions, donc les deux façons de défaire notre tassement. `OnUnitAura`
--- est là pour la raison inverse : une amélioration qui tombe **ne provoque
--- aucun recalcul** — c'est bien pourquoi la place reste vide — et sans ce
--- troisième point d'accroche, le trou resterait affiché jusqu'à ce qu'autre
--- chose fasse bouger la visionneuse.
local RELAYOUT_METHODS = { "RefreshLayout", "Layout", "OnUnitAura" }

--- En deçà, on ne repose rien. À ce niveau de précision le décalage ne se voit
--- plus, et reposer un ancrage peut faire recalculer la disposition, donc nous
--- rappeler : sans ce seuil, un demi-pixel suffirait à entretenir la boucle.
local EPSILON = 0.5

--- Géométrie relevée au passage courant. Table de travail : le tassement tourne
--- à chaque changement d'améliorations, donc dans un chemin chaud (règle 7).
local g = {}

--- Vrai pendant qu'on repose les ancrages : le client peut réagir en
--- recalculant sa disposition, donc en nous rappelant. Le drapeau coupe la
--- boucle.
local packing = false

--- Passage différé, construit à l'activation.
local settle

--- Une place est occupée quand elle est affichée **et** pleinement opaque : le
--- client efface en fondu, et une amélioration en train de disparaître compte
--- encore pour une place tant qu'on la regarde à l'instant où il l'annonce.
---@param icon table
---@return boolean
local function isLive(icon)
    return icon:IsShown() and icon:GetAlpha() >= 1
end

--- Décalage d'un emplacement sur l'axe de la rangée.
---
--- Un seul jeu de formules pour les deux orientations : on raisonne sur un axe
--- qui **croît dans le sens où la rangée se remplit** — vers la droite à
--- l'horizontale, vers le bas à la verticale. L'ordonnée de l'écran croît vers
--- le haut, d'où le signe.
---@param icon table
---@param horizontal boolean
---@return number|nil
local function alongOf(icon, horizontal)
    -- Un seul ancrage : c'est ce que pose la disposition du client. Déplacer
    -- l'un des deux ancrages d'un cadre qui en aurait deux l'étirerait au lieu
    -- de le déplacer.
    if icon:GetNumPoints() ~= 1 then return nil end

    local _, _, _, x, y = icon:GetPoint(1)
    if not (x and y) then return nil end

    return horizontal and x or -y
end

--- Relève la grille du client dans `g`. Renvoie faux si elle n'est pas lisible,
--- auquel cas on ne touche à rien : mieux vaut ne rien faire que déplacer au
--- hasard.
---@param viewer table
---@return boolean
local function measure(viewer)
    local container = viewer:GetItemContainerFrame()
    local icons     = viewer:GetItemFrames()
    if not (container and icons) then return false end

    local n = #icons
    if n < 2 then return false end

    local first      = icons[1]
    local horizontal = viewer.isHorizontal ~= false

    local size = horizontal and first:GetWidth() or first:GetHeight()
    if not size or size <= 0 then return false end

    -- Nombre de places par rangée. Au-delà, le client passe à la ligne.
    local cols = viewer.stride or n
    if cols > n then cols = n end
    if cols < 2 then return false end

    -- La boîte du conteneur couvre exactement les places réservées : le pas s'en
    -- déduit sans rien mesurer sur les emplacements eux-mêmes — dont la position
    -- vient peut-être de nous.
    --
    -- **Les deux ne sont pas dans la même échelle.** Le client agrandit ses
    -- icônes sans agrandir le conteneur, et un décalage d'ancrage s'exprime dans
    -- l'échelle du cadre qu'il place. Relevé : conteneur à 725,5 pour une
    -- première place à 659,6, soit un rapport de 1,1 — sans cette conversion,
    -- tout est faux de dix pour cent.
    local boxScale   = container:GetEffectiveScale()
    local frameScale = first:GetEffectiveScale()
    if not (boxScale and frameScale) or frameScale <= 0 then return false end

    local box = horizontal and container:GetWidth() or container:GetHeight()
    if not box or box <= 0 then return false end
    box = box * boxScale / frameScale

    local pitch = (box - size) / (cols - 1)

    -- Le pas d'une grille tient entre une place et deux : le client ne fait ni
    -- chevaucher deux emplacements, ni laisser une place entière entre eux. Hors
    -- de ces bornes, ce qu'on vient de lire ne décrit pas la grille.
    if pitch < size or pitch > size * 2 then
        pitch = nil

        -- Deuxième source, pour le cas où le conteneur ne serait pas taillé sur
        -- les places réservées : l'écart entre deux places **inoccupées et
        -- voisines**. Une place inoccupée n'a jamais été déplacée par nous — on
        -- ne bouge que ce qui est affiché — donc son décalage est celui du
        -- client, et deux places voisines donnent le pas.
        for i = 1, n - 1 do
            if (i % cols) ~= 0 and not isLive(icons[i]) and not isLive(icons[i + 1]) then
                local a = alongOf(icons[i], horizontal)
                local b = alongOf(icons[i + 1], horizontal)

                if a and b then
                    local step = b - a
                    if step >= size and step <= size * 2 and (not pitch or step < pitch) then
                        pitch = step
                    end
                end
            end
        end

        if not pitch then return false end
    end

    g.icons, g.n, g.cols          = icons, n, cols
    g.size, g.pitch, g.horizontal = size, pitch, horizontal

    -- Étendue de la grille, déduite du pas et non relue sur le conteneur : les
    -- deux coïncident quand le conteneur est taillé dessus, et c'est celle-ci
    -- qui reste juste quand il ne l'est pas.
    g.extent = (cols - 1) * pitch + size

    return true
end

--- Repose un emplacement à un décalage donné sur l'axe de la rangée. Sa
--- position sur l'axe transverse ne bouge pas : c'est le client qui l'a posée,
--- et rien ici n'a de raison d'en changer.
---@param icon table
---@param along number
local function place(icon, along)
    if icon:GetNumPoints() ~= 1 then return end

    local point, relativeTo, relativePoint, x, y = icon:GetPoint(1)
    if not (point and x and y) then return end

    local current = g.horizontal and x or -y
    local delta   = along - current
    if delta <= EPSILON and delta >= -EPSILON then return end

    if g.horizontal then
        icon:SetPoint(point, relativeTo, relativePoint, along, y)
    else
        icon:SetPoint(point, relativeTo, relativePoint, x, -along)
    end
end

--- Retasse les améliorations affichées au milieu de la grille.
---
--- Le calcul est **idempotent** : les places visées sont des positions absolues,
--- déduites de la grille et de rien d'autre. Un deuxième passage vise donc les
--- mêmes, ce qui autorise les trois points d'accroche à se recouvrir.
---@param mod table
local function repack(mod)
    if packing then return end
    -- Le passage différé peut arriver après l'extinction du module, qui vient
    -- de tout rendre : sans cette garde, il retasserait derrière lui.
    if not mod:IsEnabled() then return end
    if not mod:Get("centerTrackedBuffs") then return end

    local viewer = _G[VIEWER]
    if not (viewer and viewer.GetItemFrames and viewer.GetItemContainerFrame) then return end
    if not measure(viewer) then return end

    packing = true

    local icons, cols = g.icons, g.cols
    local rows = math.ceil(g.n / cols)

    for row = 0, rows - 1 do
        local from = row * cols + 1
        local to   = math.min(g.n, from + cols - 1)

        local shown = 0
        for i = from, to do
            if isLive(icons[i]) then shown = shown + 1 end
        end

        if shown > 0 then
            local start = (g.extent - ((shown - 1) * g.pitch + g.size)) / 2
            local rank  = 0

            -- L'ordre vient de la **liste** des emplacements, jamais de leur
            -- position : une position vient peut-être de nous, l'ordre des
            -- places est celui du client et ne bouge pas.
            for i = from, to do
                local icon = icons[i]
                if isLive(icon) then
                    place(icon, start + rank * g.pitch)
                    rank = rank + 1
                end
            end
        end
    end

    packing = false
end

--- Rend chaque emplacement à sa place dans la grille du client.
---
--- Elle se calcule comme le reste — la place `i` est à `i` fois le pas — donc
--- il n'y a rien à avoir mémorisé pour la rendre. Si la grille n'est pas
--- lisible, on demande au client de la recalculer : c'est le seul recours qui
--- reste, et à cet instant notre hook est déjà inerte.
local function restore()
    local viewer = _G[VIEWER]
    if not (viewer and viewer.GetItemFrames and viewer.GetItemContainerFrame) then return end

    if not measure(viewer) then
        if viewer.RefreshLayout then viewer:RefreshLayout() end
        return
    end

    packing = true

    for i = 1, g.n do
        place(g.icons[i], ((i - 1) % g.cols) * g.pitch)
    end

    packing = false
end

--- S'accroche à la disposition de la visionneuse.
---
--- `U.GuardedHook` est le seul motif de hook autorisé (règle 6) : posé une fois,
--- rendu inerte quand le module s'éteint. Il ne pose jamais deux fois le même,
--- ce qui permet d'appeler cette fonction à chaque fois qu'on soupçonne la
--- visionneuse d'être apparue.
---@param mod table
local function hookViewer(mod)
    local viewer = _G[VIEWER]
    if not viewer then return end

    local guard = function() return mod:IsEnabled() end

    for i = 1, #RELAYOUT_METHODS do
        local method = RELAYOUT_METHODS[i]
        if type(viewer[method]) == "function" then
            U.GuardedHook(viewer, method, function()
                BUI.safecall(repack, mod)
                -- Une amélioration qui tombe s'efface en fondu : au moment où le
                -- client l'annonce, son emplacement est encore opaque, donc
                -- encore compté. Le second passage voit la rangée retombée.
                if settle then settle() end
            end, guard)
        end
    end
end

-- =========================================================================
--  Déclaration du module
-- =========================================================================

BUI:RegisterModule(MODULE, {
    title    = L["Cooldown manager"],
    category = "Interface",
    order    = 25,
    secure   = true,

    defaults = {
        centerTrackedBuffs = false,
    },

    options = {
        { type = "header", text = L["Tracked buffs"] },
        {
            type    = "toggle",
            key     = "centerTrackedBuffs",
            text    = L["Center tracked buffs"],
            tooltip = L["Center tracked buffs tip"],
        },
    },

    OnEnable = function(self)
        settle = settle or U.Debounce(T.TIMING.CDM_SETTLE, function()
            BUI.safecall(repack, self)
        end)

        hookViewer(self)
        BUI.safecall(repack, self)

        -- Les emplacements sortent d'un pool que le client remplit au fur et à
        -- mesure : la visionneuse peut exister sans qu'aucune amélioration n'ait
        -- encore de cadre, et elle-même peut n'apparaître qu'après nous. On
        -- repasse donc à chaque frontière de zone, où l'interface se reconstruit.
        self:RegisterEvent("PLAYER_ENTERING_WORLD", function()
            hookViewer(self)
            BUI.safecall(repack, self)
        end)
    end,

    OnDisable = function()
        BUI.safecall(restore)
    end,

    OnSettingChanged = function(self, key)
        if key ~= nil and key ~= "centerTrackedBuffs" then return end

        if self:Get("centerTrackedBuffs") then
            BUI.safecall(repack, self)
        else
            BUI.safecall(restore)
        end
    end,
})
