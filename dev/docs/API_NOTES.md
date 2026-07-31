# Notes d'API

Journal des pièges rencontrés dans l'API du client. Une entrée par problème
résolu : c'est la mémoire technique du projet, et ce qui évite de repayer deux
fois le même bug.

Format : **symptôme → cause → ce qu'on fait**.

---

## Le packager saute l'envoi sans échouer

**Symptôme** — le job `release` construit le zip, affiche « Packaging complete »
puis sort en erreur, sans que rien n'arrive sur CurseForge.

**Cause** — `Skipping upload because "jq" was not found`. Le packager a besoin
de `jq` pour l'API CurseForge. Absent, il n'interrompt pas le build : il
construit l'archive et se contente d'un avertissement noyé dans le log.

**Ce qu'on fait** — `jq` est installé dans le `before_script`, et
`jq --version` est appelé juste après pour que son absence devienne une erreur
franche au lieu d'un avertissement.

---

## La vérification locale ne mesurait pas la longueur des lignes

**Symptôme** — `dev/scripts/lint-local.sh` passe intégralement, la CI échoue
aussitôt sur dix-sept `(W631) line is too long`. Rien dans la sortie locale ne
laissait présager le problème.

**Cause** — `luacheck` n'est pas installable en local (il dépend de
luafilesystem, qui exige un compilateur C sous Windows). `lua-language-server`
le remplace et couvre l'essentiel, **sauf `max_line_length`**. Un avertissement
luacheck étant fatal dans la CI, une simple ligne trop longue suffit à mettre la
pipeline au rouge sans aucun signal préalable.

Le piège vient de la confiance : « le lint local passe » se lit comme « la CI
passera », alors que les deux outils ne vérifient pas la même chose.

**Ce qu'on fait** — `lint-local.sh` a une passe dédiée, qui lit son seuil dans
`.luacheckrc` plutôt que de le recopier. Elle compte les **octets** là où
luacheck compte les caractères : un accent valant deux octets en UTF-8, la
mesure locale est toujours supérieure ou égale à la sienne. L'inégalité est dans
le bon sens — ce qui passe en local passe forcément dans la CI.

---

## Un masque posé sur une texture répétée est ignoré en silence

**Symptôme** — `texture:AddMaskTexture(mask)` ne produit aucun effet. Pas
d'erreur, pas d'avertissement : la texture s'affiche entière, comme si le masque
n'existait pas. On soupçonne donc le masque — fichier introuvable, format
invalide — alors qu'il n'y est pour rien.

**Cause** — la texture était en mode répétition. Les atlas du client dont le nom
commence par `_` (répétition horizontale) ou `!` (verticale) l'imposent, et
`SetAtlas` applique docilement ce mode. `SetHorizTile(true)` a le même effet sur
une texture de fichier. Un masque et une répétition sont incompatibles : le
premier est perdu.

Le piège se referme d'autant mieux que le symptôme oriente vers le masque. Le
signe qui détrompe : **si le masque était en cause, la texture masquée
disparaîtrait** ; qu'elle reste entière prouve que le masque n'est pas appliqué
du tout.

**Ce qu'on fait** — rien : les bandeaux gardent leurs angles droits.

La piste a été poursuivie jusqu'au bout et abandonnée. Ce qui a été vérifié, pour
que personne ne le refasse :

- `CreateMaskTexture` est disponible ; ce n'est pas une question de capacité.
- Aucun atlas de masque **rectangulaire** n'existe sur un client à jour. Les
  masques que Blizzard expose sont circulaires, et un masque circulaire sur un
  bandeau de 230 × 30 l'écrase en ellipse au lieu de l'arrondir.
- Un masque TGA fabriqué pour l'occasion (256 × 32, rayon 8, 32 bits non
  compressé, testé dans les deux orientations, chemin avec et sans extension) n'a
  pas davantage pris.
- Reconstruire la texture d'atlas en mode `CLAMP` via `C_Texture.GetAtlasInfo`
  pour supprimer la répétition n'a rien changé non plus.

La conclusion probable est que le masquage ne prend pas sur cette texture
d'atlas, quelle que soit la façon de la poser — mais elle n'a pas été prouvée. Y
revenir demande de commencer par une bissection : masquer une texture de couleur
unie, sans atlas, pour savoir si la chaîne fonctionne du tout sur cette surface.

---

## `xpcall` avec arguments

**Symptôme** — l'analyse statique signale « expects a maximum of 2 arguments »
sur `xpcall(fn, handler, ...)`.

**Cause** — le `xpcall` de Lua 5.1 standard ne transmet pas d'arguments à la
fonction appelée. Le client World of Warcraft a étendu le sien pour le faire.

**Ce qu'on fait** — on utilise la forme étendue (c'est la bonne au runtime) avec
un `---@diagnostic disable-next-line: redundant-parameter` et ce commentaire.
Ne pas « corriger » en enveloppant dans une closure : cela allouerait une
fonction à chaque dispatch d'événement.

---

## Templates XML

**Symptôme** — `CreateFrame` avec un template inconnu lève une erreur Lua qui
empêche le chargement du fichier entier.

**Cause** — les templates XML de Blizzard sont renommés ou retirés d'une
extension à l'autre.

**Ce qu'on fait** — `C_XMLUtil.GetTemplateInfo(nom)` répond avant de tenter la
création. `T.Template(kind)` encapsule ce test avec une liste de candidats.

---

## Titre d'une fenêtre

**Symptôme** — `frame.TitleText` vaut parfois `nil` selon la version du
template.

**Cause** — le FontString du titre a migré de `frame.TitleText` vers
`frame.TitleContainer.TitleText`.

**Ce qu'on fait** — `findTitleText` dans `UI/Widgets/Window.lua` teste les deux
et crée son propre FontString en dernier recours.

---

## Barre de défilement de `UIPanelScrollFrameTemplate`

**Symptôme** — la barre de défilement recouvre le contenu voisin.

**Cause** — le template ancre sa barre **à l'extérieur** du ScrollFrame, à sa
droite.

**Ce qu'on fait** — la place est réservée dans l'ancrage du ScrollFrame lui-même
(`T.SIZE.SCROLLBAR_W`), pas en réduisant la largeur du contenu.

---

## Ouvrir notre fenêtre depuis le panneau d'options du client

**Symptôme** — actions bloquées « interface action failed because of an AddOn »
après être passé par les options Blizzard.

**Cause** — appeler notre code dans la continuité directe d'un clic dans
`SettingsPanel` propage le taint du panneau.

**Ce qu'on fait** — `HideUIPanel(SettingsPanel)` puis `C_Timer.After(0, ...)`
pour ouvrir notre fenêtre à la frame suivante, hors de la pile d'appels tainted.

---

## `StaticPopupDialogs` et `preferredIndex`

**Symptôme** — un dialogue de confirmation provoque des erreurs de taint chez
certains joueurs.

**Cause** — les index bas de la pile de popups sont partagés avec des dialogues
du client.

**Ce qu'on fait** — `preferredIndex = 3` sur nos dialogues.

---

## Quêtes acceptées sans PNJ

**Symptôme** — après auto-acceptation, la fenêtre de quête reste ouverte.

**Cause** — une quête déclenchée par un objet ou par l'entrée dans une zone
passe par `QUEST_DETAIL` sans interaction PNJ ; le client ne referme pas la
fenêtre.

**Ce qu'on fait** — `if QuestGetAutoAccept() then CloseQuest() end` après
`AcceptQuest()`.

---

## Boucle de dialogue avec `GOSSIP_SHOW`

**Symptôme** — traiter toutes les quêtes d'un PNJ dans une seule passe
sélectionne la mauvaise.

**Cause** — chaque `SelectAvailableQuest` / `SelectActiveQuest` provoque un
nouveau `GOSSIP_SHOW` avec une liste modifiée.

**Ce qu'on fait** — une seule sélection par événement, puis `return`. Le client
nous rappelle.

---

## Récompenses de quête

**Symptôme** — une récompense est prise à la place du joueur.

**Cause** — `GetQuestReward(1)` sur une quête à choix multiple valide le premier
objet, sans retour possible.

**Ce qu'on fait** — l'automatisation s'arrête dès que
`GetNumQuestChoices() > 1`.

---

## Assombrir l'habillage du client

**Symptôme** — un voile sombre posé par-dessus une fenêtre de Blizzard ne se voit
pas, ou se voit sur la moitié des cadres seulement.

**Cause** — le voile est une texture de plus, soumise à l'ordre des calques du
cadre visé. Ce cadre ne nous appartient pas : rien ne garantit qu'il ne dessine
pas son habillage au-dessus du calque qu'on a choisi.

**Ce qu'on fait** — `UI/Shade.lua` ne pose rien : il **multiplie** la couleur de
sommet des textures existantes (`SetVertexColor`), ce qui agit sur la texture
elle-même quel que soit son calque. C'est le même raisonnement que
`T.SetPanelFill` pour nos propres panneaux.

Quatre familles de textures sont exclues du parcours, et l'exclusion n'est pas
cosmétique :

- la texture de remplissage d'une barre de statut (`GetStatusBarTexture`) porte
  une donnée — vie, ressource, temps restant — et non de l'habillage ;
- les **textures d'état** d'un bouton : survol, enfoncé, coché, désactivé. Elles
  ne décorent pas, elles disent au joueur ce qui se passe. Les assombrir revient
  à éteindre le signal, et c'est ainsi qu'une lueur de survol dorée devient une
  auréole noire. Un bouton n'expose donc au parcours que sa `NormalTexture` ;
- les icônes et portraits (clés `icon`, `Icon`, `portrait`…) deviennent
  illisibles une fois assombris ;
- les objets `Cooldown` : leur balayage est peint par le moteur, pas par une
  texture qu'on pourrait teinter.

Le critère commun, qui vaut mieux que la liste : **on teinte ce qui décore, jamais
ce qui informe.** Chaque fois qu'une exclusion a manqué, le symptôme a été le
même — une information devenue invisible.

Enfin, tout cadre `IsForbidden()` est ignoré — y toucher lève une erreur.

**Limite connue** — la couleur d'origine est relevée au premier passage. Si le
client reteinte lui-même une texture pendant que le mode sombre est actif (une
barre qui passe aux couleurs de classe, par exemple), la restitution repose la
couleur d'avant. Repasser le mode sombre corrige.

---

## L'habillage d'un bouton n'est pas dans ses régions

**Symptôme** — une barre d'action entière échappe à l'assombrissement alors que
le parcours descend bien jusqu'à ses boutons. Aucune erreur : il ne se passe
simplement rien, et c'est ce silence qui fait chercher au mauvais endroit.

**Cause** — `GetRegions()` ne renvoie que les régions créées **sur** le cadre.
L'habillage d'un bouton (`NormalTexture`, et ses variantes `Pushed`, `Disabled`,
`Checked`) n'en fait pas partie : il se demande par `GetNormalTexture()` et
compagnie, ou se lit sous le nom global `<NomDuBouton>NormalTexture`.

**Ce qu'on fait** — `collectFrom` interroge les quatre accesseurs sur chaque
cadre qui les expose, en plus de ses régions. C'est aussi ce qui rattrape la
barre d'action principale, dont les boutons ne descendent pas forcément de la
barre elle-même — d'où la liste explicite `ActionButton1..12`.

**Trouvé en lisant** BetterBlizzFrames (`midnight/modules/darkmode.lua`), qui
adresse ces textures par leur nom global. Aucun code n'en a été repris : la
règle 8 autorise à y chercher *quelle* fonction résout le problème, pas à copier
la façon dont elle est appelée. Le même fichier a donné trois autres faits :
`BuffFrame.AuraContainer` porte les icônes d'auras, les visionneuses du
gestionnaire de temps de recharge (`BuffBarCooldownViewer` et ses sœurs) sortent
leurs cadres d'un pool, et le pilote des barres de nom publie bien
`classNamePlateMechanicFrame`.

---

## Une valeur secrète interrompt tout un passage

**Symptôme** — le mode sombre ne prend plus que sur le **premier** élément
assombri ; les six suivants ne bougent plus. Aucun message à l'écran, ce qui
oriente vers « le code ne trouve plus les cadres » alors que le code ne s'exécute
tout simplement plus.

**Cause** — la boucle qui traite les éléments les enchaînait dans un seul appel :
la première erreur emportait tous les éléments suivants. Le symptôme observé
(« seul le premier marche ») ne ressemblait en rien à sa cause (« le deuxième
lève »).

**Ce qu'on fait** — l'isolation, à trois niveaux, et il faut les trois :

- `applyDarkMode` traite chaque élément dans son propre `BUI.safecall` ;
- `paint` traite chaque texture dans son propre `pcall` — sans quoi une région
  sur vingt laisse un cadre d'unité entier en clair ;
- `UI/Shade.lua` ne demande **rien** à un cadre autrement que par `ask` /
  `askAll`, qui enveloppent l'appel. On n'y devine jamais ce qui est touchable :
  on essaie, et un échec ne coûte que l'appel qui a échoué.

**Fausse piste, et elle a coûté un aller-retour** — le client expose
`issecretvalue`, et il était tentant d'en faire une garde posée sur le cadre
avant de le parcourir. C'était l'erreur inverse : la garde écartait des cadres
parfaitement traitables et a fait disparaître d'un coup les cadres d'unités, la
barre d'incantation et la ressource personnelle — tous liés à une unité, ce qui
est précisément le motif qui a permis de la démasquer. `issecretvalue` ne sert
plus que sur une **valeur** dont on s'apprête à faire un calcul (le résultat de
`GetVertexColor`), là où le danger est réel.

La règle qu'on en tire : **une garde décide qu'une chose est intouchable sans
avoir essayé.** Face à une API qui se protège davantage à chaque extension, il
faut essayer et isoler l'échec, pas dresser la liste de ce qu'on suppose
interdit — cette liste est fausse le jour où on l'écrit.

---

## Le bord sombre d'une icône ne se dessine pas, il se teinte

**Symptôme** — on veut foncer le pourtour des icônes de sort sans noircir le
dessin. Toute tentative d'y **poser** un liseré finit par ajouter un carré
sombre derrière l'icône, dont les coins dépassent de sa forme arrondie.

**Cause** — l'icône n'est pas seule dans le bouton : son contour est une texture
d'habillage **distincte**, que le client dessine autour d'elle avec ses coins
arrondis. La teinter fonce exactement ce qu'on voulait foncer. Tout ce qu'on
dessine en plus s'ajoute donc à un contour qui existait déjà — et un rectangle
ne suivra jamais une forme ronde.

**Ce qu'on fait** — rien de spécial là où le contour existe : l'icône est
exclue du parcours et son contour est teinté comme le reste de l'habillage.

**L'exception, et elle est réelle** — une icône d'aura n'a *pas* de contour :
le client ne lui en dessine aucun. Il n'y a donc rien à teinter, et le contour
doit bien être posé (`W.ShadeBorder`). C'est le **seul** cas, déclaré dans
`ICON_BORDERS`.

**On emprunte avant de créer, et on ne masque jamais pour ajouter.** C'est la
règle de fond, et elle vaut au-delà du mode sombre : quand le client a déjà
l'élément qu'on veut modifier, on le rhabille. On ne le cache pas pour en poser
un autre par-dessus, et on n'en ajoute pas un second à côté.

Trois conséquences concrètes, qui sont les trois cas rencontrés :

1. un bouton d'action a un contour → on le **teinte**, rien n'est ajouté ;
2. un cadre du gestionnaire de temps de recharge publie `Border` → on **rhabille
   cette texture-là** avec l'atlas et la teinte communs, ce qui l'aligne sur les
   auras sans rien créer ;
3. une icône d'aura n'a rien → c'est le seul cas où l'on **crée** une texture.

**Emprunter une texture n'est pas hériter de sa géométrie.** Elle était taillée
pour l'image du client ; appliquée à la nôtre, qui n'a pas les mêmes
proportions, elle déborde. Le contour est donc reposé sur l'icône dans tous les
cas — mais pas au même écart :

- **empruntée** : ancrage serré sur l'icône (un pixel). Ses ancrages d'origine
  sont relevés et reposés à l'extinction, comme le reste ;
- **créée** : écart proportionnel à l'icône, pour compenser la marge
  transparente que l'atlas porte autour de son trait.

Confondre les deux se voit tout de suite, et dans les deux sens : l'écart
proportionnel appliqué à une texture empruntée l'élargit, l'écart d'un pixel
appliqué à une texture créée fait tomber l'anneau à l'intérieur de l'icône.

Une texture empruntée exige par ailleurs de relever tout ce qu'on va changer —
image, coordonnées, teinte, désaturation, opacité, visibilité — pour pouvoir le
reposer à l'extinction. C'est la contrepartie de l'emprunt, et elle n'est pas
négociable (CLAUDE.md règle 6).

**Le fond n'est pas toujours de l'habillage.** Sur une infobulle, il fait partie
de la lisibilité : le jeu l'a réglé pour que le texte s'y détache, et
l'assombrir change autre chose que l'apparence. `KEEP_BACKGROUND` déclare les
éléments dont on ne touche que le contour ; la pièce centrale de leur nine-slice
(clé `Center`, ou `Bg` / `Background`) est alors laissée intacte. Ailleurs — un
cadre d'unité, une barre d'action — le fond *est* de l'habillage et suit le
reste.

Le chemin inverse — masquer l'habillage du client puis poser le sien — a été
écrit puis retiré : il marche, mais il laisse l'interface dans un état que le jeu
n'a pas prévu, et il double le nombre de choses à défaire.

Ce contour est **une texture d'atlas ancrée à un pixel** au-delà des quatre bords
de l'icône : `Adventures-Spell-Border`, désaturée puis teintée.

Le choix de l'atlas n'est pas indifférent. La bordure de sort du client a ses
coins **cassés en biseau**, qui est la forme que le jeu donne à ses icônes ; un
anneau d'avatar ou de portrait a des angles droits et se reconnaît
immédiatement comme une pièce rapportée. Cet atlas ne convient en revanche que là
où l'on **remplace** un contour ou qu'il n'y en a aucun : ajouté par-dessus un
contour existant, son trait ouvragé dessine un second cadre à l'intérieur du
premier — c'est ce qui l'avait fait écarter au premier essai, quand il était posé
sur des boutons d'action qui avaient déjà le leur.

Trois détails font toute la propreté du rendu, et aucun ne se devine :

- **l'icône est rognée de 6 %** (`SetTexCoord`) avant qu'on trace. Les icônes de
  sort portent un liseré sombre *dans leur image* ; sans rognage, notre tracé
  s'ajoute à ce liseré au lieu de le remplacer, et le bord paraît deux fois trop
  épais quelle que soit l'épaisseur qu'on lui donne.

- **le débordement est proportionnel à l'icône, mais plafonné** : il compense la
  marge transparente de l'atlas, donc il doit grandir avec elle — mais au-delà
  de quelques pixels l'anneau sort de son icône et mord sur ses voisines, qui
  sont serrées dans une rangée d'auras ou de temps de recharge. Proportion et
  plafond sont deux réglages distincts, et il a fallu les deux ;
- **le tracé est rentré vers l'intérieur** d'une demi-épaisseur plus un pixel. Un
  trait est centré sur son chemin : posé sur l'arête, il déborde de moitié et se
  lit comme un cadre *autour* de l'icône au lieu de son bord.

Les auras de la **cible** et du **focus** ne s'atteignent ni par un nom global ni
par un enfant fixe : elles sortent d'un pool porté par leur cadre d'unité,
`TargetFrame.auraPools:EnumerateActive()`. On énumère les actives à chaque
passage.

**Aucun événement n'annonce leur arrivée**, et c'est le piège de cette section.
Changer de cible reconstruit tout le pool sans déclencher le moindre événement
d'aura : le contour attendait donc qu'une aura batte quelque part pour que
`UNIT_AURA` finisse par arriver, ce qui prenait une à trois secondes.

Repasser à intervalles après `PLAYER_TARGET_CHANGED` **ne suffit pas non plus**,
et c'est la tentation à écarter. Cela revient à parier sur l'instant où le client
remplira le pool, et le pari se perd : trois passages étalés sur deux dixièmes de
seconde peuvent tous tomber avant lui.

**Ce qu'on fait** — `U.GuardedHook(TargetFrame, "UpdateAuras", …)`, seul motif de
hook autorisé (CLAUDE.md règle 6) : posé une fois, inerte quand le module
s'éteint. Le client nous prévient lui-même au lieu qu'on le devine.

Le corps traite **les auras de ce cadre-là, immédiatement** (`Shade:ApplyTo`), et
non l'élément entier en différé. La granularité n'est pas un détail
d'optimisation : un parcours complet est trop cher pour être immédiat et trop
lent pour être invisible, donc tant qu'on raisonne en éléments, il faut choisir
entre les deux. En raisonnant par cadre, la question disparaît.

La leçon générale : **quand une donnée arrive sans événement, on s'accroche à la
fonction qui la produit ; on ne la sonde pas.** Un sondage se règle à l'infini et
n'est jamais juste.

---

## Fabriquer une texture sans outil d'image

**Symptôme** — le client ne lit ni PNG ni JPEG : il lui faut un **TGA non
compressé** ou un BLP, avec des côtés en puissance de deux. Aucun convertisseur
n'est installé sur la machine.

**Piège à éviter d'abord** — sous Windows, `convert` est
`C:\WINDOWS\system32\convert.exe`, l'outil de conversion **de système de
fichiers** (FAT vers NTFS). Ce n'est pas ImageMagick, et le lancer sur un chemin
d'image n'a rien d'anodin. Vérifier `command -v convert` avant de s'en servir.

**Ce qu'on fait** — `dev/scripts/` n'en a pas besoin : PowerShell suffit.
`System.Drawing` décode le PNG, recadre et rééchantillonne ; l'en-tête TGA
s'écrit à la main, elle tient en dix-huit octets suivis des pixels bruts en
**BGRA**. Deux valeurs comptent dans cet en-tête : le type `2` (couleurs vraies
non compressées) et le descripteur `0x28` — huit bits d'alpha plus l'origine en
haut à gauche, sans quoi l'image sort à l'envers.

Le disque alpha du logo est **cuit dans la texture** plutôt que posé en jeu : le
trou de la bordure de minicarte est rond, et un masque appliqué à l'exécution
serait une dépendance de plus, qui peut ne pas prendre (voir la note sur les
masques et les textures répétées).

---

## Repeindre ne doit jamais repasser par l'état d'origine

**Symptôme** — le mode sombre est bien posé, mais changer de cible donne
l'impression que l'interface « se rafraîchit » : quelque chose bat, sans qu'on
puisse dire quoi.

**Cause** — `Apply` rendait tout l'élément à son état d'origine avant de le
reteinter. Le résultat final est le même, puisque la teinte se recalcule toujours
depuis la couleur relevée — mais chaque passage traverse un état **clair**. Un
passage isolé ne se voit pas ; sur un changement de cible, où plusieurs passages
s'enchaînent en deux dixièmes de seconde, cela se voit très bien.

**Ce qu'on fait** — on ne rend que ce qui **sort** du périmètre : le nouveau
parcours est comparé au précédent, et seules les textures qu'il n'a pas
retrouvées — une aura tombée, un cadre rangé par le client — sont rendues. Les
autres sont repeintes par-dessus elles-mêmes, ce qui ne change rien à l'écran.

C'est possible parce que la teinte est **idempotente** : elle part toujours de la
couleur d'origine mémorisée, jamais de la couleur courante. Un moteur qui
teinterait par multiplications successives serait obligé de rendre avant de
repeindre — et donc de clignoter.

**Quatre formes essayées avant celle-là**, et l'ordre a son intérêt : cadre
décoratif épais (un second carré apparaît dans l'icône) → quatre bandes de
couleur unie (carré franc, coins débordants) → huit segments `Line` en octogone
(la forme y est, mais chaque taille d'icône demande son propre réglage) → cadre
fin à un pixel, qui n'en demande aucun.

Une note de moteur relevée en route, à ne pas réapprendre : **on ne peut pas
tracer de diagonale avec une texture**. Une texture est un rectangle aligné sur
les axes, et `SetRotation` ne fait pivoter que son *image* à l'intérieur de ce
rectangle — sur un aplat de couleur, la rotation ne produit donc rien. Il faut
`frame:CreateLine` (`SetStartPoint` / `SetEndPoint` / `SetThickness`), qui relie
deux points arbitraires.

Le partage se lit d'ailleurs dans la façon dont les autres addons traitent le
sujet : ils teintent la `NormalTexture` des boutons d'action et **construisent**
une bordure pour les auras. Ce n'est pas une incohérence de leur part, c'est la
conséquence de ce que le client dessine ou non.

**Trois approches essayées et abandonnées**, dans cet ordre, chacune paraissant
corriger la précédente :

1. teinter l'icône elle-même — noircit le dessin, illisible ;
2. poser un atlas de bordure du client (`Adventures-Spell-Border`, puis
   `communities-create-avatar-border-hover`) — ces atlas portent leur propre
   dessin (ombre, biseau, coins) et se lisent comme un cadre posé derrière
   l'icône ; affiner l'épaisseur n'y change rien, le défaut est dans l'image ;
3. poser quatre bandes de couleur unie sur les arêtes — plus de dessin parasite,
   mais quatre rectangles forment un carré, dont les coins débordent du contour
   arrondi du bouton.

La leçon, et elle vaut bien au-delà du mode sombre : **avant d'ajouter une
texture par-dessus l'interface du client, vérifier que celle qu'on veut obtenir
n'existe pas déjà.** Les trois tentatives ci-dessus ajoutaient un contour à un
bouton qui en avait un.

---

## Assombrir sans désaturer donne du doré foncé

**Symptôme** — le mode sombre à pleine intensité ne rend pas l'interface sombre
mais brune : on reconnaît l'or de l'habillage, en plus terne.

**Cause** — multiplier une couleur ne change pas sa teinte, seulement sa
luminosité. L'habillage du client est doré ; assombri, il reste doré.

**Ce qu'on fait** — `UI/Shade.lua` désature les textures d'habillage avant de les
assombrir, et relève `IsDesaturated()` pour pouvoir rendre l'état exact. Les
icônes, elles, ne sont **jamais** désaturées : une icône de sort sans ses
couleurs n'est plus reconnaissable.

Les icônes reçoivent par ailleurs un dosage plus doux que l'habillage
(`T.ShadeIconFactor`, croissance en carré de l'intensité). Sans ce second
dosage, les auras et le gestionnaire de temps de recharge — qui ne sont presque
que des icônes — ne bougeaient pas d'un cheveu quelle que soit l'intensité.

---

## Réparation sur les fonds de guilde

**Symptôme** — impossible de savoir si la guilde a payé : `RepairAllItems(true)`
ne renvoie rien.

**Cause** — le client ne rend pas la main sur le résultat du paiement. Une
autorisation de retrait quotidienne épuisée fait échouer la réparation en
silence.

**Ce qu'on fait** — on redemande `GetRepairAllCost()` après l'appel. Il retombe à
zéro quand la guilde a payé ; sinon le reste est payé sur la bourse du joueur.
C'est aussi ce qui donne le bon montant à annoncer.

---

## Filtre « extension actuelle » de l'hôtel des ventes

**Symptôme** — le filtre existe dans l'interface du client mais se remet à zéro à
chaque ouverture. Envelopper `C_AuctionHouse.SendBrowseQuery` pour ajouter
`Enum.AuctionHouseFilter.CurrentExpansionOnly` à `query.filters` ne donne rien du
tout : ni erreur, ni effet.

**Cause** — ce n'était pas le bon objet. L'état des filtres vit sur le bouton de
filtre de la barre de recherche, `AuctionHouseFrame.SearchBar.FilterButton.filters`,
et c'est un **ensemble indexé par la valeur d'énumération**, pas une liste. On
écrit `filters[Enum.AuctionHouseFilter.CurrentExpansionOnly] = true`, on n'empile
pas.

**Ce qu'on fait** — on coche la case du client au lieu de filtrer derrière son
dos. Deux conséquences qui valent mieux que l'enveloppe : la fenêtre affiche un
état vrai (envelopper la requête aurait filtré les résultats en laissant la case
décochée), et il n'y a aucune fonction du client à remplacer.

Le bouton n'existe qu'une fois `Blizzard_AuctionHouseUI` chargé, et il est
construit **après** `AUCTION_HOUSE_SHOW` : on laisse passer une image
(`C_Timer.After(0, …)`) avant d'aller le chercher. `SearchBar:UpdateClearFiltersButton()`
resynchronise ensuite l'affichage.

**Trouvé en lisant** EllesmereUIQoL. Aucun code repris (règle 8).

---

## Échéance des fenêtres de file d'attente

**Symptôme** — impossible d'afficher un décompte sur la proposition de donjon :
aucune fonction ne donne le temps restant.

**Cause** — les deux fenêtres ne se ressemblent pas. Côté champ de bataille,
`GetBattlefieldPortExpiration(index)` donne les secondes restantes pour l'entrée
dont `GetBattlefieldStatus(index)` vaut `"confirm"`. Côté LFG, **le client ne
publie rien** : ni fonction, ni constante. `GetLFGProposal()` dit qu'une
proposition existe et si on y a répondu, jamais combien de temps il reste.

**Ce qu'on fait** — `W.Countdown` est branché sur une fonction qui rend les
secondes restantes, ce qui permet les deux sources dans le même widget. Pour LFG,
l'échéance est calculée à l'affichage à partir d'une constante, `PROPOSAL_SECONDS
= 40`, qui est le délai appliqué par le client. Vérifié : les addons qui affichent
ce décompte depuis des années font tous la même chose, faute d'API.

Le cadre à coiffer est `LFGDungeonReadyDialog`, **pas** `LFGDungeonReadyPopup` :
le second est le conteneur, et un décompte posé dessus ne s'affiche jamais.
