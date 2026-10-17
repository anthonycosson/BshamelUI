## 2.0.11 — 2026-10-17

### Ajouté
- **Métiers** (*Forever*) : une case **Masquer en champ de bataille**. Le
  cadre qui signale un suivi de récolte éteint s'y tait — aucun nœud n'y
  compte — et revient à la sortie.

### Interne
- Le dépôt quitte GitLab pour GitHub : la pipeline passe sur GitHub Actions
  (`.github/workflows/ci.yml`), avec les mêmes jobs `lint` et `release`. Chaque
  version crée en plus une release GitHub avec le zip attaché.

