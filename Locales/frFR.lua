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
    ["Game"]                    = "Jeu",
    ["Interface"]               = true,
    ["QoL"]                     = true,
    -- « MM+ » et non « Mythique+ » : c'est ainsi que les joueurs francophones
    -- l'écrivent, et la colonne est étroite.
    ["Mythic+ / Raid"]          = "MM+ / Raid",
    ["Search..."]               = "Rechercher...",
    ["Reset this page"]         = "Réinitialiser cette page",
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
    ["Enable dark mode"]               = "Activer le mode sombre",
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
    ["Camera"]                         = "Caméra",
    ["Max camera distance"]            = "Augmenter la distance maximale de la caméra",
    ["Max camera distance tip"] =
        "Permet à la caméra de reculer plus loin que ce que le client autorise par défaut.",
    ["Camera zoom factor"]             = "Facteur de zoom",
    ["Camera zoom factor tip"] =
        "Multiplie la limite de recul du client. 2,9 est le maximum qu'il accepte.",
    ["Game menu"]                      = "Menu du jeu",
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
    ["Auction current expansion"]      = "Hôtel des ventes : extension actuelle uniquement",
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
        "Affiche le niveau d'objet de chaque pièce équipée sur son emplacement, mise à l'échelle comprise.",
    ["Show upgrade level"]             = "Afficher le niveau d'amélioration",
    ["Show upgrade level tip"]         = "Affiche le rang d'amélioration de chaque pièce équipée.",
    ["Warn partial upgrade"]           = "Signaler les améliorations incomplètes",
    ["Warn partial upgrade tip"] =
        "Passe le rang en orange tant que la pièce n'est pas au maximum. Décoché, tous les rangs restent verts.",
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
    ["Show void core"]                 = "Afficher le noyau du vide",
    ["Show void core tip"] =
        "Signale les armes et les bijoux qui n'ont pas encore reçu la forge du vide ascendant.",
    ["Enchant badge"]                  = "Enchantement",
    ["Gem badge"]                      = "Gemme",
    ["Void core badge"]                = "Noyau du vide",

    -- Relevé en jeu sur une arme portant un noyau. Voir enUS pour ce que cette
    -- clé décide.
    ["Void core marker"]               = "Forge du vide ascendant",

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
    ["Specialization"]                 = "Spécialisation",
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

    -- Module Minimap
    ["Minimap"]                        = "Minicarte",
    ["Buttons"]                        = "Boutons",
    ["Minimap button"]                 = "Afficher le bouton BshamelUI",
    ["Minimap button tip"] =
        "Clic gauche : liste d'addons\n"
        .. "Clic droit : options\n"
        .. "Glisser : déplacer autour de la minicarte",
    ["Addon buttons empty"]            = "Aucune icône d'addon à afficher.",
    ["Group addon buttons"]            = "Regrouper les boutons d'addons",
    ["Group addon buttons tip"] =
        "Range le bouton de minicarte de chaque autre addon dans un tiroir qui s'ouvre à côté "
        .. "du bouton BshamelUI, au clic gauche. Les boutons du jeu ne sont pas touchés, et "
        .. "éteindre le réglage remet chaque bouton exactement où il était. Demande le bouton "
        .. "BshamelUI : c'est lui qui ouvre le tiroir.",
    ["Teleports"]                      = "Téléportations",
    ["Teleport menu"]                  = "Afficher un bouton de téléportation",
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
    ["Bags"]                           = "Sacs",
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

    -- Module GroupFinder
    ["Group finder"]                   = "Recherche de groupe",
    ["Signing up"]                     = "Inscription",
    ["Keep signup note"]               = "Conserver la note d'inscription",
    ["Keep signup note tip"] =
        "Retient ce que vous écrivez dans la note de candidature et le remet la fois suivante.",
    ["Auto role check"]                = "Valider les vérifications de rôle",
    ["Auto role check tip"] =
        "Répond automatiquement à la vérification des rôles, avec ceux que vous aviez déjà choisis.",
    -- Module RaidTools
    ["Raid tools"]                     = "Outils de raid",
    ["Combat"]                         = true,
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

    ["Group tools"]                    = "Outils de groupe",
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
    ["Hide raid manager"]              = "Masquer le panneau de contrôle du jeu",
    ["Hide raid manager tip"] =
        "Masque l'onglet que le jeu colle contre le bord gauche de l'écran en raid.",
    ["Group tools notice"] =
        "Le panneau n'apparaît pas, ne disparaît pas et ne se redimensionne pas en combat : le jeu "
        .. "refuse de montrer, de cacher ou de retailler un bouton de marqueur pendant qu'on se "
        .. "bat. Il suit de nouveau le réglage dès la fin du combat.",
    ["Need lead"]                      = "Il faut être chef ou promu pour ça.",

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
    ["Move windows"]                   = "Déplacer les fenêtres",
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
    ["Scale windows"]                  = "Redimensionner à Ctrl + molette",
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
})
