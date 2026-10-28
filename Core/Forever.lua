-- =========================================================================
--  Bshamel UI — Core/Forever.lua
--  Ce que *World of Warcraft: Forever* n'a pas, ou a autrement : les réglages
--  qu'il ne propose pas, les modules encore grisés, les avertissements qu'il
--  pose sous une option, et les faits de jeu qui diffèrent de retail (emplacements
--  enchantables).
--
--  Ce fichier n'est chargé que par le client de Forever : sa ligne du `.toc`
--  porte `[AllowLoadGameType camelot] [ExcludeLoadGameType standard]` — la
--  seconde parce que retail ne connaît pas `camelot`. C'est la règle « le client se choisit
--  dans le `.toc`, jamais dans un `if` » (CLAUDE.md §1), appliquée à une
--  option plutôt qu'à un fichier : un module qui charge sur les deux clients
--  garde son code intact, et c'est la présence de cette liste qui décide.
--
--  Une option retirée ici disparaît de sa page et de la recherche, et
--  `self:Get` rend son défaut quoi que la base contienne (voir
--  `Core/Module.lua`) — un réglage coché sur retail et partagé par profil ne
--  s'allume donc pas ici par la bande. Rien n'est effacé : la valeur reste en
--  base, intacte pour retail.
--
--  Chaque ligne dit pourquoi, parce que « pas sur Forever » n'est pas une
--  raison : c'est au jeu qu'il manque quelque chose, et c'est ça qu'on écrit.
-- =========================================================================

local _, ns = ...

--- Modules affichés mais **grisés** : présents dans la navigation, jamais
--- allumés — le traitement d'un module `preview`. Pour ce qui existe sur
--- Forever mais n'y a pas encore été vérifié.
---
--- Un module qui n'a pas de sens ici n'est pas listé : sa ligne du `.toc`
--- porte `[AllowLoadGameType standard]` et il n'apparaît pas du tout.
--- **Vide aujourd'hui**, et c'est le bon état : un module grisé est un aveu
--- provisoire, pas une catégorie. Le gestionnaire de temps de recharge y a
--- figuré le temps de le vérifier ; la bêta porte le même que retail, et le
--- module ne fait que relire la grille que le client vient de poser — il n'y
--- avait rien de propre à retail dedans.
ns.PREVIEW = {}

--- Les emplacements qui s'enchantent sur Forever — lus par
--- `Modules/Character.lua`, qui garde la liste de retail quand celle-ci
--- n'existe pas. Même syntaxe que la sienne.
---
--- Relevée dans les tables de la bêta (1.60.1.69913, 19 septembre 2026) : les
--- 366 sorts d'enchantement permanent, croisés avec les emplacements qu'ils
--- acceptent. Pas d'anneaux ; le cou, le dos, les poignets, les mains, le
--- bouclier, l'objet tenu en main et l'arme à distance en plus. La ceinture ne
--- reçoit que les bricolages d'ingénieur : on ne la réclame qu'à eux.
ns.ENCHANTABLE = {
    HeadSlot          = true,
    NeckSlot          = true,
    ShoulderSlot      = true,
    BackSlot          = true,
    ChestSlot         = true,
    WristSlot         = true,
    HandsSlot         = true,
    WaistSlot         = "engineer",
    LegsSlot          = true,
    FeetSlot          = true,
    MainHandSlot      = true,
    SecondaryHandSlot = true,
    RangedSlot        = true,
}

--- Avertissements posés sur la page d'un module, sur Forever seulement :
--- module -> liste de { after = clé de l'option, text = clé de locale }. La
--- ligne se pose juste sous l'option, **en rouge** (descripteur `alert`) : ce
--- sont des limites que le joueur doit voir sans aller les chercher, pas des
--- précisions d'infobulle.
ns.NOTES = {
    Quest = {
        -- Une escorte se lance à l'acceptation. L'accepter à la place du
        -- joueur, c'est la lancer avant que le groupe soit prêt : on ne le
        -- fera pas, et il faut le dire là où on coche.
        { after = "autoAccept", text = "Escort quests not auto-accepted" },
    },
}

--- module -> clé -> vrai
ns.WITHDRAWN = {
    Annoyances = {
        -- Ni têtes parlantes, ni pierres d'accès à découvrir.
        hideTalkingHead   = true,
        hideWaystoneToast = true,
    },
    Character = {
        -- Pas de châsses sur les objets de Forever.
        showGems         = true,
        -- Ni de pistes d'amélioration : pas de rang à afficher.
        showUpgradeLevel = true,
    },
    UnitFrames = {
        -- Le client pose déjà une icône sur le portrait.
        specIcon    = true,
        -- Pas de prestige ni d'icône d'honneur : l'emblème de faction est tout
        -- ce que les cadres portent, et c'est lui qui dit « JcJ activé ».
        hidePvpIcon = true,
    },
}
