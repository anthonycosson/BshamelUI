-- =========================================================================
--  Bshamel UI — Modules/Profiles.lua
--  Les profils de réglages : celui que ce personnage utilise, ce qu'on peut
--  en faire, et comment ils voyagent.
--
--  Un profil est un jeu complet de réglages, rangé dans le SavedVariables du
--  compte ; chaque **personnage** retient lequel il utilise (`Core/DB.lua`).
--  Tout existait déjà côté base — cette page est la première à le montrer.
--
--  La page tient en deux moitiés, qui sont les deux distances d'un même
--  geste : en haut, les profils **de ce compte** — basculer, créer vierge,
--  dupliquer l'actif, le supprimer, recopier un autre profil dans l'actif —
--  et en bas, la
--  **sauvegarde et le partage** — l'export photographie le profil actif en un
--  code texte (les défauts n'y sont pas, seul voyage ce que le joueur a
--  changé), l'import fait le chemin inverse et demande sa destination :
--  remplacer le profil courant, ou créer un profil neuf qui reçoit le code
--  sans toucher aux autres.
--
--  Le code exporté embarque la version de schéma des réglages. Un export
--  d'hier s'importe demain : les migrations de `Core/DB.lua` le rattrapent,
--  comme une base restée fermée six mois. Un export d'une version **plus
--  récente** que l'addon installé se refuse, franchement et avant toute
--  question.
--
--  Le module ne dessine pas (règle 2) : menus dont la liste est relue à
--  l'ouverture, boîtes de la fabrique (`W.Prompt`, `W.Choose`), fenêtres
--  `W.CopyWindow`. Réversibilité (règle 6) : il n'écrit que quand on clique,
--  le core rejoue l'état des modules à chaque bascule, et désactivé il
--  referme ses fenêtres.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local W    = BUI.Widgets
local L    = ns.L

local MODULE = "Profiles"

-- =========================================================================
--  L'autre profil, celui sur lequel portent les actions
-- =========================================================================
-- Un choix d'interface, pas un réglage : il ne survit ni au rechargement ni à
-- la fenêtre, et ne passe donc pas par la base. Comme il n'émet aucun message,
-- la page se rafraîchit à la main pour que les boutons suivent le menu.

local otherProfile

--- Le profil choisi existe-t-il encore, et est-il actionnable ? Un profil
--- supprimé entre-temps, ou devenu l'actif après une bascule, ne l'est plus.
---@return boolean
local function otherReady()
    if type(otherProfile) ~= "string" then return false end
    if otherProfile == BUI.DB:GetProfileName() then return false end

    local names = BUI.DB:ListProfiles()
    for i = 1, #names do
        if names[i] == otherProfile then return true end
    end
    return false
end

-- =========================================================================
--  Les listes des menus
-- =========================================================================

---@return BUI.DropdownEntry[]
local function profileValues()
    local names  = BUI.DB:ListProfiles()
    local values = {}
    for i = 1, #names do
        values[#values + 1] = { value = names[i], label = names[i] }
    end
    return values
end

--- Tous les profils **sauf l'actif** : se copier sur soi-même n'est pas un
--- geste, la liste ne le propose pas.
---@return BUI.DropdownEntry[]
local function otherProfileValues()
    local active = BUI.DB:GetProfileName()
    local names  = BUI.DB:ListProfiles()
    local values = {}
    for i = 1, #names do
        if names[i] ~= active then
            values[#values + 1] = { value = names[i], label = names[i] }
        end
    end
    return values
end

---@return boolean
local function aloneInList()
    return #BUI.DB:ListProfiles() < 2
end

-- =========================================================================
--  Les gestes
-- =========================================================================

--- Le nom est-il déjà pris ? La création et la duplication refusent toutes
--- deux d'écraser : un profil ne disparaît que par un geste qui le nomme.
---@param name string
---@return boolean
local function nameTaken(name)
    local names = BUI.DB:ListProfiles()
    for i = 1, #names do
        if names[i] == name then return true end
    end
    return false
end

local function createProfile()
    W.Prompt(L["New profile name"], L["Create"], function(name)
        if nameTaken(name) then
            BUI:Print(L["Profile exists"])
            return
        end
        BUI.DB:SetProfile(name)
        BUI:Print(BUI:Lf("Profile created", name))
    end)
end

local function duplicateProfile()
    W.Prompt(L["New profile name"], L["Duplicate"], function(name)
        if BUI.DB:CopyProfileTo(name) then
            BUI:Print(BUI:Lf("Profile duplicated", name))
        else
            BUI:Print(L["Profile exists"])
        end
    end)
end

local function copyFromSource()
    if not otherReady() then return end

    local source = otherProfile
    W.Confirm(BUI:Lf("Copy profile confirm", BUI.DB:GetProfileName(), source),
        function()
            if BUI.DB:CopyProfileFrom(source) then
                BUI:Print(BUI:Lf("Profile copied", source))
            end
        end)
end

--- Supprime le profil **actif**. La base fait alors retomber le personnage sur
--- le profil par défaut et l'annonce comme un changement de profil — la page
--- se rafraîchit donc sans qu'on l'appelle.
local function deleteActive()
    local doomed = BUI.DB:GetProfileName()
    W.Confirm(BUI:Lf("Delete profile confirm", doomed), function()
        if BUI.DB:DeleteProfile(doomed) then
            BUI:Print(BUI:Lf("Profile deleted", doomed))
        end
    end)
end

-- =========================================================================
--  Sauvegarde et partage : le code, dans les deux sens
-- =========================================================================

-- Le format du code — sa marque, son encodage, sa relecture — vit dans
-- `Core/DB.lua` : cette page n'est plus le seul endroit qui le produit, la
-- sauvegarde en macros s'en sert aussi.

local exportWindow
local importWindow

local function openExport()
    local text = BUI.DB:ExportString()
    if not text then
        BUI:Print(L["Export failed"])
        return
    end

    if not exportWindow then
        exportWindow = W.CopyWindow("BshamelUISharingExport",
            L["Export settings"], L["Export copy hint"])
    end
    exportWindow:OpenSelected(text)
end

--- L'import dans un profil neuf : la boîte de saisie demande le nom, la base
--- refuse un nom déjà pris — créer ne doit jamais écraser.
---@param data table
local function importIntoNew(data)
    W.Prompt(L["New profile name"], L["Create"], function(name)
        local ok, reason = BUI.DB:ImportProfile(data, name)
        if ok then
            BUI:Print(BUI:Lf("Import applied to new", name))
        elseif reason == "exists" then
            BUI:Print(L["Profile exists"])
        else
            BUI:Print(L["Import invalid"])
        end
    end)
end

---@param text string
local function submitImport(text)
    local data = BUI.DB:ParseImport(text)

    -- La validation passe **avant** les questions : demander « quel profil ? »
    -- pour répondre ensuite « le code était invalide » ferait porter la
    -- question sur rien.
    local ok, reason = BUI.DB:ValidateImport(data)
    if not ok then
        BUI:Print(reason == "newer" and L["Import newer"] or L["Import invalid"])
        return
    end

    -- La destination est la seule question, et elle **est** la confirmation :
    -- son texte dit que le profil courant serait remplacé, cliquer l'un des
    -- deux boutons est y répondre en connaissance de cause.
    W.Choose(L["Import destination"],
        L["Current profile"], function()
            if BUI.DB:ImportProfile(data) then
                BUI:Print(L["Import applied"])
            else
                BUI:Print(L["Import invalid"])
            end
        end,
        L["New profile"], function()
            importIntoNew(data)
        end)
end

local function openImport()
    if not importWindow then
        importWindow = W.CopyWindow("BshamelUISharingImport",
            L["Import settings"], L["Import paste hint"],
            L["Apply"], submitImport)
    end
    importWindow:Open("")
end

-- =========================================================================
--  Déclaration du module
-- =========================================================================

BUI:RegisterModule(MODULE, {
    title    = L["Profiles"],
    category = "Sharing",
    order    = 1,

    -- Aucun réglage : la page n'est faite que de gestes. Le bloc reste sur
    -- deux lignes — le garde-fou des défauts cherche sa fermeture en tête de
    -- ligne, et un `{},` en ligne le laisse lire les options comme des défauts.
    defaults = {
    },

    options = {
        {
            type    = "dropdown",
            text    = L["Active profile"],
            tooltip = L["Active profile tip"],
            values  = profileValues,
            get     = function() return BUI.DB:GetProfileName() end,
            set     = function(value)
                if type(value) == "string" and value ~= BUI.DB:GetProfileName() then
                    BUI.DB:SetProfile(value)
                end
            end,
        },
        {
            type    = "button",
            text    = L["Create blank profile"],
            label   = L["Create"],
            tooltip = L["Create blank profile tip"],
            onClick = createProfile,
        },
        {
            type    = "button",
            text    = L["Duplicate profile"],
            label   = L["Duplicate"],
            tooltip = L["Duplicate profile tip"],
            onClick = duplicateProfile,
        },
        {
            type    = "button",
            text    = L["Delete profile"],
            label   = L["Delete"],
            tooltip = L["Delete profile tip"],
            onClick = deleteActive,
        },

        { type = "header", text = L["Other profiles"] },
        {
            type     = "dropdown",
            text     = L["Other profile"],
            tooltip  = L["Other profile tip"],
            values   = otherProfileValues,
            get      = function() return otherProfile or L["No profile picked"] end,
            set      = function(value)
                otherProfile = value
                -- Un choix hors base n'émet pas de message : la page se
                -- rafraîchit ici pour que les boutons suivent le menu.
                BUI.PageBuilder:RefreshPage(MODULE)
            end,
            disabled = aloneInList,
            disabledReason = L["No other profile"],
        },
        {
            type     = "button",
            text     = L["Copy into active"],
            label    = L["Copy profile"],
            tooltip  = L["Copy into active tip"],
            indent   = true,
            onClick  = copyFromSource,
            disabled = function() return not otherReady() end,
            disabledReason = L["Pick a profile first"],
        },

        { type = "header", text = L["Backup and sharing"] },
        {
            type    = "button",
            text    = L["Export settings"],
            label   = L["Export"],
            tooltip = L["Export settings tip"],
            onClick = openExport,
        },
        {
            type    = "button",
            text    = L["Import settings"],
            label   = L["Import"],
            tooltip = L["Import settings tip"],
            onClick = openImport,
        },
    },

    OnDisable = function()
        if exportWindow then exportWindow:Hide() end
        if importWindow then importWindow:Hide() end
    end,
})
