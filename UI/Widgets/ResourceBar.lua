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

    -- ---------------------------------------------------------------------
    --  Effet brillant
    -- ---------------------------------------------------------------------
    -- **Deux couches, et deux matières.**
    --
    --   · un **fond** qui allume tout le contour et ne bouge pas : un cœur doré
    --     fin, flanqué de deux halos en dégradé qui s'éteignent en s'éloignant.
    --     Il est fait de couleur pure, la seule matière qui s'étire sans se
    --     dégrader — une image détaillée agrandie quatre fois devient floue et
    --     crénelée, et aucun réglage ne lui rend les pixels qu'elle n'a pas ;
    --   · huit **comètes** régulièrement espacées qui le parcourent par-dessus.
    --     Chacune est une bande arrondie à ses deux bouts, plus haute en tête
    --     qu'en queue — c'est cette forme, et non le déplacement seul, qui se lit
    --     comme une vitesse.
    --
    -- Une comète n'est pas dessinée d'un tenant : c'est une file de points ronds
    -- qui **se recouvrent**, décroissants en taille. On ne les distingue pas, on
    -- ne voit que leur enveloppe. C'est le seul moyen d'obtenir une forme fuselée
    -- qui suit un contour et tourne aux angles : une image, elle, serait à étirer
    -- et à faire pivoter, ce qui la ramènerait au flou dont on vient.
    --
    -- L'essai précédent faisait courir des traits de couleur unie, sans fond. Il
    -- restait anguleux pour une raison simple : un aplat **s'arrête net**. Ses
    -- deux bouts sont des cassures franches, et une cassure franche se lit comme
    -- un pixel, quelle que soit la douceur du fondu sur les côtés.
    --
    -- D'où la seconde matière. Le point est une image — mais une image qui n'est
    -- qu'un **fondu radial plein** : aucun trait, aucun contour, rien qui puisse
    -- se créneler, et de la lumière jusqu'en son centre. C'est exactement ce
    -- qu'une couleur unie ne sait pas faire, et exactement ce qui manquait. Les
    -- deux matières ne s'opposent donc pas : on prend de chacune ce qu'elle sait
    -- faire.
    --
    -- Les halos du client sont **creux** — leur lumière est sur le pourtour, leur
    -- centre transparent —, et réduits à la taille d'un point ils donnent un petit
    -- carré vide plutôt qu'une boule. C'est pourquoi ce n'est pas l'un d'eux qu'on
    -- prend (voir `T.TEXTURE.GLOW_SPARK`).
    --
    -- Le procédé — un fond continu, des points qui tournent — est celui des lueurs
    -- des addons ; on l'a relevé sur `LibCustomGlow-1.0` pour savoir *quelles
    -- pièces d'API et quels assets* le rendent possible, puis écrit le nôtre
    -- (CLAUDE.md règle 8).

    --- Nombre de comètes qui font le tour, régulièrement espacées, et la longueur
    --- de la traînée de chacune en nombre de points.
    ---
    --- Huit, et elles sont **petites** : à peine plus grosses que le trait
    --- qu'elles parcourent. C'est ce qui fait la différence entre une lumière qui
    --- court dans la bordure et des pastilles qui glissent à côté — quatre grosses
    --- attiraient l'œil sur elles, huit petites l'attirent sur le contour.
    --- Sept points de traînée derrière la tête, à un cinquième de point d'écart :
    --- ils se recouvrent quatre par quatre et se fondent en une forme continue.
    --- Moins nombreux ou plus espacés, on recompte les boules ; plus nombreux, la
    --- comète fait le tour à elle seule et il n'y a plus de mouvement à lire.
    local GLOW_SPARKS = 8
    local GLOW_TRAIL  = 7

    --- De combien de crans la lueur passe au-dessus de ce qu'elle borde. Huit,
    --- comme la bibliothèque de référence : assez pour dépasser tout ce qu'un
    --- cadre du client empile sur lui-même.
    local GLOW_LEVEL = 8

    --- Les quatre côtés, dans le sens des aiguilles depuis le coin haut-gauche.
    local GLOW_EDGES = 4

    --- Les deux halos d'un bord, par leur nom de champ.
    local GLOW_SIDES = { "out", "inward" }

    --- Par côté : l'axe du fondu, et de quel bout de cet axe chaque halo touche le
    --- cœur. « Dehors » n'est pas la même direction sur les quatre — le haut de la
    --- rangée déborde vers le haut, son bas vers le bas —, et l'axe vertical du
    --- moteur part du bas, ce qui inverse encore une fois sur deux.
    local GLOW_FADE = {
        [1] = { axis = "VERTICAL",   out = false, inward = true  },
        [2] = { axis = "HORIZONTAL", out = false, inward = true  },
        [3] = { axis = "VERTICAL",   out = true,  inward = false },
        [4] = { axis = "HORIZONTAL", out = true,  inward = false },
    }

    local glow = CreateFrame("Frame", nil, panel)
    glow:SetAllPoints()
    glow:SetFrameLevel((panel:GetFrameLevel() or 1) + GLOW_LEVEL)
    glow:Hide()

    -- ---------------------------------------------------------------------
    --  Le fond : quatre bords allumés
    -- ---------------------------------------------------------------------

    --- Un bord : son cœur, et les deux halos qui l'entourent.
    ---
    --- Les halos sont ancrés **au cœur** : poser le cœur les emporte, et il n'y a
    --- qu'un ancrage à refaire quand la rangée change de taille.
    ---@param edge number
    ---@return table
    local function newBand(edge)
        local fade = GLOW_FADE[edge]

        -- Le cœur au-dessus des halos : c'est lui le filament, ils ne sont que
        -- son rayonnement.
        local core = glow:CreateTexture(nil, "ARTWORK", nil, 1)
        core:SetTexture(T.TEXTURE.SOLID)
        core:SetVertexColor(T.COLOR.GLOW_CORE:GetRGB())
        core:SetAlpha(T.ALPHA.GLOW_CORE)

        local band = { core = core }

        for i = 1, #GLOW_SIDES do
            local side = GLOW_SIDES[i]
            local halo = glow:CreateTexture(nil, "ARTWORK", nil, 0)

            -- Sans dégradé, un aplat discret plutôt qu'une bande pleine : moins
            -- joli, jamais cassé.
            if not T.ApplyGradient(halo, T.COLOR.GLOW_HALO, T.ALPHA.GLOW_HALO,
                                   fade.axis, fade[side]) then
                halo:SetTexture(T.TEXTURE.SOLID)
                halo:SetVertexColor(T.COLOR.GLOW_HALO:GetRGB())
                halo:SetAlpha(T.ALPHA.GLOW_HALO)
            end

            band[side] = halo
        end

        -- Additif : le bord **ajoute** de la lumière à ce qu'il recouvre au lieu
        -- de le masquer. C'est ce qui distingue une lueur d'un liseré.
        core:SetBlendMode("ADD")
        band.out:SetBlendMode("ADD")
        band.inward:SetBlendMode("ADD")

        return band
    end

    local bands = {}
    for edge = 1, GLOW_EDGES do
        bands[edge] = newBand(edge)
    end

    -- ---------------------------------------------------------------------
    --  Les comètes qui font le tour, et les coins qu'elles arrondissent
    -- ---------------------------------------------------------------------

    --- Une boule de lumière, du même dessin partout : tête de comète, point de
    --- traînée, ou coin du bord fixe. Sa taille et son opacité sont posées par
    --- `sizeGlow`, qui seul connaît la rangée.
    ---@param layer string
    ---@return table
    local function newOrb(layer)
        local orb = glow:CreateTexture(nil, layer)
        orb:SetTexture(T.TEXTURE.GLOW_SPARK)

        local box = T.TEXCOORD.GLOW_SPARK
        orb:SetTexCoord(box[1], box[2], box[3], box[4])

        orb:SetVertexColor(T.COLOR.GLOW_HALO:GetRGB())
        orb:SetBlendMode("ADD")
        return orb
    end

    -- Une comète : une tête, puis sa traînée. Les points de traînée sont rangés
    -- derrière elle, de plus en plus petits et de plus en plus pâles — c'est
    -- cette double décroissance qui se lit comme une vitesse.
    local comets = {}
    for i = 1, GLOW_SPARKS do
        local dots = {}
        for k = 1, GLOW_TRAIL + 1 do
            dots[k] = newOrb("OVERLAY")
        end
        comets[i] = dots
    end

    -- Les quatre coins du bord fixe. Ils n'arrondissent pas l'angle — on ne peut
    -- pas —, ils le **noient** : une boule de lumière posée dessus, et l'œil ne
    -- lit plus un angle droit.
    local corners = {}
    for i = 1, GLOW_EDGES do
        corners[i] = newOrb("ARTWORK")
    end

    --- Mesures du contour, relevées par `sizeGlow`.
    local trackW, trackH, trackTh = 0, 0, 0

    --- Point du contour à l'avancement `t`, compté depuis le coin haut-gauche et
    --- dans le sens des aiguilles d'une montre.
    ---
    --- Un rectangle et non un cercle : c'est un rectangle que la lueur borde, et
    --- une trajectoire circulaire décollerait des grands côtés pour couper les
    --- petits.
    ---@param t number  avancement dans le tour, de 0 à 1
    ---@return number x, number y  décalage depuis le coin haut-gauche
    local function pointOnTrack(t)
        local run = t * 2 * (trackW + trackH)

        if run < trackW then return run, 0 end
        run = run - trackW

        if run < trackH then return trackW, -run end
        run = run - trackH

        if run < trackW then return trackW - run, -trackH end
        run = run - trackW

        return 0, -(trackH - run)
    end

    --- Écart entre deux points d'une traînée, en unités de contour. Posé par
    --- `sizeGlow` : il se mesure sur la tête, pas sur la rangée.
    local trailGap = 0

    --- Avance les comètes le long du contour.
    ---
    --- L'avancement se lit sur l'horloge et ne s'accumule pas d'un pas à l'autre :
    --- le tour dure ce qu'il doit durer quelle que soit la cadence réelle, et un
    --- pas sauté ne décale rien.
    local function runGlow()
        if trackW <= 0 or trackH <= 0 then return end

        local perimeter = 2 * (trackW + trackH)
        local lap       = T.TIMING.RESOURCE_GLOW_LAP
        local now       = (GetTime() % lap) / lap

        for i = 1, GLOW_SPARKS do
            -- Les comètes suivent le contour dans le sens où il est paramétré,
            -- c'est-à-dire celui des aiguilles d'une montre : de gauche à droite
            -- sur le bord du haut. Leur tête, la plus épaisse, est donc à droite.
            --
            -- **Pour tourner dans l'autre sens**, il faut inverser les deux lignes
            -- ensemble : `1 - (…)` pour la tête, et `+` au lieu de `-` pour la
            -- traînée. N'en inverser qu'une donne une comète qui recule, traînée
            -- devant.
            local head = ((now + (i - 1) / GLOW_SPARKS) % 1) * perimeter
            local dots = comets[i]

            for k = 1, #dots do
                -- Le premier rang est la tête ; les suivants traînent derrière
                -- elle, donc **à rebours** du contour puisqu'elle le descend. Le
                -- modulo referme le tour, ce qui suffit à traiter une comète à
                -- cheval sur le coin de départ.
                local at   = (head - (k - 1) * trailGap) % perimeter
                local x, y = pointOnTrack(at / perimeter)

                dots[k]:ClearAllPoints()
                dots[k]:SetPoint("CENTER", glow, "TOPLEFT", x, y)
            end
        end
    end

    --- Ancre les deux halos d'un bord autour de son cœur, et le cœur sur son côté.
    --- Les quatre côtés ne se factorisent pas : « dehors » n'est pas la même
    --- direction sur chacun, et deux d'entre eux se lisent à rebours de l'axe qui
    --- les porte.
    ---@param edge number
    ---@param bloom number
    local function anchorBand(edge, bloom)
        local band = bands[edge]
        local core, out, inward = band.core, band.out, band.inward
        local th = trackTh

        core:ClearAllPoints()
        out:ClearAllPoints()
        inward:ClearAllPoints()

        if edge == 1 then
            core:SetPoint("TOPLEFT",       glow, "TOPLEFT",     0, 0)
            core:SetPoint("BOTTOMRIGHT",   glow, "TOPRIGHT",    0, -th)
            out:SetPoint("BOTTOMLEFT",     core, "TOPLEFT")
            out:SetPoint("TOPRIGHT",       core, "TOPRIGHT",    0,  bloom)
            inward:SetPoint("TOPLEFT",     core, "BOTTOMLEFT")
            inward:SetPoint("BOTTOMRIGHT", core, "BOTTOMRIGHT", 0, -bloom)

        elseif edge == 2 then
            core:SetPoint("TOPLEFT",       glow, "TOPRIGHT",    -th, 0)
            core:SetPoint("BOTTOMRIGHT",   glow, "BOTTOMRIGHT",   0, 0)
            out:SetPoint("TOPLEFT",        core, "TOPRIGHT")
            out:SetPoint("BOTTOMRIGHT",    core, "BOTTOMRIGHT",  bloom, 0)
            inward:SetPoint("TOPRIGHT",    core, "TOPLEFT")
            inward:SetPoint("BOTTOMLEFT",  core, "BOTTOMLEFT",  -bloom, 0)

        elseif edge == 3 then
            core:SetPoint("TOPLEFT",       glow, "BOTTOMLEFT",  0, th)
            core:SetPoint("BOTTOMRIGHT",   glow, "BOTTOMRIGHT", 0, 0)
            out:SetPoint("TOPLEFT",        core, "BOTTOMLEFT")
            out:SetPoint("BOTTOMRIGHT",    core, "BOTTOMRIGHT", 0, -bloom)
            inward:SetPoint("BOTTOMLEFT",  core, "TOPLEFT")
            inward:SetPoint("TOPRIGHT",    core, "TOPRIGHT",    0,  bloom)

        else
            core:SetPoint("TOPLEFT",       glow, "TOPLEFT",      0, 0)
            core:SetPoint("BOTTOMRIGHT",   glow, "BOTTOMLEFT",  th, 0)
            out:SetPoint("TOPRIGHT",       core, "TOPLEFT")
            out:SetPoint("BOTTOMLEFT",     core, "BOTTOMLEFT",  -bloom, 0)
            inward:SetPoint("TOPLEFT",     core, "TOPRIGHT")
            inward:SetPoint("BOTTOMRIGHT", core, "BOTTOMRIGHT",  bloom, 0)
        end
    end

    --- Interpolation linéaire entre deux valeurs. `t` va de zéro — la tête — à un,
    --- le dernier point de la traînée.
    ---@param from number
    ---@param to number
    ---@param t number
    ---@return number
    local function lerp(from, to, t)
        return from + (to - from) * t
    end

    --- Repose toutes les mesures de la lueur.
    ---
    --- Tout s'y mesure sur l'épaisseur du **cœur du bord**, jamais sur la rangée :
    --- c'est ce qui garde la comète à peine plus grosse que le trait qu'elle
    --- parcourt, quelle que soit la taille des cases.
    ---@param width number
    ---@param height number
    local function sizeGlow(width, height)
        trackW, trackH = width, height
        trackTh        = T.ResourceGlowThickness(height)

        local bloom = trackTh * T.SIZE.RESOURCE_GLOW_BLOOM
        for edge = 1, GLOW_EDGES do
            anchorBand(edge, bloom)
        end

        local head = trackTh * T.SIZE.RESOURCE_GLOW_HEAD
        local tail = trackTh * T.SIZE.RESOURCE_GLOW_TAIL

        trailGap = head * T.SIZE.RESOURCE_GLOW_GAP

        for i = 1, GLOW_SPARKS do
            local dots = comets[i]

            for k = 1, #dots do
                -- **C'est la taille qui fait la forme, pas l'opacité.** Les points
                -- se recouvrent assez pour que leur somme soit à peu près uniforme
                -- d'un bout à l'autre : ce qu'on voit est donc leur enveloppe, une
                -- bande arrondie aux deux bouts qui va en s'amincissant. L'opacité
                -- ne fait que l'estomper vers la queue.
                local t    = (k - 1) / GLOW_TRAIL
                local side = lerp(head, tail, t)

                dots[k]:SetSize(side, side)
                dots[k]:SetAlpha(lerp(T.ALPHA.GLOW_SPARK, T.ALPHA.GLOW_TRAIL, t))
            end
        end

        -- Les coins, posés une fois : ils ne bougent pas avec le tour.
        local corner = trackTh * T.SIZE.RESOURCE_GLOW_CORNER
        local spots  = {
            { 0,      0       },
            { width,  0       },
            { width, -height  },
            { 0,     -height  },
        }

        for i = 1, GLOW_EDGES do
            corners[i]:SetSize(corner, corner)
            corners[i]:SetAlpha(T.ALPHA.GLOW_CORE)
            corners[i]:ClearAllPoints()
            corners[i]:SetPoint("CENTER", glow, "TOPLEFT", spots[i][1], spots[i][2])
        end

        runGlow()
    end

    -- Bridé (règle 7). Un cadre caché ne reçoit rien : la lueur éteinte ne coûte
    -- pas un appel. Seules les comètes bougent — le fond et ses coins sont posés
    -- une fois.
    local tick = U.Throttle(T.TIMING.RESOURCE_GLOW_STEP, runGlow)

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

        -- Les traits sont posés avant que le cadre se montre : sans cela, le
        -- premier pas les trouverait à l'endroit qu'ils occupaient la fois
        -- précédente, et la lueur apparaîtrait décalée.
        --
        -- Leur teinte, elle, ne suit pas la rangée : elle est **dorée**, comme
        -- tout ce que le jeu allume. Les cases disent où l'on en est, la lueur dit
        -- que c'est prêt — deux choses différentes, deux vocabulaires.
        if shine and not glow:IsShown() then runGlow() end

        glow:SetShown(shine)
        glow:SetScript("OnUpdate", (shine and tick) or nil)
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

        self:SetSize(rowW, cellH)

        -- Le contour que les traits parcourent est celui de la rangée. Leur cœur
        -- se pose **à l'intérieur** du bord ; ce sont leurs halos qui débordent
        -- des deux côtés, et c'est ce débordement qui fait la lueur.
        sizeGlow(rowW, cellH)

        for i = 1, T.SIZE.RESOURCE_MAX_CELLS do
            local cell = cells[i]
            local used = i <= shownCells

            if used then
                cell.edge:ClearAllPoints()
                cell.edge:SetPoint("TOPLEFT", self, "TOPLEFT", (i - 1) * stepX, 0)
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
