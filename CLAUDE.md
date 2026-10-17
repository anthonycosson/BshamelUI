# Bshamel UI — règles du dépôt

Addon World of Warcraft **retail et *Forever***, un seul dossier, zéro dépendance.
Licence *all rights reserved*. Distribution : CurseForge via GitHub Actions.

Ce fichier n'est pas un guide de style : c'est la liste des règles dont la
violation doit faire échouer une relecture. Le job `lint` de la CI en vérifie
mécaniquement une partie (`dev/scripts/check-design.sh`).

---

## 1. Périmètre et compatibilité

- Cible : `## Interface: 120007` minimum (WoW 12.0.7), et `16001`
  (*World of Warcraft: Forever*). Détail et sources : `dev/docs/FOREVER.md`.
- **Le client se choisit dans le `.toc`, jamais dans un `if`.**
  Un fichier chargé par les deux clients ne teste que des capacités. Un module
  qui n'a pas de sens sur Forever n'est pas gardé par une condition : sa ligne
  porte `[AllowLoadGameType standard]` (`standard` = retail seul, `camelot` =
  Forever, `mainline` = les deux). `Core/`, `UI/` et `Locales/` chargent partout.
  Un fichier **réservé à Forever** porte
  `[AllowLoadGameType camelot] [ExcludeLoadGameType standard]` : le client
  retail ne connaît pas `camelot` et charge la ligne sans la seconde directive.
  Une **option** qui n'a pas de sens sur Forever se retire de la même façon :
  une ligne dans `Core/Forever.lua` (chargé par Forever seul), jamais un
  `hidden` qui devinerait le client.
- **Jamais de branche par numéro de patch** dans le code métier.
  Interdit : `if select(4, GetBuildInfo()) >= 120100 then`.
  À la place, tester la capacité : `if C_Foo and C_Foo.Bar then`.
  Motif : un test de version est faux dès le patch suivant, un test de capacité
  reste vrai pour toujours.
- Pour les templates XML de Blizzard, le test de capacité est déjà écrit :
  `T.Template("BUTTON")` (voir `UI/Theme.lua`). Ne jamais nommer un template en
  dur ailleurs que dans `T.TEMPLATES`.

## 2. Frontière UI

- `CreateFrame` n'est autorisé que dans **`UI/Widgets/`** et dans
  **`Core/Init.lua`** (frame d'événements, unique).
- Toute couleur, police, taille, espacement ou chemin de texture vit dans
  **`UI/Theme.lua`**. Aucun littéral ailleurs — ni `SetColorTexture(0.1, ...)`,
  ni `"GameFontNormal"`, ni `SetHeight(26)`.
- Les modules ne dessinent pas. Ils déclarent une table `options` que
  `UI/Config/PageBuilder.lua` transforme en widgets. Un module qui a besoin d'un
  type de contrôle inexistant doit faire ajouter ce type à la fabrique, pas
  construire sa frame lui-même.
- Motif : la cohérence visuelle doit être une conséquence de la structure du
  code, pas d'une relecture attentive.

## 3. Globals

Exactement deux, plus les noms de frames :

| Global | Raison |
|---|---|
| `BshamelUI` | la table de l'addon |
| `BshamelUI_OnAddonCompartmentClick` | imposé par `## AddonCompartmentFunc` |
| `BshamelUI*` (noms de frames) | `UISpecialFrames` exige un nom global |

Tout le reste est `local`. Le namespace privé se récupère par
`local _, ns = ...` en tête de fichier.

SavedVariables : `BshamelUIDB` (compte) et `BshamelUICharDB` (personnage).

## 4. Réglages

- Un module lit et écrit **uniquement** via `self:Get(key)` / `self:Set(key, value)`.
  Jamais `BshamelUIDB` en direct.
- Toute nouvelle option exige, dans le **même commit** : une entrée dans
  `defaults`, un descripteur dans `options`, et une clé dans `Locales/enUS.lua`
  **et** `Locales/frFR.lua`.
- **Aucun défaut ne vaut `true`.** Installer Bshamel UI ne change rien au jeu
  tant que le joueur n'a rien coché : c'est la promesse de l'addon, et elle ne
  souffre aucune exception.

  Une case commandée par un interrupteur éteint n'en est pas une : elle est
  invisible, pas absente, et le jour où l'interrupteur s'allume elle a décidé à
  la place du joueur. Le prix est connu et assumé — un interrupteur maître qui
  ne fait rien seul, parce que sa liste est vide. C'est au libellé de le dire,
  pas au défaut de le rattraper.

  **Trois exceptions existent**, et elles se ressemblent moins qu'il n'y paraît.

  La première : le bouton de minicarte
  (`Modules/General.lua`), marqué `@default-on`. La règle protège une promesse
  précise — installer l'addon ne change rien **au jeu**. Ce bouton ne change rien
  au jeu : il ne remplace, ne cache ni ne déplace quoi que ce soit, il dit que
  l'addon est là et par où l'ouvrir. Livré éteint, il ne restait aucune porte
  visible, et un addon sans porte n'est pas discret, il est absent.

  La seconde : les correctifs de bêta (`Modules/Beta.lua`, *Forever*
  seulement). Ils ne font rien d'autre que réparer un bug du client — la fiche
  de personnage lève une erreur Lua à chaque survol sur tout client non
  anglais. La promesse protège ce que le jeu **fait**, pas ce qu'il **rate** :
  un plantage n'est pas un état qu'on préserve. Chaque case reste là, et la
  décocher redonne le bug à qui veut le constater. Ces correctifs sont
  provisoires par construction — le jour où Blizzard corrige, la ligne
  disparaît.

  La troisième : masquer les erreurs Lua (`Modules/Annoyances.lua`). C'est la
  plus discutable — elle ne montre pas l'addon et ne répare pas le client, elle
  éteint quelque chose. Ce qu'elle éteint n'est pas une fonction du jeu, c'est
  le **rapport d'une panne** : la fenêtre rouge ne fait rien arriver, elle
  signale ce qui est déjà arrivé, et elle le signale à qui n'en fera rien — un
  joueur ne corrige pas l'erreur Lua d'un addon, il la ferme. Rien n'est perdu :
  on coupe la CVar du client, pas les gestionnaires d'erreurs, et BugSack
  reçoit tout.

  La marque se pose donc sur ce qui **montre** l'addon, sur ce qui **répare le
  client**, ou sur ce qui **tait le symptôme** d'une panne — jamais sur ce qui
  **agit** à la place du joueur. Une case qui sauterait les cinématiques ou
  parlerait à sa place ne l'aura pas. Toute nouvelle ligne `@default-on`
  demande le même examen, écrit au-dessus d'elle.

  `dev/scripts/check-design.sh` le vérifie sur tous les blocs `defaults`, et
  refuse tout défaut vrai qui ne porte pas la marque.
- Les défauts ne sont jamais écrits sur le disque (`Core/DB.lua` les retire à la
  déconnexion). Changer un défaut change donc le comportement de tous les
  joueurs qui n'ont pas touché à l'option — c'est voulu.
- Le nom d'un module (`BUI:RegisterModule("Quest", ...)`) est une clé de base de
  données. Le renommer casse les réglages de tout le monde : ne pas le faire.

## 5. Textes

- Aucune chaîne affichée en dur. Tout passe par `L["..."]`.
- Les clés sont l'anglais lisible, pas des identifiants opaques : une clé sans
  traduction s'affiche telle quelle, ce qui dégrade proprement.
- `Locales/frFR.lua` peut mettre `true` pour « identique à l'anglais ».

## 6. Cycle de vie des modules

- `OnEnable` / `OnDisable` sont obligatoires en pensée, même si `OnDisable` vaut
  `nil` : **désactiver un module doit le rendre indétectable**. Toute frame
  cachée, texture remplacée ou point d'ancrage déplacé doit être restauré.
- Les abonnements pris via `self:RegisterEvent` / `self:RegisterMessage` sont
  révoqués automatiquement. Ne pas utiliser `BUI:RegisterEvent` depuis un module.
- `hooksecurefunc` est irréversible. Le seul motif autorisé est
  `U.GuardedHook`, qui pose le hook une fois et le rend inerte quand le module
  est éteint.
- Un module qui touche à une frame sécurisée (barres d'action, unit frames,
  boutons de sort) doit déclarer `secure = true` : le core diffère alors son
  activation hors combat.

## 7. Performance

- Pas d'`OnUpdate` sans `U.Throttle`.
- Pas de création de table dans un chemin chaud (CLEU, `UNIT_AURA`, `OnUpdate`) :
  réutiliser une table de travail au niveau du fichier.
- Rafraîchissement d'UI en rafale : passer par `U.Debounce`.
- Les frames ne se détruisent pas en World of Warcraft. Construire une fois,
  cacher/réafficher ensuite (voir `PageBuilder:GetPage`).

## 8. Code emprunté

- **Interdit** de copier du code d'un autre addon. `EllesmereUI` et
  `BetterBlizzFrames` sont *all rights reserved* ; le code sous GPL est
  incompatible avec notre licence fermée.
- Autorisé et encouragé : lire d'autres addons pour identifier **quels
  événements et quelles fonctions d'API** résolvent un problème, puis écrire
  notre implémentation. Consigner la trouvaille dans `dev/docs/API_NOTES.md`.
- Toute bibliothèque tierce embarquée exige une licence permissive vérifiée
  (MIT/BSD/zlib), son fichier de licence conservé, et une mention dans
  `README.md`.

## 9. Commits et releases

- Un commit = un sujet. Message à l'impératif, en français.
- La version ne se modifie pas à la main : `## Version: @project-version@` est
  remplacé par le tag git au packaging. Une release = un tag `vX.Y.Z`.
- `CHANGELOG.md` se met à jour dans le même commit que la fonctionnalité, pas au
  moment du tag.

## 10. Vérification avant de dire « c'est fait »

1. `luacheck .` passe.
2. `bash dev/scripts/check-design.sh` passe — **avec `luac5.1`**. Le jeu embarque
   Lua 5.1 : deux cent cinquante registres et deux cents variables locales par
   fonction. Passer une de ces bornes ne casse pas une ligne, ça empêche le
   fichier entier de se compiler, et le module disparaît du menu. Un `luac`
   récent ne le voit pas ; le script dit quelle version il a employée.
3. `/reload` en jeu, aucune erreur dans BugSack.
4. Le réglage survit à un `/reload` (vérifiable dans
   `_retail_/WTF/Account/<compte>/SavedVariables/BshamelUI.lua`).
5. Désactiver le module restaure l'état d'origine.

---

## Repères de code

| Besoin | Où |
|---|---|
| Ajouter un module | copier `Modules/Quest.lua`, ajouter la ligne dans `BshamelUI.toc` |
| Ajouter un type de contrôle | `UI/Widgets/`, puis le brancher dans `PageBuilder.lua` |
| Ajouter une catégorie de menu | `BUI.CATEGORIES` dans `Core/Module.lua` |
| Ajouter un événement global | `BUI:RegisterEvent` dans `Core/Init.lua` |
| Migrer un format de réglage | `DB:RunMigrations` dans `Core/DB.lua` |
| Piège d'API rencontré | le noter dans `dev/docs/API_NOTES.md` |
| Un module qui ne tient plus dans un fichier | le couper entre ce qui **décrit** et ce qui **agit**, la page d'abord dans le `.toc` — voir `Modules/NameplatesPage.lua` |

## Environnement de développement

Le dépôt est monté dans le jeu par une jonction NTFS :

```
C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\BshamelUI
  -> C:\Users\Cosso\Documents\Claude\BshamelUI
```

Une seconde jonction, identique, part de
`_classic_beta_\Interface\AddOns\BshamelUI` (bêta de Forever).

Éditer le dépôt, `/reload` en jeu, c'est tout.

**Règle de rangement :** tout ce qui ne part pas chez le joueur vit sous
`dev/` — documentation, scripts, packager, sorties de build. Les seules
exceptions sont les fichiers de configuration que leurs outils exigent à la
racine (`.pkgmeta`, `.github/`, `.luacheckrc`, `.luarc.json`,
`CLAUDE.md`, `README.md`…). Ajouter un fichier de développement ailleurs que
sous `dev/` oblige à l'ajouter aussi dans la liste `ignore` de `.pkgmeta`,
sous peine de le livrer aux joueurs.

Voir `README.md` pour le détail de ce qui est publié ou non.
