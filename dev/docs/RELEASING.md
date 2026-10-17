# Publier une version

Projet CurseForge : **1631877**
<https://authors.curseforge.com/#/projects/1631877/general>

## Une seule fois : créer le projet CurseForge

> Déjà fait — cette section est conservée pour mémoire, et pour le jour où un
> second projet sera créé.

L'API CurseForge sait ajouter un fichier à un projet, pas créer le projet.
Cette partie est donc manuelle et se fait une fois pour toutes.

1. Compte auteur sur <https://authors.curseforge.com>.
2. Créer un projet, jeu « World of Warcraft ». Il faut un nom, un résumé, une
   description, un logo **et un premier fichier** pour passer en modération.
3. Produire ce premier zip localement :
   ```bash
   bash dev/packager/release.sh -d -o -r "$PWD/dev/build"
   ```
   Le zip apparaît dans `dev/build/`. L'uploader à la main sur le projet.
4. Attendre la modération (de quelques minutes à trois jours ouvrés, 8 h – 15 h
   CET).
5. Une fois le projet approuvé, relever son **ID numérique** (il est dans l'URL
   du tableau de bord auteur) et le reporter dans `BshamelUI.toc` :
   ```
   ## X-Curse-Project-ID: 1631877
   ```
   C'est cette ligne, et elle seule, qui dit au packager où envoyer le fichier.
6. Générer un jeton sur <https://authors.curseforge.com/account/api-tokens>.

## Une seule fois : configurer GitHub

Dans **Settings → Secrets and variables → Actions → New repository secret** :

| Secret | Valeur |
|---|---|
| `CF_API_KEY` | le jeton CurseForge |

Le workflow `.github/workflows/ci.yml` ne passe ce secret qu'au job `release`,
qui ne tourne que sur un tag `vX.Y.Z`. Le `GITHUB_TOKEN` utilisé pour créer la
release GitHub est fourni automatiquement.

Facultatif : **Settings → Rules → Rulesets → New tag ruleset**, cible `v*`,
règles *Restrict deletions* et *Block force pushes* — l'équivalent des tags
protégés de l'ancien GitLab.

## À chaque version

Écrire ce qui a changé sous `## Non publié` dans `CHANGELOG.md` au fil des
commits, puis :

```bash
bash dev/scripts/tag-release.sh 0.2.0
```

Le script vérifie que l'arbre est propre, lance le lint et les garde-fous,
date la section du CHANGELOG, commite, tague, et affiche un aperçu du paquet.
**Il ne pousse rien** : pousser un tag publie pour de vrai sur CurseForge, ce
qui mérite un geste explicite. Quand tu es sûr :

```bash
git push origin HEAD && git push origin v0.2.0
```

Ou en une fois, si tu n'as pas besoin de relire l'aperçu :

```bash
bash dev/scripts/tag-release.sh 0.2.0 --push
```

Le job `release` du workflow GitHub Actions prend le relais : il construit le
zip, l'envoie sur le projet 1631877 et crée la release GitHub du tag.

Il n'y a **jamais** de numéro de version à modifier à la main : le `.toc`
contient `@project-version@`, que le packager remplace par le tag.

## Vérifier avant de taguer

```bash
bash dev/packager/release.sh -d -o -r "$PWD/dev/build"
```

`-d` désactive tout envoi, `-o` garde le dossier décompressé à côté du zip.
Vérifier dans ce dossier que :

- `CLAUDE.md`, `docs/`, `scripts/`, `.github/` **ne sont pas** présents
  (règle `ignore` de `.pkgmeta`) ;
- `## Version:` a bien été substitué ;
- `license.txt` est présent.

## Mettre à jour le packager

`dev/packager/release.sh` est vendu avec le dépôt, épinglé à une version connue —
pas récupéré depuis `master` à chaque build. Pour le mettre à jour :

```bash
curl -sL https://raw.githubusercontent.com/BigWigsMods/packager/v2.5.1/release.sh -o dev/packager/release.sh
```

Lire le diff avant de commiter : ce script s'exécute avec le jeton CurseForge
dans son environnement.
