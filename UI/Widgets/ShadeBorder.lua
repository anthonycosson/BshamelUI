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
local U    = BUI.Util
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

    -- Le liseré d'aura (`DebuffBorder`), **seulement quand il n'est qu'un
    -- habillage**. Le client en pose un sur chaque aura depuis qu'il les
    -- habille toutes, et sa géométrie ne suit pas l'icône : dessiné par-dessus
    -- notre trait, il laissait des bords découverts. On le rhabille donc,
    -- comme tout contour emprunté — mais pas quand son atlas dit un **type**
    -- (magie, poison, maladie, malédiction…) : cet anneau-là est un signal,
    -- le remplacer l'éteindrait. Le vocabulaire est celui d'`AuraUtil` : les
    -- liserés typés portent leur type dans le nom d'atlas, le neutre porte
    -- « default ». Un atlas illisible vaut signal — un doute se tranche en
    -- n'empruntant pas.
    local ring = owner.DebuffBorder
    if type(ring) == "table" and type(ring.SetAtlas) == "function"
       and type(ring.GetAtlas) == "function"
       and type(ring.GetObjectType) == "function"
       and ring:GetObjectType() == "Texture" then
        local ok, atlas = pcall(ring.GetAtlas, ring)
        if ok and type(atlas) == "string" and not U.IsSecret(atlas)
           and atlas:find("default", 1, true) then
            return ring
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

--- `keepImage` rend tout **sauf** l'image et la visibilité : c'est le repli du
--- liseré d'aura, où le client vient d'écrire lui-même un atlas et un état
--- d'affichage plus frais que le relevé — les reposer effacerait ce qu'il
--- vient de dire.
---@param texture table
---@param state table
---@param keepImage? boolean
local function restore(texture, state, keepImage)
    if not keepImage then
        if state.atlas then
            texture:SetAtlas(state.atlas)
        else
            texture:SetTexture(state.file)
        end
    end

    texture:SetTexCoord(unpack(state.coords))
    if texture.SetDesaturated then texture:SetDesaturated(state.desat) end
    texture:SetVertexColor(state.r, state.g, state.b, state.a)
    texture:SetAlpha(state.alpha)

    texture:ClearAllPoints()
    for i = 1, #state.points do
        texture:SetPoint(unpack(state.points[i]))
    end

    if not keepImage then texture:SetShown(state.shown) end
end

--- Le plus petit côté d'une icône, ou `nil` quand il ne se lit pas.
---
--- **Une mesure est une valeur du client comme une autre**, et le client la rend
--- *secrète* dès que le cadre descend de quelque chose qu'il protège — une barre
--- de nom, typiquement. Un nombre secret n'est pas un nombre : `math.min` lève
--- dessus, et l'erreur remonte hors de l'appel fautif. C'est exactement ce qui
--- est arrivé le jour où la rangée d'auras des barres d'infos a demandé un
--- contour, alors que les deux appelants d'avant — le suivi de Bloodlust, sur
--- notre propre panneau, et le mode sombre, qui enveloppe son tracé d'un
--- `pcall` — ne pouvaient pas le rencontrer.
---
--- Sans mesure, l'appelant peut donner la sienne (voir `Draw`) ; à défaut, le
--- retrait fixe du thème, qui n'est jamais faux, seulement moins juste.
---@param icon table
---@return number|nil
local function smallestSide(icon)
    local okW, width  = pcall(icon.GetWidth, icon)
    local okH, height = pcall(icon.GetHeight, icon)
    if not (okW and okH) then return nil end
    if U.IsSecret(width) or U.IsSecret(height) then return nil end
    if type(width) ~= "number" or type(height) ~= "number" then return nil end

    return math.min(width, height)
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

    -- Le liseré d'aura change de rôle en cours de vie : le bouton qui porte un
    -- buff neutre aujourd'hui peut porter demain un affaiblissement typé, et
    -- le client réécrit alors l'atlas lui-même. `Draw` doit le savoir pour
    -- s'effacer devant lui (voir le repli en tête de `Draw`).
    local auraRing = borrowed ~= nil and borrowed == owner.DebuffBorder

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

    --- `color` sert là où le contour **dit** quelque chose en plus d'habiller.
    --- Une vignette de la rangée d'auras des barres d'infos est le seul cas
    --- rencontré : la nature de l'aura — entrave, débuff, buff — était portée par
    --- un liseré carré d'un pixel, que ce contour-ci remplace. Sans teinte, poser
    --- le contour aurait effacé l'information ; avec, elle passe dans le trait.
    ---
    --- Sans couleur, le blanc : la multiplication ne donne alors que le gris du
    --- facteur, ce qu'attendent le mode sombre et le suivi de Bloodlust.
    --- `side` est le côté de l'icône, quand l'appelant le connaît déjà — il vient
    --- alors d'un réglage, et non d'une mesure. C'est le cas de la rangée d'auras
    --- des barres d'infos, qui vient de poser cette taille elle-même : la donner
    --- évite une lecture que le client refuse sur une plaque (voir
    --- `smallestSide`), et garde le retrait proportionnel à l'icône — sur une
    --- vignette de cinquante pixels, le repli fixe donnerait un trait trop
    --- maigre.
    ---@param factor number  multiplicateur de couleur, voir `T.SHADE_FACTOR`
    ---@param color? ColorMixin  teinte du trait, blanc par défaut
    ---@param side? number  côté de l'icône, à défaut de pouvoir le mesurer
    function border:Draw(factor, color, side)
        -- Le repli du liseré d'aura : entre deux passages, le client a pu y
        -- écrire un atlas **typé** — un affaiblissement magique vient de se
        -- poser, et son anneau dit quelque chose. On lui rend alors sa
        -- géométrie et sa couleur relevées, sans toucher à l'image ni à la
        -- visibilité qu'il vient de poser, et on ne dessine pas par-dessus.
        -- Notre atlas à nous ne compte pas comme une reprise de parole : c'est
        -- la trace du passage précédent.
        if auraRing then
            local ok, atlas = pcall(texture.GetAtlas, texture)
            if ok and type(atlas) == "string" and not U.IsSecret(atlas)
               and atlas ~= T.ATLAS.SHADE_BORDER
               and not atlas:find("default", 1, true) then
                restore(texture, state, true)
                return
            end
        end

        T.TrySetAtlas(texture, T.ATLAS.SHADE_BORDER)
        texture:SetTexCoord(0, 1, 0, 1)

        -- Désaturée avant d'être teintée : le trait de l'atlas est coloré, et le
        -- multiplier sans le désaturer donnerait un contour teinté foncé au lieu
        -- d'un contour sombre (même raison que pour l'habillage).
        if texture.SetDesaturated then texture:SetDesaturated(true) end

        local r, g, b = 1, 1, 1
        if color then r, g, b = color:GetRGB() end
        texture:SetVertexColor(r * factor, g * factor, b * factor)
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
            -- Ce que l'appelant sait d'abord, la mesure ensuite, le repli du
            -- thème en dernier : `T.ShadeBorderPad` rend le retrait fixe pour
            -- une taille absente ou nulle.
            pad = T.ShadeBorderPad(side or smallestSide(icon))
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
