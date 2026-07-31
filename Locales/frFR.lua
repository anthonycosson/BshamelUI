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
    ["Mythic+ / Raid"]          = "Mythique+ / Raid",
    ["Search..."]               = "Rechercher...",
    ["Reset this page"]         = "Réinitialiser cette page",
    ["Reset page confirm"]      = "Remettre tous les réglages de cette page à leur valeur par défaut ?",
    ["Yes"]                     = "Oui",
    ["Cancel"]                  = "Annuler",
    ["Open Bshamel UI"]         = "Ouvrir Bshamel UI",
    ["Cannot open in combat"]   = "La fenêtre d'options ne peut pas être ouverte en combat.",
    ["Module disabled tooltip"] = "Ce module est désactivé.",
    ["Version"]                 = true,

    -- Modules annoncés (Modules/Upcoming.lua)
    ["Coming soon"]             = "Bientôt disponible",
    ["Coming soon notice"] =
        "Ce module n'est pas encore écrit. Les réglages ci-dessous montrent ce qu'il proposera.",
    ["Coming soon tooltip"]     = "Pas encore disponible.",

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
    ["Minimap"]                        = "Minicarte",
    ["Minimap button"]                 = "Afficher le bouton BshamelUI",
    ["Minimap button tip"] =
        "Ajoute un bouton à côté de la minicarte. Un clic gauche ouvre cette fenêtre, "
        .. "un glisser le déplace autour.",
    ["Enable dark mode"]               = "Activer le mode sombre",
    ["Dark action bars tip"]           = "Boutons, bordures et habillage derrière chaque barre d'action.",
    ["Cast bar"]                       = "Barre d'incantation",
    ["Dark cast bar tip"]              = "Votre barre d'incantation et celle de votre cible.",
    ["Dark unit frames tip"] =
        "Cadres du joueur, du familier, de la cible, de la cible de la cible, du focus et des boss. "
        .. "Les cadres de groupe et de raid ne sont pas encore couverts.",
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
    ["Announcements"]                  = "Annonces",
    ["Announce group deaths"]          = "Annoncer les morts du groupe",
    ["Announce group deaths tip"] =
        "Publie un message dans le chat de groupe quand un membre du groupe ou du raid meurt.",
    ["Death sound alert"]              = "Alerte sonore à la mort",
    ["Death sound alert tip"]          = "Ajoute une alerte sonore à l'annonce des morts.",
    ["Annoyances"]                     = "Nuisances",
    ["Skip cinematics"]                = "Passer les cinématiques",
    ["Skip cinematics tip"]            = "Passe les cinématiques et les vidéos du jeu.",
    ["Hide talking heads"]             = "Masquer les têtes parlantes",
    ["Hide talking heads tip"] =
        "Masque le cadre de tête parlante qui apparaît pendant les quêtes et les donjons.",
    ["Hide Lua errors"]                = "Masquer les erreurs Lua",
    ["Hide Lua errors tip"] =
        "Supprime la fenêtre d'erreur. Les erreurs restent transmises aux gestionnaires d'erreurs.",

    -- Module Character
    ["Character sheet"]                = "Fiche de personnage",
    ["Item details"]                   = "Détails des objets",
    -- Voir enUS : le libellé est déclaré avec le module Bags.
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
    ["Unit frames"]                    = "Cadres d'unités",
    ["Appearance"]                     = "Apparence",
    ["Dark mode"]                      = "Mode sombre",
    ["Dark mode tip"]                  = "Assombrit l'habillage pour qu'il se fonde dans l'écran.",
    ["Dark mode moved"] =
        "Le mode sombre se règle désormais dans Général, avec un interrupteur par élément d'interface.",
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

    -- Module Bags
    ["Bags"]                           = "Sacs",
    ["Merchants"]                      = "Marchands",
    ["Auto-sell junk"]                 = "Vendre automatiquement la camelote",
    ["Auto-sell junk tip"]             = "Vend les objets gris à chaque marchand.",
    ["Confirmations"]                  = true,
    ["Fill delete confirmation"]       = "Remplir la confirmation de destruction",
    ["Fill delete confirmation tip"] =
        "Saisit le mot de confirmation à votre place quand la destruction d'un objet le demande.",
    ["Display"]                        = "Affichage",
    ["Show item level"]                = "Afficher le niveau d'objet",
    ["Show item level tip"]            = "Inscrit le niveau d'objet sur les icônes d'équipement dans les sacs.",

    -- Modules Keystones et RaidTools
    ["Keystones"]                      = "Clés mythiques",
    ["Answer keys request"]            = "Répondre à !keys dans le chat",
    ["Answer keys request tip"] =
        "Répond avec votre clé quand quelqu'un tape !keys dans le chat de groupe ou de raid.",
    ["Raid tools"]                     = "Outils de raid",
    ["Combat"]                         = true,
    ["Battle res tracker"]             = "Suivi des résurrections de combat",
    ["Battle res tracker tip"] =
        "Affiche le nombre de résurrections de combat restantes et le délai avant la suivante.",
    ["Ready check buffs"]              = "Contrôler les buffs au ready check",
    ["Ready check buffs tip"] =
        "Signale qui n'a ni nourriture, ni flacon, ni buff de raid "
        .. "au lancement d'une vérification de disponibilité.",
    ["World markers"]                  = "Panneau de marqueurs au sol",
    ["World markers tip"]              = "Ouvre un panneau pour poser et retirer les marqueurs au sol.",
    ["Logging"]                        = "Journalisation",
    ["Auto combat logging"]            = "Journalisation automatique des combats",
    ["Auto combat logging tip"] =
        "Lance la journalisation en entrant en raid ou en donjon mythique+, et la coupe en sortant.",

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
