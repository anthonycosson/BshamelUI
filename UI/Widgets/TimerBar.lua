-- =========================================================================
--  Bshamel UI — UI/Widgets/TimerBar.lua
--  Un temps restant, posé sur son propre panneau.
--
--  Même socle que la barre d'outils de groupe (`W.Panel`, voir
--  `UI/Widgets/MarkerBar.lua`) : un cadre, un fond, une position que le
--  joueur pose une fois pour toutes. Rien dedans qu'un nombre.
--
--  **Un seul cadre pour les deux suivis de `Modules/Timers.lua`.** Le vol et
--  le craft comptent deux choses qui n'ont rien à voir ; ils les montrent de
--  la même façon, et c'est ce widget qui le garantit. Deux cadres écrits
--  séparément auraient divergé au premier réglage (CLAUDE.md règle 2).
--
--  Le widget ne sait pas d'où vient le temps qu'il affiche : on lui donne une
--  fonction qui rend les secondes restantes, il l'interroge et l'écrit. Quand
--  elle rend `nil`, le cadre se cache.
--
--  **Un temps s'écrit d'une seule façon**, qu'il vienne d'une mesure ou d'une
--  estimation. Le vol a porté un `~` devant les secondes estimées, et il est
--  retiré : la nuance intéressait l'auteur, pas le joueur, qui lit un temps
--  restant et n'a rien à faire de sa provenance. Elle reste écrite là où elle
--  a des conséquences — l'infobulle du réglage.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local U    = BUI.Util
local W    = BUI.Widgets

--- La place que la poignée d'échelle occupe dans le coin bas-droit : son côté,
--- plus le retrait qui l'écarte du bord (voir `W.ScaleGrip`).
---
--- Le contenu s'arrête avant elle au lieu de passer dessous. C'est le même
--- parti pris que la rangée de boutons de la barre de marqueurs, et il se
--- justifie de la même façon : sans ce recul, le dernier chiffre du décompte
--- et la poignée se disputeraient les mêmes pixels, et le geste de
--- redimensionner tomberait sur un nombre.
local GRIP_GUTTER = T.SIZE.GRIP + T.SIZE.GRIP_INSET

--- Panneau de temps restant, masqué au départ.
---@param opts table  { title, getPos, setPos, isLocked, getScale, setScale,
---                     source: fun(): number|nil remaining }
---@return table
function W.TimerBar(opts)
    -- Taille provisoire : le panneau se mesure sur ses propres textes une fois
    -- posés, comme la barre de marqueurs se mesure sur ses boutons.
    local panel = W.Panel({
        width    = T.SIZE.TOOL_PAD * 2,
        height   = T.SIZE.TOOL_PAD * 2,
        title    = opts.title,
        getPos   = opts.getPos,
        setPos   = opts.setPos,
        isLocked = opts.isLocked,

        -- Le cadre ne se retaille pas, il change d'**échelle** : la
        -- disposition est arrêtée ici, et ce que le joueur règle est de quelle
        -- taille il la voit. Le verrou range la poignée avec la position.
        minScale = T.SIZE.TIMER_SCALE_MIN,
        maxScale = T.SIZE.TIMER_SCALE_MAX,
        getScale = opts.getScale,
        setScale = opts.setScale,
    })

    -- Le libellé du socle est cadré à gauche sur toute la largeur du panneau :
    -- ici il coiffe un nombre, et les deux doivent partager le même axe. On le
    -- réancre donc par son seul bord haut — un cadre de texte ancré par
    -- `TOP` se centre de lui-même sur ce à quoi il s'accroche, et n'a plus
    -- d'autre largeur que celle de son texte.
    local title = panel.title
    if title then
        title:ClearAllPoints()
        title:SetPoint("TOP", panel, "TOP", 0, -T.SIZE.TOOL_PAD)
    end

    local timer = panel:CreateFontString(nil, "OVERLAY", T.FONT.TIMER)
    timer:SetTextColor(T.COLOR.NORMAL:GetRGB())
    panel.timer = timer

    -- Sous le libellé, et centré sur lui — s'ancrer par le haut du nombre au
    -- bas du titre aligne les deux axes sans avoir à les calculer.
    if title then
        timer:SetPoint("TOP", title, "BOTTOM", 0, -T.SIZE.ROW_GAP)
    else
        timer:SetPoint("TOP", panel, "TOP", 0, -T.SIZE.TOOL_PAD)
    end

    -- Mesuré sur le plus long texte que le widget écrive : une attente qui
    -- approche l'heure. Ni un vol ni un lot de craft n'y arrivent, mais la
    -- case doit tenir le pire cas sans se redessiner au premier chiffre perdu.
    timer:SetText("59:59")

    local contentW = timer:GetStringWidth()
    local contentH = timer:GetStringHeight()

    if title then
        local titleW = title:GetStringWidth()
        if titleW > contentW then contentW = titleW end
        contentH = contentH + title:GetStringHeight() + T.SIZE.ROW_GAP
    end

    -- **La gouttière est prise des deux côtés**, alors que la poignée n'occupe
    -- qu'un coin. C'est ce qui garde le contenu au milieu du cadre : ne la
    -- retirer qu'à droite décalait tout vers la gauche d'un demi-pouce, et le
    -- libellé se lisait comme mal centré — il l'était.
    panel:SetWidth(contentW + GRIP_GUTTER * 2)
    panel:SetHeight(contentH + T.SIZE.TOOL_PAD * 2)

    local function update()
        local remaining
        if opts.source then remaining = opts.source() end
        if not remaining then
            panel:Hide()
            return
        end

        panel:Show()
        timer:SetText(U.Clock(remaining))
    end

    -- Le temps affiché s'écrit à la seconde : le rafraîchir à chaque image
    -- serait payer soixante fois le même texte (règle 7).
    local tick = U.Throttle(T.TIMING.TRACKER, update)

    --- Branche le panneau sur sa source et l'allume.
    ---
    --- **À rappeler au moment où il y a quelque chose à montrer**, et pas
    --- seulement une fois pour toutes : un cadre caché ne reçoit plus
    --- d'`OnUpdate`, donc une source qui se remet à rendre un nombre ne
    --- réveillerait personne. C'est `Start` qui rouvre l'œil — les deux
    --- modules l'appellent depuis l'événement qui ouvre un vol ou un lot.
    --- Cet appel a l'air redondant ; il ne l'est pas.
    function panel:Start()
        self:SetScript("OnUpdate", tick)
        update()
    end

    --- Éteint le suivi. Position et taille restent : rallumer ne redemande
    --- rien.
    function panel:Stop()
        self:SetScript("OnUpdate", nil)
        self:Hide()
    end

    -- L'échelle rangée est reposée tout de suite, et la position avec elle :
    -- la seconde se convertit dans la première (voir `W.Panel:ApplyPosition`).
    panel:ApplyScale()
    panel:ApplyLock()

    panel:Hide()
    return panel
end
