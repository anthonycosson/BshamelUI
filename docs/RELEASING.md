# Publier une version

## Une seule fois : créer le projet CurseForge

L'API CurseForge sait ajouter un fichier à un projet, pas créer le projet.
Cette partie est donc manuelle et se fait une fois pour toutes.

1. Compte auteur sur <https://authors.curseforge.com>.
2. Créer un projet, jeu « World of Warcraft ». Il faut un nom, un résumé, une
   description, un logo **et un premier fichier** pour passer en modération.
3. Produire ce premier zip localement :
   ```bash
   bash .release/release.sh -d -o
   ```
   Le zip apparaît dans `.release/`. L'uploader à la main sur le projet.
4. Attendre la modération (de quelques minutes à trois jours ouvrés, 8 h – 15 h
   CET).
5. Une fois le projet approuvé, relever son **ID numérique** dans la colonne de
   droite de sa page, et le reporter dans `BshamelUI.toc` :
   ```
   ## X-Curse-Project-ID: 123456
   ```
6. Générer un jeton sur <https://authors.curseforge.com/account/api-tokens>.

## Une seule fois : configurer GitLab

Dans **Settings → CI/CD → Variables** :

| Variable | Valeur | Options |
|---|---|---|
| `CF_API_KEY` | le jeton CurseForge | *Masked* **et** *Protected* |

Dans **Settings → Repository → Protected tags**, protéger le motif `v*`.
C'est ce qui garantit que le jeton n'est jamais exposé à une pipeline de
branche ou de merge request.

## À chaque version

1. Mettre `CHANGELOG.md` à jour (déjà fait au fil des commits).
2. Taguer et pousser :
   ```bash
   git tag -a v0.1.0 -m "v0.1.0"
   ```
   ```bash
   git push origin v0.1.0
   ```
3. La pipeline `release` construit le zip et l'envoie sur CurseForge.

Il n'y a **jamais** de numéro de version à modifier à la main : le `.toc`
contient `@project-version@`, que le packager remplace par le tag.

## Vérifier avant de taguer

```bash
bash .release/release.sh -d -o
```

`-d` désactive tout envoi, `-o` garde le dossier décompressé à côté du zip.
Vérifier dans ce dossier que :

- `CLAUDE.md`, `docs/`, `scripts/`, `.gitlab-ci.yml` **ne sont pas** présents
  (règle `ignore` de `.pkgmeta`) ;
- `## Version:` a bien été substitué ;
- `license.txt` est présent.

## Mettre à jour le packager

`.release/release.sh` est vendu avec le dépôt, épinglé à une version connue —
pas récupéré depuis `master` à chaque build. Pour le mettre à jour :

```bash
curl -sL https://raw.githubusercontent.com/BigWigsMods/packager/v2.5.1/release.sh -o .release/release.sh
```

Lire le diff avant de commiter : ce script s'exécute avec le jeton CurseForge
dans son environnement.
