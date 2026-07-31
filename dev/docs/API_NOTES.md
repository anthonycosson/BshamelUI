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
doit bien être posé (`W.ShadeBorder`). Les emplacements du gestionnaire de temps
de recharge sont dans le même cas. Ces cas-là sont déclarés dans `ICON_BORDERS`,
et l'entrée s'y ajoute après avoir **relevé** les régions du cadre, jamais
d'après ce qu'on suppose qu'il porte.

**`GetDebugName` rend un chemin, pas un nom.** Il vaut
`BuffIconCooldownViewer.…12ab.…34cd` : le nom de la région n'en est que le
dernier segment, tout le reste appartient à ses ancêtres. Chercher un mot dans
la chaîne entière fait donc porter à une texture le nom du cadre qui la contient.
Le symptôme a été un mode sombre qui marchait sur trois visionneuses de temps de
recharge et pas sur la quatrième — celle dont le nom contient « Icon », dont
*toutes* les textures passaient pour des icônes, donc pour intouchables. Ne
comparer que le dernier segment.

**On emprunte avant de créer, et on ne masque jamais pour ajouter.** C'est la
règle de fond, et elle vaut au-delà du mode sombre : quand le client a déjà
l'élément qu'on veut modifier, on le rhabille. On ne le cache pas pour en poser
un autre par-dessus, et on n'en ajoute pas un second à côté.

Deux conséquences concrètes, qui sont les deux cas rencontrés :

1. un bouton d'action a un contour → on le **teinte**, rien n'est ajouté ;
2. une icône d'aura, comme un emplacement du gestionnaire de temps de recharge,
   n'a rien → on **crée** une texture.

Le chemin « emprunter le contour du client pour le rhabiller » existe dans
`W.ShadeBorder` et reste juste, mais **aucun cadre rencontré ne l'emprunte pour
l'instant** : il attend un cadre qui publie `Border` ou `IconBorder`. Une note
antérieure attribuait ce cas au gestionnaire de temps de recharge — c'était
faux, relevé à l'appui : un emplacement ne porte que son icône, un masque,
`OutOfRange` et l'atlas `UI-HUD-CoolDownManager-IconOverlay`.

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

**Deux erreurs qui se compensent ne se voient qu'à une seule taille.** L'écart
de `T.ShadeBorderPad` valait 12 % du côté de l'icône, plafonné à 3 px. Le ratio
était deux fois trop grand — l'écart qui colle l'anneau vaut 6 % — et le plafond
le ramenait à 3 px, c'est-à-dire pile à la bonne valeur, mais **pour une icône
de 50 px et pour elle seule**. Toutes les autres tailles recevaient 3 px aussi,
donc trop, donc un anneau décollé : visible sur les icônes de 30 px du
gestionnaire de temps de recharge, invisible sur celles de 50 px juste au-dessus.

La leçon vaut au-delà de ce réglage : quand une valeur bornée rend le bon
résultat, vérifier **si c'est la formule ou la borne** qui l'a produit. Ici,
monter le plafond en croyant libérer la proportion a décollé l'anneau partout,
y compris là où il était correct. Le symptôme d'une compensation qu'on casse
n'est jamais local.

Se méfier aussi du sens : l'anneau tombe **en dehors** du bord de la texture, si
bien qu'agrandir l'écart éloigne le trait de l'icône. Le raisonnement inverse
— « l'atlas a une marge, il faut donc pousser plus loin » — est intuitif et faux.
Deux mesures à deux tailles le tranchent en une minute, un raisonnement ne le
tranche pas du tout.

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

---

## Le suivi des améliorations garde la place des améliorations tombées

**Symptôme** — deux améliorations actives s'affichent écartées de plusieurs
largeurs d'icône, une de chaque côté du centre. Elles devraient être côte à
côte.

**Cause** — le suivi des améliorations réserve **une place par amélioration
suivie**, et il garde la grille entière quelle que soit la quantité affichée.
Une amélioration qui tombe laisse sa place vide ; celles qui restent ne bougent
pas. Le client ne recalcule rien à cet instant — c'est bien pourquoi le trou
reste.

**Fausse piste, et elle a coûté un aller-retour** — le symptôme se raconte
naturellement comme « la rangée n'est pas centrée », ce qui conduit à la
**déplacer**. C'est faux et sans effet : la rangée *est* déjà centrée, trous
compris. Ce qu'il faut, c'est retasser les emplacements affichés à l'intérieur
d'une grille qui, elle, ne bouge pas. Deux mesures sur une capture d'écran le
tranchent — le milieu des deux icônes tombait pile sur le centre de l'écran —
là où le raisonnement a mené droit à un décalage nul.

**Ce qu'on fait** — `Modules/CooldownManager.lua` relève la grille du client,
puis repose les améliorations affichées serrées les unes contre les autres,
centrées sur le milieu de cette grille.

Ce que le client publie, et qui suffit :

- `viewer:GetItemFrames()` — **tous** les emplacements, y compris ceux des
  améliorations tombées, qui gardent leur position. Ce sont eux qui disent où la
  grille commence, où elle finit et à quel pas ;
- `IsShown()` et l'opacité distinguent les places occupées. L'opacité n'est pas
  facultative : le client efface en fondu, et un emplacement en train de
  disparaître est encore affiché ;
- `viewer.isHorizontal` — l'orientation. Absente, elle vaut horizontal.

**La grille se calcule, elle ne se mémorise pas.** Relevé sur un client à jour,
avec dix améliorations suivies et aucune active :

```
V 725.538 499.400   C 725.538 499.400   pad 10   stride 10   h true
1  false 1  659.580  TOPLEFT TOPLEFT    0  0
2  false 1  705.580  TOPLEFT TOPLEFT   46  0
…
10 false 1 1073.580  TOPLEFT TOPLEFT  414  0
```

Tout y est :

- les **dix places existent** en permanence, y compris quand rien n'est actif, et
  la liste les rend **dans l'ordre des places** — c'est de là que vient l'ordre
  d'affichage, jamais des positions ;
- le pas vaut **46** exactement, et la boîte du conteneur couvre exactement la
  grille : 9 × 46 + 40 = 454. Le pas se déduit donc du conteneur,
  `(largeur - côté) / (places - 1)`, sans rien mesurer sur des emplacements
  qu'on a peut-être déplacés soi-même ;
- accessoirement, `iconPadding` vaut 10 pour un écart réel de 6 : l'emplacement
  déborde de deux points de chaque côté de son icône. On ne s'en sert pas — le
  conteneur donne le pas sans cette subtilité — mais c'est ce qui explique le
  `- 4` qu'on trouve dans d'autres addons.

**Le conteneur et les emplacements ne sont pas dans la même échelle**, et c'est
le piège de cette section : `V` et `C` sont à 725,5 quand la première place est à
659,6, soit un rapport de 1,1 pile. Le client agrandit ses icônes sans agrandir
le conteneur, et un décalage d'ancrage s'exprime dans l'échelle du cadre qu'il
place. Comparer les deux sans convertir (`GetEffectiveScale`) fausse tout de dix
pour cent — silencieusement, puisque le résultat reste plausible.

**Trois points d'accroche, et le troisième est le seul indispensable** :
`RefreshLayout` et `Layout` sont les deux façons dont le client défait notre
tassement, `OnUnitAura` est la seule façon d'apprendre qu'une amélioration est
tombée. Sans lui, le trou resterait affiché jusqu'à ce qu'autre chose fasse
bouger la visionneuse. Un quatrième passage, différé de `T.TIMING.CDM_SETTLE`,
rattrape la fin du fondu : à l'instant où le client annonce la chute, l'icône
est encore opaque, donc encore comptée.

**Une mémoire de positions a été écrite, puis jetée, et c'est la leçon
principale de cette entrée.** Le raisonnement paraissait sans faille : puisqu'on
écrase les positions du client, il faut bien retenir celles qu'il avait posées.
Chaque emplacement gardait donc deux nombres — sa place chez le client, la
dernière qu'on lui avait donnée — et la grille se relisait dans cette mémoire.

Elle s'est désynchronisée deux fois, de deux façons différentes :

1. il manquait une **troisième** position, *là où le cadre est vraiment*, qui
   n'est ni l'une ni l'autre dès que l'ensemble affiché a changé depuis le
   dernier tassement. Un cadre déjà à sa place théorique était déclaré « rien à
   déplacer » et noté comme étant chez le client, alors qu'il était resté au
   tassement précédent ; au passage suivant, cette position-là était relue comme
   une place de la grille ;
2. corrigé ce point, il restait que le pas se mesurait sur des emplacements dont
   certains avaient été déplacés par nous — l'espacement se mettait alors à
   varier d'un instant à l'autre, et le centre à glisser.

Le symptôme arrive **tard**, après plusieurs cycles d'apparition et de chute,
donc jamais au premier essai : chaque correctif semblait tenir, puis dérivait.

La sortie n'a pas été un troisième correctif mais un **relevé** — les vingt
lignes ci-dessus, obtenues en deux `/run` — qui a montré que la grille se calcule
intégralement à partir de cadres qu'on ne touche jamais. Il n'y a alors plus rien
à mémoriser : le tassement vise des positions absolues, il est idempotent par
construction, et la restitution est le même calcul avec la place `i` à `i` fois
le pas.

La leçon, qui vaut bien au-delà d'ici : **une mémoire de l'état d'un cadre du
client est une source de vérité concurrente de la sienne, et deux sources de
vérité divergent toujours.** Avant d'en tenir une, chercher ce qui, dans ce que
le client publie, permet de recalculer la même chose — et si on ne le trouve pas,
aller le mesurer en jeu plutôt que le déduire. Une demi-journée de correctifs
aurait tenu dans les trente secondes qu'a pris le relevé.

Deux garde-fous restent, parce qu'une lecture peut échouer : **le pas doit tenir
entre une place et deux** (le client ne fait ni chevaucher deux emplacements, ni
laisser une place vide entre eux), et une grille illisible ne fait rien déplacer
du tout.

**Trouvé en lisant** BetterBlizzFrames (`midnight/modules/cdManager.lua`), qui
traite le même défaut. Aucun code repris (règle 8) : il en sort la liste des
membres publiés par une visionneuse, le fait qu'un emplacement inactif reste
dans la liste, et `OnUnitAura` comme point d'accroche. Notre implémentation ne
reconstruit pas la disposition à partir d'un sens de remplissage et d'un
`iconPadding` supposés : elle mesure la grille que le client vient de poser, ce
qui la rend indifférente à l'ordre, au sens et au retour à la ligne.

---

## Lire l'équipement du personnage sans monter d'infobulle

**Symptôme** — pour poser un niveau d'objet, un rang d'amélioration et l'état des
enchantements et des gemmes sur les seize emplacements de la fiche, la voie
évidente est de monter une infobulle cachée et d'en lire les lignes. C'est aussi
la voie qui coûte le plus cher et qui casse à chaque refonte des infobulles.

**Ce que le client publie directement** — presque tout, sans infobulle :

| Besoin | Chemin |
|---|---|
| Niveau d'objet **réel** | `C_Item.GetCurrentItemLevel(ItemLocation:CreateFromEquipmentSlot(slot))` |
| Rang d'amélioration | `C_Item.GetItemUpgradeInfo(link)` → `currentLevel`, `maxLevel`, `trackString` |
| Enchantement présent | 2ᵉ champ du lien : `link:match("item:%d+:(%d*)")` |
| Châsses | `C_Item.GetItemStats(link)`, clés `EMPTY_SOCKET_*` |
| Gemme sertie | `C_Item.GetItemGem(link, index)` |
| Arme ou bouclier | `select(6, C_Item.GetItemInfoInstant(link)) == Enum.ItemClass.Weapon` |

Le niveau d'objet se prend **par l'emplacement et non par le lien** : c'est le
seul chemin qui tienne compte de la mise à l'échelle. Un objet mis à l'échelle
affiche sinon le niveau écrit dans son lien, qui n'est pas celui que le
personnage porte.

Le champ d'enchantement du lien est **vide, pas absent**, quand il n'y a pas
d'enchantement : le motif doit donc capturer `(%d*)` et non `(%d+)`, sans quoi il
ne trouve rien du tout et tout paraît enchanté.

---

## `GetItemStats` compte les châsses **totales**, pas les vides

**Symptôme** — malgré son nom, la clé `EMPTY_SOCKET_PRISMATIC` ne vaut pas zéro
quand la châsse est sertie. Compter les châsses vides à partir de cette clé donne
un objet entièrement gemmé signalé comme incomplet.

**Ce qu'on fait** — le nombre rendu est le nombre de châsses de ce type,
serties ou non. Les vides se déduisent : `total − serties`, les serties étant les
index pour lesquels `C_Item.GetItemGem(link, index)` rend un lien.

On somme **tous** les types de châsse par un motif `^EMPTY_SOCKET_` plutôt que par
une liste de clés connues : une liste est fausse au premier type introduit par
une extension, et l'oubli est silencieux — la pièce paraît simplement ne pas
avoir de châsse.

**Ne pas tendre de table de travail.** L'ancienne globale acceptait un second
paramètre, `GetItemStats(link, statTable)`, qu'elle remplissait au lieu d'allouer.
Rien ne dit que la variante `C_Item` respecte ce contrat, et le pari se perd en
silence : au mieux l'argument est ignoré, au pire la fonction lève et le
rafraîchissement de l'emplacement meurt dans son `safecall` sans rien afficher.
L'économie d'une table sur un chemin groupé ne vaut pas ce risque.

**Ne pas déduire non plus le nombre de châsses du total pour interroger
`GetItemGem`.** Les deux lectures sont indépendantes : on interroge les quatre
champs de gemme que réserve un lien d'objet, et on retient le plus grand des deux
décomptes. Une gemme visible reste ainsi affichée même si le décompte des châsses
échoue — on perd la connaissance des châsses vides, pas l'affichage entier.

---

## Le noyau du vide ne se lit ni dans le lien ni dans les statistiques

**Symptôme** — savoir si une arme ou un bijou a reçu son noyau du vide. Ce n'est
ni une châsse (`GetItemStats` n'expose rien), ni un enchantement (le champ du
lien reste vide), ni un rang d'amélioration.

**Cause** — le noyau se manifeste par un **effet nommé** sur l'objet, « Forge du
vide ascendant », que seule l'infobulle publie.

**Ce qu'on fait** — `C_TooltipInfo.GetInventoryItem("player", slot)` rend des
**données** et non des `FontString`, donc sans créer la moindre frame. Deux
pièges :

- les champs d'une ligne ne sont peuplés qu'après `TooltipUtil.SurfaceArgs(data)`.
  Sans cet appel, `line.leftText` est absent et la boucle ne trouve jamais rien ;
- `leftText` porte des échappements de couleur, y compris la forme récente
  `|cn<nom>:<texte>|r`. Ils se retirent avant toute comparaison.

**Limite assumée** — la comparaison porte sur une **chaîne traduite**
(`L["Void core marker"]`). Aucun identifiant stable n'étant exposé côté objet, il
n'y a pas de solution indépendante de la langue ; une locale dont l'intitulé est
faux montre les armes et les bijoux en rouge à tort. La clé est donc isolée dans
les fichiers de locale, à corriger en un seul endroit. Si le client publie un
jour un identifiant de sort pour cet effet, le passage à
`C_Spell.GetSpellName(id)` rendrait la lecture indépendante de la langue.

---

## Aucune API ne dit qu'un emplacement peut être enchanté

Il n'existe pas de fonction « cet emplacement accepte-t-il un enchantement ? », et
la liste **change d'une extension à l'autre** : la cape et les bracelets
s'enchantaient hier et ne s'enchantent plus, le casque et les épaules ont fait le
chemin inverse. Elle se relève en jeu, pas par déduction.

`Modules/Character.lua` porte donc deux tables, `ENCHANTABLE` et `VOID_SLOTS`,
qui sont des faits de jeu et les deux seules choses du module qui puissent
afficher du rouge à tort.

Un cas se déduit quand même, et il vaut la peine : la **main gauche** ne
s'enchante — et ne reçoit de noyau — que si c'est une arme. Un bouclier ou un
objet tenu occupe le même emplacement et n'accepte rien.

---

## Déplacer une fenêtre du client sans la tainter

**Symptôme** — après avoir rendu déplaçable le cadre de recherche de groupe,
des erreurs tombent ailleurs et plus tard : `attempt to compare a secret number`
dans du code de Blizzard, des actions bloquées « interface action failed because
of an AddOn ». Rien ne les relie au déplacement, et elles ne se produisent pas
sur les autres fenêtres.

**Cause** — certaines fenêtres du client sont **protégées**. Sur celles-là,
`SetMovable`, `StartMoving`, `SetClampedToScreen`, `EnableMouseWheel`,
`SetFrameStrata`, `Raise` et `SetPoint` appelés depuis un addon *taintent* leur
arbre. L'appel ne lève pas : il réussit, et c'est le code de Blizzard qui
échouera plus tard, sur une comparaison de valeur secrète, sans rien qui remonte
jusqu'à nous.

Le point commun de ces appels, et c'est lui qu'il faut retenir plutôt que la
liste : ce sont tous des **écritures d'état** sur un cadre qui ne nous appartient
pas. Lire (`GetPoint`, `GetScale`, `IsMouseOver`) ne taint jamais.

**Ce qu'on fait** — trois substitutions, une par classe d'appel :

1. **Positionner et mettre à l'échelle** passent par un
   `SecureHandlerBaseTemplate` et un snippet `Execute` (`UI/Widgets/Mover.lua`).
   L'environnement restreint s'exécute de façon sûre par construction : il ne
   voit que ce qu'on lui passe par `SetFrameRef` et `SetAttribute`, il n'a donc
   rien à tainter. Il **refuse en combat** — c'est à l'appelant de différer, ce
   que fait `PLAYER_REGEN_ENABLED`.

2. **La molette** ne s'active sur aucun cadre du client. Une frame à nous se pose
   par-dessus celui qu'on survole, avec `EnableMouse(false)` pour que les clics
   la traversent, et ne prend que la molette. Elle n'existe que pendant que le
   modificateur est tenu.

3. **Le glisser** ne se fait pas par `StartMoving` : on relève la position du
   curseur à chaque image et on repose la fenêtre soi-même. C'était le chemin
   qu'un cadre protégé imposait de toute façon ; l'appliquer à *tous* les cadres
   supprime la moitié du code, et surtout ne laisse **rien à défaire** à
   l'extinction — pas de `SetMovable` à retirer, donc rien qui puisse rester.

**Une position est un décalage de centre à centre, jamais un ancrage.** On
mémorise de combien le centre de la fenêtre s'écarte du centre de `UIParent`, et
on repose toujours en `CENTER`/`CENTER`. Cela vaut trois choses d'un coup : le
chemin protégé et le chemin ordinaire deviennent identiques, un changement
d'échelle se rattrape par une division, et aucun ancrage relatif à un cadre tiers
ne vient surprendre. Relire l'ancrage du client pour le rejouer était la première
approche ; elle casse dès qu'une fenêtre s'ancre sur sa voisine.

**Les offsets sont en unités locales du cadre**, c'est-à-dire divisés par son
échelle effective. Une fenêtre mise à l'échelle sans que son décalage soit
multiplié par `ancienne/nouvelle` saute d'autant. Le calcul juste : relever le
décalage en **pixels d'écran** avant, et le retraduire après.

**Poser une position une fois ne suffit pas.** Le gestionnaire de panneaux du
client réancre ses fenêtres à l'ouverture, au changement d'onglet, à l'apparition
d'une fenêtre voisine. La position doit être **réimposée** depuis un hook sur
`SetPoint` — avec un drapeau pour que notre propre écriture ne réveille pas le
hook, sinon il réécrit par-dessus lui-même. Même chose pour `SetScale` : certaines
fenêtres se remettent à l'échelle sur un changement d'état, sans cycle
masquer/afficher qui aurait rejoué `OnShow`.

**Redimensionner une fenêtre jamais déplacée doit lui donner une position.**
Sans elle, le gestionnaire de panneaux la rassoit à sa place d'origine au
prochain recalcul, et elle saute sans raison visible. Mettre à l'échelle « prend
donc la place » comme le ferait un glisser.

**`OnMouseUp` n'est pas ce qui termine un glisser.** Le bouton peut être relâché
hors du cadre, où l'événement ne nous parvient pas — la fenêtre reste alors
collée au curseur. Le test qui termine vraiment est
`IsMouseButtonDown("LeftButton")`, interrogé dans la boucle de suivi.
`OnMouseUp` reste posé, mais comme raccourci, pas comme garantie.

**La carte du monde se prend par sa barre de titre.** Son corps se déplace au
glisser et zoome à la molette : un glisser posé dessus ferait les deux à la fois.
`WorldMapTitleButton` est la poignée que le client utilise lui-même. C'est le
seul cas rencontré, mais il en existera d'autres — d'où une table
(`DRAG_HANDLES`) plutôt qu'une exception écrite dans le code.

**On n'appelle jamais `EnableMouse` sur un cadre du client.** Une fenêtre qui ne
reçoit pas la souris ne sera donc pas déplaçable. C'est une limite assumée : la
rendre telle serait exactement l'écriture d'état qui taint.

**Deux fenêtres sont volontairement hors du registre** :

- les **sacs**, dont le client réancre les cadres à chaque recalcul de
  disposition. Notre réimposition entrerait dans un bras de fer avec lui ; il
  leur faut un traitement à part, pas une ligne de plus dans la liste ;
- le **menu Échap** (`GameMenuFrame`), que `Modules/General.lua` sait déjà mettre
  à l'échelle. Deux moteurs sur la même frame se contrediraient à chaque
  ouverture.

**Trouvé en lisant** EllesmereUIQoL (`EllesmereUIQoL_Shifter.lua`). Aucun code
n'en a été repris (règle 8) : ce qu'on y a lu, ce sont les *classes d'appels* qui
taintent et l'existence du chemin par environnement restreint. L'architecture
retenue ici en diverge — un seul chemin de glisser au lieu de deux, une position
toujours centrée au lieu de l'ancrage relu, et une restitution à l'extinction que
le Shifter ne fait pas.

## Barres de vie : un seul point de passage

`UnitFrameHealthBar_Update(statusbar, unit)` est la fonction par laquelle passent
tous les cadres d'unités **classiques** — joueur, cible, focus, boss, membres du
groupe hors style raid. S'y accrocher couvre les cadres d'un coup et, surtout, au
bon moment : le client repose sa propre couleur à chaque mise à jour, un
rafraîchissement périodique ne ferait que courir derrière lui.

**Une barre de vie se désature avant de se teinter.** La texture de remplissage
du client n'est pas blanche, elle est **verte**. Une couleur de sommet posée
dessus la *multiplie* au lieu de la remplacer : le bleu d'un chaman donne un vert
sombre. Le symptôme est traître, parce que la couleur *change* — on croit que le
réglage fonctionne et se trompe de teinte, alors qu'il ne s'agit pas du tout d'un
problème de couleur. `SetStatusBarDesaturated(true)` rend la texture grise, et la
couleur de sommet redevient la couleur affichée.

La désaturation d'origine se relève avec la couleur et se repose avec elle :
reposer l'une sans l'autre laisse une barre pâle que le client n'a jamais
dessinée.

Deux autres pièges :

- **les cadres de cible de la cible n'y passent pas.** `TargetFrameToT` et
  `FocusFrameToT` sont mis à jour autrement, et rien n'annonce leur changement.
  On les reprend donc à chaque fois qu'une *autre* barre bouge — c'est le seul
  moment gratuit où l'on sait que quelque chose s'est passé ;
- **la barre ne se publie pas sous la même clé partout.** Les cadres montés par
  `UnitFrame_Initialize` publient `healthbar` ; les cadres de cible de la cible
  publient `HealthBar`. Chercher la seule première laisse les deux petits cadres
  en vert, ce qui ressemble à un oubli et n'en est pas un.

Les cadres de groupe en **style raid** ont leur propre réglage de couleurs de
classe dans le client : on ne le double pas.

## La couleur de faction se repeint à chaque cible

La plaque colorée derrière le nom de la cible est
`TargetFrame.TargetFrameContent.TargetFrameContentMain.ReputationColor`, et
`FocusFrame` porte la même sous le même chemin. La cacher une fois ne suffit
pas : `CheckFaction` la repeint à chaque changement de cible.

Pour la **rendre**, on n'appelle pas `Show` : on rappelle `CheckFaction`. Lui
seul sait si cette cible-là a une faction à montrer, et la rallumer à l'aveugle
en poserait une derrière des cibles qui n'en avaient pas.

## La spécialisation d'un autre joueur passe par le serveur

Celle du joueur se demande au client : `C_SpecializationInfo.GetSpecialization()`
puis `GetSpecializationInfo(index)`. Les globales `GetSpecialization` /
`GetSpecializationInfo` existent encore, mais l'espace de noms est le chemin
récent — on essaie les deux, dans cet ordre.

Celle d'un autre joueur n'existe **que** par une inspection :
`CanInspect(unit)`, `NotifyInspect(unit)`, puis `INSPECT_READY(guid)` et
`GetInspectSpecialization(unit)`. Deux limites qu'aucune astuce ne lève :

- l'unité doit être à **portée d'inspection**. Hors de portée, il n'y a pas
  d'icône, et il ne peut pas y en avoir ;
- le serveur ne traite **qu'une demande à la fois**. En dessous d'environ une
  seconde et demie, les demandes rapprochées sont ignorées en silence — d'où un
  intervalle de garde, et un cache par GUID pour ne jamais redemander ce qu'on
  sait déjà.

`ClearInspectPlayer` n'est pas appelé : il fermerait aussi la fenêtre
d'inspection que le joueur aurait ouverte lui-même.

Il existe un autre chemin, lu chez BetterBlizzFrames : reconstituer la spé en
lisant l'infobulle de l'unité (`C_TooltipInfo.GetUnit`) et en comparant sa ligne
de classe à une table de noms de spés localisés. Il a l'avantage de la portée,
et deux inconvénients qui l'ont fait écarter : il dépend de chaînes traduites —
avec des formes genrées, et des cas particuliers par langue — et il lit un
affichage au lieu d'interroger une API.

## Les cadres de groupe se règlent par une échelle

Le mode Édition borne son curseur de taille ; l'échelle qu'il pose, elle, n'est
pas bornée. `CompactPartyFrame:SetScale()` (style raid) et `PartyFrame:SetScale()`
(cadres classiques) acceptent ce qu'on leur donne.

Trois précautions :

- ce sont des **cadres protégés** : `SetScale` en combat lève une erreur
  d'action bloquée. On se garde par `InCombatLockdown` et on rattrape à
  `PLAYER_REGEN_ENABLED` ;
- le mode Édition **repose sa taille** en se refermant et à tout changement de
  disposition. Sans un hook sur `UpdateSystemSettingFrameSize`, le réglage a
  l'air de « ne pas tenir » ;
- l'échelle posée est **absolue**, elle ne se multiplie pas à celle du mode
  Édition. Deux valeurs qui se multiplieraient donneraient un résultat que ni
  l'une ni l'autre des deux fenêtres n'annonce.

**Trouvé en lisant** BetterBlizzFrames. Aucun code n'en a été repris (règle 8) :
ce qu'on y a lu, ce sont les noms de fonctions et les chemins de cadres —
`UnitFrameHealthBar_Update`, `ReputationColor`, `CompactPartyFrame:SetScale`.

---

## Historique de chat : relever ce qui est affiché, pas ce qui est reçu

**Symptôme** — reconstruire l'historique à partir des événements `CHAT_MSG_*`
donne des lignes qui ne ressemblent pas à celles qu'on a lues : pas
d'horodatage, pas de couleurs de classe, pas de numéros de canal, et rien de ce
que les autres addons ont ajouté.

**Cause** — le texte d'une ligne de chat n'est pas le message : c'est le produit
du message, des réglages du joueur et de tous les filtres posés par
`ChatFrame_AddMessageEventFilter`. Ce produit se fabrique dans
`ChatFrame_MessageEventHandler`, qui appelle ensuite `frame:AddMessage`.

**Ce qu'on fait** — on se raccroche à `AddMessage` de chaque fenêtre permanente
(`U.GuardedHook`, seul motif de hook autorisé). On y relève le texte final et sa
couleur, et on le rejoue tel quel à la connexion suivante. C'est la même leçon
que pour les auras de la cible : **on s'accroche à la fonction qui produit la
donnée, on ne la refabrique pas**.

Deux pièges qui vont avec :

- **le rejeu se relève lui-même.** Rejouer l'historique appelle `AddMessage`,
  donc notre propre relevé : sans un drapeau qui le fait taire pendant le rejeu,
  chaque session recopie la précédente et l'historique se duplique à l'infini.
  Le drapeau retombe **après** un appel protégé, sinon une erreur au milieu du
  rejeu laisse le relevé muet pour le reste de la session ;
- **les fenêtres temporaires sont écartées** (`frame.isTemporary`) : leur numéro
  est réattribué au chuchotement suivant, ce qui mélangerait deux historiques.

L'historique n'est pas un réglage : il vit dans le SavedVariables du personnage
via `DB:CharData`, hors du mécanisme de défauts. Passer par `Set` émettrait un
message interne par ligne de chat reçue.

---

## Couleurs de discussion : `ChangeChatColor` s'annonce, donc se rappelle

**Symptôme** — aligner les couleurs de groupe, d'instance et de raid marche, puis
l'interface repeint sans fin dès qu'on écoute `UPDATE_CHAT_COLOR` pour suivre les
changements du joueur.

**Cause** — `ChangeChatColor(type, r, g, b)` émet `UPDATE_CHAT_COLOR`. Un
gestionnaire qui repeint sur cet événement se rappelle donc lui-même, et un
drapeau « je suis en train de peindre » ne suffit pas : la rafale du client
arrive après lui.

**Ce qu'on fait** — on ne repeint que ce qui **diffère** de la couleur voulue,
relue dans `ChatTypeInfo`. Un rappel qui n'a rien à changer n'émet rien, et le
va-et-vient converge de lui-même. Le drapeau reste, pour ignorer nos propres
annonces pendant la passe.

`ChatTypeInfo[type]` porte `r`, `g`, `b` — c'est la source de vérité, y compris
pour relever les couleurs d'origine avant d'y toucher. `RAID_WARNING` est
volontairement hors de la famille unifiée : il est fait pour interrompre la
lecture, l'aligner sur le reste le ferait taire.

---

## Redimensionner une fenêtre de chat

**Symptôme** — `StartSizing` sur la fenêtre qu'on tire ne donne rien de durable :
la taille revient à la précédente dès que le client remet ses fenêtres en place.

**Cause** — les fenêtres **arrimées** partagent la taille du meneur de leur dock.
Redimensionner une fenêtre arrimée revient à demander une taille que le dock
écrase aussitôt.

**Ce qu'on fait** — le cadre réellement redimensionné est
`GENERAL_CHAT_DOCK.primary` quand `frame.isDocked` est vrai, et résolu **à chaque
prise** : une fenêtre peut être arrimée ou détachée entre deux glissers.
`FCF_SavePositionAndDimensions(frame)` range ensuite la nouvelle taille dans la
disposition du client — elle survit alors au rechargement sans que nous ayons
rien à mémoriser, et même si l'addon est désinstallé.

**La poignée, c'est l'onglet.** Le placement est le vrai sujet de cette note, et
quatre formes ont été essayées dans cet ordre — les trois premières ont été
écrites puis retirées :

1. une **bande le long du bord haut, à l'intérieur** : elle couvre les premiers
   pixels de la ligne la plus haute et y rend un lien inatteignable ;
2. un **maintien du clic sur toute la fenêtre** : ça marche, mais rien ne
   l'annonce, et il faut une boucle pour distinguer le clic du maintien ;
3. une **poignée qui dépasse au-dessus du coin haut-droit**, avec la texture de
   grabber du client : rien n'est recouvert, mais c'est une pièce de plus à
   l'écran pour un geste qu'on fait deux fois par mois ;
4. l'**onglet lui-même** (`ChatFrame1Tab`), qu'on tire vers le haut ou vers le
   bas. Aucune texture ajoutée, aucune surface disputée, et la souris est déjà
   dessus quand on veut changer la fenêtre de chat.

La leçon vaut au-delà : **avant d'ajouter une poignée, chercher la surface du
client qui ne sert pas à lire.** L'onglet est le seul endroit du chat dans ce cas.

Trois points qui font que le geste ne casse rien :

- **`HookScript` et non `SetScript`** : le clic qui change d'onglet appartient au
  client et doit continuer d'arriver. Le hook ne se dépose pas plus que
  `hooksecurefunc` — d'où `U.GuardedScript`, qui le pose une fois et le rend
  inerte par une garde (CLAUDE.md règle 6) ;
- **le clic court ne redimensionne rien** : sans mouvement du curseur, le
  `StartSizing` posé sur `OnMouseDown` et le `StopMovingOrSizing` posé sur
  `OnMouseUp` s'annulent. Aucun délai de maintien n'est donc nécessaire ;
- **le relâchement revient toujours à l'onglet** qui a reçu l'appui, même si le
  curseur l'a quitté : le moteur le garantit, c'est ce qui rend le motif
  `OnMouseDown` / `OnMouseUp` correct sans boucle de surveillance. `OnHide`
  reste en filet, un onglet pouvant disparaître à un arrimage.

**Fenêtre déverrouillée** : le client fait de son onglet une poignée de
déplacement (`FCF_Tab_OnDragStart`), qui démarre au seuil de glisser, donc après
notre `StartSizing`. Un cadre ne peut ni bouger ni se redimensionner en même
temps : le dernier appel gagne, et c'est celui du client. Le déplacement l'emporte
donc là où le joueur l'a explicitement autorisé, ce qui est le bon ordre.

---

## Sortir du texte d'une fenêtre de chat

**Symptôme** — rien ne se sélectionne dans le chat : ses lignes sont dessinées,
pas saisies.

**Cause** — une `ScrollingMessageFrame` peint son texte. Il n'existe aucune
sélection à la souris, et donc aucun presse-papier.

**Ce qu'on fait** — on relit les lignes (`GetNumMessages` / `GetMessageInfo`) et
on les repose dans une zone de saisie multiligne, tout sélectionné. Trois détails
qui ne se devinent pas :

- la zone de saisie est **l'enfant défilant lui-même** et non le contenu d'une
  frame intermédiaire : une zone multiligne calcule sa propre hauteur d'après son
  texte, un parent obligerait à mesurer ce texte à sa place ;
- les échappements se retirent dans l'ordre : un lien garde ce qu'il
  **affichait** (`|H.-|h(.-)|h` → `%1`), les textures et atlas en ligne n'ont pas
  d'équivalent en texte et disparaissent ;
- le rappel « Ctrl+C » vit **hors** de la zone de texte, faute de quoi il est
  sélectionné avec le reste et part dans le presse-papier.

## Le portrait d'un cadre d'unité se repeint sans arrêt

`UnitFramePortrait_Update(frame)` est la fonction qui décide de ce qui remplit la
case du portrait : un visage, ou une icône de classe si le joueur préfère. Elle
est rappelée à chaque changement de cible, à chaque entrée en véhicule, à chaque
fois que l'unité change sous le cadre. Y poser une image sans s'accrocher à cette
fonction donne une icône qui disparaît au premier changement de cible.

Deux détails qui se paient cher si on les oublie :

- **remettre les coordonnées de texture à plein cadre.** Quand le client dessine
  une icône de classe, il découpe une vignette dans une planche commune et laisse
  ce découpage sur la texture. Une image entière posée derrière n'en montrerait
  alors qu'un coin ;
- **pour rendre le portrait, rappeler `UnitFramePortrait_Update`** plutôt que de
  reposer une texture à la main. Lui seul sait ce que le joueur a choisi de voir
  dans cette case — reposer un visage choisirait à sa place.

Le portrait se trouve sous `frame.portrait` sur les cadres montés par
`UnitFrame_Initialize`, sous `frame.Portrait` sur les cadres de cible de la
cible, et sous `PlayerFrame.PlayerFrameContainer.PlayerPortrait` pour le joueur.

## `CheckFaction` recolore la plaque de faction, il ne la réaffiche pas

**Symptôme** — masquer la couleur de réputation derrière le nom de la cible
fonctionne ; décocher le réglage ne la ramène pas. Elle ne revient qu'au
`/reload`.

**Cause** — `CheckFaction` recalcule la **couleur** de `ReputationColor` et rien
d'autre. Le client ne l'affiche jamais explicitement, parce qu'il ne la cache
jamais : un `Hide` posé par un addon est donc sans retour, et lui demander de
recalculer ne défait pas ce qu'il n'a pas fait.

**Ce qu'on fait** — on pose une **opacité nulle** au lieu de masquer. La
visibilité reste entre les mains du client, on ne fait que rendre invisible ce
qu'il montre ; reposer l'opacité relevée rend exactement son état.

C'est la règle générale quand on veut effacer un élément d'un cadre du client
sans lui disputer sa logique d'affichage : `SetAlpha(0)` se rend, `Hide` se
dispute.

## Une chaîne secrète est une chaîne : `type()` ne la trie pas

**Symptôme** — le mode sombre cesse de s'appliquer aux **cadres d'unités** le
jour où un module se met à poser une couleur de classe sur les barres de vie.
Les autres éléments — barres d'action, auras, infobulle — continuent très bien.
Rien dans le symptôme ne relie les deux : le module ne touche ni à l'habillage,
ni au moteur d'assombrissement, et son diff ne croise celui du moteur nulle part.

Le message, obtenu en rejouant le passage à la main :

    Shade.lua: attempt to index local 'name' (a secret string value,
    while execution tainted by 'BshamelUI')

**Cause** — `GetDebugName()` rend son nom en **valeur secrète** dès que
l'exécution est teintée par un addon. Un module qui se branche sur les cadres
d'unités (`UnitFrameHealthBar_Update`, `UnitFramePortrait_Update`) teinte
précisément le chemin par lequel le moteur les parcourt ensuite.

Le garde en place — `if type(name) ~= "string" then return nil end` — ne voit
rien passer : **une chaîne secrète a bien le type `string`**. C'est l'indexation
suivante, `name:match(...)`, qui lève. Et comme le nom était lu hors de tout
appel protégé, l'erreur ne coûtait pas une texture mais **tout le parcours de
l'élément**.

**Ce qu'on fait** — deux choses, et il faut les deux :

- `debugName` écarte les valeurs secrètes en plus des non-chaînes
  (`U.IsSecret`). Sans nom on ne perd que le rattrapage : le classement retombe
  sur les clés que le cadre publie, et le nom n'a jamais servi qu'à *écarter* ;
- la reconnaissance des textures d'état est appelée sous `pcall`, comme le
  classement l'était déjà. Un échec ne coûte plus que la texture concernée.

**La leçon générale** — dès qu'une valeur vient du client et qu'on s'apprête à
l'indexer, à la multiplier ou à s'en servir comme clé, `type()` ne suffit pas :
il faut `U.IsSecret`. Et tout ce qui interroge le client depuis un parcours doit
échouer **par élément parcouru**, jamais en bloc — sinon le symptôme visible
(« la fonctionnalité entière ne marche plus ») ne ressemble en rien à sa cause
(« une région sur vingt a refusé de répondre »).

## Un cadre d'unité se rafraîchit en trois passages, pas en un

**Symptôme** — le réglage s'applique, mais avec un temps de retard visible :
on cible quelqu'un, le cadre s'affiche un court instant dans son état par
défaut, puis se corrige. Le même symptôme s'était déjà produit avec le mode
sombre.

**Cause** — un rafraîchissement groupé (`U.Debounce`) est le bon outil pour
**ne pas repasser vingt fois**, et le mauvais pour **arriver à l'heure**. Tout
regrouper revient à ne rien faire avant que la rafale ne retombe. Et un
changement de cible n'a pas un seul instant utile, il en a trois :

1. l'annonce (`PLAYER_TARGET_CHANGED`) ;
2. cinq centièmes plus tard, le moment où le client a fini de **rhabiller** le
   cadre — il le fait *après* avoir annoncé ;
3. deux dixièmes plus tard, quand ce qui dépend d'une réponse est arrivé : la
   cible de la cible n'est pas résolue quand la cible l'est, et une inspection
   revient quand elle revient.

**Ce qu'on fait** — les trois passages, dans cet ordre : immédiat, court délai,
puis groupé. C'est ce que fait `refresher` dans `Modules/General.lua` pour le
mode sombre, et `Modules/UnitFrames.lua` pour ses réglages.

La condition qui rend ce motif praticable est que chaque passage soit
**idempotent** : il relit l'état voulu et le repose, sans partir de l'état
courant. Repasser ne coûte alors que le passage — jamais un clignotement (voir
« Repeindre ne doit jamais repasser par l'état d'origine »).

Effet de bord à ne pas oublier : ce qui **déclenche une requête** doit partir au
premier passage. Une demande d'inspection posée seulement dans le passage groupé
ajoute le retard du rafraîchissement à celui du serveur, et les deux se voient.
---

## Annoter les objets rangés sans connaître les cadres qui les portent

**Symptôme** — poser un niveau d'objet sur les objets des sacs, de la banque et
de la banque de bataillon demande de trouver les boutons. Les trois interfaces
ont des structures différentes, et celle de la banque a été refondue.

**Ce qu'on ne fait pas** — s'accrocher à une fonction du client. Les deux
candidates échouent chacune pour sa raison :

- `hooksecurefunc("SetItemButtonQuality", …)` ne se déclenche que si le code du
  client appelle bien la **globale**, alors qu'il peut passer par la méthode de
  mixin du bouton ;
- `hooksecurefunc(ItemButtonMixin, "SetItemButtonQuality", …)` ne sert à rien sur
  les boutons **déjà créés** : un mixin XML **copie** ses fonctions sur la frame
  à sa création. Hooker la table après coup ne touche que les frames à naître.

**Ce qu'on fait** — un parcours de l'arbre des cadres, borné en profondeur, à
partir d'une liste de racines nommées : `ContainerFrameCombinedBags`,
`ContainerFrame1` à `13`, et `BankFrame`. `GetChildren` est stable depuis
toujours, et ne suppose rien de la disposition interne.

Un bouton publie son sac de trois façons selon son âge — `button:GetBagID()`, le
`GetBagID()` de son parent, ou un champ `bagID` —, et son emplacement par
`GetID()`. **Le couple obtenu n'est retenu que si `C_Container.GetContainerItemLink`
y reconnaît un objet** : c'est ce qui empêche d'écrire un nombre sur un cadre qui
n'est pas un bouton d'objet. En cas d'échec, rien ne s'affiche — jamais une
valeur fausse.

`BankFrame` couvre à lui seul la banque du personnage **et** la banque de
bataillon : depuis leur refonte, les deux sont des onglets d'une même fenêtre.

---

## Identifiants de sac de la banque, depuis Midnight

Les onglets de banque ne sont plus des sacs numérotés à la main. Ils se lisent
dans `Enum.BagIndex` :

- banque du personnage : `CharacterBankTab_1` à `CharacterBankTab_6` ;
- banque de bataillon : `AccountBankTab_1` à `AccountBankTab_5`.

Les métadonnées d'un onglet (nom, icône, achat) passent par
`C_Bank.FetchPurchasedBankTabData(Enum.BankType.Character | .Account)`.

On ne s'en sert pas pour l'étiquetage — le parcours de l'arbre lit le sac sur le
bouton lui-même —, mais c'est le chemin à prendre pour toute lecture d'un onglet
sans passer par son interface.

---

## Les étiquettes d'un pool ne se rangent pas dans le cadre

Un bouton de conteneur sort d'un pool : il est recyclé d'un objet à l'autre, et
le client peut le rendre à tout moment. Ranger notre `FontString` dans un champ
posé sur le bouton pose deux problèmes — on écrit sur un cadre qui porte une
chaîne d'exécution sécurisée, et la référence survit au recyclage.

Une table **à clés faibles** (`__mode = "k"`) tenue par le widget règle les deux :
rien n'est écrit sur le cadre, et un bouton oublié par le client l'est aussi par
nous. Elle sert en plus d'inventaire — c'est elle qui permet de tout effacer à la
désactivation du module sans avoir à retrouver les boutons.
