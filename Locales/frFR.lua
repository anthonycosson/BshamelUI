-- =========================================================================
--  Bshamel UI — Locales/frFR.lua
--  Une clé absente ici retombe sur enUS. Mettre `true` pour « identique à
--  l'anglais » plutôt que de recopier la chaîne.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI

BUI:RegisterLocale("frFR", {
    -- Fenêtre d'options
    ["Bshamel UI"]              = true,
    ["Interface"]               = true,
    ["Quality of life"]         = "Qualité de vie",
    ["Tools"]                   = "Outils",
    ["Search..."]               = "Rechercher...",
    ["Reset this page"]         = "Réinitialiser cette page",
    ["Content scale"]           = "Vue compacte",
    ["Content scale tip"] =
        "Rapetisse tout ce qui est dans la fenêtre sans toucher à la fenêtre "
        .. "elle-même : il y tient donc plus de réglages. Cliquez pour choisir "
        .. "une taille.",
    ["Scale percent"]           = "%d %%",
    ["Slider value tip"] =
        "Clic droit pour saisir une valeur exacte. Entrée valide, Échap annule.",
    ["Reset page confirm"]      = "Remettre tous les réglages de cette page à leur valeur par défaut ?",
    ["Yes"]                     = "Oui",
    ["Cancel"]                  = "Annuler",
    ["Open Bshamel UI"]         = "Ouvrir Bshamel UI",
    ["Cannot open in combat"]   = "La fenêtre d'options ne peut pas être ouverte en combat.",
    ["Module disabled tooltip"] = "Ce module est désactivé.",
    ["Version"]                 = true,
    ["Blocked action watch"]    = "Veille des actions bloquées :",
    ["Blocked action needs errors"] =
        "L'affichage des erreurs Lua a été allumé : le jeu ne signale les actions bloquées " ..
        "qu'à cette condition. Il retrouvera son état en éteignant la veille.",
    ["On"]                      = "activée",
    ["Off"]                     = "désactivée",

    -- Modules annoncés (Modules/Upcoming.lua)
    ["Coming soon"]             = "Bientôt disponible",
    ["Coming soon notice"] =
        "Ce module n'est pas encore écrit. Les réglages ci-dessous montrent ce qu'il proposera.",
    ["Coming soon tooltip"]     = "Pas encore disponible.",
    ["Coming soon suffix"]      = " (Prochainement)",

    -- Module Quest
    ["Quest"]                   = "Quête",
    ["Automation"]              = "Automatisation",
    ["Auto-accept quests"]      = "Accepter automatiquement les quêtes",
    ["Auto-accept quests tip"] =
        "Accepte automatiquement les quêtes proposées par les PNJ et les objets de quête.",
    ["Auto-turn-in quests"]     = "Rendre automatiquement les quêtes",
    ["Auto-turn-in quests tip"] =
        "Termine la quête et prend la récompense automatiquement lorsqu'il n'y en a qu'une.",
    ["Filters"]                 = "Filtres",
    ["Skip trivial quests"]     = "Ignorer les quêtes de bas niveau",
    ["Skip trivial quests tip"] = "Ne touche pas aux quêtes grises (triviales).",
    ["Bypass modifier"]         = "Maintenir pour ignorer",
    ["Bypass modifier tip"]     = "Maintenez cette touche pour suspendre temporairement l'automatisation.",
    ["None"]                    = "Aucune",
    ["Shift"]                   = "Maj",
    ["Ctrl"]                    = true,
    ["Alt"]                     = true,

    -- Module General
    ["General"]                        = "Général",
    -- Module DarkMode
    ["Enable dark mode"]               = "Activer le mode sombre",
    ["What it darkens"]                = "Ce qu'il assombrit",
    ["Dark action bars tip"]           = "Boutons, bordures et habillage derrière chaque barre d'action.",
    ["Cast bar"]                       = "Barre d'incantation",
    ["Dark cast bar tip"]              = "Votre barre d'incantation et celle de votre cible.",
    ["Dark unit frames tip"] =
        "Cadres du joueur, du familier, de la cible, de la cible de la cible et du focus. "
        .. "Les cadres de boss, de groupe et de raid ne sont pas touchés.",
    ["Buffs and debuffs"]              = "Buffs et debuffs",
    ["Dark auras tip"]                 = "Icônes d'auras, leurs bordures et leurs minuteurs.",
    ["Tooltip"]                        = "Infobulle",
    ["Dark tooltip tip"] =
        "La bordure de l'infobulle. Son fond reste tel que le jeu l'a réglé.",
    ["Cooldown manager"]               = "Gestionnaire de temps de recharge",
    ["Dark cooldown manager tip"]      = "Les barres du gestionnaire de temps de recharge et leurs icônes.",
    -- Module General (suite)
    ["Camera"]                         = "Caméra",
    ["Max camera distance"]            = "Augmenter la distance maximale de la caméra",
    ["Max camera distance tip"] =
        "Permet à la caméra de reculer plus loin que ce que le client autorise par défaut.",
    ["Camera zoom factor"]             = "Facteur de zoom",
    ["Camera zoom factor tip"] =
        "Multiplie la limite de recul du client. 2,9 est le maximum qu'il accepte.",
    -- La touche est dans l'intitulé de la section : « menu du jeu » ne désigne
    -- rien pour qui ne l'a jamais lu écrit, alors que tout le monde connaît le
    -- menu qui s'ouvre sur Échap.
    ["Game menu"]                      = "Menu du jeu (Échap)",
    ["Compact game menu"]              = "Réduire le menu du jeu",
    ["Compact game menu tip"] =
        "Rapetisse le menu ouvert par Échap, que le client dessine très grand.",
    ["Game menu scale"]                = "Taille du menu",
    ["Game menu scale tip"]            = "Taille du menu Échap, en pourcentage de celle du client.",
    ["Queues"]                         = "Files d'attente",
    ["Queue popup timer"]              = "Afficher un minuteur sur les fenêtres de file",
    ["Queue popup timer tip"] =
        "Décompte le temps restant pour accepter une entrée en donjon, en raid, en arène ou en champ de bataille.",
    ["Auto-repair"]                    = "Réparation automatique",
    ["Auto-repair tip"] =
        "Répare à chaque marchand, en puisant d'abord dans les fonds de guilde, puis dans votre bourse.",
    ["Repaired from guild"]            = "Réparé pour %s sur les fonds de guilde.",
    ["Repaired from purse"]            = "Réparé pour %s.",
    ["Repair too expensive"]           = "Pas assez d'argent pour réparer : il faut %s.",
    ["Auction house"]                  = "Hôtel des ventes",
    ["Auction current expansion"]      = "Extension actuelle uniquement",
    ["Auction current expansion tip"] =
        "Limite la navigation de l'hôtel des ventes aux objets de l'extension actuelle.",
    ["Annoyances"]                     = "Nuisances",
    ["Skip cinematics"]                = "Passer les cinématiques",
    ["Skip cinematics tip"] =
        "Les vidéos et les cinématiques partent toutes seules. Une scène en jeu s'arrête à votre " ..
        "première touche : le jeu ne la laisse couper que pendant qu'il traite une touche.",
    ["Hide talking heads"]             = "Masquer les têtes parlantes",
    ["Hide talking heads tip"] =
        "Masque le cadre de tête parlante qui apparaît pendant les quêtes et les donjons.",
    ["Hide Lua errors"]                = "Masquer les erreurs Lua",
    ["Hide Lua errors tip"] =
        "Supprime la fenêtre d'erreur. Les erreurs restent transmises aux gestionnaires d'erreurs.",


    -- Module Character
    ["Character sheet"]                = "Fiche de personnage",
    ["Item details"]                   = "Détails des objets",
    ["Show item level"]                = "Afficher le niveau d'objet",
    ["Show item level on slots tip"] =
        "Affiche le niveau d'objet de chaque pièce équipée à côté de son emplacement, mise à "
        .. "l'échelle comprise.",
    ["Show upgrade level"]             = "Afficher le niveau d'amélioration",
    ["Show upgrade level tip"] =
        "Affiche le rang d'amélioration à côté du niveau d'objet, entre parenthèses. Les deux "
        .. "prennent la couleur de la piste d'amélioration : orange pour le mythe, violet pour "
        .. "l'héroïque, bleu pour le champion, vert pour le vétéran, blanc en dessous.",
    ["Show enchants"]                  = "Afficher les enchantements",
    ["Show enchants tip"] =
        "Vert sur chaque emplacement qui peut recevoir un enchantement et en a un, rouge sur ceux qui n'en ont pas.",
    ["Show gems"]                      = "Afficher les gemmes",
    ["Show gems tip"] =
        "Vert quand toutes les châsses sont serties, rouge dès qu'il en reste une vide.",
    ["Bags and bank"]                  = "Sacs et banque",
    ["Show item level in bags"]        = "Afficher le niveau d'objet sur l'équipement rangé",
    ["Show item level in bags tip"] =
        "Inscrit le niveau d'objet sur chaque pièce d'équipement dans les sacs, la banque et la banque de bataillon.",
    ["Enchant badge"]                  = "Enchantement",
    ["Gem badge"]                      = "Gemme",
    ["No enchant hint"]                = "Cet emplacement peut être enchanté et ne l'est pas.",
    ["Empty socket"]                   = "Châsse vide",
    ["Empty socket hint"]              = "Cliquez pour y sertir une gemme de vos sacs.",

    -- Modules ActionBars et UnitFrames
    ["Action bars"]                    = "Barres d'action",
    ["Input"]                          = "Saisie",
    ["Cast on key down"]               = "Lancer les actions",
    ["Cast on key down tip"] =
        "Si l'action part au moment où la touche s'enfonce, ou quand elle remonte. Vaut pour "
        .. "toutes les barres d'action, et pour les clics comme pour les touches.",
    ["Cast on key down notice"] =
        "Le jeu a son propre défaut ici, et d'autres addons écrivent le même réglage. C'est "
        .. "pourquoi il y a trois choix et non une case à cocher : « Défaut du jeu » ne touche "
        .. "à rien, les deux autres forcent dans un sens ou dans l'autre. Éteindre ce module "
        .. "rend au jeu la valeur qu'il avait avant.",
    ["Game default"]                   = "Défaut du jeu",
    ["Key down"]                       = "À l'enfoncement",
    ["Key up"]                         = "Au relâchement",
    ["Unit frames"]                    = "Cadres d'unités",
    ["Appearance"]                     = "Apparence",
    ["Dark mode"]                      = "Mode sombre",
    ["Dark mode tip"]                  = "Assombrit l'habillage pour qu'il se fonde dans l'écran.",
    ["Class-colored health"]           = "Barres de vie aux couleurs de classe",
    ["Class-colored health tip"]       = "Colore chaque barre de vie selon la classe de l'unité.",
    ["Hide reputation color"]          = "Masquer la couleur de réputation",
    ["Hide reputation color tip"] =
        "Retire la plaque aux couleurs de la faction posée derrière le nom, sur le cadre de la " ..
        "cible et sur celui du focus.",
    ["Show spec icon"]                 = "Afficher l'icône de spécialisation",
    ["Show spec icon tip"] =
        "Remplace le portrait par l'icône de spécialisation sur les cadres du joueur, de la cible, " ..
        "du focus et de la cible de la cible. La spécialisation d'un autre joueur n'est connue que " ..
        "lorsque le jeu peut l'inspecter, ce qui suppose qu'il soit à proximité ; d'ici là le " ..
        "portrait est laissé tel quel.",
    ["Decorations"]                    = "Décorations",
    ["Hide rested effect"]             = "Masquer l'effet de repos",
    ["Hide rested effect tip"] =
        "Retire l'animation que le jeu joue sur votre portrait lorsque vous êtes reposé.",
    ["Hide corner icon"]               = "Masquer l'icône de coin",
    ["Hide corner icon tip"] =
        "Retire la pastille que le jeu dessine dans le coin de votre portrait.",
    ["Hide combat glow"]               = "Masquer la lueur de combat",
    ["Hide combat glow tip"] =
        "Retire la lueur clignotante posée autour de chaque cadre engagé : le vôtre, celui de "
        .. "votre familier, de votre cible, de votre focus et des boss.",
    ["Hide PvP icon"]                  = "Masquer l'icône JcJ",
    ["Hide PvP icon tip"] =
        "Retire l'icône JcJ et le badge de prestige des cadres du joueur, de la cible et du focus.",
    ["Party frames"]                   = "Cadres de groupe",
    ["Enlarge party frames"]           = "Agrandir les cadres de groupe",
    ["Enlarge party frames tip"] =
        "Agrandit les cadres de groupe au-delà du maximum qu'autorise le curseur du mode Édition.",
    ["Party frame scale"]              = "Échelle des cadres de groupe",
    ["Party frame scale tip"] =
        "Pourcentage de la taille d'origine. 100 % est la taille que les cadres ont déjà.",
    ["Arena frames"]                   = "Cadres d'arène",
    ["Enlarge arena frames"]           = "Agrandir les cadres d'arène",
    ["Enlarge arena frames tip"] =
        "Agrandit les cadres des adversaires en arène au-delà du maximum qu'autorise le curseur "
        .. "du mode Édition. La taille se pose pendant la phase de préparation : le jeu refuse "
        .. "de redimensionner ces cadres pendant le combat.",
    ["Arena frame scale"]              = "Échelle des cadres d'arène",
    ["Arena frame scale tip"] =
        "Pourcentage de la taille d'origine. 100 % est la taille que les cadres ont déjà.",

    -- Module CooldownManager
    ["Tracked buffs"]                  = "Suivi des améliorations",
    ["Center tracked buffs"]           = "Garder les améliorations groupées au centre",
    ["Center tracked buffs tip"] =
        "Le jeu réserve une place par amélioration suivie et la laisse vide quand l'amélioration "
        .. "tombe : celles qui restent affichées demeurent écartées. Ce réglage les retasse "
        .. "ensemble, au milieu de la rangée.",

    -- Module Chat
    ["Chat"]                           = true,
    ["History"]                        = "Historique",
    ["Keep history"]                   = "Conserver l'historique après un rechargement",
    ["Keep history tip"]               = "Restaure les derniers messages après un /reload ou une reconnexion.",
    ["Chat history separator"]         = "----- session précédente -----",
    ["Drag to resize"]                 = "Ajuster la hauteur en tirant l'onglet",
    ["Drag to resize tip"] =
        "Tirez un onglet du chat vers le haut ou vers le bas pour en changer la hauteur. "
        .. "Un simple clic continue de changer d'onglet, et la nouvelle taille est retenue "
        .. "par le jeu lui-même.",
    ["Unify group colors"]             = "Une seule couleur pour le groupe",
    ["Unify group colors tip"] =
        "Groupe, instance et raid prennent la couleur du chat de groupe : une conversation "
        .. "avec les mêmes gens garde la même couleur partout. Les avertissements de raid "
        .. "gardent la leur.",
    ["Copy"]                           = "Copie",
    ["Copy button"]                    = "Afficher un bouton de copie sur le chat",
    ["Copy button tip"] =
        "Ajoute un bouton discret dans le coin haut-droit de chaque fenêtre de chat.",
    ["Copy chat"]                      = "Copier le chat",
    ["Copy chat hint"]                 = "Tout est sélectionné : Ctrl+C pour copier.",

    -- Bouton de l'addon (module General)
    ["Buttons"]                        = "Boutons",
    ["Minimap button"]                 = "Afficher le bouton BshamelUI sur la minicarte",
    ["Minimap button tip"] =
        "Clic gauche : liste d'addons\n"
        .. "Clic droit : options\n"
        .. "Glisser : déplacer autour de la minicarte",

    ["Addon buttons empty"]            = "Aucune icône d'addon à afficher.",
    ["Group addon buttons"]            = "Regrouper les boutons d'addons",
    ["Group addon buttons tip"] =
        "Range les boutons de minicarte des autres addons dans un tiroir. Clic gauche sur le "
        .. "bouton BshamelUI pour les retrouver. Éteindre le réglage remet chaque bouton "
        .. "exactement où il était.",

    -- Module Teleports
    ["Teleports"]                      = "Téléportations",
    ["Menu"]                           = true,
    ["Teleport menu"]                  = "Afficher un bouton de téléportation sur la minicarte",
    ["Teleport menu tip"] =
        "Ajoute un bouton à côté de la minicarte : vos pierres de foyer, et les donjons de la "
        .. "saison en cours dans un sous-menu. Un clic sur une ligne l'utilise.",
    ["Teleport menu notice"] =
        "Le menu ne montre que ce que ce personnage possède ou connaît réellement : la pierre "
        .. "de foyer choisie ci-dessus, les pierres qui ont leur propre temps de recharge, et "
        .. "chaque donjon de la saison en cours vers lequel vous avez une téléportation, voie "
        .. "héroïque ou mythique. Il ne s'ouvre pas en combat : le jeu refuse de confier un "
        .. "sort à un addon pendant un combat, et de toute façon rien de ce qu'il contient ne "
        .. "s'utilise en combat.",
    ["Teleport in combat"]             = "Le menu de téléportation ne s'ouvre pas en combat.",
    ["Hearthstones"]                   = "Pierres de foyer",
    ["Hearthstone choice"]             = "Pierre de foyer personnalisée",
    ["Hearthstone choice tip"] =
        "Quelle pierre de foyer le menu propose. Elles partagent toutes le même temps de "
        .. "recharge et vont toutes au même endroit : le menu n'en montre donc qu'une, celle "
        .. "que vous préférez regarder. La liste ne contient que celles que ce personnage "
        .. "possède.",
    ["Other expansions"]               = "Autres extensions",
    ["Teleport macro"]                 = "Macro pour la barre d'action",
    ["Teleport macro tip"] =
        "Crée une macro qui ouvre ce menu. Glissez-la depuis la fenêtre des macros sur une barre "
        .. "d'action : un emplacement n'accepte que ce que le jeu y range, et une macro en fait "
        .. "partie.",
    ["Create"]                         = "Créer",
    ["Teleport macro name"]            = "Téléportation",
    ["Teleport macro created"] =
        "Macro « %s » créée. Ouvrez la fenêtre des macros et glissez-la sur une barre d'action.",
    ["Teleport macro updated"]         = "La macro « %s » est déjà là, et à jour.",
    ["Teleport macro failed"]          = "Plus d'emplacement de macro libre : libérez-en un et réessayez.",
    -- Toutes les familles commencent par « Voie » : voie héroïque, voie
    -- temporelle. Un seul préfixe suffit donc, et il les prend toutes — y
    -- compris celles qu'une extension ajoutera.
    ["Teleport spell prefixes"]        = "Voie",

    -- Module Bags
    ["Bags and repairs"]               = "Sacs & Réparations",
    ["Sold junk"]                      = "Camelote vendue pour %s.",
    ["Merchants"]                      = "Marchands",
    ["Auto-sell junk"]                 = "Vendre automatiquement la camelote",
    ["Auto-sell junk tip"]             = "Vend les objets gris à chaque marchand.",
    ["Skip sell confirmation"]         = "Passer la confirmation de vente",
    ["Skip sell confirmation tip"] =
        "Répond à la fenêtre qui s'ouvre quand vous vendez un butin encore échangeable ou " ..
        "remboursable.",
    ["Skip sell confirmation warning"] =
        "Cette fenêtre est la dernière étape avant que l'objet cesse d'être échangeable et " ..
        "remboursable. Avec ce réglage, un clic de trop le vend pour de bon.",
    ["Confirmations"]                  = true,
    ["Fill delete confirmation"]       = "Remplir la confirmation de destruction",
    ["Fill delete confirmation tip"] =
        "Saisit le mot de confirmation à votre place quand la destruction d'un objet le demande.",

    -- Module Keystones
    ["Keystones"]                      = "Clés mythiques",
    ["Answer keys request"]            = "Répondre à !keys dans le chat",
    ["Answer keys request tip"] =
        "Répond avec votre clé quand quelqu'un tape !keys en groupe, en raid, en instance ou en "
        .. "guilde. Jamais à un chuchotement ni dans un canal public.",
    ["Auto slot keystone"]             = "Insérer la clé automatiquement",
    ["Auto slot keystone tip"] =
        "Place votre clé dans la fontaine de puissance dès qu'elle s'ouvre. Une clé déjà posée "
        .. "par quelqu'un d'autre n'est pas touchée.",
    ["Keystones notice"] =
        "La réponse est le lien de la clé lui-même dès qu'elle est trouvée dans les sacs : chacun "
        .. "peut donc la survoler. Sinon, le donjon et le niveau sont écrits en toutes lettres. "
        .. "Seuls les canaux de groupe, de raid, d'instance et de guilde sont écoutés, jamais un "
        .. "chuchotement. Votre propre !keys obtient une réponse lui aussi, ce qui est la façon "
        .. "la plus simple de vérifier que le réglage marche.",
    ["No keystone"]                    = "Pas de clé.",
    ["Dungeon dialogue"]               = "Dialogues de donjon",
    ["Auto dungeon gossip"]            = "Parler aux PNJ à votre place",
    ["Auto dungeon gossip tip"] =
        "Clique pour vous la seule ligne d'un dialogue dans un donjon : les prisonniers à libérer "
        .. "à la Fosse de Saron, le bienfait distribué au début de l'Académie Algeth'ar.",
    ["Dungeon gossip notice"] =
        "Uniquement dans un donjon, uniquement un dialogue qui propose une seule ligne et aucune "
        .. "quête, et chaque ligne n'est cliquée qu'une fois par conversation. Une quête reste à "
        .. "la page « Quêtes », un vrai choix reste à vous. Attention : un dialogue qui lance une "
        .. "rencontre n'a lui aussi qu'une seule ligne — parler à ce PNJ la déclenche aussitôt.",

    -- Module GroupFinder
    ["Group finder"]                   = "Recherche de groupe",
    ["Signing up"]                     = "Inscription",
    ["Keep signup note"]               = "Conserver la note d'inscription",
    ["Keep signup note tip"] =
        "Retient ce que vous écrivez dans la note de candidature et le remet la fois suivante.",
    ["Auto role check"]                = "Valider les vérifications de rôle",
    ["Auto role check tip"] =
        "Répond automatiquement à la vérification des rôles, avec ceux que vous aviez déjà choisis.",
    -- Module RaidCooldowns
    ["Bloodlust and battle res"]       = "BL & Résurrections",
    ["Battle resurrections"]           = "Résurrections de combat",
    ["Battle res tracker"]             = "Suivi des résurrections de combat",
    ["Battle res tracker tip"] =
        "Affiche le nombre de résurrections de combat restantes et le délai avant la suivante.",
    ["Battle res size"]                = "Taille de l'icône",
    ["Battle res size tip"] =
        "Côté de l'icône, en pixels. Elle se déplace à la souris.",
    ["Battle res shaded"]              = "Contour sombre sur l'icône",
    ["Battle res shaded tip"] =
        "Pose le contour sombre de l'addon autour de l'icône, comme le mode sombre le fait sur "
        .. "les icônes d'auras. Celui-ci est son propre réglage : le mode sombre ailleurs n'en "
        .. "décide pas.",
    ["Lock battle res"]                = "Verrouiller la position de l'icône",
    ["Lock battle res tip"]            = "Fige l'icône où elle est. Elle continue de compter.",
    ["Battle res preview"]             = "Mode aperçu",
    ["Battle res preview tip"] =
        "Affiche l'icône hors instance, remplie de valeurs d'exemple, pour pouvoir la placer.",

    ["Bloodlust"]                      = "Furie sanguinaire",
    ["Lust tracker"]                   = "Suivi de l'interdiction de BL",
    ["Lust tracker tip"] =
        "Décompte le débuff d'interdiction que toute BL laisse derrière elle. C'est lui, et non "
        .. "la hâte, qui décide du moment où le prochain pull pourra en avoir une.",
    ["Lust size"]                      = "Taille de l'icône",
    ["Lust size tip"]                  = "Côté de l'icône, en pixels. Elle se déplace à la souris.",
    ["Lust shaded"]                    = "Contour sombre sur l'icône",
    ["Lust shaded tip"] =
        "Pose le contour sombre de l'addon autour de l'icône, comme le mode sombre le fait sur "
        .. "les icônes d'auras. Celui-ci est son propre réglage : le mode sombre ailleurs n'en "
        .. "décide pas.",
    ["Lock lust"]                      = "Verrouiller la position de l'icône",
    ["Lock lust tip"]                  = "Fige l'icône où elle est. Elle continue de compter.",
    ["Lust preview"]                   = "Mode aperçu",
    ["Lust preview tip"] =
        "Affiche l'icône avec un décompte d'exemple, pour pouvoir la placer sans attendre un pull.",
    ["Hide lust debuff"]               = "Masquer le débuff dans les affaiblissements",
    ["Hide lust debuff tip"] =
        "Retire le débuff d'interdiction de votre rangée d'affaiblissements, puisque l'icône "
        .. "ci-dessus le décompte déjà. Décocher le remet.",
    ["Lust notice"] =
        "Chaque classe qui peut en donner une laisse son propre débuff — chaman, mage, familier "
        .. "de chasseur, évocateur — et le suivi les reconnaît tous. L'icône est celle du chaman, "
        .. "quelle que soit la classe qui l'a lancée : ce qu'elle dit est qu'une BL est partie, "
        .. "pas laquelle.",

    -- Module RaidPanel
    ["Group tools"]                    = "Outils de groupe",
    ["Blizzard panel"]                 = "Le panneau du jeu",
    ["World markers"]                  = "Panneau d'outils de groupe",
    ["World markers tip"] =
        "Un panneau avec les huit marqueurs au sol, un rond barré rouge qui les retire tous, une "
        .. "vérification de présence et un pull timer. Il se déplace à la souris, et son coin "
        .. "bas-droit règle sa taille.",
    ["Lock group tools"]               = "Verrouiller la position du panneau",
    ["Lock group tools tip"] =
        "Fige le panneau où il est et range sa poignée. Les boutons continuent de fonctionner.",
    ["Group tools on hover"]           = "N'afficher qu'au survol",
    ["Group tools on hover tip"] =
        "Garde le panneau invisible tant que la souris n'est pas dessus. Il prend toujours la "
        .. "souris là où il se trouve : retenez où vous l'avez posé.",
    ["World marker number"]            = "Marqueur au sol %d",
    ["World marker tip"]               = "Pose ce marqueur au sol là où vous visez.",
    ["Clear markers"]                  = "Retirer les marqueurs",
    ["Clear markers tip"]              = "Retire tous les marqueurs au sol.",
    ["Ready"]                          = "Ready",
    ["Ready check tip"] =
        "Lance une vérification de présence. Demande d'être chef ou promu.",
    ["Pull"]                           = "Pull",
    ["Pull tip"] =
        "Lance le décompte et l'annonce dans le chat du groupe. Demande d'être chef ou promu.",
    ["Pull seconds"]                   = "Pull (%d)",
    ["Pull announce"]                  = "Pull dans %d secondes.",
    ["Pull timer"]                     = "Durée du pull",
    ["Pull timer tip"]                 = "Nombre de secondes décomptées par le bouton de pull.",
    ["Group tools notice"] =
        "Le panneau n'apparaît pas, ne disparaît pas et ne se redimensionne pas en combat : le jeu "
        .. "refuse de montrer, de cacher ou de retailler un bouton de marqueur pendant qu'on se "
        .. "bat. Il suit de nouveau le réglage dès la fin du combat.",
    ["Need lead"]                      = "Il faut être chef ou promu pour ça.",

    ["Raid manager"]                   = "Panneau de contrôle",
    ["Hide raid manager"]              = "Masquer le panneau de contrôle du jeu",
    ["Hide raid manager tip"] =
        "Masque l'onglet que le jeu colle contre le bord gauche de l'écran en raid.",
    ["Raid manager notice"] =
        "Le panneau est un cadre protégé : il n'est ni rangé ni rendu pendant un combat. Il suit "
        .. "de nouveau le réglage dès la fin du combat.",

    -- Module CombatLog
    ["Logging"]                        = "Journalisation",
    ["Auto combat logging"]            = "Journalisation automatique des combats",
    ["Auto combat logging tip"] =
        "Lance la journalisation dès l'entrée dans un donjon ou un raid, et la coupe en sortant. "
        .. "La journalisation détaillée est activée avec elle, puis remise comme elle était.",
    ["Combat log armed"] =
        "Journalisation automatique activée. Elle démarrera toute seule dès que vous mettrez les "
        .. "pieds dans un donjon ou un raid, et le dira ici.",
    ["Combat log off"]                 = "Journalisation automatique désactivée.",
    ["Combat log started"] =
        "Journalisation lancée, journalisation détaillée activée. Le fichier est "
        .. "Logs\\WoWCombatLog.txt.",
    ["Combat log stopped"]             = "Journalisation des combats arrêtée.",
    ["Combat log already on"] =
        "La journalisation était déjà en cours : elle n'est pas touchée, et ne sera pas coupée en "
        .. "sortant.",
    -- Module MythicTimer
    ["Mythic+ timer"]                  = "Chrono mythique+",
    ["Display"]                        = "Affichage",
    ["Show key thresholds"]            = "Afficher les chronos +2 / +3",
    ["Show key thresholds tip"] =
        "Deux temps ajoutés à droite du chrono du jeu : ce qu'il reste avant de perdre +3, en or, "
        .. "puis avant de perdre +2, en gris. Plus un repère sur la barre à chaque palier. Un "
        .. "palier perdu retire son nombre.",
    ["Show death time"]                = "Afficher le coût des morts",
    ["Show death time tip"] =
        "Les secondes que vos morts ont ajoutées, en rouge et en petit, entre le niveau de la clé "
        .. "et les affixes. Le jeu les compte et ne montre ce nombre que dans une infobulle.",
    ["Show boss times"]                = "Afficher les temps de boss",
    ["Show boss times tip"] =
        "Le temps auquel chaque boss est tombé, contre son nom dans le suivi, et sur la ligne du "
        .. "dessous l'écart avec votre clé la plus rapide réussie dans le chrono au même niveau : "
        .. "vert si vous êtes devant, rouge sinon.",
    ["Timer preview"]                  = "Mode aperçu",
    ["Timer preview tip"] =
        "Affiche le chrono du jeu hors donjon, sur une clé d'exemple avec des boss et un décompte "
        .. "de troupes d'exemple, pour voir ce que ça donne. Éteignez les options une à une pour "
        .. "voir le suivi tel que le jeu le dessine.",
    ["Mythic timer notice"] =
        "Les paliers sont ceux du jeu : terminer sous 80 % du chrono donne +2, sous 60 % donne "
        .. "+3. Tout ici s'ajoute au chrono du jeu — le temps restant, le niveau et le compteur "
        .. "de morts restent les siens. Les temps de boss sont retenus par personnage, et "
        .. "seulement pour les clés réussies dans le chrono.",
    ["Preview dungeon"]                = "Donjon d'exemple",
    ["Preview boss"]                   = "Boss d'exemple %d",
    ["Preview forces"]                 = "Forces ennemies",

    -- Module Windows
    ["Windows"]                        = "Fenêtres",
    ["Moving"]                         = "Déplacement",
    ["Move windows"]                   = "Permettre le déplacement des fenêtres du jeu",
    ["Move windows tip"] =
        "Faites glisser une fenêtre du jeu : elle reste où vous la posez, "
        .. "d'une session à l'autre. Seules les fenêtres qui reçoivent déjà "
        .. "la souris peuvent être prises.",
    ["Move modifier"]                  = "Déplacer avec",
    ["Move modifier tip"] =
        "Touche à maintenir pour faire glisser une fenêtre. Sans touche, "
        .. "un glisser n'importe où dans le corps d'une fenêtre la déplace.",
    ["No modifier"]                    = "Aucune touche",
    ["Size"]                           = "Taille",
    ["Scale windows"]                  = "Redimensionner avec Ctrl + Molette",
    ["Scale windows tip"] =
        "Maintenez Ctrl et tournez la molette au-dessus d'une fenêtre pour "
        .. "l'agrandir ou la réduire. La taille est mémorisée comme la position.",
    ["Reset"]                          = "Réinitialiser",
    ["Reset window layout"]            = "Tout remettre en place",
    ["Reset window layout tip"] =
        "Renvoie chaque fenêtre là où Blizzard la met. %d déplacée(s) en ce moment.",
    ["Reset windows confirm"] =
        "Remettre chaque fenêtre à sa position et à sa taille d'origine ?",
    ["Window layout reset"]            = "Toutes les fenêtres ont retrouvé leur place.",

    -- Module Nameplates
    -- « Barres d'infos » et non « barres de nom » : c'est le nom que le client
    -- français donne lui-même à ces plaques. Une page se cherche sous le nom que
    -- le joueur a sous les yeux dans les options du jeu, pas sous la traduction
    -- littérale de son nom anglais.
    ["Nameplates"]                     = "Barres d'infos",

    ["Blizzard settings"]              = "Paramètres Blizzard",
    ["Blizzard settings notice"] =
        "Les réglages de barres d'infos du jeu, rassemblés ici pour n'avoir qu'un "
        .. "seul endroit où aller. Ils ne sont pas recopiés : en changer un ici le "
        .. "change aussi dans le menu du jeu, et réciproquement. Éteindre ce module "
        .. "les laisse exactement dans l'état où vous les avez mis.",
    ["Bshamel UI options"]             = "Options Bshamel UI",
    ["Bshamel UI options notice"] =
        "Ce que le menu du jeu ne propose pas : les réglages que l'addon ajoute, "
        .. "et les quelques-uns du jeu qu'il ne montre nulle part. Chaque "
        .. "interrupteur rend ce qu'il avait pris quand on l'éteint.",
    ["Cannot change in combat"]        = "Le jeu refuse ce changement pendant le combat.",

    ["Always show nameplates"]         = "Toujours afficher les barres d'infos",
    ["Always show nameplates tip"] =
        "Garde les barres d'infos affichées au lieu de ne les montrer qu'en combat.",
    ["Enemy nameplates"]               = "Unités ennemies",
    ["Enemy nameplates tip"]           = "Barres d'infos sur les unités hostiles.",
    ["Enemy minions"]                  = "Serviteurs ennemis",
    ["Enemy minions tip"]              = "Familiers, gardiens et totems du camp adverse.",
    ["Enemy minor units"]              = "Unités mineures ennemies",
    ["Enemy minor units tip"]          = "Bestioles et autres unités sans presque aucun point de vie.",
    ["Friendly player nameplates"]     = "Personnages-joueurs alliés",
    ["Friendly player nameplates tip"] = "Barres d'infos sur les joueurs de votre camp.",
    ["Friendly NPC nameplates"]        = "PNJ amicaux",
    ["Friendly NPC nameplates tip"] =
        "Barres d'infos sur les donneurs de quête, les marchands et les autres PNJ amicaux.",
    ["Nameplate distance"]             = "Distance",
    ["Nameplate distance tip"]         = "Jusqu'où une barre d'infos est encore dessinée, en mètres.",
    ["Vertical overlap"]               = "Espacement vertical",
    ["Horizontal overlap"]             = "Espacement horizontal",
    ["Overlap tip"] =
        "Place que chaque barre d'infos garde autour d'elle avant que le jeu ne "
        .. "pousse la suivante. Plus haut les écarte, plus bas les resserre.",
    ["Spacing and distance"]           = "Espacement et distance",

    ["Nameplate style"]                = "Style",
    ["Nameplate style tip"] =
        "L'allure générale que le jeu donne à ses barres d'infos. Même liste que "
        .. "dans le menu du jeu, et même réglage.",
    ["Style modern"]                   = "Moderne",
    ["Style thin"]                     = "Barres fines",
    ["Style block"]                    = "Barres en bloc",
    ["Style health focus"]             = "Barre de vie large",
    ["Style cast focus"]               = "Sorts en bloc",
    ["Style legacy"]                   = "Rouge traditionnel",

    ["Stacking"]                       = "Superposition",
    ["Stacking tip"] =
        "Des barres d'infos superposées ne se recouvrent jamais ; sans "
        .. "superposition, chacune reste au-dessus de l'unité à qui elle appartient.",
    ["Stack enemy nameplates"]         = "Unités ennemies",
    ["Stack friendly nameplates"]      = "Unités amicales",
    ["Health bar info"]                = "Informations de barre de vie",
    ["Health bar info tip"]            = "Ce que le jeu écrit sur la barre de vie d'une barre d'infos.",
    ["Health percentage"]              = "Pourcentage de points de vie",
    ["Health value"]                   = "Points de vie",
    ["Rarity icon"]                    = "Icône de rareté",
    ["Cast bar info"]                  = "Informations de barre de sorts",
    ["Cast bar info tip"]              = "Ce que le jeu écrit sur la barre de sorts d'une barre d'infos.",
    ["Spell name"]                     = "Nom du sort",
    ["Spell icon"]                     = "Icône du sort",
    ["Spell target"]                   = "Cible du sort",
    ["Highlight important casts"]      = "Mettre en avant les sorts importants",
    ["Highlight casts on you"]         = "Mettre en avant les sorts qui vous visent",

    ["Threat display"]                 = "Affichage de menace",
    ["Threat display tip"] =
        "La façon dont le jeu montre lui-même la menace. Indépendant des couleurs "
        .. "de menace de l'addon.",
    ["Threat progressive"]             = "Progressive",
    ["Threat flash"]                   = "Clignotement",
    ["Threat health bar color"]        = "Couleur de la barre de vie",

    ["Enemy NPC auras"]                = "Auras des PNJ adversaires",
    ["Enemy player auras"]             = "Auras des joueurs adverses",
    ["Friendly player auras"]          = "Auras des joueurs alliés",
    ["Health bar size"]                = "Barre de vie",
    ["Cast bar size"]                  = "Barre des sorts",
    ["Preview mode"]                   = "Mode aperçu",
    ["Show cast bar"]                  = "Montrer ce qui n'apparaît qu'en combat",
    ["Show cast bar tip"] =
        "Une barre de sorts ne se montre que pendant une incantation, une aura "
        .. "que lorsqu'un sort la pose, un marqueur que sur une unité marquée : "
        .. "rien de tout cela ne se règle en l'attendant. Ce mode maintient la "
        .. "vraie barre de sorts affichée et en cours, ajoute des auras "
        .. "d'exemple **dans les rangées que vous avez prises** — celles qui "
        .. "restent au jeu n'en reçoivent pas, elles n'apparaîtront jamais là — "
        .. "et montre le marqueur avec un crâne d'exemple. Pensez à l'éteindre.",
    ["Sample cast"]                    = "Incantation",
    ["Resize cast text"]               = "Régler la taille du texte des sorts",
    ["Resize cast text tip"] =
        "Porte sur ce que la barre de sorts écrit : le nom du sort, et sa cible "
        .. "quand le jeu l'affiche.",
    ["Cast text size"]                 = "Taille du texte des sorts (pixels)",
    ["Cast text size tip"] =
        "Distincte du texte ci-dessus, parce que le jeu lui-même écrit plus petit "
        .. "sur une barre de sorts que sur une barre de vie.",
    ["Taken over by the addon"] =
        "Bshamel UI règle la taille en pixels. Éteignez-le pour récupérer ce "
        .. "réglage.",
    ["Auras taken over"] =
        "Bshamel UI affiche cette catégorie. Décochez « Prendre cette rangée » "
        .. "dans la rangée qui la remplace pour la récupérer — elle est éteinte, "
        .. "pas perdue.",

    ["Auras and marker"]               = "Auras et marqueur",
    ["Auras paused"]                   = "En pause, le temps de régler la taille et les décalages.",
    ["Auras paused notice"] =
        "En pause : les rangées et le marqueur ne suivent pas encore leurs "
        .. "curseurs assez fidèlement. Rien dans cette section n'agit pour le "
        .. "moment.",
    ["Auras notice"] =
        "L'addon affiche une seule rangée à lui : les contrôles. La prendre "
        .. "éteint les contrôles du jeu — deux rangées sur une plaque, ce sont "
        .. "deux fois les mêmes icônes — et grise cette case-là dans la moitié "
        .. "gauche de cette page. Tout le reste lui appartient et n'est pas "
        .. "touché : il affiche désormais les améliorations et les "
        .. "affaiblissements mieux que l'addon ne le pouvait, et il lit ce "
        .. "qu'il refuse de laisser lire à un addon.",
    ["Own auras"]                      = "Régler les auras",
    ["Own auras tip"] =
        "Ouvre la section. Rien ne change tant que la rangée n'est pas prise "
        .. "ci-dessous. Ce que le mode aperçu montre est exactement cette "
        .. "rangée : même code, même place, même taille. Chaque image est un "
        .. "asset du jeu.",
    ["Take over this row"]             = "Prendre cette rangée",
    ["Take over crowd control tip"] =
        "Cochée, l'addon affiche cette rangée et le jeu cesse de montrer les "
        .. "contrôles sur les plaques adverses. Décochée, le jeu garde ses "
        .. "propres icônes de contrôles, là où il les met.",
    ["Crowd control auras"]            = "Contrôles — de tous les joueurs",
    ["Crowd control auras notice"] =
        "À droite de la barre de vie. Un mob mouton est mouton, peu importe qui "
        .. "l'a lancé.",
    ["Aura shaded"]                    = "Contour de l'addon sur les icônes",
    ["Aura shaded tip"] =
        "Cochée, une icône de cette rangée porte le contour habituel de "
        .. "l'addon — la bordure de sort du jeu, aux coins en biseau, teintée "
        .. "pour dire ce qu'est l'aura. Décochée, elle garde le liseré carré "
        .. "d'un pixel, de la même couleur.",
    ["Own aura size"]                  = "Taille des icônes (pixels)",
    ["Own aura size tip"]              = "Côté d'une icône d'aura de cette rangée.",
    ["Aura offset X"]                  = "Décalage X (pixels)",
    ["Aura offset Y"]                  = "Décalage Y (pixels)",
    ["Aura offset tip"]                = "Écarte cette rangée de son ancrage sur la plaque.",
    ["Aura max"]                       = "Icônes au plus",
    ["Aura max tip"] =
        "Combien d'icônes cette rangée affiche au maximum. Elle se remplit dans "
        .. "l'ordre où le jeu répond, et rien ne la trie — ce qui trierait est "
        .. "caché sur un adversaire. Un plafond bas est donc le moyen de garder "
        .. "la rangée lisible plutôt que complète.",
    ["Aura gap"]                       = "Espacement (pixels)",
    ["Aura gap tip"]                   = "Écart entre deux icônes de cette rangée.",
    ["Aura timer size"]                = "Corps du décompte",
    ["Aura timer size tip"] =
        "Taille du temps restant écrit sur les icônes de cette rangée. Chaque "
        .. "rangée a le sien : une entrave se lit à la seconde près, un "
        .. "affaiblissement qu'on entretient se lit du coin de l'œil.",
    ["Auras tip"]                      = "Les auras que le jeu affiche au-dessus de ces barres d'infos.",
    ["Buffs"]                          = "Améliorations",
    ["Debuffs"]                        = "Affaiblissements",
    ["Crowd control"]                  = "Contrôle de foule",
    ["Loss of control"]                = "Perte de contrôle",
    ["Nameplate size"]                 = "Taille des barres de nom",
    ["Nameplate size tip"] =
        "Le réglage de taille du jeu, en cinq crans. À distinguer de la largeur "
        .. "et de la hauteur en pixels plus bas, qui affinent ce que celui-ci pose.",
    ["Debuff spacing"]                 = "Espacement des affaiblissements",
    ["Debuff spacing tip"] =
        "Écart vertical seulement, entre la rangée d'affaiblissements et ce qui "
        .. "est au-dessus. S'applique aux trois rangées, pas seulement à la "
        .. "dernière.",

    ["Simplified nameplates"]          = "Barres d'infos simplifiées",
    ["Simplified nameplates notice"] =
        "Une barre d'infos simplifiée se réduit à un nom : ni barre, ni icônes. "
        .. "Choisissez quelles unités en reçoivent une.",
    ["Simplified nameplates tip"]      = "Affichée sous forme de nom seul.",
    ["Minions"]                        = "Serviteurs",
    ["Minor units"]                    = "Unités mineures",
    ["Friendly players"]               = "Joueurs alliés",
    ["Friendly NPCs"]                  = "PNJ amicaux",
    ["Show off-screen nameplates"]     = "Unités hors écran",
    ["Show off-screen nameplates tip"] =
        "Définit si les barres d'infos des unités hors écran sont affichées.",
    ["Friendly minions"]               = "Serviteurs alliés",
    ["Friendly minions tip"] =
        "Familiers, gardiens et totems appartenant aux joueurs de votre camp.",

    ["Resize cast bar"]                = "Régler la taille de la barre de sorts",
    ["Resize cast bar tip"] =
        "Même traitement que la barre de vie, sur son propre interrupteur : "
        .. "l'éteindre rend la barre de sorts sans toucher au reste.",
    ["Cast bar height"]                = "Hauteur de la barre de sorts (pixels)",
    ["Cast bar height tip"] =
        "Épaisseur de la barre de sorts. Le jeu la fait plus fine que la barre de vie.",

    ["Resize nameplates"]              = "Régler la taille",
    ["Resize nameplates tip"] =
        "Fixe la taille des barres d'infos en pixels tant que c'est allumé, et "
        .. "les rend au jeu quand on l'éteint.",
    ["Nameplate width"]                = "Largeur (pixels)",
    ["Nameplate width tip"] =
        "Largeur de la plaque. La barre de vie s'étire pour la remplir. Le jeu "
        .. "utilise 128.",
    ["Resize nameplate text"]          = "Régler la taille du texte",
    ["Resize nameplate text tip"] =
        "Une seule taille pour tout le texte d'une barre d'infos. En l'éteignant, "
        .. "chacun retrouve le corps que le jeu lui donnait.",
    ["Nameplate text size"]            = "Taille du texte (pixels)",
    ["Nameplate text size tip"] =
        "Le nom, le niveau, les points de vie, leur pourcentage et le sort en "
        .. "cours, d'un seul coup. La police et son contour ne sont pas touchés — "
        .. "seul le corps change.",
    ["Nameplate height"]               = "Hauteur de la barre (pixels)",
    ["Nameplate height tip"] =
        "Épaisseur de la barre de vie. Le jeu utilise 11. Le nom et les icônes "
        .. "gardent leur taille — ils ne font pas partie de la barre.",

    ["Set the bar texture"]            = "Régler la texture des barres",
    ["Set the bar texture tip"] =
        "Remplace le remplissage des barres de vie adverses. La cible et les "
        .. "autres ont chacune leur choix ci-dessous. En l'éteignant, chaque "
        .. "barre retrouve son image.",
    ["Others bar texture"]             = "Les autres — texture",
    ["Others bar texture tip"]         = "Remplissage des plaques de ce que vous ne ciblez pas.",
    ["Target bar texture"]             = "Cible — texture",
    ["Target bar texture tip"]         = "Remplissage de la plaque de votre cible.",
    ["Texture vivid"]                  = "Couleur vive",
    ["Texture standard"]               = "Couleur standard",

    ["Raid marker"]                    = "Marqueur de ciblage",
    ["Place raid marker"]              = "Placer le marqueur soi-même",
    ["Place raid marker tip"] =
        "Pose l'icône de ciblage sur le coin haut-droit de la barre de vie, à la "
        .. "taille et au décalage choisis.",
    ["Marker size"]                    = "Taille du marqueur",
    ["Marker size tip"]                = "Côté de l'icône, en pixels.",
    ["Marker offset X"]                = "Décalage du marqueur, horizontal",
    ["Marker offset Y"]                = "Décalage du marqueur, vertical",
    ["Marker offset tip"] =
        "Écart au coin haut-droit de la barre de vie. À zéro, l'icône est centrée "
        .. "sur ce coin.",

    ["Visibility"]                     = "Visibilité",
    ["Visibility notice"] =
        "Trois états, et une barre de nom est toujours dans exactement l'un des "
        .. "trois : c'est votre cible, c'en est une autre, ou elle est derrière "
        .. "quelque chose. Chaque état a sa propre opacité.",
    ["Tune visibility"]                = "Régler l'opacité",
    ["Tune visibility tip"] =
        "Décide de la visibilité de chaque barre de nom tant que c'est allumé, "
        .. "et rend les plaques au jeu quand on l'éteint.",
    ["Target opacity"]                 = "Cible — opacité",
    ["Target opacity tip"]             = "À quel point la plaque de votre cible est visible.",
    ["Others opacity"]                 = "Les autres — opacité",
    ["Others opacity tip"]             = "À quel point les plaques de ce que vous ne ciblez pas sont visibles.",
    ["Occluded opacity"]               = "Hors de vue — opacité",
    ["Occluded opacity tip"] =
        "À quel point une plaque est visible quand son porteur est derrière un "
        .. "mur ou un pilier.",

    ["Enemy colors"]                   = "Couleurs des adversaires",
    ["Enemy colors notice"] =
        "C'est l'unité qui décide, pas la zone : un PNJ ennemi prend les couleurs "
        .. "par nature ci-dessous, un joueur adverse prend celle de sa classe si "
        .. "vous le demandez. Une créature ordinaire est laissée telle quelle — "
        .. "seuls les rangs que le jeu déclare sont repeints.",
    ["PvP class colors"]               = "Couleurs de classe sur les joueurs adverses",
    ["PvP class colors tip"] =
        "La barre de vie d'un joueur adverse prend la couleur de sa classe, où "
        .. "que vous le croisiez.",
    ["Color enemies by kind"]          = "Colorier les adversaires par nature",
    ["Color enemies by kind tip"] =
        "La rareté d'abord, ce que fait la créature ensuite : un rare qui incante "
        .. "reste colorié en rare.",
    ["NPC colors scope"]               = "Où l'appliquer",
    ["NPC colors scope tip"] =
        "Partout, ou seulement en donjon et en raid — dehors, les couleurs du "
        .. "jeu reprennent la main sans rien décocher.",
    ["Everywhere"]                     = "Partout",
    ["Instances only"]                 = "En instance uniquement",
    ["Boss color"]                     = "Boss",
    ["Boss color tip"] =
        "Boss de zone, et toute élite à deux niveaux ou plus au-dessus de vous.",
    ["Miniboss color"]                 = "Miniboss",
    ["Miniboss color tip"]             = "Une élite à exactement un niveau au-dessus de vous.",
    ["Caster color"]                   = "Élite caster",
    ["Caster color tip"] =
        "Le trash de donjon et de raid qui incante. Seules les élites sont "
        .. "classées ainsi : dehors, la classe d'une créature ne veut rien dire.",
    ["Melee color"]                    = "Élite mêlée",
    ["Melee color tip"]                = "Le trash de donjon et de raid qui n'incante pas.",
    ["Rare color"]                     = "Rare",
    ["Rare color tip"]                 = "Dragon argenté, sans le liseré d'élite.",
    ["Rare elite color"]               = "Rare-élite",
    ["Rare elite color tip"]           = "Dragon argenté avec le liseré d'élite.",


    ["Threat"]                         = "Menace",
    ["Threat notice"] =
        "Quand l'aggro est là où elle doit être, ce sont les couleurs par nature "
        .. "ci-dessus qui colorent la barre — pas de couleur « tout va bien ». "
        .. "La menace n'a que deux alertes, lues selon votre rôle.",
    ["Color by threat"]                = "Colorier selon la menace",
    ["Color by threat tip"] =
        "Passe la barre à la couleur d'alerte dès que l'aggro bouge vers la "
        .. "mauvaise personne — perdue si vous êtes tank, prise si vous ne "
        .. "l'êtes pas.",
    ["Threat shifting"]                = "Aggro en train de basculer (selon le rôle)",
    ["Threat shifting tip"] =
        "Tank : elle vous échappe, ou vous la reprenez sans l'avoir assurée. "
        .. "DPS ou soigneur : vous montez et allez la prendre.",
    ["Threat wrong"]                   = "Aggro prise ou perdue (selon le rôle)",
    ["Threat wrong tip"] =
        "Tank : vous l'avez perdue. DPS ou soigneur : vous l'avez prise.",

    ["Allied names only"]              = "Afficher uniquement le nom pour les alliés",
    ["Allied names only tip"] =
        "Les joueurs alliés n'ont qu'un nom, sans barre de vie. La leur est déjà "
        .. "sur les cadres de groupe.",
    ["Resize ally names"]              = "Agrandir le nom des alliés",
    ["Resize ally names tip"] =
        "Le nom des joueurs alliés prend la taille ci-dessous. Hors instance "
        .. "uniquement : le jeu verrouille les plaques alliées en donjon et en "
        .. "raid.",
    ["Ally name size"]                 = "Taille du nom allié (12 par défaut)",
    ["Allies"]                         = "Alliés",
    ["Class colored ally names"]       = "Noms aux couleurs de classe",
    ["Class colored ally names tip"] =
        "Les noms des joueurs alliés prennent la couleur de leur classe, y compris quand "
        .. "leur plaque est réduite à son nom. Décochée, le jeu les colore comme il "
        .. "l'entend — en vert, le plus souvent. Le nom d'un adversaire garde toujours la "
        .. "couleur de sa classe : là, c'est la classe qui est l'information.",
    ["Aura scale"]                     = "Taille des auras",
    ["Aura scale tip"] =
        "Taille des icônes d'aura, en pourcentage de celle du jeu.",

    -- Diagnostic `/bui auras` : les libellés de prose seulement — les noms de
    -- filtres et de champs sont ceux de l'API, ils ne se traduisent pas.
    ["Aura diagnostic"]                = "Diagnostic des barres d'infos — plaque de la cible",
    ["Aura diagnostic needs target"] =
        "Ciblez d'abord quelque chose : le diagnostic lit la plaque de la cible.",
    ["No nameplate for target"]        = "La cible n'a pas de plaque à l'écran.",
    ["Refused"]                        = "refusé",
    ["Secret"]                         = "secret",
    ["Control"]                        = "témoin",
    ["Tokens"]                         = "jetons",
    ["Aura diagnostic unavailable"]    = "Le module Barres d'infos n'est pas actif.",

    -- Diagnostic `/bui glow` : la prose seulement — les noms de textures sont
    -- ceux du client, ils ne se traduisent pas.
    ["Glow diagnostic"] =
        "Diagnostic du mode sombre : survolez le bouton maintenant. Ses textures "
        .. "s'écrivent dans trois secondes, et celles que l'addon a assombries sont "
        .. "signalées.",
    ["Glow diagnostic nothing"]        = "Il n'y avait rien sous le curseur.",
    ["Glow diagnostic darkened"]       = "assombrie par l'addon",

    -- Ressource de classe (Modules/ClassResource.lua)
    ["Class resource"]                 = "Ressource de classe",
    ["Class resource notice"] =
        "Une case par point de la ressource que compte votre spécialisation : points de "
        .. "combo, puissance sacrée, chi, fragments d'âme, charges des arcanes, essence, "
        .. "runes ou cumuls d'Arme-tempête. La rangée choisit la bonne quand vous changez "
        .. "de spécialisation, et reste cachée sur un personnage qui n'en a aucune.",
    ["Show resource bar"]              = "Afficher la ressource de classe",
    ["Show resource bar tip"] =
        "Ajoute une rangée de cases que vous placez vous-même. Elle ne remplace rien : le "
        .. "jeu continue d'afficher sa propre ressource sous le personnage.",
    ["Resource preview"]               = "Aperçu",
    ["Resource preview tip"] =
        "Remplit la rangée toute seule, case après case : vous la placez et vous voyez le "
        .. "changement de teinte se produire, sans attendre un combat.",
    ["Lock resource bar"]              = "Verrouiller la position",
    ["Lock resource bar tip"]          = "La rangée ne se déplace plus à la souris.",

    ["Resource shape"]                 = "Forme",
    ["Resource cell width"]            = "Largeur d'une case",
    ["Resource cell width tip"]        = "Largeur d'une seule case.",
    ["Resource cell height"]           = "Hauteur d'une case",
    ["Resource cell height tip"]       = "Hauteur d'une seule case.",
    ["Resource cell gap"]              = "Écart entre les cases",
    ["Resource cell gap tip"] =
        "Espace entre deux cases. À zéro elles se touchent, séparées par leur seul liseré.",
    ["Resource cell count"]            = "Nombre de cases",
    ["Resource cell count tip"] =
        "Combien de cases la rangée compte, quel que soit le nombre de points de la "
        .. "ressource. Au-delà, elle **repart de zéro** dans les mêmes cases au lieu de "
        .. "s'allonger : à cinq, les dix cumuls d'Arme-tempête tiennent dans cinq grandes "
        .. "cases plutôt que dix petites, au même endroit. Zéro donne une case par point. "
        .. "Une rangée pleine veut alors dire cinq points ou dix : c'est le changement de "
        .. "couleur qui le dit, et le nombre au milieu si vous l'affichez.",
    ["Resource count"]                 = "Afficher le nombre",
    ["Resource count tip"]             = "Écrit le compte courant au milieu de la rangée.",
    ["Hide empty resource"]            = "Masquer quand c'est vide",
    ["Hide empty resource tip"] =
        "La rangée disparaît tant que vous n'avez rien et revient au premier point. "
        .. "L'aperçu la garde visible dans tous les cas.",

    ["Resource colours"]               = "Couleurs",
    ["Resource colour source"]         = "Couleur des cases pleines",
    ["Resource colour source tip"]     = "D'où vient la teinte d'une case pleine.",
    ["Game resource colour"]           = "Celle du jeu",
    ["Class colour"]                   = "Celle de la classe",
    ["Custom colour"]                  = "La vôtre",
    ["Resource fill colour"]           = "Teinte choisie",
    ["Resource fill colour tip"]       = "Couleur d'une case pleine.",
    ["Resource fill colour needs custom"] =
        "Utilisée seulement quand la couleur des cases pleines est « La vôtre ».",
    ["Resource threshold"]             = "Changer de couleur à partir de",
    ["Resource threshold tip"] =
        "À partir de ce nombre de points, toute la rangée prend la teinte ci-dessous. "
        .. "Zéro éteint le mécanisme.",
    ["Resource threshold colour"]      = "Couleur au-delà du palier",
    ["Resource threshold colour tip"] =
        "Teinte que prend la rangée une fois le nombre correspondant atteint.",
    ["Resource threshold 2"]           = "Deuxième palier à partir de",
    ["Resource threshold 2 tip"] =
        "Un second changement de couleur, plus haut que le premier. C'est toujours le "
        .. "palier le plus haut atteint qui l'emporte : il écrase celui du dessus.",
    ["Resource threshold colour 2"]    = "Couleur du deuxième palier",
    ["Resource threshold 3"]           = "Troisième palier à partir de",
    ["Resource threshold 3 tip"] =
        "Le dernier changement de couleur. Comme les précédents, il écrase ceux qui sont "
        .. "en dessous de lui.",
    ["Resource threshold colour 3"]    = "Couleur du troisième palier",
    ["Resource threshold needs previous"] =
        "Posez d'abord le palier du dessus.",
    ["Resource threshold glow"]        = "Afficher un effet brillant",
    ["Resource threshold glow tip"] =
        "Pose sur les cases pleines la lueur que le jeu met sur un bouton d'action quand "
        .. "un sort devient utilisable — la même exactement. Elle a son propre seuil et "
        .. "ne suit aucun palier de couleur.",
    ["Resource glow threshold"]        = "Effet brillant à partir de",
    ["Resource glow threshold tip"] =
        "Nombre de points à partir duquel les cases brillent.",
    ["Resource threshold colour needs threshold"] =
        "Choisissez d'abord un palier.",
})
