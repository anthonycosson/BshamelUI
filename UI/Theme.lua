-- =========================================================================
--  Bshamel UI — UI/Theme.lua
--  Source unique de vérité pour l'apparence.
--
--  Règle : aucune couleur, police, taille ou espacement littéral ailleurs que
--  dans ce fichier (voir CLAUDE.md, règle 2 — le job `lint` de la CI le
--  vérifie). Une valeur ajustée ici se propage à toute l'interface.
--
--  Parti pris : on n'invente presque rien. Les polices sont les objets de
--  police du client, les couleurs sont celles du client. Quand Blizzard
--  retouche sa direction artistique à un patch, l'addon suit sans code.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI

--- Objet couleur du client, renvoyé par `CreateColor` et par les globales
--- `*_FONT_COLOR`. Déclaré ici parce que l'analyse statique locale ne dispose
--- pas des annotations de l'API World of Warcraft.
---@class ColorMixin
---@field GetRGB fun(self: ColorMixin): number, number, number
---@field GetRGBA fun(self: ColorMixin): number, number, number, number
---@field WrapTextInColorCode fun(self: ColorMixin, text: string): string

local T = {}
BUI.Theme = T

-- =========================================================================
--  Géométrie
-- =========================================================================

T.SIZE = {
    WINDOW_W       = 900,   -- fenêtre d'options
    WINDOW_H       = 620,
    WINDOW_MIN_W   = 760,
    WINDOW_MIN_H   = 480,

    SIDEBAR_W      = 230,   -- colonne de navigation

    PADDING        = 16,    -- marge intérieure d'un pane
    GUTTER         = 10,    -- écart entre deux panes
    PANEL_PAD      = 6,     -- retrait du contenu à l'intérieur d'un panneau creusé

    PAGE_TITLE_H   = 46,    -- bloc du titre de page : le texte et son filet
    RULE_H         = 1,     -- épaisseur d'un filet de séparation

    ROW_H          = 30,    -- hauteur d'une ligne d'option
    ROW_GAP        = 6,     -- écart vertical entre deux lignes
    SECTION_GAP    = 16,    -- écart avant un en-tête de section
    SECTION_H      = 26,

    CONTROL_X      = 340,   -- abscisse du contrôle dans une ligne : c'est ce
                            -- nombre, et lui seul, qui aligne les cases à
                            -- cocher entre toutes les pages
    CONTROL_W      = 160,   -- largeur des dropdowns / sliders
    LABEL_INDENT   = 8,

    SIDEBAR_CAT_H  = 30,    -- bandeau d'en-tête de catégorie
    SIDEBAR_ITEM_H = 26,    -- entrée de module
    SIDEBAR_INDENT = 18,

    DIVIDER_W       = 2,    -- séparateur vertical entre navigation et contenu

    ICON            = 16,
    SCROLLBAR_W     = 20,   -- réservé à droite du contenu défilant
    THUMB_W         = 6,    -- largeur du curseur, une fois l'ascenseur dépouillé
    THUMB_MIN       = 24,   -- hauteur plancher du curseur d'ascenseur

    EDGE_SHADE      = 64,   -- profondeur du voile sombre aux bords de la fenêtre

    -- Retraits imposés par le cadre du client : barre de titre en haut, bordure
    -- nine-slice sur les côtés. Mesurés une fois, réutilisés partout.
    CHROME_TOP     = 30,
    CHROME_SIDE    = 10,
    CHROME_BOTTOM  = 10,

    -- Bouton de la minicarte, aux proportions **exactes** du client : une
    -- bordure de 53 pixels pour une zone cliquable de 31. On les a agrandies de
    -- moitié un temps, en se disant que le bouton d'un addon se cherche à la
    -- souris ; il ne se cherchait pas davantage, il dépassait simplement de la
    -- rangée. Un bouton d'addon qui a la taille de ceux du jeu se fond dans la
    -- même rangée, ce qui est exactement ce qu'on lui demande.
    --
    -- Le rapport entre les deux valeurs, lui, ne se touche pas : c'est lui qui
    -- loge l'icône dans le trou.
    MINIMAP_BUTTON = 31,
    MINIMAP_BORDER = 53,

    -- Bornes de ce qui **ressemble** à un bouton de minicarte, pour le tiroir qui
    -- range ceux des autres addons. Elles n'habillent rien : elles servent à
    -- reconnaître, et c'est la seule taille de cette table qui décrive un cadre
    -- qui ne nous appartient pas.
    --
    -- Elles encadrent largement la valeur du client, ci-dessus. Ce qu'elles
    -- écartent n'est pas le bouton d'un peu plus grand ou d'un peu plus petit,
    -- c'est ce qui n'est pas un bouton du tout : une **épingle** de carte fait la
    -- moitié d'un bouton, un panneau en fait le double.
    MINIMAP_BUTTON_MIN = 20,
    MINIMAP_BUTTON_MAX = 64,

    -- L'icône est **centrée** sur le bouton, et non posée par son coin comme le
    -- veut l'usage. L'usage suppose une icône carrée que la bordure recouvre sur
    -- ses bords ; la nôtre est un disque, qui doit remplir le trou et non s'y
    -- inscrire. Le trou étant centré, les deux décalages sont nuls — ils restent
    -- déclarés pour que le réglage se fasse ici et non dans le widget.
    --
    -- Sa taille est celle du **trou** de la bordure, mesurée à l'œil. Elle ne se
    -- déduit d'aucune des deux autres valeurs, et trois tentatives de l'en
    -- déduire ont échoué : ni le côté du carré de dix-sept pixels que posent les
    -- boutons du client, ni sa diagonale — l'anneau recouvre précisément les
    -- coins de ce carré, donc le trou tombe entre les deux —, ni une proportion
    -- de la bordure, le trou ne grandissant pas comme elle.
    --
    -- Trop grand, le disque déborde sur l'anneau ; trop petit, il laisse un jour.
    -- Le premier défaut est le plus discret des deux à petite taille : il est
    -- passé inaperçu jusqu'à ce qu'agrandir le bouton le rende évident.
    MINIMAP_ICON   = 25,
    MINIMAP_ICON_X = 0,
    MINIMAP_ICON_Y = 0,

    -- Écart entre le bord de la minicarte et le centre du bouton ; le rayon s'en
    -- déduit à l'exécution, la minicarte n'ayant pas la même taille partout.
    --
    -- Il vaut un peu moins que le rayon du bouton, de sorte que celui-ci mord
    -- sur l'anneau de la minicarte au lieu de flotter à côté. Grandir le bouton
    -- sans grandir cet écart le ferait empiéter sur la carte.
    MINIMAP_PAD    = 10,

    -- Côté d'une icône **carrée** posée dans le même trou, **quand le client ne
    -- sait pas masquer**. Le disque du logo remplit le trou ; une icône d'objet
    -- ou de sort a des angles, et à défaut de masque circulaire pour les couper,
    -- c'est le carré inscrit dans le cercle qui donne sa taille — au-delà, les
    -- quatre coins débordent sur l'anneau. Le carré inscrit dans un trou de
    -- 25 pixels mesure 25 / √2 ≈ 17,7 : on reste en dessous.
    MINIMAP_ICON_SQUARE = 17,

    -- Tiroir des boutons d'addons. C'est une liste, comme le menu de
    -- téléportation : elle en reprend donc la largeur et les marges, et n'a que
    -- sa hauteur de ligne à elle.
    --
    -- Cette hauteur est celle d'un bouton de minicarte du client : ce sont
    -- exactement ces boutons-là qu'on y range, et on ne les redimensionne pas —
    -- un bouton mis à l'échelle par nos soins ne retrouverait jamais sa taille
    -- d'origine si son addon la relit. C'est aussi la largeur de la colonne
    -- d'icônes, sur laquelle chaque bouton est centré.
    TRAY_CELL      = 32,
    TRAY_GAP       = 4,     -- écart entre le tiroir et le bouton qui l'ouvre
    TRAY_PAD       = 8,

    -- Menu de téléportation. Sa largeur est celle d'un nom d'objet complet
    -- (« Pierre de foyer du festival de la bière ») à la police des libellés.
    MENU_W         = 240,
    MENU_ROW_H     = 24,
    MENU_ICON      = 18,
    MENU_PAD       = 8,
    MENU_GAP       = 6,     -- écart entre le menu et le bouton qui l'ouvre
    MENU_ARROW     = 12,    -- flèche d'une ligne qui ouvre un sous-menu

    COUNTDOWN_PAD  = 4,     -- retrait du décompte dans la fenêtre qu'il coiffe

    -- Pièces posées sur les cadres de chat du client. La hauteur, elle, se
    -- règle en saisissant l'onglet : rien n'est ajouté pour elle.
    CHAT_BUTTON    = 16,    -- côté du bouton de copie
    CHAT_BUTTON_PAD = 4,

    -- Fenêtre de copie. Plus large que haute : on y lit des lignes de chat, et
    -- une ligne coupée se recolle mal une fois dans le presse-papier.
    -- Elle reste au-dessus des minimums de `W.Window`, qui borne tout
    -- redimensionnement.
    COPY_W         = 800,
    COPY_H         = 520,

    -- De combien le contour sombre d'une icône déborde de ses quatre bords.
    --
    -- Une **proportion** du côté de l'icône, avec un plancher et un plafond :
    -- l'atlas de bordure porte une marge transparente autour de son trait, si
    -- bien qu'étiré pile sur l'icône, l'anneau tombe à l'intérieur au lieu de
    -- l'entourer. Le débordement compense cette marge, et il doit donc grandir
    -- avec l'icône.
    --
    -- C'est le réglage à bouger si l'anneau mord sur l'image (descendre) ou
    -- flotte au large (descendre aussi). Il ne se monte que si l'anneau passe
    -- **sous** le bord de l'icône, ce qu'on n'a jamais vu.
    --
    -- La valeur est mesurée, pas déduite : à 3 px de débordement, une icône de
    -- 50 px porte un anneau collé et une icône de 30 px un anneau visiblement
    -- décollé. Le débordement qui colle vaut donc 3 pour 50, soit 6 %. Le ratio
    -- a longtemps valu le double, et le plafond de 3 px le masquait pour la
    -- seule taille où on le regardait — les deux erreurs se compensaient à
    -- 50 px et à 50 px seulement. Monter le plafond sans corriger le ratio
    -- décolle l'anneau partout ; c'est arrivé, et ça se voit tout de suite.
    --
    -- Plancher et plafond ne façonnent rien : ce sont des garde-fous, et ils
    -- doivent rester **hors** des tailles que le joueur peut choisir. Le
    -- gestionnaire de temps de recharge et les auras se règlent en jeu, et une
    -- borne qui mord ramène l'anneau à une épaisseur fixe, c'est-à-dire fausse
    -- partout sauf à une taille. Le plancher vaut 1 px parce qu'en dessous le
    -- trait disparaît sous le pixel.
    SHADE_BORDER_PAD       = 1,
    SHADE_BORDER_PAD_RATIO = 0.06,
    SHADE_BORDER_PAD_MAX   = 8,

    -- Fiche de personnage : la colonne de pastilles posée à côté de chaque
    -- emplacement. Une pastille par ligne.
    --
    -- La hauteur de ligne est le seul nombre qui façonne quelque chose ici : la
    -- colonne est centrée sur la case, donc quatre pastilles la débordent de
    -- deux lignes, une en haut et une en bas. Au-delà de dix pixels, elles
    -- commencent à mordre sur les cases voisines, qui ne sont espacées que d'une
    -- quarantaine de pixels d'axe en axe.
    SLOT_LINE_H     = 10,
    SLOT_INFO_W     = 120,  -- emprise du conteneur ; les pastilles se
                            -- dimensionnent sur leur texte, la largeur ne
                            -- façonne rien
    SLOT_INFO_GAP   = 9,    -- écart entre l'emplacement et sa colonne. Il doit
                            -- rester supérieur à l'épaisseur du liseré que le
                            -- client dessine autour d'une icône d'objet, sans
                            -- quoi les pastilles paraissent collées au cadre
    SLOT_TEXT_INSET = 2,    -- retrait du niveau d'objet posé sur l'icône

    -- Retrait de l'étiquette posée sur un objet rangé, depuis le coin bas-droit
    -- de sa case.
    --
    -- Nul : le nombre se cale dans l'angle. On l'avait d'abord rentré de trois
    -- pixels, en craignant qu'un nombre collé au bord se lise comme appartenant
    -- à la case voisine — les cases d'un sac se touchent. La crainte ne s'est pas
    -- vérifiée : la police à contour détache le chiffre de tout ce qu'il y a
    -- derrière, et rentrer le nombre le faisait flotter au milieu de l'icône au
    -- lieu de l'ancrer.
    --
    -- C'est le réglage à bouger pour déplacer l'étiquette. Une valeur négative
    -- la fait déborder **hors** de la case, ce qui la détache encore davantage
    -- de l'icône — au prix d'un empiétement sur la case d'à côté.
    BAG_TAG_INSET   = 0,


    -- De combien le bandeau passe au-dessus de son emplacement. La scène du
    -- personnage occupe la même strate que les emplacements : sans ce relèvement,
    -- le texte qui déborde sur le modèle passe dessous et disparaît.
    SLOT_INFO_LEVEL = 10,

    -- Panneaux autonomes de l'addon (suivi des résurrections de combat, barre de
    -- marqueurs, chrono mythique+, rappel de file). Ce sont de petites fenêtres
    -- posées à même l'écran : elles partagent une géométrie, sans quoi quatre
    -- pièces du même addon auraient quatre marges différentes.
    -- `PANEL_PAD` est déjà pris par le retrait d'un panneau creusé de la fenêtre
    -- d'options : ces trois-là portent donc leur propre préfixe.
    TOOL_PAD       = 8,
    TOOL_GAP       = 4,     -- écart entre deux lignes d'un panneau
    TOOL_TITLE_H   = 18,

    -- Suivi des résurrections de combat. La taille est un réglage : l'icône vit
    -- au milieu de l'écran d'un combat de raid, et ce qu'il faut voir d'un coup
    -- d'œil n'a pas la même taille pour tout le monde. Les bornes tiennent les
    -- extrêmes hors de portée — en dessous le compteur n'est plus lisible,
    -- au-dessus l'icône couvre le champ de bataille.
    BATTLE_RES_ICON = 40,
    BATTLE_RES_MIN  = 24,
    BATTLE_RES_MAX  = 80,

    -- Barre de marqueurs. La case est celle d'un bouton de barre d'action réduit :
    -- neuf cases doivent tenir sur une rangée sans que le panneau devienne une
    -- deuxième barre d'action.
    MARKER_CELL    = 26,
    MARKER_GAP     = 3,
    MARKER_ROW_GAP = 6,     -- écart entre la rangée de marqueurs et les boutons
    MARKER_BUTTON_W = 110,  -- vérification de présence et pull

    -- Chrono mythique+. Assez large pour un nom de donjon complet à la police des
    -- libellés, comme le menu de téléportation.
    KEY_TIMER_W    = 220,
    KEY_ROW_H      = 16,    -- ligne de palier ou de comparatif

    -- Rappel de la file. Une bannière, donc plus large que haute : elle porte un
    -- nom de donjon et un bouton.
    REMINDER_W     = 300,
    REMINDER_ICON  = 20,

    -- Fraction rognée sur chaque bord d'une icône avant d'y poser le contour.
    --
    -- Les icônes de sort portent un liseré sombre **dans leur image**. Sans
    -- rognage, notre contour s'ajoute à ce liseré au lieu de le remplacer, et le
    -- bord paraît deux fois trop épais quoi qu'on fasse.
    SHADE_ICON_CROP = 0.06,
}

-- =========================================================================
--  Minuteries
-- =========================================================================
-- Tout ce qui se compte en secondes et qui décide d'un rendu. Regroupé ici pour
-- la même raison que les opacités : ces valeurs se règlent les unes par rapport
-- aux autres, pas isolément au fil des fichiers.

T.TIMING = {
    DRAG          = 0.02,   -- suivi du curseur pendant un déplacement
    COUNTDOWN     = 0.1,    -- rafraîchissement d'un décompte affiché
    SHADE_QUICK   = 0.05,   -- second passage du mode sombre, juste après le
                            -- premier : le client rhabille un cadre d'unité
                            -- *après* avoir annoncé le changement de cible, et
                            -- ce délai-là doit rester invisible
    SHADE_SETTLE  = 0.2,    -- délai avant de repasser le mode sombre sur les
                            -- cadres apparus après coup (auras, fenêtres
                            -- chargées à la demande)

    -- Filet des cadres d'unités, une fois la rafale retombée. Il ne porte
    -- **rien de visible** : ce qui s'affiche est reposé par des hooks, au moment
    -- où le client écrit. Il ne rattrape que ce qu'aucune écriture n'annonce —
    -- la cible de la cible, qui n'est pas résolue quand la cible l'est, et un
    -- cadre né en cours de route.
    UNIT_SETTLE   = 0.2,

    CHAT_SETTLE   = 0.2,    -- regroupement des passages sur les cadres de chat :
                            -- le client annonce une couleur par type de
                            -- discussion et rouvre ses fenêtres une par une

    SLOT_INFO     = 0.1,    -- regroupement des relectures de l'équipement :
                            -- changer une pièce émet plusieurs événements
                            -- coup sur coup, et chacun relit les seize
                            -- emplacements
    -- Cadence de la veille sur la banque. Changer d'onglet n'émet aucun signal :
    -- c'est le seul endroit de l'addon qui scrute au lieu d'écouter (voir
    -- `Modules/Character.lua`). Elle ne tourne que banque ouverte, et chaque
    -- réveil ne fait que redemander une relecture déjà groupée — la valeur ne
    -- décide donc pas d'un coût, seulement du temps qu'un nombre périmé peut
    -- rester à l'écran.
    BANK_WATCH    = 0.25,
    BAG_TAG       = 0.2,    -- regroupement des relectures de sacs. Plus lâche
                            -- que la fiche : on parcourt l'arbre de chaque
                            -- conteneur ouvert, et un tri de sacs émet des
                            -- dizaines d'événements
    SLOT_INFO_SETTLE = 0.5, -- la même relecture, quand elle ne sert qu'à
                            -- rattraper des données d'objet arrivées en retard.
                            -- L'événement qui la déclenche est émis pour
                            -- n'importe quel objet interrogé dans l'interface,
                            -- donc en rafale et sans rapport avec la fiche

    CDM_SETTLE    = 0.15,   -- second passage sur le gestionnaire de temps de
                            -- recharge. Une amélioration qui tombe s'efface en
                            -- fondu : au moment où le client l'annonce, son
                            -- emplacement est encore opaque, donc encore compté

    -- Regroupement des relectures du pourtour de la minicarte. Large : les
    -- boutons d'addons apparaissent au chargement de leur addon, donc en rafale
    -- au démarrage puis presque jamais. Rien ne les annonce — c'est le seul
    -- endroit du tiroir qui attende au lieu d'écouter.
    TRAY_SETTLE   = 1.0,

    -- Regroupement des reconstructions du menu de téléportation. Un objet qui
    -- entre dans les sacs émet un événement par pile déplacée, et reconstruire
    -- le menu relit toute la liste.
    MENU_SETTLE   = 0.5,

    -- Sursis d'un sous-menu quand le curseur quitte la ligne qui l'ouvre. Il y a
    -- un écart entre les deux : sans ce délai, le sous-menu se refermerait sous
    -- le curseur pendant la traversée.
    MENU_HOVER    = 0.25,

    -- Cadence des temps de recharge affichés dans le menu de téléportation. Ils
    -- s'écrivent à la seconde : quatre passages par seconde suffisent à ce
    -- qu'aucun chiffre ne paraisse en retard, là où un passage par image en
    -- paierait soixante (règle 7). La cadence ne tourne que menu ouvert.
    MENU_COOLDOWN = 0.25,

    -- Cadence des passes de vente de camelote. Le serveur limite le débit des
    -- ventes : voir `Modules/Bags.lua`, qui explique pourquoi une seule passe ne
    -- suffit pas.
    SELL_PASS     = 0.5,

    -- Bride sur la reprise d'une CVar qu'un autre addon a écrite après nous.
    -- Assez court pour que le réglage reprenne la main tout de suite, assez long
    -- pour qu'un désaccord entre deux addons reste une oscillation lente et
    -- observable au lieu d'une boucle.
    CVAR_SETTLE   = 0.5,

    -- Cadence des panneaux de raid. Ils affichent des secondes : les rafraîchir
    -- à chaque image serait payer soixante fois le même texte (règle 7).
    BATTLE_RES    = 0.2,    -- charges de résurrection et temps avant la suivante
    KEY_TIMER     = 0.1,    -- chrono mythique+, qui affiche des dixièmes

    -- Regroupement des morts annoncées. Un wipe tue vingt personnes en une
    -- seconde : sans regroupement, c'est vingt lignes envoyées au groupe, donc
    -- une coupure du chat par le serveur. Une seule ligne les nomme toutes.
    DEATH_SETTLE  = 1.0,

    HOVER         = 0.1,    -- sondage de la fenêtre survolée, pendant qu'un
                            -- modificateur est tenu. Assez court pour que le
                            -- capteur de molette paraisse instantané, assez long
                            -- pour ne rien coûter — et il ne tourne que pendant
                            -- que la touche est enfoncée
}

-- =========================================================================
--  Polices
-- =========================================================================
-- Objets de police du client, jamais de chemin de fichier .ttf.
--
-- Comme pour les templates, on déclare des candidats par ordre de préférence.
-- Les variantes `Medium` et `Large2` sont récentes et ne sont garanties par
-- aucun contrat : une police inconnue passée à `CreateFontString` ne dégrade
-- pas, elle lève une erreur. On résout donc une fois au chargement, et on se
-- rabat sur la variante de base.

local FONT_CANDIDATES = {
    WINDOW_TITLE = { "GameFontNormal" },

    -- Titre de page en blanc et non en doré : c'est le repère principal de la
    -- zone de droite, il doit primer sur les en-têtes de section.
    PAGE_TITLE   = { "GameFontHighlightLarge2", "GameFontHighlightHuge", "GameFontHighlightLarge" },

    -- Décompte posé sur une fenêtre du client. Une police à contour d'abord :
    -- le chiffre se lit par-dessus une illustration, où une police sans contour
    -- se noie dès que le fond est clair.
    COUNTDOWN    = { "NumberFont_Outline_Huge", "NumberFontNormalHuge", "GameFontNormalHuge",
                     "GameFontNormalLarge" },

    -- Nombres posés sur l'icône d'un objet équipé (niveau d'objet, rang
    -- d'amélioration). Une police à contour, pour la même raison que le
    -- décompte : le chiffre se lit par-dessus une illustration.
    SLOT_BADGE   = { "NumberFont_Outline_Med", "NumberFontNormalSmall", "GameFontNormalSmall" },

    -- Texte du bandeau posé à côté d'un emplacement. La plus petite police
    -- lisible du client : seize bandeaux tiennent dans la hauteur de la fiche.
    SLOT_INFO    = { "GameFontHighlightSmall" },

    -- Texte de la fenêtre de copie. La police du chat d'abord : on y relit ce
    -- qu'on vient de lire dans le chat, à la même largeur de caractère.
    COPY         = { "ChatFontNormal", "GameFontHighlight" },

    -- Chrono mythique+. Une police à contour, pour la même raison que le
    -- décompte : le temps restant se lit par-dessus le décor d'un donjon, où une
    -- police sans contour se noie dès que le fond est clair.
    KEY_TIMER    = { "NumberFont_Outline_Large", "NumberFontNormalLarge",
                     "GameFontNormalLarge" },

    SECTION      = { "GameFontNormalMedium", "GameFontNormal" },
    LABEL        = { "GameFontHighlightMedium", "GameFontHighlight" },
    LABEL_SMALL  = { "GameFontHighlight", "GameFontHighlightSmall" },
    HINT         = { "GameFontDisableSmall" },
    SIDEBAR_CAT  = { "GameFontNormalMedium", "GameFontNormal" },
    SIDEBAR_ITEM = { "GameFontHighlightMedium", "GameFontHighlight" },
}

T.FONT = {}
for key, candidates in pairs(FONT_CANDIDATES) do
    local resolved = candidates[#candidates]
    for i = 1, #candidates do
        if _G[candidates[i]] then
            resolved = candidates[i]
            break
        end
    end
    T.FONT[key] = resolved
end

-- =========================================================================
--  Couleurs
-- =========================================================================
-- On réutilise les couleurs du client pour tout ce qui est structurel, et on
-- n'introduit qu'une seule couleur propre à l'addon : l'accent.

-- Répartition, calquée sur le panneau Options du client :
--   doré   → tout ce qui structure (catégories, en-têtes de section, entrées
--            de navigation au repos) ;
--   blanc  → ce qui est lu (titre de page, libellés d'options) et ce qui est
--            sélectionné, qui ressort ainsi sur le doré ambiant.
-- L'accent bleu reste la couleur de la marque — il vit dans le nom de l'addon,
-- pas dans le chrome de la fenêtre, où il jurerait avec l'interface du jeu.

T.COLOR = {
    ACCENT   = CreateColor(0.00, 0.68, 0.94),           -- le bleu de « Bshamel »
    NORMAL   = NORMAL_FONT_COLOR,                        -- doré Blizzard
    LABEL    = HIGHLIGHT_FONT_COLOR,                     -- blanc
    DISABLED = DISABLED_FONT_COLOR,                      -- gris
    WHITE    = WHITE_FONT_COLOR,
    RED      = RED_FONT_COLOR,
    GREEN    = GREEN_FONT_COLOR,

    -- Le troisième terme du feu tricolore : « fait, mais pas fini ». Il ne sert
    -- qu'entre le vert et le rouge — jamais à la place de l'un des deux — et
    -- c'est ce qui lui permet de garder un sens.
    --
    -- La globale du client d'abord, comme pour les autres : la teinte suit alors
    -- sa direction artistique. Le repli est un orange franc, choisi pour se
    -- distinguer du doré de l'interface, qui structure et n'alerte pas.
    ORANGE   = ORANGE_FONT_COLOR or CreateColor(1.00, 0.58, 0.20),
    SHADE    = CreateColor(0.00, 0.00, 0.00),            -- voile des bords

    -- Teinte du bandeau des en-têtes de catégorie. Un gris franc : la pierre du
    -- client est une pierre chaude, brun-doré, et un bandeau doré derrière un
    -- titre blanc se lit comme un surlignage, pas comme un en-tête. On la
    -- désature puis on la multiplie par ce gris.
    BAND     = CreateColor(0.42, 0.42, 0.45),

    -- Teinte du fond de la fenêtre. C'est **cette couleur** qui décide si la
    -- fenêtre est sombre, pas son opacité : le fond du template est une pierre
    -- claire, la multiplier est le seul moyen de l'assombrir. Une pointe de bleu
    -- pour éviter le gris mort.
    WINDOW   = CreateColor(0.13, 0.13, 0.16),

    -- Teinte du bandeau des en-têtes, appliquée par-dessus la texture de la
    -- barre de titre. Nettement plus sombre que le fond de la fenêtre : l'en-tête
    -- doit poser une plaque sous un titre blanc, pas éclaircir la colonne. Ce qui
    -- compte est l'**écart** avec `WINDOW`, pas la valeur absolue.
    TITLE_BAND = CreateColor(0.20, 0.20, 0.24),
}

-- =========================================================================
--  Opacités
-- =========================================================================
-- Une seule table pour toutes les transparences de l'interface. Elles se
-- règlent les unes par rapport aux autres — le fond d'une fenêtre, la teinte
-- d'une ligne survolée et celle d'une ligne sélectionnée forment une échelle —,
-- donc elles se lisent au même endroit.

T.ALPHA = {
    -- Opacité du fond de la fenêtre : à quel point le jeu transparaît derrière.
    -- Sa *clarté*, elle, ne se règle pas ici mais avec `T.COLOR.WINDOW`.
    --
    -- Assez haute pour que la fenêtre se lise pareil quelle que soit la scène
    -- derrière : ce qui transparaît d'un donjon noir ou d'une plaine ensoleillée
    -- ne change alors plus le fond que d'un cheveu. C'est l'autre moitié de la
    -- lisibilité « partout » — la première étant la clarté du fond lui-même.
    WINDOW_BG      = 0.92,

    EDGE_SHADE     = 0.45,  -- voile sombre au bord de la fenêtre,
                            -- dégradé vers l'intérieur. Il donne du poids au
                            -- cadre ; poussé plus haut il noircit les quatre
                            -- coins, où tombent justement la navigation et le
                            -- premier réglage de chaque page

    TITLE_BAND     = 1.00,  -- bandeau de catégorie portant la texture de la
                            -- barre de titre : pleine, pour qu'un en-tête et la
                            -- barre « Bshamel UI » se lisent identiques
    SIDEBAR_BAND   = 0.85,  -- le même bandeau, quand on a dû se rabattre sur la
                            -- pierre : gris et sombre, il peut être franc sans
                            -- attirer l'œil
    SIDEBAR_RULE   = 0.25,  -- filets qui bordent ce bandeau
    -- Les deux seuls fonds que porte une entrée de navigation, et jamais
    -- ensemble : opacité **au centre** du dégradé, qui s'estompe sur les deux
    -- bords. Hors survol et hors sélection, une entrée ne porte aucune texture
    -- — les bandeaux sont masqués, pas transparents.
    --
    -- Ces deux-là suivent la clarté du fond : un voile blanc posé sur un fond
    -- moins noir ajoute moins de lumière qu'avant (l'écart vaut `alpha × (1 −
    -- fond)`). Les monter d'autant conserve le saut visible entre une ligne au
    -- repos, survolée et sélectionnée, qui est tout ce que ces valeurs servent.
    ROW_HOVER      = 0.20,
    ROW_SELECTED   = 0.36,
    ITEM_OFF       = 0.55,  -- entrée d'un module éteint. « Éteint » doit rester
                            -- lisible : c'est la ligne sur laquelle on clique
                            -- pour rallumer le module

    RULE           = 0.35,  -- filet sous le titre de page
    SECTION_RULE   = 0.30,  -- filet d'un en-tête de section
    DIVIDER        = 0.30,  -- séparateur vertical, au plus fort de son dégradé
    THUMB          = 0.70,  -- curseur d'ascenseur

    CONTROL_OFF    = 0.50,  -- contrôle grisé
    GRIP           = 0.70,  -- poignée de redimensionnement au repos
    GRIP_HOVER     = 1.00,

    -- Pièces posées sur le chat du client, au repos. Plus discrètes que nos
    -- propres poignées : elles vivent par-dessus le texte que le joueur lit, et
    -- ce texte prime sur elles. Elles reviennent à pleine opacité au survol,
    -- qui est le seul moment où elles ont quelque chose à dire.
    CHAT_TOOL       = 0.35,
    CHAT_TOOL_HOVER = 1.00,
}

-- =========================================================================
--  Surfaces des fenêtres de l'addon
-- =========================================================================
-- `T.COLOR.WINDOW` et `T.COLOR.TITLE_BAND` sont les teintes que portent nos
-- propres fenêtres, et elles ne se règlent pas. Un curseur d'intensité a vécu
-- ici : il n'offrait qu'un dégradé de gris, réglé une fois puis oublié, et il
-- obligeait chaque surface à savoir se repeindre — un mécanisme entier pour une
-- valeur qui se décide une bonne fois. Elle se décide donc ici, comme toutes les
-- autres de ce fichier.
--
-- Deux formes de surface se rencontrent, et c'est au moment de la construction
-- qu'on sait laquelle s'applique : une **texture**, qu'on peint d'un aplat
-- (petits panneaux, tiroir, menus), et une **frame** dont le template fournit
-- déjà un fond, qu'on multiplie sans le remplacer (`T.SetPanelFill`).

--- Peint une surface qui porte le fond des fenêtres de l'addon.
---@param target table  frame ou texture
function T.WindowSurface(target)
    if target.SetColorTexture then
        target:SetColorTexture(T.COLOR.WINDOW:GetRGB())
        target:SetAlpha(T.ALPHA.WINDOW_BG)
    else
        T.SetPanelFill(target, T.COLOR.WINDOW, T.ALPHA.WINDOW_BG)
    end
end

--- Idem, pour le bandeau d'un en-tête de catégorie. Ce qui le fait lire est son
--- **écart** avec la colonne qui le porte, pas sa valeur absolue.
---@param texture table
function T.BandSurface(texture)
    texture:SetVertexColor(T.COLOR.TITLE_BAND:GetRGB())
    texture:SetAlpha(T.ALPHA.TITLE_BAND)
end

-- =========================================================================
--  Mode sombre
-- =========================================================================

--- Multiplicateur appliqué à la couleur de sommet des textures assombries.
---
--- L'assombrissement se fait en **multipliant** la couleur des textures du
--- client, jamais en posant un voile par-dessus : un voile dépend de l'ordre des
--- calques d'un template qui ne nous appartient pas, la multiplication agit sur
--- la texture elle-même (même raison que `SetPanelFill`).
---
--- Une seule valeur, sans dosage : le mode sombre est allumé ou éteint, et c'est
--- la **liste des éléments** qui se règle, pas la profondeur du noir. Un curseur
--- d'intensité n'offrait qu'un dégradé de gris sans usage — ce qu'on veut faire
--- varier, c'est ce qui s'assombrit, pas de combien.
---
--- Pas zéro : à zéro l'habillage devient une silhouette noire dont on ne
--- distingue plus les reliefs, ce qui n'est pas « sombre » mais « effacé ».
T.SHADE_FACTOR = 0.05

--- Débordement, en pixels, du contour sombre d'une icône de côté `side`.
---@param side number  plus petit côté de l'icône, en pixels
---@return number
function T.ShadeBorderPad(side)
    if not side or side <= 0 then return T.SIZE.SHADE_BORDER_PAD end

    local pad = side * T.SIZE.SHADE_BORDER_PAD_RATIO
    if pad < T.SIZE.SHADE_BORDER_PAD then return T.SIZE.SHADE_BORDER_PAD end
    if pad > T.SIZE.SHADE_BORDER_PAD_MAX then return T.SIZE.SHADE_BORDER_PAD_MAX end
    return pad
end

--- Couleur d'un décompte : vert au départ, rouge à l'échéance, dégradé entre
--- les deux. Les deux extrémités sont les couleurs du client.
---@param ratio number  1 au départ, 0 à l'échéance
---@return number r, number g, number b
function T.CountdownColor(ratio)
    if ratio < 0 then ratio = 0 elseif ratio > 1 then ratio = 1 end

    local r1, g1, b1 = T.COLOR.RED:GetRGB()
    local r2, g2, b2 = T.COLOR.GREEN:GetRGB()

    return r1 + (r2 - r1) * ratio,
           g1 + (g2 - g1) * ratio,
           b1 + (b2 - b1) * ratio
end

--- Retire le fond d'un panneau, en lui laissant sa bordure.
---
--- Un panneau creusé du client peint son fond de deux façons possibles : une
--- texture à lui, ou la pièce **centrale** de son nine-slice — laquelle est un
--- enfant du cadre, pas une région du panneau. Baisser l'alpha des seules
--- régions laisse donc le fond en place dans le second cas. On coupe les deux.
---
--- La bordure survit : ses huit autres pièces ne sont pas touchées. Le panneau
--- délimite donc la colonne sans poser la moindre teinte par-dessus le fond de
--- la fenêtre — les deux zones se lisent sur exactement la même surface.
---@param frame table
function T.ClearPanelBackground(frame)
    for _, region in ipairs({ frame:GetRegions() }) do
        if region.GetObjectType and region:GetObjectType() == "Texture" then
            region:Hide()
        end
    end

    if frame.NineSlice and frame.NineSlice.Center then
        frame.NineSlice.Center:Hide()
    end
end

--- Teinte une texture d'un dégradé d'une seule couleur : pleine d'un côté,
--- transparente de l'autre.
---
--- Renvoie `false` si le client ne sait pas dégrader une texture — l'appelant
--- doit alors se rabattre sur un aplat plutôt que de laisser une bande pleine
--- là où on attendait un fondu.
---@param texture table
---@param color ColorMixin
---@param alpha number         opacité de l'extrémité pleine
---@param orientation string   "HORIZONTAL" (min = gauche) ou "VERTICAL" (min = bas)
---@param opaqueAtMax boolean  l'extrémité pleine est-elle du côté « max » ?
---@return boolean applied
function T.ApplyGradient(texture, color, alpha, orientation, opaqueAtMax)
    if not texture.SetGradient then return false end
    texture:SetColorTexture(color:GetRGB())
    return T.FadeTexture(texture, color, alpha, orientation, opaqueAtMax)
end

--- Estompe une texture **existante** sans toucher à son image : la couleur de
--- sommet multiplie ce qui est déjà dessiné. C'est ce qui permet de faire
--- disparaître une texture de pierre à ses deux bouts sans la remplacer par un
--- aplat.
---@param texture table
---@param color ColorMixin
---@param alpha number
---@param orientation string
---@param opaqueAtMax boolean
---@return boolean applied
function T.FadeTexture(texture, color, alpha, orientation, opaqueAtMax)
    if not texture.SetGradient then return false end

    local r, g, b = color:GetRGB()
    local opaque = CreateColor(r, g, b, alpha)
    local clear  = CreateColor(r, g, b, 0)

    if opaqueAtMax then
        texture:SetGradient(orientation, clear, opaque)
    else
        texture:SetGradient(orientation, opaque, clear)
    end
    return true
end

--- Voile sombre, plein du côté du bord de la fenêtre.
---@param texture table
---@param orientation string
---@param edgeAtMax boolean
---@return boolean applied
function T.ApplyShade(texture, orientation, edgeAtMax)
    return T.ApplyGradient(texture, T.COLOR.SHADE, T.ALPHA.EDGE_SHADE, orientation, edgeAtMax)
end

--- Teinte et opacifie le fond d'un panneau, sans toucher à son contenu.
---
--- **On teinte la texture de fond, on ne pose rien par-dessus.** Le fond des
--- templates du client est une pierre claire : baisser ou monter son alpha ne
--- fait que doser sa propre clarté, jamais l'assombrir. Et un voile sombre posé
--- au-dessus dépend de l'ordre des calques du template, qui ne nous appartient
--- pas — si le template dessine son fond plus haut que notre voile, le voile ne
--- se voit jamais. La multiplication par une couleur sombre, elle, agit sur la
--- texture elle-même : elle marche quel que soit le calque.
---
--- On ne baisse jamais l'alpha de la frame elle-même, cela ferait pâlir ses
--- enfants avec elle. Le fond se cherche à trois endroits, du plus explicite au
--- plus général : la clé `Bg` que publient les templates, la pièce centrale du
--- nine-slice, et à défaut les textures du calque `BACKGROUND`.
---@param frame table
---@param color ColorMixin
---@param alpha number
function T.SetPanelFill(frame, color, alpha)
    local r, g, b = color:GetRGB()

    local function paint(texture)
        texture:SetVertexColor(r, g, b)
        texture:SetAlpha(alpha)
    end

    if frame.Bg then
        paint(frame.Bg)
    else
        for _, region in ipairs({ frame:GetRegions() }) do
            if region.GetObjectType and region:GetObjectType() == "Texture"
               and region:GetDrawLayer() == "BACKGROUND" then
                paint(region)
            end
        end
    end

    if frame.NineSlice and frame.NineSlice.Center then
        paint(frame.NineSlice.Center)
    end
end

--- Code couleur inline, pour les chaînes concaténées.
---@param color ColorMixin
---@param text string
---@return string
function T.Colorize(color, text)
    return color:WrapTextInColorCode(text)
end

--- Couleur d'un niveau d'objet, prise sur la qualité de l'objet.
---
--- Trois chemins, du plus récent au plus ancien : la fonction a migré dans
--- `C_Item`, la globale existe encore, et la table de couleurs est là depuis
--- toujours. Aucun n'est garanti pour toujours, aucun n'est nommé en dur
--- ailleurs qu'ici.
---@param quality? number
---@return number r, number g, number b
function T.ItemQualityColor(quality)
    if quality then
        if C_Item and C_Item.GetItemQualityColor then
            local r, g, b = C_Item.GetItemQualityColor(quality)
            if r then return r, g, b end
        end
        local entry = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
        if entry and entry.r then return entry.r, entry.g, entry.b end
    end
    return T.COLOR.WHITE:GetRGB()
end

--- Couleur d'un état « fait / pas fait ».
---
--- Les deux couleurs que porte une pastille de la fiche de personnage, et elles
--- se choisissent ici plutôt que dans le module : c'est le vocabulaire visuel de
--- l'addon, pas une décision propre à l'équipement.
---@param ok boolean
---@return number r, number g, number b
function T.StatusColor(ok)
    local color = ok and T.COLOR.GREEN or T.COLOR.RED
    return color:GetRGB()
end

--- Couleur d'un rang d'amélioration.
---
--- Trois états et non deux, parce que la question n'est pas la même : une pièce
--- améliorable **est** améliorée, elle ne l'est simplement pas à fond. Le rouge
--- des autres pastilles dirait « il manque quelque chose », ce qui est faux et
--- ferait crier toute une colonne pour un travail en cours.
---
--- Sans l'avertissement, le rang non maximal reste **vert** plutôt que gris ou
--- neutre : le joueur qui coupe ce réglage dit qu'il ne veut pas être relancé
--- là-dessus, pas qu'il veut une pastille de moins.
---@param maxed boolean
---@param warn boolean  teinter les rangs non maximaux ?
---@return number r, number g, number b
function T.UpgradeColor(maxed, warn)
    if maxed or not warn then return T.COLOR.GREEN:GetRGB() end
    return T.COLOR.ORANGE:GetRGB()
end

--- jeton de classe -> sa couleur, ou `false` si le client n'en connaît pas.
local classColors = {}

--- Couleur d'une classe de personnage, ou `nil` si la classe est inconnue.
---
--- On ne recopie pas les onze couleurs ici : ce sont celles du jeu, elles
--- changent avec lui, et un joueur qui reconnaît un mage à son bleu clair le
--- reconnaîtra dans notre teinte ou nulle part. Deux chemins, du plus récent au
--- plus ancien, aucun garanti pour toujours.
---
--- Le jeton attendu est le nom **anglais** de la classe (`"MAGE"`), celui que
--- rend le second retour de `UnitClass` — le premier est traduit et ne sert
--- qu'à l'affichage.
---
--- Le résultat est retenu par jeton. La fonction est appelée depuis un chemin
--- chaud — une barre de vie se met à jour à chaque coup reçu — et rien ne dit
--- que le client rend la même table à chaque appel (règle 7).
---@param class? string
---@return ColorMixin|nil
function T.ClassColor(class)
    if type(class) ~= "string" then return nil end

    local cached = classColors[class]
    if cached ~= nil then return cached or nil end

    local color
    if C_ClassColor and C_ClassColor.GetClassColor then
        color = C_ClassColor.GetClassColor(class)
    end
    if not color then
        color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] or nil
    end

    classColors[class] = color or false
    return color
end

--- Teinte du texte d'un widget selon son état actif/inactif.
---@param fontString table
---@param enabled boolean
function T.SetTextEnabled(fontString, enabled)
    local color = enabled and T.COLOR.LABEL or T.COLOR.DISABLED
    fontString:SetTextColor(color:GetRGB())
end

-- =========================================================================
--  Atlas / textures
-- =========================================================================
-- Uniquement des atlas du client (`SetAtlas`), jamais de chemin en dur.

T.ATLAS = {
    ARROW_RIGHT = "NPE_ArrowRight",
    CHECK       = "common-icon-checkmark",

    -- Croix des boutons « effacer ». Celle du client, pour la même raison que le
    -- reste : un joueur la reconnaît sans qu'on ait à écrire le mot dessus, ce
    -- qui laisse un bouton de la taille d'une case de marqueur.
    CLEAR       = "common-icon-redx",

    -- Contour posé autour d'une icône par le mode sombre.
    --
    -- La bordure de sort du client, et pas un anneau quelconque : ses coins sont
    -- **cassés en biseau**, ce qui est la forme que le jeu donne à ses icônes.
    -- Un cadre d'avatar ou de portrait a des angles droits et se reconnaît
    -- immédiatement comme une pièce rapportée.
    --
    -- Elle ne convient que là où l'on remplace un contour ou qu'il n'y en a
    -- aucun : ajoutée par-dessus un contour existant, son trait ouvragé dessine
    -- un second cadre à l'intérieur du premier.
    SHADE_BORDER = "Adventures-Spell-Border",

}

--- Chemins de texture, pour les rares cas sans atlas équivalent.
--- Toute nouvelle entrée passe par ici : aucun chemin littéral dans un widget.
T.TEXTURE = {
    RESIZE_GRIP = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up",

    -- Bandeau des en-têtes de catégorie. Une pierre tuilable du client, présente
    -- depuis toujours et jamais retouchée : c'est ce grain-là qui distingue un
    -- en-tête d'un aplat de couleur, et qui le rapproche du panneau Options.
    -- Ne sert plus que de repli : les en-têtes portent d'abord la texture de la
    -- barre de titre, relevée sur le cadre lui-même.
    SIDEBAR_BAND = "Interface\\FrameGeneral\\UI-Background-Rock",

    -- Bouton de la minicarte. La bordure et la surbrillance sont celles des
    -- boutons du client : un bouton d'addon qui ne ressemble pas aux siens se
    -- voit immédiatement, et se voit mal.
    MINIMAP_BORDER    = "Interface\\Minimap\\MiniMap-TrackingBorder",
    MINIMAP_HIGHLIGHT = "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight",

    -- Logo de l'addon, également déclaré comme icône du compartiment d'addons
    -- dans le `.toc`. Son disque alpha est **cuit dans la texture** : le trou de
    -- la bordure de minicarte est rond, et un masque posé à l'exécution serait
    -- une dépendance de plus, qui peut ne pas prendre (voir `API_NOTES.md`).
    MINIMAP_ICON      = "Interface\\AddOns\\BshamelUI\\media\\logo",

    -- Masque circulaire, pour qu'une icône **carrée** remplisse le trou d'un
    -- bouton de minicarte au lieu de s'y inscrire. Celui du portrait de
    -- personnage : c'est un disque plein, il est là depuis toujours, et il n'a
    -- pas de mode répétition — un masque et une répétition sont incompatibles
    -- (voir `dev/docs/API_NOTES.md`).
    CIRCLE_MASK       = "Interface\\CharacterFrame\\TempPortraitAlphaMask",

    -- Bouton du tiroir d'addons : le sac du client. Ce qu'il ouvre est
    -- littéralement un contenant — on y range ce qui traînait autour de la
    -- minicarte —, et l'icône existe depuis la première extension.

    -- Bouton du menu de téléportation : l'icône de la pierre de foyer. C'est le
    -- premier élément du menu, et celui que tout le monde reconnaît.
    MINIMAP_TELEPORT  = "Interface\\Icons\\INV_Misc_Rune_01",

    -- Repli d'une ligne qui ouvre une liste de donjons. Elle porte normalement
    -- l'icône que le **grimoire** donne à ce tiroir-là ; cette montre ne sert que
    -- si le grimoire n'en a pas.
    MENU_TIMEWAYS     = "Interface\\Icons\\INV_Misc_PocketWatch_01",

    -- Bouton de copie posé sur le cadre de chat : l'icône de note du client.
    -- C'est déjà ce qu'il met sur « du texte qu'on lit et qu'on recopie », et
    -- elle existe depuis toujours. Une icône de presse-papier n'existe pas dans
    -- le jeu, l'inventer ferait une pièce rapportée de plus.
    CHAT_COPY         = "Interface\\Buttons\\UI-GuildButton-PublicNote-Up",

    -- Planche des huit icônes de ciblage, celle que le client utilise partout —
    -- sur les unités marquées, dans son propre menu de marqueurs et sur la
    -- minicarte. C'est une planche de quatre colonnes sur quatre rangées dont
    -- les huit icônes occupent les deux premières : voir `T.RaidMarkerCoords`.
    RAID_MARKERS      = "Interface\\TargetingFrame\\UI-RaidTargetingIcons",
}

--- Coordonnées de l'icône de ciblage n° `index` dans la planche
--- `T.TEXTURE.RAID_MARKERS`.
---
--- Les icônes sont rangées de gauche à droite puis de haut en bas, quatre par
--- rangée, chacune occupant un quart de la planche dans les deux sens : étoile,
--- cercle, losange, triangle, lune, carré, croix, crâne.
---@param index number  1 à 8
---@return number left, number right, number top, number bottom
function T.RaidMarkerCoords(index)
    local column = (index - 1) % 4
    local row    = math.floor((index - 1) / 4)
    return column * 0.25, column * 0.25 + 0.25,
           row    * 0.25, row    * 0.25 + 0.25
end

--- Icône de ciblage qui illustre le marqueur au sol n° `index`.
---
--- Les deux numérotations ne coïncident pas, et rien dans le client ne les
--- relie : le marqueur au sol n° 1 est le **carré bleu**, qui porte l'icône de
--- ciblage n° 6. Cette table est donc une donnée de jeu, comme les listes
--- d'objets du menu de téléportation, et elle ne façonne rien : une entrée fausse
--- ne dessine pas le mauvais marqueur au sol — le clic passe par un attribut
--- sécurisé qui porte l'index, pas l'icône —, elle met la mauvaise vignette sur
--- le bouton.
T.WORLD_MARKER_ICON = { 6, 4, 3, 7, 5, 1, 2, 8 }

-- =========================================================================
--  Barre de titre : on la relève, on ne la nomme pas
-- =========================================================================
-- Les en-têtes de catégorie de la navigation portent la même texture que la
-- barre de titre de la fenêtre. On ne l'écrit nulle part : on la **copie** sur
-- le cadre au moment où il est créé.
--
-- Nommer un atlas ou un fichier ici serait un pari sur la structure interne d'un
-- template du client — celle-là même qui change d'une extension à l'autre.
-- Copier ce que le template a réellement posé reste juste quel que soit le
-- template retenu par `T.Template("WINDOW")`, et quel que soit le patch.

--- Clés sous lesquelles les templates du client publient le fond de leur barre
--- de titre, par ordre de préférence.
local TITLE_BAR_KEYS = { "TitleBg", "TopTileStreaks", "TitleBar", "Header" }

--- Apparence relevée, `nil` tant qu'aucune fenêtre n'a été construite.
local titleBar = nil

local function readTitleBar(region)
    if not (region and region.GetTexture) then return nil end

    if region.GetAtlas then
        local atlas = region:GetAtlas()
        if atlas then return { atlas = atlas } end
    end

    local file = region:GetTexture()
    if type(file) == "string" then return { texture = file } end
    return nil
end

--- Relève l'apparence de la barre de titre d'un cadre. Appelé une fois, par
--- `W.Window`, avant que quoi que ce soit d'autre ne soit dessiné.
---@param frame table
function T.CaptureTitleBar(frame)
    for i = 1, #TITLE_BAR_KEYS do
        local key = TITLE_BAR_KEYS[i]

        local look = readTitleBar(frame[key])
        if not look and frame.TitleContainer then
            look = readTitleBar(frame.TitleContainer[key])
        end

        if look then
            titleBar = look
            return
        end
    end
end

--- Applique cette apparence à une texture. Renvoie `false` si rien n'a été
--- relevé — l'appelant doit alors se rabattre sur son propre fond.
---@param texture table
---@return boolean applied
function T.ApplyTitleBar(texture)
    if not titleBar then return false end

    if titleBar.atlas then
        return T.TrySetAtlas(texture, titleBar.atlas)
    end

    texture:SetTexture(titleBar.texture)
    texture:SetHorizTile(true)
    return true
end

--- Applique un atlas si le client le connaît. Renvoie `false` sinon, sans
--- lever d'erreur : un atlas retiré à un patch ne casse pas l'interface.
---@param texture table
---@param atlasName string
---@return boolean applied
function T.TrySetAtlas(texture, atlasName)
    if not atlasName then return false end
    if C_Texture and C_Texture.GetAtlasInfo and not C_Texture.GetAtlasInfo(atlasName) then
        return false
    end
    texture:SetAtlas(atlasName)
    return true
end

-- =========================================================================
--  Templates du client
-- =========================================================================
-- Les widgets s'appuient sur des templates XML de Blizzard. Ils peuvent
-- disparaître ou être renommés d'une extension à l'autre : on déclare donc
-- des candidats par ordre de préférence, et le premier disponible gagne.
-- C'est la forme concrète de la règle « capability check, pas test de version ».

T.TEMPLATES = {
    -- `BasicFrameTemplate` d'abord : il fournit le cadre, la barre de titre et
    -- le bouton de fermeture sans le panneau creusé pleine surface de la
    -- variante `WithInset`, dont on n'a pas besoin puisqu'on pose nos deux
    -- panneaux nous-mêmes.
    WINDOW     = { "BasicFrameTemplate", "BasicFrameTemplateWithInset", "UIPanelDialogTemplate" },
    INSET      = { "InsetFrameTemplate3", "InsetFrameTemplate2", "InsetFrameTemplate" },
    BUTTON     = { "UIPanelButtonTemplate" },
    CHECKBOX   = { "UICheckButtonTemplate", "InterfaceOptionsCheckButtonTemplate" },
    SLIDER     = { "OptionsSliderTemplate" },
    DROPDOWN   = { "WowStyle1DropdownTemplate" },
    SCROLLPANE = { "UIPanelScrollFrameTemplate" },
    EDITBOX    = { "InputBoxTemplate" },

    -- Environnement restreint, seul moyen de repositionner un cadre **protégé**
    -- du client sans le tainter (voir `UI/Widgets/Mover.lua`). Sans candidat
    -- disponible, les cadres protégés ne se déplacent pas ; les autres, si.
    SECURE_HANDLER = { "SecureHandlerBaseTemplate" },

    -- Seul moyen pour un addon de lancer un sort ou d'utiliser un objet sur un
    -- clic : le client refuse ces actions depuis du code Lua ordinaire. Sans
    -- candidat disponible, le menu de téléportation ne se construit pas.
    SECURE_ACTION  = { "SecureActionButtonTemplate" },
}

local templateCache = {}

--- Le client connaît-il ce template ?
---@param name string
---@return boolean
function T.HasTemplate(name)
    local cached = templateCache[name]
    if cached ~= nil then return cached end

    local exists
    if C_XMLUtil and C_XMLUtil.GetTemplateInfo then
        exists = C_XMLUtil.GetTemplateInfo(name) ~= nil
    else
        -- Client sans C_XMLUtil : on tente la création dans un pcall.
        local ok = pcall(CreateFrame, "Frame", nil, nil, name)
        exists = ok
    end

    templateCache[name] = exists
    return exists
end

--- Premier template disponible dans la liste `T.TEMPLATES[kind]`.
--- Renvoie `nil` si aucun ne l'est — l'appelant doit alors se passer de
--- template plutôt que de lever une erreur.
---@param kind string  clé de T.TEMPLATES
---@return string|nil
function T.Template(kind)
    local candidates = T.TEMPLATES[kind]
    if not candidates then return nil end
    for i = 1, #candidates do
        if T.HasTemplate(candidates[i]) then return candidates[i] end
    end
    BUI:Warn("aucun template disponible pour « " .. kind .. " »")
    return nil
end
