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
local BUI = {}

BUI.ADDON   = ADDON
BUI.VERSION = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version"))
              or "dev"
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
        list = {}
        handlers[event] = list
        eventFrame:RegisterEvent(event)
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
