-- =========================================================================
--  Bshamel UI — Modules/Nameplates.lua
--  Les barres de nom du client : taille, opacité, couleurs, marqueur.
--
--  On ne construit pas de barre de nom. Le client les crée, les recycle et les
--  positionne ; ce module ne fait que trois choses sur ce qu'il a posé :
--
--    · **régler ce que le client sait déjà régler**, par ses propres CVars —
--      largeur, hauteur, pâleur des occultés. Ce sont ses boutons, pas les
--      nôtres : rien à repasser derrière lui, et les valeurs d'avant sont
--      rendues à l'extinction du module ;
--    · **repeindre** deux régions au moment exact où il les peint, par des
--      hooks gardés — la barre de vie et le nom. L'opacité de la cible et celle
--      des autres se posent là aussi : ce client-là n'a plus de CVar pour elles ;
--    · **déplacer** deux régions — le marqueur de ciblage, et le nom des joueurs
--      alliés.
--
--  Réversibilité (règle 6) : chaque CVar pris est relevé avant d'être écrit, et
--  tout le reste se rend en **rappelant les fonctions du client** plutôt qu'en
--  reposant ce qu'on avait relevé — les couleurs parce que lui seul sait ce
--  qu'il aurait dessiné, les ancrages parce qu'il nous interdit de les lire
--  (voir la section « Rendre un ancrage qu'on n'a pas le droit de lire »).
--
--  Tout est éteint par défaut. Allumer le module ne change donc rien à l'écran :
--  ce sont les interrupteurs de sa page qui décident, et chacun rend ce qu'il
--  avait pris quand on le rouvre.
--
--  Le fichier décrit les six sections ; **la table `LIVE` dit lesquelles sont
--  livrées**. Voir la section qui la porte pour pourquoi elles arrivent une par
--  une.
--
--  ## Ce que le client ne dit pas
--
--  Deux informations manquent à l'appel, et elles décident chacune d'une partie
--  du code :
--
--    · **l'occultation** — qu'un adversaire soit passé derrière un mur. Le
--      client le sait : il baisse l'opacité de la plaque, par le multiplicateur
--      `nameplateOccludedAlphaMult`. Mais il ne l'annonce par aucun événement et
--      ne l'expose par aucune fonction. On le **déduit** donc de l'opacité qu'il
--      a posée — voir `isOccluded`, qui explique pourquoi la déduction est sûre ;
--    · **caster ou mêlée** — aucune API ne le rend, et aucune base publique sous
--      une licence compatible n'existe (règle 8 : celles des autres addons sont
--      les leurs). On fabrique donc la nôtre en jouant : un PNJ devient un
--      caster la première fois qu'on le voit incanter, et la liste s'exporte et
--      s'importe en texte.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local U    = BUI.Util
local W    = BUI.Widgets
local L    = ns.L

local MODULE = "Nameplates"

--- Grise une ligne tant que l'interrupteur qui la commande est éteint.
---@param key string
---@return fun(): boolean
local function requires(key)
    return function()
        local mod = BUI.Modules:Get(MODULE)
        return not (mod and mod:Get(key))
    end
end

---@return table|nil
local function module()
    return BUI.Modules:Get(MODULE)
end

-- =========================================================================
--  Ce qui est livré, et ce qui attend son tour
-- =========================================================================
-- Le module a été écrit d'un bloc, puis mis à l'épreuve en jeu **section par
-- section**. Ce n'est pas une lubie de méthode : le client refuse à un addon une
-- partie de ce qu'on croit pouvoir faire sur une barre d'infos, et le refus ne se
-- découvre qu'en jouant. Six sections allumées d'un coup, c'est six causes
-- possibles pour le premier symptôme.
--
-- **Ce n'est pas un réglage de joueur.** C'est l'état d'avancement du module :
-- une section à `false` n'apparaît pas dans la page et ne pose rien — ni CVar,
-- ni couleur, ni ancrage. Ses réglages restent en base, intacts, et rallumer la
-- section les retrouve tels quels.
--
-- Ordre de validation retenu : la taille d'abord, parce qu'elle ne touche que
-- des CVars du client et ne dépend d'aucune plaque.
--- Deux d'entre elles ne sont pas seulement « pas encore validées » : `marker` et
--- `allies` déplacent une région, et **on ne sait pas rendre un déplacement** sur
--- une barre d'infos aujourd'hui. Voir la section « Rendre un ancrage qu'on n'a
--- pas le droit de lire » : les rallumer demande une idée, pas un test.
local LIVE = {
    -- Les réglages du jeu repris dans la page. Rien à valider : ils ne modifient
    -- aucune plaque, ils écrivent des CVars que le client relit lui-même.
    blizzard   = true,
    own        = true,

    size       = true,
    marker     = false,

    -- L'opacité et l'assombrissement, validés puis endormis : la page s'est
    -- resserrée sur la liste voulue, et ils n'y sont plus. Rallumer est un
    -- booléen — rien n'a été défait.
    visibility = false,
    colors     = true,
    threat     = true,
    auras      = true,    -- les trois rangées de l'addon — en pause, voir AURAS_PAUSED
    overlap    = true,    -- le chevauchement des plaques entre elles

    -- La distance, endormie quand la page s'est resserrée sur la liste voulue.
    -- Le code reste : rallumer est un booléen.
    spacing    = false,

    -- L'aperçu n'est pas une section de réglages : c'est la maquette du client,
    -- montrée telle quelle. Elle ne touche à aucune plaque et n'a donc rien à
    -- valider avant d'être livrée.
    preview    = true,
}

--- Les rangées d'auras sont **en pause** : visibles, grisées, inertes. Ce n'est
--- ni un `LIVE` à `false` — la section disparaîtrait, et une fonctionnalité qui
--- disparaît a l'air abandonnée — ni un réglage : le joueur n'a pas à pouvoir
--- rallumer ce qui ne marche pas encore comme il l'a demandé. La taille et les
--- décalages ne suivent pas encore le curseur avec assez de fidélité ; tant que
--- ce n'est pas réglé, la section l'annonce au lieu de le faire découvrir.
local AURAS_PAUSED = true

local function aurasPaused()
    return AURAS_PAUSED
end

--- Une section a-t-elle besoin des plaques elles-mêmes ?
---
--- La taille en a besoin pour sa **hauteur** seulement : elle se pose sur la
--- barre de vie de chaque plaque, et le client la repose à chaque plaque montée.
--- Sa largeur, elle, est un appel unique qui ne touche aucune frame.
---@return boolean
local function needsPlates()
    return LIVE.size or LIVE.marker or LIVE.visibility
        or LIVE.colors or LIVE.threat or LIVE.auras
end

--- Ne garde de la liste d'options que les sections livrées.
---
--- Une ligne `{ section = "..." }` n'est pas un contrôle : elle dit à quelle
--- section appartient tout ce qui la suit, jusqu'à la prochaine. C'est ce qui
--- permet de livrer la page section par section sans annoter chaque descripteur,
--- et de rallumer une section en basculant un seul booléen.
---@param all table[]
---@return table[]
--- Une entrée **sans `type`** est une liste de descripteurs, insérée telle
--- quelle. C'est ce qui permet à une fonction de rendre plusieurs lignes d'un
--- coup — une par membre d'une énumération du client, par exemple — sans que la
--- liste d'options cesse d'être un simple tableau qu'on lit de haut en bas.
local function liveOptions(all)
    local out, current = {}, nil

    local function keep(descriptor)
        if descriptor.type == nil and #descriptor > 0 then
            for i = 1, #descriptor do keep(descriptor[i]) end
            return
        end
        out[#out + 1] = descriptor
    end

    for i = 1, #all do
        local descriptor = all[i]
        if descriptor.section then
            current = descriptor.section
        elseif current == nil or LIVE[current] then
            keep(descriptor)
        end
    end

    return out
end

-- =========================================================================
--  Les plaques présentes à l'écran
-- =========================================================================
-- Le client annonce chaque plaque qui apparaît et chaque plaque qui part. On
-- tient donc la liste sans jamais la chercher : il n'y a rien à parcourir, rien
-- à sonder, et une plaque retirée sort de la table dans le même souffle.

--- jeton d'unité (`nameplate3`) -> cadre de la plaque
local plates = {}

--- plaque -> état peint au dernier passage (`"target"`, `"other"`, `"occluded"`)
local paintedState = {}

--- Le client peut déclarer un cadre **interdit** : rien de ce qu'on lui ferait ne
--- prendrait, et l'essayer lève. C'est le cas des plaques d'une arène, dont il
--- protège l'identité. On les écarte à l'entrée plutôt que de garder un `pcall`
--- au fond de chaque écriture.
---@param frame table
---@return boolean
local function isForbidden(frame)
    if type(frame.IsForbidden) ~= "function" then return false end
    local ok, forbidden = pcall(frame.IsForbidden, frame)
    return not ok or forbidden == true
end

---@param plate table|nil
---@return table|nil
local function unitFrameOf(plate)
    local frame = plate and plate.UnitFrame
    if type(frame) ~= "table" then return nil end
    if isForbidden(frame) then return nil end
    return frame
end

--- Repart des plaques **déjà à l'écran**.
---
--- Écouter les annonces suffit une fois qu'on écoute ; il faut encore rattraper
--- ce qui était là avant. C'est le cas à l'activation du module — on ne rallume
--- pas une page en zone vide — et au chargement d'une zone, où le client refait
--- ses plaques sans réannoncer celles qui restent.
---
--- La plaque personnelle est écartée, comme elle l'est à l'annonce : c'est celle
--- du joueur, posée à ses pieds, et elle n'a ni cible, ni menace, ni classement
--- de créature à montrer.
local function collectPlates()
    wipe(plates)
    if not (C_NamePlate and C_NamePlate.GetNamePlates) then return end

    local list = C_NamePlate.GetNamePlates()
    if type(list) ~= "table" then return end

    for i = 1, #list do
        local plate = list[i]
        local unit  = type(plate) == "table" and plate.namePlateUnitToken or nil
        if type(unit) == "string" and not U.IsTrue(UnitIsUnit(unit, "player")) then
            plates[unit] = plate
        end
    end
end

-- =========================================================================
--  Réglages du client dont le module prend la main
-- =========================================================================
-- Un CVar pris est relevé **avant** la première écriture, et rendu tel quel à
-- l'extinction. C'est le même contrat que l'échelle des cadres de groupe ou que
-- l'affichage des erreurs Lua : on emprunte, on ne s'approprie pas.

local CVAR = {
    -- **Il n'y a plus de CVar de taille.** `NamePlateHorizontalScale` et
    -- `NamePlateVerticalScale` sont toujours acceptés en écriture — le client ne
    -- proteste pas — mais ils ne changent plus rien à l'écran sur ce client-ci.
    -- La taille se pose désormais à la main : la hauteur sur la barre de vie de
    -- chaque plaque, la largeur sur la boîte de toutes les plaques d'un coup
    -- (voir la section « Taille »).

    -- **Le seul CVar d'opacité de ce client**, et il ne vaut que pour
    -- l'occultation. Les clients classic ont `nameplateSelectedAlpha` et
    -- `nameplateNotSelectedAlpha` ; le client actuel ne les a pas. L'opacité de
    -- la cible et celle des autres se posent donc à la main, plaque par plaque
    -- (voir `paint`), et c'est ce qui décide de la moitié du code de ce fichier.
    OCCLUDED = "nameplateOccludedAlphaMult",

    -- Le calibre de plaque du client, en cinq crans. On le lui emprunte quand
    -- notre taille en pixels est allumée, parce que les deux décident de la même
    -- chose (voir « Le calibre du client et nos pixels »).
    SIZE = "nameplateSize",

    -- Jamais écrit, seulement lu : c'est le plancher du fondu par la distance,
    -- et il sert à savoir ce qu'une plaque non occultée peut avoir de plus pâle
    -- (voir `isOccluded`).
    MIN_ALPHA = "nameplateMinAlpha",
}

--- nom du CVar -> valeur qu'il portait avant nous, ou `false` s'il n'existait pas
local savedCVars = {}

--- Écart en deçà duquel un CVar porte déjà la valeur voulue. Les CVars sont des
--- chaînes : « 1 » et « 1.000000 » sont le même réglage.
local CVAR_EPSILON = 0.001

--- On n'écrit que si la valeur diffère, et c'est ce qui empêche la boucle : le
--- client annonce chaque changement de CVar, et la veille qui reprend la main
--- après un autre addon est branchée sur cette annonce. Réécrire la même valeur
--- la déclencherait indéfiniment.
---@param name string
---@param value number
local function takeCVar(name, value)
    if savedCVars[name] == nil then
        savedCVars[name] = U.GetCVar(name) or false
    end

    local current = tonumber(U.GetCVar(name))
    if current and math.abs(current - value) < CVAR_EPSILON then return end

    U.SetCVar(name, value)
end

local function giveBackCVars()
    for name, value in pairs(savedCVars) do
        if value ~= false then U.SetCVar(name, value) end
    end
    wipe(savedCVars)
end

-- -------------------------------------------------------------------------
--  On n'appelle pas le pilote de barres d'infos. Jamais.
-- -------------------------------------------------------------------------
-- Il y avait ici une fonction qui demandait au client de reconstruire ses
-- plaques, `NamePlateDriverFrame:UpdateNamePlateOptions()`, pour que le curseur
-- de taille soit immédiat. **Elle est interdite**, et elle coûtait deux mille
-- six cents erreurs par clic :
--
--     CompactUnitFrame.lua:1199: attempt to compare local 'maxHealth'
--     (a secret number value, while execution tainted by 'BshamelUI')
--
-- Appelée depuis notre code, toute la chaîne du client s'exécute **teintée** :
-- `UpdateNamePlateOptions` → `ApplyFrameOptions` → `CompactUnitFrame_SetUpFrame`
-- → `CompactUnitFrame_UpdateAll`. Or ce chemin manipule des valeurs *secrètes* —
-- les points de vie d'une unité en sont — et une valeur secrète ne se compare
-- pas depuis du code teinté. Ce n'est pas notre code qui lève : c'est le sien,
-- parce que nous l'avons appelé.
--
-- Il n'y a pas de version prudente de cet appel. La règle est simple : **on
-- n'entre pas dans le code de mise en page du client.**
--
-- Et il n'y en a pas besoin. Le pilote écoute `CVAR_UPDATE` lui-même : écrire un
-- CVar d'échelle suffit à le faire repasser, depuis *son* gestionnaire
-- d'événement, donc sans teinture. On pose la valeur et on le laisse réagir —
-- c'est le même principe que partout ailleurs dans ce fichier, où l'on rappelle
-- ses fonctions plutôt que de refaire son travail, sauf qu'ici on ne le rappelle
-- même pas : on le laisse remarquer.

-- =========================================================================
--  Taille
-- =========================================================================
-- **En pixels, et par deux chemins différents**, parce que la largeur et la
-- hauteur d'une barre d'infos ne se règlent pas au même endroit :
--
--   · la **hauteur** est celle de la barre de vie, et elle se pose sur chaque
--     plaque, une par une. Le client la repose à chaque plaque montée : on
--     repasse derrière lui au moment où il écrit, par les mêmes hooks que les
--     couleurs ;
--   · la **largeur** est celle de la *boîte* de la plaque, et elle se pose pour
--     toutes d'un coup par `C_NamePlate.SetNamePlateSize`. C'est une fonction,
--     pas une frame : rien de teinté n'entre dans la mise en page du client, et
--     la barre de vie s'étire dans la boîte qu'on lui donne.
--
-- Les deux échelles CVar ont vécu ici. Elles ne changent plus rien sur ce
-- client — voir la table `CVAR`, qui dit pourquoi elles n'y sont plus.

--- barre de vie -> hauteur qu'elle portait avant qu'on y touche
local barHeights = {}

--- Relève la hauteur d'une barre, une fois.
---
--- Le client rend parfois une mesure **secrète** sur ces cadres : elle ne se
--- retient ni ne se repose. On garde alors la hauteur que le client donne par
--- défaut — c'est un repli, pas une mesure, et c'est ce qui permet malgré tout
--- de rendre la barre (règle 6 : on ne change pas ce qu'on ne saura pas rendre).
---@param bar table
local function rememberBarHeight(bar)
    if barHeights[bar] ~= nil then return end

    local ok, height = pcall(bar.GetHeight, bar)
    if ok and type(height) == "number" and not U.IsSecret(height) and height > 0 then
        barHeights[bar] = height
    else
        barHeights[bar] = T.SIZE.PLATE_BAR_H
    end
end

--- Sommes-nous en train de poser la hauteur ? Le hook ci-dessous rappelle notre
--- propre écriture ; ce drapeau coupe la boucle. Il est indispensable ici — à la
--- différence de la peinture, l'écriture *est* ce que le hook guette — et il ne
--- peut pas rester levé, l'écriture qu'il encadre étant sous `pcall`.
local settingHeight = false

--- Repose notre hauteur **à chaque fois que quelqu'un écrit la sienne**.
---
--- C'est ce qui manquait, et c'est ce qui faisait battre la barre entre les deux
--- valeurs : le client repose sa hauteur quand il monte une plaque, quand un
--- CVar bouge, quand l'échelle de l'interface change — des moments qu'aucun de
--- nos hooks de peinture ne couvre. On finissait donc par courir derrière lui,
--- et il gagnait une fois sur deux.
---
--- Se brancher sur l'écriture elle-même supprime la course : il n'y a plus de
--- moment à deviner, notre valeur est reposée dans le même souffle que la sienne.
--- Un hook par barre, posé une fois (`U.GuardedHook` ne double jamais), et inerte
--- dès que le module ou la section s'éteint.
---@param bar table
local function hookBarHeight(bar)
    U.GuardedHook(bar, "SetHeight", function(self)
        if settingHeight then return end

        local mod = module()
        if not (mod and LIVE.size and mod:Get("resize")) then return end

        settingHeight = true
        pcall(self.SetHeight, self, mod:Get("height"))
        settingHeight = false
    end, function()
        local mod = module()
        return mod ~= nil and mod:IsEnabled()
    end)
end

--- Pose la hauteur voulue sur la barre de vie d'une plaque.
---@param mod table
---@param unitFrame table
local function applyBarHeight(mod, unitFrame)
    if not LIVE.size then return end

    local bar = unitFrame.HealthBarsContainer or unitFrame.healthBar
    if type(bar) ~= "table" or type(bar.SetHeight) ~= "function" then return end

    -- Le hook se pose même réglage éteint : il ne fait rien tant que la case ne
    -- l'autorise pas, et le poser plus tard voudrait dire attendre qu'une plaque
    -- repasse par ici après le clic.
    hookBarHeight(bar)
    if not mod:Get("resize") then return end

    rememberBarHeight(bar)
    settingHeight = true
    pcall(bar.SetHeight, bar, mod:Get("height"))
    settingHeight = false
end

-- -------------------------------------------------------------------------
--  La barre de sorts
-- -------------------------------------------------------------------------
-- Même traitement que la barre de vie, et pour la même raison : sa hauteur se
-- pose sur elle, plaque par plaque, et le client la repose quand il monte une
-- plaque. Un hook sur son écriture, donc, comme partout ailleurs dans ce
-- fichier.
--
-- Sa **largeur** est un pari : rien ne dit qu'elle n'est pas tendue d'un bord à
-- l'autre de la plaque, auquel cas la lui imposer ne prendra pas. Le réglage est
-- écrit, il est réversible, et il se verra à l'essai.

--- barre de sorts -> { largeur, hauteur } avant qu'on y touche
local castSizes = {}

local settingCast = false

---@param unitFrame table
---@return table|nil
local function castBarOf(unitFrame)
    local bar = unitFrame.castBar or unitFrame.CastBar
    if type(bar) == "table" and type(bar.SetHeight) == "function" then return bar end
    return nil
end

---@param mod table
---@param bar table
--- La hauteur seule : la largeur de cette barre est tendue par le client entre
--- deux ancrages, et une largeur explicite y est ignorée — le curseur qu'on
--- avait offert ne faisait rien, il est parti.
local function writeCastSize(mod, bar)
    settingCast = true
    pcall(bar.SetHeight, bar, mod:Get("castHeight"))
    settingCast = false
end

---@param bar table
local function hookCastSize(bar)
    local guard = function()
        local mod = module()
        return mod ~= nil and mod:IsEnabled()
    end

    local function repost(self)
        if settingCast then return end

        local mod = module()
        if not (mod and LIVE.size and mod:Get("resizeCast")) then return end
        writeCastSize(mod, self)
    end

    U.GuardedHook(bar, "SetHeight", repost, guard)
end

---@param mod table
---@param unitFrame table
local function applyCastSize(mod, unitFrame)
    if not LIVE.size then return end

    local bar = castBarOf(unitFrame)
    if not bar then return end

    hookCastSize(bar)
    if not mod:Get("resizeCast") then return end

    if castSizes[bar] == nil then
        local okH, height = pcall(bar.GetHeight, bar)
        -- Une mesure nulle n'est pas une mesure : une barre relevée avant sa
        -- première mise en page — elle ne se montre qu'en incantation — rend
        -- zéro, et reposer zéro rend la barre invisible pour de bon. Zéro se
        -- traite comme le secret — on retient le repli du thème.
        castSizes[bar] = (okH and type(height) == "number"
            and not U.IsSecret(height) and height > 0)
            and height or T.SIZE.PLATE_CAST_BAR_H
    end

    writeCastSize(mod, bar)
end

--- Rend sa hauteur à chaque barre de sorts qu'on a retaillée.
local function restoreCastSizes()
    settingCast = true
    for bar, height in pairs(castSizes) do
        pcall(bar.SetHeight, bar, height)
    end
    settingCast = false
    wipe(castSizes)
end

-- -------------------------------------------------------------------------
--  Le corps des textes
-- -------------------------------------------------------------------------
--- Un curseur par famille de texte : ce qui s'écrit sur la barre de vie d'un
--- côté, ce qui s'écrit sur la barre de sorts de l'autre. Le client leur donne
--- déjà deux corps distincts — `HEALTH_BAR_FONT_HEIGHT` et
--- `CAST_BAR_FONT_HEIGHT` — et les fondre en un seul réglage effacerait une
--- distinction qui est la sienne.
---
--- Dans chaque famille, en revanche, **on ne nomme aucun texte**. Les clés
--- changent d'une extension à l'autre, et une clé oubliée donnerait un réglage
--- qui marche « sauf sur un texte », ce qui se lit comme une panne. On recense
--- donc ce que la plaque porte réellement, une fois par plaque.
---
--- Le partage entre les deux familles est un **périmètre**, pas une liste : tout
--- ce qui descend de la barre de sorts lui appartient, tout le reste est à la
--- plaque. C'est vrai quels que soient les cadres que Blizzard y range.
---
--- Le recensement construit des tables : il est fait une seule fois par cadre,
--- au moment où on le rencontre, et jamais depuis un chemin chaud (règle 7).

--- cadre d'unité -> ses textes, hors barre de sorts
local plateTexts = {}

--- cadre d'unité -> les textes de sa barre de sorts
local castTexts = {}

--- texte -> corps qu'il portait avant qu'on y touche
local textSizes = {}

--- Descend dans un cadre et ajoute à `list` tous les textes rencontrés.
--- Un cadre absent — une plaque sans barre de sorts — rend une liste vide.
---@param frame table|nil
---@param list table
---@param depth number
---@param skip? table  sous-arbre à ne pas visiter
local function gatherTexts(frame, list, depth, skip)
    if depth > T.SIZE.PLATE_TEXT_DEPTH then return end
    if type(frame) ~= "table" or frame == skip then return end

    local ok, regions = pcall(function() return { frame:GetRegions() } end)
    if ok then
        for i = 1, #regions do
            local region = regions[i]
            if type(region) == "table" and type(region.GetObjectType) == "function"
               and region:GetObjectType() == "FontString" then
                list[#list + 1] = region
            end
        end
    end

    local descended, children = pcall(function() return { frame:GetChildren() } end)
    if not descended then return end

    for i = 1, #children do
        gatherTexts(children[i], list, depth + 1, skip)
    end
end

--- Les textes de la plaque, la barre de sorts exceptée.
---@param unitFrame table
---@return table
local function textsOf(unitFrame)
    local list = plateTexts[unitFrame]
    if list then return list end

    list = {}
    gatherTexts(unitFrame, list, 1, castBarOf(unitFrame))
    plateTexts[unitFrame] = list
    return list
end

--- Les textes de la seule barre de sorts.
---@param unitFrame table
---@return table
local function castTextsOf(unitFrame)
    local list = castTexts[unitFrame]
    if list then return list end

    list = {}
    gatherTexts(castBarOf(unitFrame), list, 1)
    castTexts[unitFrame] = list
    return list
end

--- Oublie le recensement d'une plaque, pour qu'il soit refait.
---
--- Appelé quand le client donne une plaque à quelqu'un — le seul moment où son
--- contenu peut changer. Certains textes n'existent pas tant qu'ils n'ont rien à
--- dire : les points de vie apparaissent avec la première valeur, et une liste
--- établie avant eux les manquerait pour toujours. C'est aussi ce qui rattrape un
--- texte qu'un autre addon aurait posé sur la plaque après nous.
---
--- Recenser à ce moment-là et à aucun autre est ce qui garde la descente hors des
--- chemins chauds : quelques plaques par seconde au plus fort d'une pull, jamais
--- une par image.
---@param unitFrame table|nil
local function forgetTexts(unitFrame)
    if not unitFrame then return end
    plateTexts[unitFrame] = nil
    castTexts[unitFrame]  = nil
end

--- Sommes-nous en train de poser un corps ? Même rôle que pour la hauteur : le
--- hook ci-dessous guette l'écriture, donc il rappelle la nôtre.
local settingFont = false

--- Repose notre corps à chaque fois que quelqu'un écrit le sien.
---
--- Le hook porte les deux clés de son réglage : un texte appartient à une famille
--- et à une seule, décidée au recensement. Il n'a donc rien à redécouvrir quand il
--- se déclenche.
---@param fontString table
---@param toggleKey string
---@param sizeKey string
local function hookTextSize(fontString, toggleKey, sizeKey)
    local guard = function()
        local mod = module()
        return mod ~= nil and mod:IsEnabled()
    end

    local function repost(self)
        if settingFont then return end

        local mod = module()
        if not (mod and LIVE.size and mod:Get(toggleKey)) then return end

        settingFont = true
        T.SetTextSize(self, mod:Get(sizeKey))
        settingFont = false
    end

    -- Les deux écritures, parce que le client emploie les deux : il pose un
    -- **objet de police** au montage d'une plaque, et une police explicite
    -- ailleurs. N'en guetter qu'une laisserait la moitié des remises à zéro
    -- passer — c'est exactement ce qui faisait battre la hauteur.
    U.GuardedHook(fontString, "SetFont", repost, guard)
    U.GuardedHook(fontString, "SetFontObject", repost, guard)
end

--- Pose un corps sur une famille de textes.
---@param mod table
---@param texts table
---@param toggleKey string
---@param sizeKey string
---@param fallback number
local function sizeTexts(mod, texts, toggleKey, sizeKey, fallback)
    local on   = mod:Get(toggleKey)
    local size = mod:Get(sizeKey)

    for i = 1, #texts do
        local text = texts[i]
        hookTextSize(text, toggleKey, sizeKey)

        if on then
            if textSizes[text] == nil then
                textSizes[text] = T.TextSize(text) or fallback
            end
            settingFont = true
            T.SetTextSize(text, size)
            settingFont = false
        end
    end
end

---@param mod table
---@param unitFrame table
local function applyTextSize(mod, unitFrame)
    if not LIVE.size then return end

    sizeTexts(mod, textsOf(unitFrame), "resizeText", "textSize",
              T.SIZE.PLATE_TEXT)
    sizeTexts(mod, castTextsOf(unitFrame), "resizeCastText", "castTextSize",
              T.SIZE.PLATE_CAST_TEXT)
end

--- Rend son corps à chaque texte qu'on a retaillé.
---
--- Les deux familles d'un coup : ce qui reste allumé est reposé par le passage
--- qui suit, et distinguer ici lequel rendre demanderait de retenir à quelle
--- famille chaque texte appartenait — une table de plus pour un geste rare.
local function restoreTextSizes()
    settingFont = true
    for text, size in pairs(textSizes) do
        T.SetTextSize(text, size)
    end
    settingFont = false
    wipe(textSizes)
end

-- -------------------------------------------------------------------------
--  Le mode aperçu
-- -------------------------------------------------------------------------
-- Une barre de sorts ne se montre que pendant une incantation, une aura que
-- lorsqu'un sort la pose. Les régler supposait de trouver l'adversaire qui
-- voudra bien incanter ou lancer, de bouger un curseur d'un cran, et de
-- recommencer au suivant — ce qui n'est pas un réglage mais une chasse.
--
-- Le mode aperçu montre les deux d'un coup, sur les vraies plaques :
--
--   · **la vraie barre de sorts**, maintenue à l'écran et remplie en boucle.
--     C'est celle qu'on aura, à sa place, à sa taille — rien n'est imité ;
--   · **une rangée d'auras d'exemple**, une aide, une nuisance et une entrave.
--     Celles-là sont à nous, faute de pouvoir poser de fausses auras sur une
--     unité, mais elles portent les mesures du client et vivent **dans son
--     conteneur d'auras** : leur place n'est donc ni lue ni devinée.
--
-- Le client recache sa barre à chacune de ses passes. On se branche donc sur son
-- `Hide`, comme partout ailleurs dans ce fichier : aucun moment à deviner, elle
-- repart dans le même souffle. Éteindre le mode la lui rend sans autre forme de
-- procès — il la montrera à la prochaine incantation, c'est son travail.

--- Sommes-nous en train de la montrer ? `Show` ne déclenche pas `Hide`, donc pas
--- de récursion possible : le drapeau ne sert qu'à ce que notre propre `Hide`,
--- au moment où l'on rend la barre, ne soit pas aussitôt défait.
local showingCast = false

---@param bar table
local function hookCastPreview(bar)
    U.GuardedHook(bar, "Hide", function(self)
        if showingCast then return end

        local mod = module()
        if not (mod and LIVE.size and mod:Get("previewMode")) then return end

        showingCast = true
        pcall(self.Show, self)
        showingCast = false
    end, function()
        local mod = module()
        return mod ~= nil and mod:IsEnabled()
    end)
end

--- La barre de vie elle-même : ce qu'on teinte, et ce sur quoi le marqueur et
--- les rangées d'auras se calent.
---@param unitFrame table
---@return table|nil
local function healthBarOf(unitFrame)
    local bar = unitFrame.healthBar or unitFrame.HealthBarsContainer
    if type(bar) == "table" then return bar end
    return nil
end

--- Où en est l'incantation d'exemple, entre zéro et un.
---
--- Déduite de l'horloge et non accumulée : toutes les plaques avancent alors
--- ensemble, et une minuterie qui saute un battement ne décale rien.
---@return number
local function castFill()
    return (GetTime() % T.TIMING.PLATE_CAST_CYCLE) / T.TIMING.PLATE_CAST_CYCLE
end

--- Maintient la barre de sorts d'une plaque à l'écran, en cours d'incantation.
--- barres que l'aperçu montre en ce moment -> `true`. C'est ce qui distingue
--- « éteindre l'aperçu » de « passer en le laissant éteint » : le premier rend
--- la barre au client une fois, le second ne la touche pas. Sans cette nuance,
--- chaque repeinture cachait la barre — y compris pendant une vraie
--- incantation, et c'est pour ça qu'on ne voyait plus de castbar en combat.
local previewShown = {}

---@param mod table
---@param unitFrame table
local function applyCastPreview(mod, unitFrame)
    if not LIVE.size then return end

    local bar = castBarOf(unitFrame)
    if not bar then return end

    hookCastPreview(bar)

    if not mod:Get("previewMode") then
        if previewShown[bar] then
            previewShown[bar] = nil
            showingCast = true
            pcall(bar.Hide, bar)
            showingCast = false
        end
        return
    end

    previewShown[bar] = true

    pcall(bar.SetMinMaxValues, bar, 0, 1)
    pcall(bar.SetValue, bar, castFill())
    pcall(bar.Show, bar)

    -- L'opacité en plus de l'affichage : le client ne cache pas toujours cette
    -- barre, il la laisse parfois à opacité nulle. `Show` seul la laisserait alors
    -- invisible, et on chercherait longtemps pourquoi.
    pcall(bar.SetAlpha, bar, 1)

    -- Un nom de sort d'exemple, écrit sur le premier texte **recensé** de cette
    -- barre : on ne cherche pas son champ, on écrit sur ce qu'on a trouvé. Sans
    -- lui la barre est vide, et le corps du texte ne se règle pas mieux qu'avant.
    local texts = castTextsOf(unitFrame)
    if texts[1] then pcall(texts[1].SetText, texts[1], L["Sample cast"]) end
end

-- -------------------------------------------------------------------------
--  Les trois rangées d'auras de l'addon
-- -------------------------------------------------------------------------
-- L'addon affiche lui-même les auras des plaques, et c'est ce qui donne à
-- l'aperçu le seul luxe qui compte : **l'aperçu et la réalité sont le même
-- code** — même widget, mêmes réglages, même place (technique lue chez MiniCC,
-- règle 8). Rien n'est dessiné au sens propre : les icônes, le balayage et les
-- polices sont les assets du client, on ne fait que les assembler.
--
-- Trois rangées, parce que trois questions différentes se posent en combat, et
-- qu'elles ne se regardent pas au même endroit :
--
--   · **l'important** — ce que l'unité a d'offensif ou de défensif sur elle.
--     À gauche de la barre de vie ;
--   · **nos affaiblissements** — les nôtres seulement : ce sont eux qu'on
--     entretient. En haut à gauche ;
--   · **les contrôles** — de tous les joueurs : un mob mouton est mouton,
--     peu importe qui l'a lancé. À droite.
--
-- Chaque rangée a sa taille, son décalage et son écart. Quand elles sont
-- allumées, la rangée du client s'efface — à l'opacité, rendue d'un geste.

--- cadre d'unité -> ses trois rangées ({ imp =, dot =, cc = })
local auraRows = {}

--- cadre d'unité -> ses trois listes, tables de travail réutilisées (règle 7 :
--- `UNIT_AURA` est un chemin chaud). `list.n` borne le rempli ; `refused` compte
--- les auras que le client n'a pas laissé lire.
local auraLists = {}

--- conteneurs du client qu'on a effacés -> `true`
local dimmedHosts = {}

--- Sommes-nous en train d'écrire l'opacité du conteneur ?
local settingHostAlpha = false

--- Cachet de mise en page : les rangées ne se réancrent que quand un réglage a
--- changé, jamais à chaque repeinture — `paint` passe à chaque battement de vie.
local auraStamp = 1

--- Les entraves. Aucune API ne dit qu'une aura est un contrôle : c'est un
--- vocabulaire, comme le code couleur des paliers de clé, et il se tient ici.
--- La liste porte les contrôles que tout le monde nomme ; elle s'allonge d'une
--- ligne quand il en manque un.
local CC_SPELLS = {
    [118]    = true,  -- Métamorphose
    [51514]  = true,  -- Maléfice
    [5782]   = true,  -- Peur
    [8122]   = true,  -- Cri psychique
    [605]    = true,  -- Contrôle mental
    [408]    = true,  -- Aiguillon perfide
    [2094]   = true,  -- Cécité
    [6770]   = true,  -- Assommer
    [853]    = true,  -- Marteau de la justice
    [20066]  = true,  -- Repentir
    [99]     = true,  -- Rugissement incapacitant
    [119381] = true,  -- Balayage du pied
    [179057] = true,  -- Nova du chaos
    [30283]  = true,  -- Furie de l'ombre
}

--- Les trois rangées : leur clé de rangement, leurs réglages, leur ancrage sur
--- la barre de vie, et la nature d'aura qui teinte leur liseré.
---
--- L'ancrage est déclaré ici et nulle part ailleurs : c'est lui qui dit « à
--- gauche », « en haut à gauche », « à droite », et le décalage X/Y du joueur
--- s'ajoute à partir de là.
local AURA_GROUPS = {
    { key = "imp", kind = "HELP",
      point = "RIGHT", relative = "LEFT",
      size = "auraImpSize", x = "auraImpX", y = "auraImpY", gap = "auraImpGap" },
    { key = "dot", kind = "HARM",
      point = "BOTTOMLEFT", relative = "TOPLEFT",
      size = "auraDotSize", x = "auraDotX", y = "auraDotY", gap = "auraDotGap" },
    { key = "cc", kind = "CC",
      point = "LEFT", relative = "RIGHT",
      size = "auraCcSize", x = "auraCcX", y = "auraCcY", gap = "auraCcGap" },
}

--- Sorts d'exemple du mode aperçu, par rangée. Des classiques dont l'icône n'a
--- pas changé en vingt ans ; l'entrave est prise **dans la liste des
--- contrôles**, pour passer par le même classement qu'une vraie.
local SAMPLE_SPELLS = {
    imp = { 31884, 871 },     -- Courroux vengeur, Mur protecteur
    dot = { 172, 589 },       -- Corruption, Mot de l'ombre : Douleur
    cc  = { 118 },            -- Métamorphose
}

--- Les listes d'exemple, une par rangée. Les durées repartent à chaque allumage
--- du mode aperçu : un balayage figé ressemble à une aura expirée.
local sampleLists = {
    imp = { n = 0 }, dot = { n = 0 }, cc = { n = 0 },
}

local function refreshSampleList()
    if not (C_Spell and C_Spell.GetSpellTexture) then return end
    local now = GetTime()

    for g = 1, #AURA_GROUPS do
        local group = AURA_GROUPS[g]
        local list  = sampleLists[group.key]
        list.n = 0

        local spells = SAMPLE_SPELLS[group.key]
        for i = 1, #spells do
            local icon = C_Spell.GetSpellTexture(spells[i])
            if icon then
                local n = list.n + 1
                local entry = list[n]
                if not entry then entry = {} list[n] = entry end

                entry.icon           = icon
                entry.kind           = group.kind
                entry.count          = (group.key == "dot" and n == 1) and 3 or nil
                entry.duration       = 15
                entry.expirationTime = now + 15 - (n - 1) * 3

                -- Un vrai objet de durée quand le client sait en fabriquer :
                -- l'exemple passe alors par la même horloge que les vraies
                -- auras. Les deux nombres restent le repli.
                entry.durationObject = nil
                if C_DurationUtil and C_DurationUtil.CreateDuration then
                    local ok, durationObject = pcall(C_DurationUtil.CreateDuration,
                        now - (n - 1) * 3, 15)
                    if ok then entry.durationObject = durationObject end
                end
                list.n = n
            end
        end
    end
end

--- Les auras d'une unité pour un filtre, ou `nil` si le client refuse le
--- filtre. `GetUnitAuras` est le chemin qui **marche** sur ce client — la
--- lecture indexée d'antan ne rend plus rien — et ses filtres composés
--- (`HARMFUL|CROWD_CONTROL`…) portent le classement du client lui-même.
---@param unit string
---@param filter string
---@return table|nil
local function bulkAuras(unit, filter)
    if not (C_UnitAuras and C_UnitAuras.GetUnitAuras) then return nil end
    local ok, auras = pcall(C_UnitAuras.GetUnitAuras, unit, filter)
    if not ok or type(auras) ~= "table" then return nil end
    return auras
end

--- identifiants déjà rangés pendant un passage, pour qu'une aura qui répond à
--- deux filtres ne s'affiche pas deux fois. Table de travail (règle 7).
local collectSeen = {}

--- Range une aura dans sa liste, si elle a encore de la place.
---
--- **La durée est un objet, pas deux nombres.** Sur ce client, départ et
--- échéance ne se lisent plus sur l'aura : `GetAuraDuration` rend un objet
--- opaque que le balayage sait consommer tel quel — c'est ce qui fait tourner
--- l'horloge sans jamais lire une valeur que le client protège.
---@param list table
---@param kind string
---@param unit string
---@param aura table
---@param lists table  pour le compte des refus
local function admitAura(list, kind, unit, aura, lists)
    local icon = aura.icon
    if not icon or U.IsSecret(icon) then
        lists.refused = lists.refused + 1
        return
    end

    local id = aura.auraInstanceID
    if id and not U.IsSecret(id) then
        if collectSeen[id] then return end
        collectSeen[id] = true
    end

    if list.n >= T.SIZE.PLATE_AURA_MAX then return end

    local n = list.n + 1
    local entry = list[n]
    if not entry then entry = {} list[n] = entry end

    entry.icon  = icon
    entry.kind  = kind
    entry.count = not U.IsSecret(aura.applications) and aura.applications or nil

    entry.durationObject = nil
    if id and not U.IsSecret(id) and C_UnitAuras.GetAuraDuration then
        local ok, durationObject = pcall(C_UnitAuras.GetAuraDuration, unit, id)
        if ok then entry.durationObject = durationObject end
    end

    list.n = n
end

--- Verse un lot d'auras dans une liste.
---@param auras table|nil
---@param list table
---@param kind string
---@param unit string
---@param lists table
---@param onlyMine? boolean  n'admettre que ce que le joueur a posé
local function admitAll(auras, list, kind, unit, lists, onlyMine)
    if not auras then return end
    for i = 1, #auras do
        local aura = auras[i]
        if not onlyMine or U.IsTrue(aura.isFromPlayerOrPlayerPet) then
            admitAura(list, kind, unit, aura, lists)
        end
    end
end

--- Remplit les trois listes d'une plaque avec les vraies auras de son unité.
---
--- Chaque rangée essaie d'abord le filtre **classé** du client, qui sait mieux
--- que nous ce qui est un contrôle ou un grand défensif ; à défaut — le client
--- peut retirer un filtre — elle retombe sur le filtre large et sur notre
--- vocabulaire. Les contrôles se lisent avant les affaiblissements : une
--- entrave est aussi un affaiblissement, et `collectSeen` donne la place au
--- premier arrivé.
---@param unit string
---@param lists table
local function collectAuras(unit, lists)
    lists.refused = 0
    lists.imp.n, lists.dot.n, lists.cc.n = 0, 0, 0
    wipe(collectSeen)

    -- Les contrôles : le classement du client d'abord, tous lanceurs confondus.
    local cc = bulkAuras(unit, "HARMFUL|CROWD_CONTROL")
    admitAll(cc, lists.cc, "CC", unit, lists)

    -- Nos affaiblissements. `HARMFUL|PLAYER` filtre côté client ; à défaut, le
    -- champ de l'aura dit la même chose.
    local dots = bulkAuras(unit, "HARMFUL|PLAYER")
    if dots then
        admitAll(dots, lists.dot, "HARM", unit, lists)
    else
        local harmful = bulkAuras(unit, "HARMFUL")
        if harmful and not cc then
            -- Sans le filtre classé, notre vocabulaire fait le tri des entraves.
            for i = 1, #harmful do
                local aura = harmful[i]
                local spellID = not U.IsSecret(aura.spellId) and aura.spellId or nil
                if spellID and CC_SPELLS[spellID] then
                    admitAura(lists.cc, "CC", unit, aura, lists)
                end
            end
        end
        admitAll(harmful, lists.dot, "HARM", unit, lists, true)
    end

    -- L'important : les grands défensifs et les défensifs reçus, classés par le
    -- client. À défaut, toutes les améliorations — trop large, jamais vide.
    local big      = bulkAuras(unit, "HELPFUL|BIG_DEFENSIVE")
    local external = bulkAuras(unit, "HELPFUL|EXTERNAL_DEFENSIVE")
    if big or external then
        admitAll(big, lists.imp, "HELP", unit, lists)
        admitAll(external, lists.imp, "HELP", unit, lists)
    else
        admitAll(bulkAuras(unit, "HELPFUL"), lists.imp, "HELP", unit, lists)
    end
end

--- Efface ou rend la rangée du client. À l'opacité, avec un hook qui la tient :
--- le client la repose à ses passes, comme la hauteur de barre — même remède.
---@param host table
---@param dim boolean
local function dimHost(host, dim)
    if dim then
        dimmedHosts[host] = true
        U.GuardedHook(host, "SetAlpha", function(self)
            if settingHostAlpha then return end

            local mod = module()
            if not (mod and LIVE.auras and mod:Get("ownAuras")) then return end

            settingHostAlpha = true
            pcall(self.SetAlpha, self, 0)
            settingHostAlpha = false
        end, function()
            local mod = module()
            return mod ~= nil and mod:IsEnabled()
        end)
    elseif not dimmedHosts[host] then
        return
    else
        dimmedHosts[host] = nil
    end

    settingHostAlpha = true
    pcall(host.SetAlpha, host, dim and 0 or 1)
    settingHostAlpha = false
end

local function undimAllHosts()
    settingHostAlpha = true
    for host in pairs(dimmedHosts) do
        pcall(host.SetAlpha, host, 1)
    end
    settingHostAlpha = false
    wipe(dimmedHosts)
end

--- Un réglage d'aura a changé : les rangées se réancreront à la prochaine
--- repeinture. Appelé au changement de réglage, jamais depuis la peinture.
local function bumpAuraLayout()
    auraStamp = auraStamp + 1
end

--- Ancre les trois rangées d'une plaque sur sa barre de vie, si le cachet a
--- changé depuis la dernière fois.
---@param mod table
---@param unitFrame table
---@param rows table
local function anchorRows(mod, unitFrame, rows)
    if rows._stamp == auraStamp then return end
    rows._stamp = auraStamp

    local bar = healthBarOf(unitFrame) or unitFrame

    for g = 1, #AURA_GROUPS do
        local group = AURA_GROUPS[g]
        local row = rows[group.key]
        if row then
            pcall(row.ClearAllPoints, row)
            pcall(row.SetPoint, row, group.point, bar, group.relative,
                  mod:Get(group.x), mod:Get(group.y))
        end
    end
end

--- Pose les trois rangées d'une plaque : les auras d'exemple si le mode aperçu
--- est là, les vraies sinon. **C'est la seule fonction qui choisisse entre les
--- deux**, et elles finissent dans le même widget — le luxe tient tout ici.
---
--- `force` relit les auras même si les rangées sont peuplées. Sans lui, une
--- plaque visible garde ce qu'elle montre : `paint` passe à chaque battement de
--- vie, et relire quarante auras à ce rythme est ce que la règle 7 interdit.
--- C'est `UNIT_AURA` qui force — il ne parle que quand une aura change.
---@param mod table
---@param unitFrame table
---@param unit string
---@param force? boolean
local function applyOwnAuras(mod, unitFrame, unit, force)
    if not LIVE.auras then return end

    -- En pause : rien ne se pose, rien ne s'efface chez le client, et ce qui
    -- aurait déjà été posé se range. La page, elle, montre la section grisée.
    if AURAS_PAUSED then
        local rows = auraRows[unitFrame]
        if rows then
            for g = 1, #AURA_GROUPS do
                local row = rows[AURA_GROUPS[g].key]
                if row then row:Hide() end
            end
        end
        local host = unitFrame.AurasFrame or unitFrame.BuffFrame
        if type(host) == "table" and type(host.SetAlpha) == "function" then
            dimHost(host, false)
        end
        return
    end

    local own     = mod:Get("ownAuras") and true or false
    local preview = mod:Get("previewMode") and true or false

    local rows = auraRows[unitFrame]
    if not rows then
        if not (own or preview) then return end
        rows = {}
        for g = 1, #AURA_GROUPS do
            rows[AURA_GROUPS[g].key] = W.AuraRow(unitFrame)
        end
        auraRows[unitFrame] = rows
    end

    local host = unitFrame.AurasFrame or unitFrame.BuffFrame
    if type(host) ~= "table" or type(host.SetAlpha) ~= "function" then
        host = nil
    end

    if not (own or preview) then
        for g = 1, #AURA_GROUPS do
            local row = rows[AURA_GROUPS[g].key]
            if row then row:Hide() end
        end
        if host then dimHost(host, false) end
        return
    end

    anchorRows(mod, unitFrame, rows)

    if preview then
        if host then dimHost(host, own) end
        for g = 1, #AURA_GROUPS do
            local group = AURA_GROUPS[g]
            local row = rows[group.key]
            if row then
                W.AuraRowSet(row, sampleLists[group.key],
                             mod:Get(group.size), mod:Get(group.gap))
            end
        end
        return
    end

    local lists = auraLists[unitFrame]
    if not lists then
        lists = { imp = { n = 0 }, dot = { n = 0 }, cc = { n = 0 }, refused = 0 }
        auraLists[unitFrame] = lists
    end

    local filled = rows._filled
    if force or not filled then
        collectAuras(unit, lists)
        rows._filled = true
    end

    -- Le repli, et il est la moitié de l'honnêteté de ces rangées : quand le
    -- client refuse la lecture des auras — il le fait en instance protégée —,
    -- les nôtres seraient vides pendant que la sienne est effacée, et le joueur
    -- perdrait les auras tout court. Une aura refusée rend la main au client :
    -- sa rangée revient, les nôtres se taisent, rien ne disparaît.
    local blind = own and lists.refused > 0
        and lists.imp.n == 0 and lists.dot.n == 0 and lists.cc.n == 0
    if host then dimHost(host, own and not blind) end

    for g = 1, #AURA_GROUPS do
        local group = AURA_GROUPS[g]
        local row = rows[group.key]
        if row then
            W.AuraRowSet(row, lists[group.key],
                         mod:Get(group.size), mod:Get(group.gap))
        end
    end
end

--- Cache toutes les rangées et rend la sienne au client. Les frames restent
--- prêtes pour la prochaine fois (règle 7).
local function hideAuraRows()
    for _, rows in pairs(auraRows) do
        for g = 1, #AURA_GROUPS do
            local row = rows[AURA_GROUPS[g].key]
            if row then row:Hide() end
        end
        rows._filled = nil
    end
    undimAllHosts()
end

--- Fait couler les barres d'exemple. `nil` quand personne ne les regarde.
local castTicker

--- Ne pose que la valeur : tout le reste — l'affichage, l'opacité, le texte — a
--- été posé au dernier passage de peinture et n'a pas à être repayé vingt fois
--- par seconde (règle 7).
local function tickCastPreview()
    local fill = castFill()
    for _, plate in pairs(plates) do
        local unitFrame = unitFrameOf(plate)
        local bar = unitFrame and castBarOf(unitFrame)
        if bar then pcall(bar.SetValue, bar, fill) end
    end
end

---@param mod table
local function updateCastTicker(mod)
    local wanted = LIVE.size and mod:Get("previewMode")

    if wanted and not castTicker then
        castTicker = C_Timer.NewTicker(T.TIMING.PLATE_CAST, tickCastPreview)
    elseif not wanted and castTicker then
        castTicker:Cancel()
        castTicker = nil
    end
end

--- Rend sa hauteur à chaque barre qu'on a épaissie.
local function restoreBarHeights()
    settingHeight = true
    for bar, height in pairs(barHeights) do
        pcall(bar.SetHeight, bar, height)
    end
    settingHeight = false
    wipe(barHeights)
end

-- -------------------------------------------------------------------------
--  La largeur : une fonction, pas une frame
-- -------------------------------------------------------------------------
-- `C_NamePlate.SetNamePlateSize(largeur, hauteur)` pose la boîte de **toutes**
-- les plaques d'un coup, et `GetNamePlateSize` la relit. Deux remarques, et
-- chacune a coûté un essai :
--
--   · le nom compte. `SetNamePlateEnemySize` — la fonction par faction, celle
--     que tout le monde cite — n'existe plus ici : seul le couple sans faction
--     répond. Un appel à une fonction absente ne se voit pas quand il est sous
--     `pcall`, il ne fait simplement rien ;
--   · elle est **refusée en combat**. Rien n'échoue bruyamment : la taille ne
--     prend pas, voilà tout. Ce qui est refusé est repassé à la sortie de combat.
--
-- La hauteur de boîte n'est pas réglable ici : c'est la zone qui reçoit le clic,
-- et la rétrécir rendrait les plaques difficiles à viser sans que rien ne le
-- dise. On repose la sienne, relevée avec la largeur.

--- { largeur, hauteur } de la boîte avant qu'on y touche, ou `nil`.
local savedPlateSize

--- Relève la taille de boîte, une fois. Renvoie sa hauteur, la seule des deux
--- qu'on repose telle quelle.
---@return number|nil boxHeight
local function rememberPlateSize()
    if not (C_NamePlate and C_NamePlate.GetNamePlateSize) then return nil end

    if not savedPlateSize then
        local ok, width, height = pcall(C_NamePlate.GetNamePlateSize)
        if not (ok and type(width) == "number" and type(height) == "number") then
            return nil
        end
        savedPlateSize = { width, height }
    end

    return savedPlateSize[2]
end

---@param mod table
local function applyPlateWidth(mod)
    if not (C_NamePlate and C_NamePlate.SetNamePlateSize) then return end
    if not mod:Get("resize") then return end
    if InCombatLockdown() then return end

    local boxHeight = rememberPlateSize()
    if not boxHeight then return end

    pcall(C_NamePlate.SetNamePlateSize, mod:Get("width"), boxHeight)
end

--- Rend aux plaques la boîte qu'elles avaient — la vraie, relevée, pas une
--- reconstitution.
local function restorePlateWidth()
    if not savedPlateSize then return end
    if not (C_NamePlate and C_NamePlate.SetNamePlateSize) then return end
    if InCombatLockdown() then return end

    pcall(C_NamePlate.SetNamePlateSize, savedPlateSize[1], savedPlateSize[2])
    savedPlateSize = nil
end

---@param mod table
local function applySize(mod)
    applyPlateWidth(mod)
end

-- =========================================================================
--  Opacité
-- =========================================================================
-- Trois états, trois opacités, et elles ne se posent pas au même endroit.
--
--   · **cible et non-cible** : posées par nous, sur le cadre d'unité de chaque
--     plaque. Le client n'a pas de réglage pour elles — ses deux CVars
--     historiques n'existent plus que sur les clients classic ;
--   · **occultée** : posée par le client, sur la plaque elle-même. C'est le
--     seul des trois qu'il sache faire, et le seul qu'on ne saurait pas faire —
--     il faudrait pour cela savoir ce qu'il ne dit pas (voir `isOccluded`).
--
-- Les deux se **multiplient** : notre opacité vit sur le cadre d'unité, la
-- sienne sur la plaque qui le porte. Le CVar est donc un rapport, pas une
-- opacité, et on le calcule à partir des deux curseurs pour que le joueur règle
-- bien trois opacités et non deux opacités et un rapport.

---@param mod table
local function applyAlpha(mod)
    if not LIVE.visibility then return end
    if not mod:Get("visibility") then return end

    local other    = mod:Get("otherAlpha")
    local occluded = mod:Get("occludedAlpha")

    -- Rapporté à l'opacité des **non-ciblés** : c'est l'état dans lequel se
    -- trouve la quasi-totalité des plaques occultées. Une plaque à la fois
    -- ciblée et occultée sera donc un peu plus pâle que le curseur ne le dit —
    -- c'est le seul cas où le rapport ne tombe pas juste, et il suppose de viser
    -- à travers un mur.
    local mult = (other > 0) and (occluded / other) or 1
    takeCVar(CVAR.OCCLUDED, U.Clamp(mult, 0, 1))
end

-- =========================================================================
--  Assombrissement, et la question de l'occultation
-- =========================================================================

--- Écart en deçà duquel deux opacités sont la même. Les valeurs viennent du
--- moteur et ne tombent pas au millième près.
local ALPHA_EPSILON = 0.01

--- Cette plaque est-elle occultée ?
---
--- **Rien ne le dit, on le déduit — et la déduction est sûre.** L'opacité que le
--- moteur pose sur la **plaque** — celle qu'il possède, pas le cadre d'unité où
--- vit la nôtre — vaut, pour une plaque visible, le seul fondu par la distance.
--- Ce fondu ne descend jamais sous `nameplateMinAlpha`. Une plaque occultée
--- porte en plus le multiplicateur d'occultation.
---
--- Il suffit donc de comparer au **plancher du fondu** : rien de visible ne peut
--- passer en dessous, donc tout ce qui est en dessous est occulté. Aucun faux
--- positif, jamais.
---
--- La réciproque tient tant que le multiplicateur d'occultation est plus bas que
--- ce plancher — c'est-à-dire dès que le réglage veut dire quelque chose. Réglé
--- au-dessus, l'assombrissement des occultés ne se déclenche pas : le réglage
--- reste sans effet plutôt que d'assombrir des plaques qui ne le méritent pas.
---
--- On ne cherche que si l'assombrissement des occultés est demandé : l'opacité,
--- elle, est déjà posée par le client sans que personne ait rien à deviner.
---@param plate table
---@return boolean
local function isOccluded(plate)
    -- Sous `pcall` comme toute lecture faite sur une plaque : le client refuse
    -- certaines mesures sur ces cadres-là, et un refus se lit « on ne sait pas »,
    -- pas « erreur » (voir la section sur les ancrages restreints).
    local ok, alpha = pcall(plate.GetAlpha, plate)
    if not ok or type(alpha) ~= "number" then return false end

    local floor = tonumber(U.GetCVar(CVAR.MIN_ALPHA)) or 1
    return alpha < floor - ALPHA_EPSILON
end

--- Cette unité est-elle la cible du joueur ?
---
--- `UnitIsUnit` rend un booléen **secret** dès que l'identité d'une des deux
--- unités est protégée : le tester en direct lève (voir `U.IsTrue`).
---@param unit string
---@return boolean
local function isTargetUnit(unit)
    return U.IsTrue(UnitIsUnit(unit, "target"))
end

--- État visuel d'une plaque.
---@param mod table
---@param plate table
---@param isTarget boolean
---@return string  "target" | "other" | "occluded"
local function stateOf(mod, plate, isTarget)
    if mod:Get("visibility") and mod:Get("occludedDarkness") > 0
       and isOccluded(plate) then
        return "occluded"
    end

    return isTarget and "target" or "other"
end

--- Opacité que le module pose lui-même sur un cadre d'unité.
---
--- Deux valeurs et non trois : l'occultation est **multipliée** par-dessus par
--- le client. Une plaque occultée garde donc l'opacité de son état — cible ou
--- non — et c'est le rapport posé dans `applyAlpha` qui la rabaisse.
---@param mod table
---@param isTarget boolean
---@return number
local function alphaOf(mod, isTarget)
    return (isTarget and mod:Get("targetAlpha") or mod:Get("otherAlpha")) / 100
end

--- cadre d'unité -> opacité qu'il portait avant qu'on y touche
local alphaTaken = {}

--- Sommes-nous en train de poser une opacité ? Même rôle que pour la hauteur de
--- barre et le corps des textes : le hook ci-dessous guette l'écriture, donc il
--- rappelle la nôtre.
local settingAlpha = false

--- Repose notre opacité **à chaque fois que quelqu'un écrit la sienne**.
---
--- Posé d'emblée, sans attendre de voir battre l'opacité : c'est la troisième
--- fois que la question se pose dans ce fichier — la hauteur de barre, le corps
--- des textes, et maintenant celle-ci — et la réponse a été la même les deux
--- premières. Le client repose ce qu'il possède quand il le décide ; se brancher
--- sur son écriture est la seule façon de n'avoir aucun moment à deviner.
---@param unitFrame table
local function hookAlpha(unitFrame)
    U.GuardedHook(unitFrame, "SetAlpha", function(self)
        if settingAlpha then return end

        local mod = module()
        if not (mod and LIVE.visibility and mod:Get("visibility")) then return end

        local unit = self.unit or self.displayedUnit
        if type(unit) ~= "string" or not plates[unit] then return end

        settingAlpha = true
        pcall(self.SetAlpha, self, alphaOf(mod, isTargetUnit(unit)))
        settingAlpha = false
    end, function()
        local mod = module()
        return mod ~= nil and mod:IsEnabled()
    end)
end

---@param unitFrame table
---@param alpha number
local function takeAlpha(unitFrame, alpha)
    if alphaTaken[unitFrame] == nil then
        local ok, previous = pcall(unitFrame.GetAlpha, unitFrame)
        alphaTaken[unitFrame] = (ok and type(previous) == "number") and previous or 1
    end

    settingAlpha = true
    pcall(unitFrame.SetAlpha, unitFrame, alpha)
    settingAlpha = false
end

---@param unitFrame table
local function releaseAlpha(unitFrame)
    local previous = alphaTaken[unitFrame]
    if previous == nil then return end
    alphaTaken[unitFrame] = nil

    settingAlpha = true
    pcall(unitFrame.SetAlpha, unitFrame, previous)
    settingAlpha = false
end

local function releaseAllAlpha()
    settingAlpha = true
    for unitFrame, previous in pairs(alphaTaken) do
        pcall(unitFrame.SetAlpha, unitFrame, previous)
    end
    settingAlpha = false
    wipe(alphaTaken)
end

--- État -> clé du réglage d'assombrissement.
---
--- Une table et non une concaténation : cette lecture tourne dix fois par
--- seconde sur chaque plaque affichée, et `state .. "Darkness"` y fabriquerait
--- une chaîne à chaque passage (règle 7).
local DARKNESS_KEY = {
    target   = "targetDarkness",
    other    = "otherDarkness",
    occluded = "occludedDarkness",
}

---@param mod table
---@param state string
---@return number  0 = intacte, 1 = noire
local function darknessOf(mod, state)
    if not mod:Get("visibility") then return 0 end
    return (mod:Get(DARKNESS_KEY[state]) or 0) / 100
end

-- =========================================================================
--  Ce qu'est la créature
-- =========================================================================
-- Il y a eu ici une garde « mythique+ ou raid seulement ». Elle est partie avec
-- la refonte des couleurs : c'est l'**unité** qui décide du traitement — PNJ ou
-- joueur —, pas la zone où on la croise.

--- Les classes qui lancent des sorts.
---
--- **Une créature a une classe, comme un joueur.** C'est la découverte qui a
--- rendu inutile tout ce qu'on avait bâti pour deviner un caster : on retenait
--- les PNJ vus en train d'incanter, on exportait la liste, on l'importait — un
--- mécanisme entier pour une question à laquelle `UnitClassBase` répond du
--- premier coup, dès la première plaque, sans rien avoir appris.
---
--- Les classes retenues sont celles qui lancent l'essentiel de leurs sorts à
--- distance. Paladin et druide en font partie : leurs versions PNJ soignent et
--- foudroient bien plus qu'elles ne frappent, et c'est ce qu'on cherche à
--- repérer — qui interrompre, pas qui porte une arme.
---
--- Une créature sans classe rend `nil` : elle tombe alors en mêlée, ce qui est le
--- bon défaut — la plupart des mobs sans classe cognent.
local CASTER_CLASSES = {
    MAGE    = true,
    PRIEST  = true,
    WARLOCK = true,
    SHAMAN  = true,
    PALADIN = true,
    DRUID   = true,
    EVOKER  = true,
}

--- Niveau **effectif** d'une unité, celui que la mise à l'échelle lui donne.
---
--- Comparer des niveaux bruts ne veut plus rien dire depuis que le monde
--- s'ajuste au joueur : un mob « de niveau 30 » vaut le sien. C'est l'effectif
--- qu'il faut, et il tombe à `nil` ou à une valeur secrète là où le client
--- protège l'information.
---@param unit string
---@return number|nil
local function effectiveLevel(unit)
    local level
    if UnitEffectiveLevel then
        level = UnitEffectiveLevel(unit)
    else
        level = UnitLevel(unit)
    end

    if U.IsSecret(level) or type(level) ~= "number" then return nil end
    return level
end

--- Classement d'une unité parmi les cinq couleurs de PNJ.
---
--- L'ordre des tests est le classement lui-même, et il va du plus rare au plus
--- commun : ce qu'un PNJ **est** prime sur ce qu'il **fait**. Un rare qui
--- incante reste teint en rare — sa rareté est ce qu'on remarque en premier, et
--- c'est aussi ce qui décide de ce qu'on en fait.
---
--- Le rang d'une élite se lit à son **niveau relatif au joueur**, et non à son
--- niveau absolu : à égalité c'est un mob d'élite ordinaire, qu'on classe alors
--- par ce qu'il lance ; au-dessus, c'est un miniboss ou un boss, et son rang
--- prime sur sa classe.
---@param unit string
---@return string|nil  clé de couleur, ou `nil` si l'unité n'en relève pas
local function classify(unit)
    if U.IsTrue(UnitIsPlayer(unit)) then return nil end

    local classification = UnitClassification(unit)
    if U.IsSecret(classification) then return nil end

    if classification == "worldboss" then return "boss" end
    if classification == "rareelite" then return "rareElite" end
    if classification == "rare"      then return "rare" end

    -- Un boss déclaré comme tel, quand le client sait le dire.
    if UnitIsBossMob and U.IsTrue(UnitIsBossMob(unit)) then return "boss" end

    local level = effectiveLevel(unit)

    if classification == "elite" then
        -- Hors échelle, ou au-dessus du joueur : boss ou miniboss, que le joueur
        -- ne distingue pas et qu'on ne sépare donc pas.
        local mine = effectiveLevel("player")
        if level == -1 then return "boss" end
        if level and mine and level > mine then return "boss" end
    end

    local class = UnitClassBase and UnitClassBase(unit)
    if not U.IsSecret(class) and CASTER_CLASSES[class] then return "caster" end

    return "melee"
end

--- Clé de classement -> clé du réglage de couleur.
local NPC_COLOR_KEY = {
    boss      = "bossColor",
    caster    = "casterColor",
    melee     = "meleeColor",
    rare      = "rareColor",
    rareElite = "rareEliteColor",
}

-- =========================================================================
--  Ce que fait la menace
-- =========================================================================

--- Le joueur tient-il le rôle de tank ? Relu à chaque changement de
--- spécialisation, jamais à chaque plaque.
local playerTanks = false

local function refreshRole()
    local api = C_SpecializationInfo

    local index
    if api and api.GetSpecialization then
        index = api.GetSpecialization()
    elseif GetSpecialization then
        index = GetSpecialization()
    end
    if not index then
        playerTanks = false
        return
    end

    local role
    if api and api.GetSpecializationRole then
        role = api.GetSpecializationRole(index)
    elseif GetSpecializationRole then
        role = GetSpecializationRole(index)
    end

    playerTanks = (role == "TANK")
end

--- Clé de couleur de menace, ou `nil` si la menace ne dit rien ici.
---
--- Le client rend un état de 0 à 3, du « ni ne tient ni n'est en tête » au
--- « tient et est en tête ». Ce que cet état **vaut** dépend du rôle, et
--- l'inversion tient en une ligne : pour un tank, l'anomalie croît quand l'état
--- baisse ; pour tous les autres, elle croît quand il monte.
---
--- Deux alertes, et rien pour l'état conforme : quand l'aggro est là où elle
--- doit être, ce sont les couleurs par nature qui parlent — une couleur de
--- « tout va bien » ferait double emploi avec elles.
---
---   · la **bascule** — l'aggro est en train de changer de mains : le tank la
---     sent partir ou la reprend sans l'assurer, le DPS monte et va la prendre ;
---   · le **constat** — elle a changé de mains : perdue pour le tank, prise
---     pour les autres.
---
--- Deux pastilles distinctes pour que chacune puisse un jour avoir sa teinte ;
--- au départ, les deux portent le même rouge.
---@param unit string
---@return string|nil
local function threatKey(unit)
    if not U.IsTrue(UnitCanAttack("player", unit)) then return nil end

    local situation = UnitThreatSituation("player", unit)
    if U.IsSecret(situation) or type(situation) ~= "number" then return nil end

    local wrongness = playerTanks and (3 - situation) or situation
    if wrongness >= 2 then return "threatBadColor" end
    if wrongness >= 1 then return "threatShiftColor" end
    return nil
end

-- =========================================================================
--  Couleurs
-- =========================================================================

--- Couleur rangée en base, ou `nil` si elle n'a pas la forme attendue.
---
--- Une couleur vient du sélecteur du client, donc du disque : elle peut avoir
--- été éditée à la main dans le SavedVariables. On la lit comme on lirait
--- n'importe quelle donnée venue d'ailleurs.
---@param color any
---@return number? r, number? g, number? b
local function rgbOf(color)
    if type(color) ~= "table" then return nil end
    local r, g, b = color.r, color.g, color.b
    if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then return nil end
    return r, g, b
end

--- Couleur de fond d'une barre de vie, avant assombrissement.
---
--- L'ordre est une hiérarchie d'urgence : la menace prime sur tout, parce
--- qu'elle dit ce qui est en train de mal tourner ; le classement du PNJ vient
--- ensuite, parce qu'il dit sur quoi taper ; la couleur du client ferme la
--- marche, parce qu'elle ne dit que l'hostilité, ce qu'on sait déjà.
---@param mod table
---@param unit string
---@return number r, number g, number b
local function healthColor(mod, unit)
    -- La menace ne parle que pour alerter — bascule en cours ou aggro changée
    -- de mains — et l'alerte prime sur tout. Conforme, elle se tait : la nature
    -- du PNJ colore la barre.
    if LIVE.threat and mod:Get("threatColors") then
        local key = threatKey(unit)
        if key then
            local r, g, b = rgbOf(mod:Get(key))
            if r and g and b then return r, g, b end
        end
    end

    -- **C'est l'unité qui décide, pas la zone.** Un adversaire joueur est du
    -- PvP où qu'on soit, un PNJ est du PvE : chaque famille a son réglage.
    if LIVE.colors then
        if U.IsTrue(UnitIsPlayer(unit)) then
            if mod:Get("pvpClassColor") then
                local _, class = UnitClass(unit)
                if not U.IsSecret(class) then
                    local color = T.ClassColor(class)
                    if color then return color:GetRGB() end
                end
            end
        elseif mod:Get("npcColors") then
            local key = NPC_COLOR_KEY[classify(unit) or ""]
            if key then
                local r, g, b = rgbOf(mod:Get(key))
                if r and g and b then return r, g, b end
            end
        end
    end

    -- La couleur du client, demandée au client : c'est exactement celle qu'il
    -- poserait, réaction comprise, et elle suit ses propres réglages de couleurs
    -- de classe sans qu'on ait à les relire.
    if type(UnitSelectionColor) == "function" then
        local r, g, b = UnitSelectionColor(unit, true)
        if type(r) == "number" and not U.IsSecret(r) then return r, g, b end
    end

    return T.COLOR.WHITE:GetRGB()
end

--- Couleur d'un nom, avant assombrissement.
---
--- Le blanc pour tout le monde, la couleur de classe pour un joueur : ce sont
--- les deux teintes que le client emploie lui-même. On les repose plutôt que de
--- relire la sienne, parce qu'une lecture suivie d'une écriture s'empilerait sur
--- elle-même passage après passage — l'assombrissement se multiplierait avec
--- lui-même jusqu'au noir.
---@param unit string
---@return number r, number g, number b
local function nameColor(unit)
    if U.IsTrue(UnitIsPlayer(unit)) then
        local _, class = UnitClass(unit)
        if not U.IsSecret(class) then
            local color = T.ClassColor(class)
            if color then return color:GetRGB() end
        end
    end
    return T.COLOR.WHITE:GetRGB()
end

-- =========================================================================
--  Rendre un ancrage qu'on n'a pas le droit de lire
-- =========================================================================
-- Deux régions sont déplacées : le marqueur de ciblage et le nom des alliés. La
-- façon évidente de les rendre serait de relever leurs points avant d'y toucher
-- et de les reposer ensuite. **Elle est interdite.**
--
--     Frame:GetPoint(): Action[FrameMeasurement] failed
--     because[Can't measure restricted regions]
--
-- Les régions d'une barre d'infos sont *restreintes* : le client refuse d'en
-- laisser lire l'ancrage à un addon, parce qu'une position relative renseigne
-- sur ce qu'il protège. `GetWidth` passe encore, `GetPoint` non — et sans les
-- points, il n'y a rien à reposer.
--
-- La seconde idée était de lui demander de refaire sa mise en page —
-- `UpdateNamePlateOptions` réapplique ses options à chaque plaque, et lui seul
-- sait où il mettait le marqueur. **Elle est interdite aussi**, pour une raison
-- entièrement différente et plus grave : appeler ce chemin depuis notre code le
-- fait s'exécuter teinté, et il y manipule des valeurs secrètes (voir plus haut,
-- « On n'appelle pas le pilote de barres d'infos »).
--
-- Les deux portes sont donc fermées. On ne sait ni relever un ancrage, ni faire
-- reposer le sien au client. **Il n'y a aujourd'hui aucune façon réversible de
-- déplacer une région d'une barre d'infos**, et la règle 6 n'admet pas qu'on
-- déplace ce qu'on ne saura pas rendre.
--
-- C'est pour cela — et pas par prudence de méthode — que `marker` et `allies`
-- sont à `false` dans `LIVE`. Ce qui reste à trouver avant de les rallumer :
-- une troisième voie qui ne lise rien et n'appelle rien. Le seul candidat connu
-- est de reposer un ancrage **calculé** plutôt que relevé, en acceptant qu'il
-- soit approximatif si le client change sa disposition. Ça se décide, ça ne se
-- suppose pas.
--
-- Ce qui suit reste écrit et fonctionnel pour le jour où la question sera
-- tranchée ; rien de tout cela ne s'exécute tant que les deux sections dorment.

-- =========================================================================
--  Marqueur de ciblage
-- =========================================================================
-- Il est **centré sur le coin haut-droit** de la barre de vie, et non posé à
-- côté d'elle : une vignette calée dans l'angle appartient visiblement à la
-- plaque, une vignette flottant au-dessus appartient à ce qu'il y a derrière.
-- Les deux décalages partent de là, et les valeurs nulles sont donc déjà une
-- position juste.

---@param unitFrame table
---@return table|nil
local function markerOf(unitFrame)
    local marker = unitFrame.RaidTargetFrame
    if type(marker) == "table" and type(marker.SetPoint) == "function" then return marker end
    return nil
end

---@param mod table
---@param unitFrame table
local function placeMarker(mod, unitFrame)
    -- Éteint : on ne fait rien. Le marqueur a déjà retrouvé sa place, remise par
    -- le client au moment où l'interrupteur s'est éteint — voir plus haut.
    if not (LIVE.marker and mod:Get("marker")) then return end

    local marker = markerOf(unitFrame)
    if not marker then return end

    local size = mod:Get("markerSize")
    pcall(marker.SetSize, marker, size, size)

    -- La vignette suit le cadre qui la porte. Sans cela, agrandir le marqueur
    -- agrandirait sa boîte et laisserait l'icône à sa taille, au coin.
    local icon = marker.RaidTargetIcon
    if type(icon) == "table" and type(icon.SetAllPoints) == "function" then
        pcall(icon.ClearAllPoints, icon)
        pcall(icon.SetAllPoints, icon, marker)
    end

    local anchorTo = healthBarOf(unitFrame) or unitFrame
    pcall(marker.ClearAllPoints, marker)
    pcall(marker.SetPoint, marker, "CENTER", anchorTo, "TOPRIGHT",
          mod:Get("markerX"), mod:Get("markerY"))
end

-- =========================================================================
--  Les réglages du client, repris dans la page
-- =========================================================================
-- La page porte deux familles de contrôles, et elles ne fonctionnent pas de la
-- même façon.
--
-- Ceux-ci sont **les réglages du jeu**, repris ici pour n'avoir plus qu'un
-- endroit où aller. On ne les possède pas : le CVar *est* le rangement, on le lit
-- et on l'écrit en direct. Aucune copie en base, aucune réapplication, rien à
-- rendre quand le module s'éteint.
--
-- C'est ce qui permet de les changer indifféremment ici ou dans le menu du jeu.
-- Une copie de notre côté supposerait de la reposer, donc de courir après le
-- menu de Blizzard à chaque fois qu'il l'ouvre — c'est précisément la bagarre
-- qu'on refuse (voir `takeCVar`, qui s'en garde pour les rares CVars qu'on
-- possède vraiment).
--
-- Certains de ces réglages sont **refusés en combat** par le client. Le refus est
-- silencieux : la ligne est donc grisée tant qu'on est engagé, et le geste
-- expliqué plutôt qu'avalé.

--- Accès en lecture/écriture directe à un CVar booléen.
---@param name string
---@return fun(): boolean get, fun(value: boolean) set
local function cvarToggle(name)
    return function()
        return U.GetCVar(name) == "1"
    end, function(value)
        if InCombatLockdown() then return end
        U.SetCVar(name, value and "1" or "0")
    end
end

--- Idem pour un CVar numérique.
---
--- `factor` traduit entre ce que le CVar range et ce que le curseur montre. Le
--- client garde ses multiplicateurs — une taille d'aura vaut `1.2` chez lui —
--- mais un curseur qui affiche « 1,20 » ne se lit pas : on montre 120 %, et la
--- traduction tient en une multiplication. C'est le seul endroit où elle a lieu,
--- de sorte que ni le curseur ni le CVar n'ont à connaître l'autre.
---@param name string
---@param factor? number
---@return fun(): number get, fun(value: number) set
local function cvarSlider(name, factor)
    factor = factor or 1

    return function()
        return (tonumber(U.GetCVar(name)) or 0) * factor
    end, function(value)
        if InCombatLockdown() then return end
        U.SetCVar(name, value / factor)
    end
end

--- Un réglage du client se grise en combat : il ne prendrait pas.
local function inCombat()
    return InCombatLockdown() and true or false
end

--- Les quatre curseurs d'une rangée d'auras : taille, décalages, écart. Une
--- fabrique parce qu'ils sont identiques pour les trois rangées — douze
--- descripteurs recopiés seraient douze occasions de diverger.
---@param prefix string  "auraImp" | "auraDot" | "auraCc"
---@return table  liste de descripteurs
local function auraSliders(prefix)
    local function slider(suffix, text, tooltip, min, max)
        return {
            type     = "slider",
            key      = prefix .. suffix,
            text     = text,
            tooltip  = tooltip,
            min      = min,
            max      = max,
            step     = 1,
            indent   = true,
            disabled = AURAS_PAUSED and aurasPaused or requires("ownAuras"),
            disabledReason = AURAS_PAUSED and L["Auras paused"] or nil,
        }
    end

    -- Taille et décalages seulement : l'écart entre deux icônes garde son
    -- défaut — celui du client — sans curseur. Trois rangées à quatre curseurs
    -- faisaient une page de réglages qu'on ne règle jamais.
    return {
        slider("Size", L["Own aura size"], L["Own aura size tip"], 12, 50),
        slider("X",    L["Aura offset X"], L["Aura offset tip"], -60, 60),
        slider("Y",    L["Aura offset Y"], L["Aura offset tip"], -60, 60),
    }
end

-- -------------------------------------------------------------------------
--  Le calibre du client et nos pixels
-- -------------------------------------------------------------------------
-- Le client range la taille de ses plaques en cinq crans ; nous la posons en
-- pixels. Les deux décident de la même chose, et le laisser ainsi donnerait deux
-- curseurs qui se contredisent — on règle une largeur au pixel près, puis un cran
-- de calibre la balaie.
--
-- Quand notre réglage est allumé, il **grise** la ligne du client, et rien de
-- plus : on ne touche pas à sa valeur.
--
-- On l'avait d'abord forcée à un, en se disant qu'un calibre neutre laissait le
-- champ libre à nos pixels. C'était un réglage écrasé sans qu'on l'ait demandé —
-- et rendu, certes, mais seulement à qui pense à décocher. Griser suffit à
-- écarter la contradiction : le calibre reste celui que le joueur a choisi, il
-- cesse simplement d'être modifiable tant que nous tenons la taille.

---@return boolean
local function sizeTaken()
    if InCombatLockdown() then return true end
    local mod = module()
    return mod ~= nil and mod:Get("resize") == true
end

---@return string
local function sizeReason()
    if InCombatLockdown() then return L["Cannot change in combat"] end
    return L["Taken over by the addon"]
end

local SIZE_LOCK = { disabled = sizeTaken, reason = sizeReason }

--- Premier nom de CVar que le client connaît, parmi ceux proposés.
---
--- Blizzard renomme ses réglages en les refondant, et l'ancien nom **survit sans
--- rien piloter** : `nameplateShowFriends` répond encore, mais c'est
--- `nameplateShowFriendlyPlayers` qui décide. Un contrôle branché sur le premier
--- s'affiche donc décoché quoi qu'on fasse, et ne synchronise rien — c'est très
--- exactement le symptôme observé.
---
--- On demande donc au client lequel il connaît, plutôt que de choisir : test de
--- capacité, jamais de numéro de patch (règle 1). Un CVar inconnu rend `nil`, un
--- CVar connu rend au moins une chaîne vide.
---
--- Rend `nil` si aucun candidat n'existe. Ce n'est pas un échec à rattraper :
--- c'est ce qui fait **disparaître** le contrôle au lieu de l'afficher mort (voir
--- `blizzToggle`).
---@param ... string  noms candidats, du plus récent au plus ancien
---@return string|nil
local function pickCVar(...)
    for i = 1, select("#", ...) do
        local name = select(i, ...)
        if U.GetCVar(name) ~= nil then return name end
    end
    return nil
end

-- -------------------------------------------------------------------------
--  Les réglages à cases multiples
-- -------------------------------------------------------------------------
-- Le client range plusieurs de ses choix dans un **champ de bits** : un seul
-- CVar porte toutes les cases, et chaque case est un membre d'une énumération.
-- C'est le cas de la superposition des plaques, de ce qui s'affiche sur une
-- barre de vie, et de ce qui s'affiche sur une barre de sorts.
--
-- On ne nomme donc pas les cases : **on demande à l'énumération ce qu'elle
-- contient**, et on rend une ligne par membre. Trois conséquences, toutes
-- bonnes : rien à deviner, une case de plus apparaît d'elle-même le jour où
-- Blizzard en ajoute une, et rien ne casse le jour où il en retire une.
--
-- Le prix est l'intitulé : à défaut de traduction connue, une case porte le nom
-- que l'énumération lui donne, en anglais. Une ligne dans les fichiers de locale
-- suffit à le franciser, et c'est écrit une fois qu'on a vu ce que le client
-- publie réellement.

--- Intitulés traduits des membres qu'on sait nommer.
---
--- Les deux du premier groupe sont **certains** : le client les publie sous ces
--- noms-là. Les autres sont des paris raisonnables sur l'orthographe retenue par
--- Blizzard, et un pari perdu ne casse rien — la case porte alors le nom brut de
--- l'énumération, en anglais, et une ligne de locale suffira à le corriger une
--- fois qu'on l'aura lu à l'écran.
local STACK_LABELS = {
    Enemy    = L["Stack enemy nameplates"],
    Friendly = L["Stack friendly nameplates"],
}

local INFO_LABELS = {
    CurrentHealthPercent = L["Health percentage"],
    CurrentHealthValue   = L["Health value"],
    RarityIcon           = L["Rarity icon"],
}

local CAST_INFO_LABELS = {
    SpellName               = L["Spell name"],
    SpellIcon               = L["Spell icon"],
    SpellTarget             = L["Spell target"],
    HighlightImportantCasts = L["Highlight important casts"],
    HighlightWhenCastTarget = L["Highlight casts on you"],
}

--- Les trois rangées d'auras partagent leur vocabulaire : ce sont les mêmes
--- catégories, appliquées à trois familles d'unités. Une seule table, donc.
local AURA_LABELS = {
    Buffs         = L["Buffs"],
    Debuffs       = L["Debuffs"],
    CrowdControl  = L["Crowd control"],
    LossOfControl = L["Loss of control"],
}

local THREAT_LABELS = {
    Progressive    = L["Threat progressive"],
    Flash          = L["Threat flash"],
    HealthBarColor = L["Threat health bar color"],
}

local SIMPLIFIED_LABELS = {
    Minion         = L["Minions"],
    MinusMob       = L["Minor units"],
    FriendlyPlayer = L["Friendly players"],
    FriendlyNpc    = L["Friendly NPCs"],
}

--- Les six styles de barre d'infos du client, relevés dans son énumération.
---
--- La correspondance n'est pas devinée : les valeurs vont de zéro à cinq dans le
--- même ordre que les intitulés de sa liste déroulante, et le sens de chaque nom
--- le confirme — « mise en avant de la vie » est la barre de vie large, « mise en
--- avant de l'incantation » est celle qui grossit les sorts.
---
--- Les intitulés sont les siens, repris mot pour mot : c'est la même liste vue de
--- deux endroits, et deux vocabulaires pour un seul réglage rendraient l'un des
--- deux faux.
local STYLE_LABELS = {
    Modern      = L["Style modern"],
    Thin        = L["Style thin"],
    Block       = L["Style block"],
    HealthFocus = L["Style health focus"],
    CastFocus   = L["Style cast focus"],
    Legacy      = L["Style legacy"],
}

--- Un champ de bits se lit et s'écrit par index, pas comme un nombre.
---@param cvar string
---@param index number
---@return fun(): boolean get, fun(value: boolean) set
local function bitfieldToggle(cvar, index)
    return function()
        if not (C_CVar and C_CVar.GetCVarBitfield) then return false end
        local ok, value = pcall(C_CVar.GetCVarBitfield, cvar, index)
        return ok and value == true
    end, function(value)
        if InCombatLockdown() then return end
        if not (C_CVar and C_CVar.SetCVarBitfield) then return end
        pcall(C_CVar.SetCVarBitfield, cvar, index, value and true or false)
    end
end

--- Membres d'une énumération, triés par valeur : `pairs` rend les clés dans un
--- ordre imprévisible, et l'ordre des lignes doit être celui du client.
---
--- **`None` est écarté.** Ce n'est pas un choix parmi les autres, c'est l'absence
--- de choix : sur une liste de cases, elle est déjà exprimée en les décochant
--- toutes, et sur une liste déroulante elle double une entrée qui ne veut rien
--- dire. Une case « aucun » à côté de trois cases cochables se lit comme un
--- quatrième réglage, et laisse croire qu'on peut la cocher *avec* les autres.
---@param enum table|nil
---@return table[]  { { name = , value = }, ... }
local function enumMembers(enum)
    local members = {}
    if type(enum) ~= "table" then return members end

    for name, value in pairs(enum) do
        if type(value) == "number" and name ~= "None" then
            members[#members + 1] = { name = name, value = value }
        end
    end
    table.sort(members, function(a, b) return a.value < b.value end)

    return members
end

--- Liste déroulante branchée sur un CVar numérique, dont les choix sont ceux
--- d'une énumération du client.
---@param cvar string
---@param enum table|nil
---@param labels table<string, string>
---@param text string
---@param tooltip string
---@return table
local function enumDropdown(cvar, enum, labels, text, tooltip)
    if U.GetCVar(cvar) == nil then return {} end

    local members = enumMembers(enum)
    if #members == 0 then return {} end

    local values = {}
    for i = 1, #members do
        values[i] = {
            value = members[i].value,
            label = labels[members[i].name] or members[i].name,
        }
    end

    return {
        type    = "dropdown",
        text    = text,
        tooltip = tooltip,
        values  = values,
        get     = function() return tonumber(U.GetCVar(cvar)) end,
        set     = function(value)
            if InCombatLockdown() then return end
            U.SetCVar(cvar, value)
        end,
        disabled = inCombat,
        disabledReason = L["Cannot change in combat"],
    }
end

--- Une ligne par membre d'une énumération, triées par valeur pour que l'ordre
--- des cases soit celui du client et non celui, imprévisible, de `pairs`.
---@param cvar string
---@param enum table|nil
---@param labels table<string, string>  nom du membre -> intitulé traduit
---@param tooltip string
---@param lock? table  { disabled = fun(): boolean, reason = fun(): string }
---@return table  liste de descripteurs
local function bitfieldGroup(cvar, enum, labels, tooltip, lock)
    local rows = {}
    if U.GetCVar(cvar) == nil then return rows end

    local members = enumMembers(enum)

    for i = 1, #members do
        local member  = members[i]
        local get, set = bitfieldToggle(cvar, member.value)
        rows[#rows + 1] = {
            type    = "toggle",
            text    = labels[member.name] or member.name,
            tooltip = tooltip,
            get     = get,
            set     = set,
            disabled = lock and lock.disabled or inCombat,
            disabledReason = lock and lock.reason or L["Cannot change in combat"],
        }
    end

    return rows
end

--- Descripteur d'une case à cocher branchée sur un CVar.
---
--- **Un contrôle qui n'a rien à piloter ne s'affiche pas.** Si le client ne
--- connaît pas ce CVar, on rend une liste vide, que la construction de la page
--- absorbe sans rien montrer.
---
--- C'est la leçon de cette page, payée quatre fois : `NamePlateVerticalScale`,
--- `SetNamePlateEnemySize`, `nameplateInfo`, `nameplateShowFriends`. Chaque fois,
--- le contrôle s'affichait normalement et ne pilotait rien — et rien ne le
--- disait, ni à l'écran ni dans les erreurs. Une case morte est pire qu'une case
--- absente : elle se coche, et elle ment.
---
--- La vérification a lieu au chargement, ce qui suffit : les CVars du client sont
--- lus avant les addons, et aucun n'apparaît en cours de session.
---@param name string|nil
---@param text string
---@param tooltip? string
---@param indent? boolean  sous-option de la ligne qui précède
---@return table
local function blizzToggle(name, text, tooltip, indent)
    if not name or U.GetCVar(name) == nil then return {} end

    local get, set = cvarToggle(name)
    return {
        type    = "toggle",
        text    = text,
        tooltip = tooltip,
        indent  = indent,
        get     = get,
        set     = set,
        disabled = inCombat,
        disabledReason = L["Cannot change in combat"],
    }
end

--- Descripteur d'une glissière branchée sur un CVar.
---@param name string
---@param text string
---@param tooltip string
---@param bounds table  { min, max, step, decimals, factor }
---@param lock? table   { disabled = fun(): boolean, reason = fun(): string }
---@return table
local function blizzSlider(name, text, tooltip, bounds, lock)
    if not name or U.GetCVar(name) == nil then return {} end

    local get, set = cvarSlider(name, bounds.factor)
    return {
        type     = "slider",
        text     = text,
        tooltip  = tooltip,
        min      = bounds.min,
        max      = bounds.max,
        step     = bounds.step,
        decimals = bounds.decimals,
        get      = get,
        set      = set,
        disabled = lock and lock.disabled or inCombat,
        disabledReason = lock and lock.reason or L["Cannot change in combat"],
    }
end

-- =========================================================================
--  Peinture
-- =========================================================================

---@param mod table
---@param plate table
---@param unit string
local function paint(mod, plate, unit)
    -- Aucune section qui touche aux plaques n'est livrée : il n'y a rien à
    -- peindre, et la question ne se pose même pas.
    if not needsPlates() then return end

    local unitFrame = unitFrameOf(plate)
    if not unitFrame then return end
    -- La plaque personnelle est celle du joueur, posée à ses pieds : ni cible,
    -- ni menace, ni classement. On la laisse au client.
    if U.IsTrue(UnitIsUnit(unit, "player")) then return end

    local isTarget = isTargetUnit(unit)
    local state    = stateOf(mod, plate, isTarget)
    local darkness = darknessOf(mod, state)
    paintedState[plate] = state

    if LIVE.visibility then
        -- Le hook se pose réglage éteint comme allumé, pour la même raison que
        -- celui de la hauteur : il ne fait rien tant que la case ne l'autorise
        -- pas, et le poser plus tard voudrait dire attendre qu'une plaque
        -- repasse par ici après le clic.
        hookAlpha(unitFrame)
    end

    if LIVE.visibility and mod:Get("visibility") then
        takeAlpha(unitFrame, alphaOf(mod, isTarget))
    else
        releaseAlpha(unitFrame)
    end

    local bar = healthBarOf(unitFrame)
    if bar and type(bar.SetStatusBarColor) == "function" then
        local r, g, b = healthColor(mod, unit)
        pcall(bar.SetStatusBarColor, bar, T.Darken(r, g, b, darkness))
    end

    local name = unitFrame.name
    if type(name) == "table" and type(name.SetTextColor) == "function" then
        local r, g, b = nameColor(unit)
        pcall(name.SetTextColor, name, T.Darken(r, g, b, darkness))
    end

    applyBarHeight(mod, unitFrame)
    applyCastSize(mod, unitFrame)
    applyCastPreview(mod, unitFrame)
    applyOwnAuras(mod, unitFrame, unit)
    applyTextSize(mod, unitFrame)
    placeMarker(mod, unitFrame)
end

---@param mod table
local function paintAll(mod)
    for unit, plate in pairs(plates) do
        paint(mod, plate, unit)
    end
end

--- Défait ce que le module a **déplacé ou masqué** sur une plaque, et rien
--- d'autre.
---
--- C'est ce qu'il faut faire quand une plaque part au recyclage : le client la
--- remontera lui-même en la donnant à l'adversaire suivant — ancrages et tailles
--- compris, puisque c'est lui qui les pose — mais il ne relèvera pas une opacité
--- qu'on a baissée. Il ne sait pas qu'on y a touché : celle-là n'est pas de la
--- mise en page.
---@param plate table
---@return table|nil unitFrame
local function detach(plate)
    paintedState[plate] = nil

    local unitFrame = unitFrameOf(plate)
    if not unitFrame then return nil end

    releaseAlpha(unitFrame)

    -- Les rangées d'auras ne survivent pas au recyclage : le prochain occupant
    -- de cette plaque hériterait des auras du précédent le temps d'une
    -- repeinture.
    local rows = auraRows[unitFrame]
    if rows then
        for g = 1, #AURA_GROUPS do
            local row = rows[AURA_GROUPS[g].key]
            if row then row:Hide() end
        end
        rows._filled = nil
    end

    return unitFrame
end

--- Rend une plaque au client, couleurs comprises.
---
--- On ne repose pas une teinte : on **rappelle ses fonctions**. Lui seul sait ce
--- qu'il aurait dessiné là — la réaction, la couleur de classe si le joueur l'a
--- demandée, le gris d'une unité morte.
---
--- Uniquement sur une plaque qui montre encore quelqu'un : ces fonctions lisent
--- l'unité du cadre, et une plaque qui vient d'être retirée n'en a plus.
---@param plate table
local function release(plate)
    local unitFrame = detach(plate)
    if not (unitFrame and unitFrame.unit) then return end

    if type(CompactUnitFrame_UpdateHealthColor) == "function" then
        BUI.safecall(CompactUnitFrame_UpdateHealthColor, unitFrame)
    end
    if type(CompactUnitFrame_UpdateName) == "function" then
        BUI.safecall(CompactUnitFrame_UpdateName, unitFrame)
    end
end

local function releaseAll()
    for _, plate in pairs(plates) do
        release(plate)
    end
    wipe(paintedState)
    releaseAllAlpha()
    restoreBarHeights()
    restoreCastSizes()
    restoreTextSizes()
end

-- =========================================================================
--  Le passage qui guette l'occultation
-- =========================================================================
-- **Le seul endroit de l'addon qui sonde au lieu d'écouter**, et il ne sonde
-- qu'une chose : l'opacité que le moteur vient de poser. Rien ne l'annonce, et
-- il n'y a pas d'autre chemin (voir `isOccluded`).
--
-- Il ne repeint que les plaques dont l'**état a changé** : passer derrière un
-- mur est rare à l'échelle d'un dixième de seconde, et repeindre quarante
-- plaques dix fois par seconde pour n'en changer aucune serait exactement le
-- coût que la règle 7 interdit. Tout le reste — la couleur qui suit les points
-- de vie, le nom que le client réécrit — est reposé par les hooks, au moment où
-- il écrit.

--- Passage périodique, `nil` quand le module est éteint.
local ticker

---@param mod table
local function sweep(mod)
    for unit, plate in pairs(plates) do
        local state = stateOf(mod, plate, isTargetUnit(unit))
        if paintedState[plate] ~= state then
            paint(mod, plate, unit)
        end
    end
end

---@param mod table
local function startTicker(mod)
    if ticker then return end
    ticker = C_Timer.NewTicker(T.TIMING.NAMEPLATE, function() sweep(mod) end)
end

local function stopTicker()
    if not ticker then return end
    ticker:Cancel()
    ticker = nil
end

-- =========================================================================
--  Hooks : on repeint quand le client peint
-- =========================================================================
-- Deux fonctions, et ce sont les deux passages obligés de toutes les barres de
-- nom : la couleur de la barre de vie et le texte du nom. S'y brancher, c'est
-- écrire dans le même souffle que lui — il n'y a aucun délai à rattraper, et
-- aucune minuterie à régler pour repasser derrière.
--
-- `U.GuardedHook` est le seul motif autorisé (règle 6) : posé une fois,
-- définitivement, il devient inerte dès que le module s'éteint.

--- Le cadre que le client vient de peindre est-il une de nos plaques ?
---@param unitFrame table
---@return string|nil unit
local function trackedUnit(unitFrame)
    if type(unitFrame) ~= "table" then return nil end
    local unit = unitFrame.unit or unitFrame.displayedUnit
    if type(unit) ~= "string" then return nil end
    if not plates[unit] then return nil end
    return unit
end

--- Pas de garde de récursion, et ce n'est pas un oubli : notre peinture ne pose
--- que des couleurs, une opacité et des ancrages — aucune de ces écritures ne
--- rappelle les deux fonctions coiffées ici. Le seul endroit qui les rappelle
--- est `release`, et il ne tourne qu'une fois le module déjà éteint, donc une
--- fois le hook déjà inerte. Un drapeau de plus n'aurait rien gardé, et resterait
--- levé pour toujours le jour où une écriture lèverait au milieu.
local function hookPainting()
    local guard = function()
        local mod = module()
        return mod ~= nil and mod:IsEnabled()
    end

    local function repaint(unitFrame)
        local unit = trackedUnit(unitFrame)
        if not unit then return end

        local mod = module()
        if mod then paint(mod, plates[unit], unit) end
    end

    if type(CompactUnitFrame_UpdateHealthColor) == "function" then
        U.GuardedHook("CompactUnitFrame_UpdateHealthColor", repaint, guard)
    end
    if type(CompactUnitFrame_UpdateName) == "function" then
        U.GuardedHook("CompactUnitFrame_UpdateName", repaint, guard)
    end
end


-- =========================================================================
--  Application d'ensemble
-- =========================================================================

---@param mod table
local function applyAll(mod)
    applySize(mod)
    applyAlpha(mod)
    paintAll(mod)
end

--- Les deux groupes de réglages qui demandent autre chose qu'un repassage : ceux
--- qui écrivent un CVar. Tout ce qui n'est pas listé ici se contente d'être
--- repeint, ce qui est le cas de la quasi-totalité de la page.
local SIZE_KEYS  = { resize = true, width = true, height = true,
                     resizeText = true, textSize = true,
                     resizeCastText = true, castTextSize = true,
                     previewMode = true,
                     resizeCast = true, castHeight = true }
local ALPHA_KEYS = { visibility = true, targetAlpha = true, otherAlpha = true,
                     occludedAlpha = true }

--- Les CVars que chaque interrupteur rend quand on l'éteint. Déclarés ici plutôt
--- que construits dans la fonction : une table bâtie à chaque clic est une table
--- de trop.
local ALPHA_CVARS = { CVAR.OCCLUDED }

--- Rend les CVars d'un groupe et oublie ce qu'on en savait : le groupe n'est
--- plus à nous, et le reprendre plus tard le relèvera à nouveau.
---@param names string[]
local function giveBack(names)
    for i = 1, #names do
        local name = names[i]
        local saved = savedCVars[name]
        if saved and saved ~= false then U.SetCVar(name, saved) end
        savedCVars[name] = nil
    end
end

--- Rend la taille : la hauteur à chaque barre épaissie, la largeur aux plaques.
--- Le calibre du client, lui, n'a jamais été pris — il n'y a rien à lui rendre.
local function giveBackSize()
    restoreBarHeights()
    restorePlateWidth()
end

-- =========================================================================
--  Déclaration du module
-- =========================================================================

BUI:RegisterModule(MODULE, {
    title    = L["Nameplates"],
    category = "Interface",
    -- La place qu'occupait l'annonce de la « barre d'infos », juste après les
    -- cadres d'unités : c'est la même chose vue de deux endroits, le cadre de la
    -- cible et sa plaque.
    order    = 15,

    defaults = {
        -- Taille, en pixels. Les valeurs de départ sont celles du client : une
        -- barre de onze pixels dans une boîte de cent vingt-huit. Allumer
        -- l'interrupteur sans toucher aux curseurs rend donc les plaques telles
        -- que le jeu les pose — au détail près de l'échelle horizontale, que le
        -- joueur a pu régler ailleurs et qu'on remplace en prenant la main.
        resize = false,
        width  = T.SIZE.PLATE_W,
        height = T.SIZE.PLATE_BAR_H,

        -- Le corps des textes a son propre interrupteur, et pas par goût de la
        -- symétrie : la taille de la plaque et celle de ce qu'on y lit ne se
        -- règlent pas au même moment. On élargit une plaque une fois pour toutes ;
        -- on retouche le corps du texte en le lisant de loin, et on veut pouvoir
        -- l'annuler sans rendre du même geste la taille qu'on avait trouvée.
        resizeText = false,
        textSize   = T.PlateConstant("HEALTH_BAR_FONT_HEIGHT", T.SIZE.PLATE_TEXT),

        -- Le corps de la barre de sorts est le sien : le client ecrit plus petit
        -- dessus, et partir de sa valeur rend l'interrupteur sans effet tant
        -- qu'on n'a pas bouge le curseur.
        -- L'aperçu de la barre de sorts. Il ne règle rien : il montre. Il survit
        -- au `/reload` comme les autres réglages, ce qui est voulu — on recharge
        -- précisément pour juger — mais il se remarque, et on l'éteint.
        previewMode = false,

        resizeCastText = false,
        castTextSize   = T.PlateConstant("CAST_BAR_FONT_HEIGHT", T.SIZE.PLATE_CAST_TEXT),

        -- La rangée d'auras de l'addon. Les mesures de départ sont celles du
        -- client — allumer sans toucher aux curseurs donne des auras de la
        -- taille qu'on connaît. Les décalages de départ donnent le souffle
        -- minimal entre une rangée et la barre qu'elle borde.
        ownAuras    = false,

        auraImpSize = T.PlateConstant("AURA_ITEM_HEIGHT", T.SIZE.PLATE_AURA),
        auraImpGap  = T.PlateConstant("DEBUFF_PADDING", T.SIZE.PLATE_AURA_GAP),
        auraImpX    = -4,
        auraImpY    = 0,

        auraDotSize = T.PlateConstant("AURA_ITEM_HEIGHT", T.SIZE.PLATE_AURA),
        auraDotGap  = T.PlateConstant("DEBUFF_PADDING", T.SIZE.PLATE_AURA_GAP),
        auraDotX    = 0,
        auraDotY    = 4,

        auraCcSize  = T.PlateConstant("AURA_ITEM_HEIGHT", T.SIZE.PLATE_AURA),
        auraCcGap   = T.PlateConstant("DEBUFF_PADDING", T.SIZE.PLATE_AURA_GAP),
        auraCcX     = 4,
        auraCcY     = 0,

        resizeCast = false,
        castHeight = T.SIZE.PLATE_CAST_BAR_H,


        marker     = false,
        markerSize = 20,
        markerX    = 0,
        markerY    = 0,

        -- Opacités : celles du client, pour la même raison. L'occultée est le
        -- produit des deux valeurs qu'il emploie — la moitié pour un non-ciblé,
        -- puis les deux cinquièmes de celle-là.
        visibility       = false,
        targetAlpha      = 100,
        otherAlpha       = 50,
        occludedAlpha    = 20,
        targetDarkness   = 0,
        otherDarkness    = 0,
        occludedDarkness = 0,

        npcColors      = false,
        pvpClassColor  = false,
        bossColor      = T.ColorTable(T.COLOR.PLATE.BOSS),
        casterColor    = T.ColorTable(T.COLOR.PLATE.CASTER),
        meleeColor     = T.ColorTable(T.COLOR.PLATE.MELEE),
        rareColor      = T.ColorTable(T.COLOR.PLATE.RARE),
        rareEliteColor = T.ColorTable(T.COLOR.PLATE.RARE_ELITE),


        threatColors     = false,
        threatShiftColor = T.ColorTable(T.COLOR.PLATE.THREAT_BAD),
        threatBadColor   = T.ColorTable(T.COLOR.PLATE.THREAT_BAD),
    },

    options = liveOptions({
        -- ------------------------------------------------------------------
        --  Ce qui appartient au jeu
        -- ------------------------------------------------------------------
        { section = "blizzard" },
        { type = "header",      text = L["Blizzard settings"] },
        { type = "description", text = L["Blizzard settings notice"] },

        blizzToggle("nameplateShowAll",
            L["Always show nameplates"], L["Always show nameplates tip"]),
        blizzToggle("nameplateShowEnemies",
            L["Enemy nameplates"], L["Enemy nameplates tip"]),
        -- Les deux suivantes ne veulent rien dire sans celle du dessus : elles
        -- affinent l'affichage des ennemis, elles ne s'y ajoutent pas. La page le
        -- dit par un retrait et un corps plus petit.
        blizzToggle("nameplateShowEnemyMinions",
            L["Enemy minions"], L["Enemy minions tip"], true),
        blizzToggle("nameplateShowEnemyMinus",
            L["Enemy minor units"], L["Enemy minor units tip"], true),
        blizzToggle(pickCVar("nameplateShowFriendlyPlayers", "nameplateShowFriends"),
            L["Friendly player nameplates"], L["Friendly player nameplates tip"]),
        blizzToggle(pickCVar("nameplateShowFriendlyPlayerMinions", "nameplateShowFriendlyMinions"),
            L["Friendly minions"], L["Friendly minions tip"], true),
        blizzToggle(pickCVar("nameplateShowFriendlyNpcs", "nameplateShowFriendlyNPCs"),
            L["Friendly NPC nameplates"], L["Friendly NPC nameplates tip"]),

        -- Le client nomme cette option `UNIT_NAMEPLATES_SHOW_OFFSCREEN` dans ses
        -- chaînes affichées ; son CVar en découle, à la casse près — et la casse
        -- n'a pas d'importance, les CVars ne la distinguent pas. Les deux graphies
        -- sont proposées, et si aucune ne répond la ligne ne s'affiche pas.
        blizzToggle(pickCVar("nameplateShowOffscreen", "nameplateShowOffScreen",
                             "nameplateShowOffScreenUnits"),
            L["Show off-screen nameplates"], L["Show off-screen nameplates tip"]),

        -- L'ordre suit celui du menu du jeu, et ce n'est pas un détail : c'est le
        -- même réglage vu de deux endroits, et deux ordres différents obligeraient
        -- à chercher deux fois.
        { type = "header", text = L["Stacking"] },
        bitfieldGroup("nameplateStackingTypes", Enum.NamePlateStackType,
            STACK_LABELS, L["Stacking tip"]),

        -- La maquette au-dessus de ce qu'elle illustre : on la regarde en
        -- réglant le style et la taille, pas après les avoir quittés.
        { section = "preview" },
        { type = "header",      text = L["Preview"] },
        { type = "description", text = L["Preview notice"] },
        { type = "preview" },

        { section = "blizzard" },
        { type = "header", text = L["Appearance"] },
        enumDropdown("nameplateStyle", Enum.NamePlateStyle, STYLE_LABELS,
            L["Nameplate style"], L["Nameplate style tip"]),
        -- Le calibre de plaque du client : cinq crans, pas des pixels. Il vit
        -- sous le style parce que c'est le même sujet — l'allure d'ensemble — et
        -- parce que les deux se règlent l'un après l'autre.
        --
        -- À ne pas confondre avec la largeur et la hauteur de notre moitié, qui
        -- sont en pixels et qui, elles, ne passent par aucun CVar. Les deux
        -- coexistent : celui-ci pose le calibre, les nôtres l'ajustent.
        blizzSlider("nameplateSize",
            L["Nameplate size"], L["Nameplate size tip"],
            { min = 1, max = 5, step = 1 }, SIZE_LOCK),

        -- En pourcentage, par pas de dix : le client range un multiplicateur, mais
        -- « 1,20 » ne se lit pas comme une taille. Les bornes sont celles où la
        -- vignette reste une vignette — au-delà elle mange la plaque, en deçà elle
        -- n'est plus reconnaissable.
        blizzSlider("nameplateAuraScale",
            L["Aura scale"], L["Aura scale tip"],
            { min = 70, max = 140, step = 10, factor = 100 }),
        blizzSlider("nameplateDebuffPadding",
            L["Debuff spacing"], L["Debuff spacing tip"],
            { min = 0, max = 20, step = 1 }),

        { type = "header", text = L["Health bar info"] },
        bitfieldGroup("nameplateInfoDisplay", Enum.NamePlateInfoDisplay,
            INFO_LABELS, L["Health bar info tip"]),

        { type = "header", text = L["Cast bar info"] },
        bitfieldGroup("nameplateCastBarDisplay", Enum.NamePlateCastBarDisplay,
            CAST_INFO_LABELS, L["Cast bar info tip"]),

        { type = "header", text = L["Threat display"] },
        bitfieldGroup("nameplateThreatDisplay", Enum.NamePlateThreatDisplay,
            THREAT_LABELS, L["Threat display tip"]),

        -- Trois rangées d'auras, une par famille d'unités. Le client les range
        -- dans trois CVars distincts et leur donne trois énumérations distinctes,
        -- alors que les catégories sont les mêmes : on garde ses trois listes
        -- plutôt que de les fondre, pour que la page dise ce que le jeu fait.
        { type = "header", text = L["Enemy NPC auras"] },
        bitfieldGroup("nameplateEnemyNpcAuraDisplay", Enum.NamePlateEnemyNpcAuraDisplay,
            AURA_LABELS, L["Auras tip"]),

        { type = "header", text = L["Enemy player auras"] },
        bitfieldGroup("nameplateEnemyPlayerAuraDisplay", Enum.NamePlateEnemyPlayerAuraDisplay,
            AURA_LABELS, L["Auras tip"]),

        { type = "header", text = L["Friendly player auras"] },
        bitfieldGroup("nameplateFriendlyPlayerAuraDisplay", Enum.NamePlateFriendlyPlayerAuraDisplay,
            AURA_LABELS, L["Auras tip"]),

        { type = "header", text = L["Simplified nameplates"] },
        { type = "description", text = L["Simplified nameplates notice"] },
        bitfieldGroup("nameplateSimplifiedTypes", Enum.NamePlateSimplifiedType,
            SIMPLIFIED_LABELS, L["Simplified nameplates tip"]),

        -- ------------------------------------------------------------------
        --  Ce que l'addon ajoute
        -- ------------------------------------------------------------------
        -- Les deux moitiés de la page se lisent côte à côte quand la fenêtre est
        -- assez large : ce qui appartient au jeu à gauche, ce qu'on ajoute à
        -- droite. C'est la page la plus longue de l'addon, et la seule où deux
        -- colonnes changent quelque chose.
        { section = "own" },
        { type = "column" },
        { type = "header",      text = L["Bshamel UI options"] },
        { type = "description", text = L["Bshamel UI options notice"] },

        -- Le mode aperçu ouvre la colonne : c'est le geste qu'on fait **avant**
        -- de régler quoi que ce soit, et il sert à plusieurs sections — la barre
        -- de sorts, son texte, les auras. Rangé dans l'une d'elles, il aurait eu
        -- l'air de n'appartenir qu'à celle-là.
        { type = "header", text = L["Preview mode"] },
        {
            type    = "toggle",
            key     = "previewMode",
            text    = L["Show cast bar"],
            tooltip = L["Show cast bar tip"],
        },
        { section = "size" },
        { type = "header", text = L["Health bar size"] },
        {
            type    = "toggle",
            key     = "resize",
            text    = L["Resize nameplates"],
            tooltip = L["Resize nameplates tip"],
        },
        {
            type     = "slider",
            key      = "width",
            text     = L["Nameplate width"],
            tooltip  = L["Nameplate width tip"],
            min      = 60,
            max      = 400,
            step     = 2,
            disabled = requires("resize"),
        },
        {
            type     = "slider",
            key      = "height",
            text     = L["Nameplate height"],
            tooltip  = L["Nameplate height tip"],
            min      = 4,
            max      = 40,
            step     = 1,
            disabled = requires("resize"),
        },
        {
            type    = "toggle",
            key     = "resizeText",
            text    = L["Resize nameplate text"],
            tooltip = L["Resize nameplate text tip"],
        },
        {
            type     = "slider",
            key      = "textSize",
            text     = L["Nameplate text size"],
            tooltip  = L["Nameplate text size tip"],
            min      = 6,
            max      = 24,
            step     = 1,
            disabled = requires("resizeText"),
        },
        -- Le client sait faire lui-même « le nom seul », mais son menu ne le
        -- propose nulle part : la case vit donc ici, en dernière ligne de la
        -- barre de vie — c'est elle qu'elle remplace.
        blizzToggle("nameplateShowOnlyNameForFriendlyPlayerUnits",
            L["Allied names only"], L["Allied names only tip"]),

        { type = "header", text = L["Cast bar size"] },
        {
            type    = "toggle",
            key     = "resizeCast",
            text    = L["Resize cast bar"],
            tooltip = L["Resize cast bar tip"],
        },
        {
            type     = "slider",
            key      = "castHeight",
            text     = L["Cast bar height"],
            tooltip  = L["Cast bar height tip"],
            min      = 4,
            max      = 40,
            step     = 1,
            disabled = requires("resizeCast"),
        },
        {
            type    = "toggle",
            key     = "resizeCastText",
            text    = L["Resize cast text"],
            tooltip = L["Resize cast text tip"],
        },
        {
            type     = "slider",
            key      = "castTextSize",
            text     = L["Cast text size"],
            tooltip  = L["Cast text size tip"],
            min      = 6,
            max      = 24,
            step     = 1,
            disabled = requires("resizeCastText"),
        },

        -- Le chevauchement des plaques entre elles : la place que chacune garde
        -- avant que le jeu ne pousse la voisine. Deux réglages du client que son
        -- menu n'expose pas.
        { section = "overlap" },
        { type = "header", text = L["Stacking"] },
        blizzSlider("nameplateOverlapH",
            L["Horizontal overlap"], L["Overlap tip"],
            { min = 0.4, max = 3, step = 0.05, decimals = 2 }),
        blizzSlider("nameplateOverlapV",
            L["Vertical overlap"], L["Overlap tip"],
            { min = 0.4, max = 3, step = 0.05, decimals = 2 }),

        { section = "colors" },
        { type = "header", text = L["Enemy colors"] },
        { type = "description", text = L["Enemy colors notice"] },
        {
            type    = "toggle",
            key     = "npcColors",
            text    = L["Color enemies by kind"],
            tooltip = L["Color enemies by kind tip"],
        },
        {
            type     = "color",
            key      = "bossColor",
            text     = L["Boss color"],
            tooltip  = L["Boss color tip"],
            disabled = requires("npcColors"),
        },
        {
            type     = "color",
            key      = "casterColor",
            text     = L["Caster color"],
            tooltip  = L["Caster color tip"],
            disabled = requires("npcColors"),
        },
        {
            type     = "color",
            key      = "meleeColor",
            text     = L["Melee color"],
            tooltip  = L["Melee color tip"],
            disabled = requires("npcColors"),
        },
        {
            type     = "color",
            key      = "rareColor",
            text     = L["Rare color"],
            tooltip  = L["Rare color tip"],
            disabled = requires("npcColors"),
        },
        {
            type     = "color",
            key      = "rareEliteColor",
            text     = L["Rare elite color"],
            tooltip  = L["Rare elite color tip"],
            disabled = requires("npcColors"),
        },
        {
            type    = "toggle",
            key     = "pvpClassColor",
            text    = L["PvP class colors"],
            tooltip = L["PvP class colors tip"],
        },

        { section = "threat" },
        { type = "header", text = L["Threat"] },
        { type = "description", text = L["Threat notice"] },
        {
            type    = "toggle",
            key     = "threatColors",
            text    = L["Color by threat"],
            tooltip = L["Color by threat tip"],
        },
        {
            type     = "color",
            key      = "threatShiftColor",
            text     = L["Threat shifting"],
            tooltip  = L["Threat shifting tip"],
            disabled = requires("threatColors"),
        },
        {
            type     = "color",
            key      = "threatBadColor",
            text     = L["Threat wrong"],
            tooltip  = L["Threat wrong tip"],
            disabled = requires("threatColors"),
        },

        -- Le client sait faire lui-même « le nom seul », mais son menu ne le
        -- propose nulle part : la case est donc de ce côté-ci. On avait
        -- entrepris de construire cette fonctionnalité — masquer la barre,
        -- recentrer le nom — et on s'y était cassé les dents sur des ancrages
        -- qu'il interdit de relire. Il suffisait de le lui demander.
        { section = "marker" },
        { type = "header", text = L["Raid marker"] },
        {
            type    = "toggle",
            key     = "marker",
            text    = L["Place raid marker"],
            tooltip = L["Place raid marker tip"],
        },
        {
            type     = "slider",
            key      = "markerSize",
            text     = L["Marker size"],
            tooltip  = L["Marker size tip"],
            min      = 8,
            max      = 64,
            step     = 1,
            disabled = requires("marker"),
        },
        {
            type     = "slider",
            key      = "markerX",
            text     = L["Marker offset X"],
            tooltip  = L["Marker offset tip"],
            min      = -60,
            max      = 60,
            step     = 1,
            disabled = requires("marker"),
        },
        {
            type     = "slider",
            key      = "markerY",
            text     = L["Marker offset Y"],
            tooltip  = L["Marker offset tip"],
            min      = -60,
            max      = 60,
            step     = 1,
            disabled = requires("marker"),
        },

        { section = "visibility" },
        { type = "header", text = L["Visibility"] },
        { type = "description", text = L["Visibility notice"] },
        {
            type    = "toggle",
            key     = "visibility",
            text    = L["Tune visibility"],
            tooltip = L["Tune visibility tip"],
        },
        {
            type     = "slider",
            key      = "targetAlpha",
            text     = L["Target opacity"],
            tooltip  = L["Target opacity tip"],
            min      = 10,
            max      = 100,
            step     = 5,
            disabled = requires("visibility"),
        },
        {
            type     = "slider",
            key      = "targetDarkness",
            text     = L["Target darkness"],
            tooltip  = L["Darkness tip"],
            min      = 0,
            max      = 90,
            step     = 5,
            disabled = requires("visibility"),
        },
        {
            type     = "slider",
            key      = "otherAlpha",
            text     = L["Others opacity"],
            tooltip  = L["Others opacity tip"],
            min      = 10,
            max      = 100,
            step     = 5,
            disabled = requires("visibility"),
        },
        {
            type     = "slider",
            key      = "otherDarkness",
            text     = L["Others darkness"],
            tooltip  = L["Darkness tip"],
            min      = 0,
            max      = 90,
            step     = 5,
            disabled = requires("visibility"),
        },
        {
            type     = "slider",
            key      = "occludedAlpha",
            text     = L["Occluded opacity"],
            tooltip  = L["Occluded opacity tip"],
            min      = 5,
            max      = 100,
            step     = 5,
            disabled = requires("visibility"),
        },
        {
            type     = "slider",
            key      = "occludedDarkness",
            text     = L["Occluded darkness"],
            tooltip  = L["Occluded darkness tip"],
            min      = 0,
            max      = 90,
            step     = 5,
            disabled = requires("visibility"),
        },

        -- Ces trois-là sont des réglages du client, comme ceux de la moitié
        -- d'au-dessus, mais son menu ne les expose nulle part : il n'y a donc pas
        -- d'autre endroit où aller les chercher, et leur place est de ce côté-ci.
        --
        -- Le partage entre les deux moitiés de la page n'est pas « à qui
        -- appartient le réglage » mais « le menu du jeu sait-il le montrer ». Un
        -- réglage qu'il possède sans l'afficher est, pour le joueur, aussi
        -- introuvable qu'un réglage qui n'existerait pas.
        -- La distance et le chevauchement dorment (`LIVE.spacing`) : la page
        -- s'est resserrée sur ce qui se règle vraiment, et ces deux-là n'en font
        -- plus partie. Le code reste — les rallumer est un booléen.
        { section = "spacing" },
        { type = "header", text = L["Spacing and distance"] },
        blizzSlider("nameplateMaxDistance",
            L["Nameplate distance"], L["Nameplate distance tip"],
            { min = 10, max = 100, step = 5 }),

        { section = "auras" },
        { type = "header", text = L["Auras"] },
        { type = "description", text = L["Auras paused notice"] },
        {
            type    = "toggle",
            key     = "ownAuras",
            text    = L["Own auras"],
            tooltip = L["Own auras tip"],
            disabled = aurasPaused,
            disabledReason = L["Auras paused"],
        },

        { type = "header", text = L["Own debuff auras"] },
        { type = "description", text = L["Own debuff auras notice"] },
        auraSliders("auraDot"),

        { type = "header", text = L["Important auras"] },
        { type = "description", text = L["Important auras notice"] },
        auraSliders("auraImp"),

        { type = "header", text = L["Crowd control auras"] },
        { type = "description", text = L["Crowd control auras notice"] },
        auraSliders("auraCc"),

    }),

    OnEnable = function(self)
        -- Les exemples de l'aperçu se préparent d'abord : si la case a survécu à
        -- un `/reload`, la première peinture les montre déjà.
        if LIVE.auras and self:Get("previewMode") then refreshSampleList() end

        applySize(self)

        -- Un autre addon — ou le panneau du client — peut écrire par-dessus nos
        -- CVars. On reprend la main, sans précipitation : voir `CVAR_SETTLE`.
        -- C'est le seul abonnement que prend la seule section de taille.
        self:RegisterEvent("CVAR_UPDATE", U.Throttle(T.TIMING.CVAR_SETTLE, function()
            applySize(self)
            applyAlpha(self)
        end))

        -- La largeur de boîte est refusée en combat, sans rien dire. Ce qui a été
        -- refusé se rattrape ici — c'est le même contrat que les cadres de groupe
        -- dans `Modules/UnitFrames.lua`.
        self:RegisterEvent("PLAYER_REGEN_ENABLED", function() applySize(self) end)

        -- Tout ce qui suit s'occupe des plaques une par une. Tant qu'aucune
        -- section n'en a besoin, rien de tout cela ne s'arme : pas de hook, pas
        -- de passage périodique, pas un événement de plaque écouté. C'est ce qui
        -- rend chaque section vérifiable seule (voir `LIVE`).
        if not needsPlates() then return end

        refreshRole()
        collectPlates()
        hookPainting()
        applyAlpha(self)
        paintAll(self)

        -- Le passage périodique ne sert qu'à guetter l'occultation : sans la
        -- section qui l'exploite, il tournerait pour personne.
        if LIVE.visibility then startTicker(self) end
        updateCastTicker(self)

        self:RegisterEvent("NAME_PLATE_UNIT_ADDED", function(_, unit)
            -- La plaque personnelle est celle du joueur, posée à ses pieds : ni
            -- cible, ni menace, ni classement de créature. On ne la suit pas.
            if U.IsTrue(UnitIsUnit(unit, "player")) then return end

            local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit
                          and C_NamePlate.GetNamePlateForUnit(unit)
            if type(plate) ~= "table" then return end
            plates[unit] = plate
            -- La plaque change de main : ses textes sont à recenser à nouveau.
            forgetTexts(plate.UnitFrame)
            paint(self, plate, unit)
        end)

        self:RegisterEvent("NAME_PLATE_UNIT_REMOVED", function(_, unit)
            local plate = plates[unit]
            plates[unit] = nil
            -- La plaque part au recyclage : on lui rend son ancrage et sa barre
            -- avant qu'elle ne resserve à quelqu'un d'autre. Sans cela, le
            -- prochain adversaire hériterait du nom recentré d'un allié.
            if plate then detach(plate) end
        end)

        -- Le changement de cible bascule deux plaques d'un coup. Le passage
        -- périodique le verrait au dixième de seconde près ; ici c'est dans
        -- l'image même du clic.
        self:RegisterEvent("PLAYER_TARGET_CHANGED", function() paintAll(self) end)

        self:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE", function(_, unit)
            if plates[unit] then paint(self, plates[unit], unit) end
        end)

        -- La rangée d'auras suit les auras, pas les repeintures : `UNIT_AURA`
        -- désigne l'unité, on ne relit que la sienne. En mode aperçu, rien à
        -- suivre — la rangée montre les exemples.
        self:RegisterEvent("UNIT_AURA", function(_, unit)
            local plate = plates[unit]
            if not plate then return end
            if not (LIVE.auras and self:Get("ownAuras")) then return end
            if self:Get("previewMode") then return end

            local unitFrame = unitFrameOf(plate)
            if unitFrame then applyOwnAuras(self, unitFrame, unit, true) end
        end)

        self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", function()
            refreshRole()
            paintAll(self)
        end)

        local function enteredWorld()
            -- Le client refait ses plaques en chargeant une zone, sans
            -- réannoncer celles qui restent : on repart de ce qui est à l'écran.
            collectPlates()
            -- Les échelles se relisent au montage des plaques : rentrer dans une
            -- instance en reconstruit, et le client les remonte avec ses propres
            -- valeurs s'il a rechargé ses réglages entre-temps.
            applyAll(self)
        end

        self:RegisterEvent("PLAYER_ENTERING_WORLD",   enteredWorld)

    end,

    OnDisable = function()
        -- On rend sans relire les réglages : le module s'éteint, ce qu'il a posé
        -- doit disparaître même si les interrupteurs restent cochés.
        stopTicker()
        if castTicker then castTicker:Cancel() castTicker = nil end
        hideAuraRows()
        restorePlateWidth()
        releaseAll()
        giveBackCVars()
        wipe(plates)
    end,

    OnSettingChanged = function(self, key)
        if key == nil then
            applyAll(self)
            return
        end

        -- Chaque groupe se rend **séparément** : éteindre la taille ne doit pas
        -- rendre les opacités, qui n'ont rien demandé.
        if SIZE_KEYS[key] then
            -- L'aperçu allume et éteint sa minuterie ici, et nulle part
            -- ailleurs : c'est le seul endroit où la case change. Les durées des
            -- auras d'exemple repartent au même moment — un balayage déjà écoulé
            -- ressemble à une aura expirée.
            if key == "previewMode" then
                if self:Get("previewMode") then refreshSampleList() end
                updateCastTicker(self)
            end

            -- Les interrupteurs de la section se rendent séparément : éteindre la
            -- taille ne doit pas ramener le texte à son corps, qui n'a rien
            -- demandé.
            if key == "resize" and not self:Get("resize") then
                giveBackSize()
            elseif key == "resizeText" and not self:Get("resizeText") then
                restoreTextSizes()
            elseif key == "resizeCast" and not self:Get("resizeCast") then
                restoreCastSizes()
            else
                -- On refait les recensements avant d'appliquer. Toucher à ce
                -- réglage est précisément le geste de quelqu'un qui vient de
                -- remarquer qu'un texte n'avait pas suivi : c'est le moment de
                -- regarder ce que les plaques portent **maintenant**, plutôt que
                -- de rejouer une liste établie plus tôt.
                wipe(plateTexts)
                applySize(self)
                paintAll(self)
            end
            return
        end

        if ALPHA_KEYS[key] then
            if key == "visibility" and not self:Get("visibility") then
                giveBack(ALPHA_CVARS)
            else
                applyAlpha(self)
            end
        end

        -- Les rangées d'auras se réancreront au repassage : un réglage vient de
        -- changer, et c'est le seul moment où leurs points bougent.
        bumpAuraLayout()

        -- Le repassage rend aussi les opacités posées à la main : `paint` les
        -- reprend ou les relâche selon l'interrupteur, plaque par plaque.
        paintAll(self)
    end,
})
