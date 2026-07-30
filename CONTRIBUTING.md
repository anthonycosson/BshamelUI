# Contribuer

## Licence des contributions

Bshamel UI est publié **tous droits réservés**. En proposant une modification,
vous cédez au détenteur du copyright (Cosso) les droits patrimoniaux sur votre
contribution, afin qu'elle puisse être distribuée sous la licence du projet.

Ne proposez que du code dont vous êtes l'auteur. Le code issu d'un autre addon
ne peut pas être accepté, quelle que soit sa licence :

- *all rights reserved* (EllesmereUI, BetterBlizzFrames…) — pas de droit d'usage ;
- GPL — obligerait le projet à s'ouvrir ;
- MIT/BSD — accepté uniquement sous forme de bibliothèque embarquée entière,
  avec son fichier de licence, jamais découpée en morceaux recopiés.

En revanche, lire d'autres addons pour comprendre **quelle API** résout un
problème est parfaitement légitime : notez la trouvaille dans
`docs/API_NOTES.md` et écrivez l'implémentation.

## Avant d'ouvrir une merge request

1. `luacheck .` passe.
2. `bash scripts/check-design.sh` passe.
3. Testé en jeu, aucune erreur Lua.
4. Les règles de [CLAUDE.md](CLAUDE.md) sont respectées — en particulier :
   pas de `CreateFrame` hors `UI/Widgets/`, pas de valeur d'apparence en dur,
   pas de texte non traduit, désactiver le module restaure l'état d'origine.
5. `CHANGELOG.md` mis à jour dans le même commit.

## Style

- Indentation 4 espaces, lignes de 120 colonnes maximum, `.editorconfig` fait foi.
- Commentaires et messages de commit en français, à l'impératif.
- Un commentaire explique **pourquoi**, pas **quoi**. Le code dit déjà quoi.
- Noms de variables en anglais, comme l'API du jeu.
