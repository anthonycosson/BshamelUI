-- =========================================================================
--  Bshamel UI — Modules/GroupFinder.lua
--  Ce qui entoure une inscription : la note et la confirmation.
--
--  Deux agacements de la recherche de groupe, qui n'ont en commun que le moment
--  où on les rencontre :
--
--   · la **note d'inscription** se retape à chaque candidature, alors que c'est
--     la même depuis six mois ;
--   · la **vérification des rôles** demande de cliquer sur un bouton pour dire
--     ce qu'on a déjà dit en s'inscrivant.
--
--  La note est une **donnée**, pas un réglage : elle vit dans le SavedVariables
--  du personnage (`DB:CharData`), hors du mécanisme de défauts — c'est le même
--  chemin que l'historique de chat, et pour la même raison.
--
--  Réversibilité : les deux scripts posés sur la fenêtre d'inscription passent
--  par `U.GuardedScript`, donc deviennent inertes quand le module s'éteint
--  (règle 6).
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local U    = BUI.Util
local L    = ns.L

local MODULE = "GroupFinder"

-- =========================================================================
--  Note d'inscription
-- =========================================================================

--- Zone de saisie de la note, ou `nil` tant que la recherche de groupe n'est pas
--- montée : sa fenêtre est chargée à la demande.
---
--- Trois chemins, du plus explicite au plus général. Le client a déjà déplacé
--- cette zone d'un cran de profondeur en changeant de conteneur défilant, et un
--- chemin devenu faux ne lève pas : il rend `nil`, le réglage ne fait plus rien,
--- et rien ne le dit. On cherche donc la zone plutôt que de nommer le conteneur
--- du jour.
---@return table|nil
local function noteBox()
    local dialog = LFGListApplicationDialog
    local body   = dialog and dialog.Description
    if not body then return nil end

    if body.EditBox and body.EditBox.GetText then return body.EditBox end
    if body.GetText then return body end

    if not body.GetChildren then return nil end
    for _, child in ipairs({ body:GetChildren() }) do
        if child.GetObjectType and child:GetObjectType() == "EditBox" then
            return child
        end
    end
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

-- =========================================================================
--  Déclaration du module
-- =========================================================================

BUI:RegisterModule(MODULE, {
    title    = L["Group finder"],
    category = "MythicRaid",
    order    = 15,

    defaults = {
        keepSignupNote = false,
        autoRoleCheck  = false,
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

        self:RegisterEvent("LFG_ROLE_CHECK_SHOW", function() onRoleCheck(self) end)
    end,

    -- Pas d'`OnDisable` : le module ne pose rien à l'écran. Ses deux scripts
    -- passent par `U.GuardedScript` et deviennent inertes d'eux-mêmes, ses
    -- abonnements sont révoqués par le core (règle 6).
})
