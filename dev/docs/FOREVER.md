# Porter Bshamel UI sur *World of Warcraft: Forever*

*World of Warcraft: Forever* — le « Classic+ » annoncé le 12 septembre 2026,
bêta le 17 septembre, sortie le 4 novembre — est un **client séparé**, sur une
base vanilla, plafonné au niveau 60. Ce n'est pas un patch de retail : son API
a une dizaine d'années d'écart avec la nôtre.

Cette note dit ce qui est décidé, ce qui ne l'est pas, et l'outil qui tranche.

---

## Un seul addon, plusieurs `.toc`

Pas de second dépôt, pas de second projet CurseForge.

La moitié du code — `Core/`, `UI/Theme.lua`, `UI/Widgets/`, `UI/Config/`,
`Locales/` — ne touche pas au jeu : c'est un système de design, une base de
réglages et une fabrique de widgets. Le dupliquer, c'est se condamner à
corriger chaque bug deux fois.

Le mécanisme existe déjà de bout en bout :

| Maillon | Ce qu'il sait faire |
|---|---|
| Le client | cherche `BshamelUI_<Flavor>.toc`, puis `BshamelUI.toc` |
| `dev/packager/release.sh` | reconnaît le suffixe et construit un zip par flavor |
| CurseForge | un projet, des fichiers étiquetés par version de jeu |
| WTF | arborescences séparées : `BshamelUIDB` garde son nom, sans collision |

À terme :

```
BshamelUI_Mainline.toc   ## Interface: 120007, 120100   liste actuelle
BshamelUI_<Forever>.toc  ## Interface: ?????            socle + modules portables
```

Le suffixe exact reste à confirmer : le motif de `release.sh` ne connaît pas
encore Forever, il faudra resynchroniser le packager depuis l'amont BigWigs.

## La règle, le jour où le second `.toc` existe

À ajouter à `CLAUDE.md` §1 à ce moment-là, pas avant :

> **Le flavor se choisit dans le `.toc`, jamais dans un `if`.**
> Un fichier listé dans les deux TOC ne peut tester que des capacités
> (`if C_Foo and C_Foo.Bar then`). Un module qui n'a pas de sens sur un flavor
> n'est pas gardé par une condition : il n'est pas dans ce `.toc`.

`check-design.sh` refuse déjà `WOW_PROJECT_ID` et `GetBuildInfo()` : le
garde-fou est en place, il n'y a rien à écrire.

La frontière se pose sur l'arborescence existante, sans la bouger :
`Core/`, `UI/` et `Locales/` doivent compiler sur les deux ; `Modules/` se
répartit une ligne de `.toc` à la fois.

`T.Template()` fait déjà le bon travail côté `UI/` — les templates de base
existent partout, et ceux qui manquent dégradent proprement.

---

## La sonde : ce qui remplace les suppositions

Deviner quelle API survit est un exercice qui se trompe. La sonde mesure.

`dev/probe/BshamelUI_Probe/` est un addon autonome qui pose au client toutes
les demandes du dépôt — fonctions, globales, cadres nommés, événements, CVars,
templates, atlas — et rend un score **par fichier** : `Modules/Quest.lua — 100 %`
veut dire que ce module est portable tel quel.

La liste n'est pas écrite à la main : `dev/scripts/make-probe.sh` l'extrait du
dépôt. La relancer après chaque modification du code.

### Le parcours, dans cet ordre

```bash
# 1. Engendrer la liste depuis le dépôt
bash dev/scripts/make-probe.sh
```

```powershell
# 2. Poser sur RETAIL — le client de référence, celui qui tient tout
powershell -File dev/scripts/install-probe.ps1 -Client "C:\Program Files (x86)\World of Warcraft\_retail_"
# se connecter, /reload
powershell -File dev/scripts/install-probe.ps1 -Client "C:\Program Files (x86)\World of Warcraft\_retail_" -Collecter
```

```bash
# 3. Étalonner : ce qui manque sur retail ne renseigne pas sur Forever
bash dev/scripts/make-probe.sh --calibrer "<chemin rendu à l'étape 2>"
```

```powershell
# 4. Poser sur la bêta Forever, et lire le verdict
powershell -File dev/scripts/install-probe.ps1 -Client "<...\_beta_>" -Interface <numéro>
```

En jeu : le résumé s'affiche à la connexion, `/buiprobe` le redonne,
`/buiprobe tout` déplie tout, `/buiprobe quest` liste ce qui manque à un
fichier. Le fichier de WTF reste la sortie de référence.

### Pourquoi l'étalonnage n'est pas facultatif

Les demandes les plus fragiles de l'addon sont des **cadres nommés par une
chaîne** — `local VIEWER = "BuffIconCooldownViewer"`, puis `_G[VIEWER]`.
`luacheck` ne les voit pas : ce ne sont pas des identifiants. Le générateur les
repère à la forme de leur nom, ce qui ramène forcément des noms de méthodes et
de scripts (`SetPoint`, `OnUpdate`) qui ne sont pas des globales.

Confronter la liste à retail les élimine tous d'un coup, sans liste écrite à la
main : ce que retail ne tient pas est soit un faux positif, soit du code déjà
mort. Les noms écartés sont consignés dans `dev/probe/absent-du-retail.txt`,
pour que l'exclusion reste relisible.

Non étalonnée, la sonde le dit en toutes lettres et ses scores sont trop bas.

---

## Ce qu'on sait déjà sans sonder

Une partie des modules n'a pas d'équivalent sur un client vanilla : il n'y a
rien à porter, il n'y a pas de sujet — Keystones, MythicTimer, CooldownManager,
Teleports, GroupFinder. D'autres visent des cadres et des CVars qui existent
sous un autre nom : c'est une réécriture, pas un portage.

Le noyau portable réaliste tourne autour de dix modules sur vingt-cinq. C'est
une première version Forever honnête, et surtout le **même addon**.

La sonde est là pour remplacer ce paragraphe par des chiffres.
