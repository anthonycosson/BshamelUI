# Journal des modifications

## Non publié

### Ajouté
- **Chat** quitte l'avant-première, avec quatre conforts qui laissent le chat du
  jeu à sa place — ses onglets, son arrimage et ses filtres restent les siens :

  - l'**historique survit au rechargement**. Les dernières lignes de chaque
    fenêtre sont relues à la connexion, sous un séparateur qui dit où finit la
    session précédente. C'est ce qui a été **affiché** qui est conservé, pas les
    messages reçus : l'horodatage, les couleurs de classe et les filtres des
    autres addons sont donc restitués tels qu'on les avait lus. Éteindre le
    réglage efface ce qui avait été gardé ;
  - la **hauteur s'ajuste en tirant l'onglet** — « Général », « Journal de
    combat » — vers le haut ou vers le bas. Rien n'est ajouté à l'écran pour ça :
    l'onglet est la poignée que la souris a déjà sous elle, et la seule surface
    du chat qui ne serve pas à lire. Un simple clic continue de changer d'onglet,
    et la nouvelle taille est rangée par le jeu lui-même, donc elle survit sans
    l'addon ;
  - **une seule couleur pour le groupe** : groupe, chef de groupe, instance et
    raid prennent la couleur du chat de groupe. Une conversation avec les mêmes
    gens garde ainsi la même couleur qu'on soit dehors, en donjon ou en raid.
    Les avertissements de raid gardent la leur — ils sont faits pour couper la
    lecture. Les couleurs d'origine sont relevées avant d'être touchées et
    reposées si l'on éteint le réglage ;
  - **copier le chat** : un bouton discret dans le coin haut-droit de chaque
    fenêtre ouvre son contenu dans une fenêtre de texte, tout sélectionné, prêt
    pour un Ctrl+C. Les liens y gardent ce qu'ils affichaient, les icônes en
    ligne disparaissent.

- **Fiche de personnage** quitte l'avant-première. Le client affiche un niveau
  d'objet moyen et rien d'autre ; savoir quelle pièce traîne demandait de survoler
  seize emplacements l'un après l'autre.

  Le **niveau d'objet** se pose sur l'icône de la pièce, mise à l'échelle
  comprise — c'est celui que le personnage porte, pas celui qui est écrit dans
  le lien. À côté de la case — au-dessus pour les armes, qui n'ont pas de côté
  libre —, une colonne de **pastilles, une par ligne**, verte quand c'est fait et
  rouge quand ça ne l'est pas :

  - le **rang d'amélioration** (« 6/8 »), vert une fois au maximum et orange
    d'ici là. Le rang est le seul à échapper au rouge, et c'est voulu : une pièce
    améliorable *est* améliorée, elle ne l'est simplement pas à fond — dire
    « il manque quelque chose » serait faux. Un réglage permet de garder tous les
    rangs verts pour qui ne veut pas être relancé là-dessus ;
  - l'**enchantement**, sur les emplacements qui en acceptent un ;
  - les **gemmes** : vert quand toutes les châsses sont serties ;
  - le **noyau du vide**, sur les armes et les bijoux.

  C'est la couleur qui informe, le mot ne fait que nommer la question. Chacune
  des cinq lignes a son interrupteur, et toutes sont éteintes au départ.

  Le parti pris est d'**afficher aussi quand c'est bon** : ne signaler que les
  manques donne une fiche qui a l'air correcte dès qu'une lecture échoue,
  puisque l'absence de rouge ne se distingue plus de l'absence d'information.
  Une pastille ne se pose en revanche jamais si la question ne se pose pas —
  une pièce sans châsse n'a pas de gemme manquante.

  Un sixième réglage sort de la fiche : le **niveau d'objet sur l'équipement
  rangé**, dans les sacs, la banque et la banque de bataillon. C'est le même
  nombre et la même question — « celle-là vaut-elle mieux que ce que je
  porte ? » —, et elle se pose surtout devant un sac. Seul l'équipement en
  reçoit un : un nombre sur une potion serait du bruit sur toute la grille. Le
  module Sacs cesse donc de l'annoncer.

  Rien n'est modifié sur la fiche ni sur les sacs du client : le module ajoute
  une frame par emplacement, une étiquette par objet, et cache tout quand on
  l'éteint.

- **Gestionnaire de temps de recharge** — nouvelle page, avec un premier
  réglage : le **suivi des améliorations reste groupé**. Le client réserve une
  place par amélioration suivie et la garde vide quand l'amélioration tombe :
  deux améliorations actives sur cinq suivies s'affichaient aux deux bouts, à
  trois places l'une de l'autre. Elles sont désormais retassées ensemble, au
  milieu de la place que le suivi occupe.

  Rien n'est ajouté ni masqué : les emplacements que le client vient de poser
  sont reposés quelques pixels plus loin, et la position qu'il leur avait donnée
  est relevée pour être rendue à l'extinction.

- **Fenêtres** — nouvelle page. Les fenêtres du jeu se déplacent où l'on veut,
  se redimensionnent, et y restent d'une session à l'autre.

  - **Déplacer** : un glisser sur la fenêtre, et elle reste où on la pose.
    La touche à maintenir se choisit — Maj par défaut, Ctrl, Alt, ou aucune.
    Un modificateur au départ parce que sans lui, un glisser dans le corps
    d'une fenêtre la déplace, y compris quand on visait autre chose.
  - **Redimensionner** : Ctrl et la molette au-dessus d'une fenêtre, de la
    moitié au double de sa taille. La fenêtre ne bouge pas de l'écran en
    changeant de taille.
  - **Tout remettre en place** : un bouton renvoie chaque fenêtre là où
    Blizzard la met, position et taille comprises.

  Une soixantaine de fenêtres sont couvertes, y compris celles qui arrivent en
  cours de session (hôtel des ventes, métiers, hauts faits, carte du monde,
  journal des rencontres…). Les sacs et le menu Échap sont volontairement
  laissés de côté — le client réancre les premiers en permanence, et le second
  est déjà réglé depuis la page Général.

  Rien n'est rendu déplaçable au sens du client : aucun appel à `SetMovable`,
  aucune écriture d'état d'entrée sur un cadre de Blizzard. C'est ce qui permet
  à l'extinction du module de rendre chaque fenêtre exactement où elle était.

- **Cadres d'unités** quitte l'avant-première, avec quatre réglages :

  - les **barres de vie aux couleurs de classe**, sur le joueur, la cible, la
    cible de la cible, le focus et les membres du groupe. Les unités qui ne sont
    pas des joueurs gardent la couleur du client : un sanglier n'a pas de classe ;
  - la **couleur de réputation masquée** derrière le nom de la cible et du focus.
    La plaque aux couleurs de la faction disparaît, le nom se lit sur le cadre ;
  - l'**icône de spécialisation à la place du portrait**, sur les cinq cadres.
    Le portrait est déjà la case où l'on regarde pour savoir qui est en face :
    la spécialisation y répond plus précisément que le visage ou que l'icône de
    classe. Elle se lit dans l'infobulle de l'unité, que le client remplit
    lui-même — donc sans inspection, sans aller-retour serveur et sans limite de
    portée : l'icône est là au moment où la cible l'est ;
  - quatre **décorations qui s'éteignent** séparément : l'effet de repos,
    l'icône de coin du portrait, la lueur de combat — sur tous les cadres
    engagés, le vôtre comme celui de votre cible, de votre familier, de votre
    focus et des boss — et l'icône JcJ avec le badge de prestige, sur le joueur,
    la cible et le focus ;
  - l'**agrandissement des cadres de groupe** au-delà du maximum qu'autorise le
    curseur du mode Édition, de 100 à 250 %. Les deux styles de cadres de groupe
    sont couverts, et le réglage tient : le mode Édition repose sa taille en se
    refermant, on repose la nôtre derrière lui.

  Rien n'est reconstruit, et rien n'attend : chaque réglage est reposé par un
  hook au moment même où le client écrit sur la case concernée, pas par un
  rafraîchissement périodique. Couleurs d'origine des barres, parents des
  décorations et échelle des cadres de groupe sont relevés avant d'être changés,
  et reposés quand le module s'éteint.

### Corrigé
- **Mode sombre** — les cadres d'unités s'assombrissent de nouveau lorsqu'un
  module se branche sur eux. Le client rend le nom de débogage d'une région en
  valeur **secrète** dès que l'exécution est teintée par un addon, et une chaîne
  secrète a bien le type `string` : le garde en place la laissait passer, et
  l'indexer levait. L'erreur tombant hors de tout appel protégé, elle
  n'interrompait pas une texture mais le parcours de l'élément entier — d'où un
  mode sombre qui semblait s'être éteint tout seul, sur les seuls cadres
  d'unités et le jour où un autre module s'y est branché.

## 0.3.1 — 2026-07-31

### Corrigé
- **Mode sombre** — le contour sombre des petites icônes flottait au large au
  lieu d'épouser leur bord. Son débordement est proportionnel à l'icône, mais la
  proportion valait le double de ce qu'il fallait ; le plafond la ramenait à la
  bonne valeur pour une icône de 50 px, et pour elle seule. Visible sur la
  visionneuse utilitaire du gestionnaire de temps de recharge, réglée à 30 px,
  quand celle juste au-dessus est à 50.
- **Mode sombre** — le **suivi des améliorations** s'assombrit enfin. Il en était
  exclu par son propre nom : le client rend le chemin complet d'une texture, et
  chercher « icon » dedans faisait passer tout ce que porte
  `BuffIconCooldownViewer` pour une icône, donc pour intouchable.
- **Mode sombre** — les icônes qui apparaissent en cours de partie prennent la
  teinte sans attendre. Les visionneuses de temps de recharge créent leurs
  emplacements au fur et à mesure ; ceux nés après la connexion n'étaient jamais
  repris, ce qui laissait les améliorations suivies en clair.
- **Mode sombre** — la texture « hors de portée » du gestionnaire de temps de
  recharge n'est plus assombrie. C'est un signal, pas de l'habillage : l'éteindre
  revenait à le faire taire au moment où il a quelque chose à dire.

## 0.3.0 — 2026-07-31

### Ajouté
- **Général** est le premier module écrit depuis Quête. Il quitte l'avant-première
  et fait réellement onze choses :

  - un **bouton BshamelUI sur la minicarte**, déplaçable autour du cadran, qui
    ouvre la fenêtre d'options. Il porte le logo de l'addon
    (`media/logo.tga`), qui remplace du même coup le point d'interrogation
    provisoire du compartiment d'addons ;
  - un **mode sombre** réglable élément par élément — cadres d'unités, barres
    d'action, barre d'incantation, buffs et debuffs, gestionnaire de temps de
    recharge, infobulle. Pas de dosage : c'est la liste qui se règle, pas la
    profondeur du noir.

    Il modifie l'interface du jeu, il n'en ajoute pas : l'habillage est désaturé
    puis assombri, et les icônes ne sont jamais teintées — ce sont leurs
    contours, des textures distinctes que le client dessine autour d'elles, qui
    foncent. Là où le contour existe on le rhabille ; là où il n'y en a aucun,
    comme sur les icônes d'auras, on en pose un, à la bordure de sort du client.
    Rien n'est masqué pour laisser la place à autre chose, et l'état d'origine
    de chaque texture empruntée est rendu à l'extinction.

    L'infobulle fait exception à la règle : seul son contour fonce. Son fond
    relève de la lisibilité, pas de l'habillage.

    Deux exclusions assumées pour l'instant : les **cadres de groupe et de
    raid**, et la **barre de ressource personnelle**. Ni leur conteneur ni leurs
    noms globaux n'ont permis de les teinter, et ajouter des noms au hasard
    n'est pas une piste — y revenir demandera de comprendre comment le client
    les peint ;
  - la **distance de caméra maximale**, avec son facteur de zoom ;
  - un **menu Échap réduit**, à la taille qu'on veut ;
  - un **décompte sur les fenêtres de file d'attente**, donjon comme champ de
    bataille ;
  - la **réparation automatique**, fonds de guilde d'abord, bourse ensuite, avec
    le montant annoncé dans le chat ;
  - le filtre **extension actuelle uniquement** à l'hôtel des ventes, qui cesse
    de se remettre à zéro à chaque recherche ;
  - les **cinématiques passées**, les **têtes parlantes masquées** et la
    **fenêtre d'erreurs Lua coupée**.

  Les éléments du mode sombre sont cochés d'avance alors que le mode sombre est
  éteint : l'allumer doit produire un effet visible tout de suite.

### Modifié
- Le mode sombre quitte les pages **Barres d'action** et **Cadres d'unités**
  pour vivre uniquement dans **Général**. Un même effet réglé à deux endroits
  finit par se contredire ; les deux pages renvoient vers Général.
- **Annoncer les morts du groupe** et son alerte sonore passent de **Général** à
  **Outils de raid**, qui reste en avant-première. C'est un outil de groupe, sa
  place est avec le reste de ce qui parle au raid.

### Interne
- `UI/Shade.lua` : moteur d'assombrissement réversible. Il multiplie la couleur
  de sommet des textures du client au lieu de poser un voile par-dessus, relève
  chaque couleur d'origine avant de la changer, et sait toutes les rendre — c'est
  ce qui permet à `OnDisable` de ne rien laisser derrière.

  Rien n'y est demandé à un cadre du client autrement que par un appel
  enveloppé, et chaque élément, chaque texture, échoue pour son propre compte :
  une frame récalcitrante ne coûte qu'elle-même. Ce qui informe — remplissage
  des barres, textures d'état d'un bouton, icônes, portraits — n'est jamais
  teinté.
- Trois fabriques de widgets : `W.MinimapButton`, `W.Countdown` et
  `W.ShadeBorder`. Aucune bibliothèque tierce : le bouton de minicarte tient en
  un fichier.
- `T.ShadeFactor`, `T.TIMING` et les mesures du bouton de minicarte rejoignent
  `UI/Theme.lua`.

## 0.2.0 — 2026-07-31

### Ajouté
- Aperçu des modules à venir dans la fenêtre d'options : **Général**, **Fiche de
  personnage**, **Barres d'action**, **Cadres d'unités**, **Chat**, **Sacs**,
  **Clés mythiques** et **Outils de raid**. Leurs pages se parcourent et
  montrent les réglages qu'ils proposeront, mais rien ne s'y active : ces
  modules n'ont pas encore de code.
- Deux catégories de navigation, **Jeu** et **Interface**, pour accueillir ces
  pages.

  Ces entrées ne sont pas grisées dans la colonne, contrairement à celles d'un
  module éteint : un module à venir n'a jamais été allumable, et les griser
  délaverait toute la navigation.

### Modifié
- Fenêtre d'options sombre et translucide : le jeu reste visible derrière, les
  bordures du cadre restent pleines, et un voile en dégradé assombrit les quatre
  bords vers l'intérieur comme le panneau Options du client.
- Le titre de page n'est plus encadré. Il s'affiche en grand et en blanc,
  souligné d'un filet, sur le modèle de ce même panneau.
- L'encadrement passe à la colonne de navigation, et chaque en-tête de catégorie
  reçoit un titre blanc sur un bandeau portant la texture de la barre de titre
  de la fenêtre, borné de deux filets.
- Survol et sélection d'une entrée de la colonne sont deux bandeaux dégradés,
  forts au centre et estompés aux deux bouts. Hors survol et hors sélection, une
  entrée ne porte aucune texture de fond : les bandeaux sont masqués, et non
  rendus transparents — un alpha nul sur une texture dégradée laissait filtrer
  un voile gris permanent sur toute la colonne.
- Couleurs de texte alignées sur celles du client : le doré structure
  (catégories, en-têtes de section, entrées de module au repos), le blanc se lit
  (titre de page, libellés, entrée sélectionnée). L'accent bleu quitte le chrome
  de la fenêtre.
- Textes et lignes agrandis des deux côtés, la colonne de navigation davantage
  que la zone de contenu.
- Les deux zones partagent exactement la même teinte de fond : le panneau creusé
  ne pose plus de second voile par-dessus celui de la fenêtre.
- La colonne de navigation perd son ascenseur — la molette suffit. Celui de la
  zone de contenu est dépouillé de ses boutons et de sa piste, son curseur est
  dimensionné au prorata de la page, et il disparaît quand tout tient sur un
  écran.
- Un séparateur vertical texturé, estompé en haut et en bas, sépare la
  navigation de la zone de contenu.
- Les pages n'ont plus d'interrupteur « Activer ce module » : chaque réglage
  étant éteint par défaut, allumer celui qu'on veut suffit.

### Interne
- `dev/scripts/lint-local.sh` vérifie la longueur des lignes, seule règle de
  `luacheck` que `lua-language-server` ne couvrait pas. Sans elle, une ligne trop
  longue passait en local et mettait la CI au rouge sans signal préalable.
- Toutes les opacités de l'interface sont regroupées dans `T.ALPHA`
  (`UI/Theme.lua`) au lieu d'être écrites au fil des widgets.
- Les polices se déclarent en candidats résolus au chargement, comme les
  templates : les variantes récentes (`…Medium`, `…Large2`) ne sont garanties
  par aucun contrat et une police inconnue lève une erreur.
- `W.PageTitleBox` devient `W.PageTitle` ; `W.VerticalDivider` est remplacé par
  `W.Rule`, partagé par le titre de page, les en-têtes de section et les
  bandeaux de catégorie. Nouveau `W.EdgeShade`.
- Nouveau drapeau de module `preview` : le core refuse d'activer le module et le
  moteur de pages grise sa page entière.

## 0.1.2 — 2026-07-30

### Modifié
- Publication sous le nom d'auteur « Bshamel ».

### Interne
- `Refresh` d'une page d'options devient une fonction partagée au lieu d'une
  fermeture recréée pour chaque module.
- Suppression d'une table morte dans la barre latérale.
- Intégration continue opérationnelle : `luacheck` et garde-fous de design
  vérifiés à chaque push, packaging et publication automatiques sur tag.

<!-- La version 0.1.1 a été taguée mais jamais publiée : le job de release
     manquait `jq` et sautait l'envoi. Le tag reste en place, la protection des
     tags interdisant sa suppression. -->


## 0.1.0 — 2026-07-30

Première version. Les fondations sont posées ; un seul module fonctionnel pour
l'instant, les suivants s'appuieront dessus.

### Ajouté
- Socle de l'addon : namespace, répartiteur d'événements, bus de messages
  interne, sortie console.
- Base de données à profils (choix du profil par personnage), fusion des valeurs
  par défaut à la connexion et nettoyage à la déconnexion.
- Registre de modules déclaratifs, avec révocation automatique des abonnements
  à la désactivation et report d'activation hors combat pour les modules
  sécurisés.
- Système de traduction avec repli sur l'anglais ; locales `enUS` et `frFR`.
- Design system : tokens uniques (`UI/Theme.lua`), fabrique de widgets,
  moteur de pages déclaratives.
- Fenêtre d'options `/bui` : navigation par catégories, encadré de titre de
  page, zone défilante, entrée dans les options du client, icône dans le
  compartiment d'addons.
- Module **Quête** : acceptation et rendu automatiques, filtre sur les quêtes
  triviales, touche de contournement configurable.
- Garde-fous de design vérifiés en intégration continue
  (`dev/scripts/check-design.sh`).
- Pipeline GitLab : `luacheck` et garde-fous à chaque push, packaging et envoi
  CurseForge sur tag.
