-- =========================================================================
--  Bshamel UI — UI/Widgets/ShadeBorder.lua
--  Contour sombre autour d'une icône.
--
--  **On emprunte avant de créer.** Si le cadre porteur publie déjà un contour
--  (`Border`), c'est celui-là qu'on rhabille : même atlas, même teinte, même
--  ancrage. On ne le masque pas pour en poser un autre par-dessus, et on n'en
--  ajoute pas un second à côté. C'est la règle qui vaut déjà pour les barres
--  d'action, dont on teinte la texture existante — appliquée ici à un cadre qui
--  demande davantage qu'une teinte pour rejoindre l'apparence commune.
--
--  Une texture n'est créée que lorsqu'il n'y en a aucune à emprunter : les
--  icônes d'auras sont des carrés nus, il n'y a rien à rhabiller.
--
--  Réversibilité : d'une texture empruntée, on relève **tout** ce qu'on va
--  changer — image, coordonnées, ancrages, teinte, désaturation, opacité,
--  visibilité — et `Hide` le repose tel quel. D'une texture créée, `Hide` la
--  masque, ce qui suffit (CLAUDE.md règle 6).
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local W    = BUI.Widgets

--- Clés sous lesquelles un cadre du client publie son contour.
local BORDER_KEYS = { "Border", "IconBorder" }

--- Contour déjà présent sur ce cadre, s'il y en a un.
---@param owner table
---@return table|nil
local function borrowFrom(owner)
    for i = 1, #BORDER_KEYS do
        local region = owner[BORDER_KEYS[i]]
        if type(region) == "table" and type(region.SetAtlas) == "function"
           and type(region.GetObjectType) == "function" and region:GetObjectType() == "Texture" then
            return region
        end
    end
    return nil
end

--- Relève tout ce que `Draw` va modifier sur une texture empruntée.
---@param texture table
---@return table
local function snapshot(texture)
    local state = {
        atlas  = texture.GetAtlas and texture:GetAtlas() or nil,
        file   = texture:GetTexture(),
        alpha  = texture:GetAlpha(),
        shown  = texture:IsShown(),
        desat  = texture.IsDesaturated and texture:IsDesaturated() or false,
        points = {},
    }

    state.r, state.g, state.b, state.a = texture:GetVertexColor()
    state.coords = { texture:GetTexCoord() }

    for i = 1, texture:GetNumPoints() do
        state.points[i] = { texture:GetPoint(i) }
    end

    return state
end

---@param texture table
---@param state table
local function restore(texture, state)
    if state.atlas then
        texture:SetAtlas(state.atlas)
    else
        texture:SetTexture(state.file)
    end

    texture:SetTexCoord(unpack(state.coords))
    if texture.SetDesaturated then texture:SetDesaturated(state.desat) end
    texture:SetVertexColor(state.r, state.g, state.b, state.a)
    texture:SetAlpha(state.alpha)

    texture:ClearAllPoints()
    for i = 1, #state.points do
        texture:SetPoint(unpack(state.points[i]))
    end

    texture:SetShown(state.shown)
end

--- Contour sombre autour d'une icône.
--- Renvoie `nil` si l'icône n'a pas de porteur, ou si le client ne connaît pas
--- l'atlas — l'appelant doit alors se passer de contour.
---@param icon table
---@return table|nil
function W.ShadeBorder(icon)
    local owner = icon:GetParent()
    if not owner then return nil end

    local borrowed = borrowFrom(owner)
    local state    = borrowed and snapshot(borrowed) or nil

    -- Sous-calque négatif quand il faut créer : le contour se dessine dans le
    -- calque de recouvrement, mais **sous** ce que le client y met déjà
    -- (compteurs de charges, minuteurs, surbrillance). Un contour qui masquerait
    -- le temps restant d'une aura serait une régression déguisée en option
    -- d'apparence.
    local texture = borrowed or owner:CreateTexture(nil, "OVERLAY", nil, -1)

    local function reset()
        if state then restore(texture, state) else texture:Hide() end
    end

    if not T.TrySetAtlas(texture, T.ATLAS.SHADE_BORDER) then
        reset()
        return nil
    end

    local border = {}

    ---@param factor number  multiplicateur de couleur, voir `T.ShadeFactor`
    function border:Draw(factor)
        T.TrySetAtlas(texture, T.ATLAS.SHADE_BORDER)
        texture:SetTexCoord(0, 1, 0, 1)

        -- Désaturée avant d'être teintée : le trait de l'atlas est coloré, et le
        -- multiplier sans le désaturer donnerait un contour teinté foncé au lieu
        -- d'un contour sombre (même raison que pour l'habillage).
        if texture.SetDesaturated then texture:SetDesaturated(true) end
        texture:SetVertexColor(factor, factor, factor)
        texture:SetAlpha(1)

        -- Le contour est reposé sur l'icône dans les deux cas, mais pas au même
        -- écart, et la nuance est tout le sujet :
        --
        --   · une texture **empruntée** était taillée pour l'image du client,
        --     pas pour la nôtre. Sa géométrie d'origine appliquée à un autre
        --     dessin déborde, d'où un ancrage serré sur l'icône. Ses ancrages
        --     d'origine sont relevés et reposés à l'extinction ;
        --   · une texture **créée** n'a aucune géométrie. Son écart doit
        --     compenser la marge transparente que l'atlas porte autour de son
        --     trait, et se mesure donc sur l'icône.
        local pad = T.SIZE.SHADE_BORDER_PAD

        if not borrowed then
            local width  = icon:GetWidth()  or 0
            local height = icon:GetHeight() or 0
            pad = T.ShadeBorderPad(math.min(width, height))
        end

        texture:ClearAllPoints()
        texture:SetPoint("TOPLEFT", icon, "TOPLEFT", -pad, pad)
        texture:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", pad, -pad)
        texture:Show()
    end

    border.Hide = reset

    reset()
    return border
end
