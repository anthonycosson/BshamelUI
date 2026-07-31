-- =========================================================================
--  Bshamel UI — Modules/GroupFinder.lua
--  Ce qui entoure une inscription : la note, la confirmation, et le rappel.
--
--  Trois agacements de la recherche de groupe, qui n'ont en commun que le
--  moment où on les rencontre :
--
--   · la **note d'inscription** se retape à chaque candidature, alors que c'est
--     la même depuis six mois ;
--   · la **vérification des rôles** demande de cliquer sur un bouton pour dire
--     ce qu'on a déjà dit en s'inscrivant ;
--   · le **donjon rejoint** s'oublie dès qu'on retourne à autre chose, et rien à
--     l'écran ne le rappelle.
--
--  La note est une **donnée**, pas un réglage : elle vit dans le SavedVariables
--  du personnage (`DB:CharData`), hors du mécanisme de défauts — c'est le même
--  chemin que l'historique de chat, et pour la même raison.
--
--  Réversibilité : la bannière se ferme, et les deux scripts posés sur la
--  fenêtre d'inscription passent par `U.GuardedScript`, donc deviennent inertes
--  quand le module s'éteint (règle 6).
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local U    = BUI.Util
local W    = BUI.Widgets
local L    = ns.L

local MODULE = "GroupFinder"

-- =========================================================================
--  Note d'inscription
-- =========================================================================

--- Zone de saisie de la note, ou `nil` tant que la recherche de groupe n'est pas
--- montée : sa fenêtre est chargée à la demande.
---@return table|nil
local function noteBox()
    local dialog = LFGListApplicationDialog
    local body   = dialog and dialog.Description
    local box    = body and body.EditBox
    if box and box.GetText then return box end
    return nil
end

---@param mod table
local function hookSignupNote(mod)
    local dialog = LFGListApplicationDialog
    if not (dialog and noteBox()) then return end

    local guard = function()
        return mod:IsEnabled() and mod:Get("keepSignupNote") == true
    end

    -- À l'ouverture, on ne remplit qu'une zone **vide** : le client y met parfois
    -- lui-même quelque chose, et écraser ce qu'il a écrit serait le contredire.
    U.GuardedScript(dialog, "OnShow", function()
        local box = noteBox()
        if not box then return end
        if box:GetText() ~= "" then return end

        local note = mod:CharData().signupNote
        if note and note ~= "" then box:SetText(note) end
    end, guard)

    -- À la fermeture, on relève ce qui est écrit, que la candidature soit partie
    -- ou non : une note abandonnée est justement celle qu'on veut retrouver.
    U.GuardedScript(dialog, "OnHide", function()
        local box = noteBox()
        if not box then return end
        mod:CharData().signupNote = box:GetText()
    end, guard)
end

-- =========================================================================
--  Confirmations
-- =========================================================================

---@param mod table
local function onRoleCheck(mod)
    if not mod:Get("autoRoleCheck") then return end
    if CompleteLFGRoleCheck then CompleteLFGRoleCheck(true) end
end

--- Une candidature est-elle en cours ? C'est ce qui distingue une invitation
--- *attendue* d'une invitation reçue de n'importe qui : sans cette question, le
--- réglage ferait accepter tous les groupes du jeu.
---@return boolean
local function hasPendingApplication()
    if not (C_LFGList and C_LFGList.GetApplications and C_LFGList.GetApplicationInfo) then
        return false
    end

    local applications = C_LFGList.GetApplications()
    for i = 1, #applications do
        local _, status, pending = C_LFGList.GetApplicationInfo(applications[i])
        if status == "applied" or status == "invited" or pending == "applied" then
            return true
        end
    end
    return false
end

---@param mod table
local function onInvite(mod)
    if not mod:Get("autoAcceptInvite") then return end
    if not hasPendingApplication() then return end

    if AcceptGroup then AcceptGroup() end
    -- Le dialogue du client reste ouvert après une acceptation par le code : il
    -- attend son propre bouton. On le referme, sinon il faut cliquer « Refuser »
    -- sur un groupe qu'on vient de rejoindre.
    if StaticPopup_Hide then StaticPopup_Hide("PARTY_INVITE") end
end

-- =========================================================================
--  Rappel du donjon rejoint
-- =========================================================================

local reminder

--- Nom réduit à ce qui se compare : minuscules, et sans la précision que la
--- recherche de groupe ajoute souvent entre parenthèses.
---@param name string
---@return string
local function comparable(name)
    return string.lower(strtrim(name:match("^[^(]+") or name))
end

--- Téléportation qui mène à ce donjon, ou `nil`.
---
--- **On ne tient aucune liste de sorts.** Le client publie la téléportation d'un
--- donjon en **septième valeur** de `GetMapUIInfo`, là où il la publie — ailleurs
--- elle vaut `nil`, ce qui est exactement le test de capacité voulu. C'est le
--- même chemin que le menu de téléportation de la minicarte (voir
--- `dev/docs/API_NOTES.md`).
---
--- La table des cartes est celle de la **saison en cours**, ce qui suffit ici :
--- on ne rejoint pas une clé hors saison. Un donjon qui n'y est pas ne donne
--- simplement pas de bouton.
---@param dungeon string
---@return number|nil
local function teleportFor(dungeon)
    if type(dungeon) ~= "string" or dungeon == "" then return nil end
    if not (C_ChallengeMode and C_ChallengeMode.GetMapTable
            and C_ChallengeMode.GetMapUIInfo) then
        return nil
    end

    local needle = comparable(dungeon)
    if needle == "" then return nil end

    local maps = C_ChallengeMode.GetMapTable() or {}
    for i = 1, #maps do
        local name, _, _, _, _, _, spellID = C_ChallengeMode.GetMapUIInfo(maps[i])
        if type(name) == "string" and spellID then
            -- Les deux noms viennent du client, donc de la même langue : l'un
            -- contient l'autre, dans un sens ou dans l'autre selon que
            -- l'activité porte une précision ou un raccourci.
            local candidate = comparable(name)
            local found = string.find(needle, candidate, 1, true)
                          or string.find(candidate, needle, 1, true)

            if found and (not IsPlayerSpell or IsPlayerSpell(spellID)) then
                return spellID
            end
        end
    end
    return nil
end

--- Nom de ce à quoi correspond un résultat de recherche.
---@param resultID number
---@return string|nil
local function activityName(resultID)
    if not (C_LFGList and C_LFGList.GetSearchResultInfo) then return nil end

    local result = C_LFGList.GetSearchResultInfo(resultID)
    if not result then return nil end

    local activityID = result.activityID
                       or (result.activityIDs and result.activityIDs[1])

    if activityID and C_LFGList.GetActivityInfoTable then
        local activity = C_LFGList.GetActivityInfoTable(activityID)
        if activity then
            return activity.fullName or activity.shortName or result.name
        end
    end

    -- Sans activité lisible, le nom que le groupe s'est donné vaut mieux que
    -- rien : c'est ce que le joueur a lu au moment de s'inscrire.
    return result.name
end

---@param mod table
---@return table|nil
local function getReminder(mod)
    if reminder then return reminder end

    reminder = W.QueueReminder({
        teleportLabel = L["Teleport"],
        getPos = function() return mod:Get("reminderX"), mod:Get("reminderY") end,
        setPos = function(x, y)
            mod:Set("reminderX", x)
            mod:Set("reminderY", y)
        end,
    })
    return reminder
end

---@param mod table
---@param resultID number
local function announceJoin(mod, resultID)
    if not mod:Get("queueReminder") then return end

    local name = activityName(resultID)
    if not name then return end

    local panel = getReminder(mod)
    if not panel then return end

    local spellID = teleportFor(name)
    local icon    = spellID and C_Spell and C_Spell.GetSpellTexture
                    and C_Spell.GetSpellTexture(spellID) or nil

    panel:Announce(name, icon, spellID)
end

--- Le rappel a fait son travail dès qu'on est entré, et il n'a rien à faire à
--- l'écran pendant un combat.
local function dismissReminder()
    if reminder then reminder:Dismiss() end
end

-- =========================================================================
--  Déclaration du module
-- =========================================================================

BUI:RegisterModule(MODULE, {
    title    = L["Group finder"],
    category = "MythicRaid",
    order    = 15,

    -- En avant-première : le code est écrit, il n'a pas encore été vérifié en
    -- jeu (CLAUDE.md règle 10, points 3 à 5). Tant que cette ligne est là, le
    -- core refuse d'allumer le module — la retirer est le seul geste qui livre
    -- la page.
    preview  = true,

    defaults = {
        keepSignupNote   = false,
        autoRoleCheck    = false,
        autoAcceptInvite = false,

        queueReminder = false,
        -- Position de la bannière, en décalage de centre à centre. Elle s'ouvre
        -- au-dessus du centre de l'écran, là où le regard passe, et se déplace à
        -- la souris.
        reminderX = 0,
        reminderY = 180,
    },

    options = {
        { type = "header", text = L["Signing up"] },
        {
            type    = "toggle",
            key     = "keepSignupNote",
            text    = L["Keep signup note"],
            tooltip = L["Keep signup note tip"],
        },
        {
            type    = "toggle",
            key     = "autoRoleCheck",
            text    = L["Auto role check"],
            tooltip = L["Auto role check tip"],
        },
        {
            type    = "toggle",
            key     = "autoAcceptInvite",
            text    = L["Auto accept invite"],
            tooltip = L["Auto accept invite tip"],
        },

        { type = "header", text = L["Queues"] },
        {
            type    = "toggle",
            key     = "queueReminder",
            text    = L["Queue reminder"],
            tooltip = L["Queue reminder tip"],
        },
        { type = "description", text = L["Queue reminder notice"] },
    },

    OnEnable = function(self)
        hookSignupNote(self)

        -- La fenêtre d'inscription est chargée à la demande : elle peut
        -- n'exister qu'une fois la recherche de groupe ouverte. On retente une
        -- fois la rafale retombée ; `U.GuardedScript` ne pose jamais deux fois
        -- le même script.
        local settle = U.Debounce(T.TIMING.CHAT_SETTLE, function() hookSignupNote(self) end)
        self:RegisterEvent("ADDON_LOADED",                    settle)
        self:RegisterEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED", settle)
        self:RegisterEvent("LFG_LIST_AVAILABILITY_UPDATE",     settle)

        self:RegisterEvent("LFG_ROLE_CHECK_SHOW",  function() onRoleCheck(self) end)
        self:RegisterEvent("PARTY_INVITE_REQUEST", function() onInvite(self) end)

        self:RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED",
            function(_, resultID, status)
                if status == "inviteaccepted" then announceJoin(self, resultID) end
            end)

        -- « Jusqu'au combat ou jusqu'à l'entrée » : les deux fins possibles du
        -- rappel, plus la sortie de combat qui termine ce que le combat avait
        -- refusé (voir `UI/Widgets/QueueReminder.lua`).
        self:RegisterEvent("PLAYER_REGEN_DISABLED",  dismissReminder)
        self:RegisterEvent("PLAYER_ENTERING_WORLD",  dismissReminder)
        self:RegisterEvent("PLAYER_REGEN_ENABLED",   function()
            if reminder then reminder:Settle() end
        end)
    end,

    -- `Dismiss` et rien de plus : la bannière porte un bouton sécurisé, que le
    -- client refuse de cacher en combat. Elle devient alors invisible et se
    -- ferme pour de bon à la sortie de combat.
    OnDisable = dismissReminder,
})
