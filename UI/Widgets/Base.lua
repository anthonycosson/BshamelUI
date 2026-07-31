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

--- Applique l'état actif à un widget produit par cette fabrique.
--- Un widget inactif reste visible et survolable : l'infobulle explique
--- pourquoi il est grisé, ce qui vaut mieux qu'un contrôle qui disparaît.
---@param widget table
---@param enabled boolean
---@param reason? string
function W.SetEnabled(widget, enabled, reason)
    widget._disabledReason = (not enabled) and reason or nil

    if widget.label then
        T.SetTextEnabled(widget.label, enabled)
    end

    local control = widget.control
    if control then
        if control.SetEnabled then
            control:SetEnabled(enabled)
        elseif enabled and control.Enable then
            control:Enable()
        elseif control.Disable then
            control:Disable()
        end
        control:SetAlpha(enabled and 1 or T.ALPHA.CONTROL_OFF)
    end
end

-- =========================================================================
--  Ligne d'option
-- =========================================================================

--- Conteneur d'une ligne : un libellé à gauche, un contrôle à `CONTROL_X`.
--- Toutes les lignes de toutes les pages passent par ici, c'est ce qui garantit
--- que les contrôles restent alignés en colonne d'une page à l'autre.
---@param parent table
---@param labelText string
---@return table row
function W.Row(parent, labelText)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(T.SIZE.ROW_H)

    local label = row:CreateFontString(nil, "ARTWORK", T.FONT.LABEL)
    label:SetPoint("LEFT", row, "LEFT", T.SIZE.LABEL_INDENT, 0)
    label:SetJustifyH("LEFT")
    label:SetWidth(T.SIZE.CONTROL_X - T.SIZE.LABEL_INDENT * 2)
    label:SetWordWrap(false)
    label:SetText(labelText or "")

    row.label = label
    return row
end

--- Ancre un contrôle dans la colonne de droite d'une ligne.
---@param row table
---@param control table
function W.PlaceControl(row, control)
    control:ClearAllPoints()
    control:SetPoint("LEFT", row, "LEFT", T.SIZE.CONTROL_X, 0)
    row.control = control
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
