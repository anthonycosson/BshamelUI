-- =========================================================================
--  Bshamel UI — Modules/GroupFinder.lua
--  Ce qui entoure une inscription : la note, la confirmation, le compte à rebours.
--
--  Trois agacements de la recherche de groupe, qui n'ont en commun que le moment
--  où on les rencontre :
--
--   · la **note d'inscription** se retape à chaque candidature, alors que c'est
--     la même depuis six mois ;
--   · la **vérification des rôles** demande de cliquer sur un bouton pour dire
--     ce qu'on a déjà dit en s'inscrivant ;
--   · la fenêtre qui annonce l'instance **ne dit pas combien de temps il reste**
--     pour la prendre, alors qu'elle se referme toute seule.
--
--  Le minuteur vivait dans *Général*, faute de page où le mettre. Il est ici
--  depuis que celle-ci existe, et un palier de migration (`Core/DB.lua`) déplace
--  le réglage de ceux qui l'avaient changé.
--
--  La note est une **donnée**, pas un réglage : elle vit dans le SavedVariables
--  du personnage (`DB:CharData`), hors du mécanisme de défauts — c'est le même
--  chemin que l'historique de chat, et pour la même raison.
--
--  Réversibilité : les deux scripts posés sur la fenêtre d'inscription passent
--  par `U.GuardedScript`, donc deviennent inertes quand le module s'éteint
--  (règle 6) ; les décomptes posés sur les fenêtres du client s'arrêtent et se
--  cachent.
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

--- Vrai tant que la demande de rôles en cours a déjà reçu notre réponse.
---
--- Deux chemins y mènent — l'événement et l'ouverture de la fenêtre — et rien ne
--- dit lequel arrive le premier : le client montre sa fenêtre depuis son propre
--- abonnement au même événement, et l'ordre entre deux abonnés n'est pas défini.
--- Ce drapeau est ce qui rend les deux chemins interchangeables : le premier
--- servi répond, le second n'a plus rien à faire.
local roleCheckAnswered = false

--- Répond à la demande de rôles si le réglage le veut.
---@param mod table
---@return boolean answered  vrai si la demande est réglée, par cet appel ou l'autre
local function answerRoleCheck(mod)
    if not mod:Get("autoRoleCheck") then return false end
    if roleCheckAnswered then return true end
    if not CompleteLFGRoleCheck then return false end

    roleCheckAnswered = true
    CompleteLFGRoleCheck(true)
    return true
end

--- Fenêtres candidates du client pour la demande de rôles, de la plus récente à
--- la plus ancienne. Test de capacité et non de version (règle 1).
---@return table|nil
local function rolePopup()
    if LFGRoleCheckPopup and LFGRoleCheckPopup.HookScript then return LFGRoleCheckPopup end
    if LFDRoleCheckPopup and LFDRoleCheckPopup.HookScript then return LFDRoleCheckPopup end
    return nil
end

--- Empêche la fenêtre de demande de rôles de s'afficher quand on y répond seul.
---
--- **Répondre à l'événement ne suffit pas.** Le client ouvre sa fenêtre depuis
--- son propre abonnement au même événement : répondre avant lui ne l'empêche pas
--- d'ouvrir, cela avance seulement le moment où elle se referme. Elle apparaît
--- donc quand même, le temps d'un battement de cils, et c'est ce battement qu'on
--- vient supprimer.
---
--- Une frame montrée puis cachée **dans le même passage** n'est jamais dessinée :
--- se poser sur son `OnShow` est ce qui fait disparaître le clignotement au lieu
--- de le raccourcir.
---
--- La réponse est envoyée d'ici aussi, et pas seulement cachée : c'est ce qui
--- garantit qu'on ne masque jamais une fenêtre à laquelle personne n'a répondu.
---@param mod table
local function hookRoleCheck(mod)
    local popup = rolePopup()
    if not popup then return end

    U.GuardedScript(popup, "OnShow", function(self)
        if answerRoleCheck(mod) then self:Hide() end
    end, function()
        return mod:IsEnabled() and mod:Get("autoRoleCheck") == true
    end)
end

-- =========================================================================
--  Minuteur des fenêtres de file d'attente
-- =========================================================================

--- Durée d'une proposition de groupe, en secondes.
---
--- Le client publie l'échéance des invitations de champ de bataille
--- (`GetBattlefieldPortExpiration`) mais **rien** pour une proposition de
--- donjon : ni fonction, ni constante. Ce nombre est donc le délai que le client
--- applique, mesuré et non déduit — voir `dev/docs/API_NOTES.md`. S'il change un
--- jour, c'est ici et nulle part ailleurs.
local PROPOSAL_SECONDS = 40

--- fenêtre du client -> décompte qu'on lui a posé
local countdowns = {}

--- Cadre sur lequel poser le décompte : l'**icône du rôle** quand la fenêtre en
--- porte une, la fenêtre elle-même sinon.
---
--- C'est le seul repère qui tienne dans les deux cas. Le centre de la fenêtre
--- tombe entre le nom de l'instance et l'icône, donc sur rien ; l'icône, elle,
--- est un disque vide au milieu, exactement de la taille d'un nombre.
---
--- Deux chemins, du plus général au plus ancien, et aucun n'est un pari : un
--- champ absent ou un nom inconnu rend `nil`, et on retombe sur la fenêtre.
---@param dialog table
---@return table
local function countdownAnchor(dialog)
    local icon = dialog.roleIcon

    if not icon then
        local name = dialog.GetName and dialog:GetName()
        icon = name and _G[name .. "RoleIcon"] or nil
    end

    if icon and icon.GetCenter and icon:GetCenter() then return icon end
    return dialog
end

---@param parent table
---@param source fun(): number|nil
---@param total number  durée pleine, qui donne sa couleur au décompte
local function watch(parent, source, total)
    local countdown = countdowns[parent]
    if not countdown then
        countdown = W.Countdown(parent)
        if not countdown then return end
        countdown:SetPoint("CENTER", countdownAnchor(parent), "CENTER",
            0, T.SIZE.COUNTDOWN_Y)
        countdowns[parent] = countdown
    end
    countdown:Watch(source, total)
end

local function stopCountdowns()
    for _, countdown in pairs(countdowns) do
        countdown:Stop()
    end
end

---@param mod table
local function watchProposal(mod)
    if not mod:Get("queueTimer") then return end

    -- Le cadre qui s'affiche est le **dialogue**, pas le popup qui le porte :
    -- coiffer le second poserait le décompte sur un conteneur invisible.
    local dialog = LFGDungeonReadyDialog or LFGDungeonReadyPopup
    if not dialog then return end

    local total    = PROPOSAL_SECONDS
    local deadline = GetTime() + total

    watch(dialog, function()
        local remaining = deadline - GetTime()
        if remaining <= 0 then return nil end
        return remaining
    end, total)
end

--- Secondes restantes pour accepter une entrée en champ de bataille ou en
--- arène, prises sur le client lui-même.
---@return number|nil
local function portExpiration()
    if not (GetMaxBattlefieldID and GetBattlefieldStatus and GetBattlefieldPortExpiration) then
        return nil
    end
    for i = 1, GetMaxBattlefieldID() do
        if GetBattlefieldStatus(i) == "confirm" then
            local remaining = GetBattlefieldPortExpiration(i)
            if remaining and remaining > 0 then return remaining end
        end
    end
    return nil
end

---@param mod table
local function watchBattlefield(mod)
    if not mod:Get("queueTimer") then return end

    local dialog = PVPReadyDialog
    if not (dialog and dialog:IsShown()) then return end

    -- La durée pleine est ce qui reste au moment où la fenêtre s'ouvre : le
    -- client ne publie que le temps restant, jamais le délai qu'il a accordé.
    local remaining = portExpiration()
    if not remaining then return end

    watch(dialog, portExpiration, remaining)
end

-- =========================================================================
--  Déclaration du module
-- =========================================================================

BUI:RegisterModule(MODULE, {
    title    = L["Group finder"],
    category = "QoL",
    order    = 60,

    defaults = {
        keepSignupNote = false,
        autoRoleCheck  = false,
        queueTimer     = false,
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

        { type = "header", text = L["Queues"] },
        {
            type    = "toggle",
            key     = "queueTimer",
            text    = L["Queue popup timer"],
            tooltip = L["Queue popup timer tip"],
        },
    },

    OnEnable = function(self)
        -- Le drapeau est remis à plat ici : éteindre le module révoque ses
        -- abonnements, donc peut-être le `LFG_ROLE_CHECK_HIDE` qui l'aurait
        -- rendu. Rallumer sur un drapeau resté levé ferait cacher la fenêtre
        -- suivante sans y avoir répondu, ce qui est exactement ce qu'il faut
        -- éviter.
        roleCheckAnswered = false

        hookSignupNote(self)
        hookRoleCheck(self)

        -- La fenêtre d'inscription est chargée à la demande : elle peut
        -- n'exister qu'une fois la recherche de groupe ouverte. On retente une
        -- fois la rafale retombée ; `U.GuardedScript` ne pose jamais deux fois
        -- le même script.
        local settle = U.Debounce(T.TIMING.CHAT_SETTLE, function()
            hookSignupNote(self)
            hookRoleCheck(self)
        end)
        self:RegisterEvent("ADDON_LOADED",                    settle)
        self:RegisterEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED", settle)
        self:RegisterEvent("LFG_LIST_AVAILABILITY_UPDATE",     settle)

        self:RegisterEvent("LFG_ROLE_CHECK_SHOW", function() answerRoleCheck(self) end)

        -- La demande suivante est une autre demande : le drapeau ne vaut que pour
        -- celle en cours.
        self:RegisterEvent("LFG_ROLE_CHECK_HIDE", function() roleCheckAnswered = false end)

        self:RegisterEvent("LFG_PROPOSAL_SHOW",         function() watchProposal(self) end)
        self:RegisterEvent("UPDATE_BATTLEFIELD_STATUS", function() watchBattlefield(self) end)
    end,

    -- Les deux scripts d'inscription passent par `U.GuardedScript` et deviennent
    -- inertes d'eux-mêmes ; les abonnements sont révoqués par le core (règle 6).
    -- Restent les décomptes, qui sont posés à l'écran : eux se rendent.
    OnDisable = stopCountdowns,

    -- Décocher le minuteur pendant qu'une fenêtre de file est ouverte doit le
    -- faire disparaître tout de suite, pas à la fenêtre suivante.
    OnSettingChanged = function(self, key)
        if key ~= nil and key ~= "queueTimer" then return end
        if not self:Get("queueTimer") then stopCountdowns() end
    end,
})
