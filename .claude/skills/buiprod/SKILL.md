---
name: buiprod
description: Publie une nouvelle version de l'addon Bshamel UI sur CurseForge, via un tag GitLab. À utiliser quand l'utilisateur dit "/buiprod", "publie", "envoie sur curseforge", "mets en prod", "sors une version", "fais une release", ou nomme un numéro de version à sortir. Couvre le choix du numéro de version, les vérifications, la création du tag, la confirmation avant publication, puis le suivi de la pipeline et du job release jusqu'à l'envoi effectif. Publication publique et irréversible — exige une confirmation explicite de l'utilisateur avant de pousser le tag.
---

# Bshamel UI — publier une version sur CurseForge

Objectif : transformer l'état actuel de `main` en une version téléchargeable par
les joueurs.

| | |
|---|---|
| Dépôt local | `C:\Users\Cosso\Documents\Claude\BshamelUI` |
| Projet CurseForge | `1631877` |
| Déclencheur réel | l'arrivée d'un tag `vX.Y.Z` sur GitLab |

## La règle qui ne bouge pas

**Ne jamais pousser le tag sans une confirmation explicite de l'utilisateur,
dans le tour de conversation en cours.**

Publier envoie un fichier visible par tout le monde, qui passe en modération
puis atterrit chez les joueurs. Un fichier CurseForge ne se retire pas
proprement : la seule correction est de publier la version suivante. Une
autorisation donnée pour une release précédente ne vaut pas pour celle-ci.

## Déroulé

### 1. Le verrou qui compte : est-ce testé en jeu ?

Avant tout le reste, demander si les modifications ont été essayées en jeu.

La CI ne lance jamais World of Warcraft. Elle valide la syntaxe, les variables,
les règles de design et les traductions — **jamais le comportement**. Un addon
peut avoir une pipeline verte et planter au premier `/reload`.

Si l'utilisateur n'a pas testé, le dire franchement et proposer d'attendre. S'il
confirme malgré tout vouloir publier, poursuivre : c'est sa décision.

### 2. Vérifier l'état de départ

```bash
cd "C:/Users/Cosso/Documents/Claude/BshamelUI" && git status --short && git log --oneline -3 && git log --oneline -1 origin/main
```

Exigences :

- arbre de travail propre — sinon utiliser d'abord le skill `buidev` ;
- `main` local et distant au même commit ;
- la dernière pipeline sur `main` est verte.

### 3. Choisir le numéro de version

Lire ce qui figure sous `## Non publié` dans `CHANGELOG.md`, et proposer un
numéro d'après le contenu réel :

| Contenu | Incrément |
|---|---|
| Corrections, ajustements internes | patch — `0.1.2` → `0.1.3` |
| Nouveau module, nouvelles options | mineur — `0.1.3` → `0.2.0` |
| Réglages existants cassés ou migrés | majeur — `0.2.0` → `1.0.0` |

Proposer le numéro, laisser l'utilisateur trancher. Si la section `## Non
publié` est vide, il n'y a rien à publier : le signaler.

**Ne jamais écrire un numéro de version à la main dans le `.toc`.** Il contient
`@project-version@`, que le packager remplace par le nom du tag.

### 4. Préparer, sans publier

```bash
cd "C:/Users/Cosso/Documents/Claude/BshamelUI" && bash dev/scripts/tag-release.sh 0.2.0
```

**Sans `--push`.** Le script vérifie l'arbre, lance le lint complet, date la
section du CHANGELOG, commite, crée le tag, et affiche un aperçu du paquet.

S'il échoue, rien n'a été publié : corriger et recommencer. Il affiche lui-même
la commande d'annulation.

### 5. Montrer et demander

Reprendre l'aperçu affiché par le script — les lignes `Interface`, `Author`,
`Version`, `X-Curse-Project-ID` et le nombre de fichiers — puis **demander
explicitement l'autorisation de publier**.

### 6. Publier

Uniquement après un oui clair :

```bash
cd "C:/Users/Cosso/Documents/Claude/BshamelUI" && git push origin HEAD && git push origin v0.2.0
```

### 7. Suivre la pipeline jusqu'au bout

Sur `https://gitlab.anthocsn.com/anthony/bshamelui/-/pipelines`, la pipeline du
tag contient **deux** jobs : `lint` puis `release`.

Ne pas s'arrêter à « pipeline verte ». Ouvrir le log du job `release` et
chercher la ligne :

```
Uploading BshamelUI-v0.2.0.zip (…) to https://wow.curseforge.com/projects/1631877
Success!
```

Sans cette ligne, **rien n'est parti**, même si le zip a été construit.

### 8. Rapporter

- La ligne d'envoi et son résultat.
- Le fichier passe en modération CurseForge : quelques minutes à trois jours
  ouvrés, 8 h – 15 h CET.
- Le zip reste disponible en artefact GitLab pendant 30 jours.

## En cas d'échec du job release

**Ne pas retaguer le même numéro.** Le motif `v*` est protégé sur GitLab : la
suppression d'un tag est refusée (`pre-receive hook declined`). Corriger le
problème, puis publier le numéro suivant. Le tag mort reste, c'est sans
conséquence.

Pièges déjà rencontrés, tous consignés dans `dev/docs/API_NOTES.md` :

- **`Skipping upload because "jq" was not found`** — le packager construit le
  zip puis saute l'envoi avec un simple avertissement, et la pipeline ressemble
  à un succès partiel. `jq` est installé dans le `before_script` et
  `jq --version` rend son absence bruyante.
- **Job bloqué en attente** — aucun runner rattaché au projet.
- **Zip construit mais aucun envoi** — vérifier que `CF_API_KEY` existe, qu'elle
  est *masquée* **et** *protégée*, et que le motif de tags `v*` est protégé. Les
  deux réglages n'ont de sens qu'ensemble : sans la protection du tag, la
  variable n'est pas exposée au job.

Après diagnostic, ajouter le nouveau piège à `dev/docs/API_NOTES.md`.
