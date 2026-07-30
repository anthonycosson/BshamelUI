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
    ["Coming soon notice"]      = "Ce module n'est pas encore écrit. Les réglages ci-dessous montrent ce qu'il proposera.",
    ["Coming soon tooltip"]     = "Pas encore disponible.",

    -- Module Quest
    ["Quest"]                   = "Quête",
    ["Automation"]              = "Automatisation",
    ["Auto-accept quests"]      = "Accepter automatiquement les quêtes",
    ["Auto-accept quests tip"]  = "Accepte automatiquement les quêtes proposées par les PNJ et les objets de quête.",
    ["Auto-turn-in quests"]     = "Rendre automatiquement les quêtes",
    ["Auto-turn-in quests tip"] = "Termine la quête et prend la récompense automatiquement lorsqu'il n'y en a qu'une.",
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
    ["Auto-repair"]                    = "Réparation automatique",
    ["Auto-repair tip"]                = "Répare à chaque marchand, en puisant d'abord dans les fonds de guilde, puis dans votre bourse.",
    ["Auction current expansion"]      = "Hôtel des ventes : extension actuelle uniquement",
    ["Auction current expansion tip"]  = "Limite la navigation de l'hôtel des ventes aux objets de l'extension actuelle.",
    ["Announcements"]                  = "Annonces",
    ["Announce group deaths"]          = "Annoncer les morts du groupe",
    ["Announce group deaths tip"]      = "Publie un message dans le chat de groupe quand un membre du groupe ou du raid meurt.",
    ["Death sound alert"]              = "Alerte sonore à la mort",
    ["Death sound alert tip"]          = "Ajoute une alerte sonore à l'annonce des morts.",
    ["Annoyances"]                     = "Nuisances",
    ["Skip cinematics"]                = "Passer les cinématiques",
    ["Skip cinematics tip"]            = "Passe les cinématiques et les vidéos du jeu.",
    ["Hide talking heads"]             = "Masquer les têtes parlantes",
    ["Hide talking heads tip"]         = "Masque le cadre de tête parlante qui apparaît pendant les quêtes et les donjons.",
    ["Hide Lua errors"]                = "Masquer les erreurs Lua",
    ["Hide Lua errors tip"]            = "Supprime la fenêtre d'erreur. Les erreurs restent transmises aux gestionnaires d'erreurs.",

    -- Module Character
    ["Character sheet"]                = "Fiche de personnage",
    ["Item details"]                   = "Détails des objets",
    ["Show upgrade level"]             = "Afficher le niveau d'amélioration",
    ["Show upgrade level tip"]         = "Affiche la voie et le rang d'amélioration sur chaque objet équipé.",
    ["Show enchants"]                  = "Afficher les enchantements",
    ["Show enchants tip"]              = "Affiche l'enchantement de chaque emplacement qui peut en recevoir un, et signale ceux qui n'en ont pas.",
    ["Show gems"]                      = "Afficher les gemmes",
    ["Show gems tip"]                  = "Affiche les gemmes serties et signale les châsses vides.",
    ["Show void core"]                 = "Afficher le noyau du vide",
    ["Show void core tip"]             = "Affiche le noyau du vide monté sur chaque objet qui peut en recevoir un.",

    -- Modules ActionBars et UnitFrames
    ["Action bars"]                    = "Barres d'action",
    ["Unit frames"]                    = "Cadres d'unités",
    ["Appearance"]                     = "Apparence",
    ["Dark mode"]                      = "Mode sombre",
    ["Dark mode tip"]                  = "Assombrit l'habillage pour qu'il se fonde dans l'écran.",
    ["Class-colored health"]           = "Barres de vie aux couleurs de classe",
    ["Class-colored health tip"]       = "Colore chaque barre de vie selon la classe de l'unité.",

    -- Module Chat
    ["Chat"]                           = true,
    ["History"]                        = "Historique",
    ["Keep history"]                   = "Conserver l'historique après un rechargement",
    ["Keep history tip"]               = "Restaure les derniers messages après un /reload ou une reconnexion.",
    ["Drag to resize"]                 = "Ajuster la hauteur à la volée",
    ["Drag to resize tip"]             = "Ajoute une poignée pour changer la hauteur du chat sans passer par ses réglages.",

    -- Module Bags
    ["Bags"]                           = "Sacs",
    ["Merchants"]                      = "Marchands",
    ["Auto-sell junk"]                 = "Vendre automatiquement la camelote",
    ["Auto-sell junk tip"]             = "Vend les objets gris à chaque marchand.",
    ["Confirmations"]                  = true,
    ["Fill delete confirmation"]       = "Remplir la confirmation de destruction",
    ["Fill delete confirmation tip"]   = "Saisit le mot de confirmation à votre place quand la destruction d'un objet le demande.",
    ["Display"]                        = "Affichage",
    ["Show item level"]                = "Afficher le niveau d'objet",
    ["Show item level tip"]            = "Inscrit le niveau d'objet sur les icônes d'équipement dans les sacs.",

    -- Modules Keystones et RaidTools
    ["Keystones"]                      = "Clés mythiques",
    ["Answer keys request"]            = "Répondre à !keys dans le chat",
    ["Answer keys request tip"]        = "Répond avec votre clé quand quelqu'un tape !keys dans le chat de groupe ou de raid.",
    ["Raid tools"]                     = "Outils de raid",
    ["Combat"]                         = true,
    ["Battle res tracker"]             = "Suivi des résurrections de combat",
    ["Battle res tracker tip"]         = "Affiche le nombre de résurrections de combat restantes et le délai avant la suivante.",
    ["Ready check buffs"]              = "Contrôler les buffs au ready check",
    ["Ready check buffs tip"]          = "Signale qui n'a ni nourriture, ni flacon, ni buff de raid au lancement d'une vérification de disponibilité.",
    ["World markers"]                  = "Panneau de marqueurs au sol",
    ["World markers tip"]              = "Ouvre un panneau pour poser et retirer les marqueurs au sol.",
    ["Logging"]                        = "Journalisation",
    ["Auto combat logging"]            = "Journalisation automatique des combats",
    ["Auto combat logging tip"]        = "Lance la journalisation en entrant en raid ou en donjon mythique+, et la coupe en sortant.",
})
