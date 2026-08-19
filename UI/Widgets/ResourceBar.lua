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
--- Le remplissage est **teinté** par la couleur de sommet et non reposé :
--- `SetVertexColor` ne fait que multiplier ce qui est déjà dessiné, là où
--- `SetColorTexture` reconstruirait la texture à chaque point gagné ou perdu.
---@param panel table
---@return table
local function newCell(panel)
    local edge = panel:CreateTexture(nil, "BACKGROUND")
    local fill = panel:CreateTexture(nil, "ARTWORK")

    -- Coins arrondis, comme ceux que le client donne aux barres de la ressource
    -- personnelle : le liseré sombre du thème et le remplissage prennent tous
    -- deux le carré arrondi du thème, et c'est la découpe en neuf qui garde le
    -- rayon net sur une case étirée (voir `T.TEXTURE.ROUNDED_RECT` — les marges
    -- se posent dans `SetLayout`, qui seul connaît la taille des cases).
    --
    -- Test de capacité (règle 1) : un client sans découpe en neuf garde les
    -- angles droits plutôt qu'un rayon qui s'étire en ellipse.
    if edge.SetTextureSliceMargins then
        edge:SetTexture(T.TEXTURE.ROUNDED_RECT)
        edge:SetVertexColor(T.COLOR.SHADE:GetRGB())
        fill:SetTexture(T.TEXTURE.ROUNDED_RECT)
    else
        edge:SetColorTexture(T.COLOR.SHADE:GetRGB())
        fill:SetTexture(T.TEXTURE.STATUSBAR_FLAT)
    end
    edge:SetAlpha(T.ALPHA.RESOURCE_EDGE)

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

    -- ---------------------------------------------------------------------
    --  Effet brillant
    -- ---------------------------------------------------------------------
    -- Le contour allumé que des comètes parcourent. Il a été inventé ici, pour
    -- cette rangée, puis le module PvP en a voulu le même autour de l'entrave
    -- posée sur le soigneur : il vit désormais dans `UI/Widgets/TrackGlow.lua`,
    -- et c'est bien la même lueur des deux côtés — pas deux qui se ressemblent.
    --
    -- Ce qui reste ici est ce que la rangée seule sait dire : le contour qu'il
    -- faut parcourir (`SetTrack`, dans la disposition) et le seuil à partir
    -- duquel il s'allume (`SetRunning`, dans la peinture).
    local glow = W.TrackGlow(panel)

    -- Le nombre au milieu de la rangée, et non dans un coin : c'est la même
    -- valeur que les cases, écrite pour qui préfère lire un chiffre. Blanc à
    -- contour, parce qu'il se pose sur des cases dont la teinte est au choix du
    -- joueur (voir `T.FONT.RESOURCE`).
    --
    -- Il vit sur un cadre à lui, **au-dessus de la lueur**. Depuis que celle-ci
    -- passe par-dessus les cases, un nombre posé sur le panneau passerait dessous
    -- — et un chiffre noyé dans un tourbillon ne se lit plus. C'est la seule
    -- raison de ce cadre : rien n'y est dessiné d'autre.
    local overlay = CreateFrame("Frame", nil, panel)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(glow:GetFrameLevel() + 1)

    local text = overlay:CreateFontString(nil, "OVERLAY", T.FONT.RESOURCE)
    text:SetPoint("CENTER", panel, "CENTER", 0, 0)
    text:SetJustifyH("CENTER")
    text:SetTextColor(T.COLOR.LABEL:GetRGB())
    panel.text = text

    -- État courant. Tout est relu par `paint`, qui est le seul à peindre.
    -- Zéro case tant que l'appelant n'a pas dit combien : une case posée sans
    -- taille ni ancrage ne se dessine pas, mais la peindre serait peindre
    -- quelque chose dont on ne sait encore rien.
    --
    -- **Deux comptes et non un.** `totalCells` est ce que la ressource compte —
    -- dix cumuls d'Arme-tempête —, `shownCells` ce qui est dessiné. Les deux ne
    -- diffèrent que si l'appelant a demandé un repli, et c'est cet écart qui fait
    -- la boucle : la rangée repart de zéro au lieu de s'allonger.
    local totalCells = 0
    local shownCells = 0
    local value      = 0
    local fillColor  = T.COLOR.RESOURCE_FILL
    local showCount  = false
    local glowAt     = 0

    --- Paliers de couleur, du plus bas au plus haut : `{ at = , color = }`.
    --- Table de travail au niveau du widget, réécrite en place par `SetPalette` —
    --- en construire une neuve à chaque changement de réglage serait en construire
    --- une par mouvement de curseur.
    local steps = {}

    -- ---------------------------------------------------------------------
    --  Peinture
    -- ---------------------------------------------------------------------

    --- Combien de cases sont allumées, une fois la boucle prise en compte.
    ---
    --- Sans repli, c'est la valeur elle-même. Avec, c'est le reste de sa division
    --- — mais un reste **nul sur une valeur non nulle vaut la rangée entière** :
    --- dix points sur cinq cases est une rangée pleine au second tour, pas une
    --- rangée vide. C'est la seule règle de tout ce mécanisme, et c'est le seul
    --- endroit où elle est écrite.
    ---@return number
    local function litCells()
        if shownCells <= 0 then return 0 end
        if value <= shownCells then return value end

        local rest = value % shownCells
        return rest == 0 and shownCells or rest
    end

    --- Teinte courante de la rangée : le palier le plus haut que la valeur
    --- atteint, ou la couleur de remplissage si elle n'en atteint aucun.
    ---
    --- **Le dernier franchi écrase les précédents.** Trois paliers se lisent comme
    --- une montée, et une montée ne montre qu'un état à la fois : à sept points
    --- avec des paliers à trois, cinq et huit, c'est celui de cinq qui parle.
    --- Les paliers arrivent triés (voir `SetPalette`), on lit donc à l'envers et
    --- on s'arrête au premier qui répond.
    ---@return ColorMixin
    local function stepColor()
        for i = #steps, 1, -1 do
            if value >= steps[i].at then return steps[i].color end
        end
        return fillColor
    end

    --- **Le palier teint toute la rangée, pas la seule case franchie.** Ce que le
    --- réglage annonce est « à partir de X, la ressource change de couleur » : une
    --- rangée dont seule la dernière case vire dirait l'inverse — que c'est cette
    --- case-là qui compte, alors que c'est le total.
    ---
    --- Les paliers se jugent sur la valeur **réelle**, jamais sur les cases
    --- allumées. C'est ce qui rend la boucle lisible : à cinq cases pour dix
    --- points, la teinte dit à quel tour on en est et le compte dit où l'on est
    --- dedans.
    local function paint()
        local lit = litCells()

        local r, g, b = stepColor():GetRGB()
        for i = 1, shownCells do
            local fill = cells[i].fill
            fill:SetVertexColor(r, g, b)
            fill:SetAlpha(i <= lit and 1 or T.ALPHA.RESOURCE_EMPTY)
        end

        -- Le nombre écrit est la valeur **réelle**, pas les cases allumées : il
        -- est le seul endroit qui lève l'ambiguïté d'une rangée pleine au premier
        -- ou au second tour, et il ne servirait à rien s'il répétait ce que les
        -- cases montrent déjà.
        text:SetText(showCount and tostring(value) or "")

        -- L'effet brillant a son propre seuil : il ne suit aucun palier de
        -- couleur, et rien n'oblige les deux à tomber au même endroit.
        local shine = glowAt > 0 and value >= glowAt

        -- La teinte de la lueur ne suit pas la rangée : elle est **dorée**, comme
        -- tout ce que le jeu allume. Les cases disent où l'on en est, la lueur dit
        -- que c'est prêt — deux choses différentes, deux vocabulaires.
        glow:SetRunning(shine)
    end

    -- ---------------------------------------------------------------------
    --  Disposition
    -- ---------------------------------------------------------------------

    --- Combien de cases, et de quelle taille. Les mesures sont bornées ici plutôt
    --- qu'à l'appel : c'est le widget qui connaît la rangée qu'il sait dessiner.
    ---
    --- **La rangée reste une rangée.** `wrapAt` ne la plie pas sur une seconde
    --- ligne : il la raccourcit, et ce qui dépasse repart de zéro dans les mêmes
    --- cases. C'est ce qui permet à dix cumuls d'Arme-tempête de tenir dans
    --- l'encombrement de cinq — cinq grandes cases plutôt que dix petites, au même
    --- endroit et à la même place à l'écran.
    ---
    --- Le prix est une ambiguïté, et elle est assumée : cinq cases pleines
    --- veulent dire cinq points ou dix. C'est la teinte du palier qui dit lequel,
    --- et le nombre au milieu si on l'a demandé.
    ---@param count number   points que la ressource compte
    ---@param width number   largeur d'une case
    ---@param height number  hauteur d'une case
    ---@param gap number     écart entre deux cases
    ---@param wrapAt number  cases dessinées avant de repartir de zéro ; 0 = toutes
    function panel:SetLayout(count, width, height, gap, wrapAt)
        totalCells = math.floor(U.Clamp(count or 1, 1, T.SIZE.RESOURCE_MAX_CELLS))

        -- Zéro, ou plus long que la ressource, veut dire « tout d'un tenant » :
        -- c'est le repli, et c'est la disposition d'origine.
        shownCells = math.floor(U.Clamp(wrapAt or 0, 0, T.SIZE.RESOURCE_MAX_CELLS))
        if shownCells <= 0 or shownCells > totalCells then shownCells = totalCells end

        local cellW = U.Clamp(width or T.SIZE.RESOURCE_CELL_W,
            T.SIZE.RESOURCE_CELL_MIN, T.SIZE.RESOURCE_CELL_MAX)
        local cellH = U.Clamp(height or T.SIZE.RESOURCE_CELL_H,
            T.SIZE.RESOURCE_CELL_MIN, T.SIZE.RESOURCE_CELL_MAX)
        local space = U.Clamp(gap or T.SIZE.RESOURCE_GAP, 0, T.SIZE.RESOURCE_GAP_MAX)

        local stepX = cellW + space
        local rowW  = shownCells * cellW + (shownCells - 1) * space

        -- Marges de la découpe en neuf, bornées à la demi-case : au-delà, les
        -- deux coins d'un même bord se chevauchent et la découpe se déchire.
        -- Le remplissage, en retrait du liseré, arrondit d'autant moins — deux
        -- courbes parallèles n'ont pas le même rayon.
        local edgeRound = math.min(T.SIZE.ROUNDED_RECT_RADIUS,
                                   math.floor(math.min(cellW, cellH) / 2))
        local fillRound = math.max(edgeRound - T.SIZE.RESOURCE_EDGE, 1)

        self:SetSize(rowW, cellH)

        -- Le contour que les traits parcourent est celui de la rangée. Leur cœur
        -- se pose **à l'intérieur** du bord ; ce sont leurs halos qui débordent
        -- des deux côtés, et c'est ce débordement qui fait la lueur.
        glow:SetTrack(rowW, cellH)

        for i = 1, T.SIZE.RESOURCE_MAX_CELLS do
            local cell = cells[i]
            local used = i <= shownCells

            if used then
                cell.edge:ClearAllPoints()
                cell.edge:SetPoint("TOPLEFT", self, "TOPLEFT", (i - 1) * stepX, 0)
                cell.edge:SetSize(cellW, cellH)

                if cell.edge.SetTextureSliceMargins then
                    cell.edge:SetTextureSliceMargins(edgeRound, edgeRound,
                                                     edgeRound, edgeRound)
                    cell.fill:SetTextureSliceMargins(fillRound, fillRound,
                                                     fillRound, fillRound)
                end
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

        if value > totalCells then value = totalCells end
        paint()
    end

    --- Teinte de base de la rangée, et les paliers qui la remplacent.
    ---
    --- Un palier vaut `{ at = , color = }` ; un `at` nul ou négatif est ignoré,
    --- ce qui est la façon dont l'appelant éteint un palier qu'il ne veut pas.
    --- La liste est **triée ici**, une fois : l'ordre dans lequel la page les
    --- présente n'est pas forcément celui des valeurs, et `paint` tourne bien plus
    --- souvent que ce réglage.
    ---@param fill ColorMixin
    ---@param levels table  liste de { at = number, color = ColorMixin }
    function panel:SetPalette(fill, levels)
        fillColor = fill or T.COLOR.RESOURCE_FILL

        wipe(steps)
        for i = 1, #(levels or {}) do
            local level = levels[i]
            local at    = math.floor(math.max(level.at or 0, 0))
            if at > 0 and level.color then
                steps[#steps + 1] = { at = at, color = level.color }
            end
        end
        table.sort(steps, function(a, b) return a.at < b.at end)

        paint()
    end

    --- Points en réserve. Le compte **réel**, pas les cases à allumer : c'est le
    --- widget qui sait ce que la boucle en fait (voir `litCells`).
    ---@param count number
    function panel:SetValue(count)
        value = math.floor(U.Clamp(count or 0, 0, totalCells))
        paint()
    end

    --- Écrit ou non le nombre au milieu de la rangée.
    ---@param on boolean
    function panel:SetShowCount(on)
        showCount = on and true or false
        paint()
    end

    --- À partir de combien de points les cases pleines brillent. Zéro éteint
    --- l'effet, et c'est ainsi que l'appelant décoche sa case.
    ---@param at number
    function panel:SetGlow(at)
        glowAt = math.floor(math.max(at or 0, 0))
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

    -- Le compte **réel** et non les cases : c'est ce qui fait voir la boucle. Une
    -- rangée repliée à cinq pour dix points se remplit, repart de zéro et se
    -- remplit à nouveau dans l'autre teinte — ce qui est précisément ce qu'on
    -- règle et ce qu'on ne peut vérifier autrement qu'en combat.
    local cycle = U.Throttle(T.TIMING.RESOURCE_PREVIEW, function()
        panel:SetValue(value >= totalCells and 0 or value + 1)
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
