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

--- Montant en pièces, avec les icônes du client.
--- La fonction a migré dans `C_CurrencyInfo` ; la globale existe encore, mais
--- rien ne dit pour combien de temps.
---@param amount number
---@return string
function U.Money(amount)
    if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
        return C_CurrencyInfo.GetCoinTextureString(amount)
    end
    if GetCoinTextureString then return GetCoinTextureString(amount) end
    return tostring(amount)
end

-- =========================================================================
--  Temps
-- =========================================================================

--- Durée en `M:SS`, ou `H:MM:SS` au-delà de l'heure.
---
--- Les minutes ne sont pas ramenées sous soixante en dessous d'une heure : un
--- chrono de donjon dépasse la demi-heure et se lit « 34:12 », pas « 0:34:12 ».
--- Une durée négative se rend sans son signe : c'est à l'appelant de dire ce
--- qu'un dépassement signifie, en le préfixant ou en le colorant.
---@param seconds number
---@return string
function U.Clock(seconds)
    seconds = math.floor(math.abs(seconds or 0) + 0.5)

    local hours   = math.floor(seconds / 3600)
    local minutes = math.floor(seconds / 60)

    if hours > 0 then
        return string.format("%d:%02d:%02d", hours, minutes % 60, seconds % 60)
    end
    return string.format("%d:%02d", minutes, seconds % 60)
end

--- Écart entre deux durées, **signé**, en `±MM:SS`.
---
--- Deux différences avec `U.Clock`, et elles disent la même chose : un écart n'est
--- pas une durée, c'est une comparaison. Le signe est donc porté par la chaîne — il
--- est ce qu'on lit en premier — et les minutes sont cadrées sur deux chiffres,
--- parce qu'un écart se lit toujours à côté d'un autre écart, ligne après ligne, et
--- qu'une colonne de `+1:05` et de `-12:30` ne s'aligne pas.
---
--- Zéro se rend avec un plus : « pareil » est un résultat, et le rendre sans signe
--- le ferait lire comme une durée.
---@param seconds number
---@return string
function U.Delta(seconds)
    local total = math.floor(math.abs(seconds or 0) + 0.5)
    local sign  = ((seconds or 0) < 0) and "-" or "+"

    return string.format("%s%02d:%02d", sign, math.floor(total / 60), total % 60)
end

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
--  Sérialisation
-- =========================================================================
-- Le format texte de l'export de configuration. Maison, parce que l'addon n'a
-- pas de dépendance et n'en prend pas pour quatre fonctions ; et **jamais**
-- relu par `loadstring` : un code collé par un joueur est une entrée qu'on
-- analyse, pas un programme qu'on exécute.
--
-- Quatre types, qui sont tout ce qu'un réglage sait être :
--     vrai / faux    T  /  F
--     nombre         N<valeur>;         (`%.17g` : un double s'y relit exact)
--     chaîne         S<longueur>:<octets>
--     table          { clé valeur clé valeur ... }
--
-- Tout écart au format rend `nil`, jamais une table à moitié lue : un code
-- tronqué au collage doit échouer franchement, pas importer un demi-profil.

--- Profondeur de table au-delà de laquelle on refuse, dans les deux sens. Les
--- réglages tiennent en trois niveaux (module → clé → couleur) ; dix protège
--- l'analyse d'un code fabriqué pour la faire déborder.
local MAX_DEPTH = 10

---@param value any
---@param out string[]
---@param depth number
---@return boolean ok
local function serializeInto(value, out, depth)
    local kind = type(value)

    if kind == "boolean" then
        out[#out + 1] = value and "T" or "F"
        return true
    end

    if kind == "number" then
        -- NaN et infinis ne se relisent pas par `tonumber` : on refuse à
        -- l'écriture plutôt que d'échouer au collage, chez quelqu'un d'autre.
        if value ~= value or value == math.huge or value == -math.huge then
            return false
        end
        out[#out + 1] = string.format("N%.17g;", value)
        return true
    end

    if kind == "string" then
        out[#out + 1] = "S" .. #value .. ":" .. value
        return true
    end

    if kind == "table" then
        if depth >= MAX_DEPTH then return false end
        out[#out + 1] = "{"
        for k, v in pairs(value) do
            if not serializeInto(k, out, depth + 1) then return false end
            if not serializeInto(v, out, depth + 1) then return false end
        end
        out[#out + 1] = "}"
        return true
    end

    -- Fonction, frame, userdata : rien de tout cela n'est un réglage.
    return false
end

--- Sérialise une valeur. `nil` si elle contient quelque chose qui ne se
--- sérialise pas — l'appelant renonce alors en entier.
---@param value any
---@return string|nil
function U.Serialize(value)
    local out = {}
    if not serializeInto(value, out, 0) then return nil end
    return table.concat(out)
end

--- Lit une valeur à partir de `pos`. Rend la valeur et la position qui suit,
--- ou pas de position du tout en cas d'écart au format — c'est elle qui dit
--- l'échec, une valeur lue pouvant légitimement être `false`.
---@param text string
---@param pos number
---@param depth number
---@return any value, number|nil next
local function parseValue(text, pos, depth)
    local c = text:sub(pos, pos)

    if c == "T" then return true, pos + 1 end
    if c == "F" then return false, pos + 1 end

    if c == "N" then
        local repr, rest = text:match("^([^;]+);()", pos + 1)
        local number = repr and tonumber(repr)
        if not number then return nil, nil end
        return number, rest
    end

    if c == "S" then
        local len, rest = text:match("^(%d+):()", pos + 1)
        if not len then return nil, nil end
        local finish = rest + tonumber(len) - 1
        if finish > #text then return nil, nil end
        return text:sub(rest, finish), finish + 1
    end

    if c == "{" then
        if depth >= MAX_DEPTH then return nil, nil end
        local result = {}
        local cursor = pos + 1
        while true do
            if cursor > #text then return nil, nil end
            if text:sub(cursor, cursor) == "}" then return result, cursor + 1 end

            local key, afterKey = parseValue(text, cursor, depth + 1)
            if not afterKey or key == nil then return nil, nil end
            local val, afterValue = parseValue(text, afterKey, depth + 1)
            if not afterValue or val == nil then return nil, nil end

            result[key] = val
            cursor = afterValue
        end
    end

    return nil, nil
end

--- Relit ce que `U.Serialize` a écrit. `nil` sur tout écart au format, y
--- compris du texte en trop après la valeur — un code recollé deux fois n'est
--- pas un code valide.
---@param text string
---@return any|nil
function U.Deserialize(text)
    if type(text) ~= "string" or text == "" then return nil end

    local value, pos = parseValue(text, 1, 0)
    if not pos or pos ~= #text + 1 then return nil end
    return value
end

-- =========================================================================
--  Encodage en texte portable
-- =========================================================================
-- Base64 classique. Le sérialisé transporte des chaînes arbitraires ; encodé,
-- le code ne contient plus que des lettres, des chiffres, `+ / =` — rien que le
-- chat, un site ou une zone de saisie puisse abîmer ou interpréter (`|`).

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local b64Char, b64Code = {}, {}
for i = 1, 64 do
    local char = B64:sub(i, i)
    b64Char[i - 1] = char
    b64Code[char]  = i - 1
end

--- Le client embarque une bibliothèque `bit`, mais l'arithmétique suffit ici :
--- l'encodage ne court que sur un clic de bouton, jamais dans un chemin chaud.
---@param text string
---@return string
function U.Encode(text)
    local out = {}
    for i = 1, #text, 3 do
        local a, b, c = text:byte(i, i + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)

        out[#out + 1] = b64Char[math.floor(n / 262144) % 64]
        out[#out + 1] = b64Char[math.floor(n / 4096) % 64]
        out[#out + 1] = b and b64Char[math.floor(n / 64) % 64] or "="
        out[#out + 1] = c and b64Char[n % 64] or "="
    end
    return table.concat(out)
end

--- Décode. `nil` sur tout caractère étranger ou toute longueur boiteuse : un
--- code abîmé doit échouer ici, pas produire un sérialisé faux.
--- Les blancs sont retirés d'abord — ce qui a transité par un chat ou un site
--- revient souvent replié en plusieurs lignes.
---@param text string
---@return string|nil
function U.Decode(text)
    if type(text) ~= "string" then return nil end
    text = text:gsub("%s+", "")
    if text == "" or #text % 4 ~= 0 then return nil end

    local out = {}
    for i = 1, #text, 4 do
        local q1, q2, q3, q4 = text:sub(i, i), text:sub(i + 1, i + 1),
                               text:sub(i + 2, i + 2), text:sub(i + 3, i + 3)

        local c1, c2 = b64Code[q1], b64Code[q2]
        if not (c1 and c2) then return nil end

        -- Le remplissage n'existe qu'en fin de code, et `=` suivi d'autre
        -- chose que `=` n'existe pas du tout.
        local pad3, pad4 = q3 == "=", q4 == "="
        if (pad3 or pad4) and i + 3 ~= #text then return nil end
        if pad3 and not pad4 then return nil end

        local c3 = pad3 and 0 or b64Code[q3]
        local c4 = pad4 and 0 or b64Code[q4]
        if not (c3 and c4) then return nil end

        local n = c1 * 262144 + c2 * 4096 + c3 * 64 + c4
        out[#out + 1] = string.char(math.floor(n / 65536) % 256)
        if not pad3 then out[#out + 1] = string.char(math.floor(n / 256) % 256) end
        if not pad4 then out[#out + 1] = string.char(n % 256) end
    end
    return table.concat(out)
end

-- =========================================================================
--  Réglages du client
-- =========================================================================

--- Les deux chemins existent, aucun des deux n'est garanti pour toujours : la
--- fonction a migré dans `C_CVar`, la globale est encore là.
---@param name string
---@return string|nil
function U.GetCVar(name)
    if C_CVar and C_CVar.GetCVar then return C_CVar.GetCVar(name) end
    return GetCVar and GetCVar(name) or nil
end

---@param name string
---@param value any
function U.SetCVar(name, value)
    if C_CVar and C_CVar.SetCVar then
        C_CVar.SetCVar(name, value)
    elseif SetCVar then
        SetCVar(name, value)
    end
end

-- =========================================================================
--  Valeurs secrètes du client
-- =========================================================================

--- Une valeur « secrète » du client ne se lit ni ne se calcule : la multiplier,
--- la comparer ou s'en servir comme clé de table lève. Le client en rend là où
--- il protège une information (une instance, un adversaire d'arène), et la
--- notion n'existe pas sur tous les clients — d'où le test de capacité
--- (CLAUDE.md règle 1).
---
--- Le prédicat ne sert qu'à écarter une **valeur** dont on s'apprête à faire
--- quelque chose, jamais un cadre entier : décider qu'un cadre est intouchable
--- sur ce soupçon revient à le perdre sans avoir essayé.
---@param value any
---@return boolean
function U.IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value) == true
end

--- Un booléen secret ne se **teste** pas plus qu'une chaîne secrète ne s'indexe :
--- `if flag then` lève « attempt to perform boolean test on a secret boolean
--- value ». Ce prédicat est le seul test permis, et il rend vrai uniquement
--- quand la réponse est **connue** et vraie.
---
--- Un secret vaut donc « non », et pas « peut-être » : le client cache ces
--- réponses là où il refuse de nous laisser conclure — sur l'identité d'une unité
--- d'arène, par exemple. Conclure quand même serait plus faux que de s'abstenir.
---@param value any
---@return boolean
function U.IsTrue(value)
    if U.IsSecret(value) then return false end
    -- La truthiness de Lua, pas `== true` : plusieurs fonctions du client
    -- répondent encore `1` là où elles pourraient répondre `true`.
    return value ~= nil and value ~= false
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
---
--- **Trois registres et non un**, parce qu'une clé unique se payait cher. Un
--- hook de méthode se reconnaît à son hôte *et* au nom de la méthode ; la clé
--- était donc `tostring(hôte) .. "::" .. nom`, une chaîne fabriquée à chaque
--- appel — y compris, et surtout, pour ressortir aussitôt puisque le hook était
--- déjà là. Or ces fonctions se rappellent à chaque repeinture d'une barre de
--- nom : cette clé jetable était devenue l'une des allocations les plus
--- fréquentes de l'addon (règle 7). L'hôte est déjà une clé parfaite, et
--- s'indexer ne coûte rien.
---
--- Clés faibles pour les deux registres à hôte : un cadre que plus personne ne
--- tient n'a pas à être retenu ici.
local postedNames   = {}
local postedMethods = setmetatable({}, { __mode = "k" })
local postedScripts = setmetatable({}, { __mode = "k" })

--- Ce hook était-il déjà posé ? L'inscrit si ce n'est pas le cas.
---@param registry table
---@param host table
---@param name string
---@return boolean  vrai si le hook était déjà là, et qu'il n'y a rien à faire
local function noteOnce(registry, host, name)
    local mine = registry[host]
    if not mine then
        mine = {}
        registry[host] = mine
    end

    if mine[name] then return true end
    mine[name] = true
    return false
end

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
    local body, isEnabled

    if type(target) == "table" then
        body      = bodyOrGuard
        isEnabled = guard

        -- Sur une table hôte, le second argument est **toujours** un nom de
        -- méthode : c'est la forme `U.GuardedHook(frame, "UpdateAuras", …)`.
        -- L'analyse statique ne peut pas le déduire du seul `type(target)`, on
        -- le lui dit.
        ---@cast methodOrFn string
        if noteOnce(postedMethods, target, methodOrFn) then return end
    else
        body      = methodOrFn
        isEnabled = bodyOrGuard
        if postedNames[target] then return end
        postedNames[target] = true
    end

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

--- Même chose pour un **script** d'une frame du client (`OnMouseDown`,
--- `OnHide`…). `HookScript` ne se dépose pas plus que `hooksecurefunc` : on pose
--- le hook une fois, et sa garde le rend inerte quand le module s'éteint.
---
--- `HookScript` et non `SetScript` : le second effacerait le gestionnaire du
--- client, qui ne nous appartient pas — sur un onglet de chat, ce serait le clic
--- qui change d'onglet.
---
---     U.GuardedScript(tab, "OnMouseDown", function(_, button) ... end,
---                     function() return mod:IsEnabled() end)
---
---@param frame table
---@param script string
---@param body function
---@param guard? fun(): boolean
function U.GuardedScript(frame, script, body, guard)
    if type(frame) ~= "table" or type(frame.HookScript) ~= "function" then return end

    -- Son propre registre, et non celui des méthodes : rien ne garantit qu'un
    -- cadre n'ait pas une méthode portant le nom d'un de ses scripts, et un
    -- préfixe qui les distinguerait serait une chaîne à fabriquer.
    if noteOnce(postedScripts, frame, script) then return end

    frame:HookScript(script, function(...)
        if guard and not guard() then return end
        body(...)
    end)
end
