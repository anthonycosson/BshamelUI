## 2.0.0 — 2026-09-19

### Ajouté
- **Bshamel UI se charge sur *World of Warcraft: Forever*** (bêta, interface
  16001). Le même addon, le même zip : dix-sept modules y chargent.
  Les barres d'infos, l'hôtel des ventes, les clés, les filtres de recherche de
  groupe, les téléportations, le chrono Mythique+, les ressources de classe,
  « BL et résurrection » et les emotes restent réservés à retail.
  - Mode sombre : l'emblème JcJ (y compris celui du joueur, que son rond
    recouvrait) et le rond du niveau des cadres d'unités de
    Forever gardent leurs couleurs, comme le crâne de niveau de ses barres
    d'infos.

  - Ressources de classe n'est pas proposé sur Forever. Le gestionnaire des
    temps de recharge y figure grisé, le temps de le vérifier sur la bêta.
  - **Suivi des buffs (en chantier)**, à la place de « BL et résurrection »
    sur Forever. On coche les lignes à suivre, un panneau les affiche : en
    vert quand on a le buff, en blanc quand il manque. Trois catégories, sans
    doublon : les buffs, nommés par ce qu'ils donnent (« Intelligence »,
    « Endurance »…) avec au survol le sort de classe ou l'objet de campement
    qui les donne, les
    consommables (nourriture, élixir, flacon) et l'arme (amélioration
    temporaire, où une arme de chaman ou un poison compte, et lunette). Au
    survol, d'où vient chaque source. Ce qui est mis de côté et les buffs
    mondiaux restent grisés sur la page. Relevé dans les tables de la bêta.
  - Nuisances : pas de têtes parlantes ni de découvertes de pierres d'accès à
    masquer sur Forever, les deux cases n'y sont pas proposées.
  - Quête : sur Forever, une ligne rouge sous l'acceptation automatique dit
    que les escortes qu'on prend soi-même ne sont pas acceptées — celles
    lancées par un membre du groupe le sont.
  - Fiche de personnage : pas de case « gemmes » ni « niveau d'amélioration »
    sur Forever, qui n'a ni châsses ni pistes d'amélioration. Les enchantements suivent les emplacements de Forever — cou, dos,
    poignets, mains, bouclier, objet tenu en main et arme à distance, pas les
    anneaux — et la ceinture n'est réclamée qu'aux ingénieurs. L'arme à
    distance a sa colonne comme les autres pièces.
  - Cadres d'unités : l'icône de spécialisation et le masquage de l'icône JcJ
    ne sont pas proposés sur Forever — le jeu pose déjà l'une, et n'a pas de
    prestige pour l'autre.

### Modifié
- **Réglages du jeu** : le relevé emporte aussi l'affichage du niveau des
  quêtes, réglé par personnage hors du panneau d'options.
- **Fiche de personnage** : le niveau d'objet du personnage s'intitule
  « Niveau d'objet », comme dans les caractéristiques du jeu, et la case des
  sacs parle des « équipements dans le sac ». Il est calculé à partir des
  pièces portées, au moment où on les change : il ne reste plus sur un
  équipement qu'on vient de ranger.
- **Cadres d'unités, lueur de combat** : la bande rouge qui pulse sur le nom du
  joueur pendant l'attaque automatique s'éteint aussi. Au repos, elle reste
  jaune.
- **Mode sombre, barre d'incantation** : seul le contour s'assombrit, le fond
  de la barre garde sa couleur — ce n'est plus un pavé noir.
- **Mode sombre, barres d'infos** : le liseré blanc de la cible et celui, orange,
  du focus s'assombrissent comme le contour des autres plaques.

### Interne
- **Sonde de compatibilité, en vue de *World of Warcraft: Forever*.**
  `dev/scripts/make-probe.sh` extrait du dépôt tout ce que l'addon demande au
  client — API, globales, cadres nommés par une chaîne, événements, CVars,
  templates, atlas — et `dev/probe/BshamelUI_Probe/` les pose à un client
  inconnu pour rendre un score par fichier. Rien de tout cela ne part chez un
  joueur : `.pkgmeta` exclut `dev/` du zip.
- **Un seul `.toc` pour les deux clients.** Le client de Forever porte
  l'interface de retail : les modules qui n'y ont pas de sens sont écartés par
  `[AllowLoadGameType standard]` sur leur ligne, sans aucune condition dans le
  code. Le constat et ses sources sont dans `dev/docs/FOREVER.md`.
- **Les scripts PowerShell du dépôt s'écrivent avec un BOM.** Windows
  PowerShell 5.1 lit un `.ps1` sans BOM comme de l'ANSI ; un tiret cadratin y
  devient un guillemet fermant et le script ne se parse plus. La règle est
  déclarée dans `.editorconfig` et `.gitattributes`.

