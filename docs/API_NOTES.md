# Notes d'API

Journal des pièges rencontrés dans l'API du client. Une entrée par problème
résolu : c'est la mémoire technique du projet, et ce qui évite de repayer deux
fois le même bug.

Format : **symptôme → cause → ce qu'on fait**.

---

## `xpcall` avec arguments

**Symptôme** — l'analyse statique signale « expects a maximum of 2 arguments »
sur `xpcall(fn, handler, ...)`.

**Cause** — le `xpcall` de Lua 5.1 standard ne transmet pas d'arguments à la
fonction appelée. Le client World of Warcraft a étendu le sien pour le faire.

**Ce qu'on fait** — on utilise la forme étendue (c'est la bonne au runtime) avec
un `---@diagnostic disable-next-line: redundant-parameter` et ce commentaire.
Ne pas « corriger » en enveloppant dans une closure : cela allouerait une
fonction à chaque dispatch d'événement.

---

## Templates XML

**Symptôme** — `CreateFrame` avec un template inconnu lève une erreur Lua qui
empêche le chargement du fichier entier.

**Cause** — les templates XML de Blizzard sont renommés ou retirés d'une
extension à l'autre.

**Ce qu'on fait** — `C_XMLUtil.GetTemplateInfo(nom)` répond avant de tenter la
création. `T.Template(kind)` encapsule ce test avec une liste de candidats.

---

## Titre d'une fenêtre

**Symptôme** — `frame.TitleText` vaut parfois `nil` selon la version du
template.

**Cause** — le FontString du titre a migré de `frame.TitleText` vers
`frame.TitleContainer.TitleText`.

**Ce qu'on fait** — `findTitleText` dans `UI/Widgets/Window.lua` teste les deux
et crée son propre FontString en dernier recours.

---

## Barre de défilement de `UIPanelScrollFrameTemplate`

**Symptôme** — la barre de défilement recouvre le contenu voisin.

**Cause** — le template ancre sa barre **à l'extérieur** du ScrollFrame, à sa
droite.

**Ce qu'on fait** — la place est réservée dans l'ancrage du ScrollFrame lui-même
(`T.SIZE.SCROLLBAR_W`), pas en réduisant la largeur du contenu.

---

## Ouvrir notre fenêtre depuis le panneau d'options du client

**Symptôme** — actions bloquées « interface action failed because of an AddOn »
après être passé par les options Blizzard.

**Cause** — appeler notre code dans la continuité directe d'un clic dans
`SettingsPanel` propage le taint du panneau.

**Ce qu'on fait** — `HideUIPanel(SettingsPanel)` puis `C_Timer.After(0, ...)`
pour ouvrir notre fenêtre à la frame suivante, hors de la pile d'appels tainted.

---

## `StaticPopupDialogs` et `preferredIndex`

**Symptôme** — un dialogue de confirmation provoque des erreurs de taint chez
certains joueurs.

**Cause** — les index bas de la pile de popups sont partagés avec des dialogues
du client.

**Ce qu'on fait** — `preferredIndex = 3` sur nos dialogues.

---

## Quêtes acceptées sans PNJ

**Symptôme** — après auto-acceptation, la fenêtre de quête reste ouverte.

**Cause** — une quête déclenchée par un objet ou par l'entrée dans une zone
passe par `QUEST_DETAIL` sans interaction PNJ ; le client ne referme pas la
fenêtre.

**Ce qu'on fait** — `if QuestGetAutoAccept() then CloseQuest() end` après
`AcceptQuest()`.

---

## Boucle de dialogue avec `GOSSIP_SHOW`

**Symptôme** — traiter toutes les quêtes d'un PNJ dans une seule passe
sélectionne la mauvaise.

**Cause** — chaque `SelectAvailableQuest` / `SelectActiveQuest` provoque un
nouveau `GOSSIP_SHOW` avec une liste modifiée.

**Ce qu'on fait** — une seule sélection par événement, puis `return`. Le client
nous rappelle.

---

## Récompenses de quête

**Symptôme** — une récompense est prise à la place du joueur.

**Cause** — `GetQuestReward(1)` sur une quête à choix multiple valide le premier
objet, sans retour possible.

**Ce qu'on fait** — l'automatisation s'arrête dès que
`GetNumQuestChoices() > 1`.
