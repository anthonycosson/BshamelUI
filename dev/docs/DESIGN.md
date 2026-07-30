# Design system

## Principe

On n'invente pas une direction artistique, on emprunte celle du client. Les
polices sont les objets de police de Blizzard, les couleurs sont ses couleurs
globales, les cadres sont ses templates XML. Une seule couleur nous appartient,
l'accent `#00AEEF` — et elle vit dans le nom de l'addon, pas dans le chrome de
la fenêtre, où elle jurerait avec le doré ambiant de l'interface du jeu.

La conséquence est le vrai bénéfice : quand Blizzard retouche son interface à un
patch, l'addon suit sans qu'on écrive une ligne.

## Tokens — `UI/Theme.lua`

| Groupe | Contenu |
|---|---|
| `T.SIZE` | géométrie : tailles de fenêtre, marges, hauteurs de ligne, `CONTROL_X` |
| `T.FONT` | noms d'objets de police du client |
| `T.COLOR` | couleurs du client + `ACCENT` |
| `T.ALPHA` | opacités : fonds, survol, sélection, filets, contrôles grisés |
| `T.ATLAS` / `T.TEXTURE` | atlas et chemins de texture |
| `T.TEMPLATES` | candidats de templates XML par usage |

`T.SIZE.CONTROL_X` mérite une mention : c'est l'abscisse à laquelle tous les
contrôles se posent dans une ligne. C'est ce nombre, et lui seul, qui fait que
les cases à cocher sont alignées d'une page à l'autre.

`T.ALPHA` mérite la sienne : les transparences se règlent les unes par rapport
aux autres — le fond de la fenêtre, le creux de la navigation, le survol et la
sélection d'une entrée forment une échelle. Éparpillées dans les widgets, elles
dérivent ; réunies ici, elles se comparent d'un coup d'œil.

## Hiérarchie des surfaces

Une seule teinte de fond dans toute la fenêtre :

1. **La fenêtre**, fond sombre et translucide — le jeu reste visible derrière, la
   bordure du cadre reste pleine. `W.EdgeShade` assombrit en plus les quatre
   bords en dégradé, comme le panneau Options du client.

   Deux réglages distincts, et les confondre est le piège :
   `T.COLOR.WINDOW` décide de la **clarté** du fond, `T.ALPHA.WINDOW_BG` de sa
   **transparence**. Le fond du template est une pierre claire : monter son alpha
   ne fait qu'affirmer cette clarté. Pour une fenêtre sombre, c'est la couleur
   qu'on baisse.

   Et on **teinte** la texture (`T.SetPanelFill`), on ne pose pas un voile
   par-dessus : l'ordre des calques appartient au template du client. Un voile
   posé sur le calque `BORDER` disparaît sans bruit le jour où le template
   dessine son fond plus haut.
2. **La colonne de navigation** pose sa bordure de panneau creusé (`W.Inset`)
   mais **pas de fond** : `T.ClearPanelBackground` le coupe. Un fond de panneau,
   si pâle soit-il, s'ajoute à celui de la fenêtre et rend la zone encadrée plus
   claire que le reste — deux surfaces là où l'on n'en veut qu'une.

   Le coupage vise deux endroits, pas un : les textures propres au panneau
   **et** la pièce centrale de son nine-slice, qui est un enfant du cadre et non
   une région du panneau. Baisser l'alpha des seules régions ne suffit pas, et
   c'est exactement le piège dans lequel la première version est tombée.
3. **La zone de contenu**, sans encadrement. Son seul délimiteur est le filet
   sous le titre de page.

Encadrer les deux zones les ferait se disputer le regard : la bordure désigne la
navigation, le titre désigne le contenu.

## Couleurs de texte

Le partage est celui du panneau Options du client :

| Doré (`T.COLOR.NORMAL`) | Blanc (`T.COLOR.LABEL`) |
|---|---|
| entrées de module **au repos** | titre de la page |
| en-têtes de section (`AUTOMATISATION`) et leur filet | en-têtes de catégorie, sur bandeau **gris** |
| | entrée de module **sélectionnée** |
| | libellés des options |

**Aucune surface n'est dorée** : le doré est une couleur de texte. Une teinte
franche derrière du texte se lit comme un surlignage au marqueur, pas comme un
état.

Trois fonds dans la colonne, tous neutres :

- **Le bandeau d'en-tête de catégorie**, permanent, mais c'est un décor et non
  un état. Il porte la texture de la barre de titre de la fenêtre (voir plus
  bas).
- **Le dégradé de survol** (`W.CenterGlow`, `T.ALPHA.ROW_HOVER`).
- **Le dégradé de sélection** (`T.ALPHA.ROW_SELECTED`), le même en plus marqué,
  doublé du passage du libellé au blanc.

Les deux dégradés sont blancs, forts au centre, estompés aux deux bouts. Hors
survol et hors sélection, une entrée ne porte **aucune texture de fond**.

### Masquer, pas rendre transparent

Un bandeau au repos est `Hide()`, jamais `SetAlpha(0)`. Une texture dégradée
porte son opacité dans ses couleurs de sommet (`SetGradient`) et l'alpha d'objet
vient s'empiler par-dessus : faire dépendre l'invisibilité de cette combinaison,
c'est accepter qu'un voile filtre en permanence si l'une des deux ne se comporte
pas comme prévu. Sur un fond de fenêtre presque noir, un tel résidu se voit
immédiatement — et il se voit sur *toutes* les entrées à la fois, ce qui le fait
passer pour un fond de panneau plutôt que pour ce qu'il est.

Les dégradés ne sont créés que sur les entrées de module. Un en-tête de
catégorie ne porte que son bandeau : s'il grisaille un jour, il n'y a qu'un seul
suspect.

## La barre de titre se relève, elle ne se nomme pas

Les en-têtes de catégorie portent la **même texture que la barre de titre de la
fenêtre** : un intitulé sur une plaque, deux fois la même chose.

Cette texture n'est écrite nulle part. `T.CaptureTitleBar` la relève sur le cadre
au moment où il est construit, en sondant les clés sous lesquelles les templates
du client publient le fond de leur barre de titre (`TitleBg`, `TopTileStreaks`…),
et `T.ApplyTitleBar` la recopie.

Nommer un atlas ou un fichier serait un pari sur la structure interne d'un
template — celle-là même qui change d'une extension à l'autre. Copier ce que le
template a réellement posé reste juste quel que soit le template retenu par
`T.Template("WINDOW")`, et quel que soit le patch. À défaut, repli sur la pierre
`T.TEXTURE.SIDEBAR_BAND`, désaturée **puis** multipliée par `T.COLOR.BAND` —
désaturer d'abord n'est pas facultatif, la multiplication seule conserve la
teinte.

Les bandeaux ont des **angles droits**. Les arrondir a été tenté et abandonné —
voir `dev/docs/API_NOTES.md`, « Un masque posé sur une texture répétée est ignoré
en silence ». Ne pas y revenir sans lire cette note d'abord.

Le doré structure, le blanc se lit. Une entrée sélectionnée passe donc du doré
au blanc sur un bandeau doré : elle ressort de ses voisines sans introduire de
troisième couleur.

## Polices : candidats, comme les templates

`GameFontHighlightMedium`, `GameFontHighlightLarge2` et consorts sont récents et
ne sont garantis par aucun contrat. Une police inconnue passée à
`CreateFontString` ne dégrade pas, elle **lève une erreur** — d'où la même
mécanique que pour les templates : une liste de candidats par ordre de
préférence, résolue une fois au chargement de `UI/Theme.lua`, avec repli sur la
variante de base.

## Templates : candidats, pas noms en dur

Un template XML peut disparaître ou changer de nom entre deux extensions.
`T.TEMPLATES` déclare donc une liste de candidats par ordre de préférence, et
`T.Template(kind)` renvoie le premier que le client connaît réellement
(`C_XMLUtil.GetTemplateInfo`).

```lua
BUTTON = { "UIPanelButtonTemplate" },
WINDOW = { "BasicFrameTemplate", "BasicFrameTemplateWithInset", "UIPanelDialogTemplate" },
```

Aucun autre fichier ne doit contenir une chaîne finissant par `Template`.

## Widgets disponibles — `UI/Widgets/`

| Fonction | Rendu |
|---|---|
| `W.Window(name, title, w, h)` | fenêtre déplaçable et redimensionnable |
| `W.Container(parent)` | frame nue, sans habillage |
| `W.Inset(parent)` | panneau creusé, fond translucide |
| `W.Rule(parent, couleur, alpha)` | filet de séparation horizontal |
| `W.VerticalDivider(parent)` | séparateur vertical texturé, estompé aux deux bouts |
| `W.EdgeShade(frame)` | voile sombre aux quatre bords, dégradé vers l'intérieur |
| `W.CenterGlow(parent, couleur, alpha)` | bandeau fort au centre, éteint aux bords |
| `W.PageTitle(parent)` | titre de page en grand, souligné d'un filet |
| `W.SectionHeader(parent, texte)` | en-tête de section, majuscules + accent |
| `W.Description(parent, texte, largeur)` | paragraphe explicatif |
| `W.Row(parent, libellé)` | ligne libellé + colonne de contrôle |
| `W.Toggle(parent, opts)` | ligne + case à cocher |
| `W.Slider(parent, opts)` | ligne + glissière + valeur |
| `W.Dropdown(parent, opts)` | ligne + menu déroulant |
| `W.Button(parent, texte, onClick)` | bouton d'action |
| `W.SidebarItem(parent, texte, indenté)` | entrée de navigation |
| `W.ScrollPane(parent, masquerBarre)` | zone défilante, curseur proportionnel |
| `W.Tooltip(frame, titre, texte)` | infobulle |
| `W.Confirm(message, onAccept)` | dialogue de confirmation |

Ajouter un widget, c'est ajouter un fichier dans `UI/Widgets/`, une ligne dans
`BshamelUI.toc`, une entrée ici, et le brancher dans `PageBuilder.lua`.

## Page canonique

Une page se déclare, elle ne se dessine pas :

```lua
options = {
    { type = "header", text = L["Automation"] },
    {
        type    = "toggle",
        key     = "autoAccept",
        text    = L["Auto-accept quests"],
        tooltip = L["Auto-accept quests tip"],
    },
    {
        type     = "dropdown",
        key      = "bypassModifier",
        text     = L["Bypass modifier"],
        values   = { { value = "SHIFT", label = L["Shift"] } },
        disabled = function() return not mod:Get("autoAccept") end,
    },
},
```

**Pas d'interrupteur de module en tête de page.** Chaque réglage est éteint par
défaut : allumer celui qu'on veut suffit, et un interrupteur au-dessus
n'ajouterait qu'une case à cocher de plus à cocher pour rien. La clé `enabled`
existe toujours côté core — c'est elle qui permet de différer l'activation d'un
module sécurisé hors combat — elle n'a simplement plus de contrôle en face.

## Ascenseurs

Un ascenseur est **dépouillé** : ni boutons de fin, ni fond de piste, ni cadre.
Il ne reste qu'un curseur texturé, dont la hauteur vaut la part visible de la
page. Les deux flèches ne servent qu'à défiler d'un cran, ce que la molette fait
mieux.

Et il **disparaît quand tout tient sur une page** : une barre qui ne sert à rien
est une barre qui ment. La colonne de navigation n'en a aucun du tout, sa liste
étant courte — la molette y suffit.

## Règles de grille

- Une ligne fait `T.SIZE.ROW_H` de haut, séparée de la suivante par `ROW_GAP`.
- Un en-tête de section est précédé de `SECTION_GAP` (sauf en tête de page).
- Le libellé occupe de `LABEL_INDENT` à `CONTROL_X`, sans retour à la ligne.
- Le contrôle commence exactement à `CONTROL_X`.
- Un contrôle inactif est **grisé, pas caché** : l'infobulle explique pourquoi.
  Un contrôle qui disparaît laisse l'utilisateur croire à un bug.

## Ce qui reste à faire

- Chrome de fenêtre en nine-slice (`NineSliceUtil.ApplyLayoutByName`) plutôt que
  `BasicFrameTemplate`, une fois la source du client consultée.
- Recherche globale dans les options.
- Sélecteur de couleur, champ de saisie, liste réordonnable.
