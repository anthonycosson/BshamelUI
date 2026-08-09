-- =========================================================================
--  Bshamel UI — Modules/NameplatesPage.lua
--  Ce que la page des barres d'infos déclare : les sections livrées, les noms
--  de CVars, et la centaine de lignes que le joueur voit.
--
--  **Ce fichier n'enregistre aucun module.** Il est la moitié déclarative de
--  `Modules/Nameplates.lua`, qui le suit immédiatement dans le `.toc` et qui
--  porte le moteur — le suivi des plaques, la peinture, les hooks, les CVars
--  empruntés.
--
--  ## Pourquoi deux fichiers
--
--  Le Lua du client borne une fonction à deux cents variables locales et deux
--  cent cinquante registres. Le fichier d'un seul tenant en comptait cent
--  quatre-vingt-quinze : chaque ajout se payait d'une chasse à la variable, et
--  la borne franchie ne casse pas une ligne — elle empêche **le fichier entier**
--  de se compiler, et le module disparaît du menu (voir `dev/docs/API_NOTES.md`).
--
--  La coupure suit la seule frontière qui existait déjà dans le fichier : ce qui
--  **décrit** d'un côté, ce qui **agit** de l'autre. Les fabriques de contrôles,
--  les intitulés et la liste des options ne touchent aucune plaque ; le moteur ne
--  construit aucun descripteur.
--
--  ## Ce que ce fichier publie
--
--  Tout passe par `ns.Plates`, et rien d'autre : le nom du module, la table des
--  sections livrées, les noms de CVars, la liste des familles d'unités adverses,
--  et la fonction qui rend la page. Le moteur les relit en tête de fichier.
--
--  Il charge **avant** lui, et il le faut : `BUI:RegisterModule` réclame la
--  liste des options au moment où il s'exécute.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local U    = BUI.Util
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

    -- **La rangée d'auras de l'addon est retirée**, et le code reste ici,
    -- entier, comme le veut cette table. L'aperçu qu'on avait bâti dessus est
    -- parti avec elle.
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

    -- Quelles unités adverses portent une plaque, par contexte. N'écrit que des
    -- CVars du client : rien à valider sur les plaques elles-mêmes.
    enemies    = true,
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

    -- Le grossissement que le client applique à la plaque de la cible. Il passe
    -- **par-dessus** tout le reste, taille en pixels comprise : une plaque réglée
    -- au pixel près change quand même de taille quand on la cible. Mis à un, la
    -- cible a la taille des autres.
    TARGET_SCALE = "nameplateSelectedScale",

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

    -- Les couleurs de classe, et c'est **le client qui peint**. On les a
    -- d'abord posées nous-mêmes, et la version manuelle s'arrêtait au mur des
    -- instances : identité secrète d'un côté, plaques alliées jamais rendues de
    -- l'autre. Ces trois CVars n'ont aucun de ces murs — le client se peint
    -- lui-même, avec des droits que l'addon n'aura jamais.
    --
    -- Les noms viennent d'une lecture de BetterBlizzPlates (règle 8 : lire pour
    -- identifier l'API, jamais copier) ; la trouvaille est consignée dans
    -- `dev/docs/API_NOTES.md`. Comme le mode « nom seul » : rien d'emprunté,
    -- rien à rendre — ce sont des cases du client, cochées depuis chez nous.
    CLASS_ENEMY     = "nameplateShowClassColor",
    CLASS_ALLY      = "nameplateShowFriendlyClassColor",
    ALLY_NAME_CLASS = "nameplateUseClassColorForFriendlyPlayerUnitNames",
}

-- =========================================================================
--  Quelles unités adverses portent une barre d'infos
-- =========================================================================
-- Le client range cela dans une poignée de CVars booléens, un par famille
-- d'unités. Son menu n'en montre que trois, et surtout : **il n'en montre
-- qu'un jeu**. Or ce qu'on veut voir en donjon n'est pas ce qu'on veut voir en
-- ville — les totems d'un chaman adverse comptent en arène et encombrent en
-- ville, les créatures mineures encombrent partout sauf quand on cherche
-- justement l'une d'elles.
--
-- Le module tient donc **deux jeux de valeurs**, un par contexte, et écrit celui
-- qui correspond au passage d'un portail. Le client n'a rien pour cela ; c'est
-- tout ce que cette section ajoute.
--
-- ## Les noms sont des candidats, pas une liste
--
-- Blizzard a renommé et supprimé plusieurs de ces CVars au fil des extensions.
-- On les cite tous et **on demande au client lesquels il connaît** : un CVar
-- absent ne rend aucune ligne, exactement comme pour `blizzToggle`. Une case
-- morte se coche et ne pilote rien — c'est la leçon payée quatre fois sur cette
-- page.
--
-- ## Ce que la prise implique
--
-- Allumée, la section **possède** ces CVars : elle les relève, écrit les siens,
-- et grise les lignes correspondantes de la moitié Blizzard, qui diraient sinon
-- le contraire d'elle une fois sur deux. Éteinte, elle rend tout tel quel.

--- `cvar` est le nom candidat, et les trois clés suivantes rangent la valeur
--- d'un contexte chacune. Ces clés sont des noms de base de données : elles ne
--- se renomment pas (règle 4) — d'où `inst`, qui nommait le seul contexte
--- instancié du jour où il n'y en avait que deux, et qui désigne aujourd'hui le
--- PvE instancié.
--- **Les deux interrupteurs de tête n'y sont pas**, et c'est délibéré : « toutes
--- les unités adverses » et « serviteurs » commandent les autres au lieu de
--- désigner une famille. Les régler par contexte revenait à offrir deux fois la
--- même décision, une fois en gros et une fois en détail — et la version en gros
--- gagne toujours, ce qui rend la version en détail menteuse. Ils restent où le
--- jeu les met, dans la moitié Blizzard.
--- Les unités mineures ferment la liste : c'est la famille dont on se soucie le
--- moins, celle qu'on éteint une fois et qu'on ne rouvre jamais.
local ENEMY_UNITS = {
    { cvar = "nameplateShowEnemyPets",
      world = "petsWorld",      inst = "petsInst",      pvp = "petsPvp",
      text = L["Enemy pets"],           tip = L["Enemy pets example"] },
    { cvar = "nameplateShowEnemyGuardians",
      world = "guardiansWorld", inst = "guardiansInst", pvp = "guardiansPvp",
      text = L["Enemy guardians"],      tip = L["Enemy guardians example"] },
    { cvar = "nameplateShowEnemyTotems",
      world = "totemsWorld",    inst = "totemsInst",    pvp = "totemsPvp",
      text = L["Enemy totems"],         tip = L["Enemy totems example"] },
    { cvar = "nameplateShowEnemyMinus",
      world = "minusWorld",     inst = "minusInst",     pvp = "minusPvp",
      text = L["Enemy minor units"],    tip = L["Enemy minor units example"] },
}

--- La clé qui range la valeur d'une famille pour un contexte.
---@param entry table
---@param context string  "world" | "pve" | "pvp"
---@return string
local function enemyKey(entry, context)
    if context == "pvp" then return entry.pvp end
    if context == "pve" then return entry.inst end
    return entry.world
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

-- `auraRowToggle`, `auraSliders` et `auraShadeToggle` vivaient ici : elles
-- bâtissaient les lignes de la rangée d'entraves. La rangée est retirée de la
-- page, et une fabrique de lignes sans page à remplir est du code mort — le
-- moteur, lui, est resté : c'est lui qui sert l'aperçu d'auras.


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
        disabled = requires("marker"),
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

local SIZE_LOCK = {
    disabled = function()
        if InCombatLockdown() then return true end
        local mod = module()
        return mod ~= nil and mod:Get("resize") == true
    end,
    reason   = function()
        if InCombatLockdown() then return L["Cannot change in combat"] end
        return L["Taken over by the addon"]
    end,
}



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
            local mod = module()
            return inCombat() or (mod ~= nil and mod:Get("allyNamesOnly"))
        end,
        reason = function()
            if InCombatLockdown() then return L["Cannot change in combat"] end
            return L["Simplified taken by names only"]
        end,
    }
end

--- Les choix des deux listes déroulantes — une table, partagée : les deux
--- contrôles offrent exactement la même palette.
local BAR_TEXTURE_VALUES = {
    { value = "vivid",    label = L["Texture vivid"] },
    { value = "standard", label = L["Texture standard"] },
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

--- Les champs de bits que la page pilote, remplis par `bitfieldGroup` au fil
--- de la construction. Le moteur les relit pour **rejouer** les bits
--- enregistrés : le client oublie ses champs cachés à la reconnexion — les
--- catégories d'auras des trois familles se décochaient toutes seules, comme
--- le « nom seul des alliés » avant elles.
local BITFIELDS = {}

--- Enregistre le choix du joueur sur un bit, **par personnage** — ce sont des
--- réglages que le client range par personnage, la mémoire suit son rayon.
--- L'enregistrement se fait par **nom de catégorie**, jamais par index : une
--- énumération peut se renuméroter, un nom se retrouve (règle 1).
---@param cvar string
---@param memberName string
---@param value boolean
local function rememberBit(cvar, memberName, value)
    local mod = module()
    if not mod then return end

    local data = mod:CharData()
    data.clientBits = data.clientBits or {}

    local bits = data.clientBits[cvar]
    if not bits then
        bits = {}
        data.clientBits[cvar] = bits
    end
    bits[memberName] = value and true or false
end

--- Un champ de bits se lit et s'écrit par index, pas comme un nombre. Chaque
--- écriture du joueur est retenue (`rememberBit`) : le moteur la reposera à
--- chaque connexion, parce que le client, lui, ne s'en souvient pas.
---@param cvar string
---@param index number
---@param memberName string
---@return fun(): boolean get, fun(value: boolean) set
local function bitfieldToggle(cvar, index, memberName)
    return function()
        if not (C_CVar and C_CVar.GetCVarBitfield) then return false end
        local ok, value = pcall(C_CVar.GetCVarBitfield, cvar, index)
        return ok and value == true
    end, function(value)
        if InCombatLockdown() then return end
        if not (C_CVar and C_CVar.SetCVarBitfield) then return end
        pcall(C_CVar.SetCVarBitfield, cvar, index, value and true or false)
        rememberBit(cvar, memberName, value)
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

    -- Le champ existe sur ce client : il entre dans la liste que le moteur
    -- rejoue. Un champ mort n'y entre pas — rien à rejouer sur lui.
    BITFIELDS[#BITFIELDS + 1] = { cvar = cvar, enum = enum }

    local members = enumMembers(enum)

    for i = 1, #members do
        local member  = members[i]
        local get, set = bitfieldToggle(cvar, member.value, member.name)

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
--- Ce n'était qu'une case du client comme les autres — jusqu'à ce qu'on
--- remarque qu'elle ne survivait pas à une reconnexion : `CVAR.ALLY_NAMES` est
--- un CVar caché, absent du panneau Blizzard, et ce client-là ne le persiste
--- pas de son côté. On le traite désormais comme `overlap` : un réglage à nous,
--- rangé dans `BshamelUIDB`, que `applyAllyNamesOnly` (dans `Nameplates.lua`)
--- pose au client à chaque connexion et à chaque `CVAR_UPDATE` — y compris le
--- geste qui décoche la case qui la double (voir « Deux réglages du client qui
--- font la même chose »), déplacé là pour la même raison.
---@return table
local function allyNamesRow()
    if not CVAR.ALLY_NAMES or U.GetCVar(CVAR.ALLY_NAMES) == nil then
        return {}
    end

    return {
        type     = "toggle",
        key      = "allyNamesOnly",
        text     = L["Allied names only"],
        tooltip  = L["Allied names only tip"],
        disabled = inCombat,
        disabledReason = L["Cannot change in combat"],
    }
end

--- Une case du client que **notre section des unités adverses peut prendre**.
---
--- Identique à `blizzToggle`, au verrou près : elle se grise quand la section
--- est allumée, avec le motif qui dit où le réglage est passé.
---@param name string
---@param text string
---@param tooltip string
---@param indent? boolean
---@return table
local function enemyToggle(name, text, tooltip, indent)
    local row = blizzToggle(name, text, tooltip, indent)
    if not row.type then return row end

    row.disabled = function()
        if inCombat() then return true end
        local mod = module()
        return LIVE.enemies and mod ~= nil and mod:Get("enemyUnits") == true
    end
    row.disabledReason = function()
        if InCombatLockdown() then return L["Cannot change in combat"] end
        return L["Enemy units taken over"]
    end

    return row
end

--- Une case par famille d'unités adverses, pour un contexte.
---
--- Les familles que ce client ne connaît pas ne rendent aucune ligne : on
--- demande, on ne suppose pas (règle 1). La liste est donc plus courte sur un
--- client qui a retiré des CVars, et plus longue le jour où Blizzard en ajoute.
---@param context string  "world" | "pve" | "pvp"
---@return table[]
local function enemyRows(context)
    local rows = {}

    for i = 1, #ENEMY_UNITS do
        local entry = ENEMY_UNITS[i]
        if U.GetCVar(entry.cvar) ~= nil then
            rows[#rows + 1] = {
                type     = "toggle",
                key      = enemyKey(entry, context),
                text     = entry.text,
                tooltip  = entry.tip,
                indent   = true,
                disabled = requires("enemyUnits"),
            }
        end
    end

    return rows
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
        -- **Les trois lignes adverses passent sous la section d'en face** dès
        -- qu'elle est allumée : elle décide de la même chose, contexte par
        -- contexte. Les laisser actives donnerait deux réponses à une question,
        -- et la dernière écriture gagnerait.
        --
        -- Elles restent visibles et disent la vérité pendant ce temps : la
        -- première cochée — le camp adverse s'affiche —, la deuxième décochée —
        -- ce qu'il invoque ne passe plus par elle —, la troisième au reflet de
        -- la case d'en face. Une ligne grisée qui montrerait autre chose que ce
        -- que le jeu applique serait pire qu'une ligne absente.
        enemyToggle("nameplateShowEnemies",
            L["Enemy nameplates"], L["Enemy nameplates tip"]),
        -- Les deux suivantes ne veulent rien dire sans celle du dessus : elles
        -- affinent l'affichage des ennemis, elles ne s'y ajoutent pas. La page le
        -- dit par un retrait et un corps plus petit.
        enemyToggle("nameplateShowEnemyMinions",
            L["Enemy minions"], L["Enemy minions tip"], true),
        enemyToggle("nameplateShowEnemyMinus",
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
            AURA_LABELS, L["Auras tip"]),

        { type = "header", text = L["Enemy player auras"] },
        bitfieldGroup("nameplateEnemyPlayerAuraDisplay", Enum.NamePlateEnemyPlayerAuraDisplay,
            AURA_LABELS, L["Auras tip"]),

        { type = "header", text = L["Friendly player auras"] },
        bitfieldGroup("nameplateFriendlyPlayerAuraDisplay", Enum.NamePlateFriendlyPlayerAuraDisplay,
            AURA_LABELS, L["Auras tip"]),

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

        -- Le mode aperçu général vivait ici, en tête de colonne. Il montrait
        -- d'un seul clic tout ce qui ne se voit qu'en combat, et c'était son
        -- défaut : on l'allumait pour régler une barre de sorts et on se
        -- retrouvait avec un crâne sur chaque plaque. Chaque aperçu est
        -- désormais **dans la section qu'il illustre**, et n'y montre que ce que
        -- cette section règle.

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
        -- Au rang de l'interrupteur de taille et non sous lui : le client
        -- grossit la plaque de la cible **quels que soient** nos pixels, et cette
        -- case le lui interdit. Elle vaut donc aussi pour qui ne règle aucune
        -- taille — c'est un réglage du jeu qu'on lui emprunte, pas une mesure de
        -- plus sur les nôtres.
        {
            type    = "toggle",
            key     = "flatTarget",
            text    = L["Flat target size"],
            tooltip = L["Flat target size tip"],
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
        -- **Sans titre au-dessus.** Quatre lignes ne font pas une section, et
        -- « Alliés » en tête n'aurait dit qu'une chose que les quatre intitulés
        -- disent déjà.
        --
        -- Les deux lignes en retrait ne veulent rien dire sans le mode nom seul :
        -- c'est là que le corps du nom compte, puisqu'il ne reste que lui. Elles
        -- se grisent donc avec lui, en plus de se griser entre elles.
        --
        -- La couleur de classe ferme le groupe, **en retrait comme les deux
        -- autres**. Le retrait dit ici « ceci concerne le nom des alliés », pas
        -- « ceci dépend de la case du dessus » — elle vaut d'ailleurs pour toute
        -- plaque alliée qui montre un nom, mode « nom seul » ou pas, et c'est
        -- pourquoi elle ne se grise pas avec les deux autres.
        { section = "size" },
        allyNamesRow(),
        {
            type     = "toggle",
            key      = "resizeAllyName",
            text     = L["Resize ally names"],
            tooltip  = L["Resize ally names tip"],
            indent   = true,
            disabled = function()
                local mod = module()
                return not (mod and mod:Get("allyNamesOnly"))
            end,
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
                return not (mod and mod:Get("allyNamesOnly"))
                    or not (mod and mod:Get("resizeAllyName"))
            end,
            -- Le motif n'est donné que pour celui qui ne se devine pas : « la
            -- case du dessus est décochée » se lit sur la case du dessus.
            disabledReason = function()
                local mod = module()
                if not (mod and mod:Get("allyNamesOnly")) then
                    return L["Needs allied names only"]
                end
            end,
        },
        -- « Noms aux couleurs de classe » vivait ici, et elle y revient —
        -- retirée le jour où l'on avait cru le jeu capable de le faire seul, il
        -- ne le fait pas de lui-même : il attend qu'on le lui demande, par le
        -- CVar que cette case coche (voir `CVAR.ALLY_NAME_CLASS`).
        --
        -- Elle est bien une couleur, et la section d'en face les rassemble.
        -- Elle reste pourtant ici, avec les trois autres lignes du nom allié :
        -- on ne vient pas régler « une couleur », on vient régler **le nom des
        -- alliés** — et ce qu'on cherche alors, c'est l'endroit où il est déjà
        -- question de lui.
        --
        -- Même CVar caché, même sort que « nom seul » ci-dessus : rangée dans
        -- `BshamelUIDB` et reposée par `applyAllyNameClassColor`, plutôt que
        -- miroir direct d'un CVar qui ne persiste pas de son côté.
        (function()
            if not CVAR.ALLY_NAME_CLASS
               or U.GetCVar(CVAR.ALLY_NAME_CLASS) == nil then
                return {}
            end
            return {
                type     = "toggle",
                key      = "allyNameClassColor",
                text     = L["Ally name class colors"],
                tooltip  = L["Ally name class colors tip"],
                indent   = true,
                disabled = inCombat,
                disabledReason = L["Cannot change in combat"],
            }
        end)(),

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
        -- L'aperçu ferme la section, **en retrait sous l'interrupteur qui lui
        -- donne un sens**. Une barre de sorts ne se montre qu'en incantation, et
        -- régler une chose qu'on ne voit pas revient à chercher un adversaire
        -- qui veuille bien lancer un sort — mais tant que la taille n'est pas à
        -- nous, ce qu'il montrerait est la barre du client, que les curseurs
        -- ci-dessus ne pilotent pas. Un aperçu qui ne prévisualise rien se lit
        -- comme un réglage en panne, et c'est ce qu'il était.
        {
            type     = "toggle",
            key      = "previewCast",
            text     = L["Preview cast bar"],
            tooltip  = L["Preview cast bar tip"],
            indent   = true,
            disabled = requires("resizeCast"),
        },
        -- Le marqueur ferme la section : il se règle comme une rangée — une
        -- taille, deux décalages.
        { section = "marker" },
        { type = "header", text = L["Raid marker"] },
        {
            type    = "toggle",
            key     = "marker",
            text    = L["Place raid marker"],
            tooltip = L["Place raid marker tip"],
            disabledReason = AURAS_PAUSED and L["Auras paused"] or nil,
        },
        markerSlider("markerSize", L["Marker size"], L["Marker size tip"], 8, 64),
        markerSlider("markerX", L["Marker offset X"], L["Marker offset tip"], -60, 60),
        markerSlider("markerY", L["Marker offset Y"], L["Marker offset tip"], -60, 60),
        -- Le même aperçu que la barre de sorts, au même rang et pour la même
        -- raison : une marque ne se voit que sur une cible marquée, et on ne
        -- règle pas un décalage en attendant qu'un chef de groupe pose un crâne.
        -- Sous l'interrupteur, parce que taille et décalage n'existent que
        -- lorsque la marque est à nous — sans lui, l'aperçu montrait celle du
        -- client et les trois curseurs semblaient sans effet.
        {
            type     = "toggle",
            key      = "previewMarker",
            text     = L["Preview marker"],
            tooltip  = L["Preview marker tip"],
            indent   = true,
            disabled = requires("marker"),
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

        -- La rangée d'entraves de l'addon avait ses lignes ici : sa case
        -- maîtresse, celle de la rangée, son contour et ses quatre mesures.
        -- **Elles sont parties avec elle**, mais pas son code — il sert
        -- désormais l'aperçu d'auras, dans la moitié Blizzard, où il montre les
        -- mesures du jeu au lieu des nôtres. Les fabriques de lignes
        -- (`auraRowToggle`, `auraSliders`…) restent écrites pour le jour où la
        -- rangée reviendrait.

        -- La section ne dit plus « les adversaires » : elle porte désormais les
        -- couleurs de classe des **deux** camps, et un titre qui n'annonce que
        -- la moitié de ce qu'il contient fait chercher l'autre moitié ailleurs.
        { section = "colors" },
        { type = "header", text = L["Nameplate colors"] },
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
        -- Les deux camps, l'un sous l'autre : ce sont **des barres de vie**, et
        -- c'est ce qui décide de leur place ici. La troisième couleur de classe
        -- de la page — celle du nom des alliés — est restée avec les autres
        -- lignes du nom allié, plus haut : on la cherche là où il est question
        -- du nom, pas là où il est question des barres.
        --
        -- Deux cases du client, pas deux réglages à nous (voir `CVAR`) : c'est
        -- lui qui peint, et c'est ce qui les fait marcher là où notre pinceau
        -- n'entre pas — donjon, raid, arène. Elles disparaissent d'elles-mêmes
        -- sur un client qui ne les connaît pas, comme toute ligne `blizzToggle`.
        blizzToggle(CVAR.CLASS_ENEMY,
            L["PvP class colors"], L["PvP class colors tip"]),
        blizzToggle(CVAR.CLASS_ALLY,
            L["Ally class colors"], L["Ally class colors tip"]),

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

        -- Les unités adverses ferment la colonne. C'est la section la plus
        -- haute — deux contextes, une case par famille — et la seule qu'on règle
        -- une fois puis qu'on oublie : tout ce qui la précède se retouche en
        -- jouant, elle se décide une bonne fois.
        --
        -- Les deux contextes portent un en-tête **en retrait** : ce ne sont pas
        -- deux catégories de plus, c'est la même liste vue deux fois.
        { section = "enemies" },
        { type = "header", text = L["Enemy units section"] },
        {
            type    = "toggle",
            key     = "enemyUnits",
            text    = L["Tune enemy units"],
            tooltip = L["Tune enemy units tip"],
        },
        { type = "header", text = L["Open world"], indent = true },
        enemyRows("world"),
        { type = "header", text = L["PvE instances"], indent = true },
        enemyRows("pve"),
        { type = "header", text = L["PvP instances"], indent = true },
        enemyRows("pvp"),

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
--  Ce que le moteur relit
-- =========================================================================
-- Une seule table, et des noms courts : c'est un passage de main entre deux
-- fichiers du même module, pas une interface publique. Ce qui n'y figure pas ne
-- traverse pas — `Modules/Nameplates.lua` ne connaît de cette moitié-ci que ces
-- six entrées.

ns.Plates = {
    MODULE  = MODULE,
    LIVE    = LIVE,
    PAUSED  = AURAS_PAUSED,
    CVAR    = CVAR,
    UNITS   = ENEMY_UNITS,
    BITS    = BITFIELDS,
    Key     = enemyKey,
    Options = pageOptions,
}
