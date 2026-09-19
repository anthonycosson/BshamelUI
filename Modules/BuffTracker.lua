-- =========================================================================
--  Bshamel UI — Modules/BuffTracker.lua
--  Suivi des buffs du joueur : un panneau qui liste les bonus qu'on a choisi
--  de suivre, en vert quand on les a, en blanc quand ils manquent.
--
--  *Forever* seulement (sa ligne du `.toc` porte `[AllowLoadGameType camelot]`).
--  Il y prend la place de « BL et résurrection », qui n'y a pas de sens. C'est
--  un module **à lui** et non celui-là renommé : le nom d'un module est une clé
--  de base de données, et le renommer casserait les réglages de retail.
--
--  Ce qu'on suit et d'où ça vient vit dans `BuffTrackerData.lua`, chargé
--  avant : ce fichier-ci en fait une page, lit les auras et remplit le panneau
--  (`W.BuffList`).
--
--  **C'est le joueur qui coche ce qu'il suit** : l'interrupteur, puis une case
--  par ligne, toutes éteintes (CLAUDE.md §4). La page et le panneau écrivent
--  une ligne de la même façon. Un buff se nomme par ce qu'il donne
--  (« Intelligence »), et l'infobulle dit qui le donne : « Intelligence des
--  Arcanes (Mage), Bougie d'encens (Herboristerie) ».
--
--  Le joueur seul : pas le groupe. Les auras d'un autre joueur ne disent pas si
--  c'est à lui d'y remédier, les siennes si.
--
--  Réversibilité (règle 6) : le module n'ajoute qu'un panneau, qui se cache.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local U    = BUI.Util
local W    = BUI.Widgets
local L    = ns.L
local D    = ns.BuffTrackerData

local MODULE = "BuffTracker"

--- Préfixe des réglages « suivre cette ligne » : `track_fortitude`…
local TRACK = "track_"

--- Les trois catégories, dans l'ordre de la page et du panneau.
local GROUPS = {
    { header = "Buffs header", entries = D.BUFFS },
    { header = "Consumables",  entries = D.CONSUMABLES },
    { header = "Weapon",       entries = D.WEAPON },
}

-- =========================================================================
--  Noms et origines
-- =========================================================================

--- Nom d'un sort dans la langue du client, ou `nil` s'il ne le connaît pas.
---@param spellID integer|nil
---@return string|nil
local function spellName(spellID)
    if not (spellID and C_Spell and C_Spell.GetSpellName) then return nil end
    local name = C_Spell.GetSpellName(spellID)
    if type(name) == "string" and name ~= "" then return name end
    return nil
end

--- Nom d'une source ou d'une ligne : l'objet de camp et le buff de classe par
--- le client, le reste par sa clé de locale.
---@param item BUI.BuffSource|BUI.BuffEntry
---@return string
local function nameOf(item)
    if item.benefit then return L[item.benefit] end
    if item.camp  then return spellName(item.camp) or "?" end
    if item.label then return L[item.label] end
    return spellName(item.name or (item.ids and item.ids[1])) or "?"
end

--- Texte d'une ligne, sur la page comme au panneau : son nom, puis chacune de
--- ses autres sources. Une source qui répète la précédente (deux groupes
--- d'élixirs) ne s'écrit qu'une fois.
---@param entry BUI.BuffEntry
---@return string
local function lineText(entry)
    -- Un buff se lit par ce qu'il donne : ses sources sont dans l'infobulle.
    if entry.benefit then return nameOf(entry) end

    local parts = { nameOf(entry) }
    for i = 1, #(entry.sources or {}) do
        local name = nameOf(entry.sources[i])
        if name ~= parts[#parts] then parts[#parts + 1] = name end
    end
    return table.concat(parts, L["Buff separator"])
end

--- Nom d'un métier dans la langue du client.
---@param skillLine integer
---@return string|nil
local function professionName(skillLine)
    if C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillDisplayName then
        local ok, name = pcall(C_TradeSkillUI.GetTradeSkillDisplayName, skillLine)
        if ok and type(name) == "string" and name ~= "" then return name end
    end
    return nil
end

---@param skills integer[]|nil
---@return string|nil
local function professions(skills)
    if not skills then return nil end
    local names = {}
    for i = 1, #skills do
        names[#names + 1] = professionName(skills[i])
    end
    if #names == 0 then return nil end
    return table.concat(names, ", ")
end

--- Nom d'une classe dans la langue du client, à sa couleur.
---@param class string
---@return string
local function className(class)
    local names = LOCALIZED_CLASS_NAMES_MALE
    local name  = (type(names) == "table" and names[class]) or class
    local color = T.ClassColor(class)
    return color and color:WrapTextInColorCode(name) or name
end

--- D'où vient une source : objet de camp et son métier, ou métier.
---@param source BUI.BuffSource|BUI.BuffEntry
---@return string
local function originOf(source)
    local name = nameOf(source)
    if source.camp then
        return L["Buff via camp"]:format(name, professions(source.skills) or "?")
    end
    local craft = professions(source.skills)
    if craft then return L["Buff via profession"]:format(name, craft) end
    return name
end

--- Ce qui donne un buff, sur une ligne : « Intelligence des Arcanes (Mage),
--- Bougie d'encens (Herboristerie) ». Le sort de classe à la couleur de sa
--- classe, chaque objet de camp avec le métier qui le fabrique.
---@param entry BUI.BuffEntry
---@return string
local function givers(entry)
    local parts = {}
    if entry.class then
        parts[#parts + 1] = L["Buff giver"]:format(spellName(entry.name) or "?",
                                                  className(entry.class))
    end
    if entry.camp then
        parts[#parts + 1] = L["Buff giver"]:format(spellName(entry.camp) or "?",
                                                  professions(entry.skills) or "?")
    end
    for i = 1, #(entry.sources or {}) do
        local source = entry.sources[i]
        parts[#parts + 1] = L["Buff giver"]:format(nameOf(source),
                                                  professions(source.skills) or "?")
    end
    return table.concat(parts, ", ")
end

--- L'infobulle d'une ligne : chacune de ses sources, et d'où elle vient.
---@param entry BUI.BuffEntry
---@return string
local function sourceText(entry)
    if entry.benefit then return givers(entry) end

    local lines = {}
    local camp  = false

    if entry.class then
        lines[#lines + 1] = L["Buff source class"]:format(className(entry.class))
    end
    if entry.camp then
        -- Une ligne que son objet de camp nomme : elle dit d'abord d'où il vient.
        lines[#lines + 1] = originOf(entry)
        camp = true
    else
        local own = professions(entry.skills)
        if own then lines[#lines + 1] = L["Buff source profession"]:format(own) end
    end

    if entry.kinds then
        local kinds = {}
        for i = 1, #entry.kinds do kinds[i] = L[entry.kinds[i]] end
        lines[#lines + 1] = L["Buff kinds"]:format(table.concat(kinds, ", "))
    end

    for i = 1, #(entry.sources or {}) do
        local source = entry.sources[i]
        lines[#lines + 1] = originOf(source)
        if source.camp then camp = true end
    end

    if camp then lines[#lines + 1] = L["Buff source campfire"] end
    if entry.note then lines[#lines + 1] = L[entry.note] end
    return table.concat(lines, "\n")
end

-- =========================================================================
--  Lecture des auras et de l'arme
-- =========================================================================

--- Auras du joueur à l'instant du dernier passage : identifiant -> vrai.
--- Réutilisée d'un passage à l'autre (règle 7).
local present = {}

--- Relit les buffs du joueur. Rend `false` si le client a caché ce qu'il
--- porte (valeur **secrète**) : on garde alors l'état d'avant plutôt que
--- d'annoncer que tout manque.
---@return boolean
local function readAuras()
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return false end

    wipe(present)
    for i = 1, 255 do
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
        if not ok then return false end
        if not aura then break end

        local id = aura.spellId
        if U.IsSecret(id) then return false end
        if id then present[id] = true end
    end
    return true
end

--- L'arme porte-t-elle une amélioration temporaire — pierre, huile, arme de
--- chaman, poison ? Toutes occupent la même place.
---@return boolean
local function weaponEnhanced()
    if not GetWeaponEnchantInfo then return false end
    local mainHand, _, _, _, offHand = GetWeaponEnchantInfo()
    return U.IsTrue(mainHand) or U.IsTrue(offHand)
end

--- L'arme à distance porte-t-elle une lunette ? C'est le seul enchantement
--- permanent qu'elle reçoit, et il s'écrit dans son lien, deuxième champ.
---@return boolean
local function rangedScoped()
    if not (GetInventorySlotInfo and GetInventoryItemLink) then return false end
    local ok, slot = pcall(GetInventorySlotInfo, "RangedSlot")
    if not (ok and slot) then return false end

    local link = GetInventoryItemLink("player", slot)
    if type(link) ~= "string" or U.IsSecret(link) then return false end

    local enchant = link:match("item:%d+:(%d*)")
    return enchant ~= nil and enchant ~= "" and enchant ~= "0"
end

---@param item BUI.BuffSource|BUI.BuffEntry
---@return boolean
local function has(item)
    for i = 1, #(item.ids or {}) do
        if present[item.ids[i]] then return true end
    end
    return false
end

--- La ligne est-elle couverte, par elle-même ou l'une de ses sources ?
---@param entry BUI.BuffEntry
---@return boolean
local function isActive(entry)
    if entry.weapon == "temp"  then return weaponEnhanced() end
    if entry.weapon == "scope" then return rangedScoped() end
    if has(entry) then return true end
    for i = 1, #(entry.sources or {}) do
        if has(entry.sources[i]) then return true end
    end
    return false
end

-- =========================================================================
--  Le panneau
-- =========================================================================

local panel
--- Lignes du panneau, réutilisées d'un passage à l'autre.
local lines = {}

---@param mod table
local function refresh(mod)
    if not mod:Get("trackBuffs") then
        if panel then panel:Hide() end
        return
    end

    local fresh = readAuras()

    local count = 0
    for g = 1, #GROUPS do
        local entries = GROUPS[g].entries
        for i = 1, #entries do
            local entry = entries[i]
            if mod:Get(TRACK .. entry.key) then
                count = count + 1
                local line = lines[count] or {}
                lines[count] = line

                line.text     = lineText(entry)
                line.tipTitle = nameOf(entry)
                line.tip      = sourceText(entry)

                -- Relecture refusée : la ligne garde l'état du passage d'avant.
                if fresh or line.key ~= entry.key then
                    line.active = isActive(entry)
                end
                line.key = entry.key
            end
        end
    end
    for i = #lines, count + 1, -1 do lines[i] = nil end

    if count == 0 then
        if panel then panel:Hide() end
        return
    end

    if not panel then
        panel = W.BuffList({
            title  = L["Buff panel title"],
            getPos = function() return mod:Get("panelX"), mod:Get("panelY") end,
            setPos = function(x, y)
                mod:Set("panelX", x)
                mod:Set("panelY", y)
            end,
        })
    end

    panel:SetLines(lines)
    panel:ApplyPosition()
    panel:Show()
end

-- =========================================================================
--  La page
-- =========================================================================

--- Grise une ligne tant que le suivi est éteint.
---@return boolean
local function trackingOff()
    local mod = BUI.Modules:Get(MODULE)
    return not (mod and mod:Get("trackBuffs"))
end

---@return boolean
local function always() return true end

local defaults = {
    trackBuffs = false,
    panelX     = 0,
    panelY     = 200,
}

local options = {
    { type = "header", text = L["General"] },
    {
        type    = "toggle",
        key     = "trackBuffs",
        text    = L["Enable buff tracking"],
        tooltip = L["Enable buff tracking tip"],
    },
}

-- Une case par ligne, décochée : c'est le joueur qui choisit ce qu'il suit.
for g = 1, #GROUPS do
    local group = GROUPS[g]
    options[#options + 1] = { type = "header", text = L[group.header] }

    for i = 1, #group.entries do
        local entry = group.entries[i]
        defaults[TRACK .. entry.key] = false
        options[#options + 1] = {
            type     = "toggle",
            key      = TRACK .. entry.key,
            text     = lineText(entry),
            -- Une fonction : le nom des métiers se demande au client au moment
            -- du survol, quand il est sûr de le connaître.
            tooltip  = function() return sourceText(entry) end,
            disabled = trackingOff,
        }
    end
end

-- Ce qui attend une décision, puis ce qui attend une version : affichés
-- grisés, pour que rien ne s'oublie. Leur case n'agit sur rien.
local PARKED = {
    { header = "Pending buffs", entries = D.PENDING },
    { header = "World buffs",   entries = D.WORLD, reason = "Future version" },
}

for p = 1, #PARKED do
    local parked = PARKED[p]
    options[#options + 1] = { type = "header", text = L[parked.header] }

    for i = 1, #parked.entries do
        local entry = parked.entries[i]
        defaults["parked_" .. entry.key] = false
        options[#options + 1] = {
            type           = "toggle",
            key            = "parked_" .. entry.key,
            text           = nameOf(entry),
            disabled       = always,
            disabledReason = L[entry.reason or parked.reason],
        }
    end
end

-- =========================================================================
--  Déclaration du module
-- =========================================================================

BUI:RegisterModule(MODULE, {
    title    = L["Buff tracking"],
    category = "MythicRaid",
    order    = 20,

    defaults = defaults,
    options  = options,

    OnEnable = function(self)
        local later = U.Debounce(T.TIMING.BUFF_SCAN, function() refresh(self) end)

        self:RegisterEvent("UNIT_AURA", function(_, unit)
            if unit == "player" then later() end
        end)
        -- Pierres, huiles et lunettes ne sont pas des auras : c'est l'arme qui
        -- change, et c'est cet événement qui le dit.
        self:RegisterEvent("UNIT_INVENTORY_CHANGED", function(_, unit)
            if unit == "player" then later() end
        end)
        self:RegisterEvent("PLAYER_ENTERING_WORLD", later)

        refresh(self)
    end,

    OnDisable = function()
        if panel then panel:Hide() end
    end,

    OnSettingChanged = function(self)
        refresh(self)
    end,
})
