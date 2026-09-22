## 2.0.6 — 2026-09-22

### Ajouté
- **Suivi des temps restants**, nouvelle page (Qualité de vie). Elle tient les
  attentes que le jeu impose sans jamais dire combien elles durent, et en
  compte deux pour l'instant. Chacune a son cadre doré, du même style que le
  panneau d'outils de groupe : un libellé, un nombre, et rien autour.
- **Vol** — le temps qui reste sur un griffon ou une wyverne. Le client ne
  publie aucune durée de vol : le premier vol sur un trajet montre une
  estimation par distance ; dès que ce trajet a été volé une fois, le temps
  réellement mesuré la remplace pour tous les vols suivants.
- **Métiers** — le temps qui reste sur un lot de fabrication, « Tout créer »
  compris. Rien n'y est deviné : le jeu publie le début et la fin de chaque
  incantation, et la taille du lot est connue au lancement. Le décompte est
  donc exact dès le premier objet.
- Les deux cadres **se redimensionnent** en tirant leur coin bas-droit, comme
  le panneau d'outils de groupe. Verrouiller la position range la poignée.
- `/bui vol` écrit dans le chat ce que le dernier embarquement a donné, étape
  par étape. Ce module échoue en silence par construction : quatre lectures
  peuvent se taire sans qu'aucune ne lève, et le seul symptôme est un cadre qui
  ne vient pas.

