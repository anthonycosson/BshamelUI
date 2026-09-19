-- =========================================================================
--  Bshamel UI — UI/Shade.lua
--  Moteur du mode sombre : assombrit l'habillage du client, et sait le rendre.
--
--  Principe : on **multiplie** la couleur de sommet des textures existantes, on
--  ne pose aucun voile par-dessus. Un voile dépend de l'ordre des calques d'un
--  cadre qui ne nous appartient pas — si le client dessine son habillage
--  au-dessus, le voile ne se voit jamais. La multiplication agit sur la texture
--  elle-même, quel que soit le calque (même raison que `T.SetPanelFill`).
--
--  Assombrir ne suffit pas : l'habillage du client est doré, et une multiplication
--  seule donne un doré foncé, pas du sombre. Les textures d'habillage sont donc
--  **désaturées** avant d'être assombries. Les icônes, elles, gardent leurs
--  couleurs : une icône de sort désaturée n'est plus reconnaissable.
--
--  **Les icônes ne sont jamais teintées**, et presque jamais dessinées :
--    · un bouton d'action, une infobulle, un cadre d'unité ont déjà un contour
--      — une texture d'habillage distincte de l'icône, avec ses coins arrondis.
--      La teinter fonce le contour et rien d'autre. Y ajouter un trait poserait
--      un carré derrière une forme ronde (voir `dev/docs/API_NOTES.md`) ;
--    · une icône d'aura, comme un emplacement du gestionnaire de temps de
--      recharge, est un carré nu : le client ne lui dessine aucun contour, il
--      n'y a donc rien à teinter et le trait doit être tracé. Ces cas-là sont
--      déclarés dans `ICON_BORDERS`, et ils y sont tous.
--
--  Réversibilité : couleur et désaturation d'origine sont relevées avant la
--  première teinte et conservées. `Restore` les repose telles quelles — c'est ce
--  qui permet à `OnDisable` de rendre le module indétectable (CLAUDE.md règle 6).
--  Repeindre est idempotent : on rend d'abord, on recollecte, on reteinte.
--
--  Ce qu'on ne touche jamais :
--    · les cadres de l'addon lui-même (marque `buiOwn`, posée par le widget à
--      sa création) : leurs couleurs sont celles du thème, déjà voulues ;
--    · la texture de remplissage d'une barre de statut — c'est la donnée (vie,
--      ressource, temps restant), pas l'habillage ;
--    · les portraits et icônes de classe : les assombrir barbouille le visage du
--      personnage, ce que personne ne demande en cochant « mode sombre » ;
--    · les objets `Cooldown`, dont le balayage est peint par le moteur ;
--    · tout cadre `IsForbidden` : y toucher lève une erreur.
--
--  Les cadres du client sont résolus par leur nom global **à chaque passage**, et
--  une absence est ignorée. C'est la forme que prend ici la règle « test de
--  capacité, jamais de numéro de patch » : une fenêtre qui n'existe pas encore
--  (chargée à la demande, créée en entrant en groupe) ou plus (retirée à une
--  extension) ne casse rien.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local U    = BUI.Util

local S = {}
BUI.Shade = S

--- Voir `U.IsSecret`, où le prédicat vit depuis qu'un deuxième fichier s'en
--- sert. Il n'écarte qu'une **valeur** dont on s'apprête à faire un calcul,
--- jamais le cadre qui la porte : écarter un cadre sur ce soupçon reviendrait à
--- décider qu'il est intouchable sans avoir essayé, et c'est précisément ce qui
--- a fait disparaître les cadres d'unités d'un mode sombre qui les traitait
--- très bien la veille.
local secret = U.IsSecret

--- Appelle une méthode du client et rend sa valeur, ou `nil` si l'appel lève.
---
--- **Tout** ce que ce fichier demande à un cadre passe par ici. On ne devine
--- jamais ce qui est touchable : on essaie, et un échec ne coûte que l'appel qui
--- a échoué. C'est la seule stratégie qui reste juste quand le client ajoute des
--- protections d'une extension à l'autre — une liste de gardes écrite à la main
--- est fausse le jour où elle est écrite, et fausse autrement six mois plus tard.
---@param frame table
---@param method string
---@return any
local function ask(frame, method)
    local getter = frame[method]
    if type(getter) ~= "function" then return nil end
    local ok, value = pcall(getter, frame)
    if ok then return value end
    return nil
end

--- Même chose pour les méthodes qui rendent une liste variadique.
---@param frame table
---@param method string
---@return table
local function askAll(frame, method)
    local getter = frame[method]
    if type(getter) ~= "function" then return {} end
    local ok, list = pcall(function() return { getter(frame) } end)
    if ok then return list end
    return {}
end

-- =========================================================================
--  Ce que porte chaque élément
-- =========================================================================

--- élément -> noms globaux des cadres du client.
local FRAMES = {
    -- `MainMenuBarVehicleLeaveButton` a vécu dans cette liste, et c'était une
    -- erreur de classement : sur un bouton d'action, la texture normale est
    -- l'anneau de la case — de l'habillage — mais sur lui elle est **tout son
    -- visage**, la flèche rouge de sortie de véhicule. Assombrie au facteur des
    -- barres, elle devenait un disque noir. Même précédent que la croix de
    -- l'infobulle de lien (`SPARE_BUTTONS`) : un bouton dont la face entière
    -- dit « cliquez-moi » ne se teint pas, on ne le visite pas du tout.
    actionBars = {
        "MainMenuBar", "MainMenuBarArtFrame",
        "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft",
        "MultiBar5", "MultiBar6", "MultiBar7",
        "StanceBar", "PetActionBar", "PossessActionBar",
    },

    -- La barre véhicule, à part des autres barres : même case de réglage, autre
    -- main. Son habillage n'est pas fait de fins ornements mais d'un panneau
    -- d'art opaque qui couvre toute la barre — au facteur commun il devient une
    -- plaque noire où seules les icônes restent lisibles (voir
    -- `T.SHADE_FACTOR_VEHICLE`, qui dit le dosage et pourquoi).
    vehicleBar = { "OverrideActionBar" },

    castBar = {
        "PlayerCastingBarFrame", "PetCastingBarFrame",
        "TargetFrameSpellBar", "FocusFrameSpellBar",
    },

    -- Cadres d'unités « classiques ». Les cadres de **groupe et de raid** n'y
    -- sont pas, et c'est délibéré : les atteindre par leur conteneur comme par
    -- leurs noms globaux n'a rien donné, et rien n'indique pour l'instant que
    -- le client laisse teinter leur habillage. Y revenir demandera de
    -- comprendre d'abord *comment* ils sont peints, pas d'ajouter des noms.
    --
    -- Les cadres de **boss** n'y sont plus non plus, et pour une autre raison :
    -- ce sont des cadres de combat. Ce qu'on y lit — qui est ciblé, qui incante,
    -- combien il reste de vie — se lit vite ou ne se lit pas, et un habillage
    -- assombri les rapproche du fond au moment précis où ils comptent le plus.
    -- Le mode sombre range l'interface ; il n'a rien à faire sur ce qui sert à
    -- réagir.
    unitFrames = {
        "PlayerFrame", "PetFrame",
        "TargetFrame", "TargetFrameToT",
        "FocusFrame", "FocusFrameToT",
    },

    auras = { "BuffFrame", "DebuffFrame" },

    -- La ressource personnelle, sous le personnage. Un cadre à part entière
    -- depuis Midnight — plus une barre de nom : `C_NamePlate` ne la rend plus,
    -- même affichée, et son nom global est le seul chemin qui y mène (relevé en
    -- jeu, voir `dev/docs/API_NOTES.md`). Son habillage est celui du
    -- gestionnaire de temps de recharge — mêmes atlas de fond —, la teinte des
    -- deux va donc ensemble visuellement, sans que rien ne les lie.
    personalResource = { "PersonalResourceDisplayFrame" },

    tooltip = { "GameTooltip", "ItemRefTooltip" },

    -- Le grimoire, et **lui seul**. Le nom global d'avant la refonte, pour les
    -- clients qui l'ont encore ; la fenêtre actuelle passe par `NESTED`, qui va
    -- chercher la page des sorts sans prendre la fenêtre qui la porte — ni ses
    -- onglets, ni la partie talents, ni la barre de spécialisation.
    --
    -- **Chargé à la demande** : le cadre n'existe pas tant que le joueur ne l'a
    -- pas ouvert une fois, et la teinte se pose donc au rafraîchissement que
    -- `ADDON_LOADED` déclenche — c'est pour cela que le module écoute cet
    -- événement.
    --
    -- Les icônes de sorts gardent leur contour : il dit la nature du sort, et
    -- c'est ce que `ICON_BORDERS` protège.
    spellbook = { "SpellBookFrame" },

    -- Gestionnaire de temps de recharge. Quatre visionneuses, dont certaines
    -- n'existent que si le joueur les a activées : on cite les quatre et on
    -- prend celles qui répondent présent.
    cooldownManager = {
        "EssentialCooldownViewer", "UtilityCooldownViewer",
        "BuffIconCooldownViewer", "BuffBarCooldownViewer",
    },
}

---@param element string
---@param name string
local function alsoWatch(element, name)
    local names = FRAMES[element]
    names[#names + 1] = name
end

-- La barre d'action principale n'est pas atteignable par sa seule barre : ses
-- boutons sont nommés globalement et ne descendent pas forcément d'elle. On les
-- cite donc un par un, ce qui reste vrai quel que soit leur parent.
for i = 1, 12 do
    alsoWatch("actionBars", "ActionButton" .. i)
end

--- Éléments dont les icônes n'ont **pas** de contour et à qui il faut donc en
--- poser un.
---
--- La liste est courte, et le vérifier avant d'y ajouter une entrée évite un
--- défaut qu'on ne reconnaît pas au premier coup d'œil : un élément qui a déjà
--- son habillage reçoit alors deux contours — le sien, teinté par le moteur, et
--- le nôtre par-dessus. Le rendu n'est pas franchement cassé, il est seulement
--- *différent* du reste, ce qui est plus long à diagnostiquer.
---
--- Un emplacement du gestionnaire de temps de recharge est nu de cette
--- façon-là : relevé sur le client, il ne porte que son icône, un masque, la
--- texture d'état `OutOfRange` et l'atlas `UI-HUD-CoolDownManager-IconOverlay`.
--- Aucune texture de contour à emprunter, d'où son entrée ici. Une icône d'aura
--- est nue pour la même raison.
local ICON_BORDERS = {
    auras           = true,
    cooldownManager = true,
}

--- Clés sous lesquelles un cadre publie son contour. Sur les éléments qui
--- reçoivent un contour commun, ces textures-là sont **laissées au widget**, qui
--- les rhabille : les teinter en plus reviendrait à les traiter deux fois.
---
--- `DebuffBorder` en fait partie depuis que le client habille chaque aura d'un
--- liseré sous cette clé. Le widget l'emprunte et le rhabille quel que soit
--- son atlas — l'uniforme voulu par le joueur (voir `borrowFrom` dans
--- `UI/Widgets/ShadeBorder.lua`) ; ici on se contente de ne pas le teinter en
--- plus.
local BORDER_KEYS = { "Border", "IconBorder", "DebuffBorder" }

--- Clés sous lesquelles un cadre publie son **fond**, par opposition à son
--- contour. La pièce centrale d'un nine-slice en fait partie : c'est elle qui
--- peint la surface, les huit autres dessinent le cadre. La graphie minuscule
--- est celle des barres de plaque, qui publient leur fond en camelCase.
local BACKGROUND_KEYS = { "Center", "Bg", "Background", "background" }

--- Éléments dont la texture `Border` n'est pas de l'habillage mais un **signal**.
---
--- Sur un bouton d'action, l'habillage est porté par `NormalTexture`, `SlotArt`,
--- `SlotBackground` et `BorderShadow`. `Border`, elle, reste masquée la plupart
--- du temps et ne s'affiche que pour **dire** quelque chose : le jeu la montre en
--- vert pour marquer un objet équipé posé sur la barre — un bijou à effet
--- utilisable, typiquement.
---
--- Le nom trompe, et c'est tout le piège : « bordure » se lit comme de
--- l'habillage, et rien dans le classement ne distinguait celle-ci d'un cadre de
--- fenêtre. L'assombrir éteignait le seul repère qui distingue un bijou d'un
--- sort. Ailleurs — une infobulle, un cadre d'unité — une bordure est bien de
--- l'habillage, d'où la liste par élément plutôt qu'une règle générale.
local BORDER_SIGNALS = { actionBars = true, vehicleBar = true }

--- Éléments dont on ne descend pas sous les **boutons**.
---
--- Un bouton d'action porte une douzaine de cadres enfants, et pas un seul n'est
--- de l'habillage : animations d'incantation, réticule de cible, éclat de fin de
--- temps de recharge, halo d'attaque automatique, balayages. Tous disent quelque
--- chose, tous étaient assombris — donc éteints —, et plusieurs sont **anonymes**,
--- si bien qu'aucune liste de noms ne pouvait les rattraper.
---
--- On s'arrête donc au bouton : ses propres textures sont teintées, ce qu'il
--- porte ne l'est pas. Les barres elles-mêmes restent parcourues, elles sont
--- citées à part dans `FRAMES` — c'est là qu'est l'habillage d'une barre
--- d'action, jamais sous un bouton.
local FLAT_BUTTONS = { actionBars = true, vehicleBar = true }

--- Éléments dont on assombrit le contour **sans toucher au fond**.
---
--- Une infobulle est le cas d'école : son fond fait partie de sa lisibilité, le
--- jeu l'a réglé pour que le texte s'y détache, et l'assombrir change autre
--- chose que l'habillage. Ailleurs — un cadre d'unité, une barre d'action — le
--- fond *est* de l'habillage et suit le reste.
local KEEP_BACKGROUND = {
    tooltip = true,

    -- Une plaque aussi : son habillage est le **contour** de ses barres, et
    -- c'est lui qu'on assombrit. Le fond d'une barre de sorts couvre toute la
    -- barre — teinté, c'est la barre entière qui devient une plaque noire, et
    -- le sort en cours ne se lit plus qu'à son remplissage.
    nameplates = true,

    -- La barre d'incantation, pour la même raison : son contour s'assombrit,
    -- son fond garde sa couleur. Teinté, il faisait de la barre entière un
    -- pavé noir. La zone du nom de sort, en dessous, n'est pas un fond mais
    -- une seule image (`TextBorder`) : elle continue de s'assombrir.
    castBar = true,
}

--- Éléments dont on ne touche **pas aux boutons du tout** — ni leurs textures,
--- ni ce qu'ils portent.
---
--- L'infobulle de lien (`ItemRefTooltip`) — celle qui s'ouvre au clic sur un
--- haut fait ou un objet dans le chat — porte une croix de fermeture. C'est un
--- contrôle, pas de l'habillage : sa croix rouge désaturée puis assombrie
--- devenait une croix noire, et le joueur y lisait « le mode sombre déborde sur
--- la fenêtre des hauts faits ». Un bouton sur une infobulle n'a jamais rien
--- d'autre à dire que « cliquez-moi » — on s'arrête à sa porte.
local SPARE_BUTTONS = {
    tooltip = true,
}

--- Éléments qui **gardent leur couleur**.
---
--- Le moteur désature avant d'assombrir, et c'est le bon choix presque
--- partout : l'habillage du client est doré, et un doré simplement foncé
--- reste doré — sombre et jaune, ce qui n'est pas ce qu'on cherche.
---
--- Le parchemin du grimoire est l'exception. Désaturé, il devient une page
--- grise ; gardé, il fonce en restant brun, ce qui est exactement l'effet
--- qu'on veut de lui.
local KEEP_COLOR = {
    spellbook = true,
}

-- Une **teinte colorée** a vécu ici, pour pousser le parchemin vers le brun en
-- même temps qu'on l'assombrissait. Elle est partie deux fois, et la seconde
-- est la bonne : le brun ne vient pas d'une inclinaison, il vient de ce qu'on
-- **ne désature pas**. Un multiplicateur neutre sur un beige rend un brun ;
-- l'incliner en plus vire au marron.

--- Éléments dont les textes passent au blanc.
---
--- **C'est la seule entorse du moteur à sa propre règle**, et elle se paie
--- comptant : une couleur de texte dit souvent quelque chose, et la remplacer
--- efface ce qu'elle disait. Ici elle ne dit rien — le client écrit le nom de
--- ses sorts en brun foncé parce que le parchemin est clair, et une page
--- assombrie les rend illisibles.
---
--- Les couleurs d'origine sont relevées une par une et reposées à
--- l'extinction, comme celles des textures.
local WHITE_TEXT = {
    spellbook = true,
}

--- Cadres qui ne portent pas de nom global et qu'il faut aller chercher sur leur
--- porteur.
local NESTED = {
    -- **La page des sorts, et rien autour.** La fenêtre actuelle porte trois
    -- choses : la spécialisation, les talents et le grimoire. Prendre la fenêtre
    -- entière assombrissait les trois, plus ses onglets et son cadre — beaucoup
    -- trop pour une case qui dit « grimoire ».
    --
    -- Aucune de ces pièces n'a de nom global : elles se demandent à la fenêtre,
    -- et chaque accès est gardé — le client peut renommer ou déplacer n'importe
    -- laquelle, et une clé absente ne rend rien plutôt que de lever.
    spellbook = function(collect)
        local frame = PlayerSpellsFrame
        if type(frame) ~= "table" then return end

        local book = frame.SpellBookFrame
        if type(book) ~= "table" then return end
        collect(book)

        -- **Les lignes de sorts ne sont pas des enfants ordinaires.** Le
        -- parcours descend par `GetChildren`, et elles n'y sont pas : elles
        -- sortent d'un pool que deux vues mettent en page, et se demandent
        -- par `GetLayoutChildren`. C'est ce qui faisait que le fond du livre
        -- fonçait pendant que les noms de sorts restaient noirs — on ne les
        -- avait jamais vus.
        --
        -- Chaque maillon est gardé : deux vues aujourd'hui, une autre
        -- demain, et une clé absente ne rend rien plutôt que de lever.
        local paged = book.PagedSpellsFrame
        if type(paged) ~= "table" then return end

        for _, key in ipairs({ "View1", "View2" }) do
            local view = paged[key]
            if type(view) == "table"
               and type(view.GetLayoutChildren) == "function" then
                local ok, rows = pcall(view.GetLayoutChildren, view)
                if ok and type(rows) == "table" then
                    for i = 1, #rows do collect(rows[i]) end
                end
            end
        end
    end,

    -- Les auras de la cible et du focus sortent d'un **pool** porté par leur
    -- cadre d'unité : elles n'ont ni nom global, ni place fixe. On énumère donc
    -- celles qui sont actives à l'instant du passage, et `UNIT_AURA` nous
    -- ramène ici quand elles changent.
    --
    -- Elles sont aussi croisées par le parcours des cadres d'unités, qui
    -- descend jusqu'à elles. Sans conséquence : ce parcours-là ne touche pas
    -- aux icônes, et une texture d'habillage teintée deux fois de la même
    -- façon reste teintée une fois.
    auras = function(collect)
        local frames = { TargetFrame, FocusFrame }
        for i = 1, #frames do
            local pools = frames[i] and frames[i].auraPools
            if pools and pools.EnumerateActive then
                for aura in pools:EnumerateActive() do
                    collect(aura)
                end
            end
        end

        -- Les auras affichées sous le personnage, avec la ressource
        -- personnelle. Ce sont des buffs et des debuffs comme les autres : leur
        -- place est ici, sous la même option, et non avec la barre qui les
        -- porte. Elles vivent sur la barre de nom du joueur, qui n'existe que
        -- lorsque cet affichage est allumé.
        collect(PersonalFriendlyBuffFrame)

        if C_NamePlate and C_NamePlate.GetNamePlateForUnit then
            local plate = C_NamePlate.GetNamePlateForUnit("player")
            local unitFrame = plate and plate.UnitFrame
            if unitFrame then collect(unitFrame.BuffFrame) end
        end
    end,

    -- Les barres d'infos : l'habillage de chaque plaque à l'écran — le contour
    -- de sa barre de vie, celui de sa barre de sorts. Elles n'ont ni nom
    -- global ni place fixe : on prend celles qui existent à l'instant du
    -- passage, et chaque plaque qui monte ensuite est teinte une par une par
    -- le module (`NAME_PLATE_UNIT_ADDED` → `ApplyTo`).
    --
    -- Ce que la plaque **dit** est déjà protégé par le classement commun : le
    -- remplissage des barres (`GetStatusBarTexture`), les icônes, la
    -- surbrillance de la cible (`Highlight`, voir `STATE_KEYS`) et les cadres
    -- de signal (`SIGNAL_FRAMES`) ne se teignent pas.
    nameplates = function(collect)
        if not (C_NamePlate and C_NamePlate.GetNamePlates) then return end

        local ok, plates = pcall(C_NamePlate.GetNamePlates)
        if not (ok and type(plates) == "table") then return end

        for i = 1, #plates do
            local unitFrame = plates[i] and plates[i].UnitFrame
            if unitFrame then collect(unitFrame) end
        end
    end,
}

-- =========================================================================
--  Classement des textures
-- =========================================================================

--- Clés sous lesquelles un cadre du client publie un portrait. Intouchables.
local PORTRAIT_KEYS = { "portrait", "Portrait", "PortraitTexture", "PlayerPortrait" }

--- Clés sous lesquelles il publie une icône. Assombries, mais progressivement.
local ICON_KEYS = { "icon", "Icon" }

--- Textures qu'un bouton ne publie pas dans ses régions : elles se demandent.
--- C'est par là que passe l'habillage d'un bouton d'action — sans cette liste,
--- une barre d'action entière échappe au parcours sans que rien ne le signale.
---
--- La normale et elle seule. Les autres — enfoncé, coché, désactivé, survolé —
--- ne sont pas de l'habillage mais du **retour visuel** : elles disent au joueur
--- ce qui se passe. Les assombrir revient à éteindre le signal, et c'est ainsi
--- qu'une lueur de survol dorée devient une auréole noire.
local BUTTON_TEXTURES = { "GetNormalTexture" }

--- Textures d'état, à ne jamais teindre, pour la même raison. Elles se
--- demandent au cadre plutôt que de se reconnaître à leur nom : c'est le cadre
--- qui sait laquelle est laquelle.
local STATE_TEXTURES = {
    "GetHighlightTexture", "GetPushedTexture", "GetCheckedTexture", "GetDisabledTexture",
}

--- Textures d'état que le cadre ne rend par aucune méthode et qu'il faut donc
--- reconnaître autrement.
---
--- Un emplacement du gestionnaire de temps de recharge publie `OutOfRange` :
--- c'est le voile qui dit au joueur que la cible est hors de portée. Aucun
--- `Get…Texture` ne le rend, il échappe donc à `STATE_TEXTURES` et se retrouvait
--- classé comme habillage — donc assombri, donc éteint au moment précis où il a
--- quelque chose à dire. Le défaut ne se voit qu'à distance, ce qui explique
--- qu'il ait tenu.
---
--- Les quatre suivantes sont la même histoire sur un bouton d'action : la lueur
--- d'un procédé, celle d'un sort suggéré, celle d'un objet prêt à servir. Le
--- symptôme, lui, était trompeur — **la lueur apparaissait au survol**, puis
--- s'éteignait à l'usage suivant. C'est la signature d'un signal éteint et non
--- d'un signal absent : le client repeint la texture quand le curseur passe
--- dessus, notre passage la rassombrit au coup d'après, et on cherche du côté de
--- ce qui *déclenche* la lueur alors que le problème est ce qui la couvre.
---
--- `Highlight` est une texture de surbrillance — cible sélectionnée, survol —
--- du retour visuel par définition, comme `GetHighlightTexture` l'était déjà
--- chez les textures qui se demandent.
---
--- `DebuffBorder` et `TempEnchantBorder` ont vécu dans cette liste : l'anneau
--- d'un type de dissipation et le violet d'un enchantement d'arme disent bien
--- quelque chose. Le joueur a pourtant tranché contre eux — depuis que le
--- client habille *chaque* aura d'un liseré, trois régimes se côtoyaient sur
--- une même rangée, et l'uniforme sombre lui importe plus que le type dans le
--- trait, qui reste dit ailleurs (cadres de groupe, symbole daltonien). Le
--- premier est rhabillé par le widget (voir `BORDER_KEYS`), le second
--- s'assombrit comme l'habillage qu'il est redevenu.
---
--- `HighLevelTexture` est le crâne du cadre de cible — celui qui remplace le
--- niveau quand la cible dépasse le vôtre au point de ne plus se mesurer. Il
--- **dit** « hors de votre portée », dans l'emblème que tout le jeu emploie
--- pour cela. C'est la seule marque de classification du cadre dont le nom ne
--- contient ni « Icon » ni « Portrait » : ses voisines (`BossIcon`,
--- `RaidTargetIcon`, la dorure `BossPortraitFrameTexture`) sont écartées par le
--- classement, lui tombait dans l'habillage et sortait en médaillon noir.
---
--- `BorderShield` est l'écu d'une barre d'incantation : le jeu le montre quand
--- le sort en cours **ne peut pas être interrompu**, et sur une plaque il prend
--- alors la place de l'icône du sort — les deux ne s'affichent jamais ensemble
--- (`HideIconWhenNotInterruptible`, voir `CastingBarMixin:UpdateIconShown`).
--- C'est donc l'icône que le joueur voit, et elle ne dit qu'une chose, la seule
--- qui compte à cet instant : inutile de couper. Son nom commence par
--- « Border », ce qui la faisait classer dans l'habillage : elle sortait en écu
--- noir, et le symptôme se raconte « quand un sort n'est pas interruptible,
--- l'icône est en mode sombre ».
--- `highLevelTexture` est le même crâne sur la pastille de niveau des plaques
--- de *Forever*, écrit avec une minuscule : la recherche de nom distingue la
--- casse, la graphie de retail ne le couvrait pas.
---
--- `PvpBackgroundIcon` est l'emblème de faction que *Forever* pose sur les
--- cadres du joueur et de la cible, dans un rond (`PvpBackgroundCircle`). Le
--- rond est l'habillage et s'assombrit ; l'emblème **dit** « JcJ activé, dans
--- ce camp » et sortait en disque noir. Son nom contient bien « Icon », mais le
--- rattrapage par le nom ne l'avait pas écarté : la clé, elle, ne dépend pas de
--- ce que `GetDebugName` veut bien rendre.
---
--- `LevelBackgroundCircle` est le rond qui porte le niveau sur ces mêmes
--- cadres. Pas un signal au sens strict, mais le fond d'un chiffre, comme celui
--- d'une infobulle : assombri, le niveau se lisait sur une pastille noire.
---
--- `deselectedOverlay` est le voile que le client pose, depuis 12.1, sur toute
--- la barre des plaques **non ciblées** pour les éteindre. Ni « Highlight » ni
--- « Glow » dans son nom : le tri le prenait pour de l'habillage, et un voile
--- clair assombri devient un couvercle noir.
---
--- Son frère `selectedBorder`, le liseré blanc de la **cible**, a été protégé
--- avec lui puis rendu à l'habillage : c'est un contour, et le joueur le veut
--- sombre comme celui des autres plaques. La cible reste désignée par le voile
--- que les autres portent. Le client le repeint en blanc à chaque changement
--- de cible — le module repasse derrière (`PLAYER_TARGET_CHANGED`).
---
--- `totalAbsorb`, son `totalAbsorbOverlay` et les deux prévisions de soins sont
--- le **bouclier d'absorption** et les soins en route, dessinés par-dessus le
--- remplissage de la barre de vie. Ce ne sont pas des textures d'habillage :
--- elles disent combien de bouclier il reste. Assombries, elles couvraient la
--- barre d'un couvercle noir — sur les seuls mobs à bouclier, l'add d'affixe en
--- tête, ce qui faisait accuser sa couleur. La preuve est dans le relevé de la
--- sonde : leur frère `overAbsorbGlow` porte « Glow » dans son nom, lui seul
--- était protégé, lui seul était resté blanc (voir `dev/docs/API_NOTES.md`).
local STATE_KEYS = { "OutOfRange", "SpellHighlight", "Glow", "Alert", "Proc",
                     "Highlight",
                     "HighLevelTexture", "highLevelTexture",
                     "PvpBackgroundIcon", "LevelBackgroundCircle",
                     "BorderShield",
                     "deselectedOverlay",
                     "totalAbsorb", "totalAbsorbOverlay",
                     "myHealPrediction", "otherHealPrediction" }

--- Fragments de nom d'un **cadre entier** qui signale au lieu de décorer.
---
--- Une lueur de procédé n'est pas une texture mais un petit cadre, qui en porte
--- plusieurs : un départ d'animation, une boucle, parfois un halo. Les écarter
--- une par une revient à parier qu'on les a toutes nommées, et ce pari se perd à
--- chaque extension qui en ajoute une.
---
--- On s'arrête donc à la porte : le cadre n'est pas descendu du tout. C'est la
--- même économie que `STATE_TEXTURES` — on écarte par ce que la chose *est*, pas
--- par la liste de ce qu'elle contient.
---
--- « Feedback » : le petit cadre qu'une barre de ressource fait clignoter au
--- gain et à la perte. Il ne décore rien, il ponctue — et sa texture de flash
--- ne porte pas « Glow » dans son nom, elle échapperait donc au tri texture par
--- texture.
---
--- « AbsorbBar », « HealPredictionBar », « ManaCostPrediction » : les segments
--- que les cadres d'unités posent **par-dessus** leurs barres — bouclier
--- d'absorption, absorption de soins, soins en route, coût du sort en cours.
--- Sur les plaques ce sont des textures (voir `STATE_KEYS`) ; sur le cadre de
--- cible ce sont des cadres entiers (`TotalAbsorbBar` et ses frères, chacun
--- portant `Fill` et `TiledFillOverlay`), et c'est donc ici qu'ils s'écartent.
--- Assombri, le bouclier de l'add d'affixe couvrait de noir la barre de vie du
--- cadre de cible — même mob, même semaine, autre porteur que les plaques.
local SIGNAL_FRAMES = { "Glow", "Alert", "Proc", "Highlight", "Assisted",
                        "Feedback",
                        "AbsorbBar", "HealPredictionBar", "ManaCostPrediction" }

--- Les ressources de classe du client, enfants du cadre du joueur et donc
--- croisées par son parcours. **On ne les visite pas** : même doctrine que les
--- cadres de boss, sortis de `FRAMES` — ce sont des lectures de combat, où la
--- plaque sombre du client et les crans qui s'allument dessus se lisent vite ou
--- ne se lisent pas. Assombries, la puissance sacrée d'un paladin devenait une
--- plaque noire.
---
--- Des noms globaux, comme `FRAMES`, et le même contrat : un client qui n'a pas
--- l'un de ces cadres ne fait qu'ignorer son nom. Le totem d'un chaman ferme la
--- liste — pas une ressource au sens strict, mais la même lecture posée au même
--- endroit.
local READOUT_NAMES = {
    "PaladinPowerBarFrame", "RuneFrame", "WarlockPowerFrame",
    "ComboPointPlayerFrame", "RogueComboPointBarFrame", "DruidComboPointBarFrame",
    "MonkHarmonyBarFrame", "MonkStaggerBar", "MageArcaneChargesFrame",
    "EssencePlayerFrame", "InsanityBarFrame",
    "DemonHunterSoulFragmentsBar", "DevourerFuryBar", "DevourerFuryBarFrame",
    "AlternatePowerBar", "PlayerFrameAlternateManaBar",
    "TotemFrame",

    -- La seconde famille de barres de ressource du client, relevée en jeu par
    -- `/bui glow` sous le cadre du joueur — même lecture, autre habillage. Sur
    -- un paladin, c'est celle-là qui sortait encore en plaque noire.
    "ClassNameplateBarPaladinFrame", "ClassNameplateBarDracthyrFrame",
    "ClassNameplateBarRogueFrame", "ClassNameplateBarFeralDruidFrame",
    "ClassNameplateBarMageFrame", "ClassNameplateBarWindwalkerMonkFrame",
    "ClassNameplateBarWarlockFrame",
}

--- cadre -> vrai, pour les lectures de combat présentes sur ce client.
--- Rebâtie à chaque parcours : plusieurs de ces cadres se créent à la demande —
--- à la première spécialisation qui s'en sert — et une table figée au
--- chargement les manquerait.
local readouts = {}

--- Textures précises qu'on ne teint pas, désignées par leur chemin depuis un
--- cadre global. Le dernier recours, quand ni une clé ni un nom ne suffisent :
--- la même clé est de l'habillage à un endroit et un cache à un autre.
---
--- Le rond de l'emblème JcJ du **joueur**, sur *Forever*. Sur la cible,
--- Blizzard le pose une couche sous l'emblème ; sur le joueur, les deux
--- partagent la même couche et l'ordre n'est pas garanti. Désaturé et
--- assombri, le rond passait devant et l'emblème disparaissait sous un disque
--- noir — alors qu'il se voit très bien sans mode sombre. Le rond de la cible,
--- lui, reste assombri : c'est le contour de l'emblème.
local SPARE_PATHS = {
    { "PlayerFrame", "PlayerFrameContent", "PlayerFrameContentMain", "PvpBackgroundCircle" },
}

--- texture -> vrai, rebâtie à chaque parcours comme `readouts`.
local spared = {}

local function refreshReadouts()
    wipe(readouts)
    for i = 1, #READOUT_NAMES do
        local frame = _G[READOUT_NAMES[i]]
        if type(frame) == "table" then readouts[frame] = true end
    end

    wipe(spared)
    for i = 1, #SPARE_PATHS do
        local path = SPARE_PATHS[i]
        local node = _G[path[1]]
        for j = 2, #path do
            if type(node) ~= "table" then break end
            node = node[path[j]]
        end
        if type(node) == "table" then spared[node] = true end
    end
end

---@param owner table
---@param region table
---@param keys string[]
---@return boolean
local function publishedAs(owner, region, keys)
    for i = 1, #keys do
        if owner[keys[i]] == region then return true end
    end
    return false
end

--- région -> son nom de débogage, relevé une fois. Clés faibles : ce cache ne
--- retient rien en vie, et il voit passer bien plus de monde que `originals` —
--- portraits et signaux compris, qu'on ne teinte jamais.
local names = setmetatable({}, { __mode = "k" })

--- Nom de débogage d'une région, quand le client sait le donner. Les cadres du
--- client nomment leurs textures : « …Portrait », « …Icon » s'y lisent, ce qui
--- rattrape les textures qu'aucune clé ne publie.
---
--- **Le dernier segment, et lui seul.** `GetDebugName` rend le chemin complet —
--- `BuffIconCooldownViewer.…12ab.…34cd` — et chercher un mot dans tout ce chemin
--- fait porter à une texture le nom de ses ancêtres. Une visionneuse qui
--- s'appelle `BuffIconCooldownViewer` rendait ainsi *toutes* ses textures
--- « icônes », habillage compris : le suivi des améliorations n'a jamais pris la
--- teinte, alors que les trois autres visionneuses, aux noms sans « icon », la
--- prenaient très bien. Le nom d'un cadre parle du cadre, pas de ce qu'il porte.
---
--- **`type(name) == "string"` ne suffit pas.** Le client rend ce nom en valeur
--- *secrète* dès que l'exécution est teintée par un addon — et une chaîne
--- secrète est bel et bien une chaîne, donc le test de type la laisse passer.
--- L'indexer pour appeler `match` lève alors, et l'erreur remonte hors du seul
--- appel fautif : elle interrompt tout le parcours de l'élément. C'est ainsi
--- qu'un module qui se contentait de poser une couleur de classe sur une barre
--- de vie a éteint le mode sombre des cadres d'unités entiers — le module
--- teintait l'exécution, le nom devenait secret, et le parcours mourait à la
--- première texture. Rien dans le symptôme ne désignait le coupable.
---
--- Sans nom, on ne perd que le rattrapage : le classement retombe sur les clés
--- que le cadre publie, et le nom n'a jamais servi qu'à **écarter**, jamais à
--- décider qu'une texture est touchable.
---
--- **Le nom est relevé une fois par région.** `GetDebugName` reconstruit le
--- chemin complet en remontant les parents un à un : c'est la lecture la plus
--- chère du parcours, et elle est demandée deux fois par région — une fois pour
--- écarter les signaux, une fois pour classer. Or ce nom ne bouge pas : une aura
--- sortie d'un pool garde son parent et son rang dans la liste, et un cadre du
--- client ne change pas de nom en cours de session. Seules les **réussites**
--- entrent dans `names` : un nom illisible l'est parce que l'exécution était
--- teintée à cet instant précis, et le retenir figerait un accident de passage
--- pour le reste de la session.
---@param region table
---@return string|nil
local function debugName(region)
    local known = names[region]
    if known then return known end

    local name = ask(region, "GetDebugName")
    if type(name) ~= "string" or secret(name) then return nil end

    name = name:match("[^.]+$") or name
    names[region] = name
    return name
end

--- Ce cadre est-il tout entier un signal ?
---
--- Le nom seul, sans clé publiée en secours : un cadre de lueur est porté sous
--- des noms qui changent d'une extension à l'autre, quand il est publié tout
--- court. Sans nom lisible on ne perd rien de plus qu'avant — le parcours
--- descend, et les textures se trient une par une comme auparavant.
---@param frame table
---@return boolean
local function signalsFrame(frame)
    local name = debugName(frame)
    if not name then return false end

    for i = 1, #SIGNAL_FRAMES do
        if name:find(SIGNAL_FRAMES[i], 1, true) then return true end
    end
    return false
end

--- Cette texture dit-elle un état au joueur, plutôt que de décorer ?
---
--- La clé d'abord, le nom ensuite : le cadre qui publie sa texture sous une clé
--- d'état est le cas sûr, et le nom rattrape celle qu'aucune clé ne publie.
--- C'est le même partage que pour les portraits et les icônes, et le nom y a le
--- même rôle — il ne sert qu'à **écarter**, jamais à décider qu'on peut toucher.
---@param owner table
---@param region table
---@return boolean
local function signalsState(owner, region)
    if publishedAs(owner, region, STATE_KEYS) then return true end

    local name = debugName(region)
    if not name then return false end

    for i = 1, #STATE_KEYS do
        if name:find(STATE_KEYS[i], 1, true) then return true end
    end
    return false
end

--- « portrait » (jamais touché), « icon » (jamais teintée, éventuellement
--- bordée) ou « art » (teintée).
---
--- Seule une texture que son porteur publie **sous une clé d'icône** est traitée
--- comme une icône bordable. Se fier au nom pour cela reviendrait à border tout
--- ce qui s'appelle « …Icon », y compris des fonds de la taille d'un conteneur
--- entier — on l'a vu donner une icône géante sur le suivi des auras. Le nom ne
--- sert donc qu'à écarter.
---@param owner table
---@param region table
---@return string
local function classify(owner, region)
    if publishedAs(owner, region, PORTRAIT_KEYS) then return "portrait" end
    if publishedAs(owner, region, ICON_KEYS) then return "icon" end

    local name = debugName(region)
    if name and (name:find("[Pp]ortrait") or name:find("[Ii]con")) then return "portrait" end

    return "art"
end

-- =========================================================================
--  État
-- =========================================================================

--- texture -> apparence relevée avant la première teinte
local originals = {}
--- élément -> { art = { textures }, icons = { textures } }
local painted = {}
--- élément -> { factor = , icon = }
local active = {}

-- =========================================================================
--  Collecte
-- =========================================================================

---@param frame table|nil
---@param out table
---@param seen table
---@param rules table  { reskins = boolean, keepBackground = boolean }
local function collectFrom(frame, out, seen, rules)
    if type(frame) ~= "table" or type(frame.GetObjectType) ~= "function" then return end
    if seen[frame] then return end
    seen[frame] = true

    if ask(frame, "IsForbidden") == true then return end
    if ask(frame, "GetObjectType") == "Cooldown" then return end

    -- Un cadre de l'addon lui-même ne se visite pas : ni lui, ni ce qu'il
    -- porte. Nos widgets se posent en enfants de cadres du client que le
    -- moteur assombrit — les repères de la barre de ressource personnelle,
    -- ses textes — et le parcours les croisait comme n'importe quel enfant :
    -- un trait que le thème dit blanc ressortait gris. Leurs couleurs sont
    -- celles du thème, il n'y a rien à corriger dessus.
    if frame.buiOwn then return end

    -- Une lecture de combat ne se visite pas : ni elle, ni ce qu'elle porte
    -- (voir `READOUT_NAMES`).
    if readouts[frame] then return end

    -- Un bouton d'un élément qui les épargne ne se visite pas : ni ses
    -- textures, ni ses enfants (voir `SPARE_BUTTONS`). Avant toute prise —
    -- c'est ce qui le distingue de `flatButtons`, qui prend l'habillage du
    -- bouton et ne s'arrête qu'à ses enfants.
    if rules.spareButtons and ask(frame, "GetObjectType") == "Button" then return end

    -- Un cadre qui n'existe que pour signaler ne se visite pas : ni lui, ni ce
    -- qu'il porte. Protégé comme le reste du classement — un doute se tranche en
    -- ne touchant pas, ce qui laisse au pire une lueur claire sur une barre
    -- sombre, là où l'erreur inverse éteint le signal.
    -- Noms distincts de ceux du classement texture par texture, plus bas : les
    -- deux tests se ressemblent, et une fermeture imbriquée qui réemploie les
    -- mêmes noms masque la variable de son englobante.
    local frameKnown, frameSignals = pcall(signalsFrame, frame)
    if not frameKnown or frameSignals then return end

    -- Ce que ce cadre affiche pour informer, et non pour décorer : le
    -- remplissage de sa barre (vie, ressource, temps restant) et ses textures
    -- d'état. Rien de tout cela ne s'assombrit.
    local spare = { ask(frame, "GetStatusBarTexture") }
    for i = 1, #STATE_TEXTURES do
        spare[#spare + 1] = ask(frame, STATE_TEXTURES[i])
    end

    ---@param region any
    ---@return boolean
    local function informs(region)
        for i = 1, #spare do
            if spare[i] == region then return true end
        end
        return false
    end

    local function take(region)
        if type(region) ~= "table" or informs(region) or spared[region] then return end
        if type(region.SetVertexColor) ~= "function" then return end

        -- Protégé comme le classement plus bas, et pour la même raison : un
        -- échec ici ne doit coûter que cette texture. Sans cela, une seule
        -- région récalcitrante emporte le parcours entier et l'élément reste
        -- clair — le défaut se lit alors comme « le mode sombre ne marche plus »,
        -- ce qui n'oriente vers rien. Un doute se tranche en ne touchant pas.
        local known, signals = pcall(signalsState, frame, region)
        if not known or signals then return end

        -- Deux motifs distincts de laisser une bordure tranquille, et ils ne se
        -- confondent pas : ici on la rhabille nous-mêmes, là elle ne décore pas.
        if rules.reskins and publishedAs(frame, region, BORDER_KEYS) then return end
        if rules.borderSignals and publishedAs(frame, region, BORDER_KEYS) then return end

        -- La clé d'abord, le nom en rattrapage — même partage que les signaux :
        -- un fond qu'aucune clé ne publie porte « Background » dans son nom, et
        -- le nom ne sert qu'à écarter, jamais à décider qu'on touche.
        if rules.keepBackground then
            if publishedAs(frame, region, BACKGROUND_KEYS) then return end
            local bgName = debugName(region)
            if bgName and bgName:find("[Bb]ackground") then return end
        end

        local ok, kind = pcall(classify, frame, region)
        if not ok or kind == "portrait" then return end

        local bucket = out[kind]
        bucket[#bucket + 1] = region
    end

    for _, region in ipairs(askAll(frame, "GetRegions")) do
        if type(region) == "table" then
            local kind = ask(region, "GetObjectType")
            if kind == "Texture" then
                take(region)
            elseif kind == "FontString" and rules.whiteText then
                out.text[#out.text + 1] = region
            end
        end
    end

    -- L'habillage d'un bouton ne figure pas dans ses régions : il se demande.
    for i = 1, #BUTTON_TEXTURES do
        take(ask(frame, BUTTON_TEXTURES[i]))
    end

    -- Ce que porte un bouton n'est pas son habillage : c'est ce qu'il a à dire.
    -- On s'arrête ici, après avoir pris ses textures à lui (voir `FLAT_BUTTONS`).
    if rules.flatButtons and ask(frame, "GetObjectType") == "Button" then return end

    for _, child in ipairs(askAll(frame, "GetChildren")) do
        collectFrom(child, out, seen, rules)
    end
end

--- Ce que le parcours doit faire ou ne pas faire pour cet élément.
---@param element string
---@return table
local function rulesFor(element)
    return {
        reskins        = ICON_BORDERS[element] == true,
        keepBackground = KEEP_BACKGROUND[element] == true,
        borderSignals  = BORDER_SIGNALS[element] == true,
        flatButtons    = FLAT_BUTTONS[element] == true,
        spareButtons   = SPARE_BUTTONS[element] == true,
        whiteText      = WHITE_TEXT[element] == true,
    }
end

---@param element string
---@return table  { art = {}, icon = {} }
local function collect(element)
    local out   = { art = {}, icon = {}, text = {} }
    local seen  = {}
    local rules = rulesFor(element)

    refreshReadouts()

    -- `roots` et non `names` : le nom seul masquerait le cache de noms de
    -- débogage, déclaré plus haut dans ce fichier — deux choses différentes qui
    -- ne se distingueraient plus qu'à la portée.
    local roots = FRAMES[element]
    if roots then
        for i = 1, #roots do
            collectFrom(_G[roots[i]], out, seen, rules)
        end
    end

    local nested = NESTED[element]
    if nested then
        pcall(nested, function(frame) collectFrom(frame, out, seen, rules) end)
    end

    return out
end

-- =========================================================================
--  Teinte et restitution
-- =========================================================================

--- Apparence d'origine d'une texture, relevée une fois pour toutes.
--- Renvoie `nil` quand elle n'est pas lisible : le client peut rendre des
--- valeurs **secrètes**, sur lesquelles la moindre multiplication lève.
---@param texture table
---@return table|nil
local function remember(texture)
    local origin = originals[texture]
    if origin ~= nil then return origin or nil end

    local ok, r, g, b, a = pcall(texture.GetVertexColor, texture)
    if not ok or secret(r) or type(r) ~= "number" then
        originals[texture] = false   -- relevé impossible, ne pas y revenir
        return nil
    end

    origin = {
        r = r, g = g or 1, b = b or 1, a = a or 1,
        desaturated = texture.IsDesaturated and texture:IsDesaturated() or false,
        alpha = ask(texture, "GetAlpha") or 1,
    }
    originals[texture] = origin
    return origin
end

---@param texture table
---@param origin table
---@param factor number
---@param desaturate boolean
local function shade(texture, origin, factor, desaturate)
    if desaturate and texture.SetDesaturated then
        texture:SetDesaturated(true)
    end

    texture:SetVertexColor(origin.r * factor, origin.g * factor,
                           origin.b * factor, origin.a)
end

--- Teinte une liste de textures.
---
--- Chaque texture est isolée. C'est la même leçon qu'au niveau des éléments, un
--- cran plus bas : une seule texture qui lève emporterait sinon toutes celles
--- qui la suivent, et un cadre d'unité entier resterait clair à cause d'une de
--- ses vingt régions. On échoue donc texture par texture, jamais en bloc.
---@param textures table
---@param factor number
---@param desaturate boolean
local function paint(textures, factor, desaturate)
    for i = 1, #textures do
        local texture = textures[i]
        local origin  = remember(texture)
        if origin then pcall(shade, texture, origin, factor, desaturate) end
    end
end

---@param texture table
---@param origin table
local function unshade(texture, origin)
    if texture.SetDesaturated then texture:SetDesaturated(origin.desaturated) end
    texture:SetVertexColor(origin.r, origin.g, origin.b, origin.a)
end

-- -------------------------------------------------------------------------
--  Les textes qu'on blanchit
-- -------------------------------------------------------------------------
-- Voir `WHITE_TEXT`, qui dit pourquoi c'est une exception et à quel prix.
-- La mécanique est celle des textures, en plus simple : on relève une fois,
-- on écrit, on repose. `false` marque un relevé impossible — le client peut
-- rendre une couleur secrète — et évite d'y revenir à chaque passage.

--- texte -> couleur d'origine, ou `false`
local originalTexts = {}

--- Sommes-nous en train de blanchir ? Le hook ci-dessous guette l'écriture,
--- donc il rappellerait la nôtre.
local whitening = false

--- Repose notre blanc **chaque fois que le client réécrit la couleur**.
---
--- C'est ce qui manquait, et le symptôme ressemblait à un blanchiment qui ne
--- prend pas : le client repeint le nom de chaque sort à chacune de ses mises
--- en page — au survol, au changement de page, quand la recherche filtre — et
--- il le fait après nous. On ne peut pas deviner ces moments, et il n'y a pas
--- d'événement pour eux.
---
--- Se brancher sur l'**écriture** ne demande d'en connaître aucun : quel que
--- soit le chemin, il finit ici. C'est le parti pris de tout l'addon (voir
--- `hookNameColor` dans les barres d'infos), et il vaut ici pour la même
--- raison : on ne court pas après le client, on se met là où il écrit.
---@param text table
---@param element string
local function hookText(text, element)
    U.GuardedHook(text, "SetTextColor", function(self)
        if whitening then return end
        if not originalTexts[self] then return end

        whitening = true
        pcall(self.SetTextColor, self, T.COLOR.WHITE:GetRGB())
        whitening = false
    end, function()
        return active[element] ~= nil
    end)
end

---@param text table
---@param element string
local function whiten(text, element)
    local origin = originalTexts[text]

    if origin == nil then
        local ok, r, g, b, a = pcall(text.GetTextColor, text)
        if not ok or secret(r) or type(r) ~= "number" then
            originalTexts[text] = false
            return
        end
        origin = { r = r, g = g or 1, b = b or 1, a = a or 1 }
        originalTexts[text] = origin
    end

    if not origin then return end

    -- Le hook se pose avant l'écriture, et une seule fois par texte : posé
    -- après, il manquerait la remise en couleur qui suit immédiatement.
    hookText(text, element)

    whitening = true
    pcall(text.SetTextColor, text, T.COLOR.WHITE:GetRGB())
    whitening = false
end

---@param texts table
---@param element string
local function whitenAll(texts, element)
    for i = 1, #texts do
        pcall(whiten, texts[i], element)
    end
end

---@param texts table
local function unwhiten(texts)
    -- Sous le drapeau : sans lui, notre propre hook reposerait le blanc dans
    -- le souffle où on rend la couleur d'origine.
    whitening = true
    for i = 1, #texts do
        local text   = texts[i]
        local origin = originalTexts[text]
        if origin then
            pcall(text.SetTextColor, text, origin.r, origin.g, origin.b, origin.a)
        end
    end
    whitening = false
end

---@param textures table
local function unpaint(textures)
    for i = 1, #textures do
        local texture = textures[i]
        local origin  = originals[texture]
        if origin then pcall(unshade, texture, origin) end
    end
end


-- =========================================================================
--  Bords tracés
-- =========================================================================

--- icône -> son bord, ou `false` si le client n'a pas su le poser. La valeur
--- `false` compte : elle évite de retenter la création à chaque passage.
local borders = {}

--- icône -> ses coordonnées de texture d'origine, avant rognage.
local crops = {}

--- Rogne le liseré que l'icône porte **dans son image**. Sans ce rognage, notre
--- tracé s'ajoute à ce liseré au lieu de le remplacer, et le bord paraît deux
--- fois trop épais quelle que soit l'épaisseur qu'on lui donne.
---@param icon table
local function cropIcon(icon)
    if crops[icon] or type(icon.SetTexCoord) ~= "function" then return end

    local ok, ulx, uly, llx, lly, urx, ury, lrx, lry = pcall(icon.GetTexCoord, icon)
    if not ok or type(ulx) ~= "number" then return end

    crops[icon] = { ulx, uly, llx, lly, urx, ury, lrx, lry }

    local from, to = T.SIZE.SHADE_ICON_CROP, 1 - T.SIZE.SHADE_ICON_CROP
    icon:SetTexCoord(from, to, from, to)
end

---@param icon table
local function uncropIcon(icon)
    local origin = crops[icon]
    if not origin then return end
    crops[icon] = nil
    pcall(icon.SetTexCoord, icon, unpack(origin))
end

---@param icon table
---@param factor number
local function drawBorder(icon, factor)
    local border = borders[icon]
    if border == nil then
        border = BUI.Widgets.ShadeBorder(icon) or false
        borders[icon] = border
    end
    if not border then return end

    -- Le widget dit lui-même quand le rognage n'a pas lieu d'être : sur un
    -- liseré d'aura, l'anneau du client est fait pour l'icône entière.
    if not border.skipCrop then cropIcon(icon) end
    border:Draw(factor)
end

---@param icons table
---@param factor number
local function drawBorders(icons, factor)
    for i = 1, #icons do
        pcall(drawBorder, icons[i], factor)
    end
end

---@param icons table
local function hideBorders(icons)
    for i = 1, #icons do
        local icon   = icons[i]
        local border = borders[icon]
        if border then border:Hide() end
        uncropIcon(icon)
    end
end

---@param element string
local function restore(element)
    local lists = painted[element]
    if not lists then return end

    unpaint(lists.art)
    hideBorders(lists.icon)
    if lists.text then unwhiten(lists.text) end
    painted[element] = nil
end

--- Rend les seules textures qui étaient teintes et ne le sont plus — celles
--- qu'un nouveau parcours n'a pas retrouvées : une aura tombée, un cadre que le
--- client a rangé.
---@param previous table|nil
---@param current table
local function releaseMissing(previous, current)
    if not previous then return end

    local keep = {}
    for i = 1, #current.art do keep[current.art[i]] = true end
    for i = 1, #current.icon do keep[current.icon[i]] = true end

    local goneArt, goneIcon = {}, {}
    for i = 1, #previous.art do
        local texture = previous.art[i]
        if not keep[texture] then goneArt[#goneArt + 1] = texture end
    end
    for i = 1, #previous.icon do
        local icon = previous.icon[i]
        if not keep[icon] then goneIcon[#goneIcon + 1] = icon end
    end

    unpaint(goneArt)
    hideBorders(goneIcon)
end

--- Assombrit un élément. Rappeler après l'apparition de nouveaux cadres les
--- rattrape.
---
--- **On ne rend jamais avant de repeindre.** Rendre tout l'élément puis le
--- reteinter donnerait le même résultat — la teinte se recalcule toujours depuis
--- la couleur d'origine, donc repeindre une texture déjà teintée ne change rien
--- — mais chaque passage repasserait par un état clair. Sur un changement de
--- cible, où plusieurs passages s'enchaînent, cela se voit : l'interface a l'air
--- de « se rafraîchir » au lieu d'être simplement sombre. On ne rend donc que ce
--- qui **sort** du périmètre.
---@param element string
---@param factor number  voir `T.SHADE_FACTOR`
function S:Apply(element, factor)
    active[element] = factor

    local lists = collect(element)
    releaseMissing(painted[element], lists)
    painted[element] = lists

    paint(lists.art, factor, not KEEP_COLOR[element])
    if WHITE_TEXT[element] then whitenAll(lists.text, element) end

    -- À intensité nulle il n'y a rien à assombrir : rhabiller un contour à
    -- pleine clarté le remplacerait par un ornement que personne n'a demandé.
    if ICON_BORDERS[element] and factor < 1 then
        drawBorders(lists.icon, factor)
    end
end

--- Assombrit **un seul cadre**, au titre d'un élément déjà allumé.
---
--- Sert quand le client vient de reconstruire quelque chose et nous le dit :
--- inutile de reparcourir tout l'élément, et surtout inutile d'attendre le
--- prochain regroupement. Un cadre isolé se traite pour un coût si faible qu'on
--- peut le faire sur-le-champ, ce qu'un parcours complet interdirait.
---
--- Sans effet si l'élément est éteint : on ne rallume pas par la bande.
---@param element string
---@param frame table
function S:ApplyTo(element, frame)
    local factor = active[element]
    if not factor then return end

    local out = { art = {}, icon = {}, text = {} }
    collectFrom(frame, out, {}, rulesFor(element))

    paint(out.art, factor, not KEEP_COLOR[element])
    if WHITE_TEXT[element] then whitenAll(out.text, element) end
    if ICON_BORDERS[element] and factor < 1 then
        drawBorders(out.icon, factor)
    end

    -- Ces textures doivent pouvoir être rendues comme les autres : on les
    -- ajoute à ce que l'élément a déjà teinté. Un doublon dans la liste ne
    -- coûte rien, la restitution repose la même couleur d'origine deux fois.
    local lists = painted[element]
    if not lists then return end

    for i = 1, #out.art do lists.art[#lists.art + 1] = out.art[i] end
    for i = 1, #out.icon do lists.icon[#lists.icon + 1] = out.icon[i] end
    if lists.text then
        for i = 1, #out.text do lists.text[#lists.text + 1] = out.text[i] end
    end
end

--- Intensité en vigueur sur un élément, ou `nil` s'il n'est pas assombri.
---
--- La seule question qu'un cadre **à nous** ait à poser au moteur. La rangée
--- d'auras des barres d'infos porte le contour commun de l'addon : il se dessine
--- à pleine couleur d'ordinaire, et doit foncer avec le reste quand la teinte des
--- auras est allumée.
---
--- Poser la question au moteur et non au module `DarkMode` est délibéré : ce qui
--- décide est l'intensité **réellement appliquée**, pas l'état d'une case. Lire la
--- case reviendrait à refaire ailleurs le raisonnement qui vit ici — la case
--- maîtresse, celle de l'élément, et un module qui peut être éteint.
---@param element string
---@return number|nil
function S:FactorFor(element)
    return active[element]
end

--- L'intensité s'éteint **avant** de rendre, et l'ordre est un contrat : la
--- restitution passe par les écritures que la repose des anneaux d'auras
--- guette (voir `repost` dans `UI/Widgets/ShadeBorder.lua`), et une repose
--- encore armée regagnerait la course qu'on est en train d'arrêter.
---@param element string
function S:Restore(element)
    active[element] = nil
    restore(element)
end

--- Rend tous les éléments à leur état d'origine. Appelé par `OnDisable`.
function S:RestoreAll()
    for element in pairs(active) do
        active[element] = nil
        restore(element)
    end
end

--- Repasse la teinte sur les cadres apparus depuis le dernier passage : auras
--- recréées, cadres de groupe montés en entrant en groupe, fenêtre chargée à la
--- demande. Sans argument, sur tous les éléments allumés.
---@param element? string
function S:Refresh(element)
    if element then
        local factor = active[element]
        if factor then self:Apply(element, factor) end
        return
    end

    for name, factor in pairs(active) do
        self:Apply(name, factor)
    end
end

-- =========================================================================
--  Diagnostic
-- =========================================================================
-- `/bui glow` : ce que le mode sombre a fait au bouton sous le curseur.
--
-- Il existe pour une raison précise. Une texture de **signal** assombrie ne
-- ressemble pas à une texture assombrie : elle ressemble à une lueur qui
-- n'apparaît qu'au survol, ou à une bordure absente. Le symptôme désigne le
-- déclencheur, jamais le voile (voir `dev/docs/API_NOTES.md`). Reconnaître le cas
-- de l'extérieur demande de savoir *lequel* des vingt calques d'un bouton porte
-- la lueur — ce qu'aucune capture d'écran ne dit, et ce que ce fichier sait.
--
-- Il ne relève rien qu'on ne relève déjà : `originals` porte l'apparence d'avant
-- teinte de chaque texture qu'on a touchée. Répondre « celle-ci est à nous » est
-- une lecture de table, pas une mesure.

--- Trois secondes pour amener le curseur sur le bouton. Taper la commande occupe
--- la souris : sonder à l'instant même ne rendrait jamais que la fenêtre de chat.
local DIAGNOSE_DELAY = 3

--- Nom lisible d'une région, ou un repli.
---@param region table
---@return string
local function reportName(region)
    return debugName(region) or "?"
end

--- Une ligne par région : son nom, si elle est affichée, et si c'est nous qui
--- l'avons teintée — puis ce qu'elle affiche : atlas (ou fichier), marque de
--- désaturation, couleur de sommet. C'est ce qui permet de voir, sur pièces,
--- si une teinte a été posée, effacée, ou jamais tentée. Chaque lecture est
--- gardée : un secret s'écrit `?`, il ne fait pas taire la ligne.
---@param region table
---@param mine string
local function reportRegion(region, mine)
    local shown = ask(region, "IsShown") == true and "" or " (hidden)"
    local ours  = originals[region] ~= nil and (" <- " .. mine) or ""

    local image = ask(region, "GetAtlas")
    if type(image) ~= "string" or secret(image) or image == "" then
        image = ask(region, "GetTexture")
        if secret(image) then image = nil end
        image = image ~= nil and tostring(image) or "?"
    end

    local desat = ""
    local d = ask(region, "IsDesaturated")
    if d ~= nil and not secret(d) and d then desat = " desat" end

    local tint = "?"
    local okV, r, g, b = pcall(region.GetVertexColor, region)
    if okV and type(r) == "number" and not secret(r)
       and not secret(g) and not secret(b) then
        tint = string.format("%.2f %.2f %.2f", r, g, b)
    end

    BUI:Print("  " .. reportName(region) .. shown .. ours
        .. " | " .. image .. desat .. " | " .. tint)
end

--- Écrit dans le chat ce que porte le cadre sous le curseur.
---
--- On ne descend qu'**un** niveau d'enfants : c'est là que vivent les cadres de
--- lueur, et l'arbre complet d'un bouton d'action tient sur trente lignes qu'on
--- ne relit pas. Ce qu'on cherche est un nom, pas un inventaire.
function S:Diagnose()
    BUI:Print(ns.L["Glow diagnostic"])

    local function report(label)
        local focus = GetMouseFoci and GetMouseFoci()[1]
        if not focus and GetMouseFocus then focus = GetMouseFocus() end

        if type(focus) ~= "table" or type(focus.GetRegions) ~= "function" then
            BUI:Print(ns.L["Glow diagnostic nothing"])
            return
        end

        local mine = ns.L["Glow diagnostic darkened"]
        BUI:Print(reportName(focus) .. (label or ""))

        for _, region in ipairs(askAll(focus, "GetRegions")) do
            if ask(region, "GetObjectType") == "Texture" then
                reportRegion(region, mine)
            end
        end

        for _, child in ipairs(askAll(focus, "GetChildren")) do
            BUI:Print("  [" .. reportName(child) .. "]")
            for _, region in ipairs(askAll(child, "GetRegions")) do
                if ask(region, "GetObjectType") == "Texture" then
                    reportRegion(region, mine)
                end
            end
        end
    end

    C_Timer.After(DIAGNOSE_DELAY, function() report("") end)
end
