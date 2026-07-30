# Architecture

## Vue d'ensemble

Un seul addon, chargé dans l'ordre déclaré par `BshamelUI.toc` :

```
Core/       amorçage, base de données, registre de modules, traductions
UI/         thème, fabrique de widgets, fenêtre d'options
Modules/    les fonctionnalités
Locales/    les traductions
```

La dépendance ne va que dans un sens : `Modules` connaît `Core`, `Core` ne
connaît aucun module. `UI` connaît `Core` et lit les déclarations des modules,
mais aucun module n'appelle `UI`.

## Cycle de vie

```
chargement des fichiers
    Core/Init.lua        crée BUI, la frame d'événements, le bus de messages
    Core/DB.lua          s'abonne à PLAYER_LOGOUT
    Core/Module.lua      s'abonne à ADDON_LOADED et PLAYER_LOGIN
    Modules/*.lua        appellent BUI:RegisterModule (les défauts sont
                         enregistrés, rien n'est encore actif)
ADDON_LOADED (BshamelUI)
    DB:Initialize()      SavedVariables prêts, migrations, fusion des défauts
PLAYER_LOGIN
    pour chaque module enregistré et activé -> BUI:EnableModule
    enregistrement de la catégorie dans les options du client
premier /bui
    construction paresseuse de la fenêtre d'options
PLAYER_LOGOUT
    DB retire les valeurs égales aux défauts avant l'écriture du fichier
```

Rien n'est construit avant d'être nécessaire : se connecter sans ouvrir les
options ne crée aucune frame d'interface.

## Flux d'un réglage

```
    clic utilisateur
        -> widget.set()
        -> mod:Set(key, value)
        -> DB:Set  écrit dans BshamelUIDB.profiles[actif].modules[mod][key]
        -> SendMessage("BUI_SETTING_CHANGED", mod, key, value)
              |
              +-> Core/Module.lua   key == "enabled" ? bascule le module
              |                     sinon -> mod:OnSettingChanged(key, value)
              +-> UI/Config         rafraîchit la page si elle est visible
```

Un module ne se rafraîchit jamais lui-même depuis l'UI, et l'UI ne connaît
jamais la logique d'un module. Les deux ne communiquent que par ce message.

## Stockage

```lua
BshamelUIDB = {
    schema   = 1,
    profiles = {
        ["Default"] = {
            modules = {
                Quest = { autoAccept = true },   -- uniquement les écarts au défaut
            },
        },
    },
}

BshamelUICharDB = { profile = "Default" }        -- choix par personnage
```

Le profil actif est choisi **par personnage** : deux rerolls peuvent partager
ou non leurs réglages sans duplication de données.

Les valeurs par défaut sont fusionnées en mémoire à la connexion et retirées à
la déconnexion (`Core/Util.lua`, `MergeDefaults` / `StripDefaults`). Le fichier
sur disque ne contient donc que les choix explicites — ce qui rend indolore
l'ajout d'une option ou le changement d'un défaut.

## Registre de modules

Un module est une table déclarative passée à `BUI:RegisterModule(name, def)`.
Le core y injecte des méthodes (`Get`, `Set`, `IsEnabled`, `RegisterEvent`,
`RegisterMessage`, `Print`) et une clé `enabled` avec le défaut `true`.

Les abonnements pris via `self:RegisterEvent` sont mémorisés et révoqués à la
désactivation. C'est le mécanisme qui rend la règle « un module désactivé est
indétectable » tenable sans discipline.

Un module marqué `secure = true` voit son activation différée quand le joueur
est en combat (`PLAYER_REGEN_ENABLED`).

## Interface

`UI/Theme.lua` détient tous les tokens. `UI/Widgets/` détient toutes les
créations de frames. `UI/Config/PageBuilder.lua` traduit la table `options`
d'un module en lignes de widgets, en gérant lui-même l'alignement, l'état
grisé, les infobulles et le rafraîchissement.

Conséquence pratique : ajouter une option à un module, c'est ajouter trois
lignes (un défaut, un descripteur, une clé de traduction) et rien d'autre. Il
n'existe aucun chemin par lequel un module peut désaligner une page.

Les pages sont construites une fois puis cachées/réaffichées : une frame World
of Warcraft ne se détruit pas.
