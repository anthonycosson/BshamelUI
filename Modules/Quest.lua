-- =========================================================================
--  Bshamel UI — Modules/Quest.lua
--  Automatisation des quêtes : acceptation et rendu.
--
--  Aucune frame, aucune couleur, aucune position : ce module décrit ses
--  réglages et réagit aux événements. C'est le gabarit à copier pour tout
--  nouveau module.
--
--  Réversibilité : tout est branché via `self:RegisterEvent`, donc désactiver le
--  module suffit à tout rendre au client — il n'y a rien à défaire dans
--  `OnDisable`.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local U    = BUI.Util
local L    = ns.L

local MODULE = "Quest"

-- =========================================================================
--  Garde-fous communs
-- =========================================================================

--- L'automatisation est-elle suspendue à cet instant ?
--- Deux raisons possibles : la touche de contournement est maintenue, ou le
--- joueur est en train de faire autre chose avec l'interface de quête.
---@param mod table
---@return boolean
local function suspended(mod)
    return U.IsModifierHeld(mod:Get("bypassModifier"))
end

--- Faut-il laisser cette quête tranquille parce qu'elle est triviale ?
---@param mod table
---@param isTrivial boolean|nil
---@return boolean
local function skipBecauseTrivial(mod, isTrivial)
    return mod:Get("skipTrivial") and isTrivial == true
end

-- =========================================================================
--  Acceptation
-- =========================================================================

local function onQuestDetail(mod)
    if not mod:Get("autoAccept") or suspended(mod) then return end

    local questID = GetQuestID and GetQuestID() or nil
    if questID and questID ~= 0 and C_QuestLog and C_QuestLog.IsQuestTrivial then
        if skipBecauseTrivial(mod, C_QuestLog.IsQuestTrivial(questID)) then return end
    end

    AcceptQuest()

    -- Une quête déclenchée par un objet ou par une zone s'accepte sans PNJ :
    -- la fenêtre reste alors ouverte et il faut la refermer nous-mêmes.
    if QuestGetAutoAccept and QuestGetAutoAccept() then
        CloseQuest()
    end
end

--- Quêtes qui demandent une confirmation supplémentaire (escortes, quêtes de
--- groupe déjà prises par un coéquipier).
local function onQuestAcceptConfirm(mod)
    if not mod:Get("autoAccept") or suspended(mod) then return end
    ConfirmAcceptQuest()
end

-- =========================================================================
--  Rendu
-- =========================================================================

local function onQuestProgress(mod)
    if not mod:Get("autoTurnIn") or suspended(mod) then return end
    if IsQuestCompletable and IsQuestCompletable() then
        CompleteQuest()
    end
end

local function onQuestComplete(mod)
    if not mod:Get("autoTurnIn") or suspended(mod) then return end

    -- Dès qu'il y a un vrai choix de récompense, on rend la main au joueur :
    -- prendre la récompense à sa place serait irréversible.
    if GetNumQuestChoices and GetNumQuestChoices() > 1 then return end

    GetQuestReward(1)
end

-- =========================================================================
--  Dialogues de PNJ
-- =========================================================================

--- Interface de dialogue moderne (`C_GossipInfo`).
local function onGossipShow(mod)
    if suspended(mod) then return end
    if not C_GossipInfo then return end

    if mod:Get("autoTurnIn") and C_GossipInfo.GetActiveQuests then
        for _, info in ipairs(C_GossipInfo.GetActiveQuests()) do
            if info.isComplete and not skipBecauseTrivial(mod, info.isTrivial) then
                C_GossipInfo.SelectActiveQuest(info.questID)
                return -- une seule interaction par ouverture : le client
                       -- renvoie GOSSIP_SHOW après chaque sélection
            end
        end
    end

    if mod:Get("autoAccept") and C_GossipInfo.GetAvailableQuests then
        for _, info in ipairs(C_GossipInfo.GetAvailableQuests()) do
            if not skipBecauseTrivial(mod, info.isTrivial) then
                C_GossipInfo.SelectAvailableQuest(info.questID)
                return
            end
        end
    end
end

--- Ancienne interface de salutation, encore utilisée par certains PNJ.
local function onQuestGreeting(mod)
    if suspended(mod) then return end

    if mod:Get("autoTurnIn") then
        for i = 1, GetNumActiveQuests() do
            local _, isComplete = GetActiveTitle(i)
            local isTrivial = IsActiveQuestTrivial and IsActiveQuestTrivial(i)
            if isComplete and not skipBecauseTrivial(mod, isTrivial) then
                SelectActiveQuest(i)
                return
            end
        end
    end

    if mod:Get("autoAccept") then
        for i = 1, GetNumAvailableQuests() do
            local isTrivial = IsAvailableQuestTrivial and IsAvailableQuestTrivial(i)
            if not skipBecauseTrivial(mod, isTrivial) then
                SelectAvailableQuest(i)
                return
            end
        end
    end
end

-- =========================================================================
--  Déclaration du module
-- =========================================================================

local MODIFIER_VALUES = {
    { value = "NONE",  label = L["None"] },
    { value = "SHIFT", label = L["Shift"] },
    { value = "CTRL",  label = L["Ctrl"] },
    { value = "ALT",   label = L["Alt"] },
}

BUI:RegisterModule(MODULE, {
    title    = L["Quest"],
    category = "QoL",
    order    = 10,

    defaults = {
        autoAccept     = false,
        autoTurnIn     = false,
        skipTrivial    = true,
        bypassModifier = "SHIFT",
    },

    options = {
        { type = "header", text = L["Automation"] },
        {
            type    = "toggle",
            key     = "autoAccept",
            text    = L["Auto-accept quests"],
            tooltip = L["Auto-accept quests tip"],
        },
        {
            type    = "toggle",
            key     = "autoTurnIn",
            text    = L["Auto-turn-in quests"],
            tooltip = L["Auto-turn-in quests tip"],
        },

        { type = "header", text = L["Filters"] },
        {
            type    = "toggle",
            key     = "skipTrivial",
            text    = L["Skip trivial quests"],
            tooltip = L["Skip trivial quests tip"],
            -- Inutile tant qu'aucune automatisation n'est active.
            disabled = function()
                local mod = BUI.Modules:Get(MODULE)
                return not (mod:Get("autoAccept") or mod:Get("autoTurnIn"))
            end,
        },
        {
            type    = "dropdown",
            key     = "bypassModifier",
            text    = L["Bypass modifier"],
            tooltip = L["Bypass modifier tip"],
            values  = MODIFIER_VALUES,
        },
    },

    OnEnable = function(self)
        self:RegisterEvent("QUEST_DETAIL",         function() onQuestDetail(self) end)
        self:RegisterEvent("QUEST_ACCEPT_CONFIRM", function() onQuestAcceptConfirm(self) end)
        self:RegisterEvent("QUEST_PROGRESS",       function() onQuestProgress(self) end)
        self:RegisterEvent("QUEST_COMPLETE",       function() onQuestComplete(self) end)
        self:RegisterEvent("GOSSIP_SHOW",          function() onGossipShow(self) end)
        self:RegisterEvent("QUEST_GREETING",       function() onQuestGreeting(self) end)
    end,

    -- Rien à défaire : le module n'a modifié aucune frame du client, et ses
    -- abonnements sont révoqués par le core.
    OnDisable = nil,
})
