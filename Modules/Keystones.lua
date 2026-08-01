-- =========================================================================
--  Bshamel UI — Modules/Keystones.lua
--  La clé mythique : la montrer, et la poser.
--
--  Deux gestes qu'on répète à chaque donjon. Répondre à « !keys » demande de
--  retrouver sa clé dans ses sacs et de la coller dans le chat ; poser la clé
--  demande d'ouvrir ses sacs devant le socle alors qu'on n'a rien d'autre à y
--  faire.
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
--  Déclaration du module
-- =========================================================================

BUI:RegisterModule(MODULE, {
    title    = L["Keystones"],
    category = "MythicRaid",
    order    = 10,

    defaults = {
        answerKeysRequest = false,
        autoSlotKeystone  = false,
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
        { type = "description", text = L["Keystones notice"] },
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
    end,

    OnDisable = function()
        wipe(answered)
    end,
})
