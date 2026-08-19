-- =========================================================================
--  Bshamel UI — UI/Widgets/TrackGlow.lua
--  La lueur de l'addon : un contour allumé que des comètes parcourent.
--
--  C'est la seule lueur que Bshamel UI fabrique, et elle a un vocabulaire à
--  elle : elle veut dire « à partir d'ici, c'est prêt » sur la rangée de
--  ressource de classe, et « regarde, tout de suite » sur l'entrave posée sur le
--  soigneur. Deux phrases différentes, mais une seule lueur — c'est ce qui fait
--  qu'on la reconnaît comme étant de l'addon et pas du jeu.
--
--  Elle a vécu à l'intérieur de `UI/Widgets/ResourceBar.lua`, qui l'avait
--  inventée pour lui-même. Le module PvP en a voulu la même : elle est sortie
--  ici sans une ligne de changement, et la rangée de ressource s'en sert
--  désormais par le même chemin que lui.
--
--  **Deux couches, et deux matières** — le détail est dans le commentaire qui
--  suit, à l'endroit exact où chacune se construit.
--
--  Ce que l'appelant doit faire, et c'est tout : donner le contour à parcourir
--  (`SetTrack`), puis l'allumer ou l'éteindre (`SetRunning`). La lueur se pose
--  sur le cadre qu'on lui donne pour parent et le couvre entièrement ; c'est
--  donc la boîte de ce cadre qui décide de ce qu'elle borde.
--
--  **Ses mesures s'appellent encore `RESOURCE_GLOW_…` dans le thème.** C'est là
--  qu'elles sont nées, elles n'ont pas changé d'un pixel en déménageant, et les
--  renommer ferait un commit de trente lignes qui ne change rien à l'écran.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local U    = BUI.Util
local W    = BUI.Widgets

--- Lueur posée sur un cadre, éteinte au départ.
---
--- `opts.outset` sort le contour du cadre porteur, en pixels — zéro par défaut,
--- le trait suit alors le bord même. `opts.thickness` fixe l'épaisseur du trait
--- au lieu de la déduire de la hauteur, et emporte avec elle la taille des
--- comètes et des halos.
---@param parent table
---@param opts? table  `{ outset = number, thickness = number }`
---@return table  le cadre de la lueur, augmenté de `SetTrack` et `SetRunning`
function W.TrackGlow(parent, opts)
    opts = opts or {}

    --- De combien de pixels le contour sort du cadre porteur. Voir la note sur
    --- l'ancrage, plus bas.
    local outset = opts.outset or 0

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

    -- Le contour est celui du cadre porteur, **débordé** de ce que l'appelant
    -- demande. Zéro — le cas de la rangée de ressource — pose le trait sur le
    -- bord même ; quelques pixels le sortent, ce qu'il faut autour d'une icône,
    -- dont le dessin va jusqu'au bord et que le trait recouvrirait sinon.
    local glow = CreateFrame("Frame", nil, parent)
    glow:SetPoint("TOPLEFT",     parent, "TOPLEFT",     -outset,  outset)
    glow:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT",  outset, -outset)
    glow:SetFrameLevel((parent:GetFrameLevel() or 1) + GLOW_LEVEL)
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

        -- L'épaisseur commande **tout le reste** : le débordement des halos, la
        -- taille des comètes et celle des coins s'en déduisent. Un appelant qui
        -- la fixe obtient donc une lueur entièrement plus fine, pas un trait fin
        -- parcouru de grosses boules.
        trackTh = opts.thickness or T.ResourceGlowThickness(height)

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

    --- Le contour à parcourir : la taille du **cadre porteur**, en pixels. À
    --- reposer chaque fois qu'elle change — rien ici ne mesure tout seul.
    ---
    --- Le débordement s'ajoute ici, une fois, plutôt qu'à chaque appel : c'est
    --- une propriété de la lueur, pas une chose que l'appelant ait à recalculer.
    ---@param width number
    ---@param height number
    function glow:SetTrack(width, height)
        sizeGlow(width + 2 * outset, height + 2 * outset)
    end

    --- Allume ou éteint la lueur.
    ---
    --- Les traits sont posés **avant** que le cadre se montre : sans cela, le
    --- premier pas les trouverait à l'endroit qu'ils occupaient la fois
    --- précédente, et la lueur apparaîtrait décalée.
    ---@param on boolean
    function glow:SetRunning(on)
        on = on and true or false

        if on and not self:IsShown() then runGlow() end

        self:SetShown(on)
        self:SetScript("OnUpdate", on and tick or nil)
    end

    return glow
end
