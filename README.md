# Bshamel UI

Suite d'améliorations d'interface pour World of Warcraft *retail*, faite maison :
un seul addon, un seul dossier, zéro dépendance.

- **Dépôt** — <https://gitlab.anthocsn.com/anthony/bshamelui>
- **CurseForge** — projet `1631877`
- **Jeu** — retail, `Interface: 120007` minimum

| Module | Catégorie | État |
|---|---|---|
| Quête — acceptation et rendu automatiques | QoL | fonctionnel |

---

# Comment ça marche, de A à Z

## 1. Où vit le code

Le dépôt **est** le dossier d'addon. Il n'y a pas de copie, pas de build à
lancer pour tester : le jeu lit directement les fichiers du dépôt, grâce à une
jonction NTFS posée une fois pour toutes.

```
C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\BshamelUI
        ↓ jonction NTFS (ce n'est pas une copie, c'est le même dossier)
C:\Users\Cosso\dev\BshamelUI
```

Conséquence pratique : **éditer un fichier, puis `/reload` en jeu.** C'est toute
la boucle de développement. Rien à compiler, rien à copier.

Pour recréer la jonction sur une autre machine :

```bash
cmd //c mklink /J "C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\BshamelUI" "C:\Users\<vous>\dev\BshamelUI"
```

## 2. Ce qui est publié, et ce qui ne l'est pas

C'est la question centrale, et la réponse tient dans une règle : **tout ce qui
ne part pas chez le joueur vit sous `dev/`.**

```
BshamelUI/
│
├── Core/            ┐
├── UI/              │
├── Modules/         ├── PUBLIÉ — le code de l'addon
├── Locales/         │
├── media/           │
├── BshamelUI.toc    │   le manifeste lu par le jeu
├── CHANGELOG.md     │   affiché sur la page CurseForge
├── license.txt      ┘
│
├── dev/             ┐
│   ├── docs/        │   documentation technique
│   ├── scripts/     ├── NON PUBLIÉ — outillage de développement
│   ├── packager/    │   l'outil qui fabrique le zip
│   └── build/       ┘   sorties de build (ignoré par git)
│
├── CLAUDE.md            NON PUBLIÉ — règles du dépôt
├── README.md            NON PUBLIÉ — ce fichier
└── .pkgmeta, .gitlab-ci.yml, .luacheckrc, .luarc.json, .editorconfig,
    .gitignore, .gitattributes
                         NON PUBLIÉ — configuration des outils
```

**Pourquoi `CLAUDE.md`, `README.md` et les fichiers en `.` restent à la racine :**
leurs outils les cherchent là et nulle part ailleurs. `.pkgmeta` doit être à la
racine du dépôt pour que le packager le trouve, `.gitlab-ci.yml` pour que GitLab
le lise, `.luarc.json` pour que l'analyseur Lua l'applique. Ils commencent tous
par un point, donc l'explorateur Windows les masque : la racine reste lisible.

**C'est `.pkgmeta` qui décide** de ce qui part. Sa section `ignore` liste ce qui
est exclu du zip. Comme tout l'outillage est regroupé sous `dev/`, une seule
ligne suffit à l'exclure — c'est précisément l'intérêt du rangement.

En cas de doute sur ce que reçoit un joueur, une commande le montre :

```bash
bash dev/packager/release.sh -d -o -z -r "$PWD/dev/build" && find dev/build/BshamelUI -type f
```

`-d` désactive tout envoi, `-o` garde le dossier décompressé, `-z` saute la
compression. Rien ne sort de la machine.

## 3. Le cycle de développement

```
  éditer un fichier
        ↓
  /reload en jeu                     ← boucle courte, aucune étape intermédiaire
        ↓
  bash dev/scripts/lint-local.sh     ← avant de commiter
        ↓
  git commit && git push
        ↓
  GitLab lance le job « lint »       ← ~12 s
```

Le job `lint` tourne à **chaque** push, sur une branche comme sur un tag. Il
fait deux choses :

- **`luacheck`** — erreurs de syntaxe, variables mortes, globals non déclarés.
- **`dev/scripts/check-design.sh`** — les règles de `CLAUDE.md` qui sont
  vérifiables mécaniquement : pas de `CreateFrame` hors de la fabrique de
  widgets, pas de couleur ni de police en dur hors du thème, pas de nom de
  template Blizzard en dur, pas de global non préfixé, parité des clés de
  traduction `enUS` / `frFR`.

Un avertissement suffit à faire échouer le job. C'est volontaire : sans ça, les
avertissements s'accumulent jusqu'à devenir du bruit qu'on ignore.

## 4. La publication sur CurseForge

Une seule commande déclenche toute la chaîne :

```bash
bash dev/scripts/tag-release.sh 0.2.0 --push
```

Voici ce qu'elle enchaîne, et ce qui se passe ensuite côté GitLab :

```
  dev/scripts/tag-release.sh 0.2.0
        │
        ├─ refuse si l'arbre de travail est sale
        ├─ refuse si le tag existe déjà
        ├─ lance lint-local.sh (syntaxe + diagnostics + garde-fous)
        ├─ date la section « Non publié » du CHANGELOG en « 0.2.0 — <date> »
        ├─ commite et crée le tag v0.2.0
        └─ pousse (uniquement avec --push)
                │
                ↓
  GitLab : pipeline sur le tag v0.2.0
        │
        ├─ job « lint »      ← les mêmes vérifications, sur le code taggé
        │
        └─ job « release »   ← ne tourne QUE sur un tag vX.Y.Z
              │
              ├─ dev/packager/release.sh (BigWigs packager)
              │     ├─ copie les fichiers en excluant tout ce que .pkgmeta ignore
              │     ├─ remplace « @project-version@ » du .toc par « v0.2.0 »
              │     ├─ extrait les notes de version du CHANGELOG
              │     └─ crée BshamelUI-v0.2.0.zip
              │
              ├─ envoie le zip à CurseForge (projet 1631877) via son API
              └─ conserve le zip en artefact GitLab pendant 30 jours
                    │
                    ↓
              modération CurseForge (quelques minutes à 3 jours ouvrés)
                    │
                    ↓
              fichier téléchargeable par les joueurs
```

**Le numéro de version ne s'écrit jamais à la main.** Le `.toc` contient
`## Version: @project-version@`, que le packager remplace par le nom du tag. Un
tag = une version, il ne peut pas y avoir de désaccord entre les deux.

**Le push n'est pas automatique par défaut.** Sans `--push`, le script s'arrête
après avoir créé le tag et affiche à la fois la commande pour publier et celle
pour tout annuler. Pousser un tag publie pour de vrai, devant tout le monde, et
un fichier CurseForge ne se retire pas proprement — le geste mérite d'être
conscient.

## 5. Les secrets

Un seul secret est en jeu : le jeton de l'API CurseForge.

Il vit dans **GitLab → Settings → CI/CD → Variables**, sous le nom `CF_API_KEY`,
avec deux cases cochées qui doivent l'être **ensemble** :

- **Masquée** — le jeton n'apparaît jamais dans les logs de job.
- **Protégée** — le jeton n'est exposé qu'aux branches et tags *protégés*.

Le motif de tags `v*` est protégé dans **Settings → Repository → Protected
tags**. C'est ce qui fait le lien : sans cette protection, le job `release` ne
verrait pas `CF_API_KEY` et publierait dans le vide.

Le jeton n'est écrit nulle part dans le dépôt, et le job qui l'utilise ne tourne
que sur un tag — jamais sur une branche, jamais sur une merge request.

## 6. Où se trouve quoi

| Je veux… | Fichier |
|---|---|
| Comprendre l'architecture du code | [dev/docs/ARCHITECTURE.md](dev/docs/ARCHITECTURE.md) |
| Ajouter une option ou un widget | [dev/docs/DESIGN.md](dev/docs/DESIGN.md) |
| Savoir pourquoi un truc bizarre est écrit ainsi | [dev/docs/API_NOTES.md](dev/docs/API_NOTES.md) |
| Publier une version | [dev/docs/RELEASING.md](dev/docs/RELEASING.md) |
| Modifier la page CurseForge | [dev/docs/CURSEFORGE.md](dev/docs/CURSEFORGE.md) |
| Connaître les règles du dépôt | [CLAUDE.md](CLAUDE.md) |
| Contribuer | [dev/CONTRIBUTING.md](dev/CONTRIBUTING.md) |

## 7. Commandes utiles

```bash
bash dev/scripts/lint-local.sh
```

Vérification complète en local : syntaxe (`luac`), diagnostics
(`lua-language-server`), garde-fous de design. À lancer avant chaque commit.

```bash
bash dev/scripts/check-design.sh
```

Uniquement les garde-fous de design, instantané.

```bash
bash dev/packager/release.sh -d -o -z -r "$PWD/dev/build"
```

Fabrique le paquet sans rien envoyer, pour inspecter ce qui partirait.

```bash
bash dev/scripts/tag-release.sh 0.2.0
```

Prépare une version sans la publier. Ajouter `--push` pour publier.

## 8. En jeu

- `/bui` ou `/bshamelui` — ouvre la fenêtre d'options
- `/bui version` — affiche la version chargée
- L'icône du compartiment d'addons, près de la minicarte, ouvre la même fenêtre

Pour diagnostiquer un problème :

| Quoi | Où |
|---|---|
| Erreurs Lua | `_retail_\WTF\Account\<compte>\SavedVariables\!BugGrabber.lua` (BugSack) |
| Réglages enregistrés | `_retail_\WTF\Account\<compte>\SavedVariables\BshamelUI.lua` |
| Taint | `_retail_\Logs\taint.log`, après `/console taintLog 1` |
| Captures d'écran | `_retail_\Screenshots\` |

## Licence

Tous droits réservés — voir [license.txt](license.txt).

Bshamel UI est un addon non officiel. Il n'est ni créé, ni affilié, ni soutenu
par Blizzard Entertainment, Inc.
