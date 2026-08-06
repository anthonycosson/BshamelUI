-- =========================================================================
--  Bshamel UI — Core/Init.lua
--  Amorçage du namespace et répartiteur d'événements.
--
--  Premier fichier chargé : rien d'autre ne doit supposer un état qui ne
--  soit pas créé ici.
--
--  Note perf : la frame d'événements est créée ici, dans notre addon, et pas
--  empruntée à un autre. Le temps CPU d'un handler est facturé à l'addon qui
--  a créé la frame — donc nos coûts restent visibles sous notre nom dans les
--  outils de profilage, ce qui est le comportement voulu.
-- =========================================================================

local ADDON, ns = ...

---@class BUI
---@field Util table   rempli par `Core/Util.lua`, chargé juste après ce fichier
local BUI = {}

BUI.ADDON   = ADDON
--- Version affichée.
---
--- Le `.toc` porte `@project-version@`, que le packager remplace par le nom du
--- tag au moment de construire l'archive. Une copie de travail n'étant jamais
--- packagée, le client rend donc le **jeton tel quel** — une chaîne bien réelle,
--- si bien que le repli n'avait aucune raison de se déclencher et que le jeton
--- s'affichait en bas de la fenêtre.
---
--- Un jeton non remplacé se reconnaît à son arobase : aucun numéro de version
--- n'en porte.
local version = C_AddOns and C_AddOns.GetAddOnMetadata
                and C_AddOns.GetAddOnMetadata(ADDON, "Version")

if type(version) ~= "string" or version == "" or version:find("@", 1, true) then
    version = "dev"
end

BUI.VERSION = version
BUI.ns      = ns

ns.BUI = BUI

-- Le seul global de l'addon (voir CLAUDE.md, règle 3).
_G.BshamelUI = BUI

-- =========================================================================
--  Appel protégé
-- =========================================================================
-- Un handler qui lève une erreur ne doit jamais empêcher les autres handlers
-- du même événement de tourner. L'erreur est remontée au gestionnaire d'erreur
-- du client (donc visible dans BugSack) au lieu d'être avalée silencieusement.

local function errorHandler(err)
    return (CallErrorHandler or geterrorhandler())(err)
end

---@param fn function
local function safecall(fn, ...)
    -- Le `xpcall` de Lua 5.1 standard ne prend que deux arguments ; celui du
    -- client World of Warcraft accepte des arguments supplémentaires et les
    -- transmet à `fn`. L'analyse statique se base sur le Lua standard, d'où
    -- cette exception explicite.
    ---@diagnostic disable-next-line: redundant-parameter
    return xpcall(fn, errorHandler, ...)
end
BUI.safecall = safecall

-- =========================================================================
--  Événements du client
-- =========================================================================

local eventFrame = CreateFrame("Frame", nil, UIParent)
BUI.eventFrame = eventFrame

--- event -> liste ordonnée de handlers
local handlers = {}

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local list = handlers[event]
    if not list then return end
    -- Copie d'index inversée non nécessaire : on itère sur une taille figée et
    -- les désinscriptions faites *pendant* le dispatch ne prennent effet qu'au
    -- dispatch suivant, ce qui évite les trous d'index.
    for i = 1, #list do
        local fn = list[i]
        if fn then safecall(fn, event, ...) end
    end
end)

--- Abonne un handler à un événement du client.
--- Le handler reçoit (event, ...) comme un OnEvent classique.
---@param event string
---@param fn fun(event: string, ...: any)
function BUI:RegisterEvent(event, fn)
    if type(event) ~= "string" or type(fn) ~= "function" then return end

    local list = handlers[event]
    if not list then
        -- Un nom d'événement que le client ne connaît pas **lève**. Sans cette
        -- protection, un module qui en cite un de trop voit son `OnEnable`
        -- s'arrêter à cette ligne : tout ce qui suit n'est jamais branché, et le
        -- symptôme — « la moitié du module ne fait rien » — ne ressemble pas à sa
        -- cause. Or le cas est courant et légitime : un événement peut n'exister
        -- que sur certains clients, ou changer de nom d'une extension à l'autre.
        --
        -- On tente, on signale, et le reste du module continue de se brancher.
        if not pcall(eventFrame.RegisterEvent, eventFrame, event) then
            BUI:Warn("événement inconnu du client : " .. event)
            return
        end

        list = {}
        handlers[event] = list
    end
    for i = 1, #list do
        if list[i] == fn then return end -- déjà abonné
    end
    list[#list + 1] = fn
end

--- Désabonne un handler. Sans `fn`, désabonne tout l'événement.
---@param event string
---@param fn? function
function BUI:UnregisterEvent(event, fn)
    local list = handlers[event]
    if not list then return end

    if fn then
        for i = #list, 1, -1 do
            if list[i] == fn then table.remove(list, i) end
        end
    else
        wipe(list)
    end

    if #list == 0 then
        handlers[event] = nil
        eventFrame:UnregisterEvent(event)
    end
end

--- Variante « une seule fois » : le handler se désabonne après le premier tir.
---@param event string
---@param fn fun(event: string, ...: any)
function BUI:RegisterEventOnce(event, fn)
    local wrapper
    wrapper = function(...)
        BUI:UnregisterEvent(event, wrapper)
        fn(...)
    end
    BUI:RegisterEvent(event, wrapper)
end

-- =========================================================================
--  Messages internes
-- =========================================================================
-- Découple les modules entre eux et de l'UI : un module modifie un réglage et
-- envoie un message, l'UI se rafraîchit. Aucun module n'appelle jamais
-- directement une fonction d'un autre module.

local callbacks = {}

--- Messages émis par le core (à garder à jour) :
---   "BUI_PROFILE_CHANGED"  (profileName)
---   "BUI_SETTING_CHANGED"  (moduleName, key, value)
---   "BUI_MODULE_STATE"     (moduleName, enabled)
BUI.MESSAGES = {
    PROFILE_CHANGED = "BUI_PROFILE_CHANGED",
    SETTING_CHANGED = "BUI_SETTING_CHANGED",
    MODULE_STATE    = "BUI_MODULE_STATE",
}

---@param message string
---@param fn fun(message: string, ...: any)
function BUI:RegisterMessage(message, fn)
    if type(message) ~= "string" or type(fn) ~= "function" then return end
    local list = callbacks[message]
    if not list then
        list = {}
        callbacks[message] = list
    end
    for i = 1, #list do
        if list[i] == fn then return end
    end
    list[#list + 1] = fn
end

---@param message string
---@param fn? function
function BUI:UnregisterMessage(message, fn)
    local list = callbacks[message]
    if not list then return end
    if fn then
        for i = #list, 1, -1 do
            if list[i] == fn then table.remove(list, i) end
        end
    else
        wipe(list)
    end
end

---@param message string
function BUI:SendMessage(message, ...)
    local list = callbacks[message]
    if not list then return end
    for i = 1, #list do
        local fn = list[i]
        if fn then safecall(fn, message, ...) end
    end
end

-- =========================================================================
--  Sortie console
-- =========================================================================

local PREFIX = "|cff00aeefBshamel|rUI:|r "

function BUI:Print(...)
    print(PREFIX .. strjoin(" ", tostringall(...)))
end

--- Message d'erreur destiné à l'utilisateur (pas une erreur Lua).
function BUI:Warn(...)
    print(PREFIX .. "|cffff6060" .. strjoin(" ", tostringall(...)) .. "|r")
end

-- =========================================================================
--  Veille des actions bloquées
-- =========================================================================
-- « BshamelUI a été bloqué à cause d'une action qui n'est utilisable que par
-- l'IU de Blizzard » : le client affiche la fenêtre, mais il ne dit **pas**
-- quelle fonction a été refusée. Sans ce nom, chercher la cause revient à
-- deviner.
--
-- Le nom, lui, est publié — dans l'événement, pas dans la fenêtre. Cette veille
-- l'écoute et l'écrit dans le chat. Elle est **éteinte par défaut** : ce qui
-- s'affiche alors n'aide que celui qui cherche, et la contamination est souvent
-- attribuée à l'addon qui a lu la valeur, pas à celui qui l'a salie — un joueur
-- verrait donc passer des lignes qui accusent le mauvais coupable.
--
-- Elle vit ici plutôt que sous `dev/` parce qu'elle ne sert à rien hors du jeu :
-- c'est en jeu, chez le joueur qui rencontre le blocage, qu'il faut le nom.

--- Le client n'émet ces deux événements **que si l'affichage des erreurs de
--- script est allumé**. La fenêtre, elle, s'affiche dans tous les cas : les deux
--- ne viennent pas du même mécanisme. Une veille qui se contente d'écouter reste
--- donc muette chez la moitié des gens — et le silence se lit comme « il n'y a
--- plus de blocage », ce qui est exactement le contraire de ce qu'on cherche.
---
--- La veille allume donc la CVar elle-même, et la repose en s'éteignant. C'est
--- une commande de diagnostic : elle est demandée explicitement, et elle ne
--- laisse rien derrière elle.
local ERRORS_CVAR = "scriptErrors"

local watching = false
local savedErrors

local function onBlocked(event, addonName, functionName)
    BUI:Warn(event, addonName or "?", functionName or "?")
end

--- Arme ou désarme la veille. Renvoie son nouvel état.
---@return boolean watching
function BUI:ToggleActionWatch()
    watching = not watching
    local U = BUI.Util

    if watching then
        savedErrors = U.GetCVar(ERRORS_CVAR)
        U.SetCVar(ERRORS_CVAR, "1")

        BUI:RegisterEvent("ADDON_ACTION_BLOCKED",   onBlocked)
        BUI:RegisterEvent("ADDON_ACTION_FORBIDDEN", onBlocked)
    else
        if savedErrors ~= nil then
            U.SetCVar(ERRORS_CVAR, savedErrors)
            savedErrors = nil
        end

        BUI:UnregisterEvent("ADDON_ACTION_BLOCKED",   onBlocked)
        BUI:UnregisterEvent("ADDON_ACTION_FORBIDDEN", onBlocked)
    end

    return watching
end
