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
    -- Fenêtre d'options. Ces deux nombres ne sont pas un goût : ils sont
    -- **mesurés** sur ce qu'il y a à montrer.
    --
    -- La hauteur est décidée par la colonne de navigation, pas par les pages :
    -- une colonne qui défile oblige à chercher une page qu'on devrait voir. Et
    -- depuis que le contenu s'ouvre en vue compacte (trois quarts de sa taille),
    -- la même fenêtre montre un quart de réglages en plus — la largeur suit,
    -- pour que la coupure en deux colonnes de la page des barres d'infos tienne
    -- d'emblée.
    --
    -- Le plafond est l'écran : `UIParent` fait 768 unités de haut sur un client
    -- réglé par défaut. 744 laisse douze unités de marge en haut et en bas —
    -- serré, mais la fenêtre reste déplaçable et redimensionnable pour qui veut
    -- autre chose.
    WINDOW_W       = 1120,
    WINDOW_H       = 744,
    WINDOW_MIN_W   = 760,
    WINDOW_MIN_H   = 480,

    -- Colonne de navigation. Élargie avec la fenêtre : « Gestionnaire de temps de
    -- recharge » est le plus long intitulé, et c'est lui qui décide de cette
    -- largeur. Elle ne se resserre pas pour autant sur lui — un intitulé suivi de
    -- « (Prochainement) » le dépasse, et c'est la longueur qu'il faut pouvoir
    -- porter le jour où une page s'annonce à nouveau.
    SIDEBAR_W      = 250,

    PADDING        = 16,    -- marge intérieure d'un pane
    GUTTER         = 10,    -- écart entre deux panes
    PANEL_PAD      = 6,     -- retrait du contenu à l'intérieur d'un panneau creusé

    PAGE_TITLE_H   = 40,    -- bloc du titre de page

    -- Rythme vertical d'une page.
    --
    -- Resserré d'environ un cinquième après coup, et le motif est mesurable : la
    -- page la plus chargée de l'addon compte une soixantaine de lignes, et quatre
    -- pixels gagnés par ligne en rendent une dizaine visibles sans défiler. Ce
    -- qu'on cherche n'est pas la densité pour elle-même, c'est de voir d'un coup
    -- les réglages qui se règlent les uns par rapport aux autres.
    --
    -- Le plancher est la case à cocher. On l'avait d'abord fixé à vingt-quatre
    -- pixels, en croyant qu'en dessous elle deviendrait une cible qu'on manque ;
    -- vérification faite, le client lui-même en pose entre vingt et vingt-six
    -- selon les panneaux. Vingt-deux est donc dans ce qu'il livre, et c'est là
    -- qu'on s'arrête — non par prudence, mais parce que rien au-delà n'est
    -- attesté.
    --
    -- La case a désormais sa propre mesure : elle **ne se déduit plus** de la
    -- hauteur de ligne. Les deux avaient été liées par commodité, et cette
    -- commodité empêchait de resserrer les lignes sans rapetisser la cible.
    ROW_H          = 24,    -- hauteur d'une ligne d'option
    CHECK_SIZE     = 22,    -- côté d'une case à cocher
    ROW_GAP        = 2,     -- écart vertical entre deux lignes
    SECTION_GAP    = 10,    -- écart avant un en-tête de section
    SECTION_H      = 22,



    CONTROL_X      = 340,   -- abscisse du contrôle dans une ligne : c'est ce
                            -- nombre, et lui seul, qui aligne les cases à
                            -- cocher entre toutes les pages
    CONTROL_W      = 160,   -- largeur des dropdowns / sliders
    LABEL_INDENT   = 8,

    -- Retrait supplémentaire d'une **sous-option** : une ligne qui ne veut rien
    -- dire sans celle du dessus. Le décalage seul ne suffit pas à le faire
    -- comprendre — un libellé décalé se lit comme un libellé mal aligné —, il
    -- s'accompagne d'un corps plus petit. Les deux ensemble disent « ceci dépend
    -- de cela », ce que ni l'un ni l'autre ne dit seul.
    --
    -- Même valeur que le retrait des entrées de la navigation : c'est la même
    -- idée de subordination, et deux retraits différents pour une seule idée se
    -- liraient comme deux idées.
    LABEL_SUB_INDENT = 18,

    -- Case où s'écrit la valeur d'une glissière, posée à sa droite.
    --
    -- Une **case** et non un nombre posé à même la page : la valeur s'y saisit au
    -- clavier (clic droit), et rien d'autre ne dit qu'un nombre est modifiable.
    -- C'est le cadre qui porte l'information, pas une infobulle qu'il faut aller
    -- chercher.
    --
    -- La largeur tient le plus long nombre que les glissières de l'addon
    -- affichent — quatre chiffres et un séparateur décimal — plus les retraits
    -- que le cadre du client prend sur ses deux bords. La hauteur est celle des
    -- contrôles étroits de l'addon : elle doit rester sous `ROW_H`, sans quoi la
    -- case déborde de sa ligne.
    SLIDER_VALUE_W  = 54,
    SLIDER_VALUE_H  = 20,
    SLIDER_VALUE_GAP = 10,  -- écart entre la glissière et sa case

    -- Place qu'une ligne réserve à droite pour son contrôle : la largeur d'une
    -- glissière, la case qui la suit, et de l'air au bord. C'est ce qui permet
    -- à `CONTROL_X` de céder quand la ligne est étroite — dans une colonne, par
    -- exemple — au lieu de pousser les glissières hors du cadre.
    --
    -- C'est une somme, pas un goût : `CONTROL_W` + `SLIDER_VALUE_GAP` +
    -- `SLIDER_VALUE_W`. Elle se recalcule à la main parce qu'une table Lua ne se
    -- lit pas pendant qu'on l'écrit — changer l'un des trois oblige à repasser
    -- ici.
    CONTROL_RESERVE = 224,

    -- En deçà, un libellé n'est plus lisible mais tronqué. Une ligne qui ne peut
    -- offrir ni cette largeur ni la réserve ci-dessus est une ligne qu'il ne faut
    -- pas mettre en colonne — voir `COLUMN_MIN_W`.
    LABEL_MIN_W     = 150,

    -- Découpe d'une page en deux colonnes.
    --
    -- `COLUMN_MIN_W` est la largeur au-dessous de laquelle on **renonce** et on
    -- reste sur une colonne. Ce n'est pas une préférence : c'est la somme de la
    -- réserve du contrôle et d'un libellé lisible. En dessous, la deuxième
    -- colonne ne gagnerait de la hauteur qu'en tronquant les intitulés, ce qui
    -- revient à rendre illisible ce qu'on voulait rendre plus visible.
    COLUMN_MIN_W    = 380,
    COLUMN_GAP      = 24,

    -- Pastille de couleur d'une ligne d'option. Nettement plus étroite qu'un
    -- dropdown : ce qu'elle montre est un aplat, et un aplat de la largeur d'un
    -- contrôle se lit comme un bandeau posé dans la page. Elle prend la hauteur
    -- d'une case à cocher, pour que les deux s'alignent dans la même colonne.
    -- Contrôle posé dans la barre de titre. Étroit : il ne porte qu'un nombre
    -- suivi d'un pour-cent, et il doit tenir dans la hauteur du bandeau — une
    -- barre de titre qui s'épaissit pour loger un contrôle n'est plus une barre
    -- de titre.
    TITLE_CONTROL_W = 84,
    TITLE_CONTROL_H = 20,

    -- Échelle du contenu de la fenêtre d'options, en pourcentage.
    --
    -- Le plancher n'est pas un goût : sous soixante-dix pour cent, les libellés
    -- des options passent sous la taille à laquelle une police d'interface reste
    -- nette, et on gagne des lignes en perdant la lecture. Le plafond est cent —
    -- l'échelle **compacte**, elle n'agrandit pas ; agrandir se fait en tirant la
    -- fenêtre, qui est déjà redimensionnable.
    CONFIG_SCALE_MIN  = 70,
    CONFIG_SCALE_MAX  = 100,
    CONFIG_SCALE_STEP = 5,

    SWATCH_W       = 44,
    SWATCH_H       = 18,
    SWATCH_EDGE    = 1,     -- épaisseur du liseré sombre qui la détache du fond

    -- Barres d'infos.
    --
    -- Ni l'une ni l'autre ne façonne quoi que ce soit : ce sont les valeurs que
    -- le client donne lui-même, et elles ne servent qu'à **partir de ce qu'il
    -- fait**. La hauteur de barre est en plus le repli quand on n'a pas pu
    -- relever la sienne — le client rend parfois une mesure *secrète* sur ces
    -- cadres-là, et une valeur secrète ne se retient pas.
    --
    -- La largeur, elle, est la valeur de départ des curseurs. La vraie largeur
    -- courante est relue à l'exécution par `C_NamePlate.GetNamePlateSize`, et
    -- c'est **elle** qui est rendue à l'extinction — ce nombre-ci ne sert qu'à ce
    -- que le curseur s'ouvre à peu près là où le jeu en est.
    --
    -- `PLATE_TEXT` est de la même farine : l'ordre de grandeur du corps que le
    -- client donne aux textes d'une plaque, valeur de départ du curseur. Le corps
    -- réel de chaque texte est relu avant d'être changé, et c'est **lui** qui est
    -- rendu — chacun retrouve donc le sien, pas celui-ci.
    PLATE_BAR_H    = 11,
    PLATE_W        = 172,
    PLATE_TEXT     = 12,
    PLATE_CAST_TEXT = 10,   -- le client écrit plus petit sur une barre de sorts

    -- Le plus haut cran du calibre de plaque du client. Une valeur à lui, comme
    -- les quatre ci-dessus, et rangée avec elles pour la même raison : c'est le
    -- nombre que la glissière annonce **et** celui que l'addon pose quand il
    -- prend la taille en main. Écrit deux fois, il divergerait une fois.
    PLATE_GAUGE_MAX = 5,


    -- Barre de sorts d'une plaque : mêmes repères, même rôle. Le client la fait
    -- plus fine que la barre de vie — c'est ce qui les distingue d'un coup d'œil,
    -- et la valeur de départ le conserve.
    PLATE_CAST_BAR_H = 8,

    -- Replis des mesures d'aura, quand le client ne publie pas les siennes, et
    -- épaisseur du liseré coloré d'une vignette d'exemple. Ce liseré-là est le
    -- seul de ces trois nombres qui façonne quelque chose : c'est lui qui dit si
    -- l'aura aide, nuit ou immobilise.
    PLATE_AURA      = 25,
    PLATE_AURA_GAP  = 2,
    PLATE_AURA_EDGE = 1,

    -- Corps du décompte posé sur une vignette d'aura, valeur de départ du
    -- curseur. Volontairement plus petit que le texte d'une plaque : il s'écrit
    -- **dans** une image de vingt-cinq pixels de côté, pas à côté d'elle, et
    -- au-delà il couvre l'icône qu'il annote au lieu de la compléter.
    PLATE_AURA_TIMER = 10,


    -- Plafond d'icônes de la rangée d'auras de l'addon. Huit : au-delà, la
    -- rangée déborde d'une plaque de largeur ordinaire, et une aura qu'on ne
    -- peut plus compter d'un coup d'œil n'informe plus.
    PLATE_AURA_MAX  = 8,

    -- Profondeur de la descente qui recense les textes d'une plaque.
    --
    -- Quatre niveaux, et il en faut quatre : le nom est posé sur la plaque, le
    -- sort en cours sur sa barre d'incantation — deux niveaux suffisaient pour
    -- eux — mais **les points de vie et leur pourcentage sont deux crans plus
    -- bas**, dans la barre que porte le conteneur de barres. S'arrêter à deux
    -- donnait un réglage qui grossissait le nom et laissait les chiffres, ce qui
    -- ne se lit pas comme une limite mais comme un oubli.
    --
    -- Le coût est celui d'une descente par plaque, faite une fois : quelques
    -- dizaines de nœuds, jamais depuis un chemin chaud.
    PLATE_TEXT_DEPTH = 4,

    SIDEBAR_CAT_H  = 30,    -- bandeau d'en-tête de catégorie
    SIDEBAR_ITEM_H = 26,    -- entrée de module
    SIDEBAR_INDENT = 18,
    SIDEBAR_SEARCH_H = 26,  -- zone de recherche, au-dessus de la liste

    DIVIDER_W       = 2,    -- séparateur vertical entre navigation et contenu

    GRIP            = 16,   -- poignée de redimensionnement, coin bas-droit
    GRIP_INSET      = 4,    -- retrait de la poignée par rapport au coin

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

    -- Corps du décompte. Aucun objet de police du client ne l'a : il est posé au
    -- milieu d'une icône de rôle et doit se lire d'un coup d'œil, sans qu'on
    -- cherche où il est. C'est la seule police que l'addon fabrique (voir plus
    -- bas), et ce nombre est la raison pour laquelle il la fabrique.
    COUNTDOWN_TEXT = 36,

    -- Le décompte se cale au centre de l'icône de rôle, et deux pixels plus bas.
    -- Un cadre de texte centré met le milieu de sa **boîte** sur l'ancre, or la
    -- boîte réserve la place des jambages que « 39 » n'a pas : les chiffres
    -- flottent donc au-dessus du centre optique tant qu'on ne les redescend pas.
    COUNTDOWN_Y    = -2,

    -- Texte posé sur une barre de statut du client (ressource personnelle).
    -- Le retrait écarte le texte du bord quand il s'ancre à gauche ou à droite ;
    -- l'étage le place au-dessus des textes du client, qu'il remplace.
    BAR_TEXT_PAD   = 4,
    BAR_TEXT_LEVEL = 5,

    -- Corps du texte, au choix du joueur. Le défaut est celui de la police que
    -- le client emploie sur ces barres ; les bornes suivent la hauteur d'une
    -- barre — en dessous de 8 rien ne se lit, au-delà de 24 le texte déborde.
    BAR_TEXT_SIZE     = 14,
    BAR_TEXT_SIZE_MIN = 8,
    BAR_TEXT_SIZE_MAX = 24,

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

    -- Rangée d'icônes de la colonne : enchantement, puis gemmes. Une **rangée**
    -- et non une pile, contrairement au reste de la colonne : ces icônes-là
    -- répondent à deux questions différentes sur la même pièce, et se lisent
    -- ensemble. Empilées, elles doubleraient la hauteur du bandeau pour rien.
    --
    -- Un peu plus haute qu'une ligne de texte : une icône de quatorze pixels
    -- reste reconnaissable, une de dix devient une tache colorée.
    SLOT_ICON       = 14,
    SLOT_ICON_GAP   = 2,

    -- Air entre la dernière ligne de texte et la rangée d'icônes. Petit : il ne
    -- sépare pas deux blocs, il rend à l'icône la marge que le texte porte déjà
    -- en lui et qu'elle n'a pas.
    SLOT_STRIP_GAP  = 3,

    -- Descente d'une colonne accrochée par le haut. Le bord haut d'une case est
    -- un trait, pas une ligne de texte : posée dessus, la première pastille a
    -- l'air de sortir de la case plutôt que de lui répondre.
    SLOT_TOP_DROP   = 6,

    -- De combien l'habillage d'un panneau déborde de lui. Le contenu est posé
    -- contre les bords ; sans cet écart, le contour touche le texte.
    PANEL_CHROME_BLEED = 3,

    -- Marge transparente que le template de contour laisse autour de son trait.
    -- On l'écarte d'autant, sans quoi le fond du panneau déborde du trait et
    -- forme une bande sombre de chaque côté. Se règle à l'œil : c'est la seule
    -- valeur à bouger si le trait ne tombe pas exactement sur le bord du fond.
    PANEL_BORDER_OUTSET = 6,



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
    -- marqueurs, rappel de file). Ce sont de petites fenêtres posées à même
    -- l'écran : elles partagent une géométrie, sans quoi trois pièces du même
    -- addon auraient trois marges différentes.
    -- `PANEL_PAD` est déjà pris par le retrait d'un panneau creusé de la fenêtre
    -- d'options : ces trois-là portent donc leur propre préfixe.
    TOOL_PAD       = 8,

    -- Suivi des résurrections de combat. La taille est un réglage : l'icône vit
    -- au milieu de l'écran d'un combat de raid, et ce qu'il faut voir d'un coup
    -- d'œil n'a pas la même taille pour tout le monde. Les bornes tiennent les
    -- extrêmes hors de portée — en dessous le compteur n'est plus lisible,
    -- au-dessus l'icône couvre le champ de bataille.
    TRACKER_ICON = 40,
    TRACKER_MIN  = 24,
    TRACKER_MAX  = 80,

    -- Suivi des buffs : une liste de noms, un par ligne. La largeur est un
    -- plancher — le panneau s'élargit à sa plus longue ligne, qui porte le buff
    -- et ce qui le remplace ; la hauteur d'une ligne est celle d'un libellé,
    -- sans marge — c'est une liste qu'on parcourt, pas un menu qu'on clique.
    BUFF_PANEL_W = 230,
    BUFF_ROW_H   = 16,

    -- Barre de marqueurs. La case est celle d'un bouton de barre d'action réduit :
    -- neuf cases doivent tenir sur une rangée sans que le panneau devienne une
    -- deuxième barre d'action.
    --
    -- Sa géométrie est **fixe** : c'est l'échelle du panneau que la poignée
    -- change, pas la taille de ses pièces. Retailler la rangée laissait les
    -- libellés à leur corps de police pendant que les vignettes grossissaient —
    -- un panneau agrandi qui ne grossit qu'à moitié. L'échelle prend tout d'un
    -- coup, texte compris, et c'est ce qu'on attend d'un « plus gros ».
    MARKER_CELL    = 26,
    MARKER_GAP     = 3,
    MARKER_ROW_GAP = 6,     -- écart entre la rangée de marqueurs et les boutons

    -- Bornes de l'échelle. Larges : la moitié tient dans un coin d'écran, le
    -- double se lit depuis le fond d'un fauteuil. Au-delà on quitte le panneau
    -- d'outils pour la décoration.
    MARKER_SCALE_MIN = 0.5,
    MARKER_SCALE_MAX = 2.5,

    -- Panneau de filtres de la recherche de groupe. Il s'ancre au bord droit de
    -- la fenêtre du client et vit à sa hauteur : sa largeur est la seule
    -- dimension qui soit à nous, celle qui loge une ligne d'option standard
    -- (libellé au minimum + contrôle) sans en faire une seconde fenêtre.
    GF_PANEL_W        = 300,
    -- Écart entre le bord de la fenêtre du client et le panneau : l'habillage
    -- du panneau déborde de lui (PANEL_CHROME_BLEED + PANEL_BORDER_OUTSET), il
    -- faut au moins cette somme pour que les deux contours ne se chevauchent pas.
    GF_PANEL_OFFSET_X = 12,
    -- Plafond de lignes construites pour la liste des instances : les frames ne
    -- se détruisent pas (règle 7), la liste réutilise ses lignes et n'en bâtit
    -- jamais plus que ça. Une saison compte huit donjons ; dix laisse de l'air.
    GF_LIST_MAX       = 10,
    -- La colonne de droite, où vit cette liste : dix lignes empilées sous les
    -- rôles faisaient descendre le panneau sous la fenêtre du client, alors que
    -- la place à sa droite ne coûte rien. Plus étroite que la colonne des
    -- réglages — un nom d'instance et sa case, sans bornes à loger.
    GF_LIST_COL_W     = 220,
    -- Bouton qui range ou ressort le panneau, posé sur la recherche du client
    -- à côté de son bouton d'actualisation. Même côté que le bouton de copie
    -- du chat, pour la même raison : il vit sur une fenêtre qui ne nous
    -- appartient pas, et doit s'y faire petit.
    GF_STOW_BUTTON    = 16,
    GF_STOW_GAP       = 4,

    -- Rangée de ressource de classe : points de combo, puissance sacrée, chi,
    -- fragments d'âme, runes, cumuls d'Arme-tempête.
    --
    -- **Des cases, pas une jauge.** Ce qu'on suit ici se compte sur les doigts et
    -- se dépense par unités entières : une barre continue oblige à estimer une
    -- longueur pour retrouver un nombre qu'on avait déjà. Cinq cases se comptent
    -- sans les compter.
    --
    -- Les cases sont plus **larges** que hautes, comme le sont les segments d'une
    -- barre de ressource du jeu : à hauteur égale, des carrés se lisent comme une
    -- rangée d'icônes, et une rangée d'icônes se cherche des vignettes.
    RESOURCE_CELL_W   = 34,
    RESOURCE_CELL_H   = 22,
    RESOURCE_GAP      = 3,

    -- Épaisseur du liseré sombre qui borde chaque case. C'est lui qui sépare deux
    -- cases pleines voisines : sans lui, la rangée redevient la barre continue
    -- qu'on ne voulait pas.
    RESOURCE_EDGE     = 1,

    -- Rayon des coins de `T.TEXTURE.ROUNDED_RECT`, **cuit dans le fichier** par
    -- `dev/scripts/make-rounded-tga.ps1` : les deux valeurs bougent ensemble ou
    -- pas du tout. C'est aussi la marge de découpe en neuf à passer à
    -- `SetTextureSliceMargins` pour que le rayon reste celui-là quelle que soit
    -- la taille dessinée.
    ROUNDED_RECT_RADIUS = 5,

    -- Bornes des curseurs de taille. Le plancher est la case encore distinguable
    -- de sa voisine, le plafond celle au-delà de laquelle la rangée devient une
    -- deuxième barre d'action.
    RESOURCE_CELL_MIN = 8,
    RESOURCE_CELL_MAX = 80,
    RESOURCE_GAP_MAX  = 20,

    -- Plafond de cases **construites**. Une frame ne se détruit pas (règle 7) :
    -- on bâtit une fois ce plafond, et chaque ressource n'en montre que ce qu'il
    -- lui faut. Douze laisse de la marge sur la plus fournie qu'on connaisse — les
    -- dix cumuls d'Arme-tempête — sans qu'une extension à venir oblige à y revenir.
    RESOURCE_MAX_CELLS = 12,

    -- Nombre de cases de l'aperçu quand le personnage n'a aucune ressource à
    -- cases. Cinq : c'est ce qu'ont les points de combo et les fragments d'âme,
    -- donc la rangée la plus courante.
    RESOURCE_PREVIEW_CELLS = 5,

    -- Corps du nombre posé sur la rangée, en proportion de la hauteur d'une case.
    -- Il ne se règle pas séparément : un nombre au corps fixe se perd dans une
    -- rangée agrandie et déborde d'une rangée réduite. Les deux bornes sont des
    -- garde-fous, pas des mesures — elles ne mordent qu'aux extrêmes des curseurs.
    RESOURCE_TEXT_RATIO = 0.7,
    RESOURCE_TEXT_MIN   = 8,
    RESOURCE_TEXT_MAX   = 32,

    -- Épaisseur du **cœur** de la lueur de bord, en proportion de la hauteur d'une
    -- case. Une proportion et non un nombre fixe : deux pixels se voient sur une
    -- case de vingt et disparaissent sur une case de quatre-vingts.
    --
    -- Le plancher vaut deux : à un pixel, le trait clignote au gré de l'échelle
    -- de l'interface — c'est une ligne, pas une image, elle ne se sous-échantillonne
    -- pas gracieusement.
    RESOURCE_GLOW_TH_RATIO = 0.1,
    RESOURCE_GLOW_TH_MIN   = 2,
    RESOURCE_GLOW_TH_MAX   = 5,

    -- Épaisseur du **halo**, en multiples de celle du cœur, de chaque côté.
    --
    -- C'est lui qui fait la différence entre un trait et une lumière. Un cœur
    -- seul, si vif soit-il, garde des bords nets : l'œil y lit un liseré. Ce qui
    -- se lit comme une lueur est le **fondu** autour.
    --
    -- Deux fois le cœur, et c'est mesuré sur la référence : un noyau de quatre
    -- pixels pour un flou de six, plus un pixel d'étalement, soit un halo d'un peu
    -- moins du double de chaque côté. On était à trois fois et demie — assez large
    -- pour que le fondu se dilue et cesse d'être lu comme appartenant au trait.
    RESOURCE_GLOW_BLOOM = 2.0,

    -- La comète qui court sur le bord : sa **tête**, le dernier point de sa
    -- **traînée**, et l'écart entre deux points de celle-ci. Les deux premiers en
    -- multiples de l'épaisseur du cœur du bord, le troisième en multiples de la
    -- tête.
    --
    -- Se mesurer sur le cœur et non sur la rangée est ce qui garde l'effet
    -- discret : une tête à peine plus grosse que le trait qu'elle parcourt se lit
    -- comme une lumière qui court **dans** la bordure. Proportionnelle à la
    -- hauteur de la rangée, elle en faisait le double et devenait une pastille qui
    -- glisse à côté — le mouvement primait sur ce qu'il éclaire, et c'est
    -- l'inverse qu'on veut.
    --
    -- Une tête d'une fois et demie la queue : assez pour qu'on voie où va la
    -- comète, pas assez pour qu'elle se lise comme deux objets.
    --
    -- **L'écart décide de tout.** Il vaut un cinquième d'un point, c'est-à-dire
    -- que chaque point recouvre les quatre suivants : la traînée cesse d'être une
    -- suite de boules pour devenir une seule forme continue, arrondie à ses deux
    -- bouts et plus haute d'un côté que de l'autre. À un demi-point, on compte les
    -- boules ; à un cinquième, on ne les voit plus.
    RESOURCE_GLOW_HEAD = 4.5,
    RESOURCE_GLOW_TAIL = 3.0,
    RESOURCE_GLOW_GAP  = 0.2,

    -- Point posé à chacun des quatre coins du bord fixe, en multiples de
    -- l'épaisseur du cœur.
    --
    -- Quatre bandes droites se coupent à angle droit, et un angle droit se lit
    -- comme un carré quoi qu'on fasse du reste. Une petite boule de lumière posée
    -- sur chaque coin en arrondit la lecture : ce n'est pas le coin qu'on change,
    -- c'est ce que l'œil y voit.
    RESOURCE_GLOW_CORNER = 4.0,


    -- De combien la rangée descend sous le centre de l'écran à la première
    -- ouverture. Ce n'est pas une position définitive — elle se déplace à la
    -- souris — mais le centre exact de l'écran est le pire endroit possible pour
    -- une pièce qu'on découvre : elle y couvre le personnage. Cent quatre-vingts
    -- unités la posent entre lui et les barres d'action, là où le jeu met déjà
    -- les siennes.
    RESOURCE_DROP = 180,

    -- Repères des paliers d'une clé : une **fine pilule** posée en travers de la
    -- barre de chrono du client, et **entièrement contenue dedans**.
    --
    -- Les trois proportions se prennent sur la hauteur de la barre, relevée à
    -- l'exécution : le client a retouché la sienne d'une extension à l'autre, et
    -- une proportion survit là où un pixel ne survit pas.
    --
    -- **Rien ne dépasse, ni en haut ni en bas.** Un repère qui sort de la barre se
    -- lit comme une marque posée *devant* elle plutôt que dedans.
    --
    -- La hauteur ne vaut pas la barre entière mais un peu moins : la marge
    -- transparente de l'atlas de remplissage n'est pas symétrique, et le bleu
    -- visible occupe environ trois quarts du cadre, **cadrés en haut**. C'est cette
    -- part-là qu'on remplit, et c'est pourquoi le repère s'ancre par le haut.
    --
    -- Le plancher de largeur est le seul nombre absolu : sous deux pixels, un
    -- trait vertical papillote au gré de l'échelle de l'interface.
    -- Repères posés sur une barre du client : leur épaisseur, et combien on en
    -- offre. Deux pixels, comme le plancher des paliers de clé — sous cette
    -- épaisseur un trait vertical papillote au gré de l'échelle de l'interface.
    --
    -- Trois, parce que c'est le nombre de seuils qu'on retient réellement sur
    -- une barre : celui où l'on commence à s'inquiéter, celui où l'on agit,
    -- celui où il est trop tard. Un quatrième ne se distinguerait plus d'une
    -- graduation, et une barre graduée ne se lit plus d'un coup d'œil.
    BAR_MARKER_W   = 2,
    BAR_MARKER_MAX = 3,
    -- L'étage des repères : au-dessus de l'habillage que le client pose sur
    -- ses propres enfants de barre — resté au niveau de la barre, le trait
    -- passerait dessous — et juste sous nos textes (`BAR_TEXT_LEVEL`), qui
    -- doivent rester lisibles en croisant un trait.
    BAR_MARKER_LEVEL = 4,

    KEY_TIER_H_RATIO = 0.75,
    KEY_TIER_W_RATIO = 0.16,
    KEY_TIER_W_MIN   = 2,

    -- Écart entre deux nombres de la rangée du chrono : entre le temps restant et
    -- le premier palier, puis entre les deux paliers. Assez pour que deux nombres ne
    -- se touchent pas, assez peu pour que les trois se lisent comme une rangée et
    -- non comme trois colonnes.
    KEY_NEXT_PAD   = 6,

    -- Écart entre le temps perdu par les morts et ce contre quoi il se cale : le
    -- premier affixe à sa droite, ou le niveau de clé à sa gauche à défaut. Plus
    -- serré que celui des paliers, la rangée du niveau étant la plus étroite des
    -- deux — et un nombre calé contre une vignette n'a pas besoin du même air qu'un
    -- nombre calé contre un autre nombre.
    KEY_DEATHS_PAD = 3,

    -- Sous-calque des repères, dans le calque `OVERLAY` du bloc du client.
    --
    -- Au-dessus de ce que le client y dessine, et c'est tout ce que ce nombre
    -- veut dire : son habillage passe par-dessus sa propre barre pour lui faire
    -- un cadre, donc un repère au sous-calque zéro passerait dessous. La valeur
    -- n'a pas à être serrée — elle doit seulement dépasser celles du client, et
    -- rien ne se dessine entre les deux.
    --
    -- **C'est aussi le plafond que le moteur accepte** : un sous-calque vit entre
    -- moins huit et sept, et en demander huit ne dégrade pas — la création de la
    -- texture lève. Un repère en plusieurs épaisseurs doit donc s'empiler **vers
    -- le bas** depuis ce nombre, jamais vers le haut.
    KEY_TIER_LEVEL = 7,

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
    BUFF_SCAN     = 0.2,    -- relecture des buffs du joueur, une fois la rafale
                            -- d'`UNIT_AURA` retombée
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
    TRACKER       = 0.2,    -- décomptes posés sur une icône de suivi

    -- Cadence du chrono d'aperçu des paliers de clé. Une seconde, parce que
    -- c'est la vitesse à laquelle un chrono court : l'aperçu doit se lire comme
    -- le vrai, et le vrai n'affiche pas de dixièmes. En donjon, rien ne tourne
    -- de notre côté — c'est le client qui repose son chrono, et on ne fait que
    -- suivre.
    KEY_PREVIEW   = 1.0,

    -- Cadence de la poignée d'échelle, pendant qu'elle est tenue. Assez rapide
    -- pour que le panneau colle au curseur, assez lente pour ne pas repeindre à
    -- chaque image ce que l'œil ne suit pas (règle 7).
    SCALE_DRAG    = 0.03,

    -- Durée de la mise en évidence d'une ligne atteinte par la recherche. Assez
    -- longue pour être trouvée des yeux après le saut de page, assez courte pour
    -- que la page redevienne ordinaire sans qu'on ait rien à faire.
    ROW_FLASH     = 1.5,

    -- Barre de sorts d'exemple : la cadence de son remplissage, et le temps
    -- qu'elle met à se remplir.
    --
    -- Vingt images par seconde suffisent à ce qu'une barre paraisse couler ; on
    -- n'en paie pas soixante pour un mouvement que l'œil ne suit pas de toute
    -- façon (règle 7). Et deux secondes, parce que c'est la durée d'une
    -- incantation ordinaire — un exemple qui se remplit en un clin d'œil ne
    -- ressemble à rien de ce qu'on verra en jeu.
    --
    -- Elle ne tourne que le temps qu'on règle la barre, et pour personne
    -- d'autre : la case s'éteint, la minuterie avec.
    PLATE_CAST       = 0.05,
    PLATE_CAST_CYCLE = 2.0,

    -- Durée de vie d'une aura d'exemple, et décalage entre deux d'une même
    -- rangée. Quinze secondes, parce que c'est l'ordre de grandeur d'une entrave
    -- ou d'un affaiblissement — un décompte à trois chiffres ne dirait rien de
    -- la place que prend un vrai.
    --
    -- Le décalage sert à ce que les vignettes d'une rangée n'expirent pas toutes
    -- ensemble : un décompte identique sur trois icônes ressemble à une image
    -- figée, trois nombres différents à une rangée vivante.
    --
    -- L'aperçu **repart** à chaque cycle. Sans cela les exemples s'éteignent au
    -- bout de leur durée et ne reviennent jamais : on règle alors des icônes
    -- sans horloge, ce qui est précisément ce que l'aperçu doit montrer.
    PLATE_AURA_CYCLE = 15,
    PLATE_AURA_STEP  = 3,

    -- Cadence de l'aperçu de la rangée de ressource : une case de plus toutes
    -- les six dixièmes, puis on repart de zéro. Assez lent pour qu'on voie
    -- chaque palier se franchir — c'est précisément ce que l'aperçu doit montrer,
    -- la teinte qui change à partir de X cases —, assez rapide pour qu'on ne
    -- l'attende pas en réglant la position.
    RESOURCE_PREVIEW = 0.6,

    -- Durée d'un tour complet du contour par la lueur de bord.
    --
    -- Lent : ce qui court ici parcourt le **périmètre** d'une rangée, quelques
    -- centaines de pixels. À la seconde, les segments filent et se lisent comme
    -- des projectiles ; à quatre, ils tournent.
    RESOURCE_GLOW_LAP  = 4.0,

    -- Cadence de la lueur de bord (règle 7). Quarante pas par seconde suffisent à
    -- ce qu'un trait paraisse glisser ; on n'en paie pas soixante pour un
    -- mouvement que l'œil ne suit pas de toute façon. Elle ne tourne que pendant
    -- que la lueur est à l'écran.
    RESOURCE_GLOW_STEP = 0.025,


    HOVER         = 0.1,   -- sondage de la fenêtre survolée, pendant qu'un
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

    -- Décompte posé sur une fenêtre du client. Ce qu'on cherche ici n'est pas un
    -- objet de police à utiliser tel quel mais le **fichier de police de
    -- l'interface** : celui-ci sert de source à la police fabriquée plus bas.
    -- D'où des `GameFont*` et non des `NumberFont*` — voir le commentaire de
    -- `T.FONT.COUNTDOWN`.
    COUNTDOWN    = { "GameFontNormalHuge", "GameFontNormalLarge", "GameFontNormal" },

    -- Nombres posés sur l'icône d'un objet équipé (niveau d'objet, rang
    -- d'amélioration). Une police à contour, pour la même raison que le
    -- décompte : le chiffre se lit par-dessus une illustration.
    SLOT_BADGE   = { "NumberFont_Outline_Med", "NumberFontNormalSmall", "GameFontNormalSmall" },

    -- Texte du bandeau posé à côté d'un emplacement. La plus petite police
    -- lisible du client : seize bandeaux tiennent dans la hauteur de la fiche.
    SLOT_INFO    = { "GameFontHighlightSmall" },

    -- Niveau d'objet du personnage, posé au-dessus des armes. Plus grand que les
    -- seize autres nombres de la fiche, et c'est ce qui le distingue : ceux-là se
    -- comparent entre eux, celui-ci se lit seul.
    --
    -- D'un cran seulement. La taille au-dessus le faisait passer pour un titre de
    -- la fiche plutôt que pour une de ses valeurs, alors qu'il n'a de sens que
    -- rapproché des seize autres.
    SLOT_HEADLINE = { "GameFontNormal" },

    -- Texte de la fenêtre de copie. La police du chat d'abord : on y relit ce
    -- qu'on vient de lire dans le chat, à la même largeur de caractère.
    COPY         = { "ChatFontNormal", "GameFontHighlight" },

    -- Les deux paliers, posés en rangée à droite du temps restant.
    --
    -- Un cran sous le chrono du client, qui est en `Huge` : les trois nombres se
    -- lisent comme une rangée, et c'est leur **corps** qui dit lequel est le
    -- principal. À corps égal, les trois se disputeraient l'œil ; deux crans plus
    -- bas, les paliers deviendraient une note de bas de page.
    KEY_NEXT     = { "GameFontHighlightLarge", "GameFontHighlightMedium",
                     "GameFontHighlight" },

    -- Temps perdu par les morts, posé sur l'en-tête du suivi. Plus petit que les
    -- paliers : il ne se lit pas en courant, il se consulte. Et l'en-tête est une
    -- bande basse, que le corps des paliers déborderait.
    KEY_DEATHS   = { "GameFontHighlightSmall", "GameFontHighlight" },

    -- Les deux nombres posés sur une icône de suivi : le compteur dans son coin,
    -- le temps restant en son milieu. Grasse et à contour, comme tout ce que
    -- l'addon pose **sur** une image — l'icône d'un sort est claire par endroits, et
    -- un chiffre sans contour y disparaît. C'est leur couleur et leur place qui
    -- les distinguent l'un de l'autre, pas leur corps.
    TRACKER      = { "NumberFont_Outline_Large", "NumberFontNormalLarge",
                     "GameFontNormalLarge" },

    -- Polices des barres d'infos, celles du client. Elles ne servent qu'aux
    -- éléments d'exemple du mode test : ce qui imite une plaque doit s'écrire
    -- comme une plaque, sans quoi l'exemple ment sur la place que le vrai texte
    -- occupera.
    PLATE_NAME   = { "SystemFont_NamePlate", "GameFontNormalSmall" },
    PLATE_CAST   = { "SystemFont_NamePlateCastBar", "SystemFont_NamePlate",
                     "GameFontNormalSmall" },

    -- Compteur de cumuls d'une aura de la rangée de l'addon. À contour, comme
    -- tout nombre posé sur une image.
    PLATE_STACK  = { "NumberFontNormalSmall", "GameFontHighlightSmall" },

    -- Nombre posé sur la rangée de ressource. À contour, pour la même raison que
    -- partout ailleurs : il s'écrit **par-dessus** des cases dont la teinte est
    -- au choix du joueur, et un chiffre sans contour disparaît dès qu'elle est
    -- claire. Son corps, lui, suit la hauteur des cases (voir
    -- `T.ResourceTextSize`) — d'où une police de départ moyenne plutôt que petite.
    RESOURCE     = { "NumberFont_Outline_Med", "NumberFontNormalSmall",
                     "GameFontNormalSmall" },

    -- Texte posé sur une barre de statut du client — la ressource personnelle.
    -- `TextStatusBarText` est la police que le client emploie lui-même sur ces
    -- barres-là : notre texte remplace le sien, il doit s'écrire pareil.
    BAR_TEXT     = { "TextStatusBarText", "GameFontHighlightSmall" },

    SECTION      = { "GameFontNormalMedium", "GameFontNormal" },
    LABEL        = { "GameFontHighlightMedium", "GameFontHighlight" },
    LABEL_SMALL  = { "GameFontHighlight", "GameFontHighlightSmall" },
    HINT         = { "GameFontDisableSmall" },

    -- Note posée en tête d'une moitié de page. D'un cran au-dessus de `HINT` :
    -- une note qui dit d'où viennent les réglages qu'elle ouvre se lit **avant**
    -- eux, et le corps d'infobulle de `HINT` la faisait passer après.
    NOTICE       = { "GameFontDisable", "GameFontDisableSmall" },
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

-- -------------------------------------------------------------------------
--  La seule police que l'addon fabrique
-- -------------------------------------------------------------------------
-- Le décompte des fenêtres de file est le seul nombre de l'addon qu'aucun objet
-- du client ne sait écrire.
--
-- `NumberFont_*` — ce qu'il utilisait — est la police des **dégâts** : étroite,
-- immédiatement reconnaissable, et étrangère à tout le reste de l'interface. Un
-- nombre écrit avec elle au milieu d'une fenêtre de Blizzard se lit comme une
-- pièce rapportée. Les `GameFont*` sont la bonne famille, celle de tout le texte
-- que le joueur lit, mais aucune n'existe au corps qu'il faut.
--
-- On reprend donc le **fichier** de la police d'interface — pris sur un objet du
-- client, ce qui est le contraire d'écrire un chemin de `.ttf`, et ce qui suit
-- automatiquement la langue du client — et on lui donne notre corps et son
-- contour. Le contour tient lieu de gras : c'est ainsi que le client épaissit
-- ses propres nombres posés sur une image, et celui-ci se pose sur une icône.
--
-- Nom global, exception « noms de frames » de la règle 3 : `CreateFont` publie
-- l'objet sous son nom, et `CreateFontString` ne sait le retrouver que par là.
--
-- Test de capacité de bout en bout : si le client ne sait pas fabriquer de
-- police, ou si le fichier ne se pose pas, `T.FONT.COUNTDOWN` reste l'objet du
-- client résolu ci-dessus. Un décompte plus petit, jamais pas de décompte.
do
    local source = _G[T.FONT.COUNTDOWN]
    local file   = source and source.GetFont and source:GetFont()

    if file and CreateFont then
        local font = CreateFont("BshamelUICountdownFont")
        if font then
            font:SetFont(file, T.SIZE.COUNTDOWN_TEXT, "OUTLINE")

            -- On **relit** au lieu de croire la valeur de retour : elle n'est
            -- booléenne que sur les clients récents, et un objet sans police
            -- passé à `CreateFontString` lèverait.
            if font:GetFont() then T.FONT.COUNTDOWN = "BshamelUICountdownFont" end
        end
    end
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

    -- Le trait d'un repère posé sur une barre. Un blanc **à nous**, écrit ici,
    -- et non la couleur de police blanche du client : ce n'est pas du texte, et
    -- emprunter une teinte à une police fait dépendre un trait de ce que le
    -- client décide pour ses libellés — ce qu'on ne voit qu'au moment où il en
    -- décide autrement.
    BAR_MARKER = CreateColor(1, 1, 1),

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

    -- Or d'**habillage** : celui des cadres ouvragés que le client dessine, pas le
    -- doré de ses textes.
    --
    -- La seconde couleur inventée de l'addon après l'accent, et pour la même
    -- raison : celle-là n'est publiée nulle part. `NORMAL_FONT_COLOR` est le doré
    -- des *libellés* du client — un jaune franc, presque pur, qui a été choisi pour
    -- ressortir sur un fond noir. Posé sur un cadre de laiton, il ne s'accorde pas
    -- avec lui, il le contredit.
    --
    -- La valeur est **mesurée** : c'est le ton le plus clair des repères de palier
    -- d'Angry Keystones, relevé en décodant sa texture (230, 206, 99). Trois nombres
    -- relevés ne sont ni du code ni une texture empruntée — voir CLAUDE.md règle 8 :
    -- on lit un autre addon pour savoir ce qui marche, et on l'écrit soi-même. Sa
    -- texture, elle, n'est pas embarquée ; le dégradé est refait avec `T.FadeTexture`.
    FRAME_GOLD = CreateColor(0.90, 0.81, 0.39),

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

-- Code couleur des deux paliers d'une clé mythique+.
--
-- Ce n'est pas une donnée de jeu : le client ne teinte rien par palier et ne les
-- mentionne nulle part. C'est donc un vocabulaire, et un vocabulaire se décide ici.
-- Ni l'une ni l'autre n'est nouvelle — ce sont deux couleurs déjà nommées, dont on
-- dit ici ce qu'elles veulent dire dans ce contexte-là.
--
--   +3  → l'or de l'habillage. C'est le palier qu'on regarde, et l'or est ce que
--         le cadre a de plus clair.
--   +2  → le gris d'un contrôle éteint. Le +2 ne se regarde que quand le +3 est
--         perdu, et il doit se taire jusque-là.
--
-- **Il n'y a pas de troisième entrée.** Le temps restant garde le blanc que le
-- client lui donne : c'est le nombre principal, le blanc est ce qu'il y a de plus
-- lisible, et le teinter comme un palier le rangerait au même niveau que les deux
-- autres alors qu'il les commande.
T.COLOR.TIER_TWO   = T.COLOR.DISABLED
T.COLOR.TIER_THREE = T.COLOR.FRAME_GOLD

-- Teintes **de départ** de la rangée de ressource de classe. Comme celles des
-- barres de nom, elles se changent ensuite dans la page du module : ce qui est
-- décidé ici, c'est ce que le joueur trouve en arrivant.
--
--   remplissage → l'accent de l'addon, et seulement pour qui choisit une teinte
--                 à lui. Le mode par défaut prend celle **du jeu** (voir
--                 `T.PowerColor`), qui est déjà celle à laquelle un joueur
--                 reconnaît des points de combo d'une puissance sacrée ;
--   palier      → l'or de l'habillage, le même que le palier d'une clé mythique.
--                 Il y veut dire « c'est celui-ci qu'on regarde », et il veut
--                 dire exactement la même chose ici : à partir de X cases, la
--                 rangée dit qu'il y a de quoi dépenser.
--
-- Les deux **diffèrent** volontairement : un palier de la couleur du
-- remplissage se lirait comme un réglage qui ne marche pas.
T.COLOR.RESOURCE_FILL  = T.COLOR.ACCENT
T.COLOR.RESOURCE_ALERT = T.COLOR.FRAME_GOLD

-- Teintes de départ des deux paliers suivants. Trois paliers se lisent comme une
-- **montée**, et une montée a un vocabulaire déjà écrit dans l'addon : l'or de ce
-- qui prime, puis l'orange de « ça part de travers », puis le rouge. Ce sont les
-- mêmes couleurs qu'ailleurs, et elles y veulent dire la même chose.
--
-- Elles se changent une par une dans la page : ce qui est décidé ici, c'est ce
-- que le joueur trouve en arrivant.
T.COLOR.RESOURCE_ALERT2 = T.COLOR.ORANGE
T.COLOR.RESOURCE_ALERT3 = T.COLOR.RED

-- Lueur de bord de la rangée : **deux teintes et non une**. Un cœur, et le halo
-- un cran plus chaud qui l'entoure.
--
-- Ce sont deux ambres **relevés sur une référence** — la lueur dorée qu'un
-- tableau de bord de guilde pose sur un palier de grand coffre atteint, dont le
-- rendu était celui qu'on cherchait. Un cœur `#FCD34D` et un halo `#FBBF24` à
-- neuf dixièmes d'opacité.
--
-- On était parti d'un cœur presque blanc, en se disant qu'une lumière forte
-- sature l'œil avant de lui montrer sa couleur. C'est vrai d'une source
-- éblouissante ; ce n'est pas vrai d'un liseré de quelques pixels, qui n'a pas
-- de quoi éblouir et se contente alors de paraître **délavé**. À cette taille, la
-- chaleur passe par la saturation, pas par l'intensité.
--
-- L'or plutôt que l'accent de l'addon, et plutôt que la teinte du palier : c'est
-- la couleur que le jeu donne à tout ce qui s'allume — un procédé, un objet prêt,
-- un sort suggéré. Elle veut déjà dire « maintenant », et on ne la réapprend pas.
T.COLOR.GLOW_CORE = CreateColor(0.988, 0.827, 0.302)
T.COLOR.GLOW_HALO = CreateColor(0.984, 0.749, 0.141)

-- -------------------------------------------------------------------------
--  Barres de nom
-- -------------------------------------------------------------------------
-- Les teintes **de départ** des barres de nom. Elles ne sont pas figées : le
-- joueur les change une par une dans la page du module. Ce qui est décidé ici,
-- c'est le vocabulaire qu'il trouve en arrivant.
--
-- Deux familles, et elles ne se mélangent pas.
--
--   · **Ce qu'est la créature** — boss, caster, mêlée, rare. C'est une famille
--     de *couleurs*, sans ordre entre elles : aucune ne vaut mieux qu'une
--     autre, elles se distinguent, point. Chacune est choisie pour ne
--     ressembler à aucune des trois autres à la vitesse où on les lit ;
--   · **Ce que fait la menace** — conforme, bascule, anormale. C'est un feu
--     tricolore, avec un ordre, et c'est le même que celui des décomptes de
--     l'addon (voir `T.CountdownColor`). Un joueur qui a compris l'un a compris
--     l'autre : l'orange y veut dire « ça part de travers », jamais « attention
--     en général ».
--
-- L'or est réservé au boss, et c'est le seul emprunt d'une famille à l'autre :
-- c'est déjà la couleur de ce qui prime dans le reste de l'addon.
-- Ces teintes-là ne sont pas un choix de thème : ce sont **celles du joueur**,
-- données en hexadécimal et converties ici. On les note telles quelles pour
-- pouvoir les comparer un jour à ce qu'il a demandé.
--
--   boss/miniboss  A200FF   caster  00BFFF
--   mêlée/trivial  C2996B   rare(-élite)  7DFFBD
--
-- Le rare simple n'a pas reçu de teinte à lui : il prend celle du rare-élite —
-- un rare est un rare, et les deux lignes restent réglables séparément. Le
-- miniboss est dans le même cas vis-à-vis du boss : même teinte de départ, deux
-- réglages distincts.
--
-- La menace n'a pas de couleur d'état conforme : quand l'aggro est là où elle
-- doit être, ce sont les couleurs par nature qui parlent. Ses deux alertes —
-- bascule en cours et aggro changée de mains — partent du même rouge, chacune
-- réglable ensuite.
T.COLOR.PLATE = {
    BOSS       = CreateColor(0.635, 0.000, 1.000),
    MINIBOSS   = CreateColor(0.635, 0.000, 1.000),
    CASTER     = CreateColor(0.000, 0.749, 1.000),
    MELEE      = CreateColor(0.761, 0.600, 0.420),
    RARE       = CreateColor(0.490, 1.000, 0.741),
    RARE_ELITE = CreateColor(0.490, 1.000, 0.741),

    THREAT_BAD = CreateColor(1.000, 0.000, 0.000),
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
    ROW_FLASH      = 0.45,  -- mise en évidence d'une ligne atteinte par la
                            -- recherche : plus forte que la sélection, elle doit
                            -- se voir au milieu d'une page entière
    ITEM_OFF       = 0.55,  -- entrée d'un module éteint. « Éteint » doit rester
                            -- lisible : c'est la ligne sur laquelle on clique
                            -- pour rallumer le module

    DIVIDER        = 0.30,  -- séparateur vertical, au plus fort de son dégradé
    THUMB          = 0.70,  -- curseur d'ascenseur

    CONTROL_OFF    = 0.50,  -- contrôle grisé
    GRIP           = 0.70,  -- poignée de redimensionnement au repos
    GRIP_HOVER     = 1.00,

    -- Pièces posées sur les cadres du client — bouton de copie du chat,
    -- rangement du panneau de filtres —, au repos. Plus discrètes que nos
    -- propres poignées : elles vivent par-dessus ce que le joueur lit, et
    -- cela prime sur elles. Elles reviennent à pleine opacité au survol,
    -- qui est le seul moment où elles ont quelque chose à dire.
    CHAT_TOOL       = 0.35,
    CHAT_TOOL_HOVER = 1.00,

    -- Repère de palier, **au plus fort de son dégradé** : le centre du repère, celui
    -- qui tombe pile sur le palier. Pleine, parce que ce qui l'estompe est le
    -- dégradé lui-même, qui s'éteint vers les deux bords — la baisser ici pâlirait le
    -- repère entier au lieu d'adoucir ses bords.
    KEY_TIER        = 1.00,

    -- Case **vide** de la rangée de ressource : la même teinte que les pleines,
    -- presque éteinte. Une case vide teintée d'un gris à elle ferait deux
    -- vocabulaires dans une même rangée — « plein » et « autre chose » — là où on
    -- veut lire une seule échelle, dont une partie est allumée. C'est aussi ce
    -- que fait le jeu sur ses propres segments de ressource.
    --
    -- Assez basse pour que le compte se lise d'un coup d'œil, assez haute pour
    -- que la rangée entière reste visible quand elle est vide : c'est elle qui
    -- dit **où** la rangée se trouve quand il n'y a rien dedans.
    RESOURCE_EMPTY  = 0.22,

    -- Liseré des cases. Pleine : c'est le noir qui les sépare, et un noir dilué
    -- laisse deux cases pleines se toucher.
    RESOURCE_EDGE   = 1.00,

    -- Lueur de bord, en deux temps.
    --
    -- Le **fond** couvre tout le contour et ne bouge jamais : c'est lui qui fait
    -- que la rangée entière a l'air allumée plutôt que traversée par des traits.
    -- Il est discret par construction — permanent, il serait fatigant à pleine
    -- intensité, et posé en mode additif il blanchirait les cases au lieu de les
    -- border.
    --
    -- Les **comètes** qui le parcourent : c'est leur écart avec le fond qui se lit
    -- comme un mouvement, pas leur intensité absolue.
    --
    -- Ces deux opacités-là ne sont **pas** celles qu'on voit. Une comète est faite
    -- de points qui se recouvrent largement, et le mode additif les additionne :
    -- quatre points empilés à 0,4 donnent un blanc franc. Ce sont donc des
    -- opacités **par point**, réglées pour que leur somme tombe juste — les monter
    -- ne rend pas la comète plus lumineuse, elle la brûle.
    GLOW_CORE       = 0.55,
    GLOW_HALO       = 0.30,
    GLOW_SPARK      = 0.40,
    GLOW_TRAIL      = 0.16,
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

--- Fond d'un panneau qui doit se lire comme la fenêtre d'options : la pierre du
--- client **multipliée** par la couleur des fenêtres.
---
--- C'est toute la différence entre le noir profond de la fenêtre d'options et le
--- gris qu'un aplat de la même valeur produit. Un aplat *pose* la couleur ;
--- posée telle quelle, `WINDOW` est un gris bleuté à mi-chemin. Sur un cadre du
--- client, la même couleur **multiplie** une pierre déjà sombre, et le produit
--- est presque noir. Un panneau qu'on assemble soi-même n'a pas cette pierre :
--- on la lui donne.
---@param texture table
function T.WindowStone(texture)
    texture:SetTexture(T.TEXTURE.SIDEBAR_BAND)
    -- Tuilée plutôt qu'étirée : une pierre écrasée dans un panneau de soixante
    -- pixels de haut donne une bouillie (même raison que les en-têtes de
    -- catégorie).
    texture:SetHorizTile(true)
    texture:SetVertTile(true)
    texture:SetVertexColor(T.COLOR.WINDOW:GetRGB())
    texture:SetAlpha(T.ALPHA.WINDOW_BG)
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

--- La teinte d'un **parchemin** : à peine plus de la moitié de sa clarté.
---
--- Elle ne se compare pas à la précédente, parce qu'elle ne fait pas la même
--- chose. Un habillage doré est désaturé avant d'être assombri — sans quoi il
--- reste doré, sombre et jaune. Un parchemin, lui, **garde sa couleur** (voir
--- `KEEP_COLOR` dans `UI/Shade.lua`) : désaturé il vire au gris, gardé il fonce
--- en restant brun, ce qui est l'effet qu'on lui demande.
---
--- Un brun peut donc descendre bien plus bas qu'un doré désaturé sans devenir
--- une silhouette. Ce qu'il porte est écrit en blanc par-dessus (`WHITE_TEXT`),
--- sans quoi il faudrait s'arrêter beaucoup plus haut.
---
--- **La moitié**, et ce n'est pas un chiffre de goût : c'est la valeur que la
--- référence du genre emploie par défaut, un multiplicateur neutre à cinquante
--- pour cent (voir `dev/docs/API_NOTES.md`). On a essayé d'incliner la couleur
--- vers le brun en plus ; c'était de trop. Le brun ne vient pas d'une teinte
--- qu'on pose, il vient de ce qu'on **ne désature pas**.
T.SHADE_FACTOR_PARCHMENT = 0.50

--- La teinte de la **barre véhicule** : un tiers de sa clarté.
---
--- La teinte commune convient aux barres d'action parce que leur habillage est
--- fait de fins ornements sur du vide ; les reliefs y survivent à un facteur
--- très bas. La barre véhicule est l'inverse : un panneau d'art **opaque** qui
--- couvre toute la barre. Au facteur commun il devient exactement la silhouette
--- noire que le commentaire de `SHADE_FACTOR` décrit — plus rien ne s'y lit,
--- sauf les icônes, que le moteur ne teinte jamais.
---
--- Un tiers : assez bas pour que la barre suive visiblement le mode sombre,
--- assez haut pour qu'un panneau plein garde ses reliefs. Elle reste désaturée
--- comme les autres barres — c'est un habillage doré, pas un parchemin.
T.SHADE_FACTOR_VEHICLE = 0.35

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

--- Couleur d'un décompte : vert au départ, rouge à l'échéance.
---
--- Le trajet passe par l'**orange**, et c'est tout l'intérêt de cette fonction.
--- Aller du vert au rouge en droite ligne fait passer par leur moyenne, qui est
--- un olive sombre : au milieu du décompte — exactement le moment où on le
--- regarde — le chiffre est à son plus terne, alors qu'il devrait commencer à
--- alerter. En deux segments, le milieu tombe sur l'orange franc que le thème
--- garde pour ce rôle, et chaque étape reste vive.
---@param ratio number  1 au départ, 0 à l'échéance
---@return number r, number g, number b
function T.CountdownColor(ratio)
    if ratio < 0 then ratio = 0 elseif ratio > 1 then ratio = 1 end

    local from, to, t
    if ratio >= 0.5 then
        from, to, t = T.COLOR.ORANGE, T.COLOR.GREEN, (ratio - 0.5) * 2
    else
        from, to, t = T.COLOR.RED, T.COLOR.ORANGE, ratio * 2
    end

    local r1, g1, b1 = from:GetRGB()
    local r2, g2, b2 = to:GetRGB()

    return r1 + (r2 - r1) * t,
           g1 + (g2 - g1) * t,
           b1 + (b2 - b1) * t
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

--- Noms sous lesquels un template du client range la surface qui le remplit, et
--- les pièces qui font de lui une *fenêtre* plutôt qu'un contour.
local PANEL_FILL_KEYS = {
    "Bg", "Background", "Center", "TitleBg", "TopTileStreaks",
    "TitleContainer", "TitleText", "CloseButton", "PortraitContainer",
}

--- Retire le fond d'un contour, **nommément**.
---
--- La variante prudente de `T.ClearPanelBackground`, et la seule qui convienne à
--- un template dont la bordure est faite de régions et non d'un nine-slice :
--- cacher toutes les régions cacherait la bordure avec, et laisserait un
--- rectangle sans bord. On ne cache donc que ce qu'on sait nommer.
---
--- Un nom qu'on n'aurait pas prévu laisse au pire une surface de trop — visible,
--- corrigible, et sans commune mesure avec un panneau qui perd son contour.
---@param frame table
function T.HidePanelFill(frame)
    for i = 1, #PANEL_FILL_KEYS do
        local part = frame[PANEL_FILL_KEYS[i]]
        if part and part.Hide then part:Hide() end
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

--- Pistes d'amélioration, par l'identifiant que le client leur donne, et la
--- qualité d'objet dont chacune emprunte la couleur.
---
--- **Un identifiant, pas un nom.** `C_Item.GetItemUpgradeInfo` rend les deux :
--- `trackString`, traduit, et `trackStringID`, qui ne l'est pas. C'est le second
--- qu'on lit — une piste reconnue par son intitulé français serait une piste
--- inconnue sur un client anglais.
---
--- **Les couleurs ne sont pas inventées : ce sont celles des qualités d'objet.**
--- Orange pour le mythe, violet pour l'héroïque, bleu pour le champion, vert pour
--- le vétéran, blanc pour l'aventurier — c'est l'échelle que le joueur lit déjà
--- sur chaque objet du jeu, et la piste est elle aussi une échelle. En inventer
--- une seconde reviendrait à lui faire apprendre deux fois la même hiérarchie.
---
--- Les identifiants sont **relevés en jeu**, sur un personnage équipé des cinq
--- pistes : rien ne les publie en table. Les quatre premières se suivent, la
--- cinquième non — le mythe est à 978 quand l'héroïque est à 974, et cet écart
--- interdit de deviner les autres par le calcul. On ne les déduit donc pas, on
--- les relève.
---
--- Une piste absente retombe sur la qualité de l'objet, c'est-à-dire sur ce que
--- le module faisait avant : on perd la nuance, jamais la couleur.
local TRACK_QUALITY = {
    [971] = 1,   -- Aventurier → blanc
    [972] = 2,   -- Vétéran    → vert
    [973] = 3,   -- Champion   → bleu
    [974] = 4,   -- Héros      → violet
    [978] = 5,   -- Mythe      → orange
}

--- Couleur d'une piste d'amélioration, ou `nil` si on ne la connaît pas.
---@param trackStringID? number
---@return number|nil r, number|nil g, number|nil b
function T.TrackColor(trackStringID)
    local quality = trackStringID and TRACK_QUALITY[trackStringID]
    if not quality then return nil end
    return T.ItemQualityColor(quality)
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

--- jeton de ressource -> sa couleur, ou `false` si le client n'en publie pas.
local powerColors = {}

--- Teinte que le **client** donne à une ressource, ou `nil` s'il n'en a pas.
---
--- `PowerBarColor` est sa table : les points de combo y sont rouges, la
--- puissance sacrée dorée, le chi vert, les fragments d'âme violets. On la lit
--- plutôt que de recopier sept teintes — c'est le même parti pris que les
--- couleurs de classe, et pour la même raison : un joueur qui reconnaît une
--- ressource à sa couleur la reconnaîtra dans celle du jeu ou dans aucune.
---
--- Elle est indexée de deux façons, par jeton (« HOLY_POWER ») et par numéro de
--- type de ressource, sans que rien ne garantisse que les deux couvrent la même
--- liste : on essaie donc l'un puis l'autre.
---
--- Le résultat est retenu par jeton : la fonction est appelée sur un chemin qui
--- bat — une ressource se dépense plusieurs fois par seconde — et rien ne dit
--- que le client rende la même table à chaque fois (règle 7).
---@param token? string
---@param powerType? number
---@return ColorMixin|nil
function T.PowerColor(token, powerType)
    local key = token or powerType
    if key == nil then return nil end

    local cached = powerColors[key]
    if cached ~= nil then return cached or nil end

    local source = PowerBarColor
    local entry  = type(source) == "table"
                   and ((token and source[token]) or (powerType and source[powerType]))
                   or nil

    local color
    if type(entry) == "table" and type(entry.r) == "number" then
        color = CreateColor(entry.r, entry.g, entry.b)
    end

    powerColors[key] = color or false
    return color
end

--- Corps du nombre posé sur une rangée de ressource, d'après la hauteur d'une
--- case. Voir `T.SIZE.RESOURCE_TEXT_RATIO` pour le pourquoi de la proportion.
---@param cellHeight? number
---@return number
function T.ResourceTextSize(cellHeight)
    local size = (cellHeight or T.SIZE.RESOURCE_CELL_H) * T.SIZE.RESOURCE_TEXT_RATIO
    if size < T.SIZE.RESOURCE_TEXT_MIN then return T.SIZE.RESOURCE_TEXT_MIN end
    if size > T.SIZE.RESOURCE_TEXT_MAX then return T.SIZE.RESOURCE_TEXT_MAX end
    return size
end

--- Le passage lui-même, celui qu'on tente sous `pcall`.
---
--- **`type` et non `if not color`.** La valeur que le client rend ici est
--- *dérivée d'un secret*, et un secret ne se teste pas plus qu'il ne se lit :
--- `if not color` lève, le `pcall` avale, et la fonction annonce un refus là où
--- le passage aboutissait très bien. `type()` est le seul examen permis — il
--- rend la forme sans regarder la valeur, y compris sur un secret (voir
--- « Une valeur secrète interrompt tout un passage » dans `API_NOTES.md`).
---
--- Sortie de `T.SecretClassColor`, où elle était une fermeture : `pcall` prend
--- des arguments, et une fermeture bâtie à chaque appel est une allocation de
--- trop sur un chemin qui tourne à chaque battement de vie (règle 7).
---@param class any  jeton de classe, éventuellement secret
---@return boolean found, number? r, number? g, number? b
local function passClassColor(class)
    local color = C_ClassColor.GetClassColor(class)
    if type(color) ~= "table" then return false end
    return true, color:GetRGB()
end

--- Couleur d'une classe **qu'on n'a pas le droit de lire**.
---
--- En instance et en PvP, le client protège l'identité des unités : `UnitClass`
--- rend une chaîne *secrète*. `T.ClassColor` ne peut rien en faire — son cache
--- l'indexerait, et indexer avec un secret lève.
---
--- On ne la lit donc pas : on la **fait passer** telle quelle à la fonction du
--- client, qui a le droit de la comprendre, et on rend les trois nombres sans
--- jamais les regarder. C'est tout l'esprit du mécanisme : un secret traverse
--- l'addon, il ne s'y arrête pas.
---
--- **Le drapeau de retour n'est pas une commodité.** Les trois nombres rendus
--- peuvent être secrets à leur tour, et un secret ne se teste pas plus qu'il ne
--- se lit — `if r then` lèverait chez l'appelant. Il lui faut donc une réponse
--- qu'il ait le droit de regarder, et c'est ce booléen-là.
---
--- Tout est sous `pcall` : si le client refuse le passage, on rend `false` et
--- l'appelant s'abstient de peindre. Ne rien poser vaut mieux qu'un repli qui
--- écrase la teinte du client par une couleur qui n'informe personne.
---@param class any  jeton de classe, éventuellement secret
---@return boolean ok, number? r, number? g, number? b
function T.SecretClassColor(class)
    if not (C_ClassColor and C_ClassColor.GetClassColor) then return false end

    -- `found` est **notre** booléen, pas celui du client : c'est le seul de la
    -- chaîne qu'on ait le droit de tester. Un `r == nil` ne conviendrait pas —
    -- comparer un secret lève au même titre que le lire.
    --
    -- Le passage est une fonction de fichier et non une fermeture bâtie ici :
    -- `pcall` prend des arguments, et cette fonction-ci est appelée à chaque
    -- battement de vie de chaque plaque alliée (règle 7).
    local ok, found, r, g, b = pcall(passClassColor, class)

    if not ok or not found then return false end
    return true, r, g, b
end

--- Couleur du thème sous la forme que la base de réglages sait ranger.
---
--- Un `ColorMixin` porte des méthodes : rangé tel quel dans le SavedVariables,
--- il en ressortirait comme une table de nombres sans elles. Une couleur que le
--- joueur peut changer se stocke donc en trois nombres nommés, et cette fonction
--- est le seul endroit qui fasse la traduction — un défaut de couleur reste
--- ainsi déclaré dans le thème, jamais recopié dans un module (règle 2).
---@param color ColorMixin
---@return table  { r = , g = , b = }
function T.ColorTable(color)
    local r, g, b = color:GetRGB()
    return { r = r, g = g, b = b }
end

--- Réciproque : une couleur rangée en base, rendue sous la forme que le reste du
--- code manipule.
---
--- Elle est **relue comme une donnée venue d'ailleurs** : le sélecteur du client
--- l'a écrite, mais elle a passé la nuit sur le disque et le SavedVariables
--- s'édite à la main. Trois nombres ou rien — un repli vaut mieux qu'un cadre
--- peint avec une chaîne de caractères.
---@param stored any
---@param fallback ColorMixin
---@return ColorMixin
function T.ColorFrom(stored, fallback)
    if type(stored) == "table" then
        local r, g, b = stored.r, stored.g, stored.b
        if type(r) == "number" and type(g) == "number" and type(b) == "number" then
            return CreateColor(r, g, b)
        end
    end
    return fallback
end

--- Mesure que le client donne à ses barres d'infos, ou le repli fourni.
---
--- `NamePlateConstants` est la table où il range ce qu'il dessine : côté d'une
--- aura, hauteur d'une barre de sorts, corps des textes. **On la lit plutôt que
--- de la recopier**, et c'est ce qui distingue un exemple d'une imitation : les
--- nombres restent les siens, ils suivent ses retouches, et ils suivront un
--- changement de style qu'on n'aurait pas vu passer.
---
--- Les replis de `T.SIZE` ne servent que si le client cesse de publier la table.
--- Ils sont là pour que le mode test dégrade au lieu de disparaître ; ce ne sont
--- pas des valeurs de référence, et on ne les ajuste pas.
---@param key string
---@param fallback number
---@return number
function T.PlateConstant(key, fallback)
    local constants = NamePlateConstants
    local value = constants and constants[key]
    if type(value) == "number" and value > 0 then return value end
    return fallback
end

--- Ancre une région en arrondissant son décalage à la grille de l'écran.
---
--- Une ligne posée à un demi-pixel du bord y est dessinée à cheval sur deux
--- rangées : son texte pâlit et ses bords bavent, et comme chaque ligne d'une
--- page tombe à un endroit différent de la grille, deux lignes voisines n'ont
--- pas tout à fait la même netteté. Arrondir leur ordonnée à la grille remet
--- tout le monde en phase.
---
--- C'est ce qui reste du travail sur les filets : eux sont partis, la grille
--- vaut toujours pour ce qui s'écrit dessus.
---@param region table
---@param point string
---@param relativeTo table
---@param relativePoint string
---@param x number
---@param y number
function T.SetPixelPoint(region, point, relativeTo, relativePoint, x, y)
    if PixelUtil and PixelUtil.SetPoint then
        local ok = pcall(PixelUtil.SetPoint, region, point, relativeTo,
                         relativePoint, x, y)
        if ok then return end
    end

    region:SetPoint(point, relativeTo, relativePoint, x, y)
end

--- Corps d'un texte, en pixels, ou `nil` si le client ne le dit pas.
---@param fontString table
---@return number|nil
function T.TextSize(fontString)
    if type(fontString.GetFont) ~= "function" then return nil end

    local ok, _, size = pcall(fontString.GetFont, fontString)
    if not ok or type(size) ~= "number" or size <= 0 then return nil end
    return size
end

--- Change le corps d'un texte **sans toucher à sa police ni à son contour**.
---
--- C'est la seule écriture de police de l'addon hors des widgets, et elle vit ici
--- pour la même raison qu'eux (règle 2) : `SetFont` prend un fichier de police,
--- et un fichier de police ne se nomme pas ailleurs que dans ce fichier. Ici, on
--- n'en nomme aucun — on **relit** celui que le cadre porte déjà et on le
--- repose, avec son contour, en ne changeant que le nombre. Le texte reste donc
--- celui du client, dans sa langue et dans son style ; il est seulement plus
--- grand ou plus petit.
---@param fontString table
---@param size number
---@return boolean applied
function T.SetTextSize(fontString, size)
    if type(fontString.GetFont) ~= "function" then return false end

    local ok, file, _, flags = pcall(fontString.GetFont, fontString)
    if not ok or type(file) ~= "string" then return false end

    local written = pcall(fontString.SetFont, fontString, file, size, flags)
    return written
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

    -- Pastilles des lignes du suivi d'objectifs : la coche d'un objectif rempli et
    -- la puce d'un objectif en cours. Ce sont celles que le client pose lui-même sur
    -- ses lignes ; l'aperçu du chrono mythique+ en pose sur ses lignes d'exemple,
    -- qui doivent se lire comme les vraies.
    OBJECTIVE_DONE = "ui-questtracker-tracker-check",
    OBJECTIVE_TODO = "ui-questtracker-objective-nub",

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

    -- L'anneau **neutre** que le client pose sur ses boutons d'aura (le nom
    -- vient de sa table `DEBUFF_DISPLAY_INFO`). Le mode sombre l'impose à
    -- toutes les auras à la place des anneaux typés et des habillages
    -- spéciaux, **sans toucher à leur géométrie** : cet art-là est taillé
    -- exactement pour la région qui le porte, là où un trait replacé à la
    -- main tombait entre deux pixels — des bords découverts, jamais les mêmes
    -- selon l'icône.
    AURA_RING = "ui-debuff-border-default-noicon",
}

--- Épaisseur du trait de la lueur de bord, d'après la hauteur d'une case.
--- Voir `T.SIZE.RESOURCE_GLOW_TH_RATIO` pour le pourquoi de la proportion.
---@param cellHeight? number
---@return number
function T.ResourceGlowThickness(cellHeight)
    local th = (cellHeight or T.SIZE.RESOURCE_CELL_H) * T.SIZE.RESOURCE_GLOW_TH_RATIO
    if th < T.SIZE.RESOURCE_GLOW_TH_MIN then return T.SIZE.RESOURCE_GLOW_TH_MIN end
    if th > T.SIZE.RESOURCE_GLOW_TH_MAX then return T.SIZE.RESOURCE_GLOW_TH_MAX end
    return th
end

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

    -- Icône des macros de sauvegarde de configuration : le point
    -- d'interrogation, celui que le jeu donne d'office à une macro neuve.
    -- **Ce n'est pas un choix esthétique, c'est ce qui la rend posable** : une
    -- macro sans icône valable ne se glisse pas sur une barre d'action.
    --
    -- **Un identifiant de fichier, pas un chemin.** `CreateMacro` reçoit ce que
    -- le sélecteur d'icônes du client lui donne, et celui-ci lui passe le
    -- retour de `GetIconTexture()`, qui est un identifiant
    -- (`Blizzard_MacroIconSelector.lua`). Un chemin y est ignoré : la macro
    -- sort sans icône. Le client publie la valeur sous deux noms selon les
    -- versions ; le nombre n'est là que pour le jour où il n'en publierait
    -- aucun.
    CONFIG_MACRO      = QUESTION_MARK_ICON
                        or (Constants and Constants.CurrencyConsts
                            and Constants.CurrencyConsts.QUESTIONMARK_INV_ICON)
                        or 134400,

    -- Bouton de copie posé sur le cadre de chat : l'icône de note du client.
    -- C'est déjà ce qu'il met sur « du texte qu'on lit et qu'on recopie », et
    -- elle existe depuis toujours. Une icône de presse-papier n'existe pas dans
    -- le jeu, l'inventer ferait une pièce rapportée de plus.
    CHAT_COPY         = "Interface\\Buttons\\UI-GuildButton-PublicNote-Up",

    -- Bouton de rangement du panneau de filtres : les flèches de tourne-page
    -- du grimoire, présentes depuis la première extension. Le sens dit le
    -- geste — vers la fenêtre pour ranger le panneau, vers l'extérieur pour
    -- le ressortir.
    GF_STOW           = "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up",
    GF_SHOW           = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up",

    -- Vignette du bouton « retirer tous les marqueurs » : le rond barré rouge du
    -- **passage sur un butin**. Le jeu s'en sert déjà pour dire « celui-ci, non »
    -- ; c'est le seul signe de refus qu'il ait, et il ne ressemble à aucune des
    -- huit icônes de ciblage — une croix, elle, était la n° 7, posée juste à côté
    -- de sa propre case.
    LOOT_PASS         = "Interface\\Buttons\\UI-GroupLoot-Pass-Up",

    -- Planche des huit icônes de ciblage, celle que le client utilise partout —
    -- sur les unités marquées, dans son propre menu de marqueurs et sur la
    -- minicarte. C'est une planche de quatre colonnes sur quatre rangées dont
    -- les huit icônes occupent les deux premières : voir `T.RaidMarkerCoords`.
    RAID_MARKERS      = "Interface\\TargetingFrame\\UI-RaidTargetingIcons",

    -- Remplissages de barre de vie, au choix du joueur sur les barres d'infos.
    -- Deux textures du client, aucune empruntée à un autre addon (règle 8) :
    --
    --   · le **plat** est le carré blanc du moteur — teinté par la couleur de la
    --     barre, c'est l'aplat uniforme que les joueurs connaissent sous le nom
    --     de « Flat » ou « Solid » dans Details et consorts. La page l'appelle
    --     « couleur vive » : c'est ce qu'il fait à la teinte ;
    --   · le **raid** est le remplissage des cadres de raid du client, plus
    --     mat — la « couleur standard » de la page.
    STATUSBAR_FLAT    = "Interface\\Buttons\\WHITE8x8",
    STATUSBAR_RAID    = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill",

    -- Carré blanc du moteur. Même fichier que `STATUSBAR_FLAT` ci-dessus, sous un
    -- autre nom parce qu'il sert à tout autre chose : là c'est le remplissage
    -- d'une barre, ici c'est de la **couleur pure** à qui l'on donne sa forme par
    -- ancrage.
    --
    -- C'est ce qui en fait la matière des lueurs **étendues** : une image porte
    -- des détails, et des détails étirés sur quatre fois leur largeur deviennent
    -- flous et crénelés. Une couleur unie n'a rien à perdre — elle est aussi nette
    -- sur trois pixels que sur trois cents.
    SOLID             = "Interface\\Buttons\\WHITE8x8",

    -- Carré blanc **à coins arrondis**, le nôtre. Le client n'en a pas : ses
    -- masques sont circulaires, et un masque posé à l'exécution peut ne pas
    -- prendre du tout (voir `dev/docs/API_NOTES.md`) — l'alpha est donc cuit
    -- dans le fichier, comme le disque du logo. Blanc pour la même raison que
    -- `SOLID` : la teinte vient de `SetVertexColor`, jamais du fichier.
    --
    -- Se pose avec `SetTextureSliceMargins(T.SIZE.ROUNDED_RECT_RADIUS, …)` :
    -- sans la découpe en neuf, le rayon s'étire avec la texture et les coins
    -- d'une case large deviennent des ellipses.
    ROUNDED_RECT      = "Interface\\AddOns\\BshamelUI\\media\\rounded",

    -- Emplacement dépourvu d'enchantement : l'icône du métier d'enchanteur, celle
    -- que le jeu donne à la compétence elle-même. Elle est **désaturée** à
    -- l'affichage, ce qui suffit à dire « il manque quelque chose ici » sans
    -- écrire un mot — une icône éteinte se lit comme une case vide.
    ENCHANT_NONE      = "Interface\\Icons\\Trade_Engraving",

    -- Châsse vide, celle du cadre de sertissage du client. Prismatique parce
    -- qu'on ne cherche pas à dire **quelle** couleur de gemme irait : la question
    -- posée est « y a-t-il un trou », pas « lequel ».
    EMPTY_SOCKET      = "Interface\\ItemSocketingFrame\\UI-EmptySocket-Prismatic",

    -- Point lumineux qui court le long du bord, découpé dans la planche des armes
    -- prodigieuses (voir `T.TEXCOORD.GLOW_SPARK`).
    --
    -- **Une image, et cette fois c'est le bon outil.** Ce qui s'étire mal est une
    -- image *détaillée* ; celle-ci n'est qu'un fondu radial — aucun trait, aucun
    -- contour, rien qui puisse se créneler. Réduite à la taille d'un point, elle
    -- reste un dégradé rond, ce qu'une couleur unie ne sait pas faire : un aplat
    -- s'arrête net, et un bout net est précisément ce qui se lit comme un pixel.
    --
    -- **Pleine, et c'est ce qui la distingue des halos du client.** Ceux-ci — le
    -- cadre de qualité d'un objet, la bordure d'un bouton — sont **creux** : leur
    -- lumière est sur le pourtour et leur centre est transparent. Réduits à la
    -- taille d'un point, ils ne donnent pas une boule mais un petit carré vide,
    -- ce qui est exactement ce qu'on ne veut pas.
    --
    -- Repérée dans `LibCustomGlow-1.0`, qui s'en sert pour les étincelles tournant
    -- autour d'un bouton : on lit pour savoir *quel asset* résout le problème, on
    -- n'en copie pas le code (règle 8).
    GLOW_SPARK        = "Interface\\Artifacts\\Artifacts",
}

--- Découpes dans les planches du client, pour les textures qui n'occupent qu'une
--- part de leur fichier.
T.TEXCOORD = {
    -- Le point lumineux, dans le coin bas-droit de la planche des armes
    -- prodigieuses.
    GLOW_SPARK = { 0.8115234375, 0.9169921875, 0.8798828125, 0.9853515625 },
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
---
--- Elle se relève dans `WORLD_RAID_MARKER_ORDER` du gestionnaire de cadres de
--- raid du client, qui range ses vignettes du crâne vers l'étoile : notre table
--- est cette table-là retournée. Les cinq premiers marqueurs sont ceux de
--- Pandarie, les trois derniers ont été ajoutés en 6.0.2 — d'où la rupture de
--- suite au milieu, qui n'a l'air d'une faute de frappe que parce qu'elle est
--- historique.
T.WORLD_MARKER_ICON = { 6, 4, 3, 7, 1, 2, 5, 8 }

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

    -- Le contour d'un **panneau** : quatre côtés identiques, sans la bande de
    -- titre ni l'échancrure de bouton de fermeture que `WINDOW` ajoute en haut.
    --
    -- Deux entrées et non une, parce que ce sont deux besoins et non deux
    -- variantes du même. Une fenêtre a un titre et se ferme ; un panneau n'a ni
    -- l'un ni l'autre, et le haut de `WINDOW` réserve pourtant la place des deux.
    -- On a essayé de démonter `WINDOW` pour n'en garder que le contour : retirer
    -- par une liste de noms suppose de les connaître tous, et il en restait
    -- toujours un. Un template qui ne pose que ce qu'on veut n'a rien à démonter.
    --
    -- Repli sur le creux — moins ouvragé, jamais cassé.
    PANEL_BORDER = { "DialogBorderTemplate", "DialogBorderDarkTemplate",
                     "InsetFrameTemplate3" },
    -- `NamePlatePreviewTemplate` a vécu ici. Le monter réveille le gestionnaire
    -- de barres d'infos du panneau de réglages, qui repasse sur les **vraies**
    -- plaques en étant teinté par nous : erreur dans le code du client, et
    -- tailles rendues à celles de Blizzard à chaque ouverture de la fenêtre. Ne
    -- pas le réintroduire (voir `UI/Widgets/PlatePreview.lua`).

    -- Balayage de temps de recharge, celui que le client pose sur ses icônes de
    -- sort. Sans lui, une aura de la rangée de l'addon n'aurait pas d'horloge —
    -- elle s'affiche alors sans balayage, jamais cassée.
    COOLDOWN   = { "CooldownFrameTemplate" },

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
