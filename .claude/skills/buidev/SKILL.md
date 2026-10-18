---
name: buidev
description: Enregistre le travail en cours de l'addon Bshamel UI sur GitHub, sans rien publier sur CurseForge. À utiliser quand l'utilisateur dit "/buidev", "pousse sur github", "sauvegarde le travail", "commit et push", "enregistre ce que j'ai fait", ou quand il vient de terminer une modification de BshamelUI et veut la mettre à l'abri sans faire de version. Couvre les vérifications locales, le CHANGELOG, le commit et le push sur main. Ne crée jamais de tag et ne publie jamais — pour publier une version, c'est le skill buiprod.
---

# Bshamel UI — enregistrer le travail sur GitHub

Objectif : mettre le travail en cours à l'abri sur GitHub, avec la CI au vert.
**Rien ne part sur CurseForge.**

| | |
|---|---|
| Dépôt local | `%USERPROFILE%\Documents\Claude\BshamelUI` |
| Remote | `https://github.com/anthonycosson/BshamelUI.git` (HTTPS, identifiants GitHub en cache GCM) |
| Branche | `main` |

## La règle qui ne bouge pas

**Aucun tag n'est créé ni poussé dans ce workflow.** Un tag déclenche une
publication publique sur CurseForge. Si l'utilisateur veut publier, c'est le
skill `buiprod`, pas celui-ci — le lui dire et basculer.

## Déroulé

### 1. Regarder ce qui a changé

```bash
cd ~/Documents/Claude/BshamelUI && git status --short && git diff --stat
```

Résumer en une phrase ce que la modification fait. Si le diff contient des
choses sans rapport entre elles, proposer de découper en plusieurs commits :
un commit = un sujet.

### 2. Vérifier

```bash
cd ~/Documents/Claude/BshamelUI && bash dev/scripts/lint-local.sh
```

Trois passes : syntaxe (`luac`), diagnostics (`lua-language-server`), garde-fous
de design (`check-design.sh`).

**Ne jamais commiter si ça échoue.** Corriger d'abord. Un avertissement luacheck
fait échouer la CI, donc le laisser passer ne fait que déplacer le problème de
trente secondes.

Si un garde-fou de design bloque, la correction n'est presque jamais de
contourner la règle : relire `CLAUDE.md`, le fichier explique le motif de
chacune.

### 3. Mettre à jour le CHANGELOG

Ajouter une ligne sous `## Non publié` dans `CHANGELOG.md`, **dans le même
commit** que la modification.

- Visible par le joueur → `### Ajouté`, `### Modifié` ou `### Corrigé`
- Invisible pour lui (refactor, outillage, CI) → `### Interne`

Une modification purement locale (documentation de dev, script) peut se passer
d'entrée.

### 4. Commiter

Message en français, à l'impératif, une ligne de sujet courte, un corps qui
explique le **pourquoi** si ce n'est pas évident.

```
Corriger l'alignement des cases à cocher

Le libellé pouvait déborder sur la colonne des contrôles quand la
fenêtre était réduite au minimum.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
```

### 5. Pousser

```bash
cd ~/Documents/Claude/BshamelUI && git push origin main
```

Ne pas demander confirmation : c'est réversible, ça reste sur l'infrastructure
de l'utilisateur, et rien n'est publié.

### 6. Vérifier la pipeline

Le workflow `CI` (job `lint`) démarre automatiquement et dure une
trentaine de secondes. Aller voir le résultat sur `https://github.com/anthonycosson/BshamelUI/actions`, ou avec
`gh run list --repo anthonycosson/BshamelUI --limit 3` si `gh` est installé.

- **Verte** → le dire et s'arrêter là.
- **Rouge** → lire le log du job, diagnostiquer, corriger, recommencer. Ne pas
  laisser l'utilisateur avec une CI rouge sans explication.
- **Bloquée en attente** — rare sur les runners hébergés par GitHub ; vérifier
  <https://www.githubstatus.com> et que les Actions sont activées dans
  **Settings → Actions**.

## Ce que la CI ne fait pas

Elle ne lance jamais World of Warcraft. Elle valide la syntaxe, les variables,
les règles de design et les traductions — **pas le comportement**. Un addon peut
être vert et planter au premier `/reload`.

Si la modification touche à l'affichage ou au comportement en jeu, rappeler à
l'utilisateur de tester avec `/reload` avant d'envisager une publication, et
proposer de lire ses erreurs dans
`_retail_\WTF\Account\<compte>\SavedVariables\!BugGrabber.lua`.
