-- =========================================================================
--  Bshamel UI — UI/Widgets/ResourceBar.lua
--  Une rangée de cases, une par point de ressource.
--
--  Points de combo, puissance sacrée, chi, fragments d'âme, runes, cumuls
--  d'Arme-tempête : ce sont des ressources qui se **comptent**, pas qui se
--  jaugent. Une barre continue oblige à estimer une longueur pour retrouver un
--  nombre qu'on connaissait déjà ; cinq cases se lisent sans être comptées.
--
--  Le widget ne sait pas ce qu'il montre. On lui dit combien de cases, de quelle
--  taille, de quelle teinte, et combien sont pleines — c'est
--  `Modules/ClassResource.lua` qui sait laquelle des sept ressources le
--  personnage porte. C'est la même séparation que partout ailleurs.
--
--  **Les cases sont des textures, pas des frames.** Une case n'a ni enfant, ni
--  script, ni souris à elle : douze frames pour douze rectangles se paieraient à
--  chaque point dépensé, et la souris du panneau suffit à le déplacer d'un bloc.
--  Elles sont construites une fois au plafond du thème et montrées par ce qu'il
--  en faut — une frame ne se détruit pas en World of Warcraft (règle 7).
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local U    = BUI.Util
local W    = BUI.Widgets

--- Une case : son liseré sombre et son remplissage.
---
--- Le remplissage est le carré blanc du moteur, **teinté** par la couleur de
--- sommet et non reposé : `SetVertexColor` ne fait que multiplier ce qui est déjà
--- dessiné, là où `SetColorTexture` reconstruirait la texture à chaque point
--- gagné ou perdu.
---@param panel table
---@return table
local function newCell(panel)
    local edge = panel:CreateTexture(nil, "BACKGROUND")
    edge:SetColorTexture(T.COLOR.SHADE:GetRGB())
    edge:SetAlpha(T.ALPHA.RESOURCE_EDGE)

    local fill = panel:CreateTexture(nil, "ARTWORK")
    fill:SetTexture(T.TEXTURE.STATUSBAR_FLAT)

    local inset = T.SIZE.RESOURCE_EDGE
    fill:SetPoint("TOPLEFT",     edge, "TOPLEFT",      inset, -inset)
    fill:SetPoint("BOTTOMRIGHT", edge, "BOTTOMRIGHT", -inset,  inset)

    return { edge = edge, fill = fill }
end

---@class BUI.ResourceBarOpts
---@field getPos? fun(): number, number
---@field setPos? fun(x: number, y: number)
---@field isLocked? fun(): boolean

--- Rangée de ressource, masquée au départ.
---@param opts BUI.ResourceBarOpts
---@return table
function W.ResourceBar(opts)
    -- Aucun habillage : le jeu ne met pas de cadre autour de sa propre rangée de
    -- ressource, et un panneau posé derrière celle-ci en ferait une pièce
    -- rapportée. Le panneau ne sert plus qu'à ce qu'une texture ne sait pas
    -- faire — prendre la souris, se déplacer, retenir sa position.
    local panel = W.Panel({
        width    = T.SIZE.RESOURCE_CELL_W,
        height   = T.SIZE.RESOURCE_CELL_H,
        chrome   = "none",
        getPos   = opts.getPos,
        setPos   = opts.setPos,
        isLocked = opts.isLocked,
    })

    local cells = {}
    for i = 1, T.SIZE.RESOURCE_MAX_CELLS do
        cells[i] = newCell(panel)
    end

    -- Le nombre au milieu de la rangée, et non dans un coin : c'est la même
    -- valeur que les cases, écrite pour qui préfère lire un chiffre. Blanc à
    -- contour, parce qu'il se pose sur des cases dont la teinte est au choix du
    -- joueur (voir `T.FONT.RESOURCE`).
    local text = panel:CreateFontString(nil, "OVERLAY", T.FONT.RESOURCE)
    text:SetPoint("CENTER", panel, "CENTER", 0, 0)
    text:SetJustifyH("CENTER")
    text:SetTextColor(T.COLOR.LABEL:GetRGB())
    panel.text = text

    -- État courant. Tout est relu par `paint`, qui est le seul à peindre.
    -- Zéro case tant que l'appelant n'a pas dit combien : une case posée sans
    -- taille ni ancrage ne se dessine pas, mais la peindre serait peindre
    -- quelque chose dont on ne sait encore rien.
    local shownCells = 0
    local value      = 0
    local threshold  = 0
    local fillColor  = T.COLOR.RESOURCE_FILL
    local alertColor = T.COLOR.RESOURCE_ALERT
    local showCount  = false

    -- ---------------------------------------------------------------------
    --  Peinture
    -- ---------------------------------------------------------------------

    --- **Le palier teint toute la rangée, pas la seule case franchie.** Ce que le
    --- réglage annonce est « à partir de X, la ressource change de couleur » : une
    --- rangée dont seule la dernière case vire dirait l'inverse — que c'est cette
    --- case-là qui compte, alors que c'est le total.
    local function paint()
        local color = fillColor
        if threshold > 0 and value >= threshold then color = alertColor end

        local r, g, b = color:GetRGB()
        for i = 1, shownCells do
            local fill = cells[i].fill
            fill:SetVertexColor(r, g, b)
            fill:SetAlpha(i <= value and 1 or T.ALPHA.RESOURCE_EMPTY)
        end

        text:SetText(showCount and tostring(value) or "")
    end

    -- ---------------------------------------------------------------------
    --  Disposition
    -- ---------------------------------------------------------------------

    --- Combien de cases, et de quelle taille. Les mesures sont bornées ici plutôt
    --- qu'à l'appel : c'est le widget qui connaît la rangée qu'il sait dessiner.
    ---@param count number   cases affichées
    ---@param width number   largeur d'une case
    ---@param height number  hauteur d'une case
    ---@param gap number     écart entre deux cases
    ---@param perRow number  cases par rangée ; 0 = toutes sur une seule
    function panel:SetLayout(count, width, height, gap, perRow)
        shownCells = math.floor(U.Clamp(count or 1, 1, T.SIZE.RESOURCE_MAX_CELLS))

        local cellW = U.Clamp(width or T.SIZE.RESOURCE_CELL_W,
            T.SIZE.RESOURCE_CELL_MIN, T.SIZE.RESOURCE_CELL_MAX)
        local cellH = U.Clamp(height or T.SIZE.RESOURCE_CELL_H,
            T.SIZE.RESOURCE_CELL_MIN, T.SIZE.RESOURCE_CELL_MAX)
        local space = U.Clamp(gap or T.SIZE.RESOURCE_GAP, 0, T.SIZE.RESOURCE_GAP_MAX)

        -- **Le pliage se dit en colonnes, pas en rangées.** Dix cumuls sur deux
        -- rangées et dix cumuls pliés à cinq sont la même disposition, mais la
        -- seconde formulation est la seule qui survive à un changement de
        -- personnage : le nombre de cases, lui, n'est pas au choix du joueur.
        -- Demander « deux rangées » sur une ressource à cinq cases donnerait
        -- deux rangées de deux et demie.
        --
        -- Zéro, ou plus large que la rangée, veut dire « tout d'un tenant » :
        -- c'est le repli, et c'est la disposition d'origine.
        local columns = math.floor(U.Clamp(perRow or 0, 0, T.SIZE.RESOURCE_MAX_CELLS))
        if columns <= 0 or columns > shownCells then columns = shownCells end

        local rows  = math.ceil(shownCells / columns)
        local stepX = cellW + space
        -- Le même écart dans les deux sens. Deux réglages pour ce qui se lit
        -- comme un seul espacement donneraient une grille qu'on peut rendre
        -- bancale sans le vouloir.
        local stepY = cellH + space

        self:SetSize(columns * cellW + (columns - 1) * space,
                     rows    * cellH + (rows    - 1) * space)

        for i = 1, T.SIZE.RESOURCE_MAX_CELLS do
            local cell = cells[i]
            local used = i <= shownCells

            if used then
                -- **Une rangée incomplète reste calée à gauche.** Sept cases
                -- pliées à cinq donnent cinq puis deux, sous les deux premières :
                -- c'est l'ordre dans lequel elles se remplissent, et la colonne
                -- où l'œil revient. Centrer la dernière casserait la grille pour
                -- gagner une symétrie que personne ne lit.
                local col = (i - 1) % columns
                local row = math.floor((i - 1) / columns)

                cell.edge:ClearAllPoints()
                cell.edge:SetPoint("TOPLEFT", self, "TOPLEFT", col * stepX, -row * stepY)
                cell.edge:SetSize(cellW, cellH)
            end

            cell.edge:SetShown(used)
            cell.fill:SetShown(used)
        end

        -- Le corps du nombre suit la hauteur des cases : un nombre au corps fixe
        -- se perd dans une rangée agrandie et déborde d'une rangée réduite.
        T.SetTextSize(text, T.ResourceTextSize(cellH))

        -- La rangée vient de changer de largeur : on la repose, sans quoi elle
        -- aurait grandi à partir du coin que l'ancrage lui donne au lieu de
        -- grossir autour de son centre (voir `W.Panel:ApplyPosition`).
        self:ApplyPosition()

        if value > shownCells then value = shownCells end
        paint()
    end

    --- Teintes de la rangée, et à partir de combien de cases la seconde remplace
    --- la première. Un palier nul, ou plus haut que la rangée, éteint le
    --- mécanisme sans l'expliquer — c'est à l'appelant de griser son réglage.
    ---@param fill ColorMixin
    ---@param alert ColorMixin
    ---@param at number  cases à partir desquelles `alert` s'applique ; 0 = jamais
    function panel:SetPalette(fill, alert, at)
        fillColor  = fill  or T.COLOR.RESOURCE_FILL
        alertColor = alert or T.COLOR.RESOURCE_ALERT
        threshold  = math.floor(math.max(at or 0, 0))
        paint()
    end

    --- Cases pleines.
    ---@param count number
    function panel:SetValue(count)
        value = math.floor(U.Clamp(count or 0, 0, shownCells))
        paint()
    end

    --- Écrit ou non le nombre au milieu de la rangée.
    ---@param on boolean
    function panel:SetShowCount(on)
        showCount = on and true or false
        paint()
    end

    -- ---------------------------------------------------------------------
    --  Aperçu
    -- ---------------------------------------------------------------------
    -- La rangée se remplit toute seule, case après case, et repart de zéro.
    --
    -- Une rangée d'exemple **figée** ne montrerait que la moitié de ce qu'on
    -- règle : elle dit où la poser, pas ce que le palier fait. En la faisant
    -- monter, on voit la teinte changer à l'endroit exact où on a mis le curseur
    -- — c'est le seul moyen de régler un palier sans aller le vérifier en combat.
    --
    -- Bridé comme tout `OnUpdate` (règle 7), et un cadre caché n'en reçoit pas :
    -- l'aperçu éteint ne coûte rien.

    local cycle = U.Throttle(T.TIMING.RESOURCE_PREVIEW, function()
        panel:SetValue(value >= shownCells and 0 or value + 1)
    end)

    --- Allume ou éteint l'aperçu animé.
    ---@param on boolean
    function panel:SetPreview(on)
        self:SetScript("OnUpdate", on and cycle or nil)
        if not on then return end
        self:SetValue(0)
    end

    paint()
    return panel
end
