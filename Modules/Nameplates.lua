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
--  L'**occultation** — qu'un adversaire soit passé derrière un mur — n'est ni
--  annoncée ni exposée : le client se contente de pâlir la plaque, par le
--  multiplicateur `nameplateOccludedAlphaMult`. C'est ce multiplicateur qu'on
--  règle, et rien d'autre : l'assombrissement, qui exigeait de *déduire*
--  l'occultation plaque par plaque, est parti avec sa déduction.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local U    = BUI.Util
local W    = BUI.Widgets
local L    = ns.L

local MODULE = "Nameplates"

--- Grise une ligne tant que les interrupteurs qui la commandent ne sont pas tous
--- allumés. Plusieurs clés parce qu'une ligne peut dépendre d'une case maîtresse
--- **et** de celle de sa rangée — les réglages d'une rangée laissée au jeu ne
--- veulent rien dire.
---@param ... string
---@return fun(): boolean
local function requires(...)
    local keys = { ... }
    return function()
        local mod = BUI.Modules:Get(MODULE)
        if not mod then return true end

        for i = 1, #keys do
            if not mod:Get(keys[i]) then return true end
        end

        return false
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
local LIVE = {
    -- Les réglages du jeu repris dans la page. Rien à valider : ils ne modifient
    -- aucune plaque, ils écrivent des CVars que le client relit lui-même.
    blizzard   = true,
    own        = true,

    size       = true,

    marker     = true,

    -- **La rangée d'auras de l'addon est retirée**, et le code reste ici, entier,
    -- comme le veut cette table.
    --
    -- Elle marchait. Ce qu'elle coûtait est ailleurs : elle lit les auras d'une
    -- unité adverse, c'est-à-dire ce que le client protège le plus, et elle n'y
    -- arrive qu'en composant avec des valeurs secrètes, des filtres classés et
    -- une durée qui est devenue un objet opaque — trois choses qui ont changé
    -- deux fois en un an. Une extension suffit à la casser, et une rangée
    -- d'entraves cassée en plein combat est pire que pas de rangée du tout.
    --
    -- Le jeu les affiche lui-même, dans sa moitié de la page. C'est ce qu'on
    -- garde : ce qu'il montre ne dépend d'aucune API que nous appelons.
    auras      = false,

    -- L'opacité, validée puis endormie quand la page s'était resserrée.
    -- Rallumée : le réglage des non-ciblés est redemandé, et la section
    -- remonte dans la partie barre de vie.
    visibility = true,

    -- La texture des barres de vie.
    textures   = true,

    colors     = true,
    threat     = true,
    overlap    = true,    -- le chevauchement des plaques entre elles

    -- La distance, endormie quand la page s'est resserrée sur la liste voulue.
    -- Le code reste : rallumer est un booléen.
    spacing    = false,
}

--- Le verrou qui tenait les rangées d'auras et le marqueur en pause — visibles,
--- grisés, inertes. Il est **levé** : ce qui les faisait mentir n'était pas une
--- limite du client mais deux erreurs de notre côté, corrigées ensemble (voir
--- « La rangée d'auras de l'addon »). Le mécanisme reste écrit : c'est le
--- seul moyen honnête d'annoncer une section qui ne tient pas sa promesse, et il
--- resservira.
local AURAS_PAUSED = false

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
        or LIVE.colors or LIVE.threat or LIVE.auras or LIVE.textures
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

    -- La superposition : la place que chaque plaque garde avant que le jeu ne
    -- pousse la voisine. Deux réglages que son menu n'expose pas.
    --
    -- Ils étaient branchés en direct sur le CVar, et c'est ce qui les faisait
    -- **sauter tout seuls** : le client les réécrit en rejouant son calibre de
    -- plaque, et une glissière qui écrit sans reprendre la main perd à chaque
    -- fois. Ils passent désormais par un interrupteur, comme la taille et
    -- l'opacité — on relève, on pose, on repose sur `CVAR_UPDATE`, on rend en
    -- décochant.
    OVERLAP_H = "nameplateOverlapH",
    OVERLAP_V = "nameplateOverlapV",

    -- Le mode « nom seul » pour les alliés. Il n'est pas emprunté — c'est une
    -- case du client, cochée par le joueur depuis notre page — mais il est nommé
    -- ici parce que **deux** lignes de la page le lisent, et qu'une graphie
    -- recopiée est une graphie qui divergera.
    ALLY_NAMES = "nameplateShowOnlyNameForFriendlyPlayerUnits",
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

--- Le corps des textes suit **l'interrupteur de sa barre**, et n'a plus le sien.
---
--- Il en avait un, et l'argument tenait : on élargit une plaque une fois pour
--- toutes, on retouche un corps de texte en le lisant de loin. Mais deux cases
--- pour une seule idée — « je règle cette barre » — coûtaient une ligne à
--- chacune des deux barres et une hésitation à chaque ouverture de la page.
--- Prendre la taille d'une barre, c'est prendre celle de ce qui s'y écrit.
---@param mod table
---@param unitFrame table
local function applyTextSize(mod, unitFrame)
    if not LIVE.size then return end

    sizeTexts(mod, textsOf(unitFrame), "resize", "textSize",
              T.SIZE.PLATE_TEXT)
    sizeTexts(mod, castTextsOf(unitFrame), "resizeCast", "castTextSize",
              T.SIZE.PLATE_CAST_TEXT)
end

-- -------------------------------------------------------------------------
--  Le nom des alliés
-- -------------------------------------------------------------------------
-- Un corps à part pour le nom des joueurs alliés : c'est tout ce qui reste
-- d'une plaque en mode « le nom seul », et il se lit de plus loin que le nom
-- d'un adversaire. Le réglage ne vaut que là où le client montre des plaques
-- alliées — hors instance : en donjon comme en raid, il les verrouille.
--
-- Appliqué **après** la taille de texte générale, à chaque peinture : le plus
-- spécifique gagne. Le client réécrit le nom par `CompactUnitFrame_UpdateName`,
-- qui est précisément l'un des deux hooks qui déclenchent la peinture — la
-- reprise est donc dans le même souffle, sans hook de plus.

--- nom allié -> corps qu'il portait avant qu'on y touche
local allyNameSizes = {}

--- Un allié, au sens de cette page : **ce qu'on n'a pas le droit d'attaquer**.
---
--- Le test évident — « c'est un joueur, et je ne peux pas l'attaquer » — ne tient
--- pas sous identité protégée. En donjon, en raid et en champ de bataille, la
--- réponse à `UnitIsPlayer` est *secrète*, et un secret vaut « non » (voir
--- `U.IsTrue`, qui refuse de conclure). Chaque allié y passait donc pour autre
--- chose qu'un joueur, avec deux conséquences visibles : son nom peint en blanc
--- quoi que dise la case des couleurs de classe, et son corps de texte jamais
--- réglé. C'est très exactement le « bloqué en blanc » des instances.
---
--- Ce qu'on perd en échange est un PNJ amical rangé du même côté que les joueurs
--- alliés. C'est le bon prix : les deux sont ce qu'on ne tape pas, et c'est ce
--- que ces réglages-là veulent dire.
---@param unit string
---@return boolean
local function isFriendlyPlayer(unit)
    return not U.IsTrue(UnitCanAttack("player", unit))
end

---@param mod table
---@param unitFrame table
---@param unit string
local function applyAllyName(mod, unitFrame, unit)
    if not LIVE.size then return end

    local name = unitFrame.name
    if type(name) ~= "table" then return end

    -- **Une unité cesse d'être alliée sans que la plaque change de main.** Un
    -- contrôle mental en fait une alliée le temps de quelques secondes, puis la
    -- rend adverse — et la plaque, elle, ne repart pas au recyclage. Sans ce
    -- chemin de retour, le corps allié restait posé sur un adversaire jusqu'à ce
    -- que sa plaque resserve à quelqu'un d'autre.
    --
    -- On rend le corps relevé : il peut être celui que la taille générale avait
    -- posé, et c'est très bien — elle repasse avant nous à chaque peinture.
    if not (mod:Get("resizeAllyName") and isFriendlyPlayer(unit)) then
        local saved = allyNameSizes[name]
        if saved == nil then return end

        allyNameSizes[name] = nil
        settingFont = true
        T.SetTextSize(name, saved)
        settingFont = false
        return
    end

    if allyNameSizes[name] == nil then
        allyNameSizes[name] = T.TextSize(name) or T.SIZE.PLATE_TEXT
    end

    settingFont = true
    T.SetTextSize(name, mod:Get("allyNameSize"))
    settingFont = false
end

--- Rend son corps à chaque nom allié retouché. Avant `restoreTextSizes` à
--- l'extinction : le corps relevé ici peut être celui que la taille générale
--- avait posé, et c'est elle qui connaît l'original.
local function restoreAllyNames()
    settingFont = true
    for name, size in pairs(allyNameSizes) do
        T.SetTextSize(name, size)
    end
    settingFont = false
    wipe(allyNameSizes)
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
--   · **une aura d'exemple**, une entrave. Celle-là est à nous, faute de pouvoir
--     poser une fausse aura sur une unité, mais elle porte les mesures du client
--     et vit **dans son conteneur d'auras** : sa place n'est donc ni lue ni
--     devinée.
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
--  La rangée d'auras de l'addon
-- -------------------------------------------------------------------------
-- L'addon affiche lui-même les auras des plaques, et c'est ce qui donne à
-- l'aperçu le seul luxe qui compte : **l'aperçu et la réalité sont le même
-- code** — même widget, mêmes réglages, même place (technique lue chez MiniCC,
-- règle 8). Rien n'est dessiné au sens propre : les icônes, le balayage et les
-- polices sont les assets du client, on ne fait que les assembler.
--
-- ## Où les rangées se posent, et pourquoi elles ne tenaient pas
--
-- Trois erreurs, corrigées ensemble, et chacune produisait le même symptôme —
-- « ça marche une demi-seconde puis le jeu reprend la main » :
--
--   · les rangées étaient **portées par le cadre d'unité** et **ancrées sur sa
--     barre de vie**. Ce sont deux régions restreintes, que le client repose à
--     chacun de ses passages : ce qu'on y accroche est défait sans que rien ne
--     le dise. Elles sont désormais portées et ancrées par la **plaque** — le
--     cadre que `C_NamePlate` nous rend, dont le client ne refait pas la mise en
--     page et dont le niveau se lit ;
--   · elles **héritaient de l'échelle de la plaque**, qui n'est pas la même sur
--     la cible et qui change au clic. Un curseur posé à trente donnait trente
--     fois autre chose selon la plaque. `W.AuraRow` s'en affranchit ;
--   · on **effaçait le conteneur du client** pour mettre les nôtres à la place.
--     C'était se battre avec lui à chaque aura qui bouge, et c'était contraire à
--     la règle du dépôt : on emprunte avant de créer, on ne masque jamais pour
--     ajouter. Les rangées **s'ajoutent** maintenant à ce que le jeu montre, et
--     ce que le jeu montre se règle dans sa moitié de la page.
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
-- Chaque rangée a sa taille, son décalage et son écart. Les trois s'ajoutent à
-- ce que le client affiche : la rangée du jeu reste, et se règle chez lui.

--- plaque -> sa rangée ({ cc = })
local auraRows = {}

--- plaque -> ses trois listes, tables de travail réutilisées (règle 7 :
--- `UNIT_AURA` est un chemin chaud). `list.n` borne le rempli ; `refused` compte
--- les auras que le client n'a pas laissé lire.
local auraLists = {}

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

--- La rangée d'auras : sa clé de rangement, ses réglages, son ancrage sur la
--- plaque, et la nature d'aura qui teinte son liseré.
---
--- L'ancrage est déclaré ici et nulle part ailleurs : c'est lui qui dit « à
--- droite », et le décalage X/Y du joueur s'ajoute à partir de là. Il se prend
--- **sur la plaque** : c'est le seul repère de cette famille qu'on ait le droit
--- de lire et que le client ne rejoue pas.
---
--- `own` est l'interrupteur de la rangée, `bit` la catégorie du client qu'elle
--- remplace. Les deux vont ensemble : une rangée qu'on affiche est une catégorie
--- qu'on éteint chez lui, une rangée qu'on laisse est une catégorie qu'on lui
--- laisse.
---
--- **Il y en avait trois.** Les améliorations — gros temps de recharge offensifs
--- et défensifs — et nos affaiblissements sont partis : le jeu les affiche
--- lui-même, et mieux qu'on ne le faisait faute de pouvoir lire ce qu'il
--- protège. Ce qu'elles demandaient de contourner est consigné dans
--- `dev/docs/API_NOTES.md` ; ce qui reste est la seule des trois que le jeu ne
--- classe pas comme on la veut. La table reste une liste : la structure ne
--- change pas de forme parce qu'il ne reste qu'une entrée.
---
--- Ses autres catégories — `Buffs`, `Debuffs`, `LossOfControl` — ne sont plus
--- jamais touchées, et c'est voulu.
local AURA_GROUPS = {
    { key = "cc", kind = "CC", own = "ownAuraCc", bit = "CrowdControl",
      point = "LEFT", relative = "RIGHT",
      size = "auraCcSize", x = "auraCcX", y = "auraCcY", gap = "auraCcGap",
      timer = "auraCcTimer", max = "auraCcMax", shaded = "auraCcShaded" },
}

--- L'addon tient-il **cette rangée-là** ? La case maîtresse et celle de la
--- rangée doivent être allumées toutes les deux.
---
--- C'est le seul juge de la question, et tout s'y branche : ce qu'on peint, ce
--- que l'aperçu montre, et la catégorie qu'on éteint chez le client. Trois
--- endroits qui répondraient chacun pour soi finiraient par se contredire — un
--- exemple affiché là où aucune rangée ne se posera, par exemple.
---@param mod table|nil
---@param group table  une entrée d'`AURA_GROUPS`
---@return boolean
local function rowTaken(mod, group)
    return LIVE.auras and not AURAS_PAUSED and mod ~= nil
       and mod:Get("ownAuras") == true and mod:Get(group.own) == true
end

--- Au moins une rangée est-elle à nous ? Ce qui ne vaut que pour la section
--- entière — monter les cadres, armer la minuterie de l'aperçu — se décide ici.
---@param mod table|nil
---@return boolean
local function anyRowTaken(mod)
    for g = 1, #AURA_GROUPS do
        if rowTaken(mod, AURA_GROUPS[g]) then return true end
    end
    return false
end

--- Sorts d'exemple du mode aperçu, par rangée. L'entrave est prise **dans la
--- liste des contrôles**, pour passer par le même classement qu'une vraie.
local SAMPLE_SPELLS = {
    cc = { 118 },            -- Métamorphose
}

--- Les listes d'exemple, une par rangée. Les durées repartent à chaque allumage
--- du mode aperçu **et à chaque cycle** : un balayage figé ressemble à une aura
--- expirée, et un décompte arrêté à zéro ne se règle pas.
local sampleLists = {
    cc = { n = 0 },
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

                local cycle = T.TIMING.PLATE_AURA_CYCLE
                local stagger = (n - 1) * T.TIMING.PLATE_AURA_STEP

                entry.icon           = icon
                entry.kind           = group.kind
                entry.duration       = cycle
                entry.expirationTime = now + cycle - stagger

                -- Un vrai objet de durée quand le client sait en fabriquer :
                -- l'exemple passe alors par la même horloge que les vraies
                -- auras. Les deux nombres restent le repli.
                entry.durationObject = nil
                if C_DurationUtil and C_DurationUtil.CreateDuration then
                    local ok, durationObject = pcall(C_DurationUtil.CreateDuration,
                        now - stagger, cycle)
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
--- **Une valeur secrète se transmet, elle ne s'inspecte pas**, et c'est toute la
--- règle de cette fonction. Sur une unité adverse, le client rend l'icône, le
--- nombre de cumuls et l'identifiant de sort **secrets** — relevé en jeu par
--- `/bui auras` :
---
---     aura.icon: secret | .auraInstanceID: activée
---     .applications: secret | .spellId: secret
---
--- Une première version refusait l'aura sur ce constat, et la rangée restait
--- vide pour toujours. C'était l'erreur inverse de celle qu'on
--- croyait éviter : un secret n'est pas intouchable, il est **illisible**. Passé
--- tel quel à `SetTexture`, il peint l'icône exacte ; c'est ce que fait le client
--- lui-même, et c'est ce que font les addons qui y arrivent (règle 8).
---
--- Ce qu'on perd, on le perd donc **précisément**, et pas en bloc :
---
---   · les **cumuls** ne s'affichent pas. Les écrire demanderait de comparer le
---     nombre à un, ce qui lève sur un secret. Une icône sans son « 3 » reste
---     une icône juste ;
---   · le **vocabulaire d'entraves** (`CC_SPELLS`) ne sert plus de repli, faute
---     de pouvoir lire l'identifiant de sort. Le filtre classé du client, lui,
---     n'a jamais eu besoin qu'on lise quoi que ce soit.
---
--- L'`auraInstanceID`, lui, se lit : c'est ce qui fait tenir le dédoublonnage et
--- l'horloge.
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
    -- Absente, l'icône ne peint rien ; secrète, elle peint la bonne. Seule la
    -- première est un refus.
    local icon = aura.icon
    if not U.IsSecret(icon) and icon == nil then
        lists.refused = lists.refused + 1
        return
    end

    -- L'identifiant se lit, sauf quand il ne se lit pas : le garde vient avant
    -- le premier test, faute de quoi `if id` suffirait à lever. Sans lui, on
    -- perd le dédoublonnage et l'horloge de cette aura-là, pas le parcours.
    local id = not U.IsSecret(aura.auraInstanceID) and aura.auraInstanceID or nil
    if id then
        if collectSeen[id] then return end
        collectSeen[id] = true
    end

    -- L'horloge de l'aura. Une entrave en a toujours une : il n'y a rien à
    -- conclure de son absence, seulement un balayage en moins.
    local durationObject
    if id and C_UnitAuras.GetAuraDuration then
        local ok, answer = pcall(C_UnitAuras.GetAuraDuration, unit, id)
        if ok then durationObject = answer end
    end

    -- Le plafond dur du thème. Celui du joueur se pose à la peinture
    -- (`W.AuraRowSet`), pour qu'un curseur déplacé se voie tout de suite.
    if list.n >= T.SIZE.PLATE_AURA_MAX then return end

    local n = list.n + 1
    local entry = list[n]
    if not entry then entry = {} list[n] = entry end

    entry.icon           = icon
    entry.kind           = kind
    entry.count          = not U.IsSecret(aura.applications) and aura.applications or nil
    entry.durationObject = durationObject

    list.n = n
end

--- Verse un lot d'auras dans une liste.
---@param auras table|nil
---@param list table
---@param kind string
---@param unit string
---@param lists table
local function admitAll(auras, list, kind, unit, lists)
    if not auras then return end
    for i = 1, #auras do
        admitAura(list, kind, unit, auras[i], lists)
    end
end

-- -------------------------------------------------------------------------
--  Les entraves, et rien d'autre
-- -------------------------------------------------------------------------
-- Il y avait ici deux autres rangées et tout ce qu'elles demandaient : la liste
-- curée que le client tient pour ses propres plaques et qu'on empruntait faute
-- de pouvoir nommer un offensif, le tri du bruit purgeable, le drapeau qui
-- sépare un sort de classe d'un proc de bijou. Elles sont parties avec les
-- rangées qu'elles servaient — le jeu les affiche lui-même, et il lit ce qu'il
-- nous refuse.
--
-- Ce qu'elles ont appris reste dans `dev/docs/API_NOTES.md`, où cela vaut pour
-- tout le fichier : l'ordre des gardes de secret, la durée qui est un objet, la
-- liste `AurasFrame.buffList` et le filtre qui la resserre.

--- Remplit la liste d'une plaque avec les vraies entraves de son unité.
---
--- Deux sources, dans cet ordre : le **filtre classé** du client, qui sait mieux
--- que nous ce qui immobilise, et à défaut — il peut retirer un filtre — le
--- filtre large trié par notre vocabulaire.
---@param unit string
---@param lists table
local function collectAuras(unit, lists)
    lists.refused = 0
    lists.cc.n = 0
    wipe(collectSeen)

    -- Tous lanceurs confondus : un mob mouton est mouton, peu importe qui l'a
    -- lancé.
    local cc = bulkAuras(unit, "HARMFUL|CROWD_CONTROL")
    admitAll(cc, lists.cc, "CC", unit, lists)

    -- Le filtre large ne se lit **que** si le filtre fin a manqué : le lire pour
    -- rien serait un coût de plus sur un chemin chaud (règle 7).
    local harmful
    if not cc then
        harmful = bulkAuras(unit, "HARMFUL")
    end

    if harmful then
        for i = 1, #harmful do
            local aura = harmful[i]
            local spellID = not U.IsSecret(aura.spellId) and aura.spellId or nil
            if spellID and CC_SPELLS[spellID] then
                admitAura(lists.cc, "CC", unit, aura, lists)
            end
        end
    end

    -- Aucun chemin n'a répondu : le client refuse la lecture. Compté comme un
    -- refus, pour que le repli d'honnêteté d'`applyOwnAuras` rende la main au
    -- client au lieu d'effacer sa rangée sans rien poser à la place.
    if not (cc or harmful) then
        lists.refused = lists.refused + 1
    end
end

-- Le conteneur d'auras du client était effacé ici, à l'opacité, par un hook qui
-- le retenait. **C'est parti**, et rien ne l'a remplacé : nos rangées s'ajoutent
-- aux siennes. Ce qu'on y gagne dépasse le code supprimé — plus de bras de fer à
-- chaque aura qui bouge, plus de repli à écrire pour le cas où le client refuse
-- de nous laisser lire ses auras, et la moitié Blizzard de la page redevient ce
-- qu'elle prétend être : les réglages de la rangée du jeu.

--- Un réglage d'aura a changé : les rangées se réancreront à la prochaine
--- repeinture. Appelé au changement de réglage, jamais depuis la peinture.
local function bumpAuraLayout()
    auraStamp = auraStamp + 1
end

--- Les rangées ne se posent **que sur un adversaire**.
---
--- Une aura sur une plaque alliée ne répond à aucune question qu'on se pose en
--- combat : on ne l'interrompt pas, on ne la dissipe pas d'un coup d'œil sur une
--- barre de nom, et elle occupe la place de celles qui comptent. Les trois
--- rangées et leurs sources s'arrêtent donc ici, avant toute lecture.
---
--- Le test porte sur **l'unité, pas sur ce que la plaque montre**. C'est ce qui
--- fait qu'il tient en mode « le nom seul » : une plaque réduite à son nom garde
--- une boîte, et nos rangées s'ancrent dessus — les cacher parce que la barre de
--- vie a disparu aurait marché par accident, et cessé de marcher au premier
--- réglage changé.
---@param unit string
---@return boolean
local function auraless(unit)
    return not U.IsTrue(UnitCanAttack("player", unit))
end

--- Ancre la rangée d'une plaque **sur la plaque**, si le cachet a changé
--- depuis la dernière fois.
---@param mod table
---@param plate table
---@param rows table
local function anchorRows(mod, plate, rows)
    if rows._stamp == auraStamp then return end
    rows._stamp = auraStamp

    for g = 1, #AURA_GROUPS do
        local group = AURA_GROUPS[g]
        local row = rows[group.key]
        if row then
            pcall(row.ClearAllPoints, row)
            pcall(row.SetPoint, row, group.point, plate, group.relative,
                  mod:Get(group.x), mod:Get(group.y))
        end
    end
end

--- Pose la rangée d'une plaque : les auras d'exemple si le mode aperçu
--- est là, les vraies sinon. **C'est la seule fonction qui choisisse entre les
--- deux**, et elles finissent dans le même widget — le luxe tient tout ici.
---
--- `force` relit les auras même si les rangées sont peuplées. Sans lui, une
--- plaque visible garde ce qu'elle montre : une peinture complète survient pour
--- toutes sortes de raisons — un changement de cible, de camp, de menace — et
--- relire quarante auras à chacune ne dirait jamais rien de neuf. C'est
--- `UNIT_AURA` qui force, et il ne parle que quand une aura change.
---@param mod table
---@param plate table
---@param unit string
---@param force? boolean
local function applyOwnAuras(mod, plate, unit, force)
    if not LIVE.auras then return end
    if AURAS_PAUSED then return end

    -- Un allié n'a pas de rangées, y compris en aperçu : montrer un exemple là
    -- où rien n'apparaîtra jamais ferait régler la position contre une plaque
    -- qui ne la portera pas.
    local wanted = not auraless(unit)

    -- `own` ne dit plus « tout », il dit « au moins une rangée ». La case
    -- maîtresse ouvre la section ; celle de chaque rangée décide si cette
    -- rangée-là est à nous ou reste au jeu.
    local own = wanted and anyRowTaken(mod)

    -- **L'aperçu ne montre que les rangées qui sont à nous.** Une rangée laissée
    -- au jeu n'apparaîtra jamais à cet endroit, et poser son exemple ferait
    -- régler une position contre une plaque qui ne la portera pas — c'est le
    -- même argument que pour une plaque alliée, juste au-dessus.
    local preview = own and mod:Get("previewMode") and true or false

    local rows = auraRows[plate]
    if not rows then
        if not (own or preview) then return end
        rows = {}
        for g = 1, #AURA_GROUPS do
            rows[AURA_GROUPS[g].key] = W.AuraRow(plate)
        end
        auraRows[plate] = rows
    end

    if not (own or preview) then
        for g = 1, #AURA_GROUPS do
            local row = rows[AURA_GROUPS[g].key]
            if row then row:Hide() end
        end
        return
    end

    anchorRows(mod, plate, rows)

    if preview then
        for g = 1, #AURA_GROUPS do
            local group = AURA_GROUPS[g]
            local row = rows[group.key]
            if row then
                if rowTaken(mod, group) then
                    local list = sampleLists[group.key]
                    list.max = mod:Get(group.max)
                    W.AuraRowSet(row, list,
                                 mod:Get(group.size), mod:Get(group.gap),
                                 mod:Get(group.timer), mod:Get(group.shaded))
                else
                    row:Hide()
                end
            end
        end
        return
    end

    local lists = auraLists[plate]
    if not lists then
        lists = { cc = { n = 0 }, refused = 0 }
        auraLists[plate] = lists
    end

    local filled = rows._filled
    if force or not filled then
        collectAuras(unit, lists)
        rows._filled = true
    end

    -- Un refus du client ne demande plus rien de particulier : sa rangée n'a pas
    -- été touchée, elle est toujours là. Nos rangées se contentent d'être vides,
    -- ce qui est la vérité de ce qu'on a pu lire.
    for g = 1, #AURA_GROUPS do
        local group = AURA_GROUPS[g]
        local row = rows[group.key]
        if row then
            if rowTaken(mod, group) then
                local list = lists[group.key]
                list.max = mod:Get(group.max)
                W.AuraRowSet(row, list,
                             mod:Get(group.size), mod:Get(group.gap),
                             mod:Get(group.timer), mod:Get(group.shaded))
            else
                -- Rangée laissée au jeu : la nôtre se cache, et la sienne n'a
                -- jamais été éteinte (voir `applyClientAuras`). C'est le seul
                -- endroit où les deux affichages coexistent sans se doubler.
                row:Hide()
            end
        end
    end
end

--- Cache toutes les rangées. Les frames restent prêtes pour la prochaine fois
--- (règle 7) ; le client, lui, n'a rien à récupérer — on ne lui avait rien pris.
local function hideAuraRows()
    for _, rows in pairs(auraRows) do
        for g = 1, #AURA_GROUPS do
            local row = rows[AURA_GROUPS[g].key]
            if row then row:Hide() end
        end
        rows._filled = nil
    end
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

--- Fait repartir les auras d'exemple. `nil` quand personne ne les regarde.
local auraTicker

--- Une aura d'exemple **expire**, comme une vraie : passé sa durée, le balayage
--- s'arrête et le décompte disparaît. C'est juste, et c'est inutilisable — on
--- règle alors la taille d'un chiffre qui n'est plus affiché. On les refait donc
--- à chaque cycle, ce qui rend l'aperçu perpétuel sans lui faire mentir : ce
--- qu'on voit reste une aura de quinze secondes en train de s'écouler.
---
--- Une fois toutes les quinze secondes, et seulement pendant qu'on règle : c'est
--- la minuterie la moins chère de l'addon, à la différence de sa voisine qui
--- pousse une barre vingt fois par seconde.
local function tickAuraPreview()
    local mod = module()
    if not mod then return end

    refreshSampleList()
    for unit, plate in pairs(plates) do
        applyOwnAuras(mod, plate, unit)
    end
end

--- La minuterie ne tourne que s'il y a un exemple à faire vivre : aucune rangée
--- prise, aucun exemple, rien à rafraîchir (règle 7).
---@param mod table
local function updateAuraTicker(mod)
    local wanted = mod:Get("previewMode") and anyRowTaken(mod)

    if wanted and not auraTicker then
        auraTicker = C_Timer.NewTicker(T.TIMING.PLATE_AURA_CYCLE, tickAuraPreview)
    elseif not wanted and auraTicker then
        auraTicker:Cancel()
        auraTicker = nil
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
--
-- Troisième remarque, payée en jouant : **quelqu'un d'autre écrit cette taille**.
-- Le pilote du client la repose quand il rejoue son calibre — ouvrir une page qui
-- montre sa maquette suffit — et aucun événement ne l'annonce : ce n'est pas un
-- CVar, `CVAR_UPDATE` ne dit rien. C'est la même leçon que la hauteur de barre :
-- se brancher sur l'écriture elle-même, et reposer la nôtre dans le même souffle
-- (voir `hookPlateSize`).

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

--- Sommes-nous en train d'écrire la boîte ? Même rôle que pour la hauteur de
--- barre : le hook ci-dessous guette l'écriture, donc il rappelle la nôtre.
local settingPlateSize = false

---@param mod table
local function applyPlateWidth(mod)
    if not (C_NamePlate and C_NamePlate.SetNamePlateSize) then return end
    if not mod:Get("resize") then return end
    if InCombatLockdown() then return end

    local boxHeight = rememberPlateSize()
    if not boxHeight then return end

    settingPlateSize = true
    pcall(C_NamePlate.SetNamePlateSize, mod:Get("width"), boxHeight)
    settingPlateSize = false
end

--- Repose notre largeur **à chaque fois que quelqu'un écrit la sienne**.
---
--- C'est le correctif du symptôme « ouvrir la fenêtre d'options rend les plaques
--- à leur taille Blizzard » : le pilote du client repasse sa boîte par cette
--- fonction-là, sans événement, et on ne peut pas le deviner — on se branche
--- dessus. Sous `pcall` : hooker une table `C_*` est un pari de capacité, et un
--- refus doit coûter la veille, pas une erreur.
local function hookPlateSize()
    if not (C_NamePlate and C_NamePlate.SetNamePlateSize) then return end

    pcall(U.GuardedHook, C_NamePlate, "SetNamePlateSize", function()
        if settingPlateSize then return end

        local mod = module()
        if not (mod and LIVE.size and mod:Get("resize")) then return end
        applyPlateWidth(mod)
    end, function()
        local mod = module()
        return mod ~= nil and mod:IsEnabled()
    end)
end

--- Rend aux plaques la boîte qu'elles avaient — la vraie, relevée, pas une
--- reconstitution.
local function restorePlateWidth()
    if not savedPlateSize then return end
    if not (C_NamePlate and C_NamePlate.SetNamePlateSize) then return end
    if InCombatLockdown() then return end

    settingPlateSize = true
    pcall(C_NamePlate.SetNamePlateSize, savedPlateSize[1], savedPlateSize[2])
    settingPlateSize = false
    savedPlateSize = nil
end

-- -------------------------------------------------------------------------
--  Le calibre du client, poussé à fond
-- -------------------------------------------------------------------------
-- Prendre la taille en pixels commence par **mettre le calibre du client au
-- maximum**, puis par griser sa glissière.
--
-- Ce n'est pas une préférence : le calibre décide de la boîte dans laquelle nos
-- pixels se posent, et une boîte au calibre trois borne ce qu'on peut y écrire.
-- Au cran cinq, la boîte est la plus grande que le client sache faire, et nos
-- deux curseurs disposent de toute leur course. Un calibre laissé au joueur
-- donnait deux réglages qui se contredisent — on règle une largeur au pixel
-- près, puis un cran de calibre la balaie.
--
-- Le CVar est **emprunté** comme les autres : relevé avant la première écriture,
-- rendu tel quel en décochant (`SIZE_CVARS`).
--
-- Ce que le calibre entraînait avec lui — l'échelle des vignettes d'auras et
-- l'espacement des affaiblissements — reste réglable. Ces deux-là étaient grisés
-- avec lui parce qu'y toucher fait rejouer la mise en page du client, et que
-- c'était le geste qui écrasait nos pixels ; ce n'est plus vrai depuis que la
-- largeur de boîte et la hauteur de barre se reposent sur l'écriture elle-même
-- (`hookPlateSize`, `hookBarHeight`).

---@param mod table
local function applySize(mod)
    if LIVE.size and mod:Get("resize") then
        takeCVar(CVAR.SIZE, T.SIZE.PLATE_GAUGE_MAX)
    end

    applyPlateWidth(mod)
end

-- =========================================================================
--  La texture des barres de vie
-- =========================================================================
-- Le remplissage de la barre, remplacé image par image : on ne touche pas au
-- widget, on change ce que sa texture **affiche**. `SetStatusBarTexture`
-- reconstruirait la région ; écrire sur l'objet de texture la laisse en place,
-- balayage compris, et se rend par le chemin inverse.
--
-- La cible et les autres ont chacune leur choix : c'est ce qui rend la cible
-- lisible d'un coup d'œil sans que rien ne grossisse. Le changement de cible
-- repasse par `paintAll`, qui repose la bonne texture des deux côtés.
--
-- Réversibilité (règle 6) : ce que la texture affichait — atlas ou fichier — se
-- relève avant la première écriture. Une lecture refusée (valeur secrète) vaut
-- renoncement : cette barre-là garde son image, on ne prend pas ce qu'on ne
-- saura pas rendre.

--- barre -> ce qu'elle affichait ({ atlas = } ou { file = }), ou `false` quand
--- la lecture a été refusée.
local barTextureTaken = {}

--- Choix du réglage -> clé de `T.TEXTURE`. Deux choix, nommés par ce qu'ils
--- font à la couleur plutôt que par leur asset : l'aplat blanc rend la teinte
--- **vive**, le remplissage des cadres de raid la rend **standard** — c'est
--- celle que le joueur connaît.
local BAR_TEXTURE_KEY = {
    vivid    = "STATUSBAR_FLAT",
    standard = "STATUSBAR_RAID",
}

--- Les choix des deux listes déroulantes — une table, partagée : les deux
--- contrôles offrent exactement la même palette.
local BAR_TEXTURE_VALUES = {
    { value = "vivid",    label = L["Texture vivid"] },
    { value = "standard", label = L["Texture standard"] },
}

--- L'objet de texture du remplissage d'une barre, ou `nil`.
---@param bar table
---@return table|nil
local function fillTextureOf(bar)
    if type(bar.GetStatusBarTexture) ~= "function" then return nil end
    local ok, texture = pcall(bar.GetStatusBarTexture, bar)
    if not ok or type(texture) ~= "table" then return nil end
    return texture
end

--- Relève ce que la texture affiche, une fois. Rend vrai si la barre est
--- prenable — relevée maintenant ou lors d'un passage précédent.
---@param bar table
---@param texture table
---@return boolean
local function rememberBarTexture(bar, texture)
    local taken = barTextureTaken[bar]
    if taken ~= nil then return taken ~= false end

    local okA, atlas = pcall(texture.GetAtlas, texture)
    if okA and type(atlas) == "string" and not U.IsSecret(atlas) and atlas ~= "" then
        barTextureTaken[bar] = { atlas = atlas }
        return true
    end

    local okF, file = pcall(texture.GetTexture, texture)
    if okF and not U.IsSecret(file) and file ~= nil then
        barTextureTaken[bar] = { file = file }
        return true
    end

    barTextureTaken[bar] = false
    return false
end

---@param mod table
---@param unitFrame table
---@param isTarget boolean
local function applyBarTexture(mod, unitFrame, isTarget)
    if not LIVE.textures then return end
    if not mod:Get("barTexture") then return end

    local bar = healthBarOf(unitFrame)
    if not bar then return end

    local texture = fillTextureOf(bar)
    if not texture then return end
    if not rememberBarTexture(bar, texture) then return end

    local choice = isTarget and mod:Get("textureTarget") or mod:Get("textureOther")
    local path   = T.TEXTURE[BAR_TEXTURE_KEY[choice] or ""]
    if not path then return end

    pcall(texture.SetTexture, texture, path)
end

--- Rend son image à chaque barre dont on l'a remplacée.
local function restoreBarTextures()
    for bar, taken in pairs(barTextureTaken) do
        if taken ~= false then
            local texture = fillTextureOf(bar)
            if texture then
                if taken.atlas then
                    pcall(texture.SetAtlas, texture, taken.atlas)
                else
                    pcall(texture.SetTexture, texture, taken.file)
                end
            end
        end
    end
    wipe(barTextureTaken)
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
--     il faudrait pour cela savoir ce qu'il ne dit pas.
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
--  Superposition
-- =========================================================================
-- Deux CVars du client, pris comme tous les autres : relevés avant la première
-- écriture, reposés quand quelqu'un les réécrit, rendus tels quels en décochant.
--
-- C'est ce qui manquait quand ils étaient branchés en direct sur le CVar. Le
-- pilote du client repose ces deux valeurs en rejouant son calibre de plaque, et
-- rien ne l'annonce autrement que par `CVAR_UPDATE` — une glissière qui écrit
-- sans jamais reprendre la main revenait donc d'elle-même à la valeur du jeu.

---@param mod table
local function applyOverlap(mod)
    if not LIVE.overlap then return end
    if not mod:Get("overlap") then return end

    takeCVar(CVAR.OVERLAP_H, mod:Get("overlapH"))
    takeCVar(CVAR.OVERLAP_V, mod:Get("overlapV"))
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

-- =========================================================================
--  Ce qu'est la créature
-- =========================================================================
-- Il y a eu ici une garde « mythique+ ou raid seulement ». Elle est partie avec
-- la refonte des couleurs : c'est l'**unité** qui décide du traitement — PNJ ou
-- joueur —, pas la zone où on la croise.

--- Les classes qui lancent des sorts.
---
--- **Une créature a une classe, comme un joueur** — mais elle ne veut dire
--- quelque chose que sur une élite. C'est un champ du modèle de créature, rempli
--- avec soin sur le trash de donjon, au petit bonheur sur tout le reste : un lynx
--- d'extérieur peut très bien être déclaré druide ou chaman. La donnée existe
--- partout, elle n'est fiable que là où quelqu'un l'a renseignée pour de bon.
---
--- C'est pourquoi `classify` ne l'interroge que sur une élite (voir plus bas). Le
--- geste que ces deux couleurs servent — savoir qui interrompre dans un pack —
--- n'a de toute façon de sens que là.
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

--- Classement d'une unité parmi les six couleurs de PNJ.
---
--- L'ordre des tests est le classement lui-même, et il va du plus rare au plus
--- commun : ce qu'un PNJ **est** prime sur ce qu'il **fait**. Un rare qui
--- incante reste teint en rare — sa rareté est ce qu'on remarque en premier, et
--- c'est aussi ce qui décide de ce qu'on en fait.
---
--- **Un PNJ ordinaire n'est pas teint du tout**, et c'est la règle qui compte
--- ici. Ce module ne repeint que ce qu'il sait nommer : un rang que le client
--- déclare, ou une classe que quelqu'un a pris la peine de renseigner. Le reste —
--- la faune, les civils, tout ce qui traîne en extérieur — garde la couleur du
--- jeu, parce que la seule chose qu'on saurait en dire serait devinée. La
--- version d'avant devinait, et c'est ainsi qu'un lynx passait pour un caster.
---
--- Le rang d'une élite se lit à son **niveau relatif au joueur**, et non à son
--- niveau absolu :
---
---   · à égalité, c'est du trash d'élite : on le classe par ce qu'il lance ;
---   · un cran au-dessus, c'est un miniboss ;
---   · deux crans, ou hors échelle, c'est un boss.
---
--- Le rang prime alors sur la classe.
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

    -- Tout ce qui n'est pas élite s'arrête ici, et rend la main au client.
    if classification ~= "elite" then return nil end

    local level = effectiveLevel(unit)
    local mine  = effectiveLevel("player")

    if level == -1 then return "boss" end
    if level and mine then
        if level >= mine + 2 then return "boss" end
        if level == mine + 1 then return "miniboss" end
    end

    -- Une élite au niveau du joueur : du trash, et c'est le seul endroit où la
    -- classe d'une créature veut dire quelque chose.
    local class = UnitClassBase and UnitClassBase(unit)
    if not U.IsSecret(class) and CASTER_CLASSES[class] then return "caster" end

    return "melee"
end

--- Clé de classement -> clé du réglage de couleur.
local NPC_COLOR_KEY = {
    boss      = "bossColor",
    miniboss  = "minibossColor",
    caster    = "casterColor",
    melee     = "meleeColor",
    rare      = "rareColor",
    rareElite = "rareEliteColor",
}

--- Sommes-nous en instance ? Relu au chargement de zone, jamais à chaque
--- plaque : la peinture est un chemin chaud, l'appartenance à une instance ne
--- change qu'en passant un portail.
local playerInInstance = false

local function refreshInstance()
    playerInInstance = U.IsTrue(IsInInstance())
end

--- Les couleurs par nature s'appliquent-elles ici ? Le réglage de portée dit
--- « partout » ou « en instance seulement » — dehors, la couleur du client
--- reprend la main sans que la case soit à décocher.
---@param mod table
---@return boolean
local function npcColorsActive(mod)
    if not mod:Get("npcColors") then return false end
    if mod:Get("npcColorsScope") == "instance" then return playerInInstance end
    return true
end

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

--- Couleur de fond d'une barre de vie.
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
        elseif npcColorsActive(mod) then
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

--- Couleur d'un nom, ou `nil` quand il ne faut pas y toucher.
---
--- Le blanc pour tout le monde, la couleur de classe pour un joueur : ce sont
--- les deux teintes que le client emploie lui-même. On les repose plutôt que de
--- relire la sienne : une lecture suivie d'une écriture s'empilerait sur
--- elle-même passage après passage.
---
--- **On ne touche plus au nom d'un allié.** Le jeu le colore désormais lui-même
--- à la classe, et il le fait mieux : c'est le seul à pouvoir lire l'identité
--- qu'il protège en instance. La case qui le proposait est partie — elle
--- promettait ce qui arrive déjà.
---
--- Un adversaire, en revanche, on le lit pour savoir sur quoi taper : sa classe
--- *est* l'information, et c'est un choix de l'addon, pas un réglage.
---
--- `false` veut dire « le client garde la main de bout en bout » — pas
--- « blanc ». On ne rend pas une couleur, on s'abstient d'en poser une.
---
--- **Le premier retour est un drapeau, et il le faut.** En instance et en PvP,
--- les trois nombres peuvent être *secrets* : ils traversent l'addon jusqu'à
--- `SetTextColor` sans qu'on ait le droit de les lire, et `if r then` chez
--- l'appelant lèverait. Le drapeau est la seule réponse qu'il puisse regarder.
---@param unit string
---@return boolean paint, number? r, number? g, number? b
local function nameColor(unit)
    if isFriendlyPlayer(unit) then return false end

    local _, class = UnitClass(unit)

    -- **Identité protégée : donjon, raid, champ de bataille.** La classe est
    -- une chaîne secrète, qu'on ne peut ni lire ni indexer. On la fait passer au
    -- client sans la regarder (voir `T.SecretClassColor`).
    if U.IsSecret(class) then
        return T.SecretClassColor(class)
    end

    -- Pas de classe du tout : ce n'est pas un joueur, c'est un PNJ, et le blanc
    -- est la couleur qu'on leur donne. Il ne se pose plus que sur cette
    -- réponse-là — jamais sur une réponse qu'on n'a pas eu le droit de lire.
    if type(class) ~= "string" or class == "" then
        return true, T.COLOR.WHITE:GetRGB()
    end

    local color = T.ClassColor(class)
    if color then return true, color:GetRGB() end
    return true, T.COLOR.WHITE:GetRGB()
end

-- `releaseNames` vivait ici : elle rappelait la fonction de nom du client sur
-- chaque plaque suivie, pour lui rendre la main quand la case des couleurs
-- alliées s'éteignait. La case est partie — le jeu colore ces noms lui-même — et
-- il ne reste plus une seule teinte de nom qu'on pose puis qu'on retire : celles
-- des adversaires et des PNJ ne se règlent pas.

--- Sommes-nous en train de poser une couleur de nom ? Même rôle que
--- `settingFont` pour le corps : le hook ci-dessous guette l'écriture, donc il
--- rappellerait la nôtre.
local settingNameColor = false

--- Repose notre teinte chaque fois que le client écrit la sienne sur un nom.
---
--- **C'est ce qui tient le mode « nom seul ».** Les deux fonctions coiffées plus
--- bas (`hookPainting`) sont les passages obligés d'une plaque *ordinaire* ; une
--- plaque alliée réduite à son nom n'a plus de barre de vie, et le client y
--- repeint le nom par un chemin qui ne passe par aucune des deux. La couleur de
--- classe était donc posée, puis effacée dans le même souffle — un symptôme qui
--- ressemble à « le réglage ne marche pas » alors que le réglage a marché.
---
--- Se brancher sur l'**écriture** au lieu du chemin qui y mène ne demande de
--- connaître aucun de ces chemins : quel qu'il soit, il finit ici. C'est le même
--- parti pris que `hookTextSize` pour le corps des textes, et il est là pour la
--- même raison — on ne court pas après le client, on se met là où il écrit.
---
--- Les deux écritures, parce qu'une chaîne de texte en a deux : `SetTextColor`
--- est celle qu'on emploie, `SetVertexColor` celle que le client emploie sur ses
--- plaques. N'en guetter qu'une laisserait passer la moitié des remises à zéro.
---
--- Le hook lit l'unité **au moment où il se déclenche**, et non celle qu'on
--- connaissait en le posant : les chaînes de texte d'une plaque sortent d'un
--- pool et servent tour à tour à plusieurs unités.
---@param fontString table
---@param unitFrame table
local function hookNameColor(fontString, unitFrame)
    local guard = function()
        local mod = module()
        return mod ~= nil and mod:IsEnabled()
    end

    local function repost(self)
        if settingNameColor then return end

        local mod = module()
        if not mod then return end

        local unit = unitFrame.unit or unitFrame.displayedUnit
        if type(unit) ~= "string" then return end

        -- Une plaque qu'on ne suit pas n'est pas à nous : la plaque personnelle
        -- du joueur, ou une plaque déjà retirée dont le cadre traîne encore.
        if not plates[unit] then return end

        -- Le drapeau et non la couleur : les trois nombres peuvent être secrets,
        -- et un secret ne se teste pas (voir `nameColor`).
        local ok, r, g, b = nameColor(unit)
        if not ok then return end

        settingNameColor = true
        pcall(self.SetTextColor, self, r, g, b)
        settingNameColor = false
    end

    U.GuardedHook(fontString, "SetTextColor",   repost, guard)
    U.GuardedHook(fontString, "SetVertexColor", repost, guard)
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
-- La troisième voie a été **décidée**, pas trouvée : le marqueur est rallumé en
-- acceptant qu'un déplacement ne se relève pas. Ce qui le rend acceptable est le
-- recyclage : le client repose lui-même ancrages et tailles en remontant une
-- plaque (voir `detach`), donc une plaque redonnée après l'extinction revient
-- d'elle-même. Entre l'extinction et le recyclage, le marqueur d'une plaque déjà
-- à l'écran reste où on l'a mis — c'est le prix assumé, et un `/reload` le paie
-- comptant.

-- =========================================================================
--  Marqueur de ciblage
-- =========================================================================
-- Il est **centré sur le coin haut-droit** de la barre de vie, et non posé à
-- côté d'elle : une vignette calée dans l'angle appartient visiblement à la
-- plaque, une vignette flottant au-dessus appartient à ce qu'il y a derrière.
-- Les deux décalages partent de là, et les valeurs nulles sont donc déjà une
-- position juste.
--
-- **Le client repose son ancrage, et il faut se brancher sur cette écriture.**
-- Posé une fois par passage de peinture, le marqueur alterne entre sa place et
-- la nôtre : le client le réancre à des moments qui ne sont pas les nôtres, et
-- deux écrivains sur la même région se relaient sans jamais converger. C'est
-- exactement le symptôme de la hauteur de barre, et c'est le même remède — un
-- hook sur `SetPoint` avec un drapeau de non-récursion. Il n'y a alors plus de
-- moment à deviner : notre ancrage est reposé dans le souffle du sien.

---@param unitFrame table
---@return table|nil
local function markerOf(unitFrame)
    local marker = unitFrame.RaidTargetFrame
    if type(marker) == "table" and type(marker.SetPoint) == "function" then return marker end
    return nil
end

--- Sommes-nous en train de poser l'ancrage du marqueur ? Le hook ci-dessous
--- rappelle notre propre écriture ; ce drapeau coupe la boucle.
local settingMarkerPoint = false

--- marqueurs sortis de l'opacité de leur plaque -> `true`
---
--- Une plaque pâlit pour trois raisons — elle n'est pas la cible, elle est
--- derrière un mur, elle est loin — et le marqueur pâlissait avec elle. C'est
--- pourtant la seule chose de la plaque qu'on ait posée là **pour être vue de
--- loin** : un marqueur à demi effacé ne remplit pas son office. Il sort donc de
--- l'opacité de son parent, et il est le seul dans ce cas.
---
--- Réversible d'un booléen, contrairement à son ancrage : la liste sert à le
--- rendre à l'extinction (règle 6).
local markersOpaque = {}

---@param marker table
local function keepMarkerOpaque(marker)
    if markersOpaque[marker] then return end
    if type(marker.SetIgnoreParentAlpha) ~= "function" then return end
    if not pcall(marker.SetIgnoreParentAlpha, marker, true) then return end
    markersOpaque[marker] = true
end

--- Rend chaque marqueur à l'opacité de sa plaque.
local function restoreMarkerAlpha()
    for marker in pairs(markersOpaque) do
        pcall(marker.SetIgnoreParentAlpha, marker, false)
    end
    wipe(markersOpaque)
end

--- Pose l'ancrage et la taille voulus. Le corps commun au passage de peinture et
--- au hook — les deux écrivent la même chose, et une seule fonction la décrit.
---@param mod table
---@param unitFrame table
---@param marker table
local function writeMarker(mod, unitFrame, marker)
    local anchorTo = healthBarOf(unitFrame) or unitFrame

    settingMarkerPoint = true
    pcall(marker.ClearAllPoints, marker)
    pcall(marker.SetPoint, marker, "CENTER", anchorTo, "TOPRIGHT",
          mod:Get("markerX"), mod:Get("markerY"))
    settingMarkerPoint = false
end

--- Repose notre ancrage à chaque fois que quelqu'un écrit le sien. Un hook par
--- marqueur, posé une fois (`U.GuardedHook` ne double jamais), inerte dès que le
--- module ou l'interrupteur s'éteint.
---@param unitFrame table
---@param marker table
local function hookMarkerPoint(unitFrame, marker)
    U.GuardedHook(marker, "SetPoint", function()
        if settingMarkerPoint then return end

        local mod = module()
        if not (mod and LIVE.marker and mod:Get("marker")) then return end
        if AURAS_PAUSED then return end

        writeMarker(mod, unitFrame, marker)
    end, function()
        local mod = module()
        return mod ~= nil and mod:IsEnabled()
    end)
end

---@param mod table
---@param unitFrame table
local function placeMarker(mod, unitFrame)
    -- En pause, ou éteint : on ne fait rien. Le marqueur a déjà retrouvé sa
    -- place, remise par le client au moment où l'interrupteur s'est éteint —
    -- voir plus haut.
    if AURAS_PAUSED then return end

    local marker = markerOf(unitFrame)
    if not marker then return end

    -- Le hook se pose même réglage éteint, comme celui de la hauteur de barre :
    -- il ne fait rien tant que la case ne l'autorise pas, et le poser plus tard
    -- voudrait dire attendre qu'une plaque repasse par ici après le clic.
    hookMarkerPoint(unitFrame, marker)
    if not (LIVE.marker and mod:Get("marker")) then return end

    keepMarkerOpaque(marker)

    local size = mod:Get("markerSize")
    pcall(marker.SetSize, marker, size, size)

    -- La vignette suit le cadre qui la porte. Sans cela, agrandir le marqueur
    -- agrandirait sa boîte et laisserait l'icône à sa taille, au coin.
    local icon = marker.RaidTargetIcon
    if type(icon) == "table" and type(icon.SetAllPoints) == "function" then
        pcall(icon.ClearAllPoints, icon)
        pcall(icon.SetAllPoints, icon, marker)
    end

    writeMarker(mod, unitFrame, marker)
end

-- -------------------------------------------------------------------------
--  Le marqueur d'exemple de l'aperçu
-- -------------------------------------------------------------------------
-- Un marqueur ne se montre que sur une unité marquée : le régler supposait de
-- marquer un mob, comme la barre de sorts supposait d'attendre une incantation.
-- Le mode aperçu montre donc la vraie vignette du client, avec un crâne
-- d'exemple — l'icône que tout le monde pose en premier. Même mécanique que la
-- barre de sorts maintenue : on se branche sur son `Hide`, et éteindre l'aperçu
-- la rend une fois.

--- vignettes que l'aperçu montre en ce moment -> `true`. Même nuance que
--- `previewShown` : éteindre l'aperçu rend la vignette, passer en le laissant
--- éteint ne la touche pas — sans quoi chaque repeinture cacherait le marqueur
--- d'une unité réellement marquée.
local markerShown = {}

--- Sommes-nous en train de montrer ou de rendre la vignette ?
local settingMarker = false

--- Rend toutes les vignettes montrées par l'aperçu.
local function hideMarkerPreviews()
    settingMarker = true
    for marker in pairs(markerShown) do
        pcall(marker.Hide, marker)
    end
    settingMarker = false
    wipe(markerShown)
end

---@param marker table
local function hookMarkerPreview(marker)
    U.GuardedHook(marker, "Hide", function(self)
        if settingMarker then return end

        local mod = module()
        if not (mod and LIVE.marker and mod:Get("previewMode")) then return end

        settingMarker = true
        pcall(self.Show, self)
        settingMarker = false
    end, function()
        local mod = module()
        return mod ~= nil and mod:IsEnabled()
    end)
end

---@param mod table
---@param unitFrame table
local function applyMarkerPreview(mod, unitFrame)
    if not LIVE.marker then return end

    -- En pause : l'aperçu du marqueur l'est avec lui. Montrer un crâne
    -- d'exemple sur un réglage inerte ferait croire qu'il agit.
    if AURAS_PAUSED then
        hideMarkerPreviews()
        return
    end

    local marker = markerOf(unitFrame)
    if not marker then return end

    hookMarkerPreview(marker)

    if not mod:Get("previewMode") then
        if markerShown[marker] then
            markerShown[marker] = nil
            settingMarker = true
            pcall(marker.Hide, marker)
            settingMarker = false
        end
        return
    end

    markerShown[marker] = true

    -- Le crâne, posé sur la planche du client : c'est la même texture que ses
    -- vraies vignettes, et une unité réellement marquée reprendra la sienne au
    -- prochain marquage — le client repose l'icône lui-même.
    local icon = marker.RaidTargetIcon
    if type(icon) == "table" and type(icon.SetTexture) == "function" then
        pcall(icon.SetTexture, icon, T.TEXTURE.RAID_MARKERS)
        pcall(icon.SetTexCoord, icon, T.RaidMarkerCoords(8))
    end

    settingMarker = true
    pcall(marker.Show, marker)
    settingMarker = false
    pcall(marker.SetAlpha, marker, 1)
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

--- La case d'une rangée d'auras : « celle-ci est à nous », par opposition à
--- « celle-ci reste au jeu ». La case maîtresse ouvre la section, celle-ci dit
--- qui, de l'addon ou du jeu, affiche la rangée.
---@param key string  "ownAuraCc"
---@param tooltip string
---@return table
local function auraRowToggle(key, tooltip)
    return {
        type     = "toggle",
        key      = key,
        text     = L["Take over this row"],
        tooltip  = tooltip,
        disabled = AURAS_PAUSED and aurasPaused or requires("ownAuras"),
        disabledReason = AURAS_PAUSED and L["Auras paused"] or nil,
    }
end

--- Les six curseurs d'une rangée d'auras. Une fabrique alors qu'il ne reste
--- qu'une rangée : c'est ce qui a permis d'en retirer deux sans toucher à ce qui
--- les réglait, et ce qui permettra d'en rajouter une sans le récrire.
---@param prefix string  "auraCc"
---@param ownKey string  la case de cette rangée : ses réglages ne veulent rien
---       dire tant qu'elle est au jeu
---@return table  liste de descripteurs
local function auraSliders(prefix, ownKey)
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
            disabled = AURAS_PAUSED and aurasPaused
                       or requires("ownAuras", ownKey),
            disabledReason = AURAS_PAUSED and L["Auras paused"] or nil,
        }
    end

    -- Les six : plafond d'icônes, taille, décalages, écart entre deux icônes, et
    -- corps du décompte — tous redemandés rangée par rangée. Le décompte a son
    -- propre curseur parce qu'une entrave se lit à la seconde près, ce qui n'est
    -- pas vrai de tout ce qu'une rangée peut porter.
    --
    -- Le plafond vient en tête parce que c'est le réglage qui décide de ce qu'on
    -- voit ; les autres décident de la façon dont on le voit.
    return {
        slider("Max",   L["Aura max"],       L["Aura max tip"], 1,
               T.SIZE.PLATE_AURA_MAX),
        slider("Size",  L["Own aura size"],  L["Own aura size tip"], 12, 50),
        slider("X",     L["Aura offset X"],  L["Aura offset tip"], -60, 60),
        slider("Y",     L["Aura offset Y"],  L["Aura offset tip"], -60, 60),
        slider("Gap",   L["Aura gap"],       L["Aura gap tip"], 0, 12),
        slider("Timer", L["Aura timer size"], L["Aura timer size tip"], 6, 24),
    }
end

--- La case d'apparence d'une rangée : le contour commun de l'addon, ou le liseré
--- carré d'origine. Elle vit avec les curseurs de la rangée — elle décide de la
--- même chose qu'eux, à quoi ressemble une vignette — et porte donc le même
--- verrou : les réglages d'une rangée laissée au jeu ne veulent rien dire.
---@param key string  "auraCcShaded"
---@param ownKey string
---@return table
local function auraShadeToggle(key, ownKey)
    return {
        type     = "toggle",
        key      = key,
        text     = L["Aura shaded"],
        tooltip  = L["Aura shaded tip"],
        indent   = true,
        disabled = AURAS_PAUSED and aurasPaused or requires("ownAuras", ownKey),
        disabledReason = AURAS_PAUSED and L["Auras paused"] or nil,
    }
end

--- Un curseur du marqueur. Même fabrique que ceux des rangées, et pour la même
--- raison : ils portent le même verrou, et trois descripteurs recopiés seraient
--- trois occasions d'en oublier un le jour où la pause se lève.
---@param key string
---@param text string
---@param tooltip string
---@param min number
---@param max number
---@return table
local function markerSlider(key, text, tooltip, min, max)
    return {
        type     = "slider",
        key      = key,
        text     = text,
        tooltip  = tooltip,
        min      = min,
        max      = max,
        step     = 1,
        indent   = true,
        disabled = AURAS_PAUSED and aurasPaused or requires("marker"),
        disabledReason = AURAS_PAUSED and L["Auras paused"] or nil,
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
-- Quand notre réglage est allumé, la ligne du client est **poussée au maximum
-- puis grisée** — voir `applyClientGauge`, qui dit pourquoi c'est le maximum et
-- non le cran du joueur. Le CVar est emprunté, donc rendu en décochant.
--
-- On avait d'abord essayé le contraire : ne rien écrire, et se contenter de
-- griser. Le calibre restait celui du joueur, ce qui semblait plus poli — mais
-- au cran trois, la boîte est trop petite pour la moitié de la course de nos
-- curseurs, et une glissière qui ne fait plus rien passé son milieu est pire
-- qu'un réglage qu'on emprunte et qu'on rend.

---@return boolean
local function sizeTaken()
    if InCombatLockdown() then return true end
    local mod = module()
    return mod ~= nil and mod:Get("resize") == true
end

local SIZE_LOCK = {
    disabled = sizeTaken,
    reason   = function()
        if InCombatLockdown() then return L["Cannot change in combat"] end
        return L["Taken over by the addon"]
    end,
}

--- Les trois champs de bits qui commandent les rangées d'auras du client — un
--- par famille d'unités — et l'énumération qui nomme leurs catégories.
---
--- **On n'éteint plus le champ entier.** Il tombait à zéro, et avec lui les
--- quatre catégories : prendre les affaiblissements coûtait les améliorations,
--- les contrôles et la perte de contrôle. Or le client sait éteindre une
--- catégorie seule (`SetCVarBitfield`), ce qui permet le mélange que la case
--- unique interdisait — nos affaiblissements au-dessus de ses améliorations à
--- lui.
---
--- Chaque CVar a **sa propre** énumération, et rien ne garantit que les mêmes
--- catégories y portent le même numéro : on cherche donc l'index par nom, dans
--- l'énumération de ce CVar-là, et une catégorie inconnue se saute (règle 1).
local CLIENT_AURA_CVARS = {
    { cvar = "nameplateEnemyNpcAuraDisplay",
      enum = Enum.NamePlateEnemyNpcAuraDisplay },
    { cvar = "nameplateEnemyPlayerAuraDisplay",
      enum = Enum.NamePlateEnemyPlayerAuraDisplay },
    { cvar = "nameplateFriendlyPlayerAuraDisplay",
      enum = Enum.NamePlateFriendlyPlayerAuraDisplay },
}

--- nom du CVar -> index de bit -> ce que le bit valait avant nous.
---
--- On relève **le bit**, pas le champ : sa valeur d'avant se demande au client
--- (`GetCVarBitfield`) au lieu de se déduire du nombre par une arithmétique qui
--- supposerait son encodage. Rendre, c'est reposer ce qu'il a répondu.
local savedBits = {}

--- Pose un bit à la valeur voulue, et seulement s'il ne l'a pas déjà : le client
--- annonce chaque écriture de CVar, et la veille qui reprend la main est branchée
--- sur cette annonce (voir `takeCVar`).
---@param cvar string
---@param index number
---@param wanted boolean
local function setCVarBit(cvar, index, wanted)
    if not (C_CVar and C_CVar.GetCVarBitfield and C_CVar.SetCVarBitfield) then return end

    local ok, current = pcall(C_CVar.GetCVarBitfield, cvar, index)
    if ok and (current == true) == wanted then return end

    pcall(C_CVar.SetCVarBitfield, cvar, index, wanted)
end

--- Éteint une catégorie chez le client, en relevant ce qu'elle valait.
---@param cvar string
---@param index number
local function takeCVarBit(cvar, index)
    if not (C_CVar and C_CVar.GetCVarBitfield) then return end

    local saved = savedBits[cvar]
    if not saved then saved = {} savedBits[cvar] = saved end

    if saved[index] == nil then
        local ok, was = pcall(C_CVar.GetCVarBitfield, cvar, index)
        if not ok then return end
        saved[index] = was == true
    end

    setCVarBit(cvar, index, false)
end

--- Rend une catégorie, si elle était à nous. Sinon ne touche à rien : un bit
--- qu'on n'a jamais pris n'est pas à nous, même s'il est éteint.
---@param cvar string
---@param index number
local function giveBackCVarBit(cvar, index)
    local saved = savedBits[cvar]
    local was = saved and saved[index]
    if was == nil then return end

    saved[index] = nil
    setCVarBit(cvar, index, was)
end

--- Rend toutes les catégories prises. Appelé à l'extinction du module : une
--- rangée éteinte doit être indétectable (règle 6).
local function giveBackCVarBits()
    for cvar, saved in pairs(savedBits) do
        for index, was in pairs(saved) do
            setCVarBit(cvar, index, was)
        end
        wipe(saved)
    end
    wipe(savedBits)
end

--- Une catégorie du client est-elle grisée ? Seulement si c'est la rangée
--- correspondante que l'addon a prise — les autres restent réglables, et c'est
--- tout l'objet du découpage.
---@param member string  nom du membre d'énumération
---@return boolean
local function auraBitTaken(member)
    if InCombatLockdown() then return true end

    local mod = module()
    for g = 1, #AURA_GROUPS do
        local group = AURA_GROUPS[g]
        if group.bit == member then return rowTaken(mod, group) end
    end

    return false
end

--- Le verrou d'une catégorie d'auras du client, fabriqué pour elle : c'est ce
--- qui distingue « l'addon tient les affaiblissements » de « l'addon tient tout ».
---@param member string
---@return table
local function auraLock(member)
    return {
        disabled = function() return auraBitTaken(member) end,
        reason   = function()
            if InCombatLockdown() then return L["Cannot change in combat"] end
            return L["Auras taken over"]
        end,
    }
end

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

--- Les trois champs d'auras du client partagent leur vocabulaire : ce sont les
--- mêmes catégories, appliquées à trois familles d'unités. Une seule table, donc.
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

-- -------------------------------------------------------------------------
--  Deux réglages du client qui font la même chose
-- -------------------------------------------------------------------------
-- « Ne montrer que le nom des joueurs alliés » et « barre simplifiée pour les
-- joueurs alliés » réduisent la même plaque à la même chose. Cochés tous les
-- deux, le second ne fait rien de plus — mais il **reste coché**, et le jour où
-- l'on décoche le premier on ne retrouve pas ce qu'on croyait retrouver.
--
-- Allumer le premier décoche donc le second, et le grise tant qu'il est allumé.
-- Décocher le premier ne le recoche pas : ce serait décider à la place du joueur
-- d'un réglage qu'il n'avait peut-être jamais mis.
--
-- Écrire dans un réglage du client au clic du joueur est exactement ce que fait
-- le reste de cette moitié de page : c'est sa case à lui, cochée depuis chez
-- nous. Rien n'est donc emprunté ici, et il n'y a rien à rendre.

--- Le verrou d'une catégorie de barre simplifiée. Seuls les joueurs alliés en
--- ont un : les trois autres n'ont pas de réglage qui les double.
---@param member string
---@return table
local function simplifiedLock(member)
    if member ~= "FriendlyPlayer" then
        return { disabled = inCombat, reason = L["Cannot change in combat"] }
    end

    return {
        disabled = function()
            return inCombat() or U.GetCVar(CVAR.ALLY_NAMES) == "1"
        end,
        reason = function()
            if InCombatLockdown() then return L["Cannot change in combat"] end
            return L["Simplified taken by names only"]
        end,
    }
end

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
---@param lock? table|fun(member: string): table  verrou commun, ou fabriqué par
---       catégorie quand elles ne se prennent pas ensemble
---@return table  liste de descripteurs
local function bitfieldGroup(cvar, enum, labels, tooltip, lock)
    local rows = {}
    if U.GetCVar(cvar) == nil then return rows end

    local members = enumMembers(enum)

    for i = 1, #members do
        local member  = members[i]
        local get, set = bitfieldToggle(cvar, member.value)

        -- Le verrou peut être **fabriqué par catégorie** : les rangées d'auras
        -- se prennent une par une, et une case grisée quand rien ne la tient
        -- serait aussi menteuse qu'une case active sur un réglage pris.
        local rowLock = type(lock) == "function" and lock(member.name) or lock

        rows[#rows + 1] = {
            type    = "toggle",
            text    = labels[member.name] or member.name,
            tooltip = tooltip,
            get     = get,
            set     = set,
            disabled = rowLock and rowLock.disabled or inCombat,
            disabledReason = rowLock and rowLock.reason or L["Cannot change in combat"],
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

--- La case « ne montrer que le nom des joueurs alliés ».
---
--- C'est une case du client comme les autres, à ceci près qu'allumée elle
--- décoche celle qui la double (voir « Deux réglages du client qui font la même
--- chose »). Le geste est enchaîné à l'écriture, et non posté sur un événement :
--- c'est le même clic, il doit avoir le même effet à l'écran.
---@return table
local function allyNamesRow()
    local row = blizzToggle(CVAR.ALLY_NAMES,
        L["Allied names only"], L["Allied names only tip"])
    if not row.type then return row end

    -- L'index du bit se demande à l'énumération, jamais écrit en dur : une
    -- catégorie que ce client ne connaît pas rend `nil`, et il n'y a alors rien
    -- à décocher (règle 1).
    local set = row.set
    row.set = function(value)
        set(value)

        if value and not InCombatLockdown()
           and C_CVar and C_CVar.SetCVarBitfield then
            local enum  = Enum.NamePlateSimplifiedType
            local index = type(enum) == "table" and enum.FriendlyPlayer or nil
            if type(index) == "number" then
                pcall(C_CVar.SetCVarBitfield, "nameplateSimplifiedTypes",
                      index, false)
            end
        end

        -- **La page se redemande dans les deux sens, coché comme décoché.** Une
        -- case branchée sur un réglage du client n'écrit pas dans les nôtres :
        -- aucun message ne part de lui-même, et rien ne redessine la page. En
        -- cochant, la case d'en face gardait sa coche alors qu'on venait de la
        -- retirer ; en décochant, elle restait grisée alors qu'elle était rendue,
        -- et les deux lignes d'ici restaient actives alors qu'elles ne servaient
        -- plus à rien. Trois lignes qui mentent, faute d'un rafraîchissement.
        BUI:SendMessage(BUI.MESSAGES.SETTING_CHANGED, MODULE)
    end

    return row
end

--- Les trois lignes de la superposition : l'interrupteur et ses deux glissières.
---
--- Elles sont à nous et non branchées en direct sur le CVar, pour la raison
--- écrite dans la table `CVAR` : le client réécrit ces deux valeurs, et un
--- réglage qu'on ne reprend jamais revient tout seul au sien.
---@return table[]
local function overlapRows()
    if U.GetCVar(CVAR.OVERLAP_H) == nil or U.GetCVar(CVAR.OVERLAP_V) == nil then
        return {}
    end

    local bounds = { min = 0.4, max = 3, step = 0.05, decimals = 2 }

    return {
        {
            type    = "toggle",
            key     = "overlap",
            text    = L["Tune overlap"],
            tooltip = L["Tune overlap tip"],
        },
        {
            type     = "slider",
            key      = "overlapH",
            text     = L["Horizontal overlap"],
            tooltip  = L["Overlap tip"],
            min      = bounds.min,
            max      = bounds.max,
            step     = bounds.step,
            decimals = bounds.decimals,
            indent   = true,
            disabled = requires("overlap"),
        },
        {
            type     = "slider",
            key      = "overlapV",
            text     = L["Vertical overlap"],
            tooltip  = L["Overlap tip"],
            min      = bounds.min,
            max      = bounds.max,
            step     = bounds.step,
            decimals = bounds.decimals,
            indent   = true,
            disabled = requires("overlap"),
        },
    }
end

-- =========================================================================
--  Peinture
-- =========================================================================

--- La peinture **légère** : les deux couleurs que le client vient d'effacer, et
--- rien d'autre.
---
--- C'est elle que déclenchent les deux fonctions coiffées par `hookPainting`, et
--- elles se déclenchent à **chaque battement de vie de chaque plaque** — soit,
--- au plus fort d'une pull, quelques centaines de fois par seconde.
---
--- Tout ce qui n'est pas une couleur en a donc été retiré. Une hauteur de barre,
--- un corps de texte, une texture, une opacité, une rangée d'auras, un marqueur :
--- rien de tout cela ne bouge parce qu'un adversaire a perdu des points de vie,
--- et chacun a **son propre hook gardé** pour se reposer le jour où le client y
--- touche. Les repayer ici, c'était refaire cent fois par seconde un travail que
--- personne n'avait défait — et fabriquer au passage, à chaque fois, les
--- fermetures et les clés de tous ces hooks (règle 7).
---
--- Les couleurs restent, elles : la barre de vie est précisément ce que le
--- client vient de repeindre en nous appelant.
---@param mod table
---@param unitFrame table
---@param unit string
local function tint(mod, unitFrame, unit)
    local bar = healthBarOf(unitFrame)
    if bar and type(bar.SetStatusBarColor) == "function" then
        local r, g, b = healthColor(mod, unit)
        pcall(bar.SetStatusBarColor, bar, r, g, b)
    end

    local name = unitFrame.name
    if type(name) == "table" and type(name.SetTextColor) == "function" then
        local ok, r, g, b = nameColor(unit)
        if ok then
            settingNameColor = true
            pcall(name.SetTextColor, name, r, g, b)
            settingNameColor = false
        end
    end
end

--- La peinture **complète** : tout ce qu'une plaque porte de nous.
---
--- Elle ne tourne qu'aux moments où quelque chose a réellement pu changer : une
--- plaque qui change de main, un changement de cible, de camp, de menace, de
--- spécialisation, une frontière de zone, un réglage touché. Jamais sur un
--- battement de vie — voir `tint`, juste au-dessus.
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

    local name = unitFrame.name
    if type(name) == "table" and type(name.SetTextColor) == "function" then
        -- Posé à chaque peinture complète, comme le hook du corps des textes :
        -- la pose est idempotente (`U.GuardedHook` ne pose qu'une fois par
        -- cadre), et attendre un autre moment reviendrait à attendre qu'une
        -- plaque repasse ici après coup.
        hookNameColor(name, unitFrame)
    end

    tint(mod, unitFrame, unit)

    applyBarTexture(mod, unitFrame, isTarget)
    applyBarHeight(mod, unitFrame)
    applyCastSize(mod, unitFrame)
    applyCastPreview(mod, unitFrame)
    applyOwnAuras(mod, plate, unit)
    applyTextSize(mod, unitFrame)
    applyAllyName(mod, unitFrame, unit)
    applyMarkerPreview(mod, unitFrame)
    placeMarker(mod, unitFrame)
end

--- Repeint **toutes** les plaques à l'écran.
---
--- Elle recense avant de peindre, et ce n'est pas une précaution de plus : la
--- liste des plaques est tenue par les annonces du client, et une annonce
--- manquée ne se rattrape jamais. Le cas se produit à chaque `/reload` — le
--- client ne réannonce pas ce qui était déjà là — et à chaque fois qu'on allume
--- le module devant quelqu'un. La plaque restait alors inconnue **pour toute la
--- session** : rien n'y était peint, aucun hook n'y était posé, et cocher une
--- case ne changeait rien sur elle. Un allié campé devant vous depuis le
--- rechargement suffisait à faire croire que le réglage ne marchait pas.
---
--- Le recensement est un appel et une boucle sur ce qui est visible : quelques
--- dizaines de plaques au plus fort d'une pull, et jamais depuis un chemin
--- chaud — cette fonction ne tourne qu'aux moments où un réglage, une cible ou
--- une zone changent.
---@param mod table
local function paintAll(mod)
    collectPlates()

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
    local unitFrame = unitFrameOf(plate)
    if not unitFrame then return nil end

    releaseAlpha(unitFrame)

    -- Les rangées d'auras ne survivent pas au recyclage : le prochain occupant
    -- de cette plaque hériterait des auras du précédent le temps d'une
    -- repeinture.
    local rows = auraRows[plate]
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
    releaseAllAlpha()
    restoreBarHeights()
    restoreBarTextures()
    restoreCastSizes()
    restoreAllyNames()
    restoreTextSizes()
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
--
-- Ce sont aussi les deux fonctions les plus **fréquentes** du client sur une
-- plaque : la première part à chaque battement de vie. Ce qu'on y fait tient
-- donc dans `tint`, et pas une écriture de plus.

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

--- Pas de garde de récursion, et ce n'est pas un oubli : notre repeinture ne
--- pose que deux couleurs — aucune de ces écritures ne rappelle les deux
--- fonctions coiffées ici. Le seul endroit qui les rappelle est `release`, et il
--- ne tourne qu'une fois le module déjà éteint, donc une fois le hook déjà
--- inerte. Un drapeau de plus n'aurait rien gardé, et resterait levé pour
--- toujours le jour où une écriture lèverait au milieu.
local function hookPainting()
    local guard = function()
        local mod = module()
        return mod ~= nil and mod:IsEnabled()
    end

    local function repaint(unitFrame)
        local unit = trackedUnit(unitFrame)
        if not unit then return end

        -- Le garde que `paint` prenait par `unitFrameOf` : le client nous tend
        -- ici le cadre sans passer par la plaque, et un cadre interdit — ceux
        -- d'une arène — lève à la première méthode appelée dessus.
        if isForbidden(unitFrame) then return end

        local mod = module()
        if mod then tint(mod, unitFrame, unit) end
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
    applyOverlap(mod)
    applyAlpha(mod)
    paintAll(mod)
end

--- Les deux groupes de réglages qui demandent autre chose qu'un repassage : ceux
--- qui écrivent un CVar. Tout ce qui n'est pas listé ici se contente d'être
--- repeint, ce qui est le cas de la quasi-totalité de la page.
local SIZE_KEYS  = { resize = true, width = true, height = true,
                     textSize = true,
                     resizeAllyName = true, allyNameSize = true,
                     castTextSize = true,
                     previewMode = true,
                     resizeCast = true, castHeight = true }
local ALPHA_KEYS = { visibility = true, targetAlpha = true, otherAlpha = true,
                     occludedAlpha = true }

--- Les cases qui déplacent la frontière entre notre rangée et celles du client :
--- la maîtresse et celle de la rangée. Elles écrivent un bit de CVar, donc elles
--- ne se contentent pas d'un repassage.
local AURA_TAKE_KEYS = { ownAuras = true }
for g = 1, #AURA_GROUPS do
    AURA_TAKE_KEYS[AURA_GROUPS[g].own] = true
end

--- Les réglages de texture : un repassage suffit, sauf l'extinction, qui rend
--- leurs images aux barres.
local TEXTURE_KEYS = { barTexture = true, textureOther = true,
                       textureTarget = true }

--- Les CVars que chaque interrupteur rend quand on l'éteint. Déclarés ici plutôt
--- que construits dans la fonction : une table bâtie à chaque clic est une table
--- de trop.
local TAKEN_CVARS = {
    alpha   = { CVAR.OCCLUDED },
    size    = { CVAR.SIZE },
    overlap = { CVAR.OVERLAP_H, CVAR.OVERLAP_V },
}

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

--- Accorde les catégories d'auras du client avec les rangées qu'on affiche :
--- **une prise par rangée, pas une pour toutes**.
---
--- Chaque rangée allumée éteint sa catégorie chez lui — deux rangées d'auras sur
--- une plaque, ce sont deux fois les mêmes icônes à deux endroits. Chaque rangée
--- éteinte lui rend la sienne, telle qu'elle était. Les cases correspondantes se
--- grisent une par une (`auraLock`), pour que la page dise laquelle ne répond
--- plus et pourquoi.
---
--- **Refusé en combat**, comme tous les réglages du client dans cette page. Ce
--- qui a été refusé est repassé à la sortie de combat, par le même abonnement
--- que la largeur de plaque.
---@param mod table
local function applyClientAuras(mod)
    if not LIVE.auras or AURAS_PAUSED then return end
    if InCombatLockdown() then return end

    for g = 1, #AURA_GROUPS do
        local group = AURA_GROUPS[g]
        local taken = rowTaken(mod, group)

        for i = 1, #CLIENT_AURA_CVARS do
            local entry = CLIENT_AURA_CVARS[i]
            local index = type(entry.enum) == "table" and entry.enum[group.bit]

            -- Un CVar que le client ne connaît pas, ou une catégorie absente de
            -- son énumération : il n'y a rien à prendre et rien à rendre.
            if type(index) == "number" and U.GetCVar(entry.cvar) ~= nil then
                if taken then
                    takeCVarBit(entry.cvar, index)
                else
                    giveBackCVarBit(entry.cvar, index)
                end
            end
        end
    end
end

--- Prend au client sa **couleur de menace sur la barre de vie** quand la nôtre
--- est allumée, et la lui rend en décochant.
---
--- Les deux repeignent la même barre pour dire la même chose : cochées ensemble,
--- l'une écrase l'autre selon qui a peint en dernier, et le joueur voit une
--- couleur de menace qui n'est ni celle qu'il a choisie ni celle du jeu. C'est le
--- même emprunt que partout ailleurs ici — on relève le bit, on l'éteint, on le
--- repose tel quel — et la case du client se grise pendant ce temps, avec son
--- motif.
---@param mod table
local function applyClientThreat(mod)
    if not LIVE.threat then return end
    if InCombatLockdown() then return end

    local cvar = "nameplateThreatDisplay"
    if U.GetCVar(cvar) == nil then return end

    -- L'index se demande à l'énumération : une catégorie que ce client ne
    -- connaît pas rend `nil`, et il n'y a alors rien à prendre (règle 1).
    local enum  = Enum.NamePlateThreatDisplay
    local index = type(enum) == "table" and enum.HealthBarColor or nil
    if type(index) ~= "number" then return end

    if mod:Get("threatColors") then
        takeCVarBit(cvar, index)
    else
        giveBackCVarBit(cvar, index)
    end
end

--- Rend au jeu les catégories d'auras que la rangée de l'addon lui avait prises,
--- pour les joueurs qui l'utilisaient avant qu'elle ne soit retirée.
---
--- L'extinction ordinaire ne peut rien ici : ce qu'on a pris est écrit dans les
--- **réglages du client**, qui survivent à la session, alors que le relevé de ce
--- qu'ils valaient avant nous, lui, ne survit pas. Un joueur qui avait pris la
--- rangée se retrouverait sans contrôles sur ses plaques, sans rien qui le dise
--- et sans case à décocher pour le réparer.
---
--- Nos réglages, eux, survivent : ils disent que la catégorie était à nous. On la
--- rend **allumée**, qui est ce que le jeu livre — sa valeur d'avant est perdue
--- avec la session où on l'a prise — puis on éteint la case, pour que le geste
--- n'ait lieu qu'une fois. Un joueur qui l'avait déjà éteinte chez lui n'a qu'à
--- la décocher dans la moitié gauche de la page.
---@param mod table
local function releaseClientAuras(mod)
    if LIVE.auras then return end
    if InCombatLockdown() then return end
    if not mod:Get("ownAuras") then return end

    for g = 1, #AURA_GROUPS do
        local group = AURA_GROUPS[g]

        if mod:Get(group.own) then
            for i = 1, #CLIENT_AURA_CVARS do
                local entry = CLIENT_AURA_CVARS[i]
                local index = type(entry.enum) == "table" and entry.enum[group.bit]

                if type(index) == "number" and U.GetCVar(entry.cvar) ~= nil then
                    setCVarBit(entry.cvar, index, true)
                end
            end

            mod:Set(group.own, false)
        end
    end

    mod:Set("ownAuras", false)
end

--- Rend la taille : la hauteur à chaque barre épaissie, la largeur aux plaques.
--- Le calibre du client, lui, n'a jamais été pris — il n'y a rien à lui rendre.
local function giveBackSize()
    restoreBarHeights()
    restorePlateWidth()
    giveBack(TAKEN_CVARS.size)
end
--- La page, telle qu'elle se lit de haut en bas.
---
--- **Une fonction, et non le tableau posé à même la déclaration du module.**
--- La raison est un plafond du compilateur : le Lua du client borne à deux cent
--- cinquante les registres d'une fonction, et une liste de cent descripteurs en
--- réclame une cinquantaine à elle seule. Ajoutés aux variables de ce fichier,
--- qui en compte près de deux cents, on passait la borne — et ce n'est pas la
--- ligne fautive qui tombait, ni la page : **le fichier entier** refusait de se
--- compiler (`function or expression too complex`), donc le module, donc son
--- entrée dans le menu.
---
--- Une fonction repart de zéro registre. C'est le seul remède, et la
--- déclaration du module y gagne : elle tient désormais dans un écran.
---@return table[]
local function pageOptions()
    return liveOptions({
        -- ------------------------------------------------------------------
        --  Ce qui appartient au jeu
        -- ------------------------------------------------------------------
        { section = "blizzard" },
        { type = "header", text = L["Blizzard settings"] },
        -- L'étiquette de la moitié gauche. Rouge, comme celle d'en face : elle
        -- dit d'où viennent les réglages qui suivent, et c'est ce qu'on lit en
        -- premier sur cette page. Voir `W.Alert`.
        { type = "alert",  text = L["Blizzard settings notice"] },

        -- Le premier bloc n'avait pas de titre : il commençait sous la note, et
        -- se lisait donc comme la suite de celle-ci. « Général » est le nom que
        -- le jeu donne lui-même à ce groupe — qui montre une barre d'infos, et
        -- sur quoi.
        { type = "header", text = L["General"] },
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

        -- La maquette du client vivait ici, au-dessus de ce qu'elle illustrait.
        -- **Elle est partie, et elle ne revient pas** : la monter réveille son
        -- gestionnaire de barres d'infos, qui repasse sur les vraies plaques en
        -- étant teinté par nous — une erreur dans son code, et les tailles
        -- rendues à celles de Blizzard à chaque ouverture de cette fenêtre.
        -- Le détail est dans `UI/Widgets/PlatePreview.lua`.

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
            { min = 1, max = T.SIZE.PLATE_GAUGE_MAX, step = 1 }, SIZE_LOCK),

        -- En pourcentage, par pas de dix : le client range un multiplicateur, mais
        -- « 1,20 » ne se lit pas comme une taille. Les bornes sont celles où la
        -- vignette reste une vignette — au-delà elle mange la plaque, en deçà elle
        -- n'est plus reconnaissable.
        --
        -- Elles ne portent **plus** le verrou du calibre : ce sont des mesures
        -- d'auras, pas de barres, et notre taille en pixels ne les décide pas.
        -- Elles l'ont porté le temps que la largeur de boîte et la hauteur de
        -- barre apprennent à se reposer seules (`hookPlateSize`, `hookBarHeight`).
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
        -- Le verrou est fabriqué ici, à l'endroit qui s'en sert, plutôt que dans
        -- une variable de plus : ce fichier compte les siennes (voir
        -- `pageOptions`). Seule la couleur de barre de vie a un double chez nous.
        bitfieldGroup("nameplateThreatDisplay", Enum.NamePlateThreatDisplay,
            THREAT_LABELS, L["Threat display tip"], function(member)
                if member ~= "HealthBarColor" then
                    return { disabled = inCombat,
                             reason = L["Cannot change in combat"] }
                end

                return {
                    disabled = function()
                        if inCombat() then return true end
                        local mod = module()
                        return mod ~= nil and mod:Get("threatColors") == true
                    end,
                    reason = function()
                        if InCombatLockdown() then
                            return L["Cannot change in combat"]
                        end
                        return L["Threat taken over"]
                    end,
                }
            end),

        -- Trois rangées d'auras, une par famille d'unités. Le client les range
        -- dans trois CVars distincts et leur donne trois énumérations distinctes,
        -- alors que les catégories sont les mêmes : on garde ses trois listes
        -- plutôt que de les fondre, pour que la page dise ce que le jeu fait.
        { type = "header", text = L["Enemy NPC auras"] },
        bitfieldGroup("nameplateEnemyNpcAuraDisplay", Enum.NamePlateEnemyNpcAuraDisplay,
            AURA_LABELS, L["Auras tip"], auraLock),

        { type = "header", text = L["Enemy player auras"] },
        bitfieldGroup("nameplateEnemyPlayerAuraDisplay", Enum.NamePlateEnemyPlayerAuraDisplay,
            AURA_LABELS, L["Auras tip"], auraLock),

        { type = "header", text = L["Friendly player auras"] },
        bitfieldGroup("nameplateFriendlyPlayerAuraDisplay", Enum.NamePlateFriendlyPlayerAuraDisplay,
            AURA_LABELS, L["Auras tip"], auraLock),

        { type = "header", text = L["Simplified nameplates"] },
        -- Un verrou fabriqué par catégorie : seuls les joueurs alliés ont un
        -- réglage qui les double, et une case grisée quand rien ne la tient
        -- serait aussi menteuse qu'une case active sur un réglage pris.
        bitfieldGroup("nameplateSimplifiedTypes", Enum.NamePlateSimplifiedType,
            SIMPLIFIED_LABELS, L["Simplified nameplates tip"], simplifiedLock),

        -- ------------------------------------------------------------------
        --  Ce que l'addon ajoute
        -- ------------------------------------------------------------------
        -- Les deux moitiés de la page se lisent **toujours** côte à côte : ce qui
        -- appartient au jeu à gauche, ce qu'on ajoute à droite. C'est la seule
        -- page de l'addon où la coupure est un ordre et non un vœu, et le motif
        -- n'est pas la hauteur gagnée : un réglage de l'addon se comprend en
        -- regardant celui du jeu qu'il double ou qu'il grise. L'un sous l'autre,
        -- il n'y a plus rien à comparer, seulement une longue page à parcourir.
        --
        -- La fenêtre s'élargit d'elle-même en entrant ici, et rend au joueur sa
        -- largeur en sortant (voir `UI/Config/ConfigFrame.lua`).
        { section = "own" },
        { type = "column", required = true },
        { type = "header", text = L["Bshamel UI options"] },
        { type = "alert",  text = L["Bshamel UI options notice"] },

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
        -- Les deux mesures immédiatement sous leur interrupteur : c'est ce qu'on
        -- vient chercher en le cochant, et rien ne doit s'intercaler entre une
        -- case et ce qu'elle commande.
        {
            type     = "slider",
            key      = "width",
            text     = L["Nameplate width"],
            tooltip  = L["Nameplate width tip"],
            min      = 60,
            max      = 400,
            step     = 2,
            indent   = true,
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
            indent   = true,
            disabled = requires("resize"),
        },
        -- Le corps du texte est la troisième mesure de la barre, sous les deux
        -- autres et sous le même interrupteur : il n'a plus le sien.
        {
            type     = "slider",
            key      = "textSize",
            text     = L["Nameplate text size"],
            tooltip  = L["Nameplate text size tip"],
            min      = 6,
            max      = 24,
            step     = 1,
            indent   = true,
            disabled = requires("resize"),
        },

        -- La texture du remplissage **dans** la barre de vie, sans en-tête à
        -- elle : c'est la barre de vie qu'elle habille, et un titre de plus pour
        -- trois lignes coupait la section en deux pour rien.
        --
        -- Elle garde sa propre marque de section : le découpage de `LIVE` ne
        -- suit pas les en-têtes mais ce qui se valide ensemble, et la texture
        -- s'est validée séparément de la taille. La marque suivante rend la
        -- suite à `size`.
        { section = "textures" },
        {
            type    = "toggle",
            key     = "barTexture",
            text    = L["Set the bar texture"],
            tooltip = L["Set the bar texture tip"],
        },
        -- La cible d'abord : c'est la barre qu'on regarde, et celle dont on
        -- change la texture en premier. « Les autres » se règle par différence.
        {
            type     = "dropdown",
            key      = "textureTarget",
            text     = L["Target bar texture"],
            tooltip  = L["Target bar texture tip"],
            values   = BAR_TEXTURE_VALUES,
            indent   = true,
            disabled = requires("barTexture"),
        },
        {
            type     = "dropdown",
            key      = "textureOther",
            text     = L["Others bar texture"],
            tooltip  = L["Others bar texture tip"],
            values   = BAR_TEXTURE_VALUES,
            indent   = true,
            disabled = requires("barTexture"),
        },

        { section = "size" },
        -- L'opacité ferme la barre de vie. Elle n'a plus de section à elle : trois
        -- opacités et un interrupteur ne font pas une catégorie, ils font la
        -- dernière chose qu'on règle sur une barre — après sa taille, sa texture
        -- et son texte, ce qu'on en voit.
        { section = "visibility" },
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
            indent   = true,
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
            indent   = true,
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
            indent   = true,
            disabled = requires("visibility"),
        },

        -- Le nom des alliés, en dernières lignes de la barre de vie : c'est elle
        -- que le mode « nom seul » remplace, et c'est là qu'on vient le chercher.
        -- Le client sait le faire lui-même, mais son menu ne le propose nulle
        -- part — d'où la case ici plutôt que dans la section des réglages du jeu.
        --
        -- **Sans titre au-dessus.** Trois lignes ne font pas une section, et
        -- « Alliés » en tête n'aurait dit qu'une chose que les trois intitulés
        -- disent déjà.
        --
        -- Les deux lignes en retrait ne veulent rien dire sans le mode nom seul :
        -- c'est là que le corps du nom compte, puisqu'il ne reste que lui. Elles
        -- se grisent donc avec lui, en plus de se griser entre elles. La couleur
        -- de classe, elle, vaut pour toute plaque alliée et reste au bord.
        { section = "size" },
        allyNamesRow(),
        {
            type     = "toggle",
            key      = "resizeAllyName",
            text     = L["Resize ally names"],
            tooltip  = L["Resize ally names tip"],
            indent   = true,
            disabled = function() return U.GetCVar(CVAR.ALLY_NAMES) ~= "1" end,
            disabledReason = L["Needs allied names only"],
        },
        {
            type     = "slider",
            key      = "allyNameSize",
            text     = L["Ally name size"],
            tooltip  = L["Resize ally names tip"],
            min      = 6,
            max      = 32,
            step     = 1,
            indent   = true,
            disabled = function()
                local mod = module()
                return U.GetCVar(CVAR.ALLY_NAMES) ~= "1"
                    or not (mod and mod:Get("resizeAllyName"))
            end,
            -- Le motif n'est donné que pour celui qui ne se devine pas : « la
            -- case du dessus est décochée » se lit sur la case du dessus.
            disabledReason = function()
                if U.GetCVar(CVAR.ALLY_NAMES) ~= "1" then
                    return L["Needs allied names only"]
                end
            end,
        },
        -- « Noms aux couleurs de classe » vivait ici. Le jeu le fait désormais
        -- de lui-même, et mieux : lui seul lit l'identité qu'il protège en
        -- instance. Une case qui promet ce qui arrive déjà est une case qui
        -- ment, quelle que soit sa position.

        -- La barre de sorts suit immédiatement la barre de vie : c'est l'autre
        -- barre de la plaque, et elle se règle des mêmes façons.
        { section = "size" },
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
            indent   = true,
            disabled = requires("resizeCast"),
        },
        -- Même règle que sur la barre de vie : le corps du texte suit
        -- l'interrupteur de sa barre.
        {
            type     = "slider",
            key      = "castTextSize",
            text     = L["Cast text size"],
            tooltip  = L["Cast text size tip"],
            min      = 6,
            max      = 24,
            step     = 1,
            indent   = true,
            disabled = requires("resizeCast"),
        },

        -- Le chevauchement des plaques entre elles : la place que chacune garde
        -- avant que le jeu ne pousse la voisine. Deux réglages du client que son
        -- menu n'expose pas.
        --
        -- Il ferme les deux barres : c'est encore une mesure, celle de la place
        -- que prend la boîte qu'on vient de régler.
        { section = "overlap" },
        { type = "header", text = L["Stacking"] },
        overlapRows(),

        -- Les auras et le marqueur sous un seul en-tête : ils se règlent de la
        -- même façon — une taille, deux décalages, un écart — et ils se
        -- regardent ensemble sur la même plaque.
        --
        -- Ils viennent avant les couleurs : ce sont des choses qu'on **ajoute**
        -- à la plaque, alors que tout ce qui suit — couleurs, menace — repeint
        -- ce qui y est déjà.
        { section = "auras" },
        { type = "header", text = L["Auras and marker"] },
        { type = "description",
          text = AURAS_PAUSED and L["Auras paused notice"] or L["Auras notice"] },
        {
            type    = "toggle",
            key     = "ownAuras",
            text    = L["Own auras"],
            tooltip = L["Own auras tip"],
            disabled = AURAS_PAUSED and aurasPaused or nil,
            disabledReason = AURAS_PAUSED and L["Auras paused"] or nil,
        },

        -- La rangée ouvre par sa propre case. Décochée, le jeu garde les
        -- entraves et les affiche comme il l'a toujours fait.
        { type = "header", text = L["Crowd control auras"] },
        { type = "description", text = L["Crowd control auras notice"] },
        auraRowToggle("ownAuraCc", L["Take over crowd control tip"]),
        auraShadeToggle("auraCcShaded", "ownAuraCc"),
        auraSliders("auraCc", "ownAuraCc"),

        -- Le marqueur ferme la section : il se règle comme une rangée — une
        -- taille, deux décalages.
        { section = "marker" },
        { type = "header", text = L["Raid marker"] },
        {
            type    = "toggle",
            key     = "marker",
            text    = L["Place raid marker"],
            tooltip = L["Place raid marker tip"],
            disabled = AURAS_PAUSED and aurasPaused or nil,
            disabledReason = AURAS_PAUSED and L["Auras paused"] or nil,
        },
        markerSlider("markerSize", L["Marker size"], L["Marker size tip"], 8, 64),
        markerSlider("markerX", L["Marker offset X"], L["Marker offset tip"], -60, 60),
        markerSlider("markerY", L["Marker offset Y"], L["Marker offset tip"], -60, 60),

        { section = "colors" },
        { type = "header", text = L["Enemy colors"] },
        {
            type    = "toggle",
            key     = "npcColors",
            text    = L["Color enemies by kind"],
            tooltip = L["Color enemies by kind tip"],
        },
        {
            type     = "dropdown",
            key      = "npcColorsScope",
            text     = L["NPC colors scope"],
            tooltip  = L["NPC colors scope tip"],
            indent   = true,
            values   = {
                { value = "always",   label = L["Everywhere"] },
                { value = "instance", label = L["Instances only"] },
            },
            disabled = requires("npcColors"),
        },
        {
            type     = "color",
            key      = "bossColor",
            text     = L["Boss color"],
            tooltip  = L["Boss color tip"],
            indent   = true,
            disabled = requires("npcColors"),
        },
        {
            type     = "color",
            key      = "minibossColor",
            text     = L["Miniboss color"],
            tooltip  = L["Miniboss color tip"],
            indent   = true,
            disabled = requires("npcColors"),
        },
        {
            type     = "color",
            key      = "casterColor",
            text     = L["Caster color"],
            tooltip  = L["Caster color tip"],
            indent   = true,
            disabled = requires("npcColors"),
        },
        {
            type     = "color",
            key      = "meleeColor",
            text     = L["Melee color"],
            tooltip  = L["Melee color tip"],
            indent   = true,
            disabled = requires("npcColors"),
        },
        {
            type     = "color",
            key      = "rareColor",
            text     = L["Rare color"],
            tooltip  = L["Rare color tip"],
            indent   = true,
            disabled = requires("npcColors"),
        },
        {
            type     = "color",
            key      = "rareEliteColor",
            text     = L["Rare elite color"],
            tooltip  = L["Rare elite color tip"],
            indent   = true,
            disabled = requires("npcColors"),
        },
        {
            type    = "toggle",
            key     = "pvpClassColor",
            text    = L["PvP class colors"],
            tooltip = L["PvP class colors tip"],
        },

        -- La menace **dans les couleurs**, sans catégorie à elle : c'est une
        -- couleur d'adversaire de plus, décidée par ce qu'il regarde plutôt que
        -- par ce qu'il est. Un titre pour trois lignes coûtait une hauteur
        -- d'écran et faisait chercher deux fois où se règle la teinte d'une
        -- barre de vie.
        --
        -- Sa marque de section reste : le découpage de `LIVE` ne suit pas les
        -- en-têtes mais ce qui se valide ensemble.
        { section = "threat" },
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
            indent   = true,
            disabled = requires("threatColors"),
        },
        {
            type     = "color",
            key      = "threatBadColor",
            text     = L["Threat wrong"],
            tooltip  = L["Threat wrong tip"],
            indent   = true,
            disabled = requires("threatColors"),
        },

        -- Ces trois-là sont des réglages du client, comme ceux de la moitié
        -- d'au-dessus, mais son menu ne les expose nulle part : il n'y a donc pas
        -- d'autre endroit où aller les chercher, et leur place est de ce côté-ci.
        --
        -- Le partage entre les deux moitiés de la page n'est pas « à qui
        -- appartient le réglage » mais « le menu du jeu sait-il le montrer ». Un
        -- réglage qu'il possède sans l'afficher est, pour le joueur, aussi
        -- introuvable qu'un réglage qui n'existerait pas.
        -- La distance dort (`LIVE.spacing`) : la page s'est resserrée sur ce qui
        -- se règle vraiment, et elle n'en fait plus partie. Le code reste — la
        -- rallumer est un booléen. Le chevauchement, lui, est remonté avec la
        -- barre de vie, dont il mesure la boîte.
        { section = "spacing" },
        { type = "header", text = L["Spacing and distance"] },
        blizzSlider("nameplateMaxDistance",
            L["Nameplate distance"], L["Nameplate distance tip"],
            { min = 10, max = 100, step = 5 }),

    })
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

        -- Le corps des textes n'a plus d'interrupteur à lui : il suit celui de sa
        -- barre (voir `applyTextSize`). Sa valeur de départ reste celle du
        -- client, de sorte que prendre la taille sans toucher au curseur ne
        -- change pas ce qui est écrit sur la plaque.
        textSize   = T.PlateConstant("HEALTH_BAR_FONT_HEIGHT", T.SIZE.PLATE_TEXT),

        -- Le nom des joueurs alliés, à part : c'est ce qu'on lit en mode
        -- « le nom seul », et il se règle sans rendre le reste du texte.
        resizeAllyName = false,
        allyNameSize   = T.SIZE.PLATE_TEXT,

        -- L'aperçu de la barre de sorts. Il ne règle rien : il montre. Il survit
        -- au `/reload` comme les autres réglages, ce qui est voulu — on recharge
        -- précisément pour juger — mais il se remarque, et on l'éteint.
        previewMode = false,

        -- Le corps de la barre de sorts est le sien : le client écrit plus petit
        -- dessus, et partir de sa valeur rend le curseur sans effet tant qu'on
        -- ne l'a pas bougé.
        castTextSize   = T.PlateConstant("CAST_BAR_FONT_HEIGHT", T.SIZE.PLATE_CAST_TEXT),

        -- La rangée d'auras de l'addon. Les mesures de départ sont celles du
        -- client — allumer sans toucher aux curseurs donne des auras de la
        -- taille qu'on connaît. Les décalages de départ donnent le souffle
        -- minimal entre une rangée et la barre qu'elle borde.
        ownAuras    = false,

        -- La rangée est à nous dès que la case maîtresse s'allume. Les deux
        -- cases restent distinctes : l'une ouvre la section, l'autre dit qui,
        -- de l'addon ou du jeu, affiche les entraves.
        ownAuraCc   = false,

        auraCcMax    = T.SIZE.PLATE_AURA_MAX,
        auraCcSize   = T.PlateConstant("AURA_ITEM_HEIGHT", T.SIZE.PLATE_AURA),
        auraCcGap    = T.PlateConstant("DEBUFF_PADDING", T.SIZE.PLATE_AURA_GAP),
        auraCcX      = 4,
        auraCcY      = 0,
        auraCcTimer  = T.SIZE.PLATE_AURA_TIMER,

        -- **Allumé**, contrairement à tout le reste de la page, et ce n'est pas
        -- une entorse à la règle « tout est éteint par défaut ». Cette case-là
        -- ne prend rien au client : elle dit à quoi ressemble une vignette **de
        -- l'addon**, qui n'existe que si le joueur a déjà coché la rangée. Le
        -- liseré carré qu'elle remplace était le seul endroit de l'addon où une
        -- icône n'avait pas le contour commun.
        auraCcShaded = false,

        resizeCast = false,
        castHeight = T.SIZE.PLATE_CAST_BAR_H,


        marker     = false,
        markerSize = 20,
        markerX    = 0,
        markerY    = 0,

        -- La texture des barres. « Couleur vive » des deux côtés : c'est la
        -- demande — l'aplat façon Details —, et le premier choix de la liste.
        -- Rien ne s'écrit tant que la case est décochée.
        barTexture    = false,
        textureOther  = "vivid",
        textureTarget = "vivid",

        -- Opacités. Les trois valeurs de départ sont **lisibles avant d'être
        -- fidèles au client** : la cible pleine, les autres à peine estompées, et
        -- ce qui est derrière un mur à moitié effacé sans disparaître. Le curseur
        -- s'ouvre là où la plupart des joueurs l'auraient posé, ce qui reste sans
        -- effet tant que la case au-dessus est décochée.
        visibility       = false,
        targetAlpha      = 100,
        otherAlpha       = 90,
        occludedAlpha    = 50,

        -- Superposition : la place que chaque plaque garde avant que le jeu ne
        -- pousse la voisine. Plus serré à l'horizontale qu'à la verticale, parce
        -- que c'est en colonne qu'un paquet de plaques devient illisible.
        overlap  = false,
        overlapH = 0.5,
        overlapV = 0.8,

        npcColors      = false,
        npcColorsScope = "always",
        pvpClassColor  = false,
        bossColor      = T.ColorTable(T.COLOR.PLATE.BOSS),
        minibossColor  = T.ColorTable(T.COLOR.PLATE.MINIBOSS),
        casterColor    = T.ColorTable(T.COLOR.PLATE.CASTER),
        meleeColor     = T.ColorTable(T.COLOR.PLATE.MELEE),
        rareColor      = T.ColorTable(T.COLOR.PLATE.RARE),
        rareEliteColor = T.ColorTable(T.COLOR.PLATE.RARE_ELITE),


        threatColors     = false,
        threatShiftColor = T.ColorTable(T.COLOR.PLATE.THREAT_BAD),
        threatBadColor   = T.ColorTable(T.COLOR.PLATE.THREAT_BAD),
    },

    options = pageOptions(),

    --- `/bui noms` : pourquoi le nom d'un joueur porte la couleur qu'il porte.
    ---
    --- Trois choses décident, et aucune ne se voit à l'écran : ce que le client
    --- laisse lire de l'unité, de quel côté on la range, et ce que nos deux
    --- réglages disent. Quand la couleur « ne change pas », c'est l'une des trois
    --- qui répond autre chose que ce qu'on croit — et depuis le jeu, les trois
    --- sont muettes. Elles s'écrivent ici, sur la cible, en une ligne chacune.
    ---
    --- Les noms de fonctions sont ceux de l'API : ils ne se traduisent pas.
    DiagnoseNames = function(self)
        self:Print(L["Name diagnostic"])
        self:Print(CVAR.ALLY_NAMES .. ":", tostring(U.GetCVar(CVAR.ALLY_NAMES)))

        if not U.IsTrue(UnitExists("target")) then
            self:Print(L["Aura diagnostic needs target"])
            return
        end

        local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit
                      and C_NamePlate.GetNamePlateForUnit("target")
        local unitFrame = unitFrameOf(plate)
        if not unitFrame then
            self:Print(L["No nameplate for target"])
            return
        end

        -- Chaque réponse est gardée avant d'être écrite : une valeur secrète ne
        -- se lit pas plus qu'elle ne se raconte.
        local player  = UnitIsPlayer("target")
        local attack  = UnitCanAttack("player", "target")
        local _, class = UnitClass("target")

        self:Print("UnitIsPlayer:",
            U.IsSecret(player) and L["Refused"] or tostring(player),
            "| UnitCanAttack:",
            U.IsSecret(attack) and L["Refused"] or tostring(attack))

        -- La plaque est rangée sous le jeton que le client lui a donné
        -- (`nameplate3`), jamais sous « target » : c'est lui qu'il faut chercher
        -- pour savoir si on la suit.
        local token = type(plate) == "table" and plate.namePlateUnitToken or nil

        self:Print("UnitClass:",
            U.IsSecret(class) and L["Refused"] or tostring(class),
            "| isFriendlyPlayer:", isFriendlyPlayer("target") and L["On"] or L["Off"],
            "| plates:", (token and plates[token]) and L["On"] or L["Off"])

        -- Combien le client en montre, combien on en suit : c'est là que se voit
        -- une annonce manquée.
        local shown = C_NamePlate and C_NamePlate.GetNamePlates
                      and C_NamePlate.GetNamePlates()
        local tracked = 0
        for _ in pairs(plates) do tracked = tracked + 1 end

        self:Print("GetNamePlates:", type(shown) == "table" and #shown or L["Refused"],
            "| plates:", tracked,
            "| namePlateUnitToken:", tostring(token))

        self:Print("nameColor:", nameColor("target") and L["On"] or L["Off"],
            "| unitFrame.name:", unitFrame.name and L["On"] or L["Off"])
    end,

    --- `/bui auras` : l'état de la chaîne des auras et du zoom, écrit dans le
    --- chat. Le symptôme « les curseurs ne font rien » a trop de causes
    --- possibles — lecture refusée, conteneur introuvable, rangée jamais
    --- montée, zoom posé ailleurs que là où on le tient — pour se deviner de
    --- loin : on regarde sur pièces, sur la plaque de la cible. Les noms de
    --- filtres et de champs sont ceux de l'API, ils ne se traduisent pas.
    DiagnoseAuras = function(self)
        self:Print(L["Aura diagnostic"])

        if not U.IsTrue(UnitExists("target")) then
            self:Print(L["Aura diagnostic needs target"])
            return
        end

        local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit
                      and C_NamePlate.GetNamePlateForUnit("target")
        local unitFrame = unitFrameOf(plate)
        if not unitFrame then
            self:Print(L["No nameplate for target"])
            return
        end

        self:Print("C_UnitAuras.GetUnitAuras:",
            (C_UnitAuras and C_UnitAuras.GetUnitAuras) and L["On"] or L["Off"])

        -- Les deux filtres de la rangée, dans l'ordre où elle les emploie : le
        -- classement du client, puis le large qui lui sert de repli.
        local filters = { "HARMFUL|CROWD_CONTROL", "HARMFUL" }
        -- Le premier lot qui répond sert de spécimen : on regarde champ par
        -- champ ce que le client laisse lire d'une aura. C'est la mesure qui
        -- manquait — un filtre qui répond « quatre auras » ne dit pas si ces
        -- quatre-là passeront le tri, et c'est là que la chaîne se rompt.
        -- **Le témoin, et c'est lui qui rend le reste lisible.** Des zéros sur
        -- une cible peuvent vouloir dire « le client ne nous répond pas » aussi
        -- bien que « cette cible n'a rien sur elle », et les deux appellent des
        -- corrections opposées. Le joueur, lui, porte toujours quelque chose :
        -- si sa ligne est vide elle aussi, la lecture est en cause et l'unité
        -- n'y est pour rien.
        local mine = bulkAuras("player", "HELPFUL")
        self:Print("player HELPFUL:", mine and #mine or L["Refused"],
                   "(" .. L["Control"] .. ")")

        -- **Les deux jetons.** Les rangées lisent le jeton de plaque
        -- (`nameplate3`), jamais `target` : ce sont deux façons de désigner la
        -- même unité, et rien ne garantit que le client les protège pareil.
        -- Comparer les deux colonnes est la seule façon de le savoir.
        local token = plate.namePlateUnitToken
        if type(token) ~= "string" then
            for unit, known in pairs(plates) do
                if known == plate then token = unit break end
            end
        end
        self:Print(L["Tokens"] .. ": target |", token or L["Refused"])

        -- L'unité d'où vient le spécimen se retient avec lui : l'horloge se
        -- demande par `(unité, identifiant)`, et la poser sur l'autre unité
        -- rendrait un « refusé » qui ne voudrait rien dire.
        local specimen, specimenUnit
        for i = 1, #filters do
            local onTarget = bulkAuras("target", filters[i])
            local onPlate  = token and bulkAuras(token, filters[i])
            self:Print(filters[i] .. ":",
                       onTarget and #onTarget or L["Refused"],
                       "|", onPlate and #onPlate or L["Refused"])

            if not specimen then
                if onTarget and onTarget[1] then
                    specimen, specimenUnit = onTarget[1], "target"
                elseif onPlate and onPlate[1] then
                    specimen, specimenUnit = onPlate[1], token
                end
            end
        end

        if specimen then
            local function reads(value)
                if U.IsSecret(value) then return L["Secret"] end
                if value == nil then return "nil" end
                return L["On"]
            end
            self:Print("aura.icon:", reads(specimen.icon),
                       "| .auraInstanceID:", reads(specimen.auraInstanceID),
                       "| .applications:", reads(specimen.applications),
                       "| .spellId:", reads(specimen.spellId))

            -- L'horloge de la rangée. « refusé » veut dire que la question n'a
            -- pas de réponse — l'icône se pose alors sans balayage, ce qui est
            -- le repli voulu.
            local specimenID = not U.IsSecret(specimen.auraInstanceID)
                               and specimen.auraInstanceID or nil
            local okD, duration = false, nil
            if specimenID and C_UnitAuras.GetAuraDuration then
                okD, duration = pcall(C_UnitAuras.GetAuraDuration,
                                      specimenUnit, specimenID)
            end
            self:Print("GetAuraDuration:", okD and reads(duration) or L["Refused"])
        end

        -- Ce que le tri en fait, par le même chemin que la vraie rangée et sur
        -- le jeton qu'elle emploie. Un zéro ici avec des filtres qui répondent
        -- au-dessus désigne le tri ; des zéros des deux côtés désignent la
        -- lecture.
        local probe = { cc = { n = 0 }, refused = 0 }
        collectAuras(token or "target", probe)
        self:Print("collect cc:", probe.cc.n,
                   "| " .. L["Refused"] .. ":", probe.refused)

        self:Print("ownAuras:", self:Get("ownAuras") and L["On"] or L["Off"],
                   "| previewMode:", self:Get("previewMode") and L["On"] or L["Off"])
        self:Print("AurasFrame:", unitFrame.AurasFrame and L["On"] or L["Off"],
                   "| BuffFrame:", unitFrame.BuffFrame and L["On"] or L["Off"],
                   "| name:", unitFrame.name and L["On"] or L["Off"])

        local rows = auraRows[plate]
        if rows then
            for g = 1, #AURA_GROUPS do
                local key = AURA_GROUPS[g].key
                local row = rows[key]
                local shown = row and U.IsTrue(row:IsShown())
                self:Print("row " .. key .. ":",
                           row and (shown and L["On"] or L["Off"]) or L["Refused"])
            end
        else
            self:Print("rows:", L["Refused"])
        end

        -- Les échelles empilées. Les rangées n'en héritent plus — elles ignorent
        -- celle de leur parent —, mais les deux nombres restent la première
        -- chose à regarder quand une rangée n'est pas là où le curseur la dit.
        local okP, plateScale = pcall(plate.GetScale, plate)
        local okF, frameScale = pcall(unitFrame.GetScale, unitFrame)
        self:Print("scale plate:",
            (okP and type(plateScale) == "number" and not U.IsSecret(plateScale))
                and string.format("%.2f", plateScale) or "?",
            "| frame:",
            (okF and type(frameScale) == "number" and not U.IsSecret(frameScale))
                and string.format("%.2f", frameScale) or "?")
    end,

    OnEnable = function(self)
        -- Les exemples de l'aperçu se préparent d'abord : si la case a survécu à
        -- un `/reload`, la première peinture les montre déjà.
        if LIVE.auras and self:Get("previewMode") then refreshSampleList() end

        applySize(self)
        applyOverlap(self)
        applyClientAuras(self)
        applyClientThreat(self)

        -- La rangée d'auras a été retirée : ce qu'elle avait pris au jeu se rend
        -- ici, une fois, chez les joueurs qui l'utilisaient.
        releaseClientAuras(self)

        -- La boîte des plaques se fait réécrire sans événement — le pilote du
        -- client la repose en rejouant son calibre. On se branche sur
        -- l'écriture, comme pour la hauteur de barre.
        hookPlateSize()

        -- Un autre addon — ou le panneau du client — peut écrire par-dessus nos
        -- CVars. On reprend la main, sans précipitation : voir `CVAR_SETTLE`.
        -- C'est le seul abonnement que prend la seule section de taille.
        self:RegisterEvent("CVAR_UPDATE", U.Throttle(T.TIMING.CVAR_SETTLE, function()
            applySize(self)
            applyOverlap(self)
            applyAlpha(self)
            applyClientAuras(self)
            applyClientThreat(self)
        end))

        -- La largeur de boîte est refusée en combat, sans rien dire. Ce qui a été
        -- refusé se rattrape ici — c'est le même contrat que les cadres de groupe
        -- dans `Modules/UnitFrames.lua`.
        self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
            applySize(self)
            applyOverlap(self)
            applyClientAuras(self)
            applyClientThreat(self)
            releaseClientAuras(self)
        end)

        -- Tout ce qui suit s'occupe des plaques une par une. Tant qu'aucune
        -- section n'en a besoin, rien de tout cela ne s'arme : pas de hook, pas
        -- de passage périodique, pas un événement de plaque écouté. C'est ce qui
        -- rend chaque section vérifiable seule (voir `LIVE`).
        if not needsPlates() then return end

        refreshRole()
        refreshInstance()
        collectPlates()
        hookPainting()
        applyAlpha(self)
        paintAll(self)

        updateCastTicker(self)
        updateAuraTicker(self)

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

        -- **Le marqueur d'un mob qu'on vient de marquer.** Sa taille et sa
        -- vignette se posent à la peinture complète ; son ancrage, lui, a son
        -- hook. Sans cet abonnement, marquer une cible en plein combat ne
        -- déclencherait plus rien — la peinture de chaque battement de vie le
        -- rattrapait par accident, et elle ne le rattrape plus. Le client
        -- annonce chaque marqueur posé ou retiré, et c'est rare.
        self:RegisterEvent("RAID_TARGET_UPDATE", function() paintAll(self) end)

        -- **Une unité change de camp sans changer de plaque.** Un contrôle
        -- mental la rend alliée pour quelques secondes, puis adverse à nouveau,
        -- et la plaque ne repart pas au recyclage entre les deux.
        --
        -- Tout ce que le module décide à partir de l'hostilité en dépend : les
        -- rangées d'auras (`auraless`), la couleur de la barre et du nom, le
        -- corps du nom allié. Sans cet abonnement, ces réponses n'étaient
        -- relues qu'au prochain passage du client sur cette plaque — et sur une
        -- plaque qui ne bouge plus, ce prochain passage peut ne jamais venir.
        self:RegisterEvent("UNIT_FACTION", function(_, unit)
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

            applyOwnAuras(self, plate, unit, true)
        end)

        self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", function()
            refreshRole()
            paintAll(self)
        end)

        -- **Le seul réglage d'un autre module qui nous regarde.** Le contour de
        -- nos vignettes d'auras fonce avec le mode sombre (voir `setEdge` dans
        -- `UI/Widgets/PlatePreview.lua`), et il faut le redessiner quand la case
        -- bascule — sans quoi le changement n'apparaîtrait qu'à la prochaine aura
        -- qui bouge, ce qui se lit comme un réglage qui n'a pas pris.
        --
        -- On l'apprend par le message que le core émet, jamais en allant lire la
        -- base d'un autre module. Les deux messages, parce qu'il y a deux façons
        -- d'éteindre le mode sombre : décocher sa case, ou éteindre le module.
        local darkChanged = function(_, name)
            if name == "DarkMode" then paintAll(self) end
        end
        self:RegisterMessage(BUI.MESSAGES.SETTING_CHANGED, darkChanged)
        self:RegisterMessage(BUI.MESSAGES.MODULE_STATE,    darkChanged)

        local function enteredWorld()
            -- Le client refait ses plaques en chargeant une zone, sans
            -- réannoncer celles qui restent : on repart de ce qui est à l'écran.
            refreshInstance()
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
        if castTicker then castTicker:Cancel() castTicker = nil end
        if auraTicker then auraTicker:Cancel() auraTicker = nil end
        hideAuraRows()
        hideMarkerPreviews()
        restoreMarkerAlpha()
        restorePlateWidth()
        releaseAll()
        giveBackCVars()
        -- Les catégories d'auras se rendent à part : elles ne sont pas relevées
        -- comme des CVars entiers mais bit par bit (voir `savedBits`).
        giveBackCVarBits()
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
                updateAuraTicker(self)
            end

            -- Les interrupteurs de la section se rendent séparément : éteindre la
            -- taille ne doit pas ramener le texte à son corps, qui n'a rien
            -- demandé.
            -- Rendre une barre, c'est rendre son texte : les deux sont sous le
            -- même interrupteur. Le repassage qui suit repose le corps de
            -- l'autre famille, si elle est encore prise — `restoreTextSizes`
            -- rend les deux d'un coup, et c'est très bien tant qu'on lui offre
            -- tout de suite l'occasion de reprendre ce qui lui revient.
            if key == "resize" and not self:Get("resize") then
                giveBackSize()
                restoreTextSizes()
                paintAll(self)
            elseif key == "resizeAllyName" and not self:Get("resizeAllyName") then
                restoreAllyNames()
                -- La taille générale reprend les noms rendus au prochain
                -- passage, si elle est allumée : on le lui offre tout de suite.
                paintAll(self)
            elseif key == "resizeCast" and not self:Get("resizeCast") then
                restoreCastSizes()
                restoreTextSizes()
                paintAll(self)
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

        if TEXTURE_KEYS[key] then
            if key == "barTexture" and not self:Get("barTexture") then
                restoreBarTextures()
            else
                paintAll(self)
            end
            return
        end

        if ALPHA_KEYS[key] then
            if key == "visibility" and not self:Get("visibility") then
                giveBack(TAKEN_CVARS.alpha)
            else
                applyAlpha(self)
            end
        end

        -- La superposition écrit deux CVars du client : décocher les lui rend,
        -- bouger un curseur les repose. Trois clés énumérées plutôt qu'une table
        -- de plus : ce fichier compte ses variables (voir `pageOptions`).
        if key == "overlap" or key == "overlapH" or key == "overlapV" then
            if key == "overlap" and not self:Get("overlap") then
                giveBack(TAKEN_CVARS.overlap)
            else
                applyOverlap(self)
            end
            return
        end

        -- Les cases d'auras commandent aussi celles du client : la rangée prise
        -- éteint **sa** catégorie chez lui et grise la case correspondante ;
        -- rendue, elle la lui restitue. La maîtresse vaut pour la rangée.
        if AURA_TAKE_KEYS[key] then
            applyClientAuras(self)
            -- L'aperçu suit les mêmes cases : une rangée rendue au jeu retire
            -- son exemple, et la minuterie s'arrête s'il n'en reste aucun.
            if self:Get("previewMode") then refreshSampleList() end
            updateAuraTicker(self)
        end

        -- Notre couleur de menace éteint la sienne, et la lui rend. La case du
        -- client se grise pendant ce temps : les deux repeignent la même barre
        -- pour dire la même chose.
        if key == "threatColors" then applyClientThreat(self) end

        -- Le marqueur éteint retrouve l'opacité de sa plaque. Son ancrage, lui,
        -- ne se rend pas — c'est le prix assumé de la section, et le recyclage
        -- de la plaque le paie (voir « Rendre un ancrage qu'on n'a pas le droit
        -- de lire »).
        if key == "marker" and not self:Get("marker") then
            restoreMarkerAlpha()
        end

        -- Les rangées d'auras se réancreront au repassage : un réglage vient de
        -- changer, et c'est le seul moment où leurs points bougent.
        bumpAuraLayout()

        -- Le repassage rend aussi les opacités posées à la main : `paint` les
        -- reprend ou les relâche selon l'interrupteur, plaque par plaque.
        paintAll(self)
    end,
})