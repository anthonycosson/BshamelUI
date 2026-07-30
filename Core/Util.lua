-- =========================================================================
--  Bshamel UI — Core/Util.lua
--  Helpers sans état. Aucune dépendance en dehors de Core/Init.lua.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI

local U = {}
BUI.Util = U

-- =========================================================================
--  Tables
-- =========================================================================

--- Copie récursive. Les clés non-table sont copiées par valeur.
---@generic T
---@param src T
---@return T
function U.DeepCopy(src)
    if type(src) ~= "table" then return src end
    local out = {}
    for k, v in pairs(src) do
        out[k] = (type(v) == "table") and U.DeepCopy(v) or v
    end
    return out
end

--- Complète `target` avec les clés absentes de `defaults`, récursivement.
--- Ne remplace jamais une valeur déjà présente : c'est la fonction qui rend une
--- montée de version indolore (nouvelle option = nouveau défaut, rien à migrer).
---@param target table
---@param defaults table
---@return table target
function U.MergeDefaults(target, defaults)
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            if type(target[k]) ~= "table" then target[k] = {} end
            U.MergeDefaults(target[k], v)
        elseif target[k] == nil then
            target[k] = v
        end
    end
    return target
end

--- Retire de `target` toute valeur strictement égale à son défaut, et les
--- sous-tables devenues vides. Appelé à la déconnexion : le SavedVariables ne
--- contient alors que ce que l'utilisateur a réellement changé.
---@param target table
---@param defaults table
function U.StripDefaults(target, defaults)
    for k, v in pairs(target) do
        local d = defaults[k]
        if type(v) == "table" and type(d) == "table" then
            U.StripDefaults(v, d)
            if not next(v) then target[k] = nil end
        elseif d ~= nil and v == d then
            target[k] = nil
        end
    end
end

--- Nombre d'entrées d'une table associative.
---@param t table
---@return integer
function U.Count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

--- Clés triées d'une table, pour un affichage déterministe.
---@param t table
---@param comparator? fun(a: any, b: any): boolean
---@return any[]
function U.SortedKeys(t, comparator)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys, comparator)
    return keys
end

-- =========================================================================
--  Nombres
-- =========================================================================

---@param value number
---@param decimals? integer
---@return number
function U.Round(value, decimals)
    local mult = 10 ^ (decimals or 0)
    return math.floor(value * mult + 0.5) / mult
end

---@param value number
---@param min number
---@param max number
---@return number
function U.Clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

-- =========================================================================
--  Temps
-- =========================================================================

--- Enveloppe `fn` de sorte qu'elle ne puisse pas tourner plus d'une fois par
--- `interval` secondes. À utiliser pour tout ce qui est branché sur un
--- événement à haute fréquence (CLEU, UNIT_AURA, OnUpdate…).
---@param interval number
---@param fn function
---@return function
function U.Throttle(interval, fn)
    local last = 0
    return function(...)
        local now = GetTime()
        if now - last < interval then return end
        last = now
        return fn(...)
    end
end

--- Regroupe plusieurs appels rapprochés en un seul, exécuté après `delay`.
--- À utiliser pour les rafraîchissements d'UI déclenchés en rafale.
---@param delay number
---@param fn function
---@return function
function U.Debounce(delay, fn)
    local pending = false
    local args
    return function(...)
        args = { ... }
        if pending then return end
        pending = true
        C_Timer.After(delay, function()
            pending = false
            fn(unpack(args))
        end)
    end
end

-- =========================================================================
--  Entrées clavier / souris
-- =========================================================================

--- `modifier` vaut "SHIFT", "CTRL", "ALT", "ANY" ou "NONE".
---@param modifier string
---@return boolean
function U.IsModifierHeld(modifier)
    if modifier == "SHIFT" then return IsShiftKeyDown() end
    if modifier == "CTRL"  then return IsControlKeyDown() end
    if modifier == "ALT"   then return IsAltKeyDown() end
    if modifier == "ANY"   then return IsModifierKeyDown() end
    return false
end

-- =========================================================================
--  Hooks
-- =========================================================================

--- Hooks déjà posés, pour ne jamais en poser deux fois le même.
local posted = {}

--- `hooksecurefunc` est irréversible : on ne peut pas déposer un hook.
--- Le seul motif correct est donc de hooker **une fois**, définitivement, et de
--- laisser le corps du hook sortir immédiatement quand la condition est fausse.
--- C'est ce que fait cette fonction : le hook est posé au premier appel, et
--- désactiver le module rend le hook inerte sans le retirer.
---
---     U.GuardedHook("QuestFrame_OnShow", function() ... end,
---                   function() return mod:IsEnabled() end)
---
---@param target string|table    nom de la fonction globale, ou table hôte
---@param methodOrFn string|function
---@param bodyOrGuard function
---@param guard? fun(): boolean
function U.GuardedHook(target, methodOrFn, bodyOrGuard, guard)
    local key, body, isEnabled

    if type(target) == "table" then
        key       = tostring(target) .. "::" .. tostring(methodOrFn)
        body      = bodyOrGuard
        isEnabled = guard
    else
        key       = target
        body      = methodOrFn
        isEnabled = bodyOrGuard
    end

    if posted[key] then return end
    posted[key] = true

    local wrapped = function(...)
        if isEnabled and not isEnabled() then return end
        body(...)
    end

    if type(target) == "table" then
        hooksecurefunc(target, methodOrFn, wrapped)
    else
        hooksecurefunc(target, wrapped)
    end
end
