-- =========================================================================
--  Bshamel UI — Modules/Keystones.lua
--  La clé mythique : la montrer, la poser, et parler aux PNJ du donjon.
--
--  Trois gestes qu'on répète à chaque donjon. Répondre à « !keys » demande de
--  retrouver sa clé dans ses sacs et de la coller dans le chat ; poser la clé
--  demande d'ouvrir ses sacs devant le socle alors qu'on n'a rien d'autre à y
--  faire ; et la moitié des donjons ouvre une fenêtre de dialogue à une seule
--  ligne — les prisonniers de la Fosse de Saron, le bienfait du début
--  d'Académie Algeth'ar — dont le seul contenu est « oui ».
--
--  **La clé se cherche dans les sacs, pas dans une API.** Le client publie bien
--  le donjon et le niveau (`C_MythicPlus`), mais pas le **lien** : or c'est le
--  lien qu'on veut envoyer, parce qu'il est survolable par ceux qui le lisent.
--  Les deux chemins sont donc là, dans cet ordre : le lien s'il est trouvé, le
--  texte sinon.
--
--  Réversibilité : le module n'écoute que des événements, révoqués par le core.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local U    = BUI.Util
local L    = ns.L

local MODULE = "Keystones"

--- Identifiant de l'objet « clé mythique ». Une donnée de jeu : elle ne sert
--- qu'à reconnaître la clé dans les sacs, en second recours — le lien porte
--- normalement le mot-clé `keystone`.
local KEYSTONE_ITEM = 180653

--- Événements écoutés -> canal de réponse. C'est aussi la liste de ce à quoi on
--- accepte de répondre : un chuchotement n'y est pas, la question ne s'y pose
--- pas, et répondre dans un canal public serait de la publicité.
---
--- La guilde y est, et c'est voulu : « !keys » s'y tape la veille d'une soirée
--- pour savoir qui a quoi, et c'est même le seul endroit où la question serve
--- vraiment à composer un groupe. La réponse part alors en guilde, pas ailleurs —
--- le canal de la réponse est toujours celui de la demande.
---
--- Le canal officier (`CHAT_MSG_OFFICER`) n'y est pas : c'est un canal séparé de
--- la guilde, et une réponse automatique n'a rien à y faire.
local CHANNELS = {
    CHAT_MSG_PARTY                = "PARTY",
    CHAT_MSG_PARTY_LEADER         = "PARTY",
    CHAT_MSG_RAID                 = "RAID",
    CHAT_MSG_RAID_LEADER          = "RAID",
    CHAT_MSG_INSTANCE_CHAT        = "INSTANCE_CHAT",
    CHAT_MSG_INSTANCE_CHAT_LEADER = "INSTANCE_CHAT",
    CHAT_MSG_GUILD                = "GUILD",
}

--- Sursis entre deux réponses, en secondes. Cinq personnes qui tapent « !keys »
--- coup sur coup, ou le même message vu sur deux canaux, ne doivent produire
--- qu'une réponse : au-delà, c'est le serveur qui coupe la parole.
local ANSWER_COOLDOWN = 10

--- canal -> instant de la dernière réponse
local answered = {}

-- =========================================================================
--  Retrouver la clé
-- =========================================================================

--- Ce lien est-il une clé mythique ?
---@param link string
---@return boolean
local function isKeystone(link)
    if link:find("keystone:", 1, true) then return true end

    if C_Item and C_Item.GetItemInfoInstant then
        local id = C_Item.GetItemInfoInstant(link)
        return id == KEYSTONE_ITEM
    end
    return false
end

--- Clé du personnage, et l'emplacement où elle est rangée.
---@return string|nil link, number|nil bag, number|nil slot
local function findKeystone()
    if not (C_Container and C_Container.GetContainerNumSlots) then return nil end

    -- `NUM_BAG_SLOTS` est le nombre de sacs portés ; le sac 0 est le sac de dos,
    -- d'où la boucle qui commence à zéro.
    local lastBag = NUM_BAG_SLOTS or 4

    for bag = 0, lastBag do
        for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
            local link = C_Container.GetContainerItemLink(bag, slot)
            if link and isKeystone(link) then return link, bag, slot end
        end
    end

    return nil
end

--- Ce que le personnage possède, dit en toutes lettres. Sert de repli quand le
--- lien n'a pas été trouvé — la clé peut être dans la banque, ou le format du
--- lien peut avoir changé.
---@return string|nil
local function keystoneText()
    if not (C_MythicPlus and C_MythicPlus.GetOwnedKeystoneMapID) then return nil end

    local mapID = C_MythicPlus.GetOwnedKeystoneMapID()
    local level = C_MythicPlus.GetOwnedKeystoneLevel and C_MythicPlus.GetOwnedKeystoneLevel()
    if not (mapID and level) then return nil end

    local name = C_ChallengeMode and C_ChallengeMode.GetMapUIInfo
                 and C_ChallengeMode.GetMapUIInfo(mapID)
    if not name then return nil end

    return string.format("%s +%d", name, level)
end

--- La réponse à envoyer : le lien s'il existe, le texte sinon, et l'aveu qu'on
--- n'a pas de clé en dernier ressort. Il y a toujours une réponse : le silence
--- se lit comme « il n'a pas vu le message », et la question serait reposée.
---@return string
local function answer()
    local link = findKeystone()
    if link then return link end

    local text = keystoneText()
    if text then return text end

    return L["No keystone"]
end

-- =========================================================================
--  Répondre à « !keys »
-- =========================================================================

--- **On répond aussi à sa propre demande.** C'est le seul geste qui laisse
--- vérifier le réglage sans avoir à trouver quelqu'un pour taper « !keys » à sa
--- place — et en groupe, celui qui pose la question est souvent celui qui
--- rappelle à tout le monde de répondre. La réponse ne peut pas relancer
--- l'écoute : ni un lien de clé, ni « Donjon +N », ni « Pas de clé. » ne
--- commencent par « !keys », et le sursis de `ANSWER_COOLDOWN` couvre le reste.
---@param mod table
---@param event string
---@param text string
local function onChatMessage(mod, event, text)
    if not mod:Get("answerKeysRequest") then return end

    -- **L'ordre des deux tests n'est pas indifférent.** Une chaîne secrète a bien
    -- le type `string` : c'est `string.lower` qui lèverait, et l'erreur partirait
    -- dans BugSack au lieu de se voir ici — le symptôme serait « !keys ne
    -- répond pas », pas « une erreur ». Un message qu'on ne peut pas lire n'est
    -- pas une demande qu'on peut reconnaître (voir `Modules/Chat.lua`).
    if type(text) ~= "string" or U.IsSecret(text) then return end

    -- La demande est en début de message et rien d'autre ne compte : « !keys »,
    -- « !key », et la variante avec une majuscule. Un message qui *contient*
    -- « !keys » au milieu d'une phrase n'est pas une demande.
    if not string.find(string.lower(text), "^%s*!keys?") then return end

    local channel = CHANNELS[event]
    if not channel then return end

    local now  = GetTime()
    local last = answered[channel]
    if last and (now - last) < ANSWER_COOLDOWN then return end
    answered[channel] = now

    SendChatMessage(answer(), channel)
end

-- =========================================================================
--  Poser la clé sur le socle
-- =========================================================================

---@param mod table
local function slotKeystone(mod)
    if not mod:Get("autoSlotKeystone") then return end
    if not (C_ChallengeMode and C_ChallengeMode.SlotKeystone) then return end

    -- Une clé déjà posée — la nôtre ou celle d'un coéquipier — ne se remplace
    -- pas : le choix de la clé appartient au groupe.
    if C_ChallengeMode.HasSlottedKeystone and C_ChallengeMode.HasSlottedKeystone() then
        return
    end

    -- Le curseur porte déjà quelque chose : le prendre en main ferait tomber ce
    -- que le joueur était en train de déplacer.
    if GetCursorInfo and GetCursorInfo() then return end

    local _, bag, slot = findKeystone()
    if not bag then return end

    C_Container.PickupContainerItem(bag, slot)
    C_ChallengeMode.SlotKeystone()

    -- Si le socle a refusé la clé, elle reste accrochée au curseur : on la
    -- repose plutôt que de la laisser suivre la souris.
    if GetCursorInfo and GetCursorInfo() and ClearCursor then ClearCursor() end
end

-- =========================================================================
--  Parler aux PNJ du donjon
-- =========================================================================

--- Le seul type d'instance où on clique à la place du joueur. Un donjon, et
--- rien d'autre : c'est là que le dialogue est une formalité imposée à cinq
--- personnes pressées. Dehors, une fenêtre de dialogue est une conversation, et
--- personne n'a demandé qu'on la mène.
local DUNGEON_INSTANCE = "party"

--- Options déjà cliquées depuis l'ouverture de la fenêtre courante.
---
--- **C'est le garde anti-boucle.** Chaque sélection provoque un nouveau
--- `GOSSIP_SHOW` (voir `dev/docs/API_NOTES.md`, « Boucle de dialogue avec
--- `GOSSIP_SHOW` ») : une ligne qui se contente de rouvrir le même menu se
--- recliquerait indéfiniment. Une ligne ne se clique donc qu'une fois par
--- conversation — enchaîner deux sous-menus différents reste possible, se
--- répéter non. La table se vide à la fermeture de la fenêtre, si bien que le
--- PNJ qui redonne un bienfait répond encore quand on retourne le voir.
local gossipClicked = {}

--- Sommes-nous dans un donjon ?
--- Le type d'instance arrive du client : il se teste après `U.IsSecret`, jamais
--- avant (CLAUDE.md, et la note « Un booléen secret ne se teste pas »).
---@return boolean
local function inDungeon()
    local _, instanceType = IsInInstance()
    if U.IsSecret(instanceType) then return false end
    return instanceType == DUNGEON_INSTANCE
end

--- Ce dialogue porte-t-il une quête ?
---
--- Si oui, il ne nous regarde pas : les quêtes ont leur propre page, avec ses
--- propres réglages. Un joueur qui a allumé le dialogue de donjon sans allumer
--- l'acceptation automatique n'a pas demandé qu'on prenne une quête à sa place.
---@return boolean
local function gossipHasQuests()
    local available = C_GossipInfo.GetAvailableQuests and C_GossipInfo.GetAvailableQuests()
    if available and #available > 0 then return true end

    local active = C_GossipInfo.GetActiveQuests and C_GossipInfo.GetActiveQuests()
    return (active and #active > 0) == true
end

--- **Une seule ligne, ou rien.** Dès qu'un PNJ propose un choix, le choix est
--- au joueur : c'est la même règle que la récompense de quête à choix multiple.
--- Ce qui reste — « Nous sommes prêts », « Libère-moi », « Prends ce bienfait » —
--- est exactement ce qu'on venait cliquer.
---@param mod table
local function autoGossip(mod)
    if not mod:Get("autoDungeonGossip") then return end
    if not (C_GossipInfo and C_GossipInfo.GetOptions and C_GossipInfo.SelectOption) then return end
    if not inDungeon() then return end
    if gossipHasQuests() then return end

    local options = C_GossipInfo.GetOptions()
    if not options or #options ~= 1 then return end

    -- L'identifiant sert de clé dans `gossipClicked` : le garde de secret vient
    -- donc avant l'indexation, pas après.
    local id = options[1].gossipOptionID
    if id == nil or U.IsSecret(id) or gossipClicked[id] then return end

    gossipClicked[id] = true
    C_GossipInfo.SelectOption(id)
end

-- =========================================================================
--  Le suivi d'objectifs pendant une clé
-- =========================================================================
-- En donjon, le suivi d'objectifs porte le chrono de la clé, la liste des boss
-- et le décompte des troupes — et, sous tout cela, la campagne, les hauts faits
-- et les quêtes ramassées en chemin. Une clé se court en regardant ce coin de
-- l'écran : ce qui n'est pas la clé y est du bruit, et le bruit y est en bas de
-- ce qu'on lit.
--
-- **On ne redemande jamais de passe de mise en page.** Ni `MarkDirty`, ni
-- `RemoveModule` qui en programme une : une passe partie de notre pile et
-- refusée en combat laisse le drapeau « sale » levé, et le suivi ne se remet
-- plus en page de la session — `/reload` pour seul remède. C'est arrivé deux
-- fois (voir `dev/docs/API_NOTES.md`, « Le suivi d'objectifs ne se répare
-- pas »). Tout ce qui suit se contente donc de **cacher des cadres**, ce qui ne
-- relève d'aucune mise en page, et de le refaire après chaque passe du client.
--
-- Rien n'est déplacé pour autant : le module de scénario est le premier du
-- suivi (`ObjectiveTrackerManager:Init`), donc cacher les autres laisse du vide
-- sous lui, jamais un trou au milieu. Ce vide ne se voit pas — le fond du suivi
-- est transparent.

--- Faut-il taire le reste du suivi à cet instant ?
---
--- Une clé qui tourne, et rien d'autre : hors donjon mythique+, un réglage de
--- clé n'a pas à décider de ce que montre le suivi d'objectifs.
---@param mod table
---@return boolean
local function hushTracker(mod)
    if not mod:Get("keyTimerOnly") then return false end
    if not (C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID) then return false end
    return C_ChallengeMode.GetActiveChallengeMapID() ~= nil
end

--- Cache ce module du suivi, ou le rend au client.
---
--- `hush` arrive en argument et ne se relit pas ici : à l'extinction du module,
--- la case peut être encore cochée et la clé encore en cours, et c'est pourtant
--- le suivi entier qu'il faut rendre.
---@param hush boolean
---@param tracked table
local function focusModule(hush, tracked)
    if hush then
        -- Un module en train de glisser se cacherait au milieu de son
        -- glissement : `OnHide` appelle `EndSlide`, qui rend la main au module
        -- et peut le resalir. On le laisse finir — la passe suivante le
        -- reprendra, et une passe suivante il y en a toujours une tant qu'un
        -- glissement est en cours.
        if tracked.IsSliding and tracked:IsSliding() then return end
        tracked:Hide()
        return
    end

    -- Rendre, c'est refaire exactement ce que `EndLayout` du client vient de
    -- faire : un module se montre s'il a du contenu affichable et si le suivi
    -- n'est pas replié. On ne décide rien d'autre, et on ne recalcule rien.
    if not tracked.IsDisplayable then return end

    local frame     = ObjectiveTrackerFrame
    local collapsed = frame and frame.IsCollapsed and frame:IsCollapsed()
    tracked:SetShown(tracked:IsDisplayable() and not collapsed)
end

--- Les deux fonctions du hook, construites une fois pour la session : elles se
--- reposent sur chaque module du suivi, et en fabriquer une paire par passage
--- serait de l'ordure à chaque donjon (règle 7).
local hookBody, hookGuard

--- Pose sur ce module du suivi le hook qui le tiendra caché.
---
--- Sur `Update` du module et non sur celui du suivi : le suivi capture sa propre
--- `Update` dans `SetDirtyMethod` au chargement, et l'appelle par cette
--- référence-là — un hook posé après coup ne serait jamais vu par le chemin
--- normal. Les modules, eux, sont appelés par leur champ (`module:Update(…)`).
---@param mod table
---@param tracked table
local function hookModule(mod, tracked)
    if not hookBody then
        hookBody  = function(self) focusModule(hushTracker(mod), self) end
        hookGuard = function() return mod:IsEnabled() end
    end

    U.GuardedHook(tracked, "Update", hookBody, hookGuard)
end

--- Passe sur tous les modules du suivi sauf celui de la clé.
---
--- `mod` vaut `nil` quand on ne fait que rendre — le module s'éteint, il n'y a
--- plus de hook à poser ni de réglage à consulter.
---@param mod table|nil
local function sweepTracker(mod)
    local frame = ObjectiveTrackerFrame
    local list  = frame and frame.modules
    if type(list) ~= "table" then return end

    local hush = mod ~= nil and hushTracker(mod)

    -- Le module qui porte la clé — chrono, boss, troupes — est le seul qu'on
    -- garde. Il se relit à chaque passage plutôt que d'être retenu : il naît
    -- avec l'interface du client, pas avec nous.
    local key = ScenarioObjectiveTracker

    for i = 1, #list do
        local tracked = list[i]
        if type(tracked) == "table" and tracked ~= key and tracked.Hide and tracked.Update then
            if mod then hookModule(mod, tracked) end
            focusModule(hush, tracked)
        end
    end
end

-- =========================================================================
--  Déclaration du module
-- =========================================================================

BUI:RegisterModule(MODULE, {
    title    = L["Keystones"],
    category = "QoL",
    order    = 70,

    defaults = {
        answerKeysRequest = false,
        autoSlotKeystone  = false,
        autoDungeonGossip = false,
        keyTimerOnly      = false,
    },

    options = {
        { type = "header", text = L["Automation"] },
        {
            type    = "toggle",
            key     = "answerKeysRequest",
            text    = L["Answer keys request"],
            tooltip = L["Answer keys request tip"],
        },
        {
            type    = "toggle",
            key     = "autoSlotKeystone",
            text    = L["Auto slot keystone"],
            tooltip = L["Auto slot keystone tip"],
        },
        { type = "header", text = L["Objective tracker"] },
        {
            type    = "toggle",
            key     = "keyTimerOnly",
            text    = L["Key timer only"],
            tooltip = L["Key timer only tip"],
        },
        { type = "header", text = L["Dungeon dialogue"] },
        {
            type    = "toggle",
            key     = "autoDungeonGossip",
            text    = L["Auto dungeon gossip"],
            tooltip = L["Auto dungeon gossip tip"],
        },
    },

    OnEnable = function(self)
        for event in pairs(CHANNELS) do
            -- Le premier argument d'un événement de chat est le texte, et c'est
            -- le seul qui compte ici : plus rien ne se lit sur l'auteur.
            self:RegisterEvent(event, function(name, text)
                onChatMessage(self, name, text)
            end)
        end

        -- **Ne pas « corriger » l'orthographe de cette ligne.**
        --
        -- `RECEPTABLE` est une coquille de Blizzard, présente dans son API depuis
        -- toujours, et `OPEN` n'a pas de participe passé. Le nom correctement
        -- orthographié — `..._RECEPTACLE_OPENED` — ne désigne **rien** : le
        -- client lève alors « Attempt to register unknown event », et tout ce qui
        -- suivrait dans cet `OnEnable` ne serait jamais branché.
        --
        -- C'est arrivé une fois. Voir `dev/docs/API_NOTES.md`, « Un nom
        -- d'événement inconnu lève, et emporte la moitié d'un module ».
        self:RegisterEvent("CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN", function()
            slotKeystone(self)
        end)

        self:RegisterEvent("GOSSIP_SHOW",   function() autoGossip(self) end)
        -- La conversation est finie : ce qu'on a cliqué dedans ne vaut plus rien.
        self:RegisterEvent("GOSSIP_CLOSED", function() wipe(gossipClicked) end)

        -- Les moments où la réponse à « une clé tourne-t-elle ? » change. Le
        -- hook des modules du suivi fait le reste, passe après passe ; ces
        -- quatre-là sont ce qui le pose la première fois, et ce qui rend le
        -- suivi à la fin d'une clé sans attendre qu'une passe veuille bien
        -- venir.
        local sweep = function() sweepTracker(self) end
        self:RegisterEvent("PLAYER_ENTERING_WORLD",    sweep)
        self:RegisterEvent("CHALLENGE_MODE_START",     sweep)
        self:RegisterEvent("CHALLENGE_MODE_COMPLETED", sweep)
        self:RegisterEvent("CHALLENGE_MODE_RESET",     sweep)

        sweepTracker(self)
    end,

    OnDisable = function()
        wipe(answered)
        wipe(gossipClicked)

        -- Le hook devient inerte tout seul, mais ce qu'il avait caché le
        -- resterait : éteindre le module doit le rendre indétectable (règle 6).
        sweepTracker(nil)
    end,

    OnSettingChanged = function(self)
        sweepTracker(self)
    end,
})
