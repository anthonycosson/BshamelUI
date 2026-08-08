-- =========================================================================
--  Bshamel UI — UI/Config/Search.lua
--  Moteur de la recherche d'options : l'index, et la correspondance.
--
--  L'index recense chaque ligne réglable déclarée par les modules — leur table
--  `options`, la même que celle que `PageBuilder` transforme en widgets. Il n'y
--  a donc rien à déclarer pour être trouvé : une option existe, elle se
--  cherche. C'est la conséquence voulue de « les modules ne dessinent pas »
--  (CLAUDE.md règle 2) : la structure qui fait les pages fait aussi l'index.
--
--  La correspondance est insensible à la casse **et aux accents** : on cherche
--  « reparation » et on trouve « Réparation ». Chaque mot tapé doit se
--  retrouver quelque part dans le libellé, l'infobulle ou le titre de la page —
--  l'infobulle comprise, parce que c'est elle qui porte le vocabulaire qu'on
--  tape quand on ne connaît pas le nom exact du réglage.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI

local Search = {}
BUI.Search = Search

--- En dessous, la saisie est un début de geste, pas une question : deux lettres
--- allumeraient la moitié de l'index.
Search.MIN_CHARS = 2

--- Plafond de résultats. Au-delà, la requête est trop large pour que la liste
--- serve à quelque chose — c'est en la précisant qu'on la raccourcit.
local MAX_RESULTS = 60

--- Types de descripteur qui portent un réglage sur lequel on peut atterrir.
--- Les en-têtes, paragraphes et coupures de colonne n'en sont pas.
local SEARCHABLE = {
    toggle   = true,
    slider   = true,
    dropdown = true,
    color    = true,
    button   = true,
}

-- =========================================================================
--  Pliage : casse et accents
-- =========================================================================

--- Équivalents non accentués, en minuscules et en majuscules : `strlower` ne
--- descend que l'ASCII, les capitales accentuées se plient donc explicitement.
--- La table couvre le français, qui est la seule locale traduite (règle 5).
local FOLD = {
    ["à"] = "a", ["â"] = "a", ["ä"] = "a", ["À"] = "a", ["Â"] = "a", ["Ä"] = "a",
    ["é"] = "e", ["è"] = "e", ["ê"] = "e", ["ë"] = "e",
    ["É"] = "e", ["È"] = "e", ["Ê"] = "e", ["Ë"] = "e",
    ["î"] = "i", ["ï"] = "i", ["Î"] = "i", ["Ï"] = "i",
    ["ô"] = "o", ["ö"] = "o", ["Ô"] = "o", ["Ö"] = "o",
    ["ù"] = "u", ["û"] = "u", ["ü"] = "u", ["Ù"] = "u", ["Û"] = "u", ["Ü"] = "u",
    ["ç"] = "c", ["Ç"] = "c",
    ["œ"] = "oe", ["Œ"] = "oe", ["æ"] = "ae", ["Æ"] = "ae",
}

---@param text string
---@return string
local function fold(text)
    text = strlower(text)
    for accented, plain in pairs(FOLD) do
        text = text:gsub(accented, plain)
    end
    return text
end

-- =========================================================================
--  Index
-- =========================================================================

--- Entrées : { module, descriptor, label, haystack }. Construit au premier
--- besoin — tous les modules sont enregistrés bien avant que la fenêtre
--- d'options n'existe — puis conservé : les tables `options` ne bougent plus.
local index

local function buildIndex()
    index = {}

    for _, category in ipairs(BUI.CATEGORIES) do
        local modules = BUI.Modules:GetByCategory(category.key)

        for m = 1, #modules do
            local mod = modules[m]

            -- Une annonce ne s'ouvre pas depuis la colonne : elle ne s'atteint
            -- pas davantage par la recherche.
            if not mod.preview then
                local title   = fold(tostring(mod.title or mod.name))
                local options = mod.options or {}

                for i = 1, #options do
                    local descriptor = options[i]

                    if SEARCHABLE[descriptor.type]
                        and type(descriptor.text) == "string" then
                        local haystack = title .. " " .. fold(descriptor.text)

                        -- L'infobulle peut être calculée ; on n'indexe que ce
                        -- qui est écrit — une fonction rend un texte d'état,
                        -- pas un vocabulaire.
                        if type(descriptor.tooltip) == "string" then
                            haystack = haystack .. " " .. fold(descriptor.tooltip)
                        end

                        index[#index + 1] = {
                            module     = mod,
                            descriptor = descriptor,
                            label      = descriptor.text,
                            haystack   = haystack,
                        }
                    end
                end
            end
        end
    end
end

-- =========================================================================
--  Correspondance
-- =========================================================================

--- La requête, découpée en mots pliés. Table de travail réutilisée (règle 7) :
--- la fonction tourne à chaque frappe.
local words = {}

---@param query string
---@return number count
local function splitQuery(query)
    for i = #words, 1, -1 do words[i] = nil end
    for word in fold(query):gmatch("%S+") do
        words[#words + 1] = word
    end
    return #words
end

---@param haystack string
---@return boolean
local function matches(haystack)
    for i = 1, #words do
        -- Recherche en texte brut : un mot tapé n'est pas un motif Lua, et un
        -- « % » ou un « - » saisi ne doit pas changer le sens de la question.
        if not haystack:find(words[i], 1, true) then return false end
    end
    return true
end

--- Cherche. Rend les résultats **groupés par module**, dans l'ordre de la
--- colonne de navigation, et dit s'il en restait au-delà du plafond.
---@param query string
---@return table[] groups  { module, entries = { { descriptor, label }, ... } }
---@return boolean truncated
function Search:Find(query)
    if not index then buildIndex() end

    local groups = {}
    local total  = 0

    if splitQuery(query) == 0 then return groups, false end

    local current
    for i = 1, #index do
        local entry = index[i]

        if matches(entry.haystack) then
            if total >= MAX_RESULTS then return groups, true end
            total = total + 1

            -- L'index est déjà dans l'ordre de la colonne : un groupe se ferme
            -- dès qu'une entrée d'un autre module arrive.
            if not current or current.module ~= entry.module then
                current = { module = entry.module, entries = {} }
                groups[#groups + 1] = current
            end
            current.entries[#current.entries + 1] = entry
        end
    end

    return groups, false
end
