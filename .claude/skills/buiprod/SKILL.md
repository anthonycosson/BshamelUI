---
name: buiprod
description: Publie une nouvelle version de l'addon Bshamel UI sur CurseForge, via un tag poussé sur GitHub. À utiliser quand l'utilisateur dit "/buiprod", "publie", "envoie sur curseforge", "mets en prod", "sors une version", "fais une release", ou nomme un numéro de version à sortir. Couvre le choix du numéro de version, les vérifications, la création du tag, la confirmation avant publication, puis le suivi de la pipeline et du job release jusqu'à l'envoi effectif. Publication publique et irréversible — exige une confirmation explicite de l'utilisateur avant de pousser le tag.
---

# Bshamel UI — publier une version sur CurseForge

Objectif : transformer l'état actuel de `main` en une version téléchargeable par
les joueurs.

| | |
|---|---|
| Dépôt local | `C:\Users\Cosso\Documents\Claude\BshamelUI` |
| Projet CurseForge | `1631877` |
| Déclencheur réel | l'arrivée d'un tag `vX.Y.Z` sur GitHub |

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

Sur `https://github.com/anthonycosson/BshamelUI/actions`, le workflow `CI` du tag contient **deux** jobs : `lint`
puis `release`. Avec `gh` : `gh run watch --repo anthonycosson/BshamelUI`.

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
- Le zip est attaché à la release GitHub du tag (`https://github.com/anthonycosson/BshamelUI/releases`) et reste
  aussi en artefact du workflow pendant 30 jours.

## En cas d'échec du job release

**Ne pas retaguer le même numéro.** Si un ruleset protège `v*` sur GitHub, la
suppression d'un tag est refusée ; et même sans, CurseForge a peut-être déjà
reçu le fichier. Corriger le problème, puis publier le numéro suivant. Le tag
mort reste, c'est sans conséquence.

Pièges déjà rencontrés, tous consignés dans `dev/docs/API_NOTES.md` :

- **`Skipping upload because "jq" was not found`** — le packager construit le
  zip puis saute l'envoi avec un simple avertissement, et la pipeline ressemble
  à un succès partiel. `jq` est installé dans le `before_script` et
  `jq --version` rend son absence bruyante.
- **Job bloqué en attente** — Actions désactivées sur le dépôt, ou incident
  GitHub.
- **Zip construit mais aucun envoi** (avertissement « CF_API_KEY absent ») —
  vérifier que le secret `CF_API_KEY` existe dans **Settings → Secrets and
  variables → Actions**, avec exactement ce nom.
- **Release GitHub non créée** — le job `release` doit avoir la permission
  `contents: write` (déclarée dans `.github/workflows/ci.yml`).

Après diagnostic, ajouter le nouveau piège à `dev/docs/API_NOTES.md`.
