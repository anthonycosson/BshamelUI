# Journal des modifications

## Non publié

### Modifié
- **Le mode aperçu se scinde en deux, chacun dans sa section.** Un seul
  interrupteur montrait tout ce qui ne se voit qu'en combat : on l'allumait pour
  juger une barre de sorts et on récoltait un crâne sur chaque plaque. *Aperçu de
  la barre de sorts* vit maintenant sous la barre de sorts, *Aperçu de la marque*
  sous la marque — et chacun est en retrait sous l'interrupteur qui lui donne un
  sens.

  Ce retrait est le correctif : l'aperçu montrait la barre et la marque **du
  client** tant que la taille n'était pas à nous, et les curseurs semblaient donc
  sans effet. Un aperçu ne prévisualise que ce qu'on pilote.

- ***Marqueur de ciblage* devient *Marque de cible*.**

### Ajouté
- **Quelles unités adverses portent une barre d'infos, séparément dans le monde
  ouvert, en instance PvE et en instance PvP.** Le jeu range cela dans une poignée de réglages —
  toutes les unités hostiles, les serviteurs, les unités mineures, et selon les
  clients les familiers, les gardiens et les totems — mais il n'en tient qu'un
  seul jeu pour les deux contextes. Or les totems d'un chaman adverse comptent en
  arène et encombrent en ville.

  L'addon en tient trois, et écrit celui qui convient au passage d'un portail :
  ce qu'on veut voir n'est pas le même dehors, en donjon et en arène — dehors on
  cherche la lisibilité, en donjon les invocations qui tuent, en arène tout ce
  que l'adversaire pose au sol.
  Chaque case porte un **exemple** en infobulle, parce que « serviteur »,
  « gardien » et « unité mineure » sont le vocabulaire du moteur, pas celui du
  joueur : personne ne sait de tête de quel côté tombe une gargouille.

  Allumer la section recopie dedans l'état où le jeu se trouve : rien ne change à
  l'écran tant qu'on n'y touche pas. Les trois lignes correspondantes de la
  moitié Blizzard passent alors sous elle — elles décident de la même chose, et
  deux réponses à une question donnent la dernière écrite. Elles restent visibles
  et disent le vrai : *Unités ennemies* cochée, *Serviteurs ennemis* décochée
  puisque ce qu'un adversaire invoque ne passe plus par elle, et *Unités
  mineures* au reflet de la case d'en face.

  Les familles que le client ne connaît pas ne rendent aucune ligne : on lui
  demande, on ne suppose pas.

## 0.8.3 — 2026-08-06

### Modifié
- **Barres d'infos** affiche désormais *toujours* les réglages du jeu et ceux de
  Bshamel UI côte à côte. La page ne se replie plus sur une colonne unique quand
  la fenêtre est étroite : c'est la fenêtre qui s'élargit d'elle-même en entrant
  dans cette page, et qui rend au joueur sa largeur en la quittant. Un réglage de
  l'addon se comprend en regardant celui du jeu qu'il double ou qu'il grise —
  l'un sous l'autre, il n'y a plus rien à comparer.

  La fenêtre retaillée à la main pendant qu'on est sur cette page garde la
  largeur choisie : le geste du joueur passe avant le nôtre.

- **Les deux notes en tête de cette page tiennent en une ligne**, en rouge et
  d'un corps au-dessus du reste : ce sont les étiquettes des deux moitiés, et
  deux titres seuls ne suffisaient pas à distinguer deux colonnes qui se
  ressemblent ligne pour ligne.

- **La page est réordonnée.** *Barre de vie*, *Barre de sorts* et *Superposition*
  sont les trois catégories de la moitié Bshamel UI ; *Alliés* n'en est plus une
  et rentre dans la barre de vie, dont elle règle un cas particulier — elle porte
  désormais un en-tête subordonné, sans filet.

  Côté jeu, le premier bloc s'appelle enfin **Général** : il commençait sous la
  note d'ouverture, sans titre, et se lisait comme la suite de celle-ci.

  *Menace* perd sa catégorie et ses trois lignes rejoignent *Couleurs des
  adversaires*, sous les couleurs de classe. C'est une couleur de barre de vie de
  plus — décidée par ce que l'adversaire regarde plutôt que par ce qu'il est — et
  un titre pour trois lignes coûtait une hauteur d'écran.

- **Une ligne commandée par une case est en retrait sous elle.** Vingt lignes de
  la page l'étaient déjà par intention et pas à l'écran : largeur et hauteur sous
  *Régler la taille*, les trois opacités sous *Régler l'opacité*, les textures,
  les couleurs, la superposition. Le retrait et le corps plus petit disent ce que
  le grisé ne dit qu'après coup — que cette ligne dépend de celle du dessus.

- **Les dernières notes de la page partent** : barres simplifiées, couleurs des
  adversaires. Ce qu'elles disaient est dans les infobulles. Il ne reste que les
  deux étiquettes rouges, une par moitié, et elles ont désormais la même longueur
  — l'une plus longue que l'autre se lisait comme plus grosse.

- **Le sous-titre *Alliés* disparaît**, ses trois réglages restent, en retrait
  sous *Afficher uniquement le nom des alliés*. Trois lignes ne font pas une
  section, et leurs intitulés disent déjà de qui il s'agit.

  Les trois se grisent avec lui, couleur de classe comprise : c'est en nom seul
  que la couleur remplace ce que la barre de vie disait. Elle cesse aussi de
  peindre — une case grisée dont l'effet resterait posé serait un réglage qu'on
  ne pourrait plus éteindre.

- **Le corps du texte n'a plus d'interrupteur à lui**, sur la barre de vie comme
  sur la barre de sorts : il suit celui de sa barre et se règle juste sous sa
  hauteur. Deux cases pour une seule idée — « je règle cette barre » — coûtaient
  une ligne à chacune des deux et une hésitation à chaque ouverture de la page.
  Prendre la taille d'une barre, c'est prendre celle de ce qui s'y écrit.

- **Le filet d'un en-tête de catégorie ne disparaît plus.** Il était tendu entre
  la droite du titre et le bord de la colonne : un titre long le réduisait à
  rien, et il s'éteignait — pas sur toutes les catégories en même temps, chacune
  ayant sa longueur de titre, donc sa largeur de fenêtre à laquelle elle perdait
  sa marque. On voyait alors une page où certaines catégories avaient le rang
  qu'elles ont et d'autres non, selon le coin qu'on venait de tirer. Le filet a
  désormais un plancher que le titre lui cède, quitte à être coupé — ce qui
  n'arrive qu'à une largeur où il débordait déjà de sa colonne. Toutes les pages
  de l'addon sont concernées.

- **Le filet d'un en-tête de catégorie se voit.** Il était à trente pour cent
  d'un doré déjà sombre, sur un fond translucide : autant dire nulle part. À
  cinquante-cinq, il fait ce pour quoi il est là — dire qu'un titre ouvre une
  catégorie, et distinguer celle-ci d'un en-tête subordonné, qui n'en a pas.
  Toutes les pages en profitent.

  La largeur et la hauteur remontent juste sous l'interrupteur qui les commande.
  *Visibilité* disparaît en tant que catégorie : ses trois opacités ferment la
  barre de vie, au-dessus des réglages d'alliés.

- **Les opacités par défaut deviennent 100 / 90 / 50** — la cible, les autres, ce
  qui est derrière un mur. Les anciennes valeurs venaient du client et
  effaçaient trop.

- **L'infobulle des barres d'infos simplifiées disait le contraire de ce qui se
  passe.** Elle promettait « affichée sous forme de nom seul », qui est le
  réglage d'à côté : une plaque simplifiée ne garde pas le nom, elle ne garde
  *rien* — une barre nue. Les quatre cases partagent cette infobulle, et elle dit
  maintenant ce que le jeu fait, avec la distinction en toutes lettres.

- **« (pixels) » disparaît de tous les intitulés.** Une taille se règle en
  regardant l'écran, pas son unité.

### Ajouté
- **Un interrupteur pour la superposition**, avec ses deux valeurs à nous
  (0,50 à l'horizontale, 0,80 à la verticale). Les deux glissières écrivaient
  jusqu'ici en direct dans le réglage du jeu, et **sautaient toutes seules** : le
  jeu réécrit ces valeurs chaque fois qu'il refait ses plaques. Elles sont
  désormais empruntées comme la taille et l'opacité — reposées derrière lui,
  rendues telles quelles en décochant.

- **« Régler la taille » pousse le calibre du jeu à 5 et le verrouille.** La
  largeur et la hauteur en pixels ont besoin de la plus grande boîte que le jeu
  sache faire pour disposer de toute leur course ; à un calibre plus petit, la
  moitié de la course ne faisait rien. Le réglage est rendu tel qu'il était en
  décochant.

  L'échelle des auras et l'espacement des affaiblissements, eux, **cessent
  d'être grisés** avec lui : ce sont des mesures d'auras, et nos pixels ne les
  décident pas.

- **Cocher « Colorier selon la menace » éteint la couleur de menace du jeu** —
  *Couleur de la barre de vie*, dans son groupe *Affichage de menace* — et grise
  sa case tant que la nôtre est allumée. Les deux repeignent la même barre pour
  dire la même chose : ensemble, c'est la dernière qui a peint qui gagnait, et le
  joueur voyait une couleur qui n'était ni la sienne ni celle du jeu. Le réglage
  est emprunté, donc rendu en décochant.

- **Cocher « Joueurs alliés — nom seul » décoche « barre simplifiée pour les
  joueurs alliés »**, et la grise tant qu'il est allumé. Les deux réduisent la
  même plaque à la même chose ; cochés ensemble, le second ne faisait rien de
  plus, mais restait coché.

### Corrigé
- **Le nom d'un adversaire s'écrit en blanc**, joueur comme PNJ. Il portait la
  couleur de sa classe, et deux choses l'ont défait : le client donne une classe
  à beaucoup de PNJ — un garde humanoïde est « guerrier » à ses yeux, et la
  moitié d'une zone se retrouvait peinte sans que personne l'ait demandé — et
  surtout la classe est déjà dite par la **barre de vie**, que *Couleurs de
  classe sur les joueurs adverses* teinte pour cela. Un nom qui la répète ne dit
  rien de plus, et s'écrit par-dessus une barre de la même teinte. Le blanc se
  lit sur n'importe quelle couleur.

- **Une plaque sur treize était suivie.** Le module identifiait les plaques par
  `namePlateUnitToken`, le champ que tout le monde cite — et que ce client laisse
  vide : treize plaques à l'écran, treize champs absents, une seule plaque
  connue, celle qu'une annonce venait de donner. Tout ce qui se pose plaque par
  plaque en dépendait, et tous les symptômes en découlaient : les aperçus
  n'apparaissaient que sur une plaque, ne s'effaçaient jamais de celles qu'on
  avait cessé de suivre, leur animation se figeait dès que la plaque suivie
  changeait de main, et changer un réglage ne repeignait qu'elle.

  L'unité se lit maintenant sur le cadre d'unité quand le jeton manque — le
  chemin que le hook des couleurs de nom emploie depuis toujours, et qui n'a
  jamais failli.

- **Le recensement des plaques pouvait effacer ce qu'il ne savait pas
  reconstruire.** Il commençait par vider la liste, puis demandait au client
  celles qui sont à l'écran — et ce client-là ne répond pas toujours. On perdait
  alors tout ce que ses annonces nous avaient appris, à chaque repeinture
  complète, c'est-à-dire à chaque réglage touché : plus rien n'était peint
  jusqu'au prochain rechargement. C'est ce qui obligeait à recharger pour entrer
  et sortir des aperçus. La liste ne se remplace désormais que lorsqu'il y a de
  quoi la remplir.

- **Les lignes d'une page sont posées sur la grille de l'écran.** Une ligne à un
  demi-pixel du bord y est dessinée à cheval sur deux rangées : son texte pâlit
  et ses bords bavent. Comme chacune tombait à un endroit différent de la grille,
  deux lignes voisines n'avaient pas tout à fait la même netteté.

- **Une plaque déjà à l'écran pouvait n'être jamais suivie.** La liste des
  plaques est tenue par les annonces du client, et il ne réannonce pas ce qui
  était déjà là — après un `/reload`, ou en allumant le module devant quelqu'un,
  sa plaque restait inconnue pour toute la session. Rien n'y était peint, et
  cocher une case ne changeait rien sur elle : c'est ce qui faisait croire que
  les couleurs de classe des alliés ne répondaient pas. Le recensement se refait
  maintenant à chaque repeinture complète.

- **La page d'options ne suivait pas la fenêtre.** Sa largeur est écrite une fois,
  quand on ouvre la page, et rien ne la reposait ensuite : une fenêtre retaillée
  laissait la page se disposer pour l'ancienne. C'est ce qui coupait les
  paragraphes à la mauvaise mesure et ce qui éteignait le filet des en-têtes — un
  calcul juste, fait pour une fenêtre qui n'existait plus.

  Le premier affichage souffrait du même mal à l'envers : la fenêtre venait
  d'être élargie, et la zone de contenu n'a sa nouvelle taille qu'à l'image
  suivante. On déduit désormais cette largeur au lieu de la lire — on sait de
  combien on a poussé le cadre.

- **Les noms alliés en couleur de classe, bloqués en blanc en instance.** En
  donjon, en raid et en champ de bataille, le client refuse de dire si une unité
  est un joueur : la réponse est *secrète*, et l'addon la lisait comme « non ».
  Chaque allié y passait donc pour un PNJ, peint en blanc avant même qu'on
  regarde la case. Le camp se décide maintenant sur ce qu'on a le droit
  d'attaquer, seule question à laquelle le client réponde partout.

### Retiré
- **« Noms aux couleurs de classe » pour les alliés.** Le jeu le fait désormais
  de lui-même, et mieux que nous : lui seul lit l'identité qu'il protège en
  instance. Une case qui promet ce qui arrive déjà est une case qui ment.
  L'addon ne touche plus du tout au nom d'un allié ; celui d'un adversaire garde
  la couleur de sa classe, qui n'a jamais été un réglage.

- **Tous les filets.** Il n'y en a plus sous le titre de page, plus à droite des
  en-têtes de catégorie, plus autour des bandeaux de la navigation.

  Un trait d'un pixel ne tient pas sur un écran dont l'échelle d'interface n'est
  pas entière : il tombe entre deux rangées de la grille et s'y dessine tantôt
  net, tantôt étalé sur deux, tantôt pas du tout — et comme chaque ligne d'une
  page atterrit à une phase différente, deux catégories voisines ne se
  ressemblaient jamais. Épaisseur arrondie à la grille, position arrondie,
  lignes arrondies : il restait le défilement, qui décale la page d'une fraction
  à chaque cran de molette, et rien de ce que nous maîtrisons ne rattrape cela.

  Ce qui hiérarchise est resté, et c'est ce qui hiérarchisait déjà : la casse,
  la couleur, le corps, le retrait et le blanc avant un titre. Le filet ne
  faisait que confirmer — mal.

- **La rangée d'entraves de l'addon.** Elle marchait, et c'est ce qu'elle
  demandait pour marcher qui la condamne : lire les auras d'un adversaire, ce
  que le client protège le plus, en composant avec des valeurs secrètes, des
  filtres classés et une durée devenue objet opaque — trois choses qui ont
  changé deux fois en un an. Une extension suffit à casser la rangée, et une
  rangée d'entraves cassée en plein combat est pire que pas de rangée.

  Le jeu les affiche lui-même, et cela se règle dans sa moitié de la page. Aux
  joueurs qui avaient pris la rangée, l'addon rend au jeu la catégorie qu'il lui
  avait éteinte, à la première connexion et une seule fois.

  Le code reste dans le dépôt, entier et éteint par un booléen, comme les autres
  sections mises en sommeil.

## 0.8.2 — 2026-08-06

### Modifié
- **Ressource de classe** et **Barres d'action** perdent leur paragraphe
  d'explication. Ce que fait chaque réglage est dans son infobulle, et ce que
  fait la page se voit en cochant.

### Ajouté
- **Une ligne à la connexion pour dire où sont les options.** Un addon dont tout
  est éteint à l'installation ne se manifeste nulle part : rien ne change à
  l'écran, et rien n'indique par où l'ouvrir. C'est le seul message que l'addon
  écrive de lui-même.

  Elle se tait dès que la fenêtre a été ouverte une fois, par n'importe quel
  chemin. Un rappel qui revient pendant six mois n'informe plus, il agace — et
  une case à cocher pour éteindre une ligne coûterait plus d'attention qu'elle
  n'en ferait gagner.

## 0.8.1 — 2026-08-06

### Modifié
- **Barres d'infos** s'appelle désormais *Barres d'infos (En développement)*. La
  mention est dans le nom de la page et non dans un avertissement sous elle :
  c'est avant d'y entrer qu'elle sert.

## 0.8.0 — 2026-08-06

### Modifié
- **Plus aucun réglage n'est livré coché.** Une installation neuve ne change
  désormais rien au jeu tant qu'on n'a rien demandé — ce qui était la règle, et
  ce que sept réglages ne respectaient pas.

  Un seul se voyait : *Noms alliés aux couleurs de classe*, sur les plaques,
  n'avait aucune case maîtresse au-dessus de lui et colorait donc les noms dès
  l'installation. Les six autres attendaient derrière un interrupteur éteint —
  la liste du mode sombre, l'ignorance des quêtes grises, les rangées d'auras —
  et ne se voyaient pas, mais un réglage coché qu'on n'a pas demandé reste un
  réglage coché qu'on n'a pas demandé.

  **Ce qui change pour qui l'utilisait déjà** : le mode sombre n'assombrit plus
  rien tant qu'on n'a pas désigné au moins une chose dans sa liste, et la reprise
  des auras de plaque demande de cocher au moins une rangée. Les réglages que
  vous aviez touchés vous-même sont conservés — seuls ceux laissés tels quels
  suivent le nouveau défaut.

- **Le menu de téléportation et le tiroir d'addons prennent l'habillage de la
  fenêtre d'options.** Ils posaient un aplat de la couleur des fenêtres, qui
  donne un gris bleuté là où la fenêtre d'options est presque noire : la même
  couleur y multiplie la pierre du client au lieu de se poser telle quelle. Le
  contour passe du creux au contour ouvragé des dialogues — celui de la fenêtre
  d'options, sans la bande de titre.

  Les trois panneaux flottants partagent désormais une seule fonction
  d'habillage, ce qui est la seule façon qu'ils restent d'accord.

- **Panneau de contrôle** — le décompte du pull passe de huit à dix secondes, et
  les deux paragraphes de bas de section disparaissent.

- **BL & Résurrections** — l'aperçu et le verrou passent devant les réglages
  d'apparence. Ce sont les deux gestes qui **posent** le suivi ; on n'en règle la
  taille qu'une fois qu'il est en place et qu'on le voit.

### Corrigé
- **Journalisation — elle s'arrête vraiment en sortant.** Le module ne coupait
  que ce qu'il avait lui-même allumé, pour ne pas défaire un démarrage manuel.
  Sauf que ce souvenir ne survit ni à une reconnexion ni à un `/reload` : entré
  en donjon puis rechargé, on ressortait avec la journalisation toujours en
  cours, et rien ne le disait.

  Il compare désormais l'état réel du client à ce que le réglage demande, et
  écrit une ligne à chaque bascule. Le réglage promet « en instance, oui ;
  dehors, non » — il ne pouvait pas le tenir en s'interdisant de couper.

- **Passer les cinématiques ne faisait rien.** Les deux fenêtres de lecture
  vivent dans des modules du jeu chargés à la demande : à l'allumage du module
  elles n'existent pas encore, et l'accroche aux touches, tentée une seule fois,
  repartait sans rien accrocher. Elle se retente maintenant au début de chaque
  séquence, moment où les cadres existent forcément.

## 0.7.18 — 2026-08-06

### Corrigé
- **Recherche de groupe — la fenêtre de rôles ne clignote plus.** La validation
  automatique fonctionnait, mais la fenêtre du jeu s'ouvrait quand même le temps
  d'un battement de cils avant de se refermer.

  Répondre à l'événement ne l'empêchait pas d'ouvrir : le client s'abonne au même
  événement pour l'afficher, et l'ordre entre deux abonnés n'est pas défini —
  répondre « avant » lui n'avance que le moment où elle se referme. Elle est
  désormais supprimée à son ouverture, ce qui la rend jamais dessinée plutôt que
  brièvement visible.

  La réponse est envoyée des deux côtés, avec un drapeau pour n'en envoyer qu'une :
  la fenêtre n'est jamais masquée sans que la demande ait reçu une réponse.

### Modifié
- **Clés mythiques** — les deux paragraphes de bas de section disparaissent :
  celui qui détaillait la forme de la réponse à `!keys`, et celui qui listait les
  conditions du dialogue de donjon. Ce qu'ils avaient d'utile tient dans les
  infobulles.

  Celle de *Parler aux PNJ à votre place* tient en une ligne : ce que le réglage
  fait, et trois endroits où on le voit faire.

- **Chat — la fenêtre de copie s'ouvre là où vous lisez.** Elle présentait
  l'historique par son début, c'est-à-dire ce qui s'est dit il y a une heure à
  quelqu'un qui vient de lire la dernière ligne. Elle s'ouvre désormais à hauteur
  du bas du chat — ou de l'endroit où vous l'avez remonté.

  Le repère est approximatif d'un cran vers le haut, et c'est délibéré : on
  arrive juste au-dessus de son point de lecture, avec le contexte devant soi.

- **Chat — la fenêtre de copie ne sélectionne plus tout d'office.** On y vient
  chercher trois lignes, pas l'historique entier : la sélection posée d'avance
  était à défaire avant de faire la sienne, et un `Ctrl+C` réflexe emportait tout
  le reste sans prévenir. `Ctrl+A` reste là pour qui veut vraiment tout.

## 0.7.17 — 2026-08-05

### Ajouté
- **Fiche de personnage — le niveau d'objet du personnage, au-dessus des armes.**
  Un seul nombre pour toute la fiche, là où le reste du module en pose seize : il
  répond à une autre question. Les seize disent laquelle des pièces traîne,
  celui-ci dit où en est le personnage — et le jeu ne l'écrit nulle part sur
  cette fiche.

  C'est le niveau **porté**, pas celui que les sacs promettent : le jeu rend les
  deux, et le premier annonce un équipement qu'il faudrait aller chercher. Sur
  une fiche d'inspection, ce chemin n'existe pas et les seize pièces sont
  moyennées, ce qui est exactement ce que le jeu fait lui-même.

  Écrit « Ilvl : XXX », centré sur la paire d'armes et non sur l'une des deux, et
  coloré comme les pièces le sont : à la piste d'amélioration la plus répandue de
  l'équipement — orange pour Mythe, violet pour Héros, et ainsi de suite.

  Sa case ouvre la page, avant les nombres qui parlent des pièces, et un réglage
  dit combien de **décimales** on veut derrière — de zéro à deux. Au-delà le
  nombre n'apprend plus rien : une moyenne de seize entiers est un multiple de
  0,0625, et la troisième décimale ne sépare aucun équipement qu'on puisse
  porter.

### Supprimé
- **Fiche de personnage — sertir une gemme depuis la fiche.** Le geste est
  retiré. Il ne tenait pas sa promesse : le cadre de sertissage du jeu ne se
  remplit pas sur-le-champ, il se demande au serveur, et le geste dépendait donc
  d'un aller-retour qu'aucune reprise ne rendait fiable.

  Reste ce qui répondait à la question posée : **une icône par châsse**, la gemme
  et son infobulle quand il y en a une, la châsse vide quand il n'y en a pas.
  C'était la vraie utilité de cette rangée — dire ce qui manque. Le sertir se
  fait très bien depuis les sacs, et un raccourci qui échoue une fois sur deux
  vaut moins qu'un chemin qui marche toujours.

### Corrigé
- **Fiche de personnage — l'étoile d'enchantement ne ment plus sur le rang.**
  Elle montrait l'étoile dorée quelle que soit la qualité de l'enchantement. Deux
  causes : le rang se cherchait sous un nom d'atlas précis, alors que le jeu
  écrit cette étoile tantôt par un atlas et tantôt par un chemin de texture ; et
  faute de rang lisible, on posait l'étoile la plus haute.

  Ce second choix était le pire des deux : une étoile dorée ne dit pas « rang
  inconnu », elle dit « rang maximum » — une affirmation qu'on n'avait pas les
  moyens de tenir. Un rang illisible affiche désormais l'icône du métier, qui dit
  exactement ce qu'on sait : la pièce est enchantée.

- **Fiche de personnage — le niveau d'objet du personnage suit l'équipement.**
  Changer de pièce ne le faisait pas bouger : il fallait fermer la fiche et la
  rouvrir. Le jeu ne recalcule pas ce nombre au moment où l'on s'équipe, il le
  recalcule juste après et le dit alors — on repeignait donc avant la mise à
  jour, avec l'ancienne valeur. La fiche écoute désormais ce second signal.

### Modifié
- **Fiche de personnage — l'étoile d'enchantement est celle du jeu, recopiée.**
  On n'en lisait que le numéro pour redessiner l'étoile de son côté, ce qui
  supposait de savoir de quelle famille d'icônes il s'agissait. Le jeu en a
  plusieurs, et le rang d'un enchantement ne se compte pas sur la même échelle
  que la qualité d'une pièce d'équipement : d'où le cuivre et l'orange là où
  l'infobulle montre de l'argent et du jaune.

  L'icône est désormais reprise entière de l'infobulle. Elle est donc exactement
  celle que vous y voyez, quelle que soit l'échelle et quoi qu'en fasse une
  prochaine extension.

- **Ressource de classe** — la description de *Nombre de cases* tient en une
  phrase, suivie de deux exemples. Elle expliquait le mécanisme avant de dire à
  quoi il sert.

- **Chrono mythique+** — le paragraphe de bas de page disparaît. Les paliers du
  jeu et ce que le module ajoute au chrono se voient sur l'aperçu, qui est juste
  au-dessus.


- **Fiche de personnage** — *Afficher le niveau d'objet* devient *Afficher le
  niveau d'objet des pièces*, maintenant qu'un second réglage parle du niveau
  d'objet du personnage.

## 0.7.16 — 2026-08-05

## 0.7.15 — 2026-08-05

### Ajouté
- **Barres d'infos — les icônes d'entraves portent le contour de l'addon.** La
  rangée de contrôles était le seul endroit de l'addon où une icône n'avait pas
  le contour commun : elle portait un liseré carré d'un pixel, et l'image du
  sort gardait par-dessus le bord noir que le jeu dessine dedans — deux bords
  collés, d'où l'aspect anguleux à côté de tout le reste.

  Une icône de la rangée porte désormais la **bordure de sort du jeu**, aux coins
  en biseau — celle que le mode sombre pose déjà sur toutes les autres icônes
  d'auras —, et l'image est rognée pour ne pas doubler le trait. Elle reste
  **teintée selon la nature de l'aura** : ce que disait le liseré n'est pas
  perdu, il est passé dans le trait.

  Le contour se dessine à pleine couleur, et **fonce avec le reste de l'interface
  quand le mode sombre teinte les auras** — la rangée suit la case sans qu'on ait
  à la régler deux fois. Une case *Contour de l'addon sur les icônes* permet de
  revenir au liseré carré ; elle est cochée d'origine, et ne décide de rien tant
  que la rangée n'est pas prise au jeu.

- **Cadres d'unités — agrandir les cadres d'arène.** Un second réglage, jumeau de
  celui des cadres de groupe : les cadres des adversaires en arène dépassent la
  borne du curseur du mode Édition. Les deux ont leur propre échelle — un cadre
  de groupe se lit en donjon, un cadre d'arène à trois contre trois, et rien ne
  dit que la même taille convienne aux deux.

  Les **deux styles** sont couverts, celui du jeu et celui façon raid : le mode
  Édition sait lequel est à l'écran, nous non, et mettre à l'échelle un cadre
  caché ne coûte rien.

  La taille se pose pendant la **phase de préparation** : le jeu refuse de
  redimensionner ces cadres pendant le combat, et une manche d'arène en est un du
  début à la fin. Posée portes fermées, elle tient jusqu'au bout.

- **Ressource de classe — trois paliers de couleur au lieu d'un.** Chacun a son
  nombre de points et sa teinte, et **le plus haut atteint écrase les autres** :
  à sept points avec des paliers à trois, cinq et huit, c'est celui de cinq qui
  parle. Les deux nouveaux arrivent déjà teintés — l'or, puis l'orange, puis le
  rouge, le même vocabulaire de montée que partout ailleurs dans l'addon — et
  restent gris tant que le palier du dessus n'est pas posé.

- **Ressource de classe — un effet brillant autour de la rangée.** Le contour
  entier s'allume d'un liseré doré qui s'estompe de part et d'autre, ses quatre
  coins noyés dans une boule de lumière pour que l'angle droit ne se lise plus.
  Huit petites **comètes** régulièrement espacées en font le tour par-dessus :
  des bandes arrondies aux deux bouts, plus hautes en tête qu'en queue, à peine
  plus épaisses que le trait qu'elles parcourent.

  L'or plutôt que la teinte de la rangée : c'est la couleur que le jeu donne à
  tout ce qui s'allume, et elle veut déjà dire « maintenant ». Les cases disent
  où l'on en est, la lueur dit que c'est prêt.

  Deux matières, et chacune pour ce qu'elle sait faire. Le fond est de la
  **couleur pure**, la seule qui s'étire sans se dégrader — une image détaillée
  agrandie quatre fois devient floue, et aucun réglage ne lui rend les pixels
  qu'elle n'a pas. Les éclats sont une image, mais qui n'est qu'un **fondu
  radial** : ni trait ni contour, rien qui puisse se créneler — et c'est
  exactement ce qu'un aplat ne sait pas faire, lui qui s'arrête toujours net.

  Elle a son **propre seuil**, indépendant des paliers de couleur : deux façons
  de dire « c'est prêt », et rien n'oblige les deux à tomber au même endroit.
  Rien ne tourne tant qu'elle n'est pas à l'écran.

### Modifié
- **Fiche de personnage — le niveau d'objet rejoint le rang d'amélioration.** Les
  deux étaient séparés, l'un posé sur l'icône et l'autre dans la colonne à côté.
  Ce sont pourtant deux mesures de la même chose — ce que vaut la pièce — et on
  les compare l'une par l'autre : un 289 au rang 6/6 ne se lit pas comme un 289
  au rang 1/8, le second ayant encore de la marge. Séparés, il fallait porter
  l'œil à deux endroits pour répondre à une seule question.

  Ils tiennent maintenant sur une ligne, `289 (6/6)`, et **l'ordre s'inverse d'une
  colonne à l'autre** : le niveau se range toujours contre l'icône, le rang
  toujours vers l'extérieur. C'est ce qui aligne les niveaux d'objet des deux
  colonnes contre le modèle, là où l'œil les parcourt.

  Leur couleur est celle de la **piste d'amélioration** et non de la qualité de
  l'objet — orange pour le mythe, violet pour l'héroïque, bleu pour le champion,
  vert pour le vétéran, blanc en dessous. En fin de saison, toutes les pièces sont
  épiques : la qualité ne distingue plus rien, là où la piste dit exactement d'où
  vient la pièce. Ce sont les couleurs des qualités d'objet, reprises telles
  quelles : c'est une échelle que le joueur lit déjà partout, en inventer une
  seconde lui ferait apprendre deux fois la même hiérarchie.

  La case *Signaler les améliorations incomplètes* disparaît avec : le rang n'a
  plus de teinte à lui.

- **Fiche de personnage — les pastilles « Enchantement » et « Gemme » deviennent
  des icônes.** Elles nommaient la question et laissaient la couleur y répondre,
  ce qui obligeait à lire pour savoir de quoi on parlait.

  L'enchantement porte désormais **l'étoile de rang du métier**, celle que le jeu
  pose déjà au bout de la ligne d'enchantement d'une infobulle — dorée au rang
  maximum, terne aux premiers. Sans enchantement, c'est l'icône du métier,
  éteinte : une icône désaturée se lit comme une case vide, sans un mot.

  Les gemmes suivent sur la même rangée, **une icône par châsse** : la gemme
  sertie, ou la châsse vide. Trois châsses dont une vide se lisent d'un coup
  d'œil quand on voit deux gemmes et un trou ; un « 2/3 » demandait de savoir ce
  que valent les deux nombres.

  Le rang est lu dans le **nom de l'atlas** que le jeu glisse dans la ligne, et la
  ligne est reconnue à son **type** — deux choses qui ne se traduisent pas. Le
  module gagne cet affichage sans gagner une dépendance à la langue.

  Les deux icônes portent l'**infobulle de l'objet** quand il y en a un : devant
  une gemme sertie, ce qu'on veut savoir est ce qu'elle apporte, et le jeu le dit
  mieux que nous. Un enchantement n'a pas de lien d'objet à interroger — c'est
  alors l'intitulé que le jeu écrit dans l'infobulle de la pièce qui est repris.
  Devant une châsse vide, il n'y a rien à demander à personne : c'est à nous de
  dire ce qui manque.

- **Fiche de personnage — le noyau du vide disparaît.** C'était le seul endroit
  du module où une **chaîne traduite** décidait d'un affichage : le noyau ne se
  lisant ni dans le lien de l'objet ni dans ses statistiques, il fallait chercher
  son intitulé dans l'infobulle, et une locale au libellé faux montrait les armes
  et les bijoux en rouge à tort. Le réglage part, et le défaut avec lui.

- **Fiche de personnage — sertir une gemme depuis la fiche.** Un clic sur une
  châsse ouvre la liste des gemmes de vos sacs ; en choisir une la sertit.

  Tout se fait pendant le traitement du clic, et c'est une contrainte du jeu :
  le sertissage n'est permis que là. Rien ne peut être différé — d'où un geste en
  deux clics et non un enchaînement automatique. Si le jeu refuse la validation,
  la gemme reste sur le curseur avec sa fenêtre ouverte, et le geste s'achève à
  la main : c'est une dégradation, pas une panne.

  Seulement sur son propre équipement : on ne sertit pas la pièce de quelqu'un
  qu'on inspecte, et le jeu ne le permettrait pas davantage.

- **Clés mythiques — les repères de palier deviennent de fines pilules dorées.**
  Les deux marques posées sur la barre du chrono, aux paliers +2 et +3, sont
  désormais la **même pilule ambre** que celle de la ressource de classe : mêmes
  teintes, même dessin. Deux endroits qui disent « ce palier est acquis »
  n'avaient aucune raison de le dire de deux façons.

  Fines, et **entièrement contenues dans la barre** : un repère qui en sort se
  lit comme une marque posée devant elle plutôt que dedans.

  Pas de halo autour, contrairement à la ressource de classe. La différence n'est
  pas de goût : là-bas la lueur bouge, et c'est elle qui dit qu'il se passe
  quelque chose. Ici le repère est fixe et permanent — un halo autour d'une marque
  immobile n'ajoute rien à ce qu'elle dit, il l'épaissit.

  Leurs mesures se déduisent de la hauteur de la barre relevée à l'exécution, et
  non de nombres écrits en dur : le client a retouché la sienne d'une extension à
  l'autre.

- **Clés mythiques — l'aperçu passe en tête de la page.** On l'allume, puis on
  règle les trois cases suivantes en voyant ce qu'elles font. En dernier, on
  découvrait son existence après avoir coché à l'aveugle.

- **Toutes les glissières — la valeur se tape au clavier.** Le nombre posé à
  droite d'une glissière est désormais dans une **case de saisie** : clic droit
  dessus, on tape la valeur, Entrée valide et Échap annule. La virgule est
  acceptée comme le point.

  Une glissière règle vite mais mal : à cent crans sur cent soixante pixels,
  viser un nombre précis se fait au pixel près. Et c'est le cadre autour du
  nombre qui dit qu'on peut le saisir — une infobulle ne se lit que sur ce qu'on
  soupçonne déjà d'être cliquable. La valeur qui s'inscrit reste celle que la
  glissière retient : bornée, et sur un cran.

- **Regrouper les boutons d'addons** — l'infobulle dit maintenant, en premier,
  le geste qui rouvre le tiroir : un clic gauche sur le bouton BshamelUI.

- **Menu du jeu** — la section s'intitule « Menu du jeu (Échap) ». Le menu n'a
  pas de nom affiché en jeu ; c'est la touche qui l'ouvre qui le désigne.

- **Ressource de classe — la rangée boucle au lieu de s'allonger.** *Cases par
  rangée* devient **Nombre de cases**, et ne plie plus la rangée sur une seconde
  ligne : au-delà du nombre demandé, elle repart de zéro dans les mêmes cases.

  C'est ce qu'on cherchait en pliant : faire tenir dix cumuls d'Arme-tempête dans
  l'encombrement de cinq. Sauf qu'une seconde ligne double la hauteur au lieu de
  la garder — on voulait **cinq grandes cases plutôt que dix petites**, au même
  endroit et de la même taille à l'écran.

  Une rangée pleine veut alors dire cinq points ou dix, et c'est assumé : le
  changement de couleur du palier dit à quel tour on en est, le nombre au milieu
  aussi si on l'affiche. L'aperçu montre le tour complet, boucle comprise.

  Le réglage existant est repris tel quel — cinq voulait dire « cinq de large »
  et veut toujours dire cela ; seul change ce qui arrive à la sixième.

- **Ressource de classe** — la première case s'intitule *Afficher la ressource de
  classe* plutôt que *Afficher la rangée*, et la page ouvre sur une section
  *Général* au lieu d'aligner trois cases sans en-tête. **Mode sombre** ouvre de
  la même façon, pour la même raison : une case seule sous rien du tout se lit
  comme un reste, pas comme un début.

- **Fenêtre d'options — les intitulés longs ne sont plus coupés.** « Augmenter la
  distance maximale de la caméra » s'arrêtait en chemin : la colonne des
  contrôles était à une abscisse fixe, et ce qui ne tenait pas avant elle était
  tronqué.

  La colonne recule maintenant jusqu'au plus long libellé qu'elle porte, sans
  jamais dépasser la place que les contrôles réclament à droite. C'est la
  **colonne entière** qui bouge, jamais la ligne fautive seule — une case décalée
  au milieu de dix autres se lirait comme un défaut d'alignement, ce qui est pire
  que le texte coupé qu'on voulait réparer. Rien ne passe à la ligne : ces lignes
  ont une hauteur fixe.

- **Cadres d'unités — trois sections au lieu de quatre.** *Masquer la couleur de
  réputation* rejoint *Décorations*, où sont déjà les quatre autres « masquer » ;
  *Afficher l'icône de spécialisation* rejoint *Apparence*, où elle est la
  deuxième façon de changer ce qu'un cadre montre. La section *Spécialisation*,
  qui ne portait qu'une ligne, disparaît. Aucun réglage ne change de valeur ni de
  nom : ce qui était coché le reste.

### Corrigé
- **Copie du chat — elle ne rend plus rien du tout sur une ligne protégée.** Le
  jeu rend certaines lignes en valeur *secrète*, celles où il protège l'identité
  de quelqu'un. Une chaîne secrète est bel et bien une chaîne : le garde de type
  la laissait passer, et c'est le nettoyage des couleurs qui levait — une erreur,
  et la copie entière abandonnée.

  Une ligne qu'on n'a pas le droit de lire est désormais **sautée**. On perd
  cette ligne-là dans le presse-papier ; on perdait tout jusqu'ici.

- **Barres de vie aux couleurs de classe — les boss ne prennent plus la couleur
  du joueur précédent.** Un cadre d'unité est réemployé : la même barre montre un
  chaman, puis le boss qu'on cible ensuite. Or le jeu ne repeint pas une barre de
  vie à chaque mise à jour — il pose son vert une fois et n'y revient que pour
  dire quelque chose, une unité pillée par un autre ou un joueur déconnecté.
  Notre bleu de chaman restait donc en place, et le boss suivant en héritait.

  La barre est désormais **rendue** dès que l'unité n'est plus un joueur, dans
  l'état exact où le jeu l'avait laissée. Les réponses que le jeu garde secrètes
  sur l'identité d'une unité comptent au passage comme « ce n'est pas un
  joueur » : c'est le seul repli sûr, et certains PNJ ont bel et bien une classe
  dans les données du jeu — chaman compris.

- **Mode sombre — il ne coûte plus rien en combat.** Le module se remettait au
  travail à chaque aura qui battait quelque part : celles des dix-neuf autres
  membres du raid, celles de leurs familiers, celles de chaque mob du pull. Aucune
  de ces auras n'a jamais eu la moindre texture à l'écran chez nous — le mode
  sombre ne teinte que vos propres buffs, ceux de la cible et du focus. En raid
  comme en clé, il repassait donc l'interface entière cinq fois par seconde pour
  reteindre exactement les mêmes textures, et c'était devenu le premier poste de
  dépense de l'addon.

  Il n'écoute plus que les unités qu'il dessine, et le nom de chaque texture — la
  lecture la plus chère du parcours — n'est relevé qu'une fois au lieu de deux
  fois par passage. Rien ne change à l'écran.

- **Barres d'infos — elles ne se repeignent plus en entier à chaque point de vie
  perdu.** Le module refaisait tout son travail sur une plaque chaque fois que le
  jeu y repeignait la barre de vie : hauteurs, corps de texte, textures, opacité,
  rangée d'auras, marqueur. Sur une pull de quinze mobs, cela voulait dire
  quelques centaines de passages par seconde pour reposer, à chaque fois, des
  valeurs que rien n'avait changées.

  Un battement de vie ne repose plus que les **deux couleurs** que le jeu vient
  d'effacer — c'est la seule chose qu'il ait défaite. Tout le reste garde ses
  propres accroches, qui reposent chacune leur réglage à la milliseconde où le
  jeu y touche, et se refait aux moments qui le méritent : une plaque qui change
  de main, un changement de cible, de camp, de menace, un réglage modifié. Les
  marqueurs de ciblage, eux, suivent désormais l'annonce du jeu au lieu d'être
  rattrapés au passage. Rien ne change à l'écran.

- **Barres d'infos — le nom des alliés ne vire plus au blanc en instance.** En
  donjon, en raid et en champ de bataille, le jeu protège l'identité des unités :
  la classe ne se lit pas. L'addon posait alors un blanc, qui recouvrait la
  teinte que le jeu aurait mise — un repli plus gênant que l'absence de réglage.

  Le jeton de classe est désormais **transmis au jeu sans être lu**, ce qu'il
  autorise : la couleur de classe s'affiche donc aussi en instance. Et s'il
  refuse ce passage, l'addon ne pose plus rien du tout et lui laisse la main de
  bout en bout.

## 0.7.14 — 2026-08-04

### Ajouté
- **Clés mythiques — parler aux PNJ du donjon.** Un nouveau réglage clique pour
  vous la seule ligne d'un dialogue ouvert dans un donjon : les prisonniers à
  libérer à la Fosse de Saron, le bienfait distribué au début de l'Académie
  Algeth'ar.

  **Une seule ligne, ou rien.** Dès qu'un PNJ propose un choix, le choix reste
  au joueur ; un dialogue qui porte une quête reste à la page *Quêtes* et à ses
  propres réglages. Chaque ligne n'est cliquée qu'une fois par conversation, ce
  qui interdit la boucle sur un menu qui se rouvre — et le PNJ qui redonne un
  bienfait répond encore quand on retourne le voir. Rien ne se déclenche hors
  d'un donjon.

- **Ressource de classe**, une nouvelle page sous *Interface*. Une **rangée de
  cases**, une par point : points de combo, puissance sacrée, chi, fragments
  d'âme, charges des arcanes, essence, runes, et les cumuls d'**Arme-tempête** du
  chaman améliorations. La rangée choisit la bonne ressource toute seule au
  changement de spécialisation, et reste cachée sur un personnage qui n'en a
  aucune. Elle n'éteint rien : le jeu continue d'afficher la sienne sous le
  personnage.

  **Elle se place à la souris**, comme les autres panneaux de l'addon, et un
  **aperçu** la remplit case après case pour qu'on puisse la poser — et voir le
  palier se franchir — sans attendre un combat. Une case se verrouille ensuite en
  place.

  **Un palier de couleur** : à partir de X points, toute la rangée prend une
  seconde teinte. C'est ce qui permet de lire « il y a de quoi dépenser » sans
  compter. La teinte des cases pleines vient au choix du jeu, de la classe ou de
  vous ; celle du palier est toujours la vôtre. Largeur, hauteur et écart des
  cases se règlent, le nombre s'affiche ou non au milieu, et la rangée peut
  disparaître tant qu'elle est vide.

  **Un curseur « Cases par rangée »** plie la rangée : à cinq, les dix cumuls
  d'Arme-tempête deviennent deux rangées de cinq. Le pliage se dit en colonnes
  et non en rangées, parce que c'est la seule formulation qui survive à un
  changement de personnage — le nombre de cases, lui, n'est pas au choix du
  joueur. Une rangée qui ne se remplit pas reste calée à gauche, dans l'ordre où
  les cases se remplissent.

- **Barres d'infos — une case « Noms aux couleurs de classe »**, dans une
  nouvelle section *Alliés* qui regroupe les quatre réglages du nom allié.
  **Cochée par défaut** : l'addon posait déjà cette couleur, sans le dire ni
  offrir de l'arrêter. La case ne change donc le comportement de personne, elle
  le rend visible et refusable. Décochée, le jeu reprend la main de bout en bout
  — on ne lui repose pas une teinte, on s'abstient d'en poser une.

  Elle ne vaut que pour les alliés : le nom d'un adversaire garde toujours la
  couleur de sa classe, parce que c'est là que la classe est l'information.

- **Fiche de personnage — les mêmes bandeaux à l'inspection.** Niveau d'objet,
  rang d'amélioration, enchantement, châsses et noyau du vide s'affichent
  désormais aussi sur la fenêtre d'inspection, emplacement par emplacement.

  **Aucun nouveau réglage** : ce sont exactement les mêmes cases de la page
  *Fiche de personnage*. C'est la même fiche et la même question — « qu'est-ce
  qui manque ? » — et deux jeux de cases feraient régler deux fois un seul geste
  de lecture.

  La fenêtre suit la cible tant qu'elle reste ouverte ; les bandeaux la suivent,
  et se vident plutôt que de garder l'équipement du joueur précédent.

### Corrigé
- **Cadres d'unités — des centaines d'erreurs en arène et en champ de
  bataille**, y compris pour qui n'a jamais allumé un seul réglage de la page.
  Pour rendre un portrait au jeu, l'addon lui demandait de le redessiner ; et il
  le lui demandait à chaque changement de cible, même quand il n'avait rien
  peint dessus — c'est-à-dire par défaut. Or cette fonction du jeu cherche à
  savoir si l'unité est vous, réponse qu'il refuse de donner là où il protège
  l'identité des joueurs : appelée depuis un addon, elle lève dans son propre
  code, une fois par cadre et par changement de cible.

  L'addon ne rend désormais que les portraits qu'il a réellement remplacés, et
  il les rend sans entrer dans le code du jeu — il refait le même choix que lui,
  icône de classe ou visage, selon les mêmes réglages.

- **Barres d'infos — le nom des alliés reprend la couleur de classe en mode
  « nom seul ».** L'addon la posait déjà, et le jeu l'effaçait aussitôt : une
  plaque réduite à son nom n'a plus de barre de vie, et le client y repeint le
  nom par des chemins qui ne passent par aucun des deux points où l'on
  repeignait. On se branche désormais sur l'écriture elle-même, ce qui rend le
  chemin sans importance.

- **Mode sombre — les boutons d'action ne perdent plus leurs signaux.** Le
  liseré vert qui marque un **objet équipé** posé sur une barre — un bijou à
  effet utilisable — était assombri avec l'habillage. Il réapparaissait au
  survol, parce que le jeu repeint alors le bouton, puis repartait à
  l'utilisation suivante : une chose qui n'apparaît qu'au survol n'est pas une
  chose qui manque, c'est une chose qu'on efface.

  Le même passage éteignait tout ce qu'un bouton porte d'autre — animation
  d'incantation, réticule de cible, éclat de fin de temps de recharge, halo
  d'attaque automatique. Le mode sombre s'arrête désormais au bouton : ses
  propres textures sont teintées, ce qu'il porte ne l'est pas. L'habillage d'une
  barre, lui, est traité comme avant.

- **Une commande `/bui glow`**, sur le modèle de `/bui auras` : elle écrit dans
  le chat ce que porte le bouton sous le curseur, en signalant les textures que
  le mode sombre a assombries. C'est elle qui a permis de trouver ce qui
  précède — une texture de signal éteinte ne ressemble pas à une texture
  éteinte, elle ressemble à une lueur qui manque.

## 0.7.12 — 2026-08-04

### Retiré
- **Barres d'infos — deux des trois rangées d'auras.** Les **améliorations**
  (gros temps de recharge offensifs et défensifs, à gauche) et **vos
  affaiblissements** (en haut à gauche) ne sont plus affichés par l'addon. Le
  jeu les montre lui-même, et il le fait mieux : ces rangées reposaient sur ce
  qu'il accepte de laisser lire à un addon, et il en protège une partie
  croissante — l'identité d'un sort, ses cumuls, le jugement « ce sort est
  important ». Leurs réglages disparaissent de la page avec elles.

  **Il reste la rangée des contrôles**, à droite de la barre de vie, et le
  marqueur de ciblage. Le classement du jeu ne dit pas ce qu'on veut savoir
  d'une entrave — qui l'a lancée n'a aucune importance quand il s'agit de ne pas
  la casser — et c'est la seule des trois où l'addon ajoute encore quelque chose.

### Ajouté
- **Barres d'infos — la rangée des contrôles se prend ou se laisse.** Une case
  **« Prendre cette rangée »** : cochée, l'addon affiche les entraves et le jeu
  cesse de les montrer ; décochée, il garde les siennes, là où il les met.
  « Régler les auras » ouvre la section, cette case décide.

  Le jeu range ses auras de plaque en quatre catégories et sait les éteindre une
  par une : on n'éteint plus que celle qu'on remplace. Les améliorations, les
  affaiblissements et la perte de contrôle ne sont plus jamais touchés — ils
  tombaient jusqu'ici par ricochet. Les cases du jeu, dans la moitié gauche de la
  page, se grisent en conséquence : celle de la catégorie prise, et elle seule.

  **Le mode aperçu suit la case** : pas d'aura d'exemple là où la rangée est
  laissée au jeu. En régler la position contre un exemple qui ment ne mène nulle
  part — c'est déjà la raison pour laquelle aucune plaque alliée n'en reçoit.

- **Barres d'infos — un curseur « Icônes au plus »** pour la rangée. Rien ne la
  trie : elle se remplit dans l'ordre où le jeu répond, et ce qui permettrait de
  trier est protégé sur un adversaire. Un plafond bas est donc le moyen de la
  garder lisible plutôt que complète.

### Modifié
- **Barres d'infos — la page se lit dans l'ordre où l'on règle.** La moitié
  Bshamel UI suit maintenant : la barre de vie, la barre de sorts, le
  chevauchement des plaques, la visibilité, les auras et le marqueur, puis les
  couleurs et la menace. Les deux barres et la place qu'elles prennent d'abord,
  ce qu'on ajoute ensuite, ce qui repeint en dernier.

  **« Texture des barres » n'est plus une section à part** : ses trois réglages
  ont rejoint la barre de vie, juste avant la largeur — c'est elle qu'ils
  habillent, et un titre pour trois lignes coupait la section en deux. « Cible »
  y passe avant « Les autres » : c'est la barre qu'on regarde et celle dont on
  change la texture en premier.

  Aucun réglage ne change de valeur ni de nom.

### Corrigé
- **Barres d'infos — une unité qui change de camp.** Un contrôle mental rend un
  adversaire allié pour quelques secondes, puis le rend adverse, sans que sa
  barre d'infos change de main. Rien ne relisait cette réponse-là : les rangées
  d'auras, la couleur de la barre et du nom restaient celles du camp précédent
  jusqu'au prochain passage du jeu sur cette plaque — qui peut ne jamais venir.
  Elles se relisent maintenant au moment du changement.

  Le corps du nom allié, lui, ne repartait **jamais** : il se posait quand
  l'unité devenait alliée et restait sur l'adversaire qu'elle redevenait. Il est
  rendu avec le camp.

- **Barres d'infos** — plus d'erreur Lua en rafale devant un adversaire. Quatre
  endroits du module interrogeaient une donnée que le jeu protège sur certaines
  unités **avant** de vérifier qu'elle était lisible ; la vérification passe en
  premier. Celui qui produisait l'erreur en rafale est parti avec sa rangée, les
  trois autres sont corrigés.

## 0.7.11 — 2026-08-03

### Modifié
- **Barres d'infos — ce que chaque rangée montre.** La rangée de gauche affiche
  désormais **les gros sorts offensifs *et* défensifs**, et plus seulement les
  défensifs. Aucun filtre du jeu ne nomme les offensifs — mais le jeu cure déjà
  une liste d'améliorations importantes pour ses propres plaques, et on emprunte
  son verdict au lieu de le refaire. Le repli qui remplissait la rangée de toutes
  les améliorations disparaît : elle dit « les gros sorts », et une rangée vide
  est la bonne réponse quand il n'y en a pas.

  La rangée du haut écarte les procs de bijou et de bonus d'objet pour ne garder
  que vos sorts — **là où le jeu permet de les distinguer**. Le drapeau qui les
  sépare est illisible sur certaines unités, et le tri s'efface alors plutôt que
  de vider la rangée.

  **Aucune aura n'est affichée sur une plaque alliée** — ni amélioration, ni
  affaiblissement, ni entrave, ni temps de recharge, aperçu compris. Le test
  porte sur l'unité et non sur ce que la plaque montre : il tient donc aussi en
  mode « le nom seul ». Les rangées du jeu sur les plaques alliées restent
  éteintes comme les autres tant que l'addon tient les auras.

### Corrigé
- **Barres d'infos — aperçu des auras.** Le décompte ne s'affichait qu'un instant
  après avoir coché la case : les auras d'exemple duraient quinze secondes et ne
  repartaient jamais. Elles se renouvellent maintenant tant que l'aperçu est
  ouvert, ce qui permet de régler le corps du décompte en le voyant.

### Corrigé
- **Téléportation** — le menu ne produit plus d'erreur Lua à la connexion. Le
  temps de recharge d'une ligne se lit en demandant deux nombres au jeu, et le
  client les rend désormais **protégés** sur certaines actions : les comparer
  depuis du code d'addon lève. La lecture s'en écarte maintenant avant de
  comparer ; la ligne concernée s'affiche alors sans horloge — comme une ligne
  prête — et reste cliquable.

## 0.7.10 — 2026-08-03

### Corrigé
- **Barres d'infos** — ouvrir la fenêtre d'options ne rend plus les plaques à
  leur taille Blizzard, et ne produit plus d'erreur Lua dans le code du jeu.
  Les deux avaient la même cause : **l'aperçu**. Monter la maquette du client
  réveillait son gestionnaire de barres d'infos, qui repassait sa mise en page
  sur les vraies plaques en étant teinté par l'addon — d'où l'erreur
  `attempted to iterate a table that cannot be accessed while tainted`, et
  d'où les tailles reposées. L'aperçu est retiré ; il ne reviendra pas, la
  règle « on n'entre pas dans le code de mise en page du client » valant aussi
  pour un template qui l'y fait entrer. L'addon se branche par ailleurs sur
  l'écriture de la boîte des plaques, ce qui le protège des autres écrivains,
  et la taille des auras comme l'espacement des affaiblissements se grisent
  tant que la taille en pixels est tenue — comme le calibre l'était déjà.

- **Barres d'infos** — un PNJ ordinaire n'est plus repeint. Une créature a une
  classe comme un joueur, mais ce champ n'est renseigné avec soin que sur le
  trash de donjon : ailleurs il vaut ce qu'il vaut, et un lynx d'extérieur
  pouvait passer pour un caster. Les couleurs « caster » et « mêlée » ne
  s'appliquent donc plus qu'aux **élites**, là où la donnée veut dire quelque
  chose et où le geste — savoir qui interrompre dans un pack — a un sens. Rare,
  rare-élite, miniboss et boss restent teints partout ; tout le reste garde la
  couleur du jeu.

### Ajouté
- **Barres d'infos — barre de vie.** La texture du remplissage se choisit,
  séparément pour la cible et pour les autres — « couleur vive » (l'aplat) ou
  « couleur standard » (le remplissage des cadres de raid), deux textures du
  client. « Le nom seul » des alliés rejoint le bas de la section Barre de vie,
  avec une taille de nom dédiée pour les joueurs alliés — 12 par défaut, hors
  instance seulement : le jeu y verrouille les plaques alliées. La section
  Visibilité se rallume, resserrée sur les trois opacités — cible, les autres,
  hors de vue — et remonte dans la partie barre de vie ; l'assombrissement est
  parti, et avec lui la mécanique qui guettait l'occultation.
- **Barres d'infos — auras et marqueur.** Les deux sections n'en font plus
  qu'une, et **la pause est levée** : les rangées et le marqueur suivent leurs
  curseurs. Trois choses les en empêchaient, et c'étaient trois erreurs de
  l'addon, pas des limites du jeu — les rangées étaient portées par une région
  que le client repose à chacun de ses passages, elles héritaient de l'échelle
  de la plaque, qui n'est pas la même sur la cible et qui change au clic, et
  elles effaçaient la rangée du jeu pour prendre sa place. Elles sont
  désormais portées par la plaque elle-même, hors de son échelle, et elles
  **s'ajoutent** à celle du jeu au lieu de la remplacer : ce que le jeu montre
  continue de se régler dans sa moitié de la page. Chaque rangée garde sa
  taille, ses deux décalages, son espacement entre icônes et **le corps de son
  décompte** ; le marqueur, sa taille et ses deux décalages. Le temps restant
  s'écrit sur les icônes : le balayage dit « bientôt fini », le chiffre dit
  *quand*, et sur une entrave de huit secondes les deux ne répondent pas à la
  même question. Un curseur par rangée, parce qu'une entrave se lit à la
  seconde près là où un affaiblissement qu'on entretient se lit du coin de
  l'œil.

  Cocher « Régler les auras » **éteint les rangées du jeu** et grise leurs
  cases dans la moitié gauche de la page : deux rangées d'auras sur une plaque,
  ce sont deux fois les mêmes icônes à deux endroits. Elles s'éteignent par les
  propres réglages du client — les trois champs de bits d'affichage d'auras —,
  relevés avant d'être écrits et rendus tels quels au décochage comme à
  l'extinction du module. Le marqueur ne bat plus entre sa place et la
  nôtre : le client le réancre à des moments qui ne sont pas les nôtres, et
  deux écrivains sur la même région se relaient sans converger. Notre ancrage
  est désormais reposé dans le souffle du sien — le même remède que la hauteur
  de barre. Il ne pâlit plus non plus avec sa plaque : une plaque s'efface
  parce qu'elle n'est pas la cible, qu'elle est loin ou derrière un mur, et le
  marqueur est justement ce qu'on y a mis pour être vu de loin.

  Les rangées restaient par ailleurs vides sur une vraie plaque quand elles
  s'affichaient en aperçu : sur une unité adverse, le client rend l'icône d'une
  aura **secrète**, et le tri la refusait pour cette raison. Une valeur secrète
  se transmet pourtant très bien — passée telle quelle, elle peint la bonne
  image ; c'est l'inspecter qui est interdit. Deux conséquences assumées : les
  cumuls ne s'affichent pas (les écrire demanderait de comparer un nombre
  secret), et la liste d'entraves de l'addon ne sert plus de repli, faute de
  pouvoir lire un identifiant de sort. Le classement du jeu, lui, n'a jamais
  eu besoin qu'on lise quoi que ce soit.
- **Barres d'infos — portée des couleurs par nature.** Les couleurs de PNJ
  s'appliquent partout, ou en donjon et raid seulement : dehors, les couleurs
  du jeu reprennent la main sans rien décocher.
- **Barres d'infos — couleur des miniboss.** Une élite exactement un niveau
  au-dessus du joueur a sa propre couleur, séparée de celle des boss.

### Interne
- `/bui auras` écrit dans le chat l'état de la chaîne des barres d'infos, lu
  sur la plaque de la cible : filtres d'auras acceptés ou refusés, conteneurs
  trouvés, rangées montées, échelles empilées. C'est ce qui permet de
  diagnostiquer sur pièces ce qu'un « ça ne marche pas » ne décrit pas.

## 0.7.9 — 2026-08-03

### Interne
- La 0.7.8 est un tag mort : sa pipeline a échoué avant tout envoi — un
  avertissement que seule la CI voyait — et un tag protégé ne se supprime pas.
  Cette version porte exactement son contenu, plus la déclaration qui manquait.

### Ajouté
- **Barres d'infos** — la page annoncée en 0.7.7 s'ouvre, et l'entrée n'est plus
  grisée. Elle ne remplace pas les barres d'infos du jeu : elle règle celles
  qu'il dessine déjà.

  La page est en deux colonnes quand la fenêtre est assez large. **Paramètres
  Blizzard** reflète le menu du jeu, réglage pour réglage — affichage par type
  d'unité, superposition, style, taille en cinq crans, contenu des barres et des
  rangées d'auras, plaques simplifiées, et l'affichage hors écran que le menu ne
  montre pas. Rien n'est recopié : en changer un ici le change aussi dans le menu
  du jeu, et réciproquement. La maquette d'exemple du jeu s'affiche au-dessus du
  style, et suit chaque réglage en direct.

  **Options Bshamel UI** tient ce que l'addon ajoute, et chaque interrupteur rend
  ce qu'il avait pris quand on l'éteint :

  - **Barre de vie** — largeur de la plaque et épaisseur de la barre en pixels,
    corps du texte (nom, niveau, points de vie), et « le nom seul » pour les
    joueurs alliés — un réglage du jeu que son menu cache. Tant que la taille est
    tenue, le curseur de taille du jeu se grise sans que sa valeur bouge.
  - **Barre des sorts** — épaisseur en pixels et corps du texte, réglés sur la
    vraie barre. Sa largeur n'est pas réglable : le jeu la tend entre deux
    ancrages, une largeur imposée y est ignorée.
  - **Superposition** — l'espacement horizontal et vertical entre plaques, deux
    réglages du jeu absents de son menu.
  - **Couleurs des adversaires.** C'est l'unité qui décide, pas la zone : un PNJ
    prend une couleur selon sa nature — boss et miniboss, caster, mêlée, rare,
    rare-élite, reconnus par les classifications du jeu et par la classe que
    chaque créature porte —, un joueur adverse peut prendre celle de sa classe.
  - **Menace, lue selon le rôle.** Pas de couleur « tout va bien » — ce sont les
    couleurs par nature qui parlent. Deux alertes qui priment sur tout : l'aggro
    en train de basculer, et l'aggro changée de mains — perdue pour un tank,
    prise pour les autres.
  - **Mode aperçu** — maintient la vraie barre de sorts à l'écran, en cours
    d'incantation, pour la régler sans attendre le combat.
  - **Auras** — trois rangées dessinées par l'addon avec les images du jeu (nos
    affaiblissements, les offensifs et défensifs importants, les contrôles),
    chacune avec sa taille et ses décalages. La section est **en pause**, grisée :
    les rangées ne suivent pas encore leurs curseurs assez fidèlement.

- **Sélecteur de couleur** dans la fenêtre d'options : une pastille qu'on clique
  ouvre celui du jeu. C'est un type de contrôle de plus dans la fabrique, pas une
  pièce propre aux barres d'infos.

- **Vue compacte.** Un menu dans la barre de titre de la fenêtre d'options règle
  l'échelle de son contenu, de 100 % à 70 %, sans toucher à la fenêtre : il y
  tient d'autant plus de réglages. Ouverte à 75 % par défaut.

### Modifié
- **La fenêtre d'options s'ouvre plus grande** — 1120 × 744 — **et plus dense** :
  lignes resserrées d'un tiers, sous-options en retrait et d'un corps plus
  petit, et la page des barres d'infos se coupe en deux colonnes quand la place
  le permet.

### Corrigé
- **Panneau d'outils de groupe : trois vignettes de marqueur étaient permutées.**
  Les cases 5, 6 et 7 montraient la lune, l'étoile et le rond là où elles posent
  l'étoile, le rond et la lune. Le marqueur posé était le bon — l'index part d'un
  attribut sécurisé, pas de l'image —, c'est bien la vignette qui mentait.
- **Le bouton « retirer tous les marqueurs » ne retirait rien.** Il passait `0` à
  la fonction du client, qui attend un index de 1 à 8 et n'efface tout que si on
  ne lui donne rien : zéro tombait hors de la plage et l'appel se perdait en
  silence.

## 0.7.7 — 2026-08-02

### Ajouté
- **Barre d'infos** apparaît dans *Interface*, grisée et suivie de
  « (Prochainement) » : elle n'est pas encore écrite, et l'entrée est là pour dire
  ce qui vient plutôt que de le laisser deviner. Elle ne s'ouvre pas.
- **Suivi de l'interdiction de Furie sanguinaire**, dans la nouvelle page *BL &
  Résurrections*. Ce qu'il décompte n'est pas la BL — quarante secondes, qu'on
  voit passer — mais le **débuff d'interdiction** qu'elle laisse derrière elle :
  dix minutes, et c'est lui qui décide si le prochain pull en aura une.

  Toutes les classes qui peuvent en donner une sont reconnues : chaman, mage,
  familier de chasseur, évocateur. Chacune pose son propre débuff, sous son propre
  nom ; l'icône du suivi reste celle du chaman, quelle que soit celle qui a
  lancé — ce qu'elle dit est qu'une BL est partie, pas laquelle.

  Une option retire ce débuff de votre rangée d'affaiblissements tant que le suivi
  est allumé : la même information deux fois occupe la place de ce qu'on a
  vraiment besoin d'y lire. Taille, contour sombre, verrouillage et mode aperçu se
  règlent comme pour les résurrections de combat.

- **Les fenêtres de sacs se déplacent.** Elles étaient les seules à ne pas suivre
  le réglage de déplacement des fenêtres. C'est la **pile** qui se déplace, d'un
  seul geste : le jeu continue de décider du nombre de colonnes, du sens de
  remplissage et du mode « sacs combinés », on ne fait que la poser ailleurs. Elle
  se prend par sa **barre de titre** comme n'importe quelle fenêtre, ou par le
  fond de la grille. La molette ne les redimensionne pas — les écarts entre sacs
  sont calculés par le jeu pour leur taille d'origine, et les agrandir les ferait
  se chevaucher.

### Modifié
- **Les réglages ont été rangés.** La colonne de gauche disait où les choses
  étaient posées à l'écran ; elle dit maintenant de quoi elles s'occupent.

  - La catégorie *QoL* s'appelle **Qualité de vie** : **Fenêtres**, **Sacs &
    Réparations**, **Quête**, **Chat**, **Hôtel des ventes**, **Recherche de
    groupe**, **Clés mythiques**, **Téléportations** et **Nuisances**.
  - *Interface* tient tout ce qui touche à l'écran : **Général**, **Mode sombre**,
    cadres d'unité, **barre d'infos** (à venir), barres d'action, gestionnaire de
    temps de recharge, **fiche de personnage** et **chrono mythique+**.
  - *MM+ / Raid* s'appelle **Outils** et tient **Panneau de contrôle**, **BL &
    Résurrections** et **Journalisation**.
  - Les catégories **Jeu** et **Minicarte** ont disparu. La première ne tenait
    plus que deux pages qui appartenaient ailleurs ; la seconde rassemblait trois
    choses qui n'avaient en commun que l'endroit où elles se posent, et l'endroit
    n'est pas un sujet de réglage.

  Aucun réglage n'est perdu ni remis à zéro : tout ce qui avait été changé suit
  son réglage à sa nouvelle place.

- **Général** ne garde que trois choses : le bouton de l'addon, la caméra et le
  menu Échap. Il servait de fourre-tout, et chaque départ s'est fait pour la même
  raison — la **réparation automatique** se déclenche chez le marchand, donc elle
  est dans *Sacs & Réparations* avec la vente de la camelote ; le filtre de
  l'**hôtel des ventes** et les **nuisances** ont leur page.

- Le **mode sombre** a sa page. Il occupait le haut de *Général* avec ses sept
  cases, et il fallait descendre la moitié de la colonne pour atteindre le premier
  réglage qui n'était pas lui.
- **Outils de raid** tenait quatre choses que rien ne rassemblait qu'un même
  moment de la soirée, et la page disparaît. Les deux suivis de réserve vont dans
  *BL & Résurrections*, la journalisation a la sienne, et la barre d'outils de
  groupe rejoint le **panneau de contrôle** du jeu — les deux portent exactement
  les mêmes boutons, on choisit entre eux, et les séparer laissait deux pages dont
  aucune ne le disait.
- Le **menu de téléportation** a la sienne, dans *Qualité de vie*. Ce qu'on y
  règle est le menu, pas la carte à côté de laquelle son bouton se pose.
- Le **bouton BshamelUI** et le **regroupement des boutons d'addons** sont dans
  *Général*, l'un sous l'autre. Ils ne se lisent pas séparément : le tiroir
  s'ouvre sur le bouton, et la case est grisée tant que le bouton est éteint.
- Le **minuteur des fenêtres de file** est passé dans *Recherche de groupe*, le
  seul endroit où on pense à le chercher.
- **La fenêtre d'options s'ouvre plus grande** : 1040 × 720 au lieu de 900 × 620.
  La hauteur est décidée par la colonne de navigation et non par les pages — trois
  catégories et vingt entrées ne tenaient plus, et une colonne qui défile oblige à
  chercher une page qu'on devrait voir. La colonne s'élargit du même coup, pour
  que « Gestionnaire de temps de recharge » tienne sur sa ligne.

### Corrigé
- **Installer l'addon ne change plus rien du tout.** Le masquage du panneau de
  contrôle des cadres de raid était le seul réglage allumé par défaut : un joueur
  qui découvrait Bshamel UI voyait un morceau de l'interface du jeu disparaître
  sans l'avoir demandé. Le motif ne tenait d'ailleurs pas — ce réglage était censé
  remplacer ce panneau par le nôtre, lui-même éteint au premier lancement.

  Ceux qui l'avaient déjà ne perdent rien : le réglage qu'ils avaient est écrit
  explicitement dans leur profil au premier chargement.
- Le **décompte** posé sur la fenêtre d'instance était écrit avec la police des
  dégâts : étroite, immédiatement reconnaissable, et étrangère au reste de
  l'interface. Il reprend la police de l'interface, en plus gros et à contour, et
  se cale au centre de l'icône de rôle plutôt qu'au centre de la fenêtre — où il
  tombait entre le nom de l'instance et l'icône, donc sur rien.
- Sa **couleur** passait du vert au rouge en droite ligne, donc par leur moyenne,
  qui est un olive sombre : à mi-décompte — exactement le moment où on le
  regarde — le chiffre était à son plus terne, alors qu'il devrait commencer à
  alerter. Il passe maintenant par l'orange, et chaque étape reste vive.
- Le clic gauche sur le bouton BshamelUI ouvrait un tiroir vide quand le
  regroupement des boutons d'addons avait été éteint après avoir été allumé. Il
  rend maintenant son clic à la fenêtre d'options.

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
