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

--- Sommes-nous en train de poser l'anneau d'aura ? Le hook ci-dessous guette
--- l'écriture, donc il rappellerait la nôtre.
local settingRing = false

--- anneau emprunté -> sa fonction de repose. Clés faibles : le registre ne
--- retient aucun anneau en vie, il ne fait qu'aiguiller le hook ci-dessous.
local ringReposts = setmetatable({}, { __mode = "k" })

--- Guette **la fonction du client** qui écrit les anneaux d'auras, plutôt que
--- la méthode de chaque texture. Les deux hooks d'objet restent — ils couvrent
--- les écritures directes — mais `AuraUtil.SetAuraBorderAtlas` n'a pas de
--- corps Lua : si elle pose l'atlas côté client, la méthode de l'objet n'est
--- jamais appelée et un hook d'objet ne voit rien passer. La table `AuraUtil`,
--- elle, est à portée : un seul hook, posé au premier anneau emprunté, couvre
--- tous ses appels quel que soit leur chemin interne.
local function watchAuraUtil()
    if type(AuraUtil) ~= "table"
       or type(AuraUtil.SetAuraBorderAtlas) ~= "function" then
        return
    end

    U.GuardedHook(AuraUtil, "SetAuraBorderAtlas", function(region)
        local repost = ringReposts[region]
        if repost then repost() end
    end, nil)
end

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

    -- Le liseré d'aura (`DebuffBorder`), **quel que soit son atlas**. Le
    -- client en pose un sur chaque aura depuis qu'il les habille toutes ; on
    -- l'emprunte pour imposer l'anneau neutre assombri — à sa géométrie à
    -- lui, voir la première branche de `Draw`.
    --
    -- Y compris l'anneau **typé** d'un affaiblissement, et c'est un choix et
    -- non un oubli : on a livré le départage — l'anneau magie/poison gardait
    -- sa couleur, l'habillage neutre passait au sombre — et le mélange des
    -- deux régimes, plus les habillages spéciaux de certains buffs qui
    -- échappaient au critère, rendait la rangée brouillonne. Le joueur a
    -- tranché pour l'uniforme : un seul anneau, sombre, partout. Le type d'un
    -- affaiblissement reste lisible ailleurs — les cadres de groupe et le
    -- symbole daltonien le disent toujours.
    local ring = owner.DebuffBorder
    if type(ring) == "table" and type(ring.SetAtlas) == "function"
       and type(ring.GetObjectType) == "function"
       and ring:GetObjectType() == "Texture" then
        return ring
    end

    return nil
end

--- Relève tout ce que `Draw` va modifier sur une texture empruntée.
---
--- **Chaque lecture est gardée**, et c'est une leçon payée : les régions d'un
--- bouton d'aura de la cible descendent d'une unité que le client protège —
--- n'importe laquelle de ces valeurs peut être *secrète*, et une boucle
--- bornée par un nombre secret lève. Le relevé mourait, le widget avec, le
--- `pcall` de l'appelant avalait tout : les auras de la cible restaient sans
--- contour, sans un mot d'erreur. Ce qui ne se lit pas ne se relève pas — et
--- ne se reposera pas (voir `restore`) : on ne rend que ce qu'on a su
--- prendre, le client redessine le reste lui-même.
---@param texture table
---@return table
local function snapshot(texture)
    local state = { points = {} }

    local ok, a, b, c, d, e, f, g, h

    ok, a = pcall(texture.GetAtlas, texture)
    if ok and type(a) == "string" and not U.IsSecret(a) and a ~= "" then
        state.atlas = a
    end

    if not state.atlas then
        ok, a = pcall(texture.GetTexture, texture)
        if ok and not U.IsSecret(a) then state.file = a end
    end

    ok, a = pcall(texture.GetAlpha, texture)
    if ok and type(a) == "number" and not U.IsSecret(a) then state.alpha = a end

    ok, a = pcall(texture.IsShown, texture)
    if ok and not U.IsSecret(a) then state.shown = a and true or false end

    if texture.IsDesaturated then
        ok, a = pcall(texture.IsDesaturated, texture)
        if ok and not U.IsSecret(a) then state.desat = a and true or false end
    end

    if texture.IsIgnoringParentAlpha then
        ok, a = pcall(texture.IsIgnoringParentAlpha, texture)
        if ok and not U.IsSecret(a) then
            state.ignoreParentAlpha = a and true or false
        end
    end

    ok, a, b, c, d = pcall(texture.GetVertexColor, texture)
    if ok and type(a) == "number" and not U.IsSecret(a)
       and not U.IsSecret(b) and not U.IsSecret(c) and not U.IsSecret(d) then
        state.r, state.g, state.b, state.a = a, b or 1, c or 1, d or 1
    end

    ok, a, b, c, d, e, f, g, h = pcall(texture.GetTexCoord, texture)
    if ok and type(a) == "number" and not U.IsSecret(a) then
        state.coords = { a, b, c, d, e, f, g, h }
    end

    ok, a = pcall(texture.GetNumPoints, texture)
    if ok and type(a) == "number" and not U.IsSecret(a) then
        for i = 1, a do
            local okP, p1, p2, p3, p4, p5 = pcall(texture.GetPoint, texture, i)
            if okP and p1 ~= nil and not U.IsSecret(p1)
               and not U.IsSecret(p4) and not U.IsSecret(p5) then
                state.points[#state.points + 1] = { p1, p2, p3, p4, p5 }
            end
        end
    end

    return state
end

--- Ne repose que ce que le relevé a su lire — champ par champ, pour la raison
--- écrite sur `snapshot`. Les ancrages ne s'effacent que si on en a d'autres à
--- poser : un `ClearAllPoints` sans suite laisserait la texture sans place.
---@param texture table
---@param state table
local function restore(texture, state)
    if state.atlas then
        texture:SetAtlas(state.atlas)
    elseif state.file ~= nil then
        texture:SetTexture(state.file)
    end

    if state.coords then texture:SetTexCoord(unpack(state.coords)) end
    if texture.SetDesaturated and state.desat ~= nil then
        texture:SetDesaturated(state.desat)
    end
    if texture.SetIgnoreParentAlpha and state.ignoreParentAlpha ~= nil then
        texture:SetIgnoreParentAlpha(state.ignoreParentAlpha)
    end
    if state.r then
        texture:SetVertexColor(state.r, state.g, state.b, state.a)
    end
    if state.alpha then texture:SetAlpha(state.alpha) end

    if #state.points > 0 then
        texture:ClearAllPoints()
        for i = 1, #state.points do
            texture:SetPoint(unpack(state.points[i]))
        end
    end

    if state.shown ~= nil then texture:SetShown(state.shown) end
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

    -- Le liseré d'aura ne suit pas le régime commun : sa géométrie est celle
    -- du client, et on la garde (voir la première branche de `Draw`).
    local auraRing = borrowed ~= nil and borrowed == owner.DebuffBorder

    -- Sous-calque négatif quand il faut créer : le contour se dessine dans le
    -- calque de recouvrement, mais **sous** ce que le client y met déjà
    -- (compteurs de charges, minuteurs, surbrillance). Un contour qui masquerait
    -- le temps restant d'une aura serait une régression déguisée en option
    -- d'apparence.
    local texture = borrowed or owner:CreateTexture(nil, "OVERLAY", nil, -1)

    -- Protégé comme le relevé, et pour la même raison : une écriture peut
    -- être refusée, et un échec ici ne doit coûter que cette restitution.
    local function reset()
        if state then
            pcall(restore, texture, state)
        else
            pcall(texture.Hide, texture)
        end
    end

    if not T.TrySetAtlas(texture, T.ATLAS.SHADE_BORDER) then
        reset()
        return nil
    end

    local border = {}

    -- L'appelant rogne d'ordinaire le liseré que l'icône porte **dans son
    -- image**, parce que notre trait le remplace. Ici rien n'est remplacé :
    -- l'anneau du client est fait pour l'icône entière, la rogner décollerait
    -- l'image de son cadre.
    border.skipCrop = auraRing

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
    --- La teinte que le dernier `Draw` a demandée, pour que la repose rejoue
    --- le même trait. Le facteur, lui, se relit à la source à chaque repose
    --- (voir `repost`) : c'est lui qui dit si la repose a encore lieu d'être.
    local lastColor

    --- L'anneau d'aura, teinté **sans bouger** : ni ancrage, ni coordonnées —
    --- l'anneau du client est taillé au pixel pour la région qui le porte, et
    --- chaque tentative de le replacer sur l'icône a laissé des bords
    --- découverts, jamais les mêmes selon la vignette. On impose seulement
    --- l'image commune (l'anneau neutre, à la place des anneaux typés et des
    --- habillages spéciaux), la désaturation et la teinte.
    ---
    --- **La visibilité se décide ici, et elle est déterministe.** Le client
    --- de 12.1 cache l'anneau des buffs ordinaires : le laisser faire
    --- éteignait le mode sombre de toute la rangée, et le contrer au
    --- balayage suivant la faisait clignoter — chaque repeinture du client
    --- recachait, chaque passage à nous remontrait. L'anneau s'affiche donc
    --- partout — c'est l'uniforme voulu — avec une exception : le bouton qui
    --- porte déjà son liseré d'enchantement d'arme, où un second cadre
    --- serait un de trop. Et la réponse aux écritures de visibilité du
    --- client part dans le même souffle que les siennes (voir les hooks
    --- `Hide`/`Show` plus bas), jamais au battement suivant.
    --- L'anneau a-t-il sa place sur ce bouton ? Partout, sauf quand le
    --- liseré d'enchantement d'arme est affiché : il tient lieu de cadre.
    ---@return boolean
    local function ringWanted()
        local enchant = owner.TempEnchantBorder
        if type(enchant) == "table" and type(enchant.IsShown) == "function" then
            local ok, shown = pcall(enchant.IsShown, enchant)
            if ok and not U.IsSecret(shown) and shown then return false end
        end
        return true
    end

    ---@param factor number
    ---@param color? ColorMixin
    ---@return boolean
    local function drawRing(factor, color)
        if not T.TrySetAtlas(texture, T.ATLAS.AURA_RING) then return false end

        if texture.SetDesaturated then texture:SetDesaturated(true) end

        local r, g, b = 1, 1, 1
        if color then r, g, b = color:GetRGB() end
        texture:SetVertexColor(r * factor, g * factor, b * factor)
        texture:SetAlpha(1)

        -- **Le trait ignore l'alpha de son bouton.** Le client fait pulser
        -- l'alpha des boutons d'auras à moins de trente et une secondes — une
        -- animation de son moteur, synchronisée pour la rangée, qu'aucun hook
        -- ne voit. L'icône, claire, traverse ce battement sans gêner l'œil ;
        -- un trait sombre, lui, disparaît à chaque creux. L'information
        -- reste : l'icône continue de pulser, seul le cadre tient. Relevé et
        -- rendu comme le reste (voir `snapshot`).
        if texture.SetIgnoreParentAlpha then
            pcall(texture.SetIgnoreParentAlpha, texture, true)
        end

        texture:SetShown(ringWanted())
        return true
    end

    -- Le client réécrit son anneau à chaque rafraîchissement d'aura — lancer
    -- un sort suffit — et notre repose n'arrivait qu'au balayage suivant :
    -- l'anneau doré se voyait le temps d'un battement. On guette donc ses
    -- deux écritures et on repose dans le même souffle, comme les barres
    -- d'infos le font pour leur remplissage. Inerte tant qu'aucun `Draw`
    -- n'est en vigueur (`border.active`), donc aussi après `Hide`.
    if auraRing then
        -- **L'autorité de la repose est l'intensité en vigueur sur les
        -- auras, jamais la vie du widget.** Le client réécrit les anneaux de
        -- toute sa rangée à chaque sort lancé — boutons cachés de ses
        -- réservoirs compris, et surtout ceux que le dernier balayage n'avait
        -- pas re-marqués : une garde de cycle de vie les refusait, ils
        -- restaient dorés jusqu'au passage suivant, et la rangée clignotait à
        -- chaque sort. Tant que le mode sombre des auras est allumé, un
        -- anneau d'aura réécrit se repose, point. Éteint — et l'extinction
        -- retire l'intensité **avant** de rendre —, la repose se tait et le
        -- client reprend la main de lui-même.
        local function repost()
            if settingRing then return end

            local shade  = BUI.Shade
            local factor = shade and shade.FactorFor
                           and shade:FactorFor("auras") or nil
            if not factor or factor >= 1 then return end

            settingRing = true
            drawRing(factor, lastColor)
            settingRing = false
        end

        U.GuardedHook(texture, "SetAtlas",       repost, nil)
        U.GuardedHook(texture, "SetVertexColor", repost, nil)

        -- La visibilité aussi : c'est par `Hide` que le client éteint
        -- l'anneau d'un buff ordinaire, et par `Show` qu'il le rallume sur
        -- un bouton qui n'en veut pas chez nous. Les deux se corrigent dans
        -- le même souffle — la repose repasse par `SetShown(ringWanted())`.
        U.GuardedHook(texture, "Hide", repost, nil)
        U.GuardedHook(texture, "Show", repost, nil)

        ringReposts[texture] = repost
        watchAuraUtil()
    end

    function border:Draw(factor, color, side)
        lastColor = color

        if auraRing then
            settingRing = true
            local drawn = drawRing(factor, color)
            settingRing = false
            if drawn then return end
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

    -- La restauration passe par les écritures que la repose guette : elle ne
    -- se tait que parce que l'extinction retire l'intensité **avant** de
    -- rendre (voir `S:Restore`).
    border.Hide = reset

    reset()
    return border
end
