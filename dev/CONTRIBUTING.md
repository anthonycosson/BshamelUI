# Contribuer

## Licence des contributions

Bshamel UI est publié **tous droits réservés**. En proposant une modification,
vous cédez au détenteur du copyright (Bshamel) les droits patrimoniaux sur votre
contribution, afin qu'elle puisse être distribuée sous la licence du projet.

Ne proposez que du code dont vous êtes l'auteur. Le code issu d'un autre addon
ne peut pas être accepté, quelle que soit sa licence :

- *all rights reserved* (EllesmereUI, BetterBlizzFrames…) — pas de droit d'usage ;
- GPL — obligerait le projet à s'ouvrir ;
- MIT/BSD — accepté uniquement sous forme de bibliothèque embarquée entière,
  avec son fichier de licence, jamais découpée en morceaux recopiés.

En revanche, lire d'autres addons pour comprendre **quelle API** résout un
problème est parfaitement légitime : notez la trouvaille dans
`dev/docs/API_NOTES.md` et écrivez l'implémentation.

## Outillage

L'installation complète d'un poste de développement est décrite dans
[docs/SETUP.md](docs/SETUP.md). Ce qui suit en reprend le point délicat.

`check-design.sh` compile chaque fichier avec le Lua du client — **5.1**, dont
les plafonds par fonction sont plus bas que ceux des versions récentes. Un
`luac` moderne ne lève pas cette erreur-là : il faut celui de cette version. Le
script annonce toujours laquelle il a employée, à lire avant de croire son
verdict — sans `luac5.1`, il se rabat sur ce qu'il trouve, ou ne vérifie rien.

- Linux : `apt install lua5.1`. macOS : `brew install lua@5.1`.
- Windows : ni winget ni WSL ne le proposent. Prendre
  `lua-5.1.5_Win64_bin.zip` chez [LuaBinaries][], n'en extraire que
  `luac5.1.exe` — il est lié statiquement, les DLL de l'archive ne servent à
  rien — et le poser dans `%USERPROFILE%\bin`, que Git Bash ajoute au `PATH`
  même s'il faut d'abord le créer.

[LuaBinaries]: https://sourceforge.net/projects/luabinaries/files/5.1.5/Tools%20Executables/

## Avant d'ouvrir une pull request

1. `luacheck .` passe.
2. `bash dev/scripts/check-design.sh` passe.
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
