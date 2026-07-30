# Page CurseForge

Texte à coller dans le projet CurseForge. À relire à chaque version qui ajoute
un module — une page qui décrit des fonctionnalités absentes se paie en
commentaires.

L'anglais est la version de référence : c'est la langue de la modération et de
la majorité des visiteurs. Le français est fourni pour la section
« Description » en second, si tu veux la doubler.

---

## Summary (champ court, obligatoire)

```
A hand-made, dependency-free quality-of-life suite that looks and feels like the default Blizzard UI.
```

Variante plus concrète si tu préfères annoncer le contenu réel :

```
Lightweight quality-of-life addon built on Blizzard's own UI templates. Quest automation, with more modules on the way.
```

---

## Description (anglais)

```
## Bshamel UI

Bshamel UI is a quality-of-life suite for retail World of Warcraft, built from
scratch as a single addon with **no dependencies** — no Ace3, no embedded
libraries, nothing to install alongside it.

It is designed around one idea: **the game already has a good-looking
interface**. Rather than replacing it, Bshamel UI builds on Blizzard's own
frame templates, font objects and colours. The options window looks like it
ships with the game, and when Blizzard restyles the UI in a patch, this addon
follows along instead of looking dated.

### Current features

**Quest**
- Auto-accept quests from NPCs, quest items and zone triggers
- Auto-turn-in completed quests
- Stops automatically when a quest offers a real choice of rewards — it will
  never pick one for you
- Optional filter to leave low-level (grey) quests alone
- Hold a configurable modifier key to temporarily suspend automation

### Everything else

- **One window for everything** — `/bui` opens a categorised options panel.
  Also reachable from the addon compartment next to the minimap, and from the
  game's own Options menu.
- **Per-character profiles** — each character picks which profile it uses;
  settings are shared or separate as you like.
- **Every module can be switched off** individually, and turning one off leaves
  no trace: the interface goes back exactly as Blizzard shipped it.
- **English and French**, with more languages easy to add.
- **Lightweight** — nothing is built until it is needed. Logging in without
  opening the options creates no interface frames at all.

### Roadmap

More modules are planned across three categories: General, Quality of Life, and
Mythic+ / Raid. This is an early release; the foundation is done and modules
will land steadily.

### Feedback

Bug reports and suggestions are welcome. When reporting a Lua error, please
include the full error text — BugSack makes this easy.

---

Bshamel UI is an unofficial add-on. It is not created by, affiliated with, or
endorsed by Blizzard Entertainment, Inc.
```

---

## Description (français)

```
## Bshamel UI

Bshamel UI est une suite de confort pour World of Warcraft retail, écrite de
zéro en un seul addon, **sans aucune dépendance** — pas d'Ace3, pas de
bibliothèque embarquée, rien à installer à côté.

Le parti pris est simple : **l'interface du jeu est déjà réussie**. Plutôt que
de la remplacer, Bshamel UI s'appuie sur les cadres, les polices et les couleurs
de Blizzard. La fenêtre d'options a l'air de faire partie du jeu, et quand
Blizzard retouche son interface à un patch, l'addon suit au lieu de vieillir.

### Fonctionnalités actuelles

**Quête**
- Acceptation automatique des quêtes des PNJ, des objets et des déclencheurs de zone
- Rendu automatique des quêtes terminées
- S'arrête net dès qu'une quête propose un vrai choix de récompense : elle ne
  choisira jamais à votre place
- Filtre facultatif pour ignorer les quêtes grises
- Une touche configurable, maintenue, suspend temporairement l'automatisation

### Le reste

- **Une seule fenêtre** — `/bui` ouvre un panneau d'options rangé par
  catégories. Accessible aussi depuis le compartiment d'addons près de la
  minicarte et depuis les options du jeu.
- **Profils par personnage** — chaque personnage choisit son profil ; les
  réglages sont partagés ou séparés selon vos envies.
- **Chaque module se désactive** indépendamment, et l'éteindre ne laisse aucune
  trace : l'interface revient exactement telle que Blizzard l'a livrée.
- **Français et anglais**, d'autres langues faciles à ajouter.
- **Léger** — rien n'est construit avant d'être nécessaire. Se connecter sans
  ouvrir les options ne crée aucune frame d'interface.

### À venir

D'autres modules sont prévus dans trois catégories : Général, Confort (QoL) et
Mythique+ / Raid. C'est une première version : les fondations sont posées, les
modules arriveront régulièrement.

### Retours

Les rapports de bug et les suggestions sont bienvenus. Pour une erreur Lua,
merci de joindre le texte complet — BugSack le rend facile à récupérer.

---

Bshamel UI est un addon non officiel. Il n'est ni créé, ni affilié, ni soutenu
par Blizzard Entertainment, Inc.
```

---

## Métadonnées du projet

| Champ | Valeur |
|---|---|
| Nom | Bshamel UI |
| Catégories suggérées | *Quests & Leveling*, *Miscellaneous* |
| Licence | All Rights Reserved (option « Custom License », coller `license.txt`) |
| Source | l'URL du dépôt GitLab, si tu veux le rendre public |
| Issues | l'URL des issues GitLab |

## À faire avant de soumettre

- [ ] Un logo (400×400 minimum). C'est bloquant pour la modération.
- [ ] Le premier zip, produit par `bash .release/release.sh -d -o`.
- [ ] Une capture d'écran de la fenêtre d'options — c'est ce qui décide un
      visiteur, bien plus que le texte.
