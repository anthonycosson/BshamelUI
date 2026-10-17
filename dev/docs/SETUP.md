# Installer le dépôt sur un nouvel ordinateur

De zéro jusqu'au premier `/reload` qui charge ton code. Compter une
vingtaine de minutes. Le chemin principal est Windows, la machine de
développement habituelle ; les différences pour macOS sont regroupées à la fin.

À la fin de ce guide :

- le dépôt est cloné depuis GitHub ;
- le jeu lit directement les fichiers du dépôt (pas de copie, pas de build) ;
- `bash dev/scripts/lint-local.sh` passe, ce qui veut dire que la CI passera.

---

## 1. Prérequis

| Outil | Pourquoi | Installation (Windows) |
|---|---|---|
| **World of Warcraft** retail | l'addon tourne dedans | Battle.net |
| **Git for Windows** | cloner, commiter, et **Git Bash** pour lancer les scripts `.sh` | `winget install Git.Git` |
| **Accès au dépôt** | il est privé | se faire inviter sur `anthonycosson/BshamelUI` |

Git for Windows installe aussi le *Git Credential Manager* : au premier `git
pull` ou `git push`, une fenêtre de connexion GitHub s'ouvre, et le jeton est
mémorisé ensuite. Aucun mot de passe à taper dans le terminal.

Toutes les commandes qui suivent se lancent dans **Git Bash**, sauf indication
contraire.

## 2. Cloner

Le chemin est libre. Celui-ci est celui que citent `CLAUDE.md` et les skills
Claude Code ; le garder évite d'avoir à adapter les commandes.

```bash
mkdir -p ~/Documents/Claude
git clone https://github.com/anthonycosson/BshamelUI.git ~/Documents/Claude/BshamelUI
cd ~/Documents/Claude/BshamelUI
```

Pour régler l'identité des commits de ce dépôt uniquement :

```bash
git config user.name "Bshamel"
git config user.email "ton-adresse@exemple.com"
```

## 3. Brancher le dépôt dans le jeu

Le dépôt **est** le dossier d'addon. On ne le copie pas dans `AddOns` : on y
pose une **jonction NTFS**, qui fait apparaître le même dossier à deux
endroits. Ensuite, chaque modification est visible en jeu après un simple
`/reload`.

Fermer le jeu, puis, **depuis une invite de commandes Windows (`cmd`) lancée en
administrateur** — `Program Files` l'exige :

```bat
mklink /J "C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\BshamelUI" "%USERPROFILE%\Documents\Claude\BshamelUI"
```

Depuis Git Bash, la même commande s'écrit `cmd //c mklink /J "…" "…"`, mais
Git Bash doit alors lui aussi avoir été lancé en administrateur.

Adapter le premier chemin si WoW est installé ailleurs. Le dossier `AddOns`
doit exister : lancer le jeu une fois suffit à le créer.

**Bêta de *Forever*** (facultatif) : poser une seconde jonction identique, en
remplaçant `_retail_` par `_classic_beta_`.

Vérifier :

```bat
dir /AL "C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns"
```

`BshamelUI` doit apparaître avec la mention `<JONCTION>`.

> ⚠️ **Ne jamais installer Bshamel UI depuis CurseForge sur cette machine.**
> L'application CurseForge remplace la jonction par un vrai dossier contenant
> la version publiée, et tes modifications locales cessent d'être chargées sans
> que rien ne le signale. Le README (§ 1) explique comment s'en apercevoir et
> réparer.

## 4. Premier lancement

1. Lancer le jeu. À l'écran des personnages → **AddOns** : `Bshamel UI` doit
   être listé et coché.
2. En jeu : `/bui` ouvre la fenêtre d'options, `/bui version` affiche la
   version chargée. Depuis un clone, elle affiche `dev` : seul le packager
   écrit le vrai numéro, au moment d'une release.
3. Recommandé : installer **BugSack** (qui embarque BugGrabber) depuis
   CurseForge. Il capture les erreurs Lua que le jeu masque par défaut. Ce
   n'est pas une dépendance de l'addon, seulement un outil de développement.

## 5. Outils de vérification

`lint-local.sh` enchaîne quatre passes. Chacune s'appuie sur un outil ; s'il
manque, la passe est **ignorée** avec un message, pas en échec. Lire la sortie
avant de croire un « tout va bien ».

### `luac5.1` — compilation avec le Lua du jeu

Le client WoW embarque **Lua 5.1**, dont certaines limites sont plus basses
que celles des versions récentes. Un `luac` moderne ne lève pas ces
erreurs-là : il faut celui de la 5.1.

Ni winget ni WSL ne le proposent sous Windows :

1. Télécharger `lua-5.1.5_Win64_bin.zip` chez
   [LuaBinaries](https://sourceforge.net/projects/luabinaries/files/5.1.5/Tools%20Executables/).
2. N'en extraire que **`luac5.1.exe`** — il est lié statiquement, les DLL de
   l'archive ne servent à rien.
3. Le poser dans `%USERPROFILE%\bin` (créer le dossier au besoin). Git Bash
   ajoute ce dossier au `PATH` automatiquement ; rouvrir Git Bash.

```bash
luac5.1 -v    # → Lua 5.1.5
```

### `lua-language-server` — diagnostics

Globals inconnus, variables mortes, types incohérents. C'est l'équivalent
local de `luacheck`, qui lui ne tourne qu'en CI (il exige un compilateur C sous
Windows).

```bat
winget install LuaLS.lua-language-server
```

Le script le trouve à l'emplacement d'installation de winget. Installé
ailleurs, le désigner avec la variable `LLS` :

```bash
export LLS="/chemin/vers/lua-language-server.exe"
```

### Éditeur (recommandé)

**VS Code** avec l'extension **Lua** de *sumneko* (`sumneko.lua`). Elle lit
`.luarc.json` à la racine : runtime 5.1, globales du client déjà déclarées.
Les mêmes diagnostics que `lint-local.sh` s'affichent alors pendant la frappe.

## 6. Vérifier que tout est en place

```bash
cd ~/Documents/Claude/BshamelUI
bash dev/scripts/lint-local.sh
```

Attendu : une coche `✓` sur chaque section, et **aucune** ligne
« introuvable, passe ignorée ». Si c'est le cas, une modification qui passe ici
passera dans la CI GitHub Actions.

Pour voir exactement ce qu'un joueur recevrait, sans rien envoyer nulle part :

```bash
bash dev/packager/release.sh -d -o -z -r "$PWD/dev/build" && find dev/build/BshamelUI -type f
```

## 7. Et maintenant

La boucle de travail : éditer → `/reload` en jeu → `lint-local.sh` → commit →
push. Le README (§ 3) la détaille, et la CI vérifie chaque push sur
<https://github.com/anthonycosson/BshamelUI/actions>.

Avant d'écrire la première ligne :

| À lire | Pour |
|---|---|
| [`CLAUDE.md`](../../CLAUDE.md) | les règles que la CI fait respecter, et leur raison |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | comment le code est découpé |
| [`DESIGN.md`](DESIGN.md) | ajouter une option ou un widget |
| [`CONTRIBUTING.md`](../CONTRIBUTING.md) | licence des contributions, checklist de pull request |

**Avec Claude Code** : ouvrir la session **depuis le dossier du dépôt**. C'est
ce qui charge `CLAUDE.md` et les skills `/buidev` et `/buiprod`, versionnés
dans `.claude/skills/`.

---

## Sur macOS

Les étapes sont les mêmes, à quatre différences près.

**Outils :**

```bash
brew install git lua@5.1 lua-language-server
```

`lua@5.1` fournit `luac5.1`. Si `lint-local.sh` ne trouve pas
`lua-language-server`, le désigner avec `export LLS=$(which lua-language-server)`.

**Brancher le dépôt dans le jeu :** un lien symbolique remplace la jonction
NTFS.

```bash
ln -s ~/Documents/Claude/BshamelUI "/Applications/World of Warcraft/_retail_/Interface/AddOns/BshamelUI"
ls -l "/Applications/World of Warcraft/_retail_/Interface/AddOns" | grep BshamelUI   # doit montrer la flèche ->
```

**Fichiers de diagnostic :** les chemins `WTF\…` et `Logs\…` du README se
trouvent sous `/Applications/World of Warcraft/_retail_/`.

**Scripts PowerShell :** `dev/scripts/*.ps1` (sonde, logo, textures) sont
écrits pour Windows. Ils ne servent pas au développement courant.
