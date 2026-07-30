# Journal des modifications

## Non publié

### Modifié
- Fenêtre d'options translucide : le jeu reste visible derrière, les bordures
  du cadre restent pleines, et un voile sombre en dégradé assombrit les quatre
  bords vers l'intérieur comme le panneau Options du client.
- Le titre de page n'est plus encadré. Il s'affiche en grand et en blanc,
  souligné d'un filet, sur le modèle de ce même panneau.
- L'encadrement passe à la colonne de navigation, et chaque en-tête de catégorie
  reçoit un bandeau doré borné de deux filets.
- Couleurs de texte alignées sur celles du client : le doré structure
  (catégories, en-têtes de section, entrées de module au repos), le blanc se lit
  (titre de page, libellés, entrée sélectionnée). L'accent bleu quitte le chrome
  de la fenêtre.
- Textes et lignes agrandis des deux côtés, la colonne de navigation davantage
  que la zone de contenu.
- Les deux zones partagent exactement la même teinte de fond : le panneau creusé
  ne pose plus de second voile par-dessus celui de la fenêtre.
- La colonne de navigation perd son ascenseur — la molette suffit. Celui de la
  zone de contenu voit son curseur dimensionné au prorata de la page.

### Interne
- Toutes les opacités de l'interface sont regroupées dans `T.ALPHA`
  (`UI/Theme.lua`) au lieu d'être écrites au fil des widgets.
- Les polices se déclarent en candidats résolus au chargement, comme les
  templates : les variantes récentes (`…Medium`, `…Large2`) ne sont garanties
  par aucun contrat et une police inconnue lève une erreur.
- `W.PageTitleBox` devient `W.PageTitle` ; `W.VerticalDivider` est remplacé par
  `W.Rule`, partagé par le titre de page, les en-têtes de section et les
  bandeaux de catégorie. Nouveau `W.EdgeShade`.

## 0.1.2 — 2026-07-30

### Modifié
- Publication sous le nom d'auteur « Bshamel ».

### Interne
- `Refresh` d'une page d'options devient une fonction partagée au lieu d'une
  fermeture recréée pour chaque module.
- Suppression d'une table morte dans la barre latérale.
- Intégration continue opérationnelle : `luacheck` et garde-fous de design
  vérifiés à chaque push, packaging et publication automatiques sur tag.

<!-- La version 0.1.1 a été taguée mais jamais publiée : le job de release
     manquait `jq` et sautait l'envoi. Le tag reste en place, la protection des
     tags interdisant sa suppression. -->


## 0.1.0 — 2026-07-30

Première version. Les fondations sont posées ; un seul module fonctionnel pour
l'instant, les suivants s'appuieront dessus.

### Ajouté
- Socle de l'addon : namespace, répartiteur d'événements, bus de messages
  interne, sortie console.
- Base de données à profils (choix du profil par personnage), fusion des valeurs
  par défaut à la connexion et nettoyage à la déconnexion.
- Registre de modules déclaratifs, avec révocation automatique des abonnements
  à la désactivation et report d'activation hors combat pour les modules
  sécurisés.
- Système de traduction avec repli sur l'anglais ; locales `enUS` et `frFR`.
- Design system : tokens uniques (`UI/Theme.lua`), fabrique de widgets,
  moteur de pages déclaratives.
- Fenêtre d'options `/bui` : navigation par catégories, encadré de titre de
  page, zone défilante, entrée dans les options du client, icône dans le
  compartiment d'addons.
- Module **Quête** : acceptation et rendu automatiques, filtre sur les quêtes
  triviales, touche de contournement configurable.
- Garde-fous de design vérifiés en intégration continue
  (`dev/scripts/check-design.sh`).
- Pipeline GitLab : `luacheck` et garde-fous à chaque push, packaging et envoi
  CurseForge sur tag.
