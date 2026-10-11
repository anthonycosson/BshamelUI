## 2.0.10 — 2026-10-11

### Ajouté
- **Files d'attente**, nouvelle page (Qualité de vie), sur les deux clients.
  Elle ne porte qu'un réglage, le minuteur posé sur la fenêtre qui annonce une
  instance ou un champ de bataille — celle qui se referme toute seule sans
  jamais dire quand.
- Le minuteur existait déjà, mais il vivait dans *Recherche de groupe*, qui ne
  charge pas sur *Forever* : il y était donc **introuvable**, alors que la
  fenêtre de champ de bataille, elle, y existe. Il est maintenant partout, et
  votre réglage suit tout seul.
- **Liste BIS**, nouvelle page (Outils), sur *Forever* — **annoncée, grisée**.
  Elle est écrite en entier, elle ne s'allume pas : l'index des objets dont sa
  recherche se nourrit repose sur une capacité du client qui reste à vérifier,
  et une recherche qui ne trouve rien ne vaut pas mieux que pas de recherche.
  La page montre ce qu'elle proposera. Ce qui suit décrit ce qui l'attend.
- Une ligne par emplacement, trois choix par ligne — BIS 1, BIS 2, BIS 3 — et
  la liste appartient au personnage : un chasseur et un prêtre ne visent pas le
  même casque. Ctrl + clic gauche sur le bouton de la minicarte l'ouvre.
- **Une recherche d'objets avec des filtres**, pour remplir la liste sans
  chercher à la main : emplacement, niveau requis au plus, niveau d'objet entre
  deux bornes, type d'armure, stats voulues, et « ce personnage peut le
  porter ». Les résultats sont triés par niveau d'objet.
- **Tout le jeu y passe** — donjons, trash, monde ouvert, PvP, métiers : la
  recherche ne regarde pas d'où vient un objet, elle regarde tous les objets.
  En revanche elle ne dit pas d'où il tombe : le jeu ne publie pas cette
  information sur ce client.
- Un clic sur une case choisit ou remplace, un clic droit la vide, Maj + clic
  colle le lien dans le chat. Le survol donne l'infobulle de l'objet.
- **L'index se bâtit en cochant la case**, et pas avant : il lit la table
  d'objets du client, puis demande les fiches manquantes au serveur par petits
  paquets. Quelques minutes la première fois, rien ensuite — il se range dans
  la sauvegarde du compte et se répare tout seul à chaque allumage. Un bouton
  « Reconstruire » est là pour qui le croit périmé.

