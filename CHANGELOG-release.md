## 2.0.1 — 2026-09-20

### Ajouté
- **Un message explique la panne de sauvegarde de la bêta.** Quand le client
  écrit le fichier de réglages sans jamais le relire — constaté sur Forever —
  l'addon s'en aperçoit à la connexion et dit quoi faire : quitter le jeu et
  supprimer `BshamelUI.lua` du dossier `SavedVariables`. Le témoin qui permet
  cette détection vit dans une CVar, hors du fichier en cause.
- **Ramassage rapide** (Sacs et réparations). Tout est pris dès l'ouverture
  d'un cadavre : la fenêtre de butin n'apparaît plus, et son animation avec.
  Seulement quand le butin automatique est déjà actif, ou sa touche maintenue.
- **La fenêtre de recherche de groupe de Forever se déplace** comme les autres.
  C'est une autre fenêtre que celle de retail, apportée par un addon du client
  chargé à la demande, et ses trois pages couvrent la fenêtre entière : le clic
  n'arrivait jamais jusqu'à elle, d'où une fenêtre qu'on redimensionnait sans
  pouvoir la déplacer.
- **Correctifs de la bêta de Forever**, nouveau module. Il ne répare que ce que
  le client casse, et ses cases sont cochées à la livraison : un plantage n'est
  pas un réglage de confort. Premier correctif : la fiche de personnage levait
  une erreur Lua à chaque survol d'une caractéristique sur tout client non
  anglais — la bêta y cherche ses infobulles sous leur nom traduit, qui
  n'existe qu'en anglais.
  Le module a sa propre catégorie, « Beta », vide sur retail.

### Interne
- **Le packager connaît Forever.** Resynchronisé depuis l'amont BigWigs : une
  interface `16???` est désormais un client « forever », et le fichier part sur
  CurseForge avec la version de jeu 1.60.1 au lieu d'être classé retail.
- **Le changelog publié ne contient plus que la version en cours.** Le packager
  envoie le fichier désigné en entier ; `dev/scripts/tag-release.sh` engendre
  donc `CHANGELOG-release.md`, la seule section fraîchement datée, et c'est lui
  que `.pkgmeta` désigne. L'historique complet reste dans `CHANGELOG.md`.

