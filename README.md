# Bshamel UI

Suite d'améliorations d'interface pour World of Warcraft *retail*, faite maison :
un seul addon, un seul dossier, zéro dépendance.

L'objectif est de remplacer un empilement d'addons tiers par un ensemble
cohérent, qui s'intègre à la direction artistique du client au lieu de la
recouvrir.

## État

En cours de construction.

| Module | Catégorie | État |
|---|---|---|
| Quête — acceptation et rendu automatiques | QoL | fonctionnel |

## Installation

Version publiée : via CurseForge.

Depuis les sources : cloner le dépôt et le monter dans le dossier des addons.
Sous Windows, une jonction NTFS évite toute copie manuelle :

```bash
cmd //c mklink /J "C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\BshamelUI" "C:\Users\<vous>\dev\BshamelUI"
```

## Utilisation

- `/bui` ou `/bshamelui` — ouvre la fenêtre d'options
- `/bui version` — affiche la version chargée
- L'icône du compartiment d'addons, à côté de la minicarte, ouvre la même fenêtre

## Développement

Les règles du dépôt sont dans [CLAUDE.md](CLAUDE.md). Le reste :

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — structure et cycle de vie
- [docs/DESIGN.md](docs/DESIGN.md) — tokens, widgets, règles de grille
- [docs/API_NOTES.md](docs/API_NOTES.md) — pièges de l'API du client
- [docs/RELEASING.md](docs/RELEASING.md) — publication

Vérifications locales :

```bash
luacheck . && bash scripts/check-design.sh
```

## Licence

Tous droits réservés — voir [license.txt](license.txt).

Bshamel UI est un addon non officiel. Il n'est ni créé, ni affilié, ni soutenu
par Blizzard Entertainment, Inc.
