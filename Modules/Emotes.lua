-- =========================================================================
--  Bshamel UI — Modules/Emotes.lua
--  Répondre tout seul à un emote qu'on nous adresse.
--
--  Aucune frame, aucune couleur : le module écoute une annonce du client et
--  joue un emote en retour. Tout est branché via `self:RegisterEvent`, donc
--  l'éteindre suffit à tout rendre — il n'y a rien à défaire dans `OnDisable`.
--
--  ## Ce que le client donne, et ce qu'il ne donne pas
--
--  `CHAT_MSG_TEXT_EMOTE` ne porte **aucun identifiant d'emote**. Ni jeton, ni
--  numéro : uniquement la phrase déjà rédigée, telle qu'elle s'affiche dans le
--  chat. C'est le premier fait qui décide de tout ce fichier, et il a été
--  vérifié plutôt que supposé (voir `dev/docs/API_NOTES.md`).
--
--  Le second fait sauve la mise : cette phrase est **rédigée par notre client à
--  nous**, dans notre langue. Le serveur n'envoie qu'un numéro d'emote et une
--  cible ; chaque client destinataire va chercher la formule dans ses propres
--  données. La langue de celui qui joue l'emote ne voyage donc jamais — un
--  joueur en russe qui nous fait `/kiss` produit chez nous la phrase française,
--  et la reconnaissance n'a jamais à s'en soucier.
--
--  ## Pourquoi la formule est une clé de traduction
--
--  Il reste à reconnaître la phrase, et aucune API ne la publie : les textes
--  d'emote vivent dans les données du client, pas dans ses `GlobalStrings` —
--  vérifié sur les deux locales. La formule est donc une chaîne qui dépend de la
--  langue, et sa place est celle de toutes les chaînes qui en dépendent : les
--  fichiers de locale.
--
--  Une locale que nous ne fournissons pas retombe sur l'anglais, ne reconnaît
--  rien, et le module **ne fait rien**. C'est la bonne dégradation : un emote
--  automatique qui part de travers se voit par tout le monde, là où un emote qui
--  ne part pas ne se voit par personne.
--
--  ## La réponse s'adresse à quelqu'un
--
--  Un `/non` lancé dans le vide ne répond à personne : c'est celui qui a fait
--  l'emote qu'il faut nommer. `DoEmote` prend une cible et `C_ChatInfo.PerformEmote`
--  n'en prend pas — c'est pourquoi le chemin le plus ancien est ici le principal
--  (voir `perform`).
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local U    = BUI.Util
local L    = ns.L

local MODULE = "Emotes"

--- Ce à quoi on répond, et par quoi.
---
--- Une table et non deux fonctions jumelles : les deux réponses ne diffèrent que
--- par la formule qu'elles guettent et la case qui les commande. Ajouter un
--- troisième emote doit être une ligne ici, quatre clés de locale, et rien
--- d'autre.
---
--- `answer` est un **jeton d'emote**, et les jetons ne sont pas traduits : c'est
--- le seul bout de cette table qui vaille dans toutes les langues sans être
--- écrit deux fois. `"NO"` joue `/non` en français comme `/no` en anglais.
local ANSWERS = {
    {
        key      = "noToKiss",
        answer   = "NO",
        patterns = L["Kiss received"],
        text     = L["Say no to kiss"],
        tooltip  = L["Say no to kiss tip"],
    },
    {
        key      = "noToHug",
        answer   = "NO",
        patterns = L["Hug received"],
        text     = L["Say no to hug"],
        tooltip  = L["Say no to hug tip"],
    },
}

-- Un frein entre deux réponses a vécu ici : une seule réponse toutes les trois
-- secondes, quel que soit le nombre d'emotes reçus. Il est **retiré**.
--
-- Le motif écrit alors était la protection du compte, en supposant que le
-- serveur compte les emotes et fasse taire qui en produit une rafale. La
-- supposition ne s'est pas vérifiée en jeu : rien n'indique une limite sur les
-- emotes. Et à supposer qu'elle existe, c'est le serveur qui l'appliquerait —
-- il n'a besoin de personne pour cela, et surtout pas de nous.
--
-- Ce que le frein coûtait, en revanche, se voyait : quelqu'un qui martèle sa
-- touche obtenait une réponse sur dix, ce qui ressemble à un réglage qui
-- décroche. On répond à chaque fois. C'est ce que la case promet.

--- La veille du `/bui emote` : écrit dans le chat le texte brut de chaque emote
--- reçu. Elle existe parce que la formule reconnue est une chaîne de locale, et
--- qu'une chaîne de locale fausse ne lève pas — le module reste simplement muet,
--- ce qui ressemble trait pour trait à un réglage décoché.
local watching = false

--- L'emote vient-il de nous ?
---
--- **Par le GUID d'abord**, qui est exact et ne se compare pas à un nom : le
--- client nous renvoie nos propres emotes, et en français « Vous embrassez Bob »
--- contient la formule « vous embrasse » que l'on guette. Sans ce garde, embrasser
--- quelqu'un déclenchait un `/non` adressé à soi-même.
---
--- Le nom sert de repli, débarrassé de son royaume : un emote venu d'ailleurs
--- s'écrit « Bob-Archimonde », le nôtre « Bob ».
---@param guid any
---@param sender any
---@return boolean
local function isSelf(guid, sender)
    if type(guid) == "string" and not U.IsSecret(guid) then
        return guid == UnitGUID("player")
    end

    if type(sender) ~= "string" or U.IsSecret(sender) then return false end

    local short = sender:match("^([^-]+)") or sender
    return short == UnitName("player")
end

--- Joue un emote, adressé à quelqu'un.
---
--- **`DoEmote` d'abord, et le plus récent en repli** — l'ordre inhabituel est le
--- sujet de cette fonction. `C_ChatInfo.PerformEmote` ne prend que le jeton :
--- l'emote part dans le vide, ou sur notre cible du moment, c'est-à-dire sur
--- n'importe qui sauf la bonne personne. `DoEmote` prend une cible, et c'est
--- tout ce qui compte ici. Le plus récent des deux chemins n'est pas le bon
--- quand il en fait moins.
---
--- **La cible est un nom, pas un jeton d'unité.** La documentation annonce un
--- `UnitToken`, mais c'est un nom que le client se passe à lui-même quand on
--- tape `/non Joséebovin` : son analyseur de commandes appelle `DoEmote(jeton,
--- reste_de_la_ligne)`. On fait le même geste, avec le nom que l'annonce nous a
--- donné — et il le faut, car un joueur qui nous fait un emote n'est presque
--- jamais notre cible, donc aucun jeton d'unité ne le désigne.
---
--- Sans cible — nom illisible ou secret —, l'emote part quand même : il est
--- alors ce qu'il aurait été sans ce module, plutôt que rien.
---@param token string
---@param target string|nil
local function perform(token, target)
    if type(DoEmote) == "function" then
        BUI.safecall(DoEmote, token, target)
    elseif C_ChatInfo and C_ChatInfo.PerformEmote then
        BUI.safecall(C_ChatInfo.PerformEmote, token)
    end
end

--- Le texte reçu porte-t-il l'une des formules cherchées ?
---
--- **Plusieurs formules par emote, séparées par `;`.** Une seule ne suffisait
--- pas, et l'essai en jeu l'a montré du premier coup : la phrase française d'un
--- `/kiss` n'est pas « vous embrasse » mais « vous envoie un baiser ». Une
--- formule est un relevé, pas une déduction — et un relevé se corrige, se double
--- d'une variante, survit à une tournure que Blizzard réécrit.
---
--- Comparaison **sans casse et en clair** : `find` en mode littéral, parce
--- qu'une formule de locale est une phrase et non un motif Lua — un tiret ou une
--- parenthèse dans une traduction ferait autrement un motif silencieusement
--- faux.
---
--- Une formule vide ne reconnaît rien : c'est ce que rend une locale sans
--- traduction, et il ne faut surtout pas que le vide réponde « oui ».
---@param text string  déjà en minuscules
---@param patterns any
---@return boolean
local function carries(text, patterns)
    if type(patterns) ~= "string" or patterns == "" then return false end

    for piece in patterns:lower():gmatch("[^;]+") do
        if text:find(piece, 1, true) then return true end
    end

    return false
end

--- Un emote vient d'arriver dans le chat.
---@param mod table
---@param text any
---@param sender any
---@param guid any
local function onTextEmote(mod, text, sender, guid)
    -- Le garde de secret avant toute manipulation : une chaîne secrète ne
    -- s'indexe pas plus qu'elle ne se met en minuscules.
    if type(text) ~= "string" or U.IsSecret(text) then return end

    if watching then
        mod:Print(L["Emote seen"], text)
    end

    if isSelf(guid, sender) then return end

    local lowered = text:lower()

    for i = 1, #ANSWERS do
        local rule = ANSWERS[i]
        if mod:Get(rule.key) and carries(lowered, rule.patterns) then
            -- Le nom part tel que l'annonce l'a écrit, royaume compris : c'est
            -- ce que le joueur taperait, et le client sait le lire. Un nom
            -- secret ne se transmet pas — l'emote part alors sans cible.
            local target = (type(sender) == "string" and not U.IsSecret(sender))
                           and sender or nil

            perform(rule.answer, target)
            return
        end
    end
end

-- =========================================================================
--  Déclaration du module
-- =========================================================================

BUI:RegisterModule(MODULE, {
    title    = L["Emotes"],
    category = "Fun",
    order    = 10,

    defaults = {
        noToKiss = false,
        noToHug  = false,
    },

    options = {
        { type = "header", text = L["Answer by yourself"] },
        {
            type    = "toggle",
            key     = "noToKiss",
            text    = ANSWERS[1].text,
            tooltip = ANSWERS[1].tooltip,
        },
        {
            type    = "toggle",
            key     = "noToHug",
            text    = ANSWERS[2].text,
            tooltip = ANSWERS[2].tooltip,
        },
    },

    --- `/bui emote` : écrit le texte brut de chaque emote reçu.
    ---
    --- Ce que le module reconnaît est une phrase, et une phrase mal orthographiée
    --- dans un fichier de locale **ne lève pas** : le module se tait, ce qui
    --- ressemble exactement à une case décochée. Cette veille est le seul moyen
    --- de voir ce que le client écrit vraiment, mot pour mot, et de corriger la
    --- formule plutôt que de la deviner.
    ---@return boolean  l'état après bascule
    ToggleWatch = function()
        watching = not watching
        return watching
    end,

    OnEnable = function(self)
        self:RegisterEvent("CHAT_MSG_TEXT_EMOTE",
            function(_, text, sender, _, _, _, _, _, _, _, _, _, guid)
                onTextEmote(self, text, sender, guid)
            end)
    end,

    -- Rien à défaire : l'abonnement est révoqué par le core, et le module n'a
    -- rien posé nulle part. La veille s'éteint quand même — elle écrit dans le
    -- chat, et un module éteint doit être indétectable (règle 6).
    OnDisable = function()
        watching = false
    end,
})
