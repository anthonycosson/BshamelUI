# Journal des modifications

## Non publié

## 0.7.6 — 2026-08-01

### Modifié
- Le **chrono mythique+** n'est plus un panneau à nous. Il redisait le temps
  restant à côté de celui du jeu — deux chronos pour une clé, dont un seul est le
  vrai —, et il fallait le placer. Tout s'ajoute désormais au chrono du jeu, et
  chaque pièce s'allume séparément :

  - **Les chronos +2 / +3.** Deux temps ajoutés à droite du chrono du jeu : ce
    qu'il reste avant de perdre +3, en **or**, puis avant de perdre +2, en
    **gris** — le +2 ne se regarde que quand le +3 est perdu, et il doit se taire
    jusque-là. Le chrono du jeu, lui, garde son blanc : c'est le nombre principal,
    et le teindre l'aurait rangé au même niveau que les deux autres alors qu'il les
    commande. Un palier perdu retire son nombre, et le suivant se recale contre le
    chrono.

    Plus un repère sur la barre à chaque palier : une **lueur dorée** de huit
    pixels, opaque sur le palier et éteinte sur ses deux bords, cadrée en haut de la
    barre. Le bleu qu'on voit est plus court que le cadre de la barre, et pas
    symétriquement — les trois pixels qu'on laisse sont ceux du bas.
  - **Le coût des morts.** Les secondes que vos morts ont ajoutées, en rouge et en
    petit, sur la rangée du niveau de clé — entre le niveau et les affixes. Le jeu
    compte ce nombre et ne le montre que dans une infobulle. Son compteur de morts,
    lui, ne bouge pas d'un pixel : il reste où le jeu le met.

    Le nombre se cale **contre les affixes** et grandit vers la gauche. C'est le
    seul sens qui tienne : le jeu pose ses affixes depuis le bord droit du bloc,
    donc quatre affixes commencent plus à gauche que deux, et un nombre posé à la
    suite du niveau leur monterait dessus.
  - **Les temps de boss.** Le temps auquel chaque boss est tombé, contre son nom
    dans le suivi.

  Le temps restant, le niveau de la clé et le compteur de morts restent ceux du
  jeu, écrits par ses propres fonctions.

  Le réglage qui allumait le panneau allume les repères, et il garde votre choix.
  Sa position, elle, n'a plus d'objet et disparaît.

- Le **mode aperçu** montre désormais le suivi du jeu lui-même, hors donjon, sur
  une clé d'exemple prise dans la saison en cours : le chrono, trois lignes de boss
  et un décompte de troupes. Éteignez les réglages un à un pour voir le suivi tel
  que le jeu le dessine.

  L'exemple démarre à la moitié du chrono dépensé, ce qui met le remplissage juste
  au-dessus des deux repères : les trois temps sont là d'un seul coup d'œil. Ses
  trois boss couvrent les trois états du comparatif — devant, derrière, et sans
  référence du tout, ce qui est le cas d'un boss jamais passé sur une clé réussie.
  Et il compte trois morts, parce que le jeu cache son compteur à zéro mort : un
  aperçu qui ne le montre pas laisse croire qu'on l'a perdu.

  Ses lignes passent par la fabrique de lignes du jeu, avec ses pastilles et ses
  teintes : un aperçu bâti autrement montrerait autre chose que ce qu'on verra.

### Ajouté
- Le **comparatif des temps de boss**. Sous le nom du boss, l'écart avec votre clé
  la plus rapide déjà réussie **dans le chrono, au même niveau et dans le même
  donjon** : `-00:30` en vert si vous êtes devant, `+00:30` en rouge sinon.

  Sous le nom, et non à la suite : bout à bout, l'écart tombait après le nom, donc à
  un endroit différent pour chaque boss selon la longueur de ce nom — le retour à la
  ligne paraissait aléatoire et aucune colonne ne se formait. Forcé sur sa propre
  ligne, il est au même endroit partout.

  La plus rapide et non la dernière : un écart sert à savoir si on est en avance,
  et on est en avance sur ce qu'on sait faire. Rien ne s'affiche tant qu'aucune clé
  de ce niveau n'a été réussie — un écart avec une clé ratée ne voudrait rien dire.

  C'est la seule mémoire de l'addon, et elle est assumée : le jeu ne garde d'une
  clé réussie que sa durée totale, jamais ses temps de passage. Ils sont retenus
  **par personnage**, à côté de l'historique de chat, et non dans les réglages.

### Corrigé
- L'infobulle de **« Répondre à !keys »** annonçait le groupe et le raid seulement.
  Elle répondait déjà en instance et **en guilde** ; c'était l'infobulle qui
  mentait, pas le code.

### Retiré
- Le **comparatif du meilleur temps de la saison** dans le chrono mythique+. Le
  temps total qu'on avait mis la dernière fois ne change pas ce qu'on fait de celui
  qui reste ; les temps de boss, eux, le changent, et ils le remplacent.

- La mention **« le mode sombre a déménagé »** sur les pages *Barres d'action* et
  *Cadres d'unités*. Elle datait du déplacement du réglage vers *Général* et n'avait
  plus rien à signaler. Le bandeau *Apparence* des barres d'action part avec elle :
  il ne servait qu'à l'introduire.

## 0.7.5 — 2026-08-01

### Ajouté
- La catégorie **MM+ / Raid** s'allume. Ses quatre pages étaient annoncées et
  grisées ; elles sont livrées, chaque réglage restant éteint par défaut.

  - **Clés mythiques** — répondre à « !keys » avec le lien de sa clé, et la poser
    sur le socle sans ouvrir ses sacs.
  - **Recherche de groupe** — conserver la note d'inscription d'une candidature à
    l'autre, et répondre aux vérifications de rôle.
  - **Outils de raid** — le suivi des résurrections de combat, le panneau
    d'outils de groupe, le masquage du panneau de contrôle du jeu et la
    journalisation automatique.
  - **Chrono mythique+** — le décompte de la clé et ses paliers.

- Le **panneau d'outils de groupe** : les huit marqueurs au sol, un rond barré
  rouge qui les retire tous, une vérification de présence et un pull qui lance le
  décompte du jeu et l'annonce dans le chat du groupe. Il porte le contour ouvragé
  des dialogues du jeu, sans bande de titre : un panneau de deux rangées n'a pas
  de hauteur à perdre, et neuf vignettes n'ont pas besoin d'être légendées.

  Son coin bas-droit règle son **échelle** et non sa taille — tout grossit d'un
  coup, vignettes et libellés compris, entre la moitié et le double et demi. Deux
  réglages l'accompagnent : **verrouiller sa position**, qui le fige et range sa
  poignée sans toucher aux boutons, et **ne l'afficher qu'au survol**, où il reste
  invisible jusqu'à ce que la souris le trouve.

  Il ne se montre ni ne se cache en combat : le jeu refuse qu'on touche à un
  bouton de marqueur pendant qu'on se bat. Il suit de nouveau le réglage dès la
  fin du combat.

- Le **suivi des résurrections de combat** : une icône de sort, le nombre de
  charges dans son coin, le temps avant la suivante en son milieu — comme le jeu
  habille un bouton d'action. Trois réglages là où on l'allume : le **contour
  sombre**, le **verrou de position**, et un **mode aperçu** qui l'affiche hors
  instance, rempli de valeurs d'exemple, le temps de le placer. Il ne se montre
  autrement que là où il y a une réserve à compter, c'est-à-dire nulle part au
  moment précis où l'on cherche où le poser.

- La **journalisation automatique** part dès le seuil d'un donjon ou d'un raid,
  active la journalisation détaillée dont les sites d'analyse ont besoin, et remet
  le tout comme elle l'a trouvé en sortant. Chaque bascule laisse une ligne dans
  le chat — armée, lancée avec le chemin du fichier, arrêtée, ou déjà en cours et
  laissée tranquille. Une journalisation lancée à la main n'est jamais coupée :
  l'addon ne s'éteint que ce qu'il a lui-même allumé.

- **Masquer le panneau de contrôle du jeu**, seul réglage du module allumé par
  défaut : il porte les mêmes outils que le nôtre, et les deux côte à côte ne
  servent qu'à se demander lequel on regarde.

### Corrigé
- Plus d'erreurs à répétition sur les **icônes de spécialisation** des cadres
  d'unités ni sur l'**historique du chat**. Le jeu répond désormais par des
  valeurs « secrètes » là où il protège une information — l'identité d'une unité
  d'arène, le texte d'une ligne de chat —, et une telle valeur ne se compare ni ne
  se teste. Ce qui ne peut pas être lu est simplement laissé de côté : l'icône
  n'est pas posée, la ligne n'est pas retenue, et le reste continue.

## 0.7.4 — 2026-07-31

### Ajouté
- Le menu de téléportation affiche le **temps de recharge** de chaque ligne. Il
  n'apparaît que lorsqu'il y en a un : une ligne prête ne porte rien, si bien que
  c'est la présence du nombre qui renseigne, pas sa valeur. Le temps de recharge
  global n'est pas compté — il court sur tout et ne dit rien.

### Corrigé
- **Passer les cinématiques** fonctionne enfin sur les scènes en jeu, c'est-à-dire
  sur presque toutes celles qu'on croise. Trois choses différentes se cachent
  derrière ce mot : le film, qui se termine ; la vraie cinématique, qui s'arrête ;
  et la **scène en jeu**, que le client ne laisse couper que pendant qu'il traite
  une touche. L'addon ne pouvait donc rien faire depuis l'événement d'ouverture.
  Il arme désormais l'annulation, que votre première touche déclenche — et il
  répond pour vous à la demande de confirmation, de sorte qu'une touche suffit là
  où il en fallait deux.

### Modifié
- Le mode sombre laisse les **cadres de boss** tranquilles. Ce sont des cadres de
  combat : ce qu'on y lit se lit vite ou ne se lit pas, et un habillage assombri
  les rapproche du fond au moment précis où ils comptent le plus. Le mode sombre
  range l'interface, il n'a rien à faire sur ce qui sert à réagir. Les cadres
  déjà assombris reprennent leur apparence sans rechargement.

## 0.7.2 — 2026-07-31

### Ajouté
- **Passer la confirmation de vente**, dans *Sacs*. Vendre un butin encore
  échangeable — ou encore remboursable — ouvre une fenêtre qui demande de
  valider ; le réglage y répond à votre place. Il est éteint par défaut et porte
  un avertissement en toutes lettres : cette fenêtre est la dernière chose qui
  sépare l'objet d'une vente définitive, et ce qu'on économise est un clic là où
  ce qu'on risque est un objet. On clique d'ailleurs *son* bouton, on ne vend
  pas nous-mêmes — c'est sa fenêtre, sa vente.

### Modifié
- Le menu de téléportation nomme les **donjons**, plus les sorts qui y mènent :
  « Voie de Coursevent » était le nom du chemin, pas celui de l'endroit. Le lien
  vient du client — la carte de mode défi quand elle publie son sort, la
  description du sort sinon, qui nomme le donjon dans sa phrase. Aucune liste
  n'est écrite dans l'addon, et un sort dont le donjon reste introuvable garde
  son nom d'avant.
- Le choix de la **pierre de foyer** ne dépend plus du bouton de téléportation.
  Le menu s'ouvre aussi depuis sa macro : qui a rangé son bouton gardait sa
  macro, mais perdait le réglage qui décide de ce qu'elle propose.

### Corrigé
- Le **tiroir de boutons d'addons** ne ramasse plus les épingles que les addons
  de récolte posent sur la minicarte. Elles sont des boutons nommés comme les
  autres, et il y en a trente : le tiroir se remplissait de « GatherMatePin1 »,
  « GatherMatePin2 »… Pire, une épingle rangée était une épingle volée à l'addon
  qui la recycle à chaque pas. Trois signes les écartent désormais — une racine
  de nom portée par plusieurs cadres, un nom qui dit ce que le cadre est plutôt
  qu'à qui il appartient, et la **taille** : une épingle fait la moitié d'un
  bouton de minicarte. Ce dernier signe ne demande rien au nom, et c'est le seul
  qui vaille pour un addon dont on n'a jamais vu les épingles.

### Supprimé
- Le curseur d'**intensité des fenêtres**, arrivé à la version précédente. Il
  n'offrait qu'un dégradé de gris, réglé une fois puis oublié, et il obligeait
  chaque surface de l'addon à savoir se repeindre — un mécanisme entier pour une
  valeur qui se décide une bonne fois. C'est le maximum, c'est-à-dire l'apparence
  d'origine, qui reste. Le réglage de ceux qui l'avaient bougé est effacé de leur
  fichier au premier chargement.

## 0.6.0 — 2026-07-31

### Ajouté
- **Intensité des fenêtres**, curseur en tête de *Général*. Au maximum, c'est
  l'apparence d'origine ; en descendant, les fenêtres de l'addon s'éclaircissent
  vers le gris. Il n'y a rien au-dessus : un fond plus sombre que celui-là ne se
  distinguerait plus du vide.

  Le réglage existe parce qu'aucune valeur ne peut être juste partout. Le même
  fond qui a du relief sur un écran est un aplat mort sur un autre, selon le
  gamma, la dalle et la lumière de la pièce — c'est en le voyant chez quelqu'un
  d'autre qu'on s'en aperçoit, et c'est précisément ce qu'on ne peut pas deviner.
  Plutôt qu'une valeur de plus, discutée sans fin, un curseur.

  Il porte sur **toutes** les fenêtres de l'addon d'un coup — options, tiroir de
  la minicarte, menu de téléportation, panneaux de raid —, et se voit pendant
  qu'on le bouge : une clarté se règle à l'œil, pas au rechargement. Le bandeau
  des en-têtes suit le fond au même facteur, sans quoi il finirait par le croiser
  et l'en-tête disparaîtrait à un réglage précis.

### Modifié
- La fenêtre d'options est **éclaircie** d'un cran, et c'est elle que le curseur
  prend désormais pour maximum. Le voile sombre des bords s'allège dans la même
  passe : il noircissait les quatre coins, là où tombent justement la navigation
  et le premier réglage de chaque page. Le survol, la sélection et les modules
  éteints sont remontés d'autant — un voile blanc sur un fond moins noir ajoute
  moins de lumière, il fallait les rendre pour que les trois états d'une ligne
  restent aussi séparés qu'avant.
- Une catégorie de la navigation dont **tous** les modules sont annoncés porte la
  mention *(Prochainement)*, ce qui évite d'ouvrir quatre pages pour découvrir
  qu'aucune n'est allumable. Tous, et non certains : une catégorie où un module
  sur trois fonctionne ne s'annonce pas comme à venir.
- *Mythique+ / Raid* devient **MM+ / Raid** en français : c'est ainsi que les
  joueurs l'écrivent, et la colonne est étroite.

## 0.5.0 — 2026-07-31

### Ajouté
- **Minicarte**, page nouvelle, avec deux boutons qui se déplacent à la souris
  autour de la carte :

  - le **bouton BshamelUI**, qui était dans *Général*. Il a déménagé : une page
    « Minicarte » qui ne contiendrait pas le bouton de l'addon obligerait à le
    chercher ailleurs. Le réglage de ceux qui l'avaient allumé suit tout seul.
    Il porte maintenant deux gestes — **clic droit** pour cette fenêtre, **clic
    gauche** pour les boutons d'addons ;
  - le **tiroir de boutons d'addons** : les boutons que les autres addons posent
    autour de la carte sont rangés dans un tiroir qui s'ouvre **à côté du bouton
    BshamelUI**, au clic gauche. Il n'a pas de bouton à lui : un addon qui en
    ajouterait un pour ranger ceux des autres se moquerait du monde. Les boutons
    du jeu ne sont pas touchés — ils font partie de la minicarte, pas de son
    encombrement —, et éteindre le réglage rend chaque bouton à son parent, à ses
    ancrages et à sa strate d'origine, c'est-à-dire exactement là où il était ;
  - le **menu de téléportation**, en deux sections. Les **pierres de foyer** :
    celle qu'on a choisie — elles partagent toutes un temps de recharge et vont
    toutes au même endroit, le menu n'en montre donc qu'une, et un réglage dit
    laquelle —, puis celles qui ont leur propre temps de recharge (Dalaran,
    Arcantina, fief) et le rappel astral du chaman. Les **téléportations** ensuite,
    en tiroirs qui s'ouvrent au survol : **un par extension**, portant le nom et
    l'icône que leur donne le grimoire, celui de la saison en cours en tête.

    Rien n'est écrit en dur, pas même le nom de la saison : les tiroirs sont
    ceux du grimoire, donc débloquer une voie l'ajoute sans rien mettre à jour,
    et la saison suivante s'appellera comme le jeu l'appellera. La rotation
    publiée par le jeu ne sert qu'à savoir lequel des tiroirs est celui de la
    saison, pour le poser en premier.

    Le menu s'ouvre aussi **depuis une barre d'action** : un bouton des options
    crée la macro, il ne reste qu'à la glisser sur un emplacement. Un emplacement
    n'accepte que ce que le jeu y range — et une macro en fait partie, là où le
    cadre d'un addon n'y entre jamais. Le menu s'ouvre alors contre
    l'emplacement cliqué, pas à côté de la minicarte.

    Le menu ne montre que ce que le personnage possède ou connaît réellement, et
    un clic sur une ligne l'utilise. Il ne s'ouvre pas en combat : le jeu refuse
    de confier un sort à un addon pendant un combat, et rien de ce qu'il
    contient ne s'utilise en combat.

- **Barres d'action** quitte l'avant-première avec **le moment où part une
  action** : à l'enfoncement de la touche ou à son relâchement. Le réglage
  existe dans le client, il n'est simplement pas là où on le cherche.

  Trois choix et non une case à cocher, parce que le jeu a son propre défaut et
  que d'autres addons écrivent la même valeur : « défaut du jeu » ne touche à
  rien, les deux autres forcent dans un sens ou dans l'autre. C'est ce qui
  permet de dire « je veux le relâchement » et d'être obéi, là où une case
  décochée n'aurait fait que s'abstenir. La valeur d'origine est relevée avant
  d'être changée et reposée si l'on éteint le module.

- **Sacs** quitte l'avant-première avec ses deux conforts :

  - **vendre la camelote** à chaque marchand. C'est la vente groupée du client
    qui est appelée, donc sa définition de la camelote et non la nôtre. Elle
    part sans accusé de réception et le serveur en écarte une partie quand elle
    arrive trop vite : on recompte après chaque passe et on recommence tant que
    le nombre baisse, ce qui évite les gris oubliés dans les sacs. Le total
    encaissé est annoncé dans le chat ;
  - **remplir la confirmation de destruction** : le mot à recopier pour détruire
    un objet de valeur est écrit à votre place. Le geste qui engage reste le
    vôtre — il reste à cliquer, et c'est ce clic qui détruit.

### En avant-première

La catégorie **Mythique+ / Raid** compte désormais quatre pages, et leur code est
écrit. Elles restent **grisées** : rien ne s'y allume tant qu'elles n'ont pas été
vérifiées en jeu. Ce qui suit décrit donc ce qu'elles feront, pas ce qu'elles
font aujourd'hui.

`Modules/Upcoming.lua` a disparu au passage : un module annoncé n'est plus une
déclaration sans code, c'est son propre fichier avec un interrupteur en tête.

  **Clés mythiques** :

  - **répondre à !keys** dans le chat de groupe, de raid, d'instance ou de
    guilde. La réponse est le **lien** de la clé dès qu'elle est trouvée dans les
    sacs, donc survolable par ceux qui la lisent ; à défaut, le donjon et le
    niveau sont écrits en toutes lettres. Une seule réponse par canal toutes les
    dix secondes — cinq personnes qui demandent en même temps ne doivent pas
    faire couper la parole par le serveur — et jamais de réponse à soi-même ;
  - **insérer la clé automatiquement** dans la fontaine de puissance dès qu'elle
    s'ouvre. Une clé déjà posée par quelqu'un d'autre n'est pas remplacée : le
    choix de la clé appartient au groupe.

  **Recherche de groupe** :

  - la **note d'inscription est conservée** d'une candidature à l'autre. Elle est
    relevée à la fermeture de la fenêtre, que la candidature soit partie ou non —
    une note abandonnée est justement celle qu'on veut retrouver ;
  - les **vérifications de rôle se valident** toutes seules, avec les rôles que
    vous aviez déjà choisis en vous inscrivant ;
  - l'**invitation attendue s'accepte** toute seule, et elle seule : le réglage
    ne fait rien tant qu'aucune candidature n'est en cours, donc une invitation
    reçue de n'importe qui reste à votre main ;
  - un **rappel de ce que vous venez de rejoindre** s'affiche à l'écran, avec un
    bouton de téléportation quand le personnage connaît celle qui mène à ce
    donjon. Il reste jusqu'à l'entrée dans l'instance ou jusqu'au premier combat.

  **Outils de raid** :

  - le **suivi des résurrections de combat** : l'icône du sort, le nombre de
    charges restantes et le délai avant la suivante. La taille se règle, le
    panneau se déplace à la souris, et le mode sombre lui pose le même contour
    qu'aux icônes d'auras ;
  - une **barre de marqueurs au sol**, avec les huit marqueurs, un bouton pour
    tout retirer, une vérification de présence et un **pull timer** qui déclenche
    le décompte du jeu — celui que tout le monde voit, y compris sans addon — et
    l'annonce dans le chat du groupe ;
  - le **panneau de contrôle de raid du jeu se masque**, cet onglet collé au bord
    gauche de l'écran dont notre barre reprend l'utile ;
  - le **contrôle des buffs à la vérification de présence** : qui n'a pas de
    nourriture, qui n'a pas de flacon, quels flacons expirent bientôt, et si
    votre enchantement d'arme manque ou touche à sa fin. Le rapport n'est envoyé
    à personne, vous seul le lisez ;
  - l'**annonce des morts du groupe**, avec alerte sonore facultative. Un wipe
    ne produit qu'une ligne qui nomme tout le monde : vingt messages en une
    seconde, c'est le serveur qui coupe la parole ;
  - la **journalisation automatique** des combats en raid et en clé mythique,
    journalisation détaillée comprise — sans elle, le journal ne porte ni
    positions ni ressources et les sites d'analyse n'en tirent presque rien. Elle
    ne s'arrête que si c'est nous qui l'avions lancée.

  **Chrono mythique+** : un panneau qui montre ce que le chrono du jeu ne montre
  pas — les **paliers +2 et +3**, à 80 % et 60 % du temps accordé, avec le temps
  qu'il reste pour chacun et de combien celui qui est passé a été manqué. Une
  ligne de **comparatif** rappelle votre meilleur temps de la saison sur ce
  donjon, et devient un écart signé à l'arrivée. Rien n'est mémorisé ici : ce
  meilleur temps est celui que le jeu retient lui-même. Un **mode aperçu**
  affiche le panneau hors donjon, rempli de valeurs d'exemple, pour le placer.

### Interne

- un **nom d'événement inconnu du client n'emporte plus le module** qui le cite.
  `RegisterEvent` lève sur un nom qu'il ne connaît pas, et l'`OnEnable` s'arrêtait
  là : tout ce qui suivait n'était jamais branché, pour un symptôme — « la moitié
  du module ne fait rien » — qui ne ressemble pas à sa cause. Le core tente, le
  signale, et continue ;
- **`/bui blocked`** écrit dans le chat le nom de l'action refusée quand le
  client affiche « BshamelUI a été bloqué ». La fenêtre ne le dit jamais, et sans
  lui la cause se cherche à l'aveugle. La veille allume l'affichage des erreurs —
  seule condition pour que le jeu émette l'événement — et le repose en
  s'éteignant ;
- un **menu déroulant accepte une liste calculée** et non plus seulement une
  liste écrite : c'est ce qui permet de proposer les pierres de foyer que le
  personnage possède réellement ;
- deux pièces nouvelles dans la fabrique de widgets — un bouton nommé, cliquable
  par une macro, et la fermeture au clic extérieur, qui écoute l'appui de souris
  du client au lieu de poser un cadre qui avale les clics ;
- une **quinzaine d'entrées** dans `dev/docs/API_NOTES.md`, dont plusieurs pièges
  coûteux : l'identifiant d'un sort ne date pas son extension, une téléportation
  de donjon est un tiroir et non un sort, relever la strate d'un cadre emprunté
  cache son icône, et `Click()` ne déclenche qu'une des deux façons de brancher
  un clic.

## 0.4.0 — 2026-07-31

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
