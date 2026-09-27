-- =========================================================================
--  Bshamel UI — UI/Widgets/IconBadge.lua
--  Une rangée d'icônes cliquables, posée à même l'écran.
--
--  Même socle que la barre d'outils de groupe (`W.Panel`, voir
--  `UI/Widgets/MarkerBar.lua`) : un cadre, un fond, une position que le joueur
--  pose une fois pour toutes, une poignée d'échelle dans le coin. Rien dedans
--  que des icônes.
--
--  **Une icône vaut la phrase qu'on n'écrit pas.** Celles qu'on y met sont
--  celles du client — l'image que le joueur a déjà vue dans le menu où il
--  devra retourner —, et le cadre n'a donc rien à expliquer : il montre ce qui
--  manque, et le clic va le chercher. Ce qu'il y aurait à dire de plus tient
--  dans l'infobulle de chaque icône, qui est l'endroit de l'addon où vivent
--  les explications.
--
--  **La rangée se recompose à chaque passage.** Les cases sont construites une
--  fois pour toutes — les frames ne se détruisent pas (règle 7) —, mais seules
--  celles qui ont quelque chose à montrer sont posées, et le cadre se remesure
--  sur elles. Une case cachée ne laisse donc pas de trou : deux icônes, une
--  icône, ou pas de cadre du tout.
--
--  Le widget ne sait pas ce qu'il montre : chaque case lui donne une fonction
--  qui dit s'il y a lieu de paraître, une qui rend l'image, et ce que le clic
--  déclenche.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local W    = BUI.Widgets

---@class BUI.IconBadgeSlot
---@field shown fun(): boolean        y a-t-il lieu de montrer cette case ?
---@field icon fun(): any             son image : identifiant de fichier ou atlas
---@field title? string               titre de son infobulle
---@field tip? string                 corps de son infobulle
---@field onClick? fun()              ce que le clic déclenche

---@class BUI.IconBadgeOpts
---@field slots BUI.IconBadgeSlot[]
---@field getPos? fun(): number, number
---@field setPos? fun(x: number, y: number)
---@field isLocked? fun(): boolean
---@field getScale? fun(): number|nil
---@field setScale? fun(scale: number)

--- Pose une image sur une texture. Un nom d'atlas ou un identifiant de
--- fichier : le premier est une chaîne, le second un nombre, et c'est tout ce
--- qu'il y a à distinguer.
---@param texture table
---@param source any
---@return boolean painted
local function paint(texture, source)
    if type(source) == "string" then
        return T.TrySetAtlas(texture, source)
    end

    if source then
        texture:SetTexture(source)
        return true
    end

    return false
end

--- Rangée d'icônes, masquée au départ.
---@param opts BUI.IconBadgeOpts
---@return table
function W.IconBadge(opts)
    local slots = opts.slots or {}

    -- Taille provisoire : le cadre se mesure sur les cases qu'il montre, à
    -- chaque passage.
    local panel = W.Panel({
        width    = T.SIZE.BADGE_ICON,
        height   = T.SIZE.BADGE_ICON,
        getPos   = opts.getPos,
        setPos   = opts.setPos,
        isLocked = opts.isLocked,

        -- Le cadre ne se retaille pas, il change d'**échelle** : ce que le
        -- joueur règle est de quelle taille il voit la rangée, et les icônes
        -- grossissent avec elle. Le verrou range la poignée avec la position.
        minScale = T.SIZE.BADGE_SCALE_MIN,
        maxScale = T.SIZE.BADGE_SCALE_MAX,
        getScale = opts.getScale,
        setScale = opts.setScale,
    })

    -- **La poignée sort du cadre.** Il n'y a plus de marge où la loger, et la
    -- poser dans le coin la mettrait sur ce qui se clique : le geste de
    -- redimensionner disputerait ses pixels au geste que ce cadre existe pour
    -- offrir. Accrochée par son propre coin haut-gauche au coin bas-droit du
    -- panneau, elle pend dehors, ne recouvre rien, et disparaît avec le verrou
    -- comme avant.
    if panel.ResizeGrip then
        panel.ResizeGrip:ClearAllPoints()
        panel.ResizeGrip:SetPoint("TOPLEFT", panel, "BOTTOMRIGHT", 0, 0)
    end

    local buttons = {}

    for index = 1, #slots do
        local slot   = slots[index]
        local button = CreateFrame("Button", nil, panel)
        button:SetSize(T.SIZE.BADGE_ICON, T.SIZE.BADGE_ICON)
        button:Hide()

        local image = button:CreateTexture(nil, "ARTWORK")
        image:SetAllPoints(button)
        button.image = image

        -- **La surbrillance du client, et par-dessus l'icône.** La lueur
        -- centrale des boutons de la barre d'outils passe derrière, ce qui
        -- marche pour un marqueur de raid — troué — et pas du tout pour une
        -- icône de sort, qui est un carré plein : rien ne s'allumerait sous le
        -- curseur, et rien n'annoncerait que ça se clique.
        button:SetHighlightTexture(T.TEXTURE.ICON_HIGHLIGHT, "ADD")

        if slot.onClick then
            button:SetScript("OnClick", function() slot.onClick() end)
        end

        -- **C'est ici que l'explication vit.** Le cadre ne porte aucun texte :
        -- une case dit ce qui manque par son image, et le reste — son nom, ce
        -- que le clic fera — se lit au survol, comme partout ailleurs dans
        -- l'addon. Chaque case a son titre : elle ne montre jamais qu'une
        -- seule chose.
        if slot.title or slot.tip then
            W.Tooltip(button, slot.title, slot.tip)
        end

        buttons[index] = button
    end

    --- Repose les cases visibles côte à côte et remesure le cadre.
    ---@param visible table  indices des cases à montrer, dans l'ordre
    local function reflow(visible)
        local count = #visible
        local width = count * T.SIZE.BADGE_ICON + (count - 1) * T.SIZE.BADGE_GAP

        -- **Le cadre est la rangée, au pixel près** : aucune marge, ni pour
        -- respirer ni pour loger la poignée. Ce panneau ne porte pas de texte
        -- qu'un bord viendrait toucher — il porte des icônes, qui sont déjà
        -- des carrés finis, et l'habillage les cerne de lui-même en débordant
        -- vers l'extérieur (voir `W.PanelChrome`).
        panel:SetWidth(width)
        panel:SetHeight(T.SIZE.BADGE_ICON)

        -- Posées à partir du bord gauche de la rangée, qui est celui du cadre.
        local x = -width / 2

        for i = 1, count do
            local button = buttons[visible[i]]
            button:ClearAllPoints()
            button:SetPoint("LEFT", panel, "CENTER", x, 0)
            button:Show()
            x = x + T.SIZE.BADGE_ICON + T.SIZE.BADGE_GAP
        end
    end

    --- Les cases à montrer, du passage en cours. Une seule table, réemployée :
    --- elle est refaite à chaque relecture, et en créer une par passage ne
    --- servirait qu'à donner du travail au ramasse-miettes (règle 7).
    local showing = {}

    --- Ce qui a lieu de paraître, et ce qui reste rangé.
    ---@return table visible
    local function collect()
        wipe(showing)

        for index = 1, #slots do
            local slot   = slots[index]
            local button = buttons[index]
            local show   = slot.shown == nil or slot.shown() == true

            if show and paint(button.image, slot.icon and slot.icon()) then
                showing[#showing + 1] = index
            else
                button:Hide()
            end
        end

        return showing
    end

    --- Relit toutes les cases et repose le cadre. Rien à montrer, pas de
    --- cadre : un panneau vide est un panneau qui se déplace tout seul sous le
    --- curseur pour rien.
    ---
    --- C'est la seule voie de rafraîchissement, et c'est voulu : ce que ce
    --- cadre montre ne change qu'à l'annonce du client, jamais avec le temps.
    --- Poser une boucle pour relire une image qui ne bouge qu'au clic serait
    --- payer pour rien (règle 7).
    function panel:Refresh()
        local visible = collect()

        if #visible == 0 then
            self:Hide()
            return
        end

        reflow(visible)
        self:Show()
    end

    --- Range le cadre. Position et taille restent : rallumer ne redemande
    --- rien.
    function panel:Stop()
        self:Hide()
    end

    -- L'échelle rangée est reposée tout de suite, et la position avec elle :
    -- la seconde se convertit dans la première (voir `W.Panel:ApplyPosition`).
    panel:ApplyScale()
    panel:ApplyLock()

    panel:Hide()
    return panel
end
