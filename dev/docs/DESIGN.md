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

1. **La fenêtre**, fond translucide (`T.ALPHA.WINDOW_BG`) — le jeu reste visible
   derrière, la bordure du cadre reste pleine. Un voile sombre en dégradé
   (`W.EdgeShade`) assombrit les quatre bords vers l'intérieur, comme le panneau
   Options du client.
2. **La colonne de navigation** pose sa bordure de panneau creusé (`W.Inset`)
   mais **pas de fond** : `T.ALPHA.PANEL_BG` vaut zéro, exprès. Un second voile
   empilé sur celui de la fenêtre rendrait la colonne plus sombre que la zone de
   contenu, alors que les deux doivent se lire sur exactement la même teinte.
3. **La zone de contenu**, sans encadrement. Son seul délimiteur est le filet
   sous le titre de page.

Encadrer les deux zones les ferait se disputer le regard : la bordure désigne la
navigation, le titre désigne le contenu.

## Couleurs de texte

Le partage est celui du panneau Options du client :

| Doré (`T.COLOR.NORMAL`) | Blanc (`T.COLOR.LABEL`) |
|---|---|
| en-têtes de catégorie de la colonne | titre de la page |
| entrées de module **au repos** | entrée de module **sélectionnée** |
| en-têtes de section (`AUTOMATISATION`) et leur filet | libellés des options |

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
| `W.EdgeShade(frame)` | voile sombre aux quatre bords, dégradé vers l'intérieur |
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

`PageBuilder` ajoute lui-même, en tête de chaque page, l'interrupteur du module.
Toutes les pages ont donc la même première ligne au même endroit.

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
