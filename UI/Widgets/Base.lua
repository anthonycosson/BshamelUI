-- =========================================================================
--  Bshamel UI — UI/Widgets/Base.lua
--  Fabrique de widgets : primitives partagées.
--
--  `UI/Widgets/` est le seul endroit du dépôt autorisé à appeler `CreateFrame`
--  (avec Core/Init.lua pour la frame d'événements). Tout le reste du code
--  déclare, ne dessine pas.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T   = BUI.Theme
local U   = BUI.Util
local L   = ns.L

local W = {}
BUI.Widgets = W

-- =========================================================================
--  Infobulle
-- =========================================================================

--- Attache une infobulle à une frame. `text` peut être une fonction, évaluée à
--- l'affichage — utile pour un texte qui dépend de l'état courant.
---@param frame table
---@param title string
---@param text? string|fun(): string
function W.Tooltip(frame, title, text)
    frame._tooltipTitle = title
    frame._tooltipText  = text

    if frame._tooltipHooked then return end
    frame._tooltipHooked = true

    frame:HookScript("OnEnter", function(self)
        if not self._tooltipTitle and not self._tooltipText then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self._tooltipTitle then
            GameTooltip_SetTitle(GameTooltip, self._tooltipTitle)
        end

        local body = self._tooltipText
        if type(body) == "function" then body = body() end
        if body then
            GameTooltip_AddNormalLine(GameTooltip, body, true)
        end

        if self._disabledReason then
            GameTooltip_AddErrorLine(GameTooltip, self._disabledReason, true)
        end
        GameTooltip:Show()
    end)

    frame:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

-- =========================================================================
--  Panneaux
-- =========================================================================

--- Frame nue, sans habillage. Sert de conteneur quand on a besoin d'une frame
--- pour des raisons structurelles (page, panneau d'options du client) et non
--- pour son apparence.
---@param parent? table
---@return table
function W.Container(parent)
    return CreateFrame("Frame", nil, parent)
end

--- Parent invisible, où l'on range un élément du client qu'un réglage éteint.
---
--- **Masquer ne suffit pas pour tout.** Le client montre et cache lui-même ses
--- éléments contextuels — la lueur de combat, l'effet de repos, l'icône de coin
--- — et certains portent une animation qui pilote leur opacité. Un `Hide` comme
--- un `SetAlpha(0)` y sont défaits au passage suivant, et on se retrouve à
--- courir après lui.
---
--- Rangé sous un parent masqué, l'élément ne se dessine plus quoi que le client
--- lui demande. Il n'y a ni hook à poser, ni moment à deviner, et rendre son
--- parent d'origine le remet exactement où il était.
---
--- Une seule frame pour tout le monde : elle n'affiche rien, elle ne sert qu'à
--- ne pas être dessinée.
---@return table
local hidden
function W.Hidden()
    if not hidden then
        hidden = CreateFrame("Frame", nil, UIParent)
        hidden:Hide()
    end
    return hidden
end

--- Bouton nommé et invisible, fait pour être cliqué **par une macro**
--- (`/click <nom>`) ou par un raccourci clavier.
---
--- C'est le seul chemin par lequel un addon peut poser quelque chose sur une
--- barre d'action : les emplacements n'acceptent que ce que le jeu y range —
--- sort, objet, macro, monture, tenue —, jamais un cadre d'addon. La macro, elle,
--- est un contenu que le jeu accepte, et elle clique ce bouton-ci.
---
--- Il exige un **nom global**, sans quoi la macro n'aurait rien à nommer : c'est
--- l'exception « noms de frames » de la règle 3, et le nom doit donc être
--- préfixé `BshamelUI`.
---@param globalName string
---@param onClick fun(mouseButton: string)
---@return table
function W.ClickTarget(globalName, onClick)
    local button = CreateFrame("Button", globalName, UIParent)

    -- Jamais montré : `Click()` n'a pas besoin de la souris, et un bouton
    -- invisible ne prend de place nulle part.
    button:Hide()
    button:SetScript("OnClick", function(_, mouseButton)
        onClick(mouseButton)
    end)

    return button
end

--- Ferme un panneau au premier clic posé **ailleurs**.
---
--- Le client annonce chaque appui de souris, où qu'il tombe
--- (`GLOBAL_MOUSE_DOWN`) : il suffit alors de demander au panneau s'il était
--- sous le curseur. C'est ce qui distingue cette approche du procédé habituel —
--- un cadre transparent posé sur tout l'écran pour intercepter les clics —, qui
--- **avale** le clic et oblige à cliquer deux fois pour agir ailleurs. Ici le
--- clic va où il allait, et la fenêtre se ferme en plus.
---
--- La veille n'est armée que pendant que le panneau est ouvert : fermé, il ne
--- coûte rien.
---
--- `isInside` couvre ce qui appartient au panneau sans être dedans : ses
--- sous-menus, et le bouton qui l'a ouvert — sans quoi un clic sur ce bouton
--- fermerait la fenêtre à l'appui puis la rouvrirait au relâchement.
---@param panel table
---@param close fun()
---@param isInside? fun(): boolean
function W.CloseOnOutsideClick(panel, close, isInside)
    local watcher = CreateFrame("Frame")

    watcher:SetScript("OnEvent", function()
        if panel:IsMouseOver() then return end
        if isInside and isInside() then return end
        close()
    end)

    panel:HookScript("OnShow", function()
        -- Sous `pcall` : un client qui ne connaît pas l'événement lèverait, et
        -- une fenêtre qui ne se ferme pas au clic vaut mieux qu'une erreur.
        pcall(watcher.RegisterEvent, watcher, "GLOBAL_MOUSE_DOWN")
    end)

    panel:HookScript("OnHide", function()
        watcher:UnregisterAllEvents()
    end)
end

--- Panneau creusé, comme les zones de contenu de l'interface Blizzard, mais
--- réduit à sa bordure : on lui retire son fond.
---
--- Il délimite sans teinter. Un fond de panneau, si pâle soit-il, s'ajoute à
--- celui de la fenêtre et rend la zone encadrée plus claire que le reste — deux
--- surfaces là où l'on n'en veut qu'une.
---@param parent table
---@return table
function W.Inset(parent)
    local template = T.Template("INSET")
    local inset = CreateFrame("Frame", nil, parent, template)
    T.ClearPanelBackground(inset)
    return inset
end

--- Redessine intégralement le contour d'un cadre monté sur un template de
--- fenêtre : huit pièces à nous, aucune du template.
---
--- **Tout reprendre plutôt que retoucher.** Trois tentatives ont échoué à
--- corriger le haut du contour du client sans toucher au reste, et pour la même
--- raison à chaque fois : ses pièces s'appuient les unes sur les autres. Changer
--- la taille d'un coin déplace le bord qui lui est accroché, décrocher un bord
--- lui fait perdre la largeur qu'il tenait de ses ancrages, et chaque correction
--- en appelle une autre. On ne sait pas ce dont on hérite.
---
--- Les pièces d'origine sont donc **toutes** masquées, et huit textures à nous
--- prennent leur place : quatre coins, quatre bords, chacun copié d'une pièce du
--- client et ancré par nous. Le haut est le bas retourné, les coins hauts sont
--- les coins bas retournés. Plus rien n'est hérité, donc plus rien ne surprend.
---@param border table
local function rebuildBorder(border)
    if border._rebuilt then return end

    local P = T.BORDER
    local botLeft  = T.BorderPiece(border, P.BOTTOM_LEFT)
    local botRight = T.BorderPiece(border, P.BOTTOM_RIGHT)
    local bottom   = T.BorderPiece(border, P.BOTTOM)
    local left     = T.BorderPiece(border, P.LEFT)
    local right    = T.BorderPiece(border, P.RIGHT)

    if not (botLeft and botRight and bottom and left and right) then return end

    -- **Rien tant que les pièces n'ont pas de dimensions.** On les relève sur
    -- elles, et elles valent zéro avant la première mise en page : construit trop
    -- tôt, le contour naîtrait plat.
    if bottom:GetHeight() <= 0 or left:GetWidth() <= 0 then return end

    border._rebuilt = true

    local cornerW, cornerH = botLeft:GetWidth(), botLeft:GetHeight()
    local rightW, rightH   = botRight:GetWidth(), botRight:GetHeight()
    local edgeH, edgeW     = bottom:GetHeight(), left:GetWidth()
    local layer, sublevel  = bottom:GetDrawLayer()

    ---@param source table
    ---@param flip boolean
    ---@return table
    local function newPiece(source, flip)
        local piece = border:CreateTexture(nil, layer, nil, sublevel)
        T.CopyTexture(piece, source, flip)
        return piece
    end

    --- Décalage de la pièce du client par rapport au bord du cadre.
    ---
    --- **Ces textures ne sont pas posées à ras.** Le métal du client déborde du
    --- cadre qu'il entoure — c'est ce qui lui donne son relief —, et chaque pièce
    --- porte donc un décalage négatif. Les poser à zéro, comme on le faisait, les
    --- rentre à l'intérieur : le contour se dessine alors en retrait, et le fond
    --- du panneau reste visible tout autour de lui.
    ---@param piece table
    ---@return number x, number y
    local function offsetOf(piece)
        local _, _, _, x, y = piece:GetPoint(1)
        return x or 0, y or 0
    end

    local cornerX,  cornerY  = offsetOf(botLeft)
    local rCornerX, rCornerY = offsetOf(botRight)
    local _,        bottomY  = offsetOf(bottom)
    local leftX              = offsetOf(left)
    local rightX             = offsetOf(right)

    -- **Les bords d'abord, les coins ensuite.** À calque égal, l'ordre de dessin
    -- est celui de la création. Or les bords sont plus épais que les coins — 16
    -- de large contre 14, relevé en jeu —, si bien qu'un bord dessiné après
    -- mange le raccord du coin qu'il touche. C'est l'incohérence qu'on voyait
    -- aux angles. Les coins par-dessus, le raccord est de nouveau à eux.
    --
    -- Les bords vont de bord à bord du cadre : ce sont les coins qui les
    -- recouvrent à leurs extrémités, comme le fait le client.
    -- Le décalage vertical change de signe en haut : ce qui débordait vers le bas
    -- doit déborder vers le haut.
    local bo = newPiece(bottom, false)
    bo:SetHeight(edgeH)
    bo:SetPoint("BOTTOMLEFT",  border, "BOTTOMLEFT",  0, bottomY)
    bo:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", 0, bottomY)

    local to = newPiece(bottom, true)
    to:SetHeight(edgeH)
    to:SetPoint("TOPLEFT",  border, "TOPLEFT",  0, -bottomY)
    to:SetPoint("TOPRIGHT", border, "TOPRIGHT", 0, -bottomY)

    local le = newPiece(left, false)
    le:SetWidth(edgeW)
    le:SetPoint("TOPLEFT",    border, "TOPLEFT",    leftX, 0)
    le:SetPoint("BOTTOMLEFT", border, "BOTTOMLEFT", leftX, 0)

    local ri = newPiece(right, false)
    ri:SetWidth(right:GetWidth())
    ri:SetPoint("TOPRIGHT",    border, "TOPRIGHT",    rightX, 0)
    ri:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", rightX, 0)

    local bl = newPiece(botLeft,  false)
    bl:SetSize(cornerW, cornerH)
    bl:SetPoint("BOTTOMLEFT", border, "BOTTOMLEFT", cornerX, cornerY)

    local br = newPiece(botRight, false)
    br:SetSize(rightW, rightH)
    br:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", rCornerX, rCornerY)

    local tl = newPiece(botLeft,  true)
    tl:SetSize(cornerW, cornerH)
    tl:SetPoint("TOPLEFT", border, "TOPLEFT", cornerX, -cornerY)

    local tr = newPiece(botRight, true)
    tr:SetSize(rightW, rightH)
    tr:SetPoint("TOPRIGHT", border, "TOPRIGHT", rCornerX, -rCornerY)
end

--- Masque tout ce que le template pose lui-même : son remplissage et les huit
--- pièces de son contour.
---
--- **À chaque passage, pas une fois.** Un template du client repose et réaffiche
--- ses pièces quand son cadre change de taille ou réapparaît ; masquer une seule
--- fois laissait revenir le bandeau de titre, par-dessus notre contour, sans que
--- rien ne l'annonce.
---@param border table
local function hideTemplatePieces(border)
    T.HidePanelFill(border)

    if not border._rebuilt then return end
    for _, names in pairs(T.BORDER) do
        local piece = T.BorderPiece(border, names)
        if piece then piece:Hide() end
    end
end

--- Contour d'un panneau : **celui de la fenêtre d'options**, sans sa barre de
--- titre.
---
--- Le métal du client, celui qu'il pose autour de presque tous ses menus, et non
--- un contour qui lui ressemble : un liseré de dialogue a la même silhouette mais
--- ni la même matière ni la même épaisseur, et deux panneaux de la même famille
--- ne peuvent pas porter deux contours différents.
---
--- On monte le template de fenêtre pour ses textures, puis `rebuildBorder`
--- redessine le contour entier à partir d'elles — symétrique, donc sans barre de
--- titre ni logement de croix.
---
--- Repli sur le contour de dialogue si aucun template de fenêtre n'existe : moins
--- ressemblant, jamais cassé.
---@param parent table
---@return table
function W.PanelBorder(parent)
    local template = T.Template("WINDOW") or T.Template("PANEL_BORDER")
    local border = CreateFrame("Frame", nil, parent, template)

    -- Un contour ne prend pas les clics : sous le menu de téléportation, il
    -- avalerait ceux des rangées qu'il encadre.
    border:EnableMouse(false)

    local function dress()
        rebuildBorder(border)
        hideTemplatePieces(border)
    end

    dress()

    -- **Trois occasions, parce qu'aucune ne suffit seule.** La reconstruction a
    -- besoin que les pièces du template soient mesurées, ce qui n'arrive pas à la
    -- création ; le changement de taille l'apporte, mais un panneau qui naît déjà
    -- à sa taille définitive n'en émet pas ; et un panneau caché puis réaffiché
    -- voit son template reposer ses pièces. La trame suivante couvre le cas du
    -- milieu, celui qui laissait des panneaux entiers sans contour.
    border:HookScript("OnSizeChanged", dress)
    border:HookScript("OnShow", dress)
    C_Timer.After(0, dress)

    return border
end

--- Habillage d'un panneau flottant : le fond de la fenêtre d'options, et le
--- contour de panneau.
---
--- Deux pièces qui ne se séparent pas, d'où une seule fonction. Le fond est la
--- pierre du client teintée (`T.WindowStone`) et non un aplat : c'est ce qui fait
--- la différence entre le noir profond de la fenêtre d'options et le gris bleuté
--- que la même couleur donne posée telle quelle.
---
--- Les prendre séparément est ce qui avait produit trois habillages différents
--- pour trois panneaux qui se ressemblent : le menu de téléportation et le
--- tiroir posaient l'aplat, le panneau d'outils la pierre. La cohérence visuelle
--- doit tomber de la structure du code, pas d'une relecture (CLAUDE.md règle 2).
---@param frame table
---@return table border
function W.PanelChrome(frame)
    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    T.WindowStone(background)
    frame.background = background

    local border = W.PanelBorder(frame)
    border:SetAllPoints()
    return border
end

--- Bandeau lumineux fort au centre et éteint sur les deux bords.
---
--- Deux textures et non une : une texture ne porte qu'un dégradé à deux
--- extrémités, il en faut donc une par moitié, chacune pleine du côté du
--- centre. L'objet renvoyé les pilote ensemble — l'appelant n'a qu'un `SetAlpha`
--- à connaître, comme pour une texture ordinaire.
---
--- Sans `SetGradient`, on retombe sur un aplat : moins joli, jamais cassé.
---@param parent table
---@param color ColorMixin
---@param alpha number  opacité au centre
---@param vertical? boolean  estompe en haut et en bas plutôt qu'à gauche et à droite
---@return table
function W.CenterGlow(parent, color, alpha, vertical)
    local orientation = vertical and "VERTICAL" or "HORIZONTAL"

    -- La moitié « première » est celle du haut ou de la gauche. Chacune est
    -- pleine du côté du centre : pour un dégradé horizontal le centre est le
    -- maximum de la moitié gauche, pour un vertical c'est le minimum de la
    -- moitié haute (l'axe vertical part du bas).
    local left = parent:CreateTexture(nil, "BACKGROUND")
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMRIGHT", parent, vertical and "RIGHT" or "BOTTOM")

    local right = parent:CreateTexture(nil, "BACKGROUND")
    right:SetPoint("TOPLEFT", parent, vertical and "LEFT" or "TOP")
    right:SetPoint("BOTTOMRIGHT")

    local firstAtMax = not vertical

    if T.ApplyGradient(left, color, alpha, orientation, firstAtMax) then
        T.ApplyGradient(right, color, alpha, orientation, not firstAtMax)
    else
        left:SetColorTexture(color:GetRGB())
        left:SetAlpha(alpha)
        right:SetColorTexture(color:GetRGB())
        right:SetAlpha(alpha)
    end

    local glow = { left = left, right = right }

    --- Montre ou cache le bandeau.
    ---
    --- On **masque** les textures au lieu de leur poser un alpha nul, et ce
    --- n'est pas une préférence de style : une texture dégradée porte son
    --- opacité dans ses couleurs de sommet, et l'alpha d'objet vient s'empiler
    --- par-dessus. Faire dépendre l'invisibilité de cette combinaison, c'est
    --- accepter qu'un voile filtre en permanence si l'une des deux ne se
    --- comporte pas comme prévu. `Hide` ne laisse rien filtrer, jamais.
    ---@param shown boolean
    function glow:SetShown(shown)
        self.left:SetShown(shown)
        self.right:SetShown(shown)
    end

    glow:SetShown(false)
    return glow
end

--- Voile sombre aux quatre bords d'une frame, diffusé vers l'intérieur — le
--- même assombrissement des bords que le panneau Options du client.
---
--- Les textures vivent sur le calque `BORDER` de la frame : elles assombrissent
--- son fond sans toucher à ses frames enfants, qui se dessinent de toute façon
--- au-dessus. Le voile porte donc sur la fenêtre, jamais sur ce qu'elle contient.
---@param frame table
function W.EdgeShade(frame)
    local depth = T.SIZE.EDGE_SHADE

    local function strip(from, to, orientation, edgeAtMax)
        local tex = frame:CreateTexture(nil, "BORDER")
        if not T.ApplyShade(tex, orientation, edgeAtMax) then
            tex:Hide()
            return
        end
        tex:SetPoint(from)
        tex:SetPoint(to)
        if orientation == "VERTICAL" then
            tex:SetHeight(depth)
        else
            tex:SetWidth(depth)
        end
    end

    strip("TOPLEFT",  "TOPRIGHT",     "VERTICAL",   true)   -- max = haut
    strip("BOTTOMLEFT", "BOTTOMRIGHT", "VERTICAL",  false)  -- min = bas
    strip("TOPLEFT",  "BOTTOMLEFT",   "HORIZONTAL", false)  -- min = gauche
    strip("TOPRIGHT", "BOTTOMRIGHT",  "HORIZONTAL", true)   -- max = droite
end

--- Poignée de redimensionnement, posée dans le coin bas-droit.
---
--- Construite sans template : les templates de poignée du client ont changé de
--- nom plusieurs fois, une frame nue avec sa texture est plus stable.
---
--- `allow` existe pour les cadres qui portent des boutons **sécurisés** : le
--- client refuse d'en changer la taille en combat, et une poignée qui accepte
--- d'être tirée sans rien redimensionner est pire qu'une poignée inerte. On
--- refuse donc le geste au lieu de le laisser échouer en silence.
--- Le corps d'une poignée : sa vignette, son coin, sa réaction au survol. Ce que
--- le geste **fait** est décidé par les deux fabriques qui s'en servent.
---@param frame table
---@return table
local function newGrip(frame)
    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(T.SIZE.GRIP, T.SIZE.GRIP)
    grip:SetPoint("BOTTOMRIGHT", -T.SIZE.GRIP_INSET, T.SIZE.GRIP_INSET)
    grip:SetFrameLevel(frame:GetFrameLevel() + 10)

    local tex = grip:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints()
    tex:SetTexture(T.TEXTURE.RESIZE_GRIP)
    tex:SetAlpha(T.ALPHA.GRIP)

    grip:SetScript("OnEnter", function() tex:SetAlpha(T.ALPHA.GRIP_HOVER) end)
    grip:SetScript("OnLeave", function() tex:SetAlpha(T.ALPHA.GRIP) end)

    frame.ResizeGrip = grip
    return grip
end

---@class BUI.GripOpts
---@field side? string             coin ou bord tiré ; « BOTTOMRIGHT » par défaut
---@field allow? fun(): boolean    le geste est-il permis en ce moment ?
---@field onStop? fun()
---@param frame table
---@param opts? BUI.GripOpts
---@return table
function W.ResizeGrip(frame, opts)
    opts = opts or {}
    local side = opts.side or "BOTTOMRIGHT"

    local grip = newGrip(frame)

    grip:SetScript("OnMouseDown", function()
        if opts.allow and not opts.allow() then return end
        grip._sizing = true
        frame:StartSizing(side)
    end)

    grip:SetScript("OnMouseUp", function()
        if not grip._sizing then return end
        grip._sizing = false
        frame:StopMovingOrSizing()
        if opts.onStop then opts.onStop() end
    end)

    return grip
end

--- Poignée qui change l'**échelle** d'un cadre au lieu de sa taille.
---
--- Deux gestes différents, et le choix entre eux n'est pas cosmétique :
--- retailler un cadre laisse ses textes au corps où ils sont, agrandir son
--- échelle emporte tout — vignettes, libellés, bordure. Pour un panneau dont la
--- disposition est arrêtée et qu'on veut seulement voir de plus loin, c'est
--- l'échelle qu'on cherche.
---
--- C'est aussi ce qui le rend inoffensif au milieu de boutons **sécurisés** :
--- rien n'est mesuré ni réancré sur eux, seul leur parent change d'échelle.
---
--- La largeur intrinsèque du cadre ne bouge jamais : l'échelle visée est donc le
--- rapport entre la largeur qu'on veut voir et celle-là.
---@class BUI.ScaleGripOpts
---@field min number
---@field max number
---@field setScale fun(scale: number)
---@field onScale? fun()          appelé à chaque cran du geste, pas seulement à sa fin
---@field allow? fun(): boolean
---@param frame table
---@param opts BUI.ScaleGripOpts
---@return table
function W.ScaleGrip(frame, opts)
    local grip = newGrip(frame)
    local originX, originWidth
    local release

    local function track()
        -- Le relâchement ne revient pas toujours à la poignée : le curseur a pu
        -- sortir du cadre, ou la fenêtre perdre le focus pendant le geste. On ne
        -- s'en remet donc pas à `OnMouseUp` seul — on regarde le bouton.
        if not IsMouseButtonDown("LeftButton") then
            release()
            return
        end

        local width = frame:GetWidth()
        if not (originWidth and width and width > 0) then return end

        -- `GetCursorPosition` répond en pixels de l'écran, pas dans l'échelle de
        -- `UIParent` : on ramène l'écart dans la sienne avant de s'en servir,
        -- sans quoi la poignée irait deux fois trop vite chez qui a réglé
        -- l'échelle de l'interface.
        local dx = (GetCursorPosition() - originX) / UIParent:GetEffectiveScale()
        local scale = (originWidth + dx) / width

        if scale < opts.min then scale = opts.min end
        if scale > opts.max then scale = opts.max end
        frame:SetScale(scale)
        if opts.onScale then opts.onScale() end
    end

    local tick = U.Throttle(T.TIMING.SCALE_DRAG, track)

    release = function()
        if not originX then return end
        originX, originWidth = nil, nil
        grip:SetScript("OnUpdate", nil)
        opts.setScale(frame:GetScale())
    end

    grip:SetScript("OnMouseDown", function()
        if opts.allow and not opts.allow() then return end
        originX     = GetCursorPosition()
        originWidth = frame:GetWidth() * frame:GetScale()
        grip:SetScript("OnUpdate", tick)
    end)

    grip:SetScript("OnMouseUp", release)
    grip:SetScript("OnHide", release)

    return grip
end

--- Séparateur vertical entre deux zones.
---
--- Une barre fine texturée, estompée en haut et en bas : un trait qui court d'un
--- bord à l'autre couperait la fenêtre en deux, alors qu'on veut seulement
--- suggérer la limite. C'est le même vocabulaire que les bandeaux de la
--- navigation — fort au milieu, éteint aux extrémités.
---
--- La texture est celle de la pierre du client, désaturée, seulement estompée
--- par le dégradé : `T.FadeTexture` multiplie ce qui est dessiné au lieu de le
--- remplacer, le grain survit donc au fondu.
---
--- L'appelant l'ancre par le haut et par le bas ; la largeur vient du thème.
---@param parent table
---@return table
function W.VerticalDivider(parent)
    local bar = W.Container(parent)
    bar:SetWidth(T.SIZE.DIVIDER_W)

    local function half(from, fromRegion, to, toRegion, opaqueAtMax)
        local tex = bar:CreateTexture(nil, "ARTWORK")
        tex:SetPoint(from, bar, fromRegion)
        tex:SetPoint(to, bar, toRegion)
        tex:SetTexture(T.TEXTURE.SIDEBAR_BAND)
        tex:SetDesaturated(true)
        tex:SetVertTile(true)

        if not T.FadeTexture(tex, T.COLOR.LABEL, T.ALPHA.DIVIDER, "VERTICAL", opaqueAtMax) then
            tex:SetVertexColor(T.COLOR.LABEL:GetRGB())
            tex:SetAlpha(T.ALPHA.DIVIDER)
        end
    end

    half("TOPLEFT", "TOPLEFT", "BOTTOMRIGHT", "RIGHT", false)
    half("TOPLEFT", "LEFT", "BOTTOMRIGHT", "BOTTOMRIGHT", true)

    return bar
end

--- Filet de séparation horizontal.
--- Une texture et non une frame : un trait n'a ni enfant ni script. L'appelant
--- lui donne ses deux extrémités par ancrage, l'épaisseur vient du thème.
---@param parent table
---@param color ColorMixin
---@param alpha number
---@return table
function W.Rule(parent, color, alpha)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetHeight(T.SIZE.RULE_H)
    line:SetColorTexture(color:GetRGB())
    line:SetAlpha(alpha)
    return line
end

-- =========================================================================
--  État actif / inactif
-- =========================================================================

--- Allume ou éteint un contrôle, quel qu'il soit.
---
--- Les trois chemins ne sont pas une prudence de plus : `SetEnabled` est récent
--- et n'existe pas sur tous les types de contrôle, `Enable`/`Disable` sont
--- l'ancienne paire, et un contrôle qui n'a ni l'un ni l'autre se contente de
--- l'opacité. C'est la seule chose que toutes les lignes de l'addon partagent
--- vraiment, d'où une fonction plutôt qu'un bloc recopié.
---@param control table
---@param enabled boolean
function W.SetControlEnabled(control, enabled)
    if control.SetEnabled then
        control:SetEnabled(enabled)
    elseif enabled and control.Enable then
        control:Enable()
    elseif control.Disable then
        control:Disable()
    end
    control:SetAlpha(enabled and 1 or T.ALPHA.CONTROL_OFF)
end

--- Applique l'état actif à un widget produit par cette fabrique.
--- Un widget inactif reste visible et survolable : l'infobulle explique
--- pourquoi il est grisé, ce qui vaut mieux qu'un contrôle qui disparaît.
---
--- Une ligne peut porter **plus d'un** contrôle — la glissière a sa case de
--- saisie —, et rien ici ne sait lequel. Elle déclare alors `OnEnabled`, et dit
--- elle-même ce que devient le reste. Sans ce crochet, un second contrôle
--- resterait vivant sous une ligne grisée : un réglage qu'on nous dit
--- indisponible et qui se règle quand même.
---@param widget table
---@param enabled boolean
---@param reason? string
function W.SetEnabled(widget, enabled, reason)
    widget._disabledReason = (not enabled) and reason or nil

    if widget.label then
        T.SetTextEnabled(widget.label, enabled)
    end

    if widget.OnEnabled then widget:OnEnabled(enabled) end

    if widget.control then
        W.SetControlEnabled(widget.control, enabled)
    end
end

-- =========================================================================
--  Ligne d'option
-- =========================================================================

--- Répartit le libellé et le contrôle d'après la largeur **courante** de la
--- ligne.
---
--- `CONTROL_X` est la position de référence, et c'est elle qui aligne les
--- contrôles d'une page à l'autre. Elle cède dans les deux sens, et pour deux
--- raisons opposées :
---
---   · vers la **gauche**, quand la ligne est étroite — une page en deux colonnes
---     en fait des moitiés —, sans quoi une abscisse fixe pousserait les
---     glissières hors du cadre ;
---   · vers la **droite**, quand un libellé ne tient pas dans cette place-là. La
---     mise en page relève alors le plus long de la colonne et le passe ici par
---     `_controlX` (voir `PageBuilder`). Un intitulé coupé ne se lit pas, et ces
---     lignes ont une hauteur fixe : le retour à la ligne n'est pas une option.
---
--- Le rétrécissement a le dernier mot : la largeur disponible n'est pas
--- négociable, le confort de lecture si.
---
--- Appelée à la construction, puis par la mise en page chaque fois que la largeur
--- change. Définie une fois et partagée par toutes les lignes : une fermeture par
--- ligne serait une fermeture par réglage de l'addon.
---@param row table
local function arrangeRow(row)
    local S = T.SIZE
    local width = row:GetWidth() or 0

    local x = row._controlX or S.CONTROL_X
    if x < S.CONTROL_X then x = S.CONTROL_X end

    if width > 0 then
        local latest = width - S.CONTROL_RESERVE
        if latest < x then
            x = (latest > S.LABEL_MIN_W) and latest or S.LABEL_MIN_W
        end
    end

    -- Une sous-option part de plus loin : sa largeur disponible est amputée
    -- d'autant, sans quoi son libellé déborderait sous le contrôle.
    row.label:SetWidth(math.max(1, x - row._labelX - S.LABEL_INDENT))

    if row.control then
        row.control:ClearAllPoints()
        row.control:SetPoint("LEFT", row, "LEFT", x, 0)
    end
end

--- Conteneur d'une ligne : un libellé à gauche, un contrôle à `CONTROL_X`.
--- Toutes les lignes de toutes les pages passent par ici, c'est ce qui garantit
--- que les contrôles restent alignés en colonne d'une page à l'autre.
--- `indented` marque une **sous-option** : une ligne qui ne veut rien dire sans
--- celle du dessus — « Serviteurs » sous « Unités ennemies ». Elle part de plus
--- à droite et s'écrit un cran plus petit ; c'est la conjonction des deux qui se
--- lit comme une subordination, un décalage seul se lisant comme un défaut
--- d'alignement.
---@param parent table
---@param labelText string
---@param indented? boolean
---@return table row
function W.Row(parent, labelText, indented)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(T.SIZE.ROW_H)

    local labelX = T.SIZE.LABEL_INDENT
    if indented then labelX = labelX + T.SIZE.LABEL_SUB_INDENT end

    local label = row:CreateFontString(nil, "ARTWORK",
        indented and T.FONT.LABEL_SMALL or T.FONT.LABEL)
    label:SetPoint("LEFT", row, "LEFT", labelX, 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    label:SetText(labelText or "")

    row.label   = label
    row._labelX = labelX
    row.Arrange = arrangeRow
    row:Arrange()
    return row
end

--- Ancre un contrôle dans la colonne de droite d'une ligne.
---@param row table
---@param control table
function W.PlaceControl(row, control)
    row.control = control
    row:Arrange()
end

-- =========================================================================
--  Confirmation
-- =========================================================================

--- Boîte de confirmation modale, sur le modèle des dialogues du client.
---@param message string
---@param onAccept fun()
function W.Confirm(message, onAccept)
    local KEY = "BSHAMELUI_CONFIRM"
    StaticPopupDialogs[KEY] = {
        text         = message,
        button1      = L["Yes"],
        button2      = L["Cancel"],
        OnAccept     = onAccept,
        timeout      = 0,
        whileDead    = true,
        hideOnEscape = true,
        showAlert    = true,
        preferredIndex = 3, -- évite le bug de taint des index bas
    }
    StaticPopup_Show(KEY)
end
