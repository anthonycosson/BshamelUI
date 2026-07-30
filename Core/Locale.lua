-- =========================================================================
--  Bshamel UI — Core/Locale.lua
--  Table de traduction unique, avec repli sur enUS puis sur la clé elle-même.
--
--  Une clé manquante n'est jamais une erreur : elle s'affiche telle quelle.
--  On garde donc des clés lisibles en anglais plutôt que des identifiants
--  opaques — un oubli de traduction dégrade l'affichage, il ne le casse pas.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI

local L = setmetatable({}, {
    __index = function(_, key) return key end,
})

ns.L  = L
BUI.L = L

local CLIENT_LOCALE = GetLocale()

--- Déclare un jeu de traductions.
--- `enUS` est toujours appliqué (c'est la base) ; les autres locales ne sont
--- appliquées que si elles correspondent au client, et écrasent la base.
---@param locale string  code de locale, ex. "frFR"
---@param entries table<string, string>
function BUI:RegisterLocale(locale, entries)
    if locale ~= "enUS" and locale ~= CLIENT_LOCALE then return end
    for key, value in pairs(entries) do
        if value ~= true then -- `true` = « identique à enUS », rien à faire
            L[key] = value
        end
    end
end

--- Formatage localisé : `BUI:Lf("%d quêtes", n)`.
---@param key string
---@return string
function BUI:Lf(key, ...)
    return string.format(L[key], ...)
end
