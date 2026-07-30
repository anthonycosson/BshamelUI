# Journal des modifications

## Non publié

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
  (`scripts/check-design.sh`).
- Pipeline GitLab : `luacheck` et garde-fous à chaque push, packaging et envoi
  CurseForge sur tag.
