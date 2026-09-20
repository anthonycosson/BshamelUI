## 2.0.2 — 2026-09-20

### Ajouté
- **Sauvegarder ses réglages dans des macros** (Correctifs de la bêta,
  *Forever* seulement). La bêta ne rend pas leurs réglages aux addons au
  démarrage du jeu, et aucun addon n'y échappe. Les macros, elle les
  restitue : un bouton y écrit les vôtres, et l'addon les remet tout seul au
  démarrage suivant. La page donne la marche à suivre, et une ligne rouge à la
  connexion y renvoie tant que ce n'est pas fait. À refaire après chaque
  changement de réglage.

### Modifié
- **Masquer les erreurs Lua est coché à l'installation.** Seule la fenêtre du
  client se tait ; les gestionnaires d'erreurs reçoivent toujours tout, et
  décocher la case la rend.
- Le module Journalisation ne s'annonce plus à la connexion.

### Corrigé
- **Les réglages ne se perdent plus d'une session à l'autre sur Forever.** Ce
  qui appartient à un personnage — son profil actif, son historique de chat —
  vivait dans un fichier que le client ne relit jamais. Il est désormais rangé
  dans celui du compte, et ce qui y était déjà est repris automatiquement.
- **Un traitement prévu pour la connexion pouvait ne jamais partir.** Un
  abonné qui se désabonnait pendant la distribution d'un événement faisait
  sauter le suivant, sans un mot.
- **Une source d'erreur Lua en moins à l'ouverture de la fiche de personnage.**
  Celle du correctif d'infobulles demeure : il n'en existe pas de version
  propre, et les infobulles lisibles valent mieux qu'elle.
- La fenêtre de recherche de groupe de *Forever* se repose plus sûrement.

