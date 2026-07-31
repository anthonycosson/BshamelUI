# Journal des modifications

## Non publié

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
