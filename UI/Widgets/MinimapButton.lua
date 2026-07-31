-- =========================================================================
--  Bshamel UI — UI/Widgets/MinimapButton.lua
--  Bouton posé sur le pourtour de la minicarte.
--
--  Aucune bibliothèque : `LibDBIcon` fait exactement ce fichier, mais embarquer
--  une bibliothèque pour un seul bouton coûterait plus cher en surface qu'en
--  lignes économisées (et sa licence est à vérifier, voir CLAUDE.md règle 8).
--  Les proportions, elles, sont bien celles des boutons du client : c'est ce qui
--  fait qu'il se lit comme un bouton de minicarte et pas comme une pastille
--  d'addon posée dessus.
--
--  Le bouton ne connaît pas la base de données : il rend son angle à l'appelant
--  quand on le lâche, et le lit par la fonction qu'on lui donne. Un widget qui
--  écrirait un réglage serait un module déguisé.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local U    = BUI.Util
local W    = BUI.Widgets

---@class BUI.MinimapButtonOpts
---@field tooltipTitle string
---@field tooltipText? string|fun(): string
---@field onClick fun(mouseButton: string)
---@field getAngle fun(): number   angle en degrés, 0 = est, sens trigonométrique
---@field setAngle fun(angle: number)
---@field icon? string        chemin de texture ; le logo de l'addon par défaut
---@field squareIcon? boolean l'icône a des angles : on l'inscrit dans le trou

--- Rayon sur lequel se pose le bouton. Mesuré à chaque placement plutôt que
--- calculé une fois : la minicarte change de taille avec les réglages du client
--- et avec les autres addons.
---@return number
local function radius()
    return (Minimap:GetWidth() / 2) + T.SIZE.MINIMAP_PAD
end

---@param button table
---@param angle number
local function place(button, angle)
    local rad = math.rad(angle or 0)
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER",
        math.cos(rad) * radius(),
        math.sin(rad) * radius())
end

--- Angle, en degrés, du curseur vu depuis le centre de la minicarte.
---@return number|nil
local function angleUnderCursor()
    local cx, cy = Minimap:GetCenter()
    if not cx then return nil end

    local scale = Minimap:GetEffectiveScale()
    if not scale or scale == 0 then return nil end

    local px, py = GetCursorPosition()
    return math.deg(math.atan2((py / scale) - cy, (px / scale) - cx))
end

--- Bouton rond déplaçable autour de la minicarte.
--- Renvoie `nil` si le client n'expose pas de minicarte — l'appelant doit alors
--- se passer de bouton plutôt que d'échouer.
---@param opts BUI.MinimapButtonOpts
---@return table|nil
function W.MinimapButton(opts)
    if not Minimap then return nil end

    local button = CreateFrame("Button", nil, Minimap)
    button:SetSize(T.SIZE.MINIMAP_BUTTON, T.SIZE.MINIMAP_BUTTON)
    button:SetFrameStrata(Minimap:GetFrameStrata())
    button:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetMovable(true)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("CENTER", button, "CENTER", T.SIZE.MINIMAP_ICON_X, T.SIZE.MINIMAP_ICON_Y)
    icon:SetTexture(opts.icon or T.TEXTURE.MINIMAP_ICON)

    -- Le logo de l'addon porte son disque **dans sa texture** : posé à la taille
    -- du trou, il le remplit. Une icône d'objet ou de sort est carrée, et rien
    -- ne l'arrondit — d'où le masque circulaire, qui lui coupe les coins et lui
    -- permet de remplir le trou comme le logo. Sans lui, il faudrait la réduire
    -- au carré inscrit dans le cercle et elle flotterait au milieu de l'anneau.
    --
    -- Test de capacité et non pari : un client qui ne sait pas masquer retombe
    -- sur le carré inscrit, plus petit mais jamais débordant.
    -- Une icône d'objet ou de sort porte un **liseré sombre dans son image**.
    -- Agrandie pour remplir le trou, ce liseré devient un croissant noir sur le
    -- bord — très visible en bas, où l'illustration est déjà foncée. On rogne
    -- donc la même fraction que le mode sombre rogne avant de poser son contour.
    local masked = false
    if opts.squareIcon then
        local crop = T.SIZE.SHADE_ICON_CROP
        icon:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
    end

    if opts.squareIcon and button.CreateMaskTexture and icon.AddMaskTexture then
        local mask = button:CreateMaskTexture()
        mask:SetTexture(T.TEXTURE.CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetPoint("CENTER", icon, "CENTER")
        mask:SetSize(T.SIZE.MINIMAP_ICON, T.SIZE.MINIMAP_ICON)
        icon:AddMaskTexture(mask)
        masked = true
    end

    local side = (opts.squareIcon and not masked)
                 and T.SIZE.MINIMAP_ICON_SQUARE
                 or T.SIZE.MINIMAP_ICON
    icon:SetSize(side, side)

    -- La bordure se dessine **au-dessus** de l'icône : c'est elle qui découpe le
    -- rond. Une icône posée par-dessus déborderait de l'anneau.
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(T.SIZE.MINIMAP_BORDER, T.SIZE.MINIMAP_BORDER)
    border:SetPoint("TOPLEFT")
    border:SetTexture(T.TEXTURE.MINIMAP_BORDER)

    button:SetHighlightTexture(T.TEXTURE.MINIMAP_HIGHLIGHT)

    button.icon = icon

    -- Déplacement : on suit le curseur tant que le bouton est tenu, et on ne
    -- rend l'angle à l'appelant qu'au relâchement. Écrire le réglage à chaque
    -- image ferait un message de changement par image.
    local follow = U.Throttle(T.TIMING.DRAG, function()
        local angle = angleUnderCursor()
        if not angle then return end
        button._angle = angle
        place(button, angle)
    end)

    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", follow)
    end)

    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        if self._angle and opts.setAngle then opts.setAngle(self._angle) end
    end)

    button:SetScript("OnClick", function(_, mouseButton)
        if opts.onClick then opts.onClick(mouseButton) end
    end)

    W.Tooltip(button, opts.tooltipTitle, opts.tooltipText)

    --- Replace le bouton d'après l'angle enregistré. À rappeler quand le réglage
    --- change ou quand la minicarte a pu être redimensionnée.
    function button:Refresh()
        self._angle = (opts.getAngle and opts.getAngle()) or self._angle
        place(self, self._angle)
    end

    button:Refresh()
    return button
end
