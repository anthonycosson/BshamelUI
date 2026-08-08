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

## La même lecture vaut pour l'inspection, sauf le niveau d'objet

Tout le tableau ci-dessus part d'un **lien**, et `GetInventoryItemLink(unit, slot)`
en rend un pour n'importe quelle unité inspectée : enchantement, châsses, gemmes,
rang d'amélioration et classe d'objet se lisent donc à l'identique sur quelqu'un
d'autre. `C_TooltipInfo.GetInventoryItem(unit, slot)` prend lui aussi l'unité, ce
qui couvre le noyau du vide.

**La seule exception est le niveau d'objet.** `ItemLocation` ne sait désigner que
l'inventaire du joueur : `CreateFromEquipmentSlot` y renvoie toujours à
`"player"`, quelle que soit l'unité regardée — il n'y a pas d'argument d'unité à
lui passer. Pour une autre unité il reste `C_Item.GetDetailedItemLevelInfo(link)`,
qui lit les identifiants de bonus du lien. C'est ce que le serveur envoie de
l'inspection, donc il n'y a rien de plus juste à lire.

Trois points de mise en œuvre :

- `Blizzard_InspectUI` est **chargé à la demande** : `InspectFrame` et ses
  boutons `Inspect<Nom>Slot` n'existent pas au démarrage. La construction se
  diffère à `ADDON_LOADED` ;
- l'unité regardée est `InspectFrame.unit`, et c'est en général `"target"`. Elle
  se **relit à chaque passage** plutôt que de se retenir : le client suit
  lui-même les changements de cible tant que la fenêtre est ouverte ;
- l'équipement arrive par `INSPECT_READY`, c'est-à-dire après coup. Les données
  d'objet, elles, peuvent arriver plus tard encore — `GET_ITEM_INFO_RECEIVED` à
  cadence lâche est le rattrapage, exactement comme pour la fiche du joueur.

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

`Modules/Character.lua` porte donc une table, `ENCHANTABLE`, qui est un fait de
jeu et la seule chose du module qui puisse afficher du rouge à tort.

Un cas se déduit quand même, et il vaut la peine : la **main gauche** ne
s'enchante que si c'est une arme. Un bouclier ou un objet tenu occupe le même
emplacement et n'accepte rien.

---

## L'étoile de rang d'un enchantement se recopie, elle ne se reconstruit pas

La ligne d'infobulle `type = 15` porte l'étoile de rang sous la forme
`|A:nom-d-atlas:h:l|a`. **Prendre le nom entier**, avec
`text:match("|A:([^:|]+)")`, et le poser tel quel : c'est exactement ce que le
joueur voit dans l'infobulle, et un nom d'atlas ne se traduit pas.

Le piège est d'en lire seulement le chiffre — `[Tt]ier(%d)` — et de reconstruire
le nom autour d'un préfixe choisi. Cela paraît plus propre et se trompe : le jeu
a **plusieurs familles d'étoiles de qualité**, et l'échelle diffère selon ce
qu'on crafte. Une pièce d'équipement va jusqu'à cinq qualités, un consommable ou
un enchantement s'arrête bien avant, et le rang 1 de l'un n'a ni le dessin ni la
couleur du rang 1 de l'autre. Reconstruire le nom, c'est parier sur la famille.

Trois essais successifs ont raté pour cette seule raison — 1/5, puis 2/3 — avant
de constater qu'aucun couple de numéros ne pouvait être bon : le numéro seul ne
dit pas de quelle icône il parle. Le nom, si.

Corollaire, dans `UI/Widgets/SlotInfo.lua` : un atlas venu du client peut ne plus
exister. `T.TrySetAtlas` rend `false` dans ce cas, et l'icône retombe alors sur
une texture de repli plutôt que de rester vide.

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

## Un booléen secret ne se teste pas, et l'ordre des gardes compte

**Symptôme** — trois erreurs sans rapport apparent, relevées par BugSack dans la
même session, dont une à **339 occurrences** :

    UnitFrames.lua:400: attempt to perform boolean test on a secret boolean
    value (execution tainted by 'BshamelUI')

    Chat.lua:97: attempt to compare local 'text' (a secret string value,
    while execution tainted by 'BshamelUI')

**Cause** — c'est la même que celle de la note précédente, étendue à deux formes
qu'on n'avait pas vues venir :

- **le booléen.** `UnitIsUnit` répond en valeur secrète dès que l'identité d'une
  des deux unités est protégée. Un booléen secret ne se compare pas *et ne se
  teste pas* : `if UnitIsUnit(unit, "player") then` lève à lui seul. C'est la
  seule famille de valeurs dont la simple lecture dans un `if` suffit à casser le
  chemin — d'où le compteur à trois cent trente-neuf ;
- **l'ordre des gardes.** `type(text) ~= "string" or text == ""` laisse passer
  une chaîne secrète — elle *est* de type `string` — et lève sur la comparaison
  suivante. Le garde de secret doit donc venir **avant** toute comparaison, pas
  à la fin de la liste des tests, où il ne protège plus rien. Deux endroits
  écrivaient déjà `U.IsSecret` en dernier (`Modules/Teleports.lua`) : ils
  n'avaient pas encore levé, faute d'être passés sur une valeur secrète.

Le texte d'une ligne de chat est secret dès que **notre propre hook** a teint
l'exécution : `AddMessage` reçoit alors une chaîne qu'on ne peut ni comparer ni
ranger. La ligne n'entre pas dans l'historique, et c'est aussi bien — rien de
secret ne doit atterrir dans un SavedVariables.

**Ce qu'on fait** — `U.IsTrue` (`Core/Util.lua`) est le seul test permis sur un
booléen venu du client, et un secret y vaut « non » : le client cache ces
réponses là où il refuse de nous laisser conclure, et conclure quand même serait
plus faux que de s'abstenir.

**La leçon générale** — la note précédente disait « avant d'indexer, de
multiplier ou de servir de clé ». Il faut y ajouter : **avant de comparer, et
avant de tester**. Autrement dit, un `U.IsSecret` (ou `U.IsTrue`) se place à la
frontière — là où la valeur arrive du client — et jamais au milieu d'une
conjonction dont un maillon antérieur touche déjà la valeur.

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
mode sombre, où l'on n'a pas de prise plus fine : le moteur teinte des dizaines
de textures qu'on ne peut pas toutes coiffer une par une.

**Quand on a cette prise, elle vaut mieux.** `Modules/UnitFrames.lua` est parti
de ce motif-là et l'a quitté : trois passages laissaient encore voir le cadre
par défaut, et se brancher sur la texture a supprimé le délai au lieu de le
raccourcir (voir « Pour ne pas courir après le client, se brancher sur sa
texture »). Le motif à trois passages est un pis-aller, pas une cible.

La condition qui rend ce motif praticable est que chaque passage soit
**idempotent** : il relit l'état voulu et le repose, sans partir de l'état
courant. Repasser ne coûte alors que le passage — jamais un clignotement (voir
« Repeindre ne doit jamais repasser par l'état d'origine »).

Effet de bord à ne pas oublier : ce qui **déclenche une requête** doit partir au
premier passage. Une demande d'inspection posée seulement dans le passage groupé
ajoute le retard du rafraîchissement à celui du serveur, et les deux se voient.

## Pour ne pas courir après le client, se brancher sur sa texture

**Symptôme** — un réglage posé sur un cadre d'unité s'applique « avec un temps
de retard » : on cible quelqu'un, le cadre s'affiche un battement dans son état
par défaut, puis se corrige. Ajouter un passage immédiat sur
`PLAYER_TARGET_CHANGED` ne suffit pas, et déplacer les passages non plus.

**Cause** — l'événement est annoncé **avant** que le client n'ait redessiné le
cadre. Un passage posé sur l'événement travaille donc sur l'ancien état ; le
client peint ensuite le sien par-dessus. Les hooks « déclarés »
(`UnitFramePortrait_Update`, `CheckFaction`) n'y suffisent pas davantage : le
client repasse sur la case **après** eux, à un moment qu'aucun contrat ne fixe.

Toute la famille des correctifs par minuterie est perdue d'avance. Elle parie
sur l'instant où le client s'y met, et le pari se perd des deux côtés : trop tôt
on peint l'ancienne cible, trop tard le joueur a vu l'état par défaut.

**Ce qu'on fait** — on se branche sur **la texture elle-même**, pas sur la
fonction censée la peindre : `SetTexture` pour un portrait, `SetAlpha` et `Show`
pour une plaque qu'on veut effacée. Quoi que le client écrive, et quand qu'il
l'écrive, notre écriture part dans le même souffle. Il n'y a plus de moment à
deviner, donc plus de délai.

Deux précautions :

- **couper la récursion.** Notre propre écriture rappelle le hook. Un drapeau
  (`painting`) pour une pose de texture ; pour une opacité, il suffit de
  n'agir que si la valeur reçue est non nulle — reposer zéro rappelle le hook
  avec zéro, qui ne fait rien ;
- **garder un passage groupé pour ce qu'aucune écriture n'annonce** : la cible
  de la cible n'est pas résolue quand la cible l'est, et ce qui dépend d'une
  réponse du serveur doit être **demandé au premier passage**, pas au dernier —
  sinon le retard du rafraîchissement s'ajoute à celui du serveur.

## La spécialisation d'un autre joueur se lit, elle ne se demande pas

**Symptôme** — l'icône de spécialisation arrive systématiquement après coup sur
une nouvelle cible, et parfois jamais. Aucun réglage du rafraîchissement n'y
change rien : le délai ne vient pas de nous.

**Cause** — l'inspection (`CanInspect` / `NotifyInspect` / `INSPECT_READY` /
`GetInspectSpecialization`) est le chemin **déclaré**, et c'est un aller-retour
serveur. Il coûte trois choses qu'aucun code ne rattrape : une latence, une
portée de quelques dizaines de mètres, et une demande à la fois — deux cibles
prises coup sur coup et la seconde attend.

**Ce qu'on fait** — on lit l'infobulle de l'unité. Le client **connaît déjà** la
spécialisation des joueurs qu'il affiche : il l'écrit là.
`C_TooltipInfo.GetUnit(unit)` rend ces lignes comme des **données**, sans créer
de frame et sans rien demander à personne — la réponse tombe dans la même image
que la question.

Trois points de mise en œuvre :

- `TooltipUtil.SurfaceArgs(data)` est obligatoire, sinon `line.leftText` est
  absent et la boucle ne trouve jamais rien (même piège que la lecture d'un
  objet équipé dans `Modules/Character.lua`) ;
- **on cherche par classe.** `UnitClass` rend le `classID` en troisième valeur ;
  `GetNumSpecializationsForClassID` et `GetSpecializationInfoForClassID` donnent
  les noms traduits des spécialisations de cette classe-là, et on ne cherche que
  parmi eux. Deux classes peuvent partager un nom — un druide et un chaman ont
  chacun une « Restauration » —, et passer par la classe lève l'ambiguïté sans
  jamais avoir besoin du **nom traduit de la classe**, qui se décline en genre
  selon les langues et demanderait une table d'exceptions par locale ;
- une lecture d'infobulle **alloue une table**. Elle n'est donc appelée que
  depuis un passage de rafraîchissement, jamais depuis un hook de texture
  (règle 7) : le résultat est mis en cache par GUID, et c'est le cache que les
  hooks consultent. Le `false` mis en cache compte autant que le nombre — sans
  lui, une unité sans ligne de spécialisation ferait relire son infobulle à
  chaque écriture du client.

**Trouvé en lisant** BetterBlizzFrames. Aucun code n'en a été repris (règle 8) :
ce qu'on y a lu, c'est *que la réponse est dans l'infobulle*. Leur mise en œuvre
compare la ligne entière à « nom de spé + nom de classe », ce qui les oblige à
gérer les formes genrées et à corriger l'espagnol à la main ; passer par le
`classID` évite tout cela.

## Une décoration contextuelle se range, elle ne se cache pas

**Symptôme** — masquer la lueur de combat, l'effet de repos ou l'icône de coin
« ne tient pas » : l'élément revient au prochain changement d'état.

**Cause** — ce sont des éléments **contextuels**. Le client décide lui-même de
les montrer et de les cacher, et deux d'entre eux portent une animation qui
pilote leur opacité. `Hide` est défait par le prochain `Show`, `SetAlpha(0)` par
la piste d'opacité de l'animation.

**Ce qu'on fait** — on les **reparente** à une frame masquée (`W.Hidden`). Un
élément rangé là ne se dessine plus, quoi que le client lui demande, sans hook à
poser ni moment à deviner. Lui rendre son parent d'origine le remet exactement
où il était.

Deux précautions :

- ces éléments pendent de cadres **protégés** : reparenter en combat lève une
  erreur d'action bloquée. On se garde par `InCombatLockdown` et on rattrape à
  `PLAYER_REGEN_ENABLED` ;
- on garde le parent relevé avant de le changer, jamais un parent supposé.

Les chemins relevés sur le client, tous sous
`PlayerFrame.PlayerFrameContent.PlayerFrameContentContextual` sauf mention :
`PlayerRestLoop` (repos), `PlayerPortraitCornerIcon` (coin), `PrestigeBadge` /
`PrestigePortrait` / `PvpIcon` (JcJ, également sous
`TargetFrameContent.TargetFrameContentContextual` pour la cible et le focus).

**La lueur de combat n'est pas une décoration du cadre du joueur.** C'est un même
signal posé sur **chaque cadre engagé**, et son nom change d'un cadre à l'autre :

| Cadre | Chemin |
|---|---|
| joueur | `PlayerFrame.PlayerFrameContainer.FrameFlash` |
| cible / focus | `<Frame>.TargetFrameContainer.Flash` |
| boss 1 à 5 | `Boss<i>TargetFrame.TargetFrameContainer.Flash` |
| familier | `PetFrameFlash`, `PetAttackModeTexture` |

N'en éteindre qu'une partie ne se lit pas comme un réglage partiel mais comme un
réglage qui ne marche pas — le cadre du joueur se tait, celui de la cible
continue de battre, et on conclut que l'option est cassée. Le nom qui diffère
(`FrameFlash` contre `Flash`) est la raison de citer les chemins un par un
plutôt que de croire à une convention.

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

---

## Un bouton sécurisé recyclé garde l'action du précédent

**Symptôme** — dans le menu de téléportation, une ligne lance la téléportation
d'une autre ligne. Le nom et l'icône sont pourtant les bons.

**Cause** — un bouton d'action sécurisé décrit ce qu'il lance par des attributs :
`type` dit lequel de `item`, `toy` ou `spell` s'applique, et l'attribut du même
nom porte la charge. Une ligne recyclée d'une pierre de foyer vers un sort voit
son `type` passer à `spell`… en gardant son ancien attribut `toy`. Le jour où le
`type` repasse à `toy`, c'est la charge d'il y a trois reconstructions qui part.

**Ce qu'on fait** — `UI/Widgets/SecureMenu.lua` réécrit **les trois** attributs
de charge à chaque réemploi, en remettant à `nil` ceux qui ne servent pas.

Deux autres faits d'API relevés au même endroit :

- la charge d'un `type = "item"` est un lien (`"item:6948"`), pas un nombre : un
  nombre est lu comme un **emplacement d'inventaire** ;
- une ligne doit s'enregistrer sur `AnyUp` **et** poser
  `useOnKeyDown = false`. Sans ça, la CVar `ActionButtonUseKeyDown` — que le
  module Barres d'action expose — fait partir l'action deux fois, et le second
  départ annule la téléportation que le premier avait commencée.

Enfin, aucun attribut ne s'écrit en combat, et un bouton sécurisé ne se montre ni
ne se cache : le menu ne s'ouvre donc pas pendant un combat, et se reconstruit à
`PLAYER_REGEN_ENABLED`.

---

## Un bouton de minicarte emprunté retourne se poser sur la carte

**Symptôme** — les boutons d'addons rangés dans le tiroir en ressortent tout
seuls, un par un, et se reposent sur le pourtour de la minicarte. Ils sont
pourtant bien nos enfants : `GetParent()` rend le tiroir.

**Cause** — la position d'un bouton de bibliothèque ne dépend pas de son parent.
`LibDBIcon` et consorts l'ancrent à `Minimap` par un angle, et **réappliquent cet
ancrage** dès qu'ils rafraîchissent quoi que ce soit. Un `SetPoint` sur un cadre
étranger nous passe donc devant sans prévenir.

**Ce qu'on fait** — l'emprunt masque `SetPoint` et `ClearAllPoints` sur le cadre
le temps du séjour, en gardant les vraies méthodes pour notre propre mise en
page (`UI/Widgets/Tray.lua`). Le masquage se retire au retour : une méthode qui
n'appartenait pas au cadre redevient absente — `rawget` le dit —, une méthode
qu'il portait lui-même lui est rendue.

Le parent, lui, se reprend à chaque passage : certaines versions rattachent le
bouton à `Minimap` en le rafraîchissant, et un bouton sorti du tiroir avec ses
ancrages masqués serait posé n'importe où sans moyen d'en bouger.

---

## Vendre la camelote ne se fait pas en un appel

**Symptôme** — `C_MerchantFrame.SellAllJunkItems()` est appelée à
`MERCHANT_SHOW`, et il reste des gris dans les sacs.

**Cause** — l'appel part sans accusé de réception. Le serveur écarte les ventes
au-delà de sa limite de débit, et une case dont l'objet n'est pas encore en cache
au moment de l'ouverture n'est pas vue du tout.

**Ce qu'on fait** — `Modules/Bags.lua` recompte les gris après chaque passe et
recommence tant que le nombre baisse. L'arrêt vient de l'absence de progrès, pas
d'un délai : c'est elle qui prouve qu'il ne reste rien à tenter.

---

## Le mot de la confirmation de destruction

Détruire un objet de valeur demande d'écrire un mot dans la zone de saisie du
dialogue. Le mot est publié par le client (`DELETE_ITEM_CONFIRM_STRING`), donc
juste dans toutes les langues.

Le dialogue se reconnaît à son champ `which` : `DELETE_GOOD_ITEM` et
`DELETE_GOOD_QUEST_ITEM` sont les deux qui portent une zone de saisie.

Le hook se pose sur **`Show`** et non sur le script `OnShow` : le client vide la
zone dans son `OnShow`, qui s'exécute *pendant* `Show`. Un hook posé sur `Show`
se termine après lui, et c'est donc le dernier à écrire.

---

## La rotation de donjons et sa téléportation se demandent au client

**Symptôme** — un menu de téléportation de donjons construit sur une liste
d'identifiants écrite à la main est faux au premier changement de saison, et il
est faux **en silence** : les donjons sortis restent proposés, les nouveaux
manquent, et rien ne le signale.

**Ce qu'on fait** — `Modules/Teleports.lua` ne tient aucune liste de donjons, et
n'en construit même pas une : le contenu vient **entièrement du grimoire** (voir
la note suivante). Le mode défi ne sert qu'à une chose, l'**ordre** :

- `C_ChallengeMode.GetMapTable()` rend les cartes de la saison en cours ;
- `C_ChallengeMode.GetMapUIInfo(mapID)` rend le nom du donjon, et sur les clients
  qui le publient, **le sort de téléportation en septième valeur**.

Un tiroir du grimoire dont **toutes** les destinations sont dans cet ensemble est
celui de la saison : il passe en tête de menu. Le test doit rester strict — un
donjon d'une vieille extension revient régulièrement dans la rotation, et « au
moins une correspondance » ferait remonter Legion au-dessus de l'extension
courante.

Deux signaux valent pour une destination, et il suffit que l'un réponde : le sort
publié en septième valeur, ou le **nom du donjon**, qui est publié partout. Le
septième retour, lui, n'existe pas sur tous les clients — d'où le second signal,
sans lequel aucun tiroir n'était reconnu.

**Rien du contenu n'en dépend, et l'ordre non plus** — voir la note suivante.

C'est ce qui permet de ne jamais nommer la saison : le tiroir s'appelle « Voie
héroïque : Midnight – Saison 1 » parce que le jeu l'appelle ainsi, et il
s'appellera autrement à la saison suivante sans qu'on y revienne.

Un détail d'affichage qui en découle : la ligne porte le nom qui suit le
deux-points — le donjon —, pas le nom complet du sort, qui répéterait le nom de
la famille à chaque ligne.

---

## Les pierres de foyer se rangent en deux familles, pas en une liste

Il existe une trentaine de « pierres de foyer » et elles ne sont pas
interchangeables du point de vue d'un menu :

- celles à **temps de recharge partagé** font toutes la même chose, retourner au
  point de liaison, et ne diffèrent que par l'animation. Les lister toutes, c'est
  écrire trente fois la même ligne : on en montre une, choisie par un réglage ;
- celles à **temps de recharge propre** (Dalaran, Arcantina, fief) vont chacune
  ailleurs et se rechargent séparément : elles se listent toutes.

Rien dans l'API ne dit à quelle famille appartient un identifiant — c'est une
donnée du jeu, et donc une liste à tenir.

Une pierre se possède de deux façons selon son âge : jouet de la collection
(`PlayerHasToy`) ou objet dans les sacs (`C_Item.GetItemCount`). On ne l'écrit
pas dans la liste, on le redemande : le même identifiant a changé de camp d'une
extension à l'autre.

---

## Les téléportations hors saison se relèvent dans le grimoire

**Symptôme** — `C_ChallengeMode.GetMapTable()` ne rend que la saison en cours.
Les donjons des autres extensions vers lesquels le personnage sait se téléporter
n'apparaissent donc nulle part, alors qu'il les a bel et bien appris.

**Cause** — il n'existe aucune API qui liste « toutes les téléportations de
donjon ». Le seul endroit où elles vivent toutes est le **grimoire**, puisque ce
sont des sorts appris comme les autres.

**Ce qu'on fait** — `Modules/Teleports.lua` parcourt le grimoire :

- `C_SpellBook.GetNumSpellBookSkillLines()` puis
  `C_SpellBook.GetSpellBookSkillLineInfo(i)`, qui donne `itemIndexOffset` et
  `numSpellBookItems` — les index sont **globaux**, une ligne de compétence ne
  fait qu'y ouvrir une fenêtre ;
- `C_SpellBook.GetSpellBookItemInfo(index, Enum.SpellBookSpellBank.Player)` pour
  chaque index ;
- le nom et l'icône sont déjà dans ce que rend le grimoire : on ne réinterroge
  le sort que s'il les a tus.

**Le piège est là : une téléportation de donjon n'est pas un sort.** Le grimoire
range celles d'une extension dans un **tiroir** — un `flyout` —, et
`Enum.SpellBookItemType.Flyout` n'a pas de `spellID` : il porte un `actionID`,
qui est l'identifiant du tiroir. Un parcours qui ne retient que
`Enum.SpellBookItemType.Spell` ne trouve donc **rien**, alors que le grimoire en
montre une page entière. Le symptôme est trompeur : la section reste vide, ce
qui ressemble exactement à un préfixe de nom mal orthographié.

Le contenu d'un tiroir se lit par `GetFlyoutInfo(flyoutID)` — nom, description,
nombre d'emplacements, connu — puis `GetFlyoutSlotInfo(flyoutID, slot)` — sort,
sort de remplacement, connu. Les deux fonctions existent sous leur nom global et
sous `C_SpellBook` selon le client, et rien ne garantit qu'elles rendent des
valeurs plutôt qu'une table : on accepte les deux formes.

Un tiroir par extension donne d'ailleurs la bonne disposition de menu — c'est
celle du grimoire, donc celle que le joueur connaît déjà.

Reste à reconnaître la famille, et le seul point d'accroche est le **nom** : ces
sorts **commencent** par le nom de leur famille (« Voie héroïque : donjon »,
« Voie temporelle : donjon »). Les préfixes sont donc des chaînes du client,
rangées en locale (`Teleport spell prefixes`, séparées par des virgules) comme le
marqueur de noyau du vide de la fiche de personnage. C'est la deuxième fois que
ce motif sert, et il a la même propriété : une locale dont les préfixes sont faux
montre une section vide, jamais une entrée fausse.

Le nombre de préfixes dépend de la langue, et c'est pour ça que la locale en
porte une **liste** : le français réunit toutes les familles sous « Voie », là où
l'anglais les nomme chacune autrement. Un préfixe large ramasse un peu plus que
les téléportations — une classe peut avoir un sort qui commence pareil — et c'est
le compromis retenu : une ligne de trop se voit et s'ignore, un donjon manquant
ne se voit pas.

Le nom affiché est ce qui suit le deux-points — le donjon —, pour que la liste se
lise et se trie comme celle de la saison en cours.

---

## Poser un marqueur au sol est une action protégée

**Symptôme** — `PlaceRaidMarker(index)` appelé depuis un bouton ordinaire ne pose
rien. Pas d'erreur en dehors du combat, juste aucun marqueur.

**Cause** — c'est une action protégée, comme lancer un sort : le client exige que
le clic vienne de son moteur, pas de notre code.

**Ce qu'on fait** — `UI/Widgets/MarkerBar.lua` bâtit ses cases sur le template
d'action sécurisée et les décrit par attributs :

| Attribut | Valeur |
|---|---|
| `type` | `"worldmarker"` |
| `marker` | 1 à 8, **absent** pour tout effacer |
| `action` | `"set"` ou `"clear"` |

**« Tout effacer » s'écrit en n'écrivant rien.** Le gestionnaire sécurisé fait
`ClearRaidMarker(tonumber(attribut))` sans rien interpréter, et l'argument de
`ClearRaidMarker` est déclaré `luaIndex` non nul, de défaut « tous ». Zéro n'est
donc pas un « tous » : c'est un index hors plage, et l'appel ne fait rien — sans
erreur, sans message. Le `nil` d'un attribut jamais posé, lui, déclenche le
défaut. C'est ce que fait le bouton de remise à zéro du client, qui appelle
`ClearRaidMarker()` sans argument.

Les attributs sont écrits **une fois**, à la construction : un bouton de marqueur
porte le même numéro toute sa vie. C'est la différence avec le menu de
téléportation, dont les lignes sont recyclées et doivent donc être réécrites en
entier (voir « Un bouton sécurisé recyclé garde l'action du précédent »).

Conséquence héritée du même mécanisme : le panneau **ne se montre ni ne se cache
en combat**. `SetShownOutOfCombat` rend `false` dans ce cas, et l'appelant
repasse à `PLAYER_REGEN_ENABLED`.

**Le joueur règle l'échelle, pas la taille.** La disposition du panneau est
arrêtée à sa construction ; sa poignée appelle `SetScale` sur le panneau et rien
d'autre. C'est ce qui la rend inoffensive ici : `SetSize` et `SetPoint` sur un
bouton sécurisé sont refusés en combat, `SetScale` sur leur parent ne les touche
pas. La poignée reste malgré tout refusée en combat (`canScale`), par prudence et
pour que la notice affichée au joueur reste vraie.

---

## Le décalage d'un ancrage s'exprime dans l'échelle du cadre ancré

**Symptôme** — un panneau mis à l'échelle 2 se retrouve deux fois plus loin du
centre de l'écran qu'il ne devrait, et il s'éloigne encore à chaque cran de la
poignée.

**Cause** — `frame:SetPoint("CENTER", UIParent, "CENTER", x, y)` interprète `x`
et `y` dans l'échelle effective de **`frame`**, pas dans celle d'`UIParent`. Un
décalage de cent pixels vaut donc deux cents pixels d'écran à l'échelle double.

**Ce qu'on fait** — une position rangée est toujours en unités d'`UIParent`,
c'est la seule qui reste vraie quand l'échelle change. `Panel:ApplyPosition` la
convertit au moment de la poser :

```lua
local factor = UIParent:GetEffectiveScale() / self:GetEffectiveScale()
self:SetPoint("CENTER", UIParent, "CENTER", x * factor, y * factor)
```

`Panel:ApplyScale` repose donc la position juste après l'échelle, et la poignée
la repose à chaque cran du geste : sans cela le panneau glisserait sous le
curseur au lieu de gonfler sur place. `savePosition` faisait déjà la conversion
inverse — c'était la moitié aller du même trajet.

**Les deux numérotations ne coïncident pas.** Le marqueur au sol n° 1 est le
carré bleu, qui porte l'icône de ciblage n° 6. Rien dans le client ne relie les
deux : `T.WORLD_MARKER_ICON` est donc une table de données, et elle ne façonne
rien — l'index posé est celui de l'attribut, la table ne décide que de la
vignette. Une entrée fausse met la mauvaise image sur un bouton qui pose quand
même le bon marqueur.

La correspondance se relève dans `WORLD_RAID_MARKER_ORDER`, du gestionnaire de
cadres de raid du client, mais elle y est écrite **à l'envers** : ses vignettes
sont rangées du crâne vers l'étoile, si bien que sa position *i* montre l'icône
de ciblage `9 - i`. Notre table est cette table-là retournée :

| Marqueur au sol | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
|---|---|---|---|---|---|---|---|---|
| Icône de ciblage | 6 | 4 | 3 | 7 | 1 | 2 | 5 | 8 |
| | carré | triangle | losange | croix | étoile | rond | lune | crâne |

La suite se casse au milieu parce qu'elle est historique : les cinq premiers
marqueurs datent de Pandarie, les trois derniers ont été ajoutés en 6.0.2 et se
sont rangés à la fin.

La vérification de présence (`DoReadyCheck`) et le décompte
(`C_PartyInfo.DoCountdown`) ne sont **pas** protégés : ce sont des boutons
ordinaires. Ils exigent en revanche d'être chef ou promu, et refusent en
silence — d'où le message affiché à la place.

---

## Le compteur de résurrections de combat se lit sur un sort de druide

**Symptôme** — aucune API ne s'appelle « charges de résurrection de combat ». Le
nombre que le client affiche dans les instances qui les limitent semble n'exister
nulle part.

**Cause** — il existe, mais il est publié comme **les charges du sort de
Rétablissement** (20484), et pour tout le monde : un mage y lit la réserve
partagée du groupe aussi bien qu'un druide.

**Ce qu'on fait** — `C_Spell.GetSpellCharges(20484)`, avec `GetSpellCharges` en
repli. Le relevé rend `currentCharges`, `maxCharges`, `cooldownStartTime` et
`cooldownDuration` ; hors instance, `maxCharges` vaut zéro, ce qui sert de test
« y a-t-il une réserve à suivre ? ».

La lecture se fait depuis un `OnUpdate` bridé : les deux tables du relevé sont
donc réutilisées et jamais allouées (règle 7).

---

## Le lien d'une clé mythique ne se demande pas, il se cherche dans les sacs

**Symptôme** — `C_MythicPlus.GetOwnedKeystoneMapID()` et `GetOwnedKeystoneLevel()`
donnent le donjon et le niveau, mais **pas le lien**. Or c'est le lien qu'on veut
envoyer dans le chat : lui seul est survolable.

**Ce qu'on fait** — `Modules/Keystones.lua` parcourt les sacs et reconnaît la clé
à son lien (`keystone:`), avec l'identifiant d'objet en second recours. Le texte
« donjon + niveau » reste le repli quand la clé n'est pas dans les sacs — elle
peut être en banque.

**Poser la clé demande de la prendre en main.** `C_ChallengeMode.SlotKeystone()`
pose ce que le curseur porte : la séquence est
`C_Container.PickupContainerItem(bag, slot)` puis `SlotKeystone()`. Deux
précautions évitent de faire tomber quelque chose : ne rien prendre si le curseur
porte déjà un objet (`GetCursorInfo`), et vider le curseur si le socle a refusé
la clé — sinon elle suit la souris.

`C_ChallengeMode.HasSlottedKeystone()` dit si quelqu'un a déjà posé la sienne ; on
ne remplace jamais celle d'un coéquipier.

---

## Le chrono d'une clé ne se compte pas — et ne se réaffiche pas non plus

**Symptôme** — un chrono démarré sur `CHALLENGE_MODE_START` est faux dès qu'on
recharge l'interface au milieu d'une clé, c'est-à-dire précisément au moment où
l'on tient à ce qu'il soit juste.

**Premier remède, insuffisant** — lire le chrono de zone du client :
`GetWorldElapsedTimers()` rend les identifiants,
`GetWorldElapsedTime(timerID)` leur type et leur temps écoulé, le type cherché
étant `Enum.WorldElapsedTimerTypes.ChallengeMode`. C'est juste, mais ça ne fait
que déplacer le problème : on affiche alors **un second chrono** à côté de celui
du client, pour la même clé, et deux chronos ne peuvent qu'être en désaccord d'une
seconde ou d'un dixième.

**Ce qu'on fait** — on n'affiche pas de chrono du tout. Le client en dessine un
dans son suivi d'objectifs, et on lui **ajoute** ce qui manque :

- `ScenarioObjectiveTracker.ChallengeModeBlock` est le bloc de chrono, un cadre
  fixe du module de scénario (`FixedBlocks`), mixé de
  `ScenarioObjectiveTrackerChallengeModeMixin`. Ses pièces utiles : `StatusBar`,
  `TimeLeft`, `Level`, `DeathCount`, `StartedDepleted`, `TimesUpLootStatus`.
- **La barre porte le temps restant, pas le temps écoulé** : `Activate` la borne
  de `0` à `timeLimit` puis lui donne `timeLimit - elapsed`. Un palier accordé
  « sous 60 % du chrono » se lit donc à **40 % de la barre**, et le remplissage le
  franchit en descendant.
- `block:UpdateTime(elapsed)` est la seule fonction qui repose le chrono, appelée
  par `ScenarioTimerFrame`. S'y accrocher fait suivre ce qu'on a ajouté sans rien
  compter de son côté ; `Activate` sert à replacer ce qui dépend de la largeur de
  la barre.
- Les repères sont posés sur le **bloc**, à un sous-calque `OVERLAY` plus haut que
  celui du client, et ancrés sur la barre : l'habillage du bloc est dessiné
  par-dessus sa propre barre pour lui faire un cadre, donc une texture posée sur
  la barre passerait dessous.
- **La barre est un cadre plus haut que son remplissage, et pas symétriquement.**
  `StatusBar` mesure treize pixels ; l'atlas `ChallengeMode-TimerFill` porte une
  marge transparente et n'en occupe pas la totalité. Un repère ancré sur `TOP` et
  `BOTTOM` de la barre dépasse donc du bleu, et une hauteur *centrée* en proportion
  du cadre en dépasse encore — les deux ont été essayées avant d'y voir clair.

  Ce qui marche : **huit pixels de large sur dix de haut, cadrés en haut**. Les
  trois pixels laissés sont ceux du bas, qui est le côté où la marge se trouve.
  Ces mesures sont celles d'Angry Keystones, relevées et non recopiées (règle 8) ;
  sa texture, un DXT3 de 16×16 découpé en deux vignettes, n'est pas embarquée. Elle
  a en revanche appris deux choses : le repère est une **lueur** et non un trait —
  opaque sur le palier, éteinte sur ses deux bords, ce qui demande deux textures
  dos à dos, un dégradé n'allant que dans un sens — et son ton le plus clair vaut
  `(230, 206, 99)`.

Les paliers, eux, ne sont publiés par aucune fonction : ce sont 80 % et 60 % du
chrono, écrits une fois dans `UI/Widgets/KeyThresholds.lua`.
`C_ChallengeMode.GetMapUIInfo(mapID)` rend le nom du donjon **et son chrono en
troisième valeur**, ce qui suffit à remplir un exemple.

---

## Faire poser un bloc du suivi d'objectifs là où le client ne le pose pas

**Symptôme** — on veut montrer le bloc de chrono mythique+ hors donjon, pour voir
ce qu'il donne. Le montrer à la main ne suffit pas : sans passer par la mise en
page du module, le bloc n'a aucun ancrage, et le prochain passage le recache.

**Cause** — `ScenarioObjectiveTrackerMixin:LayoutContents()` sort avant tout le
reste quand `C_Scenario.GetInfo()` ne rend aucune étape. Et `EndLayout` appelle
`FreeUnusedBlocks`, qui cache tout bloc fixe dont `used` n'a pas été mis à vrai
pendant le passage.

**Ce qu'on fait** — on demande la pose **après** son passage, dans un
`hooksecurefunc` sur `LayoutContents` : un hook ne défait pas ce qu'une fonction
du client a décidé, mais il ajoute ce qu'elle n'a pas fait.
`module:LayoutBlock(block)` met `used = true`, ancre le bloc, l'affiche, et
`InternalAddBlock` met `hasContents` à vrai — ce qui suffit à `EndLayout` pour
montrer le module. Il ne reste qu'à demander un passage :
`module:MarkDirty()`, celui-là même que le client s'appelle à lui-même quand son
chrono s'arrête.

Deux gardes s'imposent. `hasContents` **déjà vrai** signifie que le module a posé
son propre contenu (un scénario, un delve) : y coller un bloc de chrono serait un
exemple posé sur du vrai. Et `block:IsActive()` vrai signifie qu'une clé tourne —
c'est alors le vrai chrono qu'on regarde.

L'exemple lui-même passe par les fonctions du client : on remplit `timeLimit`,
`Level`, les bornes de la barre, puis on appelle **son** `UpdateTime`. Un aperçu
ne peut alors pas ressembler à autre chose que le vrai, puisque c'est le vrai qui
dessine. `timerID` reste `nil` : le poser ferait croire au client qu'une clé
tourne.

Les **lignes** d'exemple suivent le même principe, un cran plus loin :
`ObjectivesBlock:Reset()`, puis autant d'appels à son `AddObjective(key, texte,
nil, nil, OBJECTIVE_DASH_STYLE_HIDE, OBJECTIVE_TRACKER_COLOR["Complete"])` que de
lignes voulues, chacune recevant sa pastille (`line.Icon`), et un
`module:LayoutBlock(objectivesBlock)` pour finir. Le décompte de troupes, lui, est
posé en ligne de texte et non en barre de progression : une `AddProgressBar` va
relire le scénario en cours pour se remplir, et hors donjon il n'y en a pas.

---

## Un critère dit qu'il est rempli, jamais quand il l'a été

**Symptôme** — on veut le temps auquel chaque boss est tombé. Rien ne le publie.
`C_ScenarioInfo.GetCriteriaInfo(index)` porte bien `duration` et `elapsed`, mais
ces deux champs servent aux critères **chronométrés** (« survivre trois
minutes ») et valent zéro pour un boss.

**Ce qu'on fait** — on horodate soi-même, sur `SCENARIO_CRITERIA_UPDATE` (doublé
de `SCENARIO_UPDATE`) : à chaque passage, tout critère `completed` qu'on n'avait
pas encore vu reçoit le temps écoulé du client. C'est le seul endroit de l'addon
qui écrive une seconde, et encore : elle est **demandée** au chrono de zone
(`GetWorldElapsedTime`), pas tenue par nous.

**La clé de rangement est `criteriaID`, pas le rang du critère.** Un rang se
réordonne d'un patch à l'autre ; l'historique rangé par rang comparerait alors le
troisième boss d'aujourd'hui au deuxième d'hier.

Puis on redemande une passe au suivi (`module:MarkDirty()`) au lieu de compter sur
la sienne : rien ne garantit l'ordre dans lequel deux cadres reçoivent le même
événement, et un boss horodaté après le passage du suivi ne s'afficherait qu'au
suivant.

**La fin d'une clé est aussi la chute d'un boss.** `CHALLENGE_MODE_COMPLETED` doit
donc horodater avant de ranger, sans quoi la ligne qui compte le plus manque.

---

## Ce que le client garde d'une clé finie, et ce qu'il n'en garde pas

`C_ChallengeMode.GetChallengeCompletionInfo()` rend une **table** :
`mapChallengeModeID`, `level`, `time` (en millisecondes), `onTime`,
`keystoneUpgradeLevels`, et la liste des membres. C'est la forme à préférer — la
variante positionnelle `GetCompletionInfo()`, que le client s'appelle encore à
lui-même, ne figure plus dans sa documentation générée.

Il ne garde en revanche **aucun temps de passage**. Retenir les nôtres ne crée donc
pas de seconde source de vérité à côté de la sienne : il n'y en a pas de première.
C'est la seule mémoire de l'addon, et elle vit dans les données du personnage
(`DB:CharData`), pas dans ses réglages.

**À la fin d'une clé, le client ne dit plus laquelle était active** : `mapID` et
niveau sont donc relevés au départ et retenus, faute de quoi il n'y a plus rien
sous quoi ranger au moment de ranger.

`C_ChallengeMode.GetDeathCount()` rend `numDeaths, timeLost`. Le client affiche le
premier nombre et réserve le second à une **infobulle**, c'est-à-dire à nulle part
quand on court.

---

## Rallonger le texte d'une ligne du suivi d'objectifs oblige à refaire sa hauteur

**Symptôme** — on ajoute un temps à la ligne d'un boss. Sur les noms courts tout
va bien ; sur un nom long, le texte passe à la ligne et l'objectif suivant lui
monte dessus.

**Cause** — `ObjectiveTrackerBlockMixin:AddObjective` pose le texte **et en déduit
la hauteur** : il appelle `SetStringText`, qui rend la hauteur du texte, la donne à
la ligne et l'accumule dans `block.height`. Écrire par-dessus après coup laisse les
deux valeurs sur l'ancien texte.

**Ce qu'on fait** — on refait le calcul avec sa fonction, dans un post-hook de
`AddObjective` : `block:SetStringText(line.Text, texte .. suffixe, useFullHeight,
colorStyle, block.isHighlighted)` rend la nouvelle hauteur, qu'on donne à la ligne,
et on reporte l'écart sur `block.height`. Le reste suit tout seul — les lignes
s'ancrent l'une sous l'autre.

Une ligne est un **seul texte**, donc une seule couleur : un suffixe qui en demande
plusieurs passe par des codes couleur en ligne (`T.Colorize`).

**Le plafond de rangs est dans `SetStringText`, pas dans la ligne.** Il vaut
`SetMaxLines(2)` quand `useFullHeight` est faux, et `SetMaxLines(0)` — sans limite —
quand il est vrai. Un suffixe qui occupe un rang à lui seul, par un `\n` dans le
texte, oblige donc à passer `useFullHeight` vrai : sinon le nom qui passe à la ligne
en demande trois, et c'est le troisième — le suffixe ajouté — qui est coupé.

Le `\n` n'est pas un détail de présentation. Bout à bout, un suffixe tombe après le
nom, donc à un endroit différent pour chaque ligne selon la longueur de ce nom : le
retour à la ligne paraît aléatoire et aucune colonne ne se forme. Forcé, il est au
même endroit partout.

Et la réversibilité est gratuite : on ne retouche rien qui persiste. Éteindre le
réglage et redemander une passe suffit — le client réécrit ses lignes sans nous.

---

## Une bannière qui porte un bouton sécurisé ne se cache pas en combat

**Symptôme** — le rappel de file doit disparaître quand le combat commence. Or il
porte un bouton de téléportation sécurisé, et un cadre protégé ne se cache pas en
combat : `Hide` est refusé au moment exact où l'on en a besoin.

**Fausse piste** — poser une opacité nulle. La bannière devient invisible, mais
son bouton reste **cliquable** : une téléportation part toute seule sous le
curseur au milieu d'un combat.

**Ce qu'on fait** — on sort la bannière de l'écran
(`SetClampedToScreen(false)`, puis un ancrage à deux hauteurs d'écran), ce qui
passe puisque le panneau est à nous, là où cacher son bouton serait refusé. La
fermeture est notée et terminée à `PLAYER_REGEN_ENABLED`.

C'est la même leçon que pour la couleur de faction : quand le client refuse un
geste sur un de ses objets, on cherche ce qu'on peut faire sur **le nôtre**.

---

## Contrôler les buffs : ce que le client publie, et pour qui

| Besoin | Chemin | Portée |
|---|---|---|
| Nourriture, flacon | `C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")` | tout le groupe |
| Expiration | `aura.expirationTime` | tout le groupe |
| Enchantement d'arme | `GetWeaponEnchantInfo()` | **le personnage seul** |

L'enchantement d'arme d'un coéquipier n'est publié nulle part : le contrôle ne
porte que sur soi, et c'est une limite du client, pas un choix. Ses durées sont en
**millisecondes**, là où une aura rend un instant absolu à comparer à `GetTime()`.

**La reconnaissance passe par le nom de l'aura**, rangé en locale
(`Well fed aura`, `Flask aura`, `Phial aura`). Aucun identifiant stable n'existe
côté aura, et une liste d'identifiants de nourritures et de flacons est fausse à
chaque extension — silencieusement. C'est le troisième endroit où ce motif sert,
après le noyau du vide et les préfixes de téléportation, et il garde la même
propriété : une locale fausse signale tout le monde comme non buffé, et se corrige
à un seul endroit. Le français réunit d'ailleurs *flask* et *phial* sous
« Flacon », d'où deux clés qui portent la même valeur.

Un joueur **déconnecté** n'a aucune aura à lire : sans le test `UnitIsConnected`,
son nom apparaît dans toutes les listes à la fois.

---

## Annoncer les morts sans faire couper la parole par le serveur

**Symptôme** — une annonce par mort donne vingt messages en une seconde sur un
wipe, et le serveur coupe alors la parole pour plusieurs dizaines de secondes.

**Ce qu'on fait** — les noms sont accumulés et une seule ligne part une seconde
plus tard (`U.Debounce`), avec un seul son. Le regroupement n'est pas une
optimisation, c'est ce qui rend la fonctionnalité utilisable.

**On lit les drapeaux du journal, pas les noms.** `COMBATLOG_OBJECT_TYPE_PLAYER`
et les trois drapeaux d'affiliation (`MINE`, `PARTY`, `RAID`) disent si la mort
concerne le groupe. Comparer des noms échouerait précisément sur les groupes
formés par la recherche de groupe, où ils portent un suffixe de royaume.

Le journal peut par ailleurs annoncer **deux fois** la même mort : la liste
accumulée sert aussi à ne nommer personne deux fois.

---

## Journaliser un combat sans journalisation détaillée ne sert presque à rien

`LoggingCombat(true)` suffit à écrire le journal, mais sans la CVar
`advancedCombatLogging` il ne porte ni positions, ni ressources, ni la moitié de
ce que les sites d'analyse lisent. Les deux vont donc ensemble, et la CVar est
relevée avant d'être changée puis reposée, comme toutes les CVar de l'addon.

On ne coupe la journalisation que si **c'est nous qui l'avions lancée** : couper
celle qu'un joueur a lancée à la main serait défaire son geste.

`GetInstanceInfo()` donne le type d'instance ;
`C_ChallengeMode.IsChallengeModeActive()` reconnaît une clé plus sûrement qu'un
numéro de difficulté — un numéro est une donnée qui bouge, une capacité non.

---

## Un cadre protégé ne se range pas dans un tiroir

**Symptôme** — « BshamelUI a été bloqué à cause d'une action qui n'est utilisable
que par l'IU de Blizzard », sans erreur Lua, alors qu'aucun cadre du client n'est
touché volontairement.

**Cause** — le tiroir de boutons d'addons emprunte ce qu'il trouve autour de la
minicarte : il reparente, change la strate et le niveau. Ces trois gestes sont
refusés sur un cadre **protégé**, et il y en a deux sortes autour de la carte :
ceux du client — le client en ajoute à chaque extension, une liste de noms est
donc périmée d'avance — et ceux des addons qui bâtissent leur bouton sur un
template sécurisé, ce que fait tout bouton qui lance un sort.

**Ce qu'on fait** — on pose la question au cadre lui-même,
`frame:IsProtected()`, plutôt qu'à une liste de noms : la réponse est juste sur
les deux sortes, et elle le restera. S'y ajoutent deux gardes de combat — le
rangement ne se fait pas en combat et est rattrapé à `PLAYER_REGEN_ENABLED`, et
le module est déclaré `secure = true` pour que son allumage comme son extinction
soient différés hors combat (règle 6).

**Pour identifier un blocage** — le client ne dit pas *quelle* action a été
refusée tant que le journal n'est pas armé :

    /console taintLog 1

puis `/reload`, on reproduit, et `_retail_/Logs/taint.log` nomme la fonction et
le fichier fautif. `/console taintLog 0` pour le couper — il grossit vite.

---

## L'identifiant d'un sort ne date pas son extension

**Symptôme** — les tiroirs de téléportation, triés sur le plus grand identifiant
de sort qu'ils contiennent, sortent dans un ordre qui n'est celui d'aucune
chronologie : Legion, Cataclysme, Battle for Azeroth, Dragonflight, Shadowlands,
Warlords of Draenor, Pandarie.

**Cause** — le raisonnement paraissait solide : les identifiants sont attribués
dans l'ordre où le jeu crée les sorts, donc le plus grand désigne le plus récent.
Il l'est, mais il ne mesure pas ce qu'on croyait. Un donjon **revient** en saison
des années après son extension, et il reçoit alors une téléportation neuve : le
Siège du Triumvirat est un donjon Legion qui porte un sort Midnight, Bastion
Cendregueule est un donjon Cataclysme qui porte un sort The War Within. Le plus
grand identifiant d'un tiroir date donc son dernier **retour**, pas son âge.

C'est un piège du genre le plus coûteux : la valeur est réellement croissante
dans le temps, elle passe donc toutes les vérifications de bon sens — et elle
répond à une autre question que celle qu'on pose.

**Ce qu'on fait** — on demande le rang au client, qui le publie : les extensions
sont énumérées **dans l'ordre** sous `EXPANSION_NAME0`, `EXPANSION_NAME1`… et
`GetNumExpansions()` en donne le nombre. Le tiroir portant le nom de son
extension, son rang se lit directement, et la prochaine extension prendra sa
place en tête sans qu'on touche à quoi que ce soit.

La comparaison se fait **dans les deux sens** : le tiroir de la saison porte le
nom de l'extension plus un suffixe (« Midnight – Saison 1 »), et une extension
peut être écrite sans son article (« Burning Crusade » pour « The Burning
Crusade »). À rang égal, le nom le plus long passe devant — c'est celui qui porte
le suffixe, donc la saison avant son extension.

---

## Le client ne dit pas quelle action il a bloquée

**Symptôme** — « BshamelUI a été bloqué à cause d'une action qui n'est utilisable
que par l'IU de Blizzard ». La fenêtre nomme l'addon et rien d'autre : ni la
fonction refusée, ni le cadre en cause. `Logs/taint.log` reste vide même après
`/console taintLog 1`, qui ne consigne pas ce cas.

**Cause** — le nom de la fonction n'est pas dans la fenêtre, il est dans un
**événement** : `ADDON_ACTION_BLOCKED` et `ADDON_ACTION_FORBIDDEN` sont émis avec
`(addon, fonction)`.

**Ce qu'on fait** — `/bui blocked` arme une veille qui écrit ces deux événements
dans le chat (`BUI:ToggleActionWatch`, dans `Core/Init.lua`). Éteinte par défaut,
et pour une raison de fond : la contamination est régulièrement imputée à l'addon
qui a **lu** une valeur salie, pas à celui qui l'a salie. Laissée allumée, elle
accuserait donc régulièrement le mauvais coupable devant un joueur qui n'a rien
demandé.

---

## La veille des actions bloquées est muette si les erreurs sont masquées

**Symptôme** — `/bui blocked` répond « veille activée », la fenêtre « action
réservée à l'IU de Blizzard » continue de s'afficher, et **rien** n'arrive dans
le chat. On en conclut que le blocage a disparu, ou que la veille ne marche pas.

**Cause** — le client n'émet `ADDON_ACTION_BLOCKED` et `ADDON_ACTION_FORBIDDEN`
que si l'affichage des erreurs de script est allumé (`scriptErrors`). La fenêtre,
elle, s'affiche dans tous les cas : les deux ne viennent pas du même mécanisme.

Le piège se referme d'autant mieux que **notre propre réglage** « masquer les
erreurs Lua » (Général) coupe cette CVar. Un joueur qui l'a coché a donc une
fenêtre sans le moindre moyen d'en connaître la cause.

**Ce qu'on fait** — armer la veille vérifie la CVar et le dit quand elle est à
zéro, avec les deux façons de la rallumer.

---

## Poser un menu d'addon sur une barre d'action

Un emplacement de barre d'action n'accepte que ce que le jeu y range : sort,
objet, macro, monture, tenue, tiroir de grimoire. **Jamais le cadre d'un addon**,
et le déploiement au survol est le mécanisme de flyout de Blizzard, réservé à ses
propres listes.

Le seul chemin est donc la **macro**, qui est un contenu accepté et qui peut
cliquer un bouton nommé (`/click <nom>`). D'où, dans `UI/Widgets/Base.lua`, un
bouton invisible portant un nom global — l'exception « noms de frames » de la
règle 3 — et, dans les options, un bouton qui **crée la macro** au lieu de
l'expliquer : le nom du bouton à cliquer est un détail d'implémentation, et le
premier joueur qui le recopie de travers croira que rien ne marche.

Deux points relevés à l'écriture :

- un nom de macro ne dépasse pas **seize caractères**, sinon la création échoue ;
- le menu s'ouvre contre le **cadre survolé** (`GetMouseFoci`, `GetMouseFocus`
  sur les clients plus anciens), donc contre l'emplacement cliqué. Ancré à la
  minicarte alors qu'on vient de cliquer en bas de l'écran, il paraîtrait ne pas
  s'être ouvert. L'écran et le monde sont écartés de ce test : s'y ancrer
  poserait le menu dans un coin.

---

## Un nom d'événement inconnu lève, et emporte la moitié d'un module

**Symptôme** — `Frame:RegisterEvent(): Attempt to register unknown event`, et le
module concerné ne fait qu'une partie de ce qu'il promet. Le symptôme observé
n'est pas l'erreur mais le manque : ce qui suit la ligne fautive dans `OnEnable`
n'a jamais été branché.

**Cause** — `RegisterEvent` **lève** sur un nom que le client ne connaît pas. Or
citer un événement absent est un cas courant et légitime : ils changent de nom
d'une extension à l'autre, et certains n'existent que sur certains clients.
`OnEnable` s'exécute sous `safecall`, donc l'erreur est bien remontée — mais le
reste de la fonction est perdu.

**Ce qu'on fait** — `BUI:RegisterEvent` tente l'inscription sous `pcall`,
signale le nom fautif, et rend la main. Le module continue de se brancher. C'est
la même logique que les tests de capacité de la règle 1 : ce que le client
n'expose pas ne doit pas emporter ce qu'il expose.

**Cas rencontré** — l'ouverture de la fontaine de puissance s'appelle
`CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN`. « Receptable » est une **coquille de
Blizzard**, présente dans son API depuis toujours ; le mot correct
(« receptacle ») ne désigne rien, et le nom au participe passé non plus.

---

## Une icône carrée dans un trou rond

**Symptôme** — le bouton de minicarte de l'addon remplit son anneau, celui du
menu de téléportation flotte au milieu, plus petit. Les deux utilisent pourtant
le même widget.

**Cause** — le logo porte son **disque dans sa texture** : posé à la taille du
trou, il le remplit. Une icône d'objet ou de sort est carrée, et rien ne
l'arrondit : à la taille du trou, ses quatre coins débordent sur l'anneau. On la
réduisait donc au carré inscrit dans le cercle (côté = diamètre / √2, soit un
tiers de surface en moins), d'où l'impression qu'elle flotte.

**Ce qu'on fait** — un **masque circulaire** (`CreateMaskTexture` +
`AddMaskTexture`) coupe les coins de l'icône, qui peut alors être posée à la
taille du trou comme le logo. Le masque est celui du portrait de personnage : un
disque plein, présent depuis toujours.

Test de capacité et non pari : un client sans masque retombe sur le carré
inscrit, plus petit mais jamais débordant. Et le masque ne s'applique qu'à une
texture **non répétée** — ce qui est le cas ici, contrairement aux bandeaux de la
navigation (voir « Un masque posé sur une texture répétée est ignoré en
silence »).

---

## Relever la strate d'un cadre emprunté cache son icône

**Symptôme** — les boutons rangés dans le tiroir n'affichent plus qu'un **disque
noir** : leur anneau se dessine, leur icône a disparu. Sur la minicarte, les
mêmes boutons sont normaux.

**Cause** — le tiroir se mettait à la strate `DIALOG` et **imposait la sienne**
aux boutons empruntés, pour qu'ils passent au-dessus de son fond. Mais un bouton
de minicarte porte souvent son icône sur un **sous-cadre** dont la strate est
fixée séparément : relever le bouton ne relève pas ses enfants, restés plus bas.
Le fond du tiroir passait donc entre les deux — au-dessus de l'icône, sous
l'anneau.

Le symptôme trompe : on soupçonne la couleur ou le chargement de la texture,
alors qu'il s'agit d'un ordre de dessin, et que le noir est notre propre fond.

**Ce qu'on fait** — l'inverse : **le tiroir s'aligne sur la strate des boutons**
(celle de la minicarte) et ne touche plus à la leur. Seul le niveau est imposé,
qui s'applique, lui, sans surprise. C'est aussi une mutation de moins à défaire
sur un cadre qui ne nous appartient pas.

Règle générale à retenir : sur un cadre emprunté, **on ne change que ce qu'on
sait rendre**, et une strate se propage moins bien qu'on ne le croit.

---

## Fermer une fenêtre au clic extérieur sans avaler le clic

Le procédé habituel est un cadre transparent posé sur tout l'écran, sous la
fenêtre, qui intercepte les clics. Il ferme bien, mais il **avale** le clic : il
faut cliquer deux fois pour agir ailleurs, une fois pour fermer et une fois pour
faire. Et il se règle mal — au-dessus de tout il masque la fenêtre elle-même,
en dessous il rate les clics posés sur une strate supérieure.

Le client annonce chaque appui de souris, où qu'il tombe : **`GLOBAL_MOUSE_DOWN`**.
Il suffit alors de demander à la fenêtre si le curseur était sur elle
(`IsMouseOver`). Le clic va où il allait, et la fenêtre se ferme en plus
(`W.CloseOnOutsideClick`, dans `UI/Widgets/Base.lua`).

Deux pièges tenus par le prédicat `isInside` :

- un **sous-menu** est un cadre à part, posé à côté du sien : il sort du
  rectangle de son parent, et `IsMouseOver` sur le parent seul le déclarerait
  « ailleurs » ;
- le **bouton qui a ouvert** la fenêtre n'est pas « ailleurs » non plus. L'appui
  y ferme la fenêtre, et le relâchement la rouvrirait aussitôt — le bouton
  paraîtrait ne plus répondre une fois sur deux.

La veille n'est armée que pendant que la fenêtre est ouverte, et l'inscription
passe par `pcall` : sur un client qui ne connaît pas l'événement, une fenêtre qui
ne se ferme pas au clic vaut mieux qu'une erreur.

---

## Il y a deux façons de brancher un clic, et `Click()` n'en déclenche qu'une

**Symptôme** — dans le tiroir, cliquer le **nom** d'un addon ouvre celui-ci pour
certains et ne fait rien pour d'autres. Cliquer son **icône** marche dans tous
les cas. Aucune erreur, aucun signe : le nom paraît mort.

**Cause** — un bouton de minicarte peut brancher son clic de deux façons :

- `OnClick`, la voie normale, celle des bibliothèques d'icônes ;
- `OnMouseUp` (parfois `OnMouseDown`), ce que font les boutons écrits à la main.
  Method Raid Tools est de cette famille, Mythic Dungeon Tools de la première.

`Button:Click()` ne déclenche que la première. Sur un bouton de la seconde
sorte, elle ne fait rien du tout — l'icône, elle, continue de répondre parce que
c'est le vrai clic de la souris qui l'atteint.

**Ce qu'on fait** — on regarde ce que le bouton **écoute** avant de le
solliciter : `OnClick` s'il existe, sinon l'appui puis le relâchement. Jamais les
deux : un bouton portant les deux scripts agirait deux fois.

---

## Le nom d'une téléportation n'est pas le nom du donjon

**Symptôme** — le menu de téléportation propose « Voie de Coursevent ». C'est le
nom du sort ; le donjon, lui, s'appelle autrement, et c'est sous ce nom-là qu'on
le cherche des yeux et qu'on en parle en groupe.

**Cause** — les sorts d'une famille de téléportations sont nommés par thème, pas
d'après leur destination. Découper le nom ne peut donc pas donner le donjon : il
n'y est pas.

**Ce qu'on fait** — on relie le sort au donjon par le client, jamais par une
liste écrite ici. Deux chemins, du plus sûr au plus large :

1. `C_ChallengeMode.GetMapUIInfo(mapID)` rend le nom du donjon et, sur les
   clients qui le publient, **son sort de téléportation en septième valeur**. Le
   lien est alors donné. Les numéros de carte se parcourent jusqu'à une borne
   (`MAX_CHALLENGE_MAP`) : ce n'est pas une liste de donjons, c'est une borne, et
   ce qui vivrait au-delà retombe simplement sur le nom du sort ;
2. sinon, `C_Spell.GetSpellDescription(spellID)` **nomme le donjon** dans sa
   phrase (« Vous téléporte à l'entrée de… »). On cherche donc lequel des donjons
   relevés à l'étape 1 y apparaît, du nom le plus long au plus court — sans quoi
   « Tazavesh » l'emporterait sur « Tazavesh : le Gambit de So'leah », que la
   même description contient. Aucune langue n'est écrite nulle part : c'est du
   texte du client comparé à du texte du client.

Une description **vide** n'est pas une réponse négative : le client charge celle
d'un sort à la demande. On la réclame (`C_Spell.RequestLoadSpellData`) et on rend
la main sans rien retenir, pour que la reconstruction suivante repose la
question. Les réponses, elles, sont retenues — le menu se refait à chaque objet
qui entre dans les sacs.

---

## Une épingle de carte est un bouton de minicarte pour qui la regarde

**Symptôme** — le tiroir de boutons d'addons se remplit de « GatherMatePin1 »,
« GatherMatePin2 »… jusqu'à ce qu'on n'y trouve plus les vrais boutons.

**Cause** — un addon de récolte affiche ses gisements sur la minicarte, et il les
pose exactement comme un bouton : `CreateFrame("Button", "GatherMatePin"..n,
Minimap)`, nommé, affiché, enfant de la carte. Aucune question posée au cadre ne
les sépare — même type, même parent, même état.

L'encombrement n'est pas le pire : une épingle rangée est une épingle **volée** à
l'addon qui la recycle à chaque pas du joueur. Elle ressort dans le tiroir sous
un autre gisement, et son propriétaire ne peut plus la replacer, puisque le
tiroir masque `SetPoint` pendant l'emprunt.

**Ce qu'on fait** — trois signes dans `UI/MinimapDock.lua`, et il en faut trois :

- un **pool** se reconnaît à ses numéros : plusieurs cadres qui partagent la même
  racine de nom une fois le numéro retiré. La famille entière est écartée, y
  compris son premier membre ;
- une **racine qui se termine par** `Pin`, `Node`, `Waypoint` ou `POI`. Ce
  second signe rattrape le cas où une seule épingle est visible à l'instant du
  parcours, où le premier ne voit qu'un cadre isolé ;
- la **taille** du cadre (`T.SIZE.MINIMAP_BUTTON_MIN` / `MAX`). Une épingle fait
  la moitié d'un bouton de minicarte — c'est ce qui la rend lisible au milieu de
  la carte — et un panneau en fait le double.

Les deux premiers signes lisent le nom, et un nom ne se lit que si l'on a deviné
le vocabulaire de celui qui l'a écrit : `GatherMateIcon12` ne contient aucun des
mots de la liste. Le troisième ne demande rien à personne, et c'est le seul qui
vaille pour un addon dont on n'a jamais vu les épingles.

Un nom dit ici ce que le cadre **est**, là où le nom d'un bouton d'addon dit à
qui il appartient — et un addon a un bouton, pas une collection numérotée. Seul
le préfixe d'une bibliothèque d'icônes (`LibDBIcon10_`) échappe aux trois : il
identifie un bouton d'addon à lui seul, et rien n'interdit d'en vouloir un petit.

---

## La vente d'un objet encore échangeable passe par une StaticPopup

**Symptôme** — vendre un butin encore échangeable ouvre une fenêtre de
confirmation. Aucun réglage du client ne la coupe, et aucune fonction ne vend
« sans demander ».

**Ce qu'on fait** — on ne vend pas à la place du joueur : on **clique le bouton
du client**. Les dialogues concernés sont
`CONFIRM_MERCHANT_TRADE_TIMER_REMOVAL` (l'échange) et
`CONFIRM_REFUND_TIMER_REMOVAL` (le remboursement) ; la table de noms vaut test de
capacité, un dialogue que le client ne connaît pas ne s'affiche jamais et n'est
donc jamais cliqué.

Le clic est **différé d'une image** (`C_Timer.After(0, …)`) : le hook s'exécute à
l'intérieur du `Show` de la fenêtre qu'il s'apprête à fermer. Il revérifie alors
que le réglage est toujours coché et que la fenêtre est toujours la bonne — une
image suffit pour qu'elle ait été fermée à la main.

---

## « Cinématique » recouvre trois choses, qui ne s'arrêtent pas pareil

**Symptôme** — le réglage « passer les cinématiques » ne fait rien. Les films
s'en vont, les scènes de quête — c'est-à-dire l'immense majorité de ce qu'on
croise — restent.

**Cause** — un seul appel traitait le cas le plus rare :

- le **film** (`PLAY_MOVIE`) : `GameMovieFinished()`, et `MovieFrame:Hide()` pour
  la fenêtre qui peut rester posée ;
- la **vraie cinématique** (`CinematicFrame.isRealCinematic`) : `StopCinematic()`
  passe depuis n'importe où, gestionnaire d'événement compris ;
- la **scène en jeu** : la caméra prend la main pendant que le monde tourne.
  Elle s'annule par `CancelScene()`, sous réserve de `CanCancelScene()` — et cet
  appel est **conditionné à un geste matériel**. Depuis `CINEMATIC_START`, il est
  refusé.

**Ce qu'on fait** — on n'appelle jamais `CancelScene` depuis l'événement : on
**arme** une annulation à `CINEMATIC_START`, et la première touche pressée sur
`CinematicFrame` la consomme, puisque le client accepte l'appel pendant qu'il
traite une touche. `CINEMATIC_STOP` désarme, pour qu'une scène passée ne laisse
pas de piège à la suivante.

Le hook des touches passe par `U.GuardedScript` (règle 6) : posé une fois, inerte
quand le module s'éteint. Il sert aussi à **cliquer la confirmation** que le
client ouvre sur Échap — sans quoi couper une séquence demande deux touches, et
le réglage a l'air de ne rien faire à la première.

Conséquence assumée : une scène en jeu demande une touche, là où un film part
tout seul. Aucune API ne permet mieux.

---

## Le temps de recharge d'un jouet se demande comme celui d'un objet

**Ce qu'on fait** — dans le menu de téléportation, chaque ligne affiche ce qui
lui reste :

- un sort : `C_Spell.GetSpellCooldown(spellID)`, qui rend une **table**
  (`startTime`, `duration`) sur les clients récents et deux valeurs sur les
  autres. On accepte les deux formes ;
- un objet **et un jouet** : `C_Item.GetItemCooldown(itemID)`, la globale
  `GetItemCooldown` en second recours. Un jouet est un objet, son identifiant
  suffit.

Deux règles d'affichage. Une durée inférieure ou égale à **1,5 s** est le temps
de recharge global : elle court sur presque tout ce que le personnage connaît, et
l'afficher ferait clignoter le menu entier à chaque sort lancé. Et une ligne
prête ne porte **rien** — c'est la présence du nombre qui renseigne, pas sa
valeur.

Le rafraîchissement est un `OnUpdate` bridé à `T.TIMING.MENU_COOLDOWN` (règle 7),
qui ne tourne que menu ouvert : un cadre caché n'en reçoit pas. `SetEntries` le
rappelle tout de suite, sans quoi une ligne recyclée garderait le temps de
recharge de ce qu'elle affichait avant.

**Et ces deux nombres peuvent être secrets.** Le menu se remplit au moment où le
module s'allume, donc depuis du code teinté, et le client rend alors une durée
protégée :

```
SecureMenu.lua:122: attempt to compare local 'duration'
(a secret number value, while execution tainted by 'BshamelUI')
  remainingCooldown <- refreshCooldowns <- SetEntries <- OnEnable
```

Le test de forme ne suffit pas : `type()` d'un nombre secret rend bien
`"number"`. C'est la **troisième** fois que la règle « le garde de secret se
place avant toute comparaison, jamais après » se paie — voir « Un booléen secret
ne se teste pas » et « Une valeur secrète interrompt tout un passage ». Ici elle
manquait tout entière, sur un fichier écrit avant elle.

Le garde rend `nil`, donc pas d'horloge sur la ligne — ce qui est déjà ce
qu'affiche une action prête. Il n'y a rien à conclure d'un secret, et une ligne
sans horloge reste cliquable : c'est le clic qui décide, pas nous.

---

## Deux listes de globals, et seule la CI voit qu'elles divergent

**Symptôme** — la pipeline du tag `v0.7.3` est rouge alors que les vérifications
locales étaient toutes vertes. Le job `lint` échoue, donc le job `release` ne
tourne jamais : rien n'est publié.

**Cause** — les globales du client sont déclarées **deux fois** :
`.luarc.json` pour `lua-language-server`, qui tourne en local, et `.luacheckrc`
pour `luacheck`, qui tourne en CI. Une globale nouvellement utilisée est ajoutée
au premier — sans quoi la passe locale échoue tout de suite — et oubliée au
second, où rien ne la réclame avant le prochain push. `luacheck` la signale alors
en W113, « accessing undefined variable », et un avertissement y est fatal.

C'est le pire endroit possible pour un défaut : il ne se manifeste qu'après le
tag, et un tag ne se rejoue pas (le motif `v*` est protégé, la suppression est
refusée). Il coûte donc un numéro de version à chaque fois.

**Ce qu'on fait** — `dev/scripts/lint-local.sh` compare les deux listes et
échoue sur la différence. Le sens du test compte : ce qui est déclaré dans
`.luarc.json` doit l'être dans `.luacheckrc`, l'inverse restant permis — la
seconde liste peut citer des noms que l'analyse locale connaît d'elle-même.

---

## L'interdiction de Furie sanguinaire n'a pas un débuff mais sept

**Symptôme** — un suivi qui ne cherche que « Rassasié » (57724) reste muet dès
qu'un mage, un évocateur ou un familier de chasseur a lancé la Furie. Le groupe
est pourtant bel et bien sous interdiction : personne ne peut en relancer une, et
rien ne l'affiche.

**Cause** — chaque source pose **son propre débuff**, avec son propre nom et son
propre identifiant. Ils se remplacent l'un l'autre et ont tous la même durée,
mais aucun n'est l'alias d'un autre : il n'existe pas d'identifiant « canonique »
de l'interdiction.

Ceux que l'on connaît, et que `Modules/RaidCooldowns.lua` reconnaît :

| ID | Débuff | Source |
|---|---|---|
| 57724 | Rassasié | Furie sanguinaire (chaman Horde) |
| 57723 | Épuisement | Héroïsme (chaman Alliance) |
| 80354 | Déplacement temporel | Distorsion temporelle (mage) |
| 264689 | Fatigué | Rage primitive (familier du chasseur) |
| 95809 | Démence | Hystérie ancestrale (familier du chasseur) |
| 160455 | Fatigué | Vents inférieurs (familier du chasseur) |
| 390435 | Épuisement | Furie des Aspects (évocateur) |

**Ce qu'on fait** — une table d'identifiants, traitée comme une **donnée** et non
comme du code : un identifiant inconnu ne se déclenche jamais, donc la liste est
sûre à étendre, et une extension qui ajoute une source se règle en ajoutant une
ligne. La lecture passe par `C_UnitAuras.GetPlayerAuraBySpellID`, qui répond
débuff par débuff, avec un repli sur `GetDebuffDataByIndex` pour un client qui ne
la publierait pas.

L'**icône**, elle, est celle du chaman (sort 2825) quelle que soit la source. Ce
que le suivi annonce est « une Furie est partie », pas « laquelle » : une icône
qui changerait de classe en classe demanderait de la relire à chaque fois pour
constater qu'elle dit toujours la même chose.

---

## Les sacs ne sont pas des fenêtres, mais une pile

**Symptôme** — ajouter `ContainerFrame1` à la liste des fenêtres déplaçables les
épingle **toutes au même endroit**, et le client les remet en place à la première
ouverture.

**Cause** — deux choses, et il faut les deux pour comprendre.

Le client dispose ses sacs en pile depuis le coin bas-droit de l'écran, chaque
cadre ancré à `UIParent` avec un décalage qu'il **recalcule en entier** à chaque
ouverture, fermeture ou changement de réglage de sacs. Épingler chaque cadre à sa
propre position détruit donc la pile.

Et le hook sur `SetPoint` qui sert à réimposer la position des autres fenêtres se
déclenche **cadre par cadre**, donc au milieu de la passe de disposition, quand
la moitié de la pile est encore à son ancienne place. Tout décalage mesuré à ce
moment-là l'est sur un état incohérent.

**Ce qu'on fait** — on ne refait pas la disposition, on la **translate**, et on
se branche sur la passe et non sur les cadres : `UpdateContainerFrameAnchors` est
post-hookée, et à la fin de chaque passe tous les cadres portent une disposition
cohérente. Il suffit alors de mesurer l'écart entre le coin bas-droit que le
client a choisi et celui que le joueur veut, et de décaler tout le monde
d'autant. Le nombre de colonnes, le sens de remplissage, le mode « sacs
combinés » : tout continue de venir du client.

Le **coin** et non le centre : une pile change de taille dès qu'on ouvre un sac de
plus, et son centre bouge alors que son coin bas-droit non.

La molette n'est pas branchée dessus, et c'est délibéré : les écarts entre sacs
sont calculés par le client pour leur taille d'origine, agrandir les cadres sans
agrandir les écarts les ferait se chevaucher, et recalculer les écarts serait
refaire sa disposition.

---

## `DebuffFrame.auraFrames` n'est pas une liste

**Symptôme** — le masquage d'un débuff du joueur ne fait rien, sans erreur. La
table existe pourtant : `DebuffFrame.auraFrames ~= nil` répond `true`.

**Cause** — deux pièges qui se cumulent, et le premier cache le second.

`auraFrames` est **indexée par identifiant d'instance d'aura**, pas par un entier
consécutif. `#auraFrames` vaut donc zéro, et un parcours de `1` à `#auraFrames`
ne visite aucun cadre. Le test « la table existe » est vrai, la boucle tourne à
vide, et rien ne le signale.

Et `UNIT_AURA` arrive **avant** que le client n'ait rebâti sa rangée : ce qu'on
masque à ce moment-là est réaffiché juste après. C'est le même piège que les
auras de la cible (voir la note sur `UpdateAuras`), et il se traite de la même
façon — on s'accroche à la reconstruction plutôt que de parier sur l'événement.

Relevé sur un client 12.0 : `auraPool` est `nil`, `auraFrames` et `AuraContainer`
existent.

**Ce qu'on fait** — `pairs` et non une boucle numérique, et on essaie **tous** les
chemins connus au lieu de s'arrêter au premier qui répond : `auraFrames`, un
`auraPool`/`auraPools` s'il y en a un, les enfants d'`AuraContainer`, ceux du
cadre lui-même. Masquer deux fois le même cadre ne coûte rien ; en manquer un
coûte la fonctionnalité entière.

L'identifiant du sort se lit d'abord par `auraInstanceID` et
`C_UnitAuras.GetAuraDataByAuraInstanceID` : sur un client récent, le bouton ne
retient que l'identifiant d'instance et c'est au client qu'il faut redemander de
quel sort il s'agit.

---

## Le client n'a pas d'opacité de cible pour les barres de nom

**Symptôme** — on cherche les CVars `nameplateSelectedAlpha` et
`nameplateNotSelectedAlpha`, qui sont partout dans la documentation et dans les
addons. Écrits sur un client retail, ils ne font rien.

**Cause** — ils n'existent plus que sur les clients classic. Le client actuel ne
publie, pour l'opacité des barres de nom, que le fondu par la distance
(`nameplateMinAlpha`, `nameplateMaxAlpha`, et leurs deux distances) et le
multiplicateur d'occultation `nameplateOccludedAlphaMult`. La distinction
cible / non-cible n'est pas un réglage : c'est du code.

**Ce qu'on fait** — l'opacité de la cible et celle des autres sont posées à la
main, par `SetAlpha` sur le **cadre d'unité** de chaque plaque, au moment où le
client repeint (voir `Modules/Nameplates.lua`). L'occultation reste au client :
elle se pose sur la **plaque**, un cran au-dessus, et les deux opacités se
multiplient donc naturellement. Le CVar d'occultation est calculé comme un
rapport entre les deux curseurs, pour que le joueur règle trois opacités et non
deux opacités et un rapport.

---

## Rien ne dit qu'une barre de nom est passée derrière un mur

**Symptôme** — on veut assombrir la plaque d'un adversaire hors du champ de
vision. Aucun événement ne l'annonce, aucune fonction ne répond, et
`UnitIsVisible` parle d'autre chose (la portée du client, pas la ligne de vue).

**Cause** — l'occultation est calculée par le moteur, qui se contente d'en
appliquer le résultat : il multiplie l'opacité de la plaque par
`nameplateOccludedAlphaMult`. L'information existe donc, mais seulement sous la
forme d'un nombre déjà appliqué.

**Ce qu'on fait** — on la **déduit de l'opacité posée**, et la déduction est
sûre dans un sens. L'opacité que le moteur pose sur la plaque vaut le seul fondu
par la distance, lequel ne descend jamais sous `nameplateMinAlpha`. Tout ce qui
passe sous ce plancher est donc occulté — aucun faux positif possible. La
réciproque tient tant que le multiplicateur d'occultation est plus bas que ce
plancher, c'est-à-dire dès que le réglage veut dire quelque chose ; réglé
au-dessus, l'assombrissement ne se déclenche pas plutôt que de se tromper.

La lecture demande un passage périodique — le seul de l'addon qui sonde au lieu
d'écouter, et il ne repeint que les plaques dont l'état a changé.

---

## La classe d'une créature n'est fiable que sur une élite

**Symptôme** — un lynx d'extérieur s'affiche avec la couleur des casters. Il n'y
a pourtant aucune erreur : le classement fonctionne comme il est écrit.

**Ce qu'on avait cru** — une entrée précédente de ce fichier concluait que « le
jeu ne sait pas qu'un PNJ est un caster », et l'addon fabriquait sa propre base
en retenant les PNJ vus en train d'incanter. `UnitClassBase` a rendu ce mécanisme
inutile : une créature a bien une classe, comme un joueur, et la fonction la rend
dès la première plaque.

**La conclusion était juste, la correction est allée trop loin.** `UnitClassBase`
lit un champ du modèle de créature. Ce champ est renseigné avec soin là où
quelqu'un avait une raison de le faire — le trash de donjon et de raid, dont la
classe décide des sorts — et rempli au petit bonheur partout ailleurs. La faune
en hérite d'une, et la donnée est alors une valeur qui existe sans rien dire.

Le symptôme est trompeur pour cette raison : il ne ressemble pas à une donnée
absente (`nil`, un repli, un cas non traité) mais à une donnée fausse, ce qui
oriente vers la table `CASTER_CLASSES` au lieu de la question posée.

**Ce qu'on fait** — la classe n'est interrogée que sur `UnitClassification(unit)
== "elite"`. Un PNJ ordinaire n'est pas classé du tout, et garde la couleur du
client. Le rang d'une élite se lit à son niveau **effectif** relatif au joueur :
égal, c'est du trash qu'on classe par sa classe ; +1, un miniboss ; +2 ou hors
échelle (`-1`), un boss.

Corollaire général, et il vaut au-delà d'ici : **une API qui répond n'est pas une
API qui sait.** Avant de se fier à un champ rendu pour toutes les unités, se
demander qui l'a rempli et pourquoi. Là où personne n'avait de raison de le
renseigner, il vaut mieux ne rien afficher que d'afficher ce qu'il contient.

**Vérifié en lisant** BetterBlizzPlates, qui applique exactement cette borne
(`UnitClassBase` sur les seules élites, et sur les joueurs). Aucun code repris
(règle 8) : ce qu'on y a lu est la borne elle-même.

---

## L'ancrage d'une barre d'infos ne se lit pas

**Symptôme** — quatre-vingts erreurs d'affilée en cochant un réglage de barres
d'infos :

```
Frame:GetPoint(): Action[FrameMeasurement] failed
because[Can't measure restricted regions]
Lua Taint: BshamelUI
```

**Cause** — les régions d'une barre d'infos sont **restreintes** : le client
refuse d'en laisser mesurer l'ancrage à du code d'addon, une position relative
renseignant sur ce qu'il protège. La restriction est fine — `GetWidth` et
`GetHeight` passent encore, `GetPoint` et `GetNumPoints` non. Et sans les points,
il n'y a rien à reposer : le motif habituel « je relève avant de bouger, je
repose ensuite » est impossible sur ces cadres-là.

**Ce qu'on fait** — on ne relève rien, et on rend l'ancrage en **demandant au
client de refaire sa mise en page** : `NamePlateDriverFrame:UpdateNamePlateOptions()`
repasse sur chaque plaque visible et y réapplique ses propres options. C'est le
même principe que pour les couleurs, où l'on rappelle `CompactUnitFrame_UpdateHealthColor`
au lieu de reposer une teinte — lui seul sait ce qu'il aurait dessiné.

Deux conséquences sur la structure du code :

- **la restitution ne peut pas venir du passage de peinture.** La mise en page du
  client rappelle les fonctions que nos hooks coiffent, qui rappellent la
  peinture : l'appeler de là boucle. Elle se fait au changement de réglage et à
  l'extinction, une fois ;
- **il n'y a rien à défaire quand une plaque part au recyclage.** Le pilote
  appelle `ApplyFrameOptions` à chaque unité ajoutée, donc il réancre lui-même.
  Ne restent à notre charge que les deux choses qui ne sont pas de la mise en
  page : une barre qu'on a masquée et une opacité qu'on a baissée.

Corollaire général : **toute lecture faite sur une plaque passe par `pcall`**, et
un refus se lit « on ne sait pas » plutôt que « erreur ». Les cadres que le
client déclare `IsForbidden()` — les plaques d'arène, dont il protège l'identité
— sont écartés à l'entrée.

---

## Appeler le pilote de barres d'infos teinte tout ce qu'il touche

**Symptôme** — deux mille six cents erreurs pour un seul clic sur une case à
cocher, et plus une barre d'infos à l'écran :

```
CompactUnitFrame.lua:1199: attempt to compare local 'maxHealth'
(a secret number value, while execution tainted by 'BshamelUI')
  CompactUnitFrame_UpdateHealPrediction
  CompactUnitFrame_UpdateAll
  CompactUnitFrame_SetUpFrame
  ApplyFrameOptions
  NamePlateDriverFrame:UpdateNamePlateOptions()   <- appelé par l'addon
```

**Cause** — `UpdateNamePlateOptions` repasse sur chaque plaque et la remonte
entièrement. Appelé depuis du code d'addon, **tout ce chemin s'exécute teinté**,
et il manipule des valeurs *secrètes* — les points de vie d'une unité en sont
une. Une valeur secrète ne se compare pas depuis du code teinté : c'est le code
de Blizzard qui lève, une fois par plaque, à chaque passage. La mise en page
s'interrompt au milieu, et les plaques ne s'affichent plus.

Ce n'est pas propre aux barres d'infos : c'est la règle générale du modèle des
valeurs secrètes. **On n'entre pas dans le code de mise en page du client.** Il
n'existe pas de version prudente de cet appel — ni `pcall`, ni garde, ni moment
opportun.

**Ce qu'on fait** — rien. Écrire le CVar suffit : le pilote écoute `CVAR_UPDATE`
lui-même et repasse depuis *son* gestionnaire d'événement, donc sans teinture. On
pose la valeur et on le laisse remarquer.

Corollaire, et il coûte deux fonctionnalités : **il n'existe aujourd'hui aucune
façon réversible de déplacer une région d'une barre d'infos.** On ne peut pas
relever son ancrage (voir l'entrée précédente) et on ne peut pas faire reposer le
sien au client. Déplacer ce qu'on ne saura pas rendre est interdit par la
règle 6 : le marqueur de ciblage et le recentrage du nom des alliés restent donc
éteints tant qu'une troisième voie n'est pas trouvée.

---

## Appeler `RefreshLayout` d'une visionneuse de recharges empoisonne ses événements

**Symptôme** — des erreurs détachées de tout, sans pile lisible, longtemps après
le geste qui les a semées :

```
Blizzard_SharedXMLBase/TableUtil.lua:82: attempt to compare local 'item'
(a secret number value, while execution tainted by 'BshamelUI')
debugstack() returned secrets.
```

La ligne 82 est le `item == v` de `tContains`. L'appelant qui lui passe un
secret est `CooldownViewerItemData.lua`, `UpdateLinkedSpell` :
`tContains(cooldownInfo.linkedSpellIDs, spellID)`, où `spellID` sort d'une aura
(`auraInfo.spellId`, secret) ou d'un événement de recharge.

**Cause** — le tassement du suivi des améliorations rendait la grille en
demandant `viewer:RefreshLayout()` quand il ne savait pas la relever. Même
maladie que le pilote des barres d'infos (voir plus haut), mais la facture
arrive **plus tard** : `RefreshLayout` réécrit tout l'état Lua de la visionneuse
— le pool d'emplacements (`ReleaseAll`/`Acquire`), les `layoutIndex`, les
champs du conteneur, les fiches `cooldownID`/`cooldownInfo` — et tout cela
devient teinté. L'appel lui-même **réussit**. C'est chaque événement que le
client traite ensuite *de son côté* qui, en relisant cet état, s'exécute teinté
et meurt sur la première comparaison d'un sort secret. Une erreur par
amélioration qui bouge, jusqu'au `/reload` — rien d'autre ne détache la
teinture d'un état déjà écrit.

Le déclencheur réel n'était même pas l'option : `restore()` tourne à
l'extinction du module et sur `OnSettingChanged(nil)` — donc à chaque bascule
de profil — et son repli partait dès que la grille était illisible, ce qui est
le cas ordinaire (moins de deux places visibles).

**Ce qu'on fait** — rien, encore une fois. Une grille qu'on ne sait pas relever
ne se rend pas : le client refait sa mise en page au prochain changement
d'amélioration — et sur cette visionneuse-là, ça ne tarde jamais. La règle
reste entière : **on n'entre pas dans le code de mise en page du client**, et
« il réussit sur le coup » n'est pas une exception — c'est la forme la plus
chère de l'échec, celle qui signe nos erreurs longtemps après.

---

## Taille d'une barre d'infos : ni CVar, ni fonction par faction

**Symptôme** — trois tentatives, trois échecs silencieux : `NamePlateVerticalScale`
et `NamePlateHorizontalScale` s'écrivent sans rien changer, puis
`C_NamePlate.SetNamePlateEnemySize` ne fait rien non plus. Aucune erreur nulle
part — sous `pcall`, un appel à une fonction absente est indiscernable d'un appel
qui a réussi.

**Cause** — trois choses ont changé sur ce client, et il faut les trois :

- les deux CVars d'échelle sont **acceptés mais inertes**. Ils ne façonnent plus
  rien ;
- la taille de boîte se pose par **`C_NamePlate.SetNamePlateSize(largeur, hauteur)`**
  et se relit par `C_NamePlate.GetNamePlateSize()`. Les variantes par faction
  (`SetNamePlateEnemySize`, `SetNamePlateFriendlySize`) ont disparu côté écriture ;
- la hauteur de la **barre de vie** n'est pas la hauteur de la boîte : elle se
  pose sur `unitFrame.HealthBarsContainer:SetHeight(pixels)`, plaque par plaque.

**Ce qu'on fait** — deux chemins séparés. La largeur par `SetNamePlateSize`, la
hauteur de barre sur le conteneur de chaque plaque. Trois pièges à retenir :

- `SetNamePlateSize` est **refusée en combat**, silencieusement. On la garde
  derrière `InCombatLockdown` et on rattrape sur `PLAYER_REGEN_ENABLED` ;
- la taille de boîte se **relève** avant d'écrire (`GetNamePlateSize`), ce qui est
  la seule mesure de barre d'infos qu'on ait le droit de lire — les ancrages ne le
  sont pas ;
- la hauteur de barre doit être reposée **sur l'écriture elle-même**. Le client la
  repose en montant une plaque, sur changement de CVar et sur changement d'échelle
  d'interface : se contenter des hooks de peinture fait battre la barre entre les
  deux valeurs, une fois sur deux. Un `hooksecurefunc` sur le `SetHeight` du
  conteneur, avec un drapeau de non-récursion, supprime la course — il n'y a plus
  de moment à deviner.

---

## L'aperçu de barre d'infos du client ne se réutilise pas

**Symptôme** — le panneau d'options du jeu montre une barre d'infos d'exemple,
auras et incantation comprises. On voudrait la même chose dans notre page plutôt
que de dessiner une imitation.

**Ce qu'on trouve** — `NamePlatePreviewMixin` existe, avec `GetPreview`,
`ShowPreviewNamePlateCastBar`, `ToggleEnemyNpcAuraDisplay` et le reste.
`NamePlateConstants.PREVIEW_UNIT_TOKEN` vaut `"preview"`, ce qui laisse espérer
une plaque pilotée par une unité fictive.

**Ce qu'on vérifie** — panneau du jeu ouvert, aperçu affiché :

```
/run print(C_NamePlate.GetNamePlateForUnit("preview"))
```

ne rend rien. L'aperçu **n'est pas** une plaque du moteur : c'est une pièce
interne du panneau, montée par le Lua de mise en page de Blizzard. Or ce Lua ne
s'appelle pas depuis un addon (voir « Appeler le pilote de barres d'infos teinte
tout ce qu'il touche ») : appeler les méthodes du mixin le ferait tourner teinté,
sur des valeurs secrètes.

**Ce qu'on fait** — on renonce à l'aperçu et on garde nos propres cadres, mais
dimensionnés sur `NamePlateConstants`, la table où le client publie ses mesures :
`AURA_ITEM_HEIGHT`, `CAST_BAR_ICON_HEIGHT`, `LARGE_CAST_BAR_HEIGHT`,
`CAST_BAR_FONT_HEIGHT`, `DEBUFF_PADDING`. On lit ses nombres au lieu de les
recopier — l'exemple reste alors juste après un patch. La **position**, elle,
demeure une convention à nous : elle ne se lit pas (voir « L'ancrage d'une barre
d'infos ne se lit pas »).

Relevé au passage, pour plus tard : `C_NamePlateManager` publie
`SetNamePlateSimplified`, `Get`/`SetNamePlateHitTestInsets` et
`IsNamePlateUnitBehindCamera` — de quoi rendre une plaque cliquable-au-travers ou
la réduire à son nom, plaque par plaque, sans passer par un CVar global.

---

## L'aperçu du client s'affiche, mais ne se configure pas

**Suite de l'entrée précédente.** L'aperçu n'était pas hors de portée : le
template existe et s'instancie.

```lua
CreateFrame("Frame", nil, parent, "NamePlatePreviewTemplate")
```

rend une maquette qui s'affiche correctement — style, taille, informations de
barre, auras, barre de sorts — et qui suit les CVars sans qu'on lui demande rien.
C'est ce que la page d'options affiche aujourd'hui.

**Ce qu'elle ne fait pas** — changer de type d'unité. `Enum.NamePlateType` n'a
que deux membres (`Friendly = 0`, `Enemy = 1`), mais rien sur le cadre ne permet
de choisir : `SetExplicitValues` y est `nil`, et les seuls champs sont
`NamePlate`, `Border` et `Preview`, aucun ne portant de méthode.

`NamePlatePreviewMixin` est donc appliqué à un **autre** template, celui que le
panneau de réglages monte lui-même. On ne l'obtient pas sans lui.

Il n'y a pas non plus de template frère par type : ni `NamePlatePreviewEnemyTemplate`,
ni `NamePlateEnemyPreviewTemplate`, ni `NamePlatePreviewFriendlyTemplate`. La
maquette est unique et son type est décidé par celui qui la monte.

Piège à éviter au passage : `frame[0]` est `userdata` sur **toute** frame — c'est
son pointeur interne, pas une donnée du template. Le voir apparaître dans un
`pairs()` ne veut rien dire.

**Ce qu'on fait** — on affiche la maquette telle qu'elle vient, sur son type par
défaut. Ce qui distingue un allié d'un adverse est la couleur de la barre et le
nom, soit à peu près la seule chose que la page ne règle pas ; tout le reste — ce
que l'aperçu sert à juger — est montré fidèlement.

---

## Un aperçu d'auras ne se pose pas dans le conteneur du client

**Symptôme** — on veut montrer une rangée d'auras d'exemple là où les vraies
apparaîtront. `unitFrame.AurasFrame` existe (250 × 100, mesuré en jeu), on y
accroche la rangée : elle flotte au mauvais endroit, au centre comme au bas.

**Cause** — le conteneur est une *zone*, pas une rangée, et la position des
rangées à l'intérieur ne se lit pas : `GetBottom`/`GetLeft` de ses enfants
rendent des valeurs secrètes, comme les ancrages. On ne saura jamais où le
client pose ses auras *dans* ce cadre.

**Ce qu'on fait** — la technique de MiniCC (lue pour la méthode, règle 8) : ne
rien poser *dans* ce qu'on ne peut pas lire, s'ancrer *sur* un repère qu'on
connaît. Le client empile ses auras au-dessus du **nom** de la plaque, et
`unitFrame.name` est un champ publié. Un seul point d'ancrage suffit — le nom
est centré sur la plaque, donc bas-milieu de la rangée sur haut-milieu du nom
centre les deux axes d'un geste.

Deux autres choses relevées chez MiniCC en passant :

- son mode test rend de fausses icônes **par le même chemin que les vraies**
  (mêmes conteneurs, faux identifiants de sort, fausses durées). C'est ce qui le
  rend fidèle — possible seulement quand on possède l'affichage qu'on prévisualise ;
- `AurasFrame.RefreshAuras` existe et se laisse coiffer par `hooksecurefunc` :
  c'est l'annonce « le client vient de reposer ses auras », si un jour on en a
  besoin.

**Suite, et correction : le nom de la plaque n'était pas le bon repère non
plus.** La conclusion ci-dessus — s'ancrer sur `unitFrame.name` — reste dans la
bonne famille d'idées mais désigne encore une région du cadre d'unité. Voir
l'entrée suivante.

---

## Une rangée posée sur une barre d'infos tient une demi-seconde

**Symptôme** — les rangées d'auras de l'addon s'affichent au bon endroit sur un
pull, puis le jeu « reprend la main » : elles sautent, ou disparaissent, sans
erreur ni message. Les curseurs de taille et de décalage, eux, donnent des
résultats qui varient selon la plaque et selon la cible.

**Trois causes, et elles produisent le même symptôme** — ce qui explique qu'aucun
correctif isolé n'ait tenu :

1. **le porteur et l'ancrage.** Les rangées étaient créées sur le cadre d'unité
   et ancrées sur sa barre de vie. Ce sont des régions restreintes, que le client
   repose à chacun de ses passages de mise en page : ce qu'on y accroche est
   défait sans que rien ne le dise, et l'ancrage ne se relit pas pour vérifier
   (voir « L'ancrage d'une barre d'infos ne se lit pas ») ;
2. **l'échelle.** Une rangée portée par la plaque hérite de son échelle. Celle de
   la cible n'est pas celle des autres, et elle change au clic : un curseur posé
   à trente donne trente fois autre chose selon la plaque, et la rangée respire à
   chaque changement de cible ;
3. **le bras de fer.** On effaçait le conteneur du client (`SetAlpha(0)`, tenu
   par un hook) pour mettre les nôtres à sa place. Le client le remet à chaque
   `RefreshAuras`, c'est-à-dire à chaque aura qui bouge.

**Ce qu'on fait** — trois lignes, une par cause :

- la rangée est portée **par la plaque** — le cadre que `C_NamePlate.GetNamePlateForUnit`
  rend — et ancrée dessus. C'est le seul repère de cette famille qui soit à nous
  d'accès : son niveau se lit, le client n'en refait pas la mise en page ;
- `row:SetIgnoreParentScale(true)`. Le nombre du curseur redevient un nombre de
  pixels d'écran, et il le reste quand la plaque de la cible grossit ;
- on n'efface plus rien. Les rangées **s'ajoutent** à celle du client, qui se
  règle dans sa moitié de la page. C'est la règle du dépôt appliquée là où elle
  ne l'était pas : on emprunte avant de créer, on ne masque jamais pour ajouter.

Le repli d'honnêteté qu'exigeait l'effacement — « si le client refuse de nous
laisser lire ses auras, lui rendre sa rangée » — disparaît avec lui : sa rangée
n'a pas été touchée, il n'y a rien à rendre.

**Trouvé en lisant** MiniCC (`Modules/NameplatesModule.lua`), qui fait
exactement cela : conteneur créé sur la plaque, `SetPoint` sur la plaque,
`SetIgnoreParentScale`, `EnableMouse(false)`, niveau du parent + 10, et aucune
touche à l'affichage du client. Aucun code repris (règle 8).

**L'autre voie existe, et elle est celle de BetterBlizzPlates** : ne rien créer
du tout et **reposer les vignettes du client**. Sur ce client, `NamePlateAurasMixin`
publie `RefreshList(listFrame, auraList)` et `RefreshLossOfControl`, et chaque
`unitFrame.AurasFrame` porte `BuffListFrame`, `CrowdControlListFrame`,
`DebuffListFrame`, `LossOfControlFrame` et un `auraItemFramePool`. Un
`hooksecurefunc` sur `RefreshList` permet de parcourir le pool et de réancrer les
vignettes sur `HealthBarsContainer`. À noter pour plus tard : c'est la seule
chose que BBP fait encore sur ce client — son module d'auras complet
(`RunAuraModule`) commence par `if BBP.isMidnight then return end`. Réimplémenter
la lecture des auras d'une barre d'infos est une voie que ceux qui l'avaient
faite ont abandonnée.

Les deux approches sont valides et ne se mélangent pas : l'une **ajoute** ce
qu'on lit soi-même, l'autre **déplace** ce que le client a déjà trié. On tient la
première, qui n'a rien à rendre à l'extinction.

---

## L'icône d'une aura est secrète, et c'est sans importance

**Symptôme** — les rangées d'auras restent vides sur une vraie plaque alors que
les mêmes rangées, nourries d'auras d'exemple, s'affichent parfaitement. Aucune
erreur. Le mode aperçu et le mode réel ne diffèrent que par la source des
données, ce qui désigne la lecture — mais `C_UnitAuras.GetUnitAuras` répond, et
elle rend bien l'aura attendue.

**Relevé en jeu** (`/bui auras`, un affaiblissement du joueur sur la cible) :

```
player HELPFUL: 6 (témoin)
jetons: target | nameplate2
HARMFUL|PLAYER: 1 | 1
aura.icon: secret | .auraInstanceID: activée
.applications: secret | .spellId: secret
collect imp: 0 | dot: 0 | cc: 0 | refusé: 1
```

Tout y est : l'API répond, les deux jetons s'accordent, l'aura est là — et le
tri la jette.

**Cause** — sur une unité adverse, le client rend l'icône, les cumuls et
l'identifiant de sort **secrets**. Notre tri les refusait sur ce constat, par une
garde `issecretvalue` posée avant d'essayer.

**Une valeur secrète se transmet, elle ne s'inspecte pas.** Passée telle quelle à
`texture:SetTexture(...)`, l'icône secrète peint l'image exacte. C'est ce que
fait le client, et c'est ce que font les addons qui affichent ces auras : ils ne
gardent rien, ils passent la valeur au setter. Il en existe même des setters
dédiés pour les cas où le type interdit tout le reste — `SetAlphaFromBoolean`
consomme un booléen secret (`C_Spell.IsSpellImportant`), `GetAuraDispelTypeColor`
rend une couleur depuis un identifiant sans exposer le type de dissipation.

**Ce qu'on fait** — la garde ne porte plus que sur l'absence : `icon == nil` est
un refus, `issecretvalue(icon)` n'en est pas un. Ce qu'on perd se perd alors
précisément, et le reste marche :

- les **cumuls** ne s'affichent pas — les écrire demande de comparer le nombre à
  un, ce qui lève sur un secret ;
- le **repli par identifiant de sort** (notre liste d'entraves) est mort : il
  lisait `spellId`. Le filtre classé du client, lui, n'a jamais eu besoin qu'on
  lise quoi que ce soit, et c'est le chemin qui reste ;
- l'`auraInstanceID` **n'est pas secret**, et c'est lui qui fait tenir le reste :
  dédoublonnage entre deux filtres, et horloge par `GetAuraDuration`.

**C'est la deuxième fois que cette garde coûte un aller-retour** — voir « Une
valeur secrète interrompt tout un passage », où elle avait fait disparaître les
cadres d'unités du mode sombre. La règle y était déjà écrite et n'avait pas été
appliquée ici : **une garde décide qu'une chose est intouchable sans avoir
essayé.** `issecretvalue` ne sert que sur une valeur dont on s'apprête à faire un
**calcul** — une comparaison, une concaténation, une indexation. Jamais sur une
valeur qu'on se contente de faire suivre.

Le symptôme est trompeur parce qu'il ressemble à une donnée absente. Ce qui
tranche en une commande : demander à la donnée si elle est *là* avant de demander
si elle est *lisible*. Les deux questions n'ont pas la même réponse, et seule la
seconde était posée.

**Le secret est par unité, pas par champ.** Relevé décisif, deux cibles à
quelques minutes d'écart, même version du code :

```
cible A   aura.icon: secret  .applications: secret  .spellId: secret
          .nameplateShowPersonal: secret
cible B   aura.icon: activée .applications: activée .spellId: activée
          .nameplateShowPersonal: activée
```

Le même champ, de la même fonction, sur le même client. Ce n'est donc pas
« `icon` est un champ protégé » mais « cette unité-ci est protégée ». La
conséquence pratique est qu'**on ne peut pas décider à l'écriture du code ce qui
sera lisible** : toute logique qui dépend d'un champ doit marcher dans les deux
cas, et se dégrader du côté secret plutôt que de disparaître.

**Noté au passage, pour un choix qui pourrait être révisé** : la liste curée
`AurasFrame.buffList` n'est triée à l'important que sur les unités **adverses**.
Sur un allié elle est brute, et il faut la resserrer soi-même — le filtre employé
ailleurs pour cela est `HELPFUL|INCLUDE_NAME_PLATE_ONLY|RAID_IN_COMBAT|PLAYER`.
L'addon n'en a plus besoin : il n'affiche aucune aura sur une plaque alliée.

Le motif qui en découle, et qui est celui à reproduire :

```lua
local flag = aura.nameplateShowPersonal
local drop = not U.IsSecret(flag) and flag == false
```

**Cette note prescrivait d'abord un test de plus, en tête** — `flag ~= nil and
not U.IsSecret(flag) and flag == false` — au motif qu'un champ absent ne dit
rien. Elle a coûté six cent cinquante-deux erreurs :

    Nameplates.lua: attempt to compare a secret boolean value
    (execution tainted by 'BshamelUI')

**`~= nil` est une comparaison comme une autre.** Comparer un secret à `nil` lève
exactement comme le comparer à `false` ; que les deux types diffèrent ne dispense
de rien, la valeur secrète est refusée avant qu'on en arrive là. Et le test ne
servait à rien : `nil == false` répond déjà « non ».

L'ordre n'est donc pas « la garde avant la comparaison qui compte », c'est **la
garde en premier, avant le premier maillon qui touche la valeur** — y compris un
`~= nil`, y compris un `if valeur and …`. Tout ce qui précède la garde dans une
conjonction est du code qui lève.

Le raffinement s'applique là où la donnée se lit, et s'efface ailleurs — ce qui
donne un affichage un peu moins fin sur les unités protégées, et jamais un
affichage vide.

---

## Le lint local ne lance pas luacheck

**Symptôme** — `dev/scripts/lint-local.sh` intégralement vert, tag poussé, et la
CI rouge sur cinq `W122` que rien n'avait annoncés. Le job `release` est sauté,
la version `v0.7.8` est morte — un tag protégé ne se supprime pas, on publie le
numéro suivant.

**Cause** — le script local passe la syntaxe, `lua-language-server`, la longueur
des lignes, l'accord des listes de globals et les garde-fous de design. **Pas
`luacheck`**, qui n'est pas installé sur la machine de dev. Or la CI le lance,
et un avertissement y vaut échec. Les deux outils ne recouvrent pas les mêmes
diagnostics : `W122` (écriture d'un champ d'une globale en lecture seule) n'a
pas d'équivalent chez `lua-language-server`.

**Ce qu'on fait** — avant tout tag : ou bien installer `luacheck` localement
(`luarocks install luacheck`) et l'ajouter à `lint-local.sh`, ou bien pousser
sur `main` d'abord et attendre la pipeline verte avant de taguer. La deuxième
est celle qui ne dépend pas du poste.

Le `W122` lui-même : écrire les champs du protocole d'une frame du client
(`ColorPickerFrame.func`…) est légitime — c'est son API ancienne — et se
déclare au plus près par `-- luacheck: push ignore 122` / `pop`, jamais en
rendant la frame inscriptible pour tout le dépôt.

---

## La boîte des plaques se fait réécrire sans événement

**Symptôme** — la largeur posée par `C_NamePlate.SetNamePlateSize` revient à la
valeur Blizzard en ouvrant une page qui montre la maquette
(`NamePlatePreviewTemplate`), et parfois sans qu'on sache dire quel geste l'a
provoqué. Aucun `CVAR_UPDATE` : ce n'est pas un CVar, c'est une fonction, et le
pilote du client la rappelle quand il rejoue son calibre (`nameplateSize`).

**Ce qu'on fait** — la leçon de la hauteur de barre, appliquée à la largeur :
se brancher sur l'écriture elle-même. `hooksecurefunc(C_NamePlate,
"SetNamePlateSize", ...)` fonctionne sur cette table, et le hook repose notre
largeur dans le même souffle, drapeau de non-récursion compris. La pose du hook
reste sous `pcall` : hooker une table `C_*` est un pari de capacité.

Corollaire d'interface : tant que l'addon tient la taille en pixels, tout
réglage du client qui fait rejouer sa mise en page (`nameplateSize`,
`nameplateAuraScale`, `nameplateDebuffPadding`) se grise plutôt que de se
battre avec lui.

---

## Monter `NamePlatePreviewTemplate` teinte le pilote de barres d'infos

**Suite, et fin, des deux entrées sur l'aperçu.** Le template s'instancie et
s'affiche : c'est ce qui avait fait conclure qu'il était sans danger, la
maquette n'ayant pas d'unité et donc, croyait-on, aucune valeur secrète à
comparer.

**Le raisonnement était faux.** Ouvrir la page qui le portait produit :

```
attempted to iterate a table that cannot be accessed while tainted
(execution tainted by 'BshamelUI')
  CastingBarFrame.lua:722: StopFinishAnims <- StopAnims <- SetUnit
  CompactUnitFrame_SetUnit <- ApplyFrameOptions <- NamePlateBase SetUnit
  <- OnNamePlateAdded <- Blizzard_NamePlates OnEvent
  <- Blizzard_SettingsDefinitions_Frame/Nameplates.lua:15
  <- pcall <- UI/Widgets/PlatePreview.lua:50
```

**Cause** — monter ce template réveille le gestionnaire de barres d'infos du
*panneau de réglages* du client, qui repasse `OnNamePlateAdded` puis
`ApplyFrameOptions` sur les **vraies** plaques. Donc sur de vraies unités, avec
de vraies valeurs secrètes, et toute la chaîne teintée par nous. C'est
exactement le mur de « Appeler le pilote de barres d'infos teinte tout ce qu'il
touche », atteint par une porte qu'on croyait dérobée.

Le même appel expliquait un second symptôme qu'on cherchait ailleurs : **les
plaques reprenaient leur taille Blizzard à chaque ouverture de la fenêtre
d'options**, `ApplyFrameOptions` reposant la mise en page du client.

**Ce qu'on fait** — l'aperçu est retiré, template compris. `pcall` n'en protège
pas : ce n'est pas nous qui levons, c'est le client, parce que nous l'avons
réveillé. Il n'y a pas de version prudente de cet appel — la règle reste **on
n'entre pas dans le code de mise en page du client**, et un template qui le
réveille en fait partie.

---

## Les ressources à cases ne se lisent pas toutes par `UnitPower`

**Symptôme** — un suivi de ressource bâti sur `UnitPower` affiche tout : points
de combo, puissance sacrée, chi, fragments d'âme, charges des arcanes, essence,
runes. Il reste vide sur un **chaman améliorations**, dont Arme-tempête est
pourtant la ressource qu'on regarde le plus.

**Cause** — Arme-tempête n'est pas une ressource du client. C'est une **aura**
qui se cumule (sort 344179, dix cumuls), et `Enum.PowerType` n'a rien qui lui
corresponde. La ressource que le client déclare pour un chaman améliorations est
la puissance élémentaire, qui n'existe pas dans cette spécialisation — donc une
réserve nulle, donc aucune case.

Le piège symétrique existe côté détection : on retient la première ressource dont
`UnitPowerMax` est non nul, et **les points de combo se déclarent plus largement
que les spécialisations qui s'en servent** — un druide qui change de forme en est
le cas courant. Les mettre en tête de liste donne une rangée de cinq cases vides
sur des personnages qui n'ont pas de points de combo.

Troisième piège, dans le piège : **le cumul et le passif qui le donne sont deux
sorts distincts**. `IsPlayerSpell(344179)` rend toujours non — 344179 est le
buff, et un buff ne se « connaît » pas. La reconnaissance par le sort ne marche
donc pas du tout, et elle échoue en silence : la rangée reste simplement éteinte.

**Ce qu'on fait** — deux mécanismes côte à côte dans `Modules/ClassResource.lua` :
`UnitPower` pour les six ressources du client, `C_UnitAuras.GetPlayerAuraBySpellID`
pour les cumuls d'Arme-tempête. Celle-ci est reconnue par son **numéro de
spécialisation** (263, Améliorations), qui est la seule réponse valable aussi
quand la rangée est vide — c'est-à-dire au moment précis où il faut décider de
l'afficher. La présence du cumul sert de filet : tant qu'aucune ressource n'a été
retenue, chaque aura du joueur redéclenche une détection, ce qui rallume la
rangée même si le numéro de spécialisation devenait faux.

Et les points de combo **ferment** la liste de détection, de sorte qu'une
ressource franche l'emporte toujours sur eux.

Les runes ont leur propre variante du même piège : elles n'émettent pas
`UNIT_POWER_UPDATE` mais `RUNE_POWER_UPDATE`, parce que chacune a son temps de
recharge. Leur valeur, elle, se lit bien par `UnitPower` — c'est le nombre de
runes prêtes.

---

## Les teintes de ressource sont publiées, il ne faut pas les recopier

**Symptôme** — sept teintes écrites en dur pour sept ressources, qui ne
ressemblent plus tout à fait à celles du jeu après un changement d'habillage.

**Cause** — `PowerBarColor` est la table où le client range la couleur de chaque
ressource. Elle est indexée de **deux** façons — par jeton (`"HOLY_POWER"`) et
par numéro de type de ressource — sans que rien ne garantisse que les deux
couvrent la même liste.

**Ce qu'on fait** — `T.PowerColor(token, powerType)` essaie l'un puis l'autre, et
retient le résultat par jeton : la fonction est appelée depuis un chemin qui bat,
et rien ne dit que le client rende la même table à chaque fois (règle 7). Elle
rend `nil` là où il ne publie rien — Arme-tempête, qui n'est pas une ressource —
et l'appelant se rabat alors sur la couleur de classe.

---

## Une plaque réduite à son nom repeint ce nom hors des deux passages obligés

**Symptôme** — les noms des joueurs alliés restent au vert du client alors que
l'addon leur pose une couleur de classe. Le même code teinte pourtant très bien
le nom d'un adversaire. La différence : les plaques alliées sont en **nom seul**
(`nameplateShowOnlyNameForFriendlyPlayerUnits`).

**Cause** — les deux fonctions que le module coiffe pour repeindre,
`CompactUnitFrame_UpdateHealthColor` et `CompactUnitFrame_UpdateName`, sont les
passages obligés d'une plaque **ordinaire**. Une plaque réduite à son nom n'a
plus de barre de vie, et le client y réécrit la couleur du nom par d'autres
chemins — mise en place du cadre, changement d'options du pilote. Notre teinte
est donc bien posée, puis effacée dans le même souffle.

Le symptôme est trompeur pour cette raison : il ressemble à « le réglage ne
s'applique pas » alors que le réglage s'est appliqué, et il oriente vers la
lecture de la classe — `UnitClass`, les valeurs secrètes — au lieu de la question
posée, qui est *qui a écrit en dernier*.

**Ce qu'on fait** — on se branche sur l'**écriture** au lieu du chemin qui y
mène : `U.GuardedHook` sur `SetTextColor` **et** `SetVertexColor` de la chaîne de
texte du nom. Quel que soit le chemin par lequel le client repasse, il finit là.

C'est exactement le remède déjà employé pour le corps des textes de plaque
(`hookTextSize`, sur `SetFont` et `SetFontObject`), et pour la même raison : on
ne court pas après le client, on se met là où il écrit. Les deux méthodes sont
guettées dans les deux cas — n'en prendre qu'une laisse passer la moitié des
remises à zéro.

Deux précautions qui vont avec :

- **un drapeau de réentrance** (`settingNameColor`), sans quoi notre propre
  écriture rappelle le hook ;
- **l'unité se lit au déclenchement**, pas à la pose. Les chaînes de texte d'une
  plaque sortent d'un pool et servent tour à tour à plusieurs unités : un hook
  qui retiendrait l'unité connue au moment de sa pose teindrait le nom du
  suivant avec la classe du précédent. Le hook sort d'ailleurs tout de suite si
  l'unité n'est pas une plaque suivie — c'est ce qui écarte la plaque
  personnelle.

---

## Rendre un portrait au client sans lui demander de le redessiner

**Symptôme** — trois cent sept erreurs dans une session d'arène, dans le code du
client, sans qu'aucun réglage de la page *Cadres d'unités* n'ait jamais été
allumé :

```
Blizzard_UnitFrame/Mainline/UnitFrame.lua:1054: attempt to perform boolean test
on local 'isMyPlayer' (a secret boolean value, while execution tainted by
'BshamelUI')
  UnitFrame_ShouldReplacePortrait
```

**Cause** — deux fautes qui se multiplient l'une l'autre.

La première est un appel. `restorePortraits` rendait le portrait au client en
rappelant `UnitFramePortrait_Update`, au motif que lui seul sait s'il aurait
dessiné un visage ou une icône de classe. Sauf que la façon dont il le sait est
exactement ce qui casse :

```lua
function UnitFrame_ShouldReplacePortrait(self)
    if UnitIsHumanPlayer(self.unit) then
        local isMyPlayer = UnitIsUnit(self.unit, "player");
        if isMyPlayer then                       -- ligne 1054
```

`UnitIsUnit` répond en booléen **secret** dès que l'identité de l'unité est
protégée — une arène, un champ de bataille. Le client teste ce booléen en
direct, ce qu'il a parfaitement le droit de faire depuis son propre code ; il
n'en a plus le droit quand l'exécution est teintée par un addon, et elle l'est
puisque c'est l'addon qui a lancé l'appel. C'est le même constat que pour
`UpdateNamePlateOptions` (voir « Appeler le pilote de barres d'infos teinte tout
ce qu'il touche ») : **on n'entre pas dans le code du client**, et il n'existe
pas de version prudente de cet appel — ni `pcall`, ni garde, ni moment opportun.
Ici `BUI.safecall` attrapait bien l'erreur, ce qui l'empêchait de casser le
passage mais pas de remplir BugSack.

La seconde faute est un compteur. La restitution passait sur les cinq cadres à
**chaque** rafraîchissement — changement de cible, de focus, de groupe — et pas
seulement quand l'option venait de s'éteindre. Un joueur qui n'a jamais coché la
case payait donc cinq appels par changement de cible pour rendre des portraits
auxquels personne n'avait touché. D'où le compteur à trois cent sept.

**Ce qu'on fait** — les deux, et il faut les deux :

- **on ne rend que ce qu'on a pris.** Une table `painted` retient les cadres sur
  lesquels l'icône a réellement été posée ; la restitution ne parcourt qu'elle,
  et la vide. Quand rien n'a été peint, elle ne fait rien du tout ;
- **on refait le choix du client au lieu de le lui demander.** `replacementAtlas`
  reprend `UnitFrame_ShouldReplacePortrait` avec des gardes de secret là où il
  teste en direct, et `SetPortraitTexture` — la fonction qu'il appelle lui-même
  pour un visage — pose le reste. `U.IsTrue` fait qu'un secret vaut « non » : on
  retombe alors sur le visage, qui est son défaut.

Le commentaire qui vivait là disait « reposer une texture à la main choisirait à
sa place ». Il avait raison sur le principe et tort sur la conclusion : la copie
d'une décision de six lignes se paie une fois par patch, l'appel se paie une fois
par cadre et par changement de cible.

**La leçon générale** — une restitution est une **transition**, pas un état à
réaffirmer. Tant qu'elle est écrite comme « à chaque passage, remets tout en
place », son coût est celui du chemin le plus chaud, et elle s'exécute surtout
pour des joueurs qui n'ont jamais demandé la fonctionnalité. Retenir ce qu'on a
modifié coûte une table ; ne pas le retenir coûte un appel dans le code du client
à chaque battement.

---

## Une lueur qui n'apparaît qu'au survol est une lueur éteinte, pas absente

**Symptôme** — la petite lueur verte que le client pose sur un bijou à effet
utilisable, dans la barre d'action, ne s'affiche pas. Elle apparaît dès qu'on
survole le bouton avec le curseur, puis disparaît à la première utilisation.

**Ce que le symptôme fait croire** — que quelque chose *déclenche* la lueur trop
tard, et qu'il manque un événement à écouter. On cherche alors du côté de ce qui
l'allume.

**Cause** — c'est l'inverse : la lueur est allumée depuis le début, et on la
couvre. Le mode sombre classait sa texture comme de l'habillage et la multipliait
par `T.SHADE_FACTOR`, ce qui la rend noire donc invisible. Le survol fait
repeindre le bouton par le client, qui repose sa couleur de sommet ; notre
passage suivant — déclenché par l'utilisation d'une action — la rassombrit.

D'où la règle de lecture, qui vaut au-delà d'ici : **une chose qui apparaît au
survol et repart ensuite n'est pas une chose qui manque, c'est une chose qu'on
efface.** Le survol n'est pas un déclencheur, c'est le seul moment où le client
réécrit sans qu'on repasse derrière.

C'est exactement le défaut de la texture `OutOfRange` du gestionnaire de temps de
recharge, deux entrées plus haut, avec un symptôme différent parce que ce qui
repeint n'est pas le même.

**Ce qu'on fait** — deux listes, parce qu'il y a deux formes :

- `STATE_KEYS` gagne `SpellHighlight`, `Glow`, `Alert` et `Proc` : les textures
  de signal posées directement sur le bouton ;
- `SIGNAL_FRAMES` est nouvelle et écarte des **cadres entiers**. Une lueur de
  procédé n'est pas une texture mais un petit cadre qui en porte plusieurs —
  départ d'animation, boucle, halo. Les nommer une par une revient à parier
  qu'on les a toutes, et ce pari se reperd à chaque extension. On s'arrête à la
  porte : le cadre n'est pas descendu.

Le doute se tranche toujours dans le même sens : ne pas toucher. Au pire il
reste une lueur claire sur une barre sombre ; l'erreur inverse éteint un signal.

---

## La bordure d'un bouton d'action n'est pas de l'habillage

**Symptôme** — le liseré vert que le jeu pose autour d'un **objet équipé** placé
sur une barre d'action (un bijou à effet utilisable, typiquement) ne s'affiche
pas. Il apparaît au survol du bouton et repart à l'utilisation suivante.

**Cause** — la texture est `ActionButtonNNBorder`, publiée sous la clé `Border`.
Le mode sombre la classait comme de l'habillage et l'assombrissait.

Le nom est tout le piège : « bordure » se lit comme du décor, et rien dans le
classement ne la distinguait du cadre d'une fenêtre. Sur un bouton d'action, elle
ne décore rien — l'habillage y est porté par `NormalTexture`, `SlotArt`,
`SlotBackground` et `BorderShadow`. `Border` reste masquée la plupart du temps et
ne s'affiche **que pour dire quelque chose** ; le jeu la montre teintée de vert
(`0, 1, 0`) pour marquer un objet équipé.

**Ce qu'on fait** — `BORDER_SIGNALS`, par élément : sur les barres d'action, la
bordure est laissée intacte. Ailleurs — infobulle, cadre d'unité — une bordure
est bien de l'habillage, d'où la liste par élément plutôt qu'une règle générale.

**Le corollaire, plus large** — le relevé qui a tranché (`/bui glow`, ajouté pour
l'occasion) a montré que *tout* ce qu'un bouton d'action porte en cadres enfants
était assombri : animations d'incantation, réticule de cible, éclat de fin de
temps de recharge, halo d'attaque automatique. Aucun n'est de l'habillage, tous
disent quelque chose, et **plusieurs sont anonymes** — aucune liste de noms ne
pouvait donc les rattraper.

D'où `FLAT_BUTTONS` : sur les barres d'action, le parcours s'arrête au bouton.
Ses propres textures sont teintées, ce qu'il porte ne l'est pas. C'est la leçon
générale de cette famille de défauts — **écarter par ce que la chose est, pas par
la liste de ce qu'elle contient**, parce que la seconde se reperd à chaque
extension.

**Comment on l'a su** — pas en lisant le code du client ni en devinant : en
demandant à l'addon ce qu'il avait touché. C'est ce que fait `/bui glow`, et
c'est pourquoi il reste livré. Une texture de signal assombrie ne ressemble pas à
une texture assombrie : elle ressemble à une lueur qui manque, et le symptôme
désigne toujours le déclencheur plutôt que le voile.

---

## Un secret se fait passer, il ne se lit pas — et le repli comptait plus que le garde

**Symptôme** — les noms alliés prennent bien la couleur de classe en extérieur,
et virent au **blanc** en donjon, en raid et en champ de bataille.

**Ce qui a mis sur la voie** — c'est un blanc, pas le vert du client. Une teinte
qu'on ne pose pas laisse celle du jeu ; un blanc franc ne peut venir que de nous.
Le symptôme désignait donc notre repli, pas notre garde.

**Cause** — en instance et en PvP, le client protège l'identité des unités :
`UnitClass` rend une chaîne **secrète**. Le garde `U.IsSecret` la voyait très
bien et sortait — comme il devait — mais tombait alors sur
`return T.COLOR.WHITE:GetRGB()`, écrasant la teinte du client par un blanc qui
n'informe personne.

Le garde était juste, le repli était mal placé. C'est une erreur plus discrète
qu'un secret lu par mégarde : rien ne lève, rien n'apparaît dans BugSack, et la
fonctionnalité marche partout où l'on pense à la tester.

**Ce qu'on fait** — deux choses, et la seconde vaut au-delà d'ici :

- **on tente le passage.** Un secret traverse l'addon, il ne s'y arrête pas :
  `T.SecretClassColor` remet le jeton tel quel à `C_ClassColor.GetClassColor`,
  qui a le droit de le comprendre, et rend trois nombres qu'on ne regarde jamais.
  Le tout sous `pcall` — un refus ne coûte rien ;
- **on ne se replie plus sur une couleur.** Quand le passage échoue, on
  s'abstient de peindre et le client garde la main de bout en bout.

**Le drapeau de retour n'est pas une commodité.** Les nombres rendus peuvent être
secrets à leur tour, et un secret ne se **teste** pas plus qu'il ne se lit :
`if r then` lève exactement comme `if flag then` sur un booléen secret. La
fonction rend donc un booléen **qu'on a fabriqué soi-même**, seul de la chaîne
que l'appelant ait le droit de regarder. Même raison pour le `found` interne :
`r == nil` ne conviendrait pas, comparer un secret lève aussi.

**La leçon générale** — face à une valeur protégée, il y a trois conduites et
elles ne se valent pas : la lire (lève), s'en passer par un repli (silencieux, et
souvent pire que rien), ou la **faire circuler** jusqu'à une API du client.
La troisième est celle que le mécanisme prévoit ; la deuxième est celle qu'on
écrit sans y penser.

**Ce qui reste limité** — la couleur de classe des adversaires sur la barre de
vie (`pvpClassColor`) a la même contrainte. Elle dégrade proprement, elle :
faute de classe lisible, `healthColor` retombe sur `UnitSelectionColor`,
c'est-à-dire sur la teinte du client. Pas de blanc, donc pas de symptôme — mais
pas de couleur de classe en instance non plus.

---

## Une planche d'images posée par son atlas ne s'anime pas toute seule

**Symptôme** — la lueur de procédé du client, reprise sur une rangée de cases,
s'affiche mais reste **fixe**. Elle ne ressemble pas à une panne : à la taille
d'une case de ressource, la planche entière tassée dans la place d'une vignette
passe très bien pour une lueur floue. On cherche donc du côté de l'animation,
alors que la texture n'est même pas cadrée.

**Cause** — `UI-HUD-ActionBar-Proc-Loop-Flipbook` n'est pas une image mais une
**planche de trente vignettes**. `SetAtlas` la pose en entier ; c'est une
animation `FlipBook` qui, chez le client, en montre une à la fois. Brancher cette
animation depuis Lua demande de désigner la texture animée par une clé publiée
sur le cadre (`Animation:SetChildKey`), un détour dont l'échec **ne se voit
pas** : rien ne lève, l'animation ne fait simplement rien.

**Ce qu'on fait** — le montage complet a été **relevé sur `LibCustomGlow-1.0`**,
l'implémentation de référence des addons, qui le tient elle-même du code
d'interface du client. On l'a lue pour savoir *quelles pièces d'API* résolvent le
problème, puis on a écrit les nôtres (règle 8). Aucune ligne n'en vient, et la
bibliothèque n'est pas embarquée.

Trois pièces, dont aucune ne se devine — on a passé une demi-douzaine de tours à
les deviner, et à chaque fois le symptôme désignait autre chose :

1. **Une animation d'opacité immobile accompagne le défilement.** Sur la même
   texture (`SetChildKey`), au même rang (`SetOrder(0)`), d'une durée nulle, et
   qui va de 1 à 1. Elle ne fait rien — elle est là pour que le groupe ait une
   opacité à tenir sur la texture pendant que la planche défile. Sans elle, la
   planche **ne défile pas**, et une planche qui ne défile pas s'affiche en
   entier : trente vignettes tassées dans la place d'une, ce qui ressemble à une
   lueur floue et non à une panne.
2. **La lueur passe au-dessus**, et de plusieurs crans de niveau (huit).
3. **Elle n'est pas additive.** C'est le contre-pied de l'intuition — une lueur,
   on la veut lumineuse — mais la planche porte déjà sa propre lumière :
   l'additionner à ce qu'il y a dessous la brûle jusqu'au blanc. C'est ce qui
   donnait une tache blanche là où on attendait un tourbillon. Seule la vignette
   de *départ*, un éclat bref, est additive chez le client.

À quoi s'ajoute la géométrie : le cadre de la lueur déborde d'un cinquième **de
chaque côté** — de la largeur à gauche et à droite, de la hauteur en haut et en
bas —, ce qui lui donne la forme de ce qu'il entoure.

**La grille se vérifie, elle ne se devine pas.** `GetAtlasInfo` ne rend pas le
découpage, mais il rend `width` et `height` — et une planche de vignettes
**carrées** se recoupe de là. Pour celle-ci : 333 × 400, soit 333/5 = 66,6 et
400/6 = 66,7 sur une grille de 5 colonnes × 6 rangées. Les deux tombent sur le
même nombre, la grille est donc la bonne — ce que la référence a confirmé. Un
découpage faux se serait vu à ces deux quotients qui ne se rejoignent pas.

**Une lueur par élément, jamais une pour l'ensemble — et c'est une question de
netteté, pas de goût.** Une vignette de cette planche mesure soixante-six pixels
de côté. Tirée aux mesures d'une rangée entière — deux cent cinquante de large
sur trente de haut —, elle est agrandie de quatre fois dans un sens et réduite de
moitié dans l'autre : elle devient floue et crénelée. Aucun réglage ne rend à une
image des pixels qu'elle n'a pas.

À l'échelle d'un élément, la même vignette n'est que **réduite** dans les deux
sens, donc nette. Les lueurs voisines se recouvrent et se lisent de toute façon
comme une seule bande : on obtient l'effet d'ensemble sans payer l'étirement.
C'est la règle générale pour toute planche du client — elle est dessinée à la
taille d'un bouton, et c'est à cette taille-là qu'elle se pose.

**Ce qui doit rester lisible au-dessus de la lueur a besoin de son propre cadre.**
Le nombre posé au milieu de la rangée en est un : une texture du panneau passe
sous n'importe quel cadre enfant, quel que soit son calque.

**La leçon de méthode, et c'est la vraie.** Sur un effet visuel du client, le
symptôme ne désigne presque jamais le réglage. Une planche qui ne défile pas
paraît **discrète** ; une lueur additive paraît **trop grande** ; une lueur
rangée derrière paraît **fixe**. Les trois poussent à toucher la taille et la
vitesse, et aucun des trois n'en vient — on a monté le débordement deux fois,
ralenti jusqu'à onze fois la vitesse du client, essayé de faire voyager la lueur
autour du cadre, pour finir exactement sur les valeurs de départ.

Le bon réflexe n'est pas d'ajuster, c'est d'**aller lire une implémentation qui
marche**. Elles sont à portée : les bibliothèques embarquées dans les addons de
`Interface\AddOns` sont du code qui tourne sur ce client-ci. La règle 8 permet de
les lire pour identifier les pièces d'API ; ce qu'elle interdit est d'en copier.
Une demi-douzaine d'allers-retours de réglages au jugé contre dix minutes de
lecture.

---

## Une lueur qui doit s'étendre ne se fait pas avec une image

**Symptôme** — la lueur de procédé du client, montée correctement, rendue sur une
rangée large et basse : floue, crénelée, « hyper étendue ». Réduite à l'échelle
d'un élément elle redevient nette, mais on perd l'effet d'ensemble qu'on voulait.

**Cause** — c'est une **image**, et une image a une taille. Une vignette de cette
planche mesure soixante-six pixels de côté ; posée sur deux cent cinquante, elle
est agrandie de quatre fois. Aucun réglage ne rend à une image des pixels qu'elle
n'a pas, et c'est vrai de toutes les lueurs dessinées du client — planches de
procédé, halos de bouton, contours ouvragés. Elles sont faites pour un bouton.

**Ce qu'on fait** — on change de matière. La lueur est faite de **rectangles de
couleur unie** (`Interface\Buttons\WHITE8x8`, teinté par `SetVertexColor`) dont
la forme vient de l'ancrage et la position d'un calcul. Rien n'est échantillonné,
donc rien ne se dégrade : c'est aussi net sur trois pixels que sur trois cents,
quelles que soient les proportions du cadre.

Des segments courent le long du contour : pour chacun, on prend son intervalle
sur le périmètre et on l'intersecte avec les quatre côtés, ce qui donne au plus
quatre morceaux à poser. Les côtés sont visités deux fois, décalés d'un tour,
pour qu'un segment à cheval sur le coin de départ retrouve sa part rebouclée sans
qu'on traite ce cas à part.

**C'est le procédé des lueurs « au pixel » des addons**, relevé sur
`LibCustomGlow-1.0` pour savoir quelles pièces d'API le rendent possible, puis
réécrit (règle 8). La bibliothèque, elle, découpe la bande par une **texture de
masque** inset de l'épaisseur du trait, ce qui lui permet de n'ancrer que deux
coins par segment ; on a préféré calculer les morceaux côté par côté — un peu
plus d'arithmétique, aucune dépendance à un masque ni à une texture tierce.

**La règle générale** — devant une lueur à poser sur un cadre dont on ne connaît
pas d'avance les proportions, la question n'est pas « quelle texture » mais
**« image ou couleur »**. Une image tient si le cadre est à peu près carré et à
peu près de la taille d'un bouton ; sinon il faut de la couleur, qu'on peut
étirer sans fin. On a passé plusieurs itérations à chercher la bonne image avant
de se poser la question.

**Un aplat n'est pas une lueur, un dégradé si.** Le premier essai en couleur unie
donnait un liseré : net, franc, et parfaitement plat. Ce que l'œil lit comme de la
lumière n'est pas l'intensité mais le **fondu** — un trait qui s'éteint
progressivement autour de lui. `SetGradient` le donne sans image, et le dégradé
est calculé par sommet : il ne se pixellise pas davantage que l'aplat, ce qui
préserve tout l'intérêt de la couleur pure.

Deux teintes, enfin, et non une : un cœur presque **blanc**, un halo coloré. Une
lumière forte sature l'œil avant de lui montrer sa couleur, et c'est en
s'éloignant qu'elle la prend. Un halo de la teinte du cœur ne donne pas une lueur
plus colorée — il donne un trait plus épais.

**Le dernier mot : ni l'une ni l'autre, les deux.** La couleur pure n'a pas
suffi. Un aplat **s'arrête net** : ses deux bouts sont des cassures franches, et
une cassure franche se lit comme un pixel, quelle que soit la douceur du fondu
sur ses côtés. On peut adoucir les flancs indéfiniment, jamais les extrémités.

D'où le partage retenu :

- **le fond**, continu et immobile, en couleur pure. Il n'a pas d'extrémités —
  il fait le tour — donc rien à trahir, et il s'étire à volonté ;
- **les éclats** qui le parcourent, en image. Mais une image qui n'est qu'un
  **fondu radial** : ni trait, ni contour, ni détail. Agrandie, elle reste un
  dégradé rond. C'est précisément ce qu'un aplat ne sait pas produire.

La règle « image ou couleur » n'était donc pas la bonne question. La bonne est
**« l'image a-t-elle des détails ? »** : une planche de tourbillon en a, un fondu
radial n'en a pas. Le second s'étire aussi bien qu'une couleur unie, et sait en
plus ce qu'elle ne saura jamais faire — finir en douceur.

**Les teintes, elles, se relèvent — elles ne se raisonnent pas.** On était parti
d'un cœur presque blanc, sur le raisonnement qu'une lumière forte sature l'œil
avant de lui montrer sa couleur. C'est vrai d'une source éblouissante ; ça ne
l'est pas d'un liseré de quelques pixels, qui n'a pas de quoi éblouir et se
contente de paraître **délavé**. À cette taille, la chaleur passe par la
saturation, pas par l'intensité.

Les valeurs retenues sont celles d'une interface web dont le rendu était celui
qu'on cherchait, lues dans sa feuille de style : un noyau `#FCD34D`, un halo
`#FBBF24` à neuf dixièmes, et un flou d'une fois et demie l'épaisseur du noyau.
Ce dernier rapport comptait autant que les couleurs — on avait un halo deux fois
plus large, assez dilué pour ne plus se lire comme appartenant au trait.

---

## Un sous-calque de texture ne dépasse pas sept

**Symptôme** — `Frame:CreateTexture(): Sublevel must be between -8 and 7`, à la
construction, dès qu'un repère a été refait en plusieurs épaisseurs.

**Cause** — le sous-calque du repère de palier valait déjà sept, le plafond, et
les épaisseurs ajoutées s'empilaient **au-dessus** de lui. C'est le piège d'une
constante nommée par son rôle (« au-dessus de ce que le client dessine ») et non
par sa position dans une échelle bornée : rien dans son nom ne dit qu'il n'y a
plus de place au-dessus.

**Ce qu'on fait** — on empile **vers le bas** depuis la constante : elle marque le
dessus de la pile, et chaque couche supplémentaire se range en dessous. La borne
est notée avec elle, pour que le prochain qui l'utilise n'ait pas à la
redécouvrir par une erreur.

**À retenir** — un sous-calque n'est pas une valeur qu'on ajuste, c'est un rang
dans une échelle de seize crans. Les deux bouts lèvent, ils ne saturent pas.

---

## La vérification locale ne voyait ni le code mort ni les noms masqués

**Symptôme** — `lint-local.sh` intégralement vert, la CI rouge dix secondes après
le tag, sur quatre avertissements `luacheck` : une fonction devenue inutilisée
(`W211`) et trois variables masquant une portée englobante (`W431`, `W432`).

**Cause** — `luacheck` ne tourne pas en local : il dépend de `luafilesystem`, qui
se compile, et la machine n'a pas de compilateur C. L'en-tête du script le dit,
mais la conséquence n'était pas tirée : ces familles-là n'étaient vérifiées
**nulle part** avant la CI. Le trou ne se voyait qu'au pire moment — un tag posé,
donc un numéro de version brûlé.

**Ce qu'on fait** — `lua-language-server`, lui, connaît les mêmes défauts ; il les
classait simplement en *hint*, que le script ne lit pas. On relève leur sévérité
à `Warning` dans `.luarc.json` (`unused-function`, `unused-local`,
`redefined-local`). Les deux analyses ne se recouvrent pas entièrement, mais ces
trois familles-là sont désormais couvertes des deux côtés.

**Un effet de bord à connaître** — la comparaison des globales lisait **tout**
`.luarc.json` et prenait la moindre chaîne pour un nom déclaré. Le nouveau bloc de
sévérités y a introduit des `"Warning"`, aussitôt signalés comme globales
manquantes de `.luacheckrc`. La lecture est maintenant bornée au bloc
`diagnostics.globals`.

**À retenir** — un garde-fou qui ne tourne que dans la CI n'est pas un garde-fou,
c'est un préavis. Quand un outil ne peut pas tourner en local, la question n'est
pas « tant pis » mais « qu'est-ce qui, ici, couvre le même terrain ».

---

## Répondre à un événement n'empêche pas le client d'ouvrir sa fenêtre

**Symptôme** — la validation automatique des rôles marche, la fenêtre du client
part d'elle-même, et pourtant elle *apparaît* : un clignotement au milieu de
l'écran à chaque inscription.

**Cause** — le client ouvre `LFGRoleCheckPopup` depuis son propre abonnement à
`LFG_ROLE_CHECK_SHOW`, celui-là même auquel on répond. Répondre plus tôt ne
l'empêche pas d'ouvrir : cela avance seulement le moment où elle se referme.
L'ordre entre deux abonnés d'un même événement n'est pas défini, donc il n'y a
même pas de « plus tôt » sur lequel compter.

**Ce qui marche** — se poser sur le `OnShow` de la fenêtre et la cacher là. Une
frame montrée puis cachée **dans le même passage** n'est jamais dessinée : le
clignotement disparaît au lieu d'être raccourci.

Deux précautions vont avec :

* **répondre depuis les deux chemins**, l'événement et le `OnShow`, avec un
  drapeau qui dit que la demande en cours a déjà sa réponse. Puisque l'ordre est
  indéfini, le premier servi répond et le second n'a plus rien à faire ;
* **ne jamais cacher sans avoir répondu**. Une fenêtre masquée à laquelle
  personne n'a répondu laisse la demande expirer sans que le joueur ait rien vu —
  le pire des deux mondes.

Le même raisonnement vaut pour toute fenêtre du client qu'on veut supprimer
plutôt que fermer.

---

## Le contour d'une fenêtre du client ne se convertit pas en contour de panneau

**Ce qu'on voulait** — le métal que le jeu pose autour de ses menus, sans la
barre de titre, pour habiller les panneaux flottants de l'addon.

**Ce qui a été tenté**, dans l'ordre, chaque étape corrigeant la précédente et en
révélant une autre :

1. monter `BasicFrameTemplate` et masquer ce qui n'est pas le contour — il reste
   toujours une pièce, et `T.ClearPanelBackground` masque la bordure avec le
   fond puisqu'elle est faite de régions ;
2. reposer la texture du bas sur les pièces du haut — elles n'ont ni la même
   hauteur ni la même largeur, le dessin arrive étiré ;
3. n'appliquer que son découpage neuf à un cadre nu — ce template n'en a pas,
   ses textures sont posées à même le cadre ;
4. redessiner les huit pièces à partir de celles du bas — un bord décroché perd
   la largeur qu'il tenait de ses deux ancrages ;
5. reprendre les décalages d'ancrage de chaque pièce — un seul côté tombe juste,
   le droit, parce que c'est le seul que le client ancre au cadre : les autres
   s'accrochent à leurs voisines, et leur décalage ne parle pas du cadre ;
6. cesser d'imposer des coordonnées aux bords — une texture en répétition tire
   les siennes de sa taille, donc le retournement est perdu et la répétition
   brouillée.

**Ce qui marche** — `DialogBorderTemplate`, symétrique par construction, monté
tel quel. Il n'a rien à démonter, donc rien à casser.

**À retenir** — la géométrie d'un template du client est un tout : ses pièces se
tiennent les unes aux autres, et on n'en emprunte pas la moitié. Quand un
template ne fait pas ce qu'on veut, la question est « lequel le fait ? », pas
« comment démonter celui-ci ? ». Six tentatives et neuf allers-retours avec le
joueur pour l'établir.

---

## `namePlateUnitToken` est vide sur les plaques de ce client

**Symptôme** — tout ce que le module pose plaque par plaque n'atteint qu'une
plaque sur treize : un aperçu qui n'apparaît que sur une, une animation qui se
fige, un réglage qui ne repeint rien, un crâne d'exemple qu'on ne parvient plus
à retirer.

**Ce qu'on trouve** — `/bui noms`, treize plaques à l'écran :

```
GetNamePlates: 13 | plates: 1 | namePlateUnitToken: nil
```

`C_NamePlate.GetNamePlates()` répond, et bien. Ce qui manque est le champ que
`NamePlateBaseMixin:OnAdded` est censé poser sur chaque plaque, et sur lequel
tous les recensements s'appuient — y compris le nôtre, qui écartait donc
silencieusement tout ce qu'il ne savait pas nommer. La seule plaque connue
venait d'une annonce `NAME_PLATE_UNIT_ADDED`, où le jeton est passé en argument.

**Ce qu'on fait** — l'unité se lit sur le **cadre d'unité** de la plaque,
`UnitFrame.unit` ou `UnitFrame.displayedUnit`, avec le jeton comme premier choix
s'il est là. C'est le chemin qu'emploie déjà le hook des couleurs de nom, et il
n'a jamais manqué une plaque.

**La leçon** — un champ publié par le client se vérifie sur pièces avant qu'on
bâtisse dessus, surtout quand il est le seul lien entre deux mondes. Une liste
qui se remplit à moitié ne lève aucune erreur : elle rend simplement la moitié
des symptômes inexplicables.


---

## Les lignes du grimoire ne sont pas des enfants ordinaires

**Symptôme** — le mode sombre fonce le parchemin du grimoire, et rien d'autre :
les noms de sorts restent noirs, le petit fond clair derrière chaque ligne reste
clair. Un relevé sous le curseur confirme que `BookBGLeft`, `BookBGRight`,
`TopBar` et `Bookmark` sont bien teintés — donc le parcours atteint la fenêtre.

**Ce qu'on trouve** — les lignes de sorts ne descendent pas de `GetChildren` :
elles sortent d'un pool que deux vues mettent en page, et se demandent à celles-ci
par `GetLayoutChildren` :

```
PlayerSpellsFrame.SpellBookFrame.PagedSpellsFrame.View1  (et View2)
    → :GetLayoutChildren() → une ligne par sort
        .Name       le nom
        .SubName    « Passif », « Invocation »…
        .Backplate  le fond clair derrière la ligne
```

Un parcours récursif classique ne les voit donc jamais, et il n'y a aucune erreur
pour le dire : on teinte une fenêtre vide.

**Quand y revenir** — le client remplit chaque ligne par
`PagedSpellsFrame.elementTemplateData.SPELL.initFunc`, et il y repose la couleur
du texte. C'est le seul moment qui soit à l'heure : l'affichage de la fenêtre
arrive avant que les lignes existent, la pagination avant qu'elles soient
remplies. On s'y branche par `hooksecurefunc`, en **groupant** — cette fonction
est appelée une fois par ligne, donc dix-huit fois pour une page tournée.

**Provenance** — chemins et fonction relevés en lisant *DarkModeSpellBook* de
keyboardturner, pour savoir **où** se brancher (CLAUDE.md règle 8 : lire pour
identifier une API, jamais copier). Son réglage par défaut est un multiplicateur
neutre à 0,5 sur le fond et du blanc plein sur les textes — c'est la valeur que
`T.SHADE_FACTOR_PARCHMENT` reprend. Notre implémentation est la nôtre : le moteur
d'assombrissement existait déjà, il lui manquait ces deux adresses.

---

## En instance, le client ne rend aucune plaque alliée — il n'en cache pas l'identité, il ne les donne pas

**Symptôme** — la couleur de classe sur le nom des alliés marche en extérieur et
ne fait **rien** en donjon. Aucune erreur, aucune trace dans BugSack : le nom
reste blanc, exactement comme si la case n'était pas cochée.

**Les trois causes qu'on a soupçonnées, et pourquoi elles étaient toutes fausses**
— chacune était plausible, et toutes supposaient qu'on tenait la plaque :

1. le passage de la classe refusé (`C_ClassColor.GetClassColor` sur un jeton
   secret) ;
2. l'écriture refusée (`SetTextColor` sur des nombres secrets) ;
3. le cadre déclaré interdit (`IsForbidden`), qu'on écarte à l'entrée.

**Ce qu'on trouve** — `/bui noms`, dans un donjon, l'écran couvert de noms
alliés :

```
nameplateShowOnlyNameForFriendlyPlayerUnits: 1
GetNamePlates: 0 | plates: 0
```

Zéro. Pas une plaque protégée, pas un cadre interdit qu'on aurait à écarter :
**le client n'en rend aucune**. `C_NamePlate.GetNamePlates()` et
`C_NamePlate.GetNamePlateForUnit()` répondent vide au code non sécurisé, et
`NAME_PLATE_UNIT_ADDED` ne parle pas de ces unités. Le nom que le joueur voit à
l'écran est dessiné par le client sur un cadre qu'il ne publie pas.

Aucun des trois soupçons n'était donc en cause, et aucun ne pouvait l'être : les
trois décrivent ce qu'on ferait d'une plaque qu'on ne reçoit pas.

**La leçon, et elle vaut au-delà d'ici** — *avant* de se demander ce que le
client laisse **lire** d'une unité, se demander s'il donne la **frame**. Ce sont
deux murs distincts, à deux hauteurs différentes, et le second est très au-dessus
du premier. Le mécanisme des valeurs secrètes est bavard — il lève, il nomme, il
apparaît dans BugSack — et c'est ce qui le rend attirant comme explication. Une
liste vide ne dit rien du tout, et c'est justement pour cela qu'on la lit en
dernier.

**Ce que le diagnostic a coûté** — `/bui noms` finissait par son recensement, et
les deux sorties anticipées l'emportaient avec elles. « La cible n'a pas de
plaque » sans les deux nombres qui l'expliquent : trois allers-retours en jeu
pour une ligne qui était déjà écrite, mais placée après la porte de sortie. **Un
diagnostic dit l'état d'ensemble avant de dire l'état du cas**, toujours — le cas
manque précisément quand on en a besoin.

**Ce qu'on fait** — pour tout ce qui demande la frame, rien : la limite est celle
du client, elle vaut pour tout addon, et les infobulles de la taille et du corps
du nom allié la disent (« hors instance uniquement »). Pour les **couleurs de
classe**, en revanche, il existe une porte que ce mur ne ferme pas : trois CVars
que le client relit lui-même — voir la note suivante. La couleur du nom allié
est donc passée par là, et son infobulle ne porte plus la restriction.

---

## Les couleurs de classe des plaques sont trois CVars — le client peint là où l'addon n'entre pas

**Symptôme** — nos couleurs de classe, peintes à la main, marchent en extérieur
et s'arrêtent net en instance. Deux murs distincts les arrêtaient : l'identité
secrète des joueurs (arène, champ de bataille, donjon), et les plaques alliées
que le client ne rend pas du tout (voir la note précédente).

**Ce qu'on trouve** — relevé dans BetterBlizzPlates (règle 8 : lire pour
identifier l'API, jamais copier), qui ne peint rien lui-même pour ce cas : il
coche des CVars, et c'est le client qui peint.

- `nameplateShowClassColor` — la barre de vie des joueurs **adverses** ;
- `nameplateShowFriendlyClassColor` — la barre de vie des joueurs **alliés** ;
- `nameplateUseClassColorForFriendlyPlayerUnitNames` — le **nom** des joueurs
  alliés. La graphie est de la même famille que
  `nameplateShowOnlyNameForFriendlyPlayerUnits`, le mode « nom seul ».

Le client se peint lui-même, avec ses pleins droits : l'identité secrète ne le
concerne pas — c'est *lui* qui la protège — et les plaques qu'il ne nous rend
pas, il les dessine quand même. Les trois CVars valent donc partout, donjon,
raid et arène compris, là où notre pinceau ne recevait ni la classe ni la frame.

**Ce qu'on fait** — les trois cases de la page écrivent ces CVars en direct,
comme le mode « nom seul » : le CVar est le rangement, rien n'est copié en base,
rien n'est emprunté, rien à rendre à l'extinction. La peinture manuelle est
retirée (`classRGB`, ses clés `pvpClassColor`/`allyBarClassColor`/
`allyClassColor`, et le palier 16 efface leurs traces). `T.SecretClassColor`
reste dans le thème : le mécanisme du passage de secret est correct et documenté,
il n'a simplement plus de client ici.

**La leçon** — avant de peindre à la place du client, chercher le réglage par
lequel il accepterait de peindre lui-même. Un CVar qu'il relit traverse tous les
murs qu'il nous oppose, précisément parce que c'est lui qui les tient : nos
droits s'arrêtent où les siens commencent, mais ses réglages sont à nous. La
peinture manuelle reste le recours quand aucun CVar n'existe — c'est le cas du
classement des PNJ par nature — jamais le premier choix.

---

## Un emote reçu n'a pas d'identifiant — mais sa phrase est déjà dans notre langue

**Ce qu'on cherchait** — répondre automatiquement à un `/kiss` qu'on nous
adresse, « quelle que soit la langue dans laquelle l'emote est fait ».

**Ce que le client donne** — `CHAT_MSG_TEXT_EMOTE` porte dix-huit arguments et
**aucun identifiant d'emote** : ni jeton, ni numéro. Le premier est la phrase
déjà rédigée, telle qu'elle s'affiche dans le chat, et c'est tout ce qu'on a.

**Ce qui sauve la mise** — la phrase est rédigée par le client **destinataire**,
dans sa langue. Le serveur n'envoie qu'un numéro d'emote et une cible
(`SMSG_TEXT_EMOTE`) ; chaque client va chercher la formule dans ses propres
données (`EmotesText` / `EmotesTextData`). **La langue de l'émetteur ne voyage
donc jamais.** L'exigence « quelle que soit la langue de l'autre » est tenue sans
rien écrire — c'est notre propre locale, et elle seule, qu'il faut reconnaître.

**Ce que le client ne donne pas** — les textes d'emote **ne sont pas dans
`GlobalStrings`**. Vérifié sur les deux locales du dépôt de tekkub : `EMOTE59_CMD1`
vaut `"/kiss"` en anglais et `"/embrasser"` en français, mais aucune entrée ne
contient « kisses » ni « embrasse » au sens d'une phrase d'emote. Elles vivent
dans les données du client, hors de portée du Lua.

Corollaire : `EMOTE<n>_CMD<m>` donne les **commandes** localisées, jamais les
**messages**. Les deux se ressemblent assez pour qu'on croie tenir la solution.

**Ce qu'on fait** — la formule reconnue est une **clé de locale**, comme toute
chaîne qui dépend de la langue. Fragment court (`"vous embrasse"`), cherché tel
quel et sans casse au milieu de la phrase : il survit au nom du joueur, au genre
du personnage et à la ponctuation. Une locale non fournie retombe sur l'anglais,
ne reconnaît rien, et le module se tait — la bonne dégradation, un emote parti de
travers se voyant par tout le monde.

**Deux pièges qui ne se voient qu'en jouant :**

- **le client nous renvoie nos propres emotes**, et en français « Vous embrassez
  Bob » contient « vous embrasse ». Sans garde, embrasser quelqu'un déclenchait
  un `/non` adressé à soi-même. Le garde se pose sur le **GUID** (argument 12),
  pas sur le nom : un nom porte parfois son royaume, un GUID jamais ;
- **le frein anti-spam qu'on avait écrit n'avait pas lieu d'être.** Une réponse
  toutes les trois secondes, au motif que le serveur ferait taire qui produit une
  rafale d'emotes. La limite était supposée, pas observée — rien n'indique que
  les emotes soient comptés. Elle est retirée : à supposer qu'une telle limite
  existe, c'est le serveur qui l'applique, il n'a besoin de personne pour cela.
  Ce que le frein coûtait, lui, se voyait — une réponse sur dix face à quelqu'un
  qui martèle sa touche, ce qui se lit comme un réglage qui décroche.

  La leçon n'est pas propre aux emotes : **une protection contre un risque
  supposé est du comportement en moins pour un bénéfice qu'on n'a pas mesuré.**
  Le doute se lève en jouant, pas en ajoutant un garde-fou.

**Pour jouer un emote, `DoEmote` et non `C_ChatInfo.PerformEmote`** — le plus
ancien des deux, et c'est délibéré : le récent ne prend que le jeton, donc
l'emote part sur notre cible du moment, c'est-à-dire sur n'importe qui sauf la
bonne personne. `DoEmote(token, cible)` prend une cible.

**Et cette cible est un nom, pas un jeton d'unité.** La documentation annonce un
`UnitToken` ; c'est pourtant un nom que le client se passe à lui-même quand on
tape `/non Joséebovin` — son analyseur appelle `DoEmote(jeton, reste_de_la_ligne)`.
Il le faut : celui qui nous fait un emote n'est presque jamais notre cible, donc
aucun jeton d'unité ne le désigne. Le nom de l'annonce part tel quel, royaume
compris.

Les jetons (`"NO"`, `"KISS"`) ne sont **pas** traduits — c'est le seul bout de la
chaîne qui vaille dans toutes les langues sans être écrit deux fois.

**Les formules relevées en jeu, et ce qu'elles apprennent** — la première version
pariait sur « vous embrasse » pour un `/kiss`. Le client écrit en réalité :

```
Joséebovin vous envoie un baiser
Joséebovin vous serre dans ses bras. Gros câlin !
```

Deux leçons, et la seconde vaut au-delà des emotes :

- **une formule est un relevé, jamais une déduction.** « Embrasser » est la
  traduction de *to kiss* et n'est pas ce que le client écrit. Le seul moyen de
  savoir est de lire ce qu'il produit — d'où `/bui emote`, qui écrit le texte
  brut de chaque emote reçu ;
- **on se cale sur le complément, pas sur le verbe.** Le câlin est reconnu à
  « dans ses bras ». Le verbe est la partie qui bouge — accord, tournure réécrite
  d'une extension à l'autre — et il ne suffit pas à distinguer : « vous serre la
  main » est la poignée de main, un tout autre emote. Le complément, lui, ne
  désigne que le câlin.

D'où plusieurs formules par emote, séparées par `;` dans la clé de locale : une
formule de trop ne coûte rien, une formule manquante rend le module muet.
