## 2.0.4 — 2026-09-21

### Ajouté
- **Graphismes**, nouvelle page (Qualité de vie). Elle tient les réglages
  graphiques que le panneau Options ne montre pas. Première case :
  **désactiver l'effet de brouillard**, qui dégage le paysage au loin.
  Décocher rend au jeu la valeur qu'il avait.

### Modifié
- **Le gestionnaire de temps de recharge n'est plus grisé sur *Forever*.** La
  bêta porte le même que retail, et centrer les améliorations suivies y marche
  comme ailleurs.
- **Ressource personnelle** : une ligne rouge sous « N'afficher aucun texte »
  rappelle qu'il faut « Afficher le texte de la barre » dans le mode Édition —
  sans quoi le jeu n'écrit rien, et la case semble ne rien faire.
- **Quatre fenêtres de plus se déplacent** : l'assistance, la charte de guilde,
  la fenêtre de raid et le registre des rangs de guilde.
- **Toute fenêtre se prend désormais par sa barre de titre.** Beaucoup ne se
  laissaient saisir que dans une bordure de quelques pixels : leur contenu
  prend la souris et couvre tout le corps — le navigateur d'aide couvre cent
  pour cent de sa fenêtre, le canevas des talents quatre-vingt-douze pour cent
  de la sienne. Le modificateur reste demandé, et la bande s'arrête avant les
  boutons de fermeture et de réduction.

### Corrigé
- **La fenêtre des compagnons de gouffre se déplace enfin.** Elle était
  enregistrée sous un nom d'addon qui n'existe pas, et n'a donc jamais été
  branchée.

### Interne
- **Sonde des fenêtres** (`/buiwin`, dans l'addon de sonde sous `dev/`). Pour
  chaque fenêtre du client, elle mesure le pourcentage de sa surface où un
  glisser répond, et nomme les enfants qui avalent le clic ailleurs. C'est la
  question que la lecture de la source ne tranche pas.

