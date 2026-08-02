-- =========================================================================
--  Bshamel UI — UI/Config/Sidebar.lua
--  Colonne de navigation : catégories en dur (Core/Module.lua), modules
--  remplis dynamiquement par ceux qui se sont enregistrés.
--
--  Une catégorie sans module ne s'affiche pas : la liste reflète ce qui est
--  réellement installé, elle n'annonce pas des sections vides.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local W    = BUI.Widgets
local L    = ns.L

local Sidebar = {}
BUI.Sidebar = Sidebar

local items = {}      --- moduleName -> bouton
local built = false

--- Intitulé d'une catégorie, suivi d'une mention quand **tous** ses modules sont
--- en avant-première.
---
--- Tous, et non certains : une catégorie où un module sur trois est écrit
--- fonctionne, et la coiffer d'un « prochainement » ferait passer à côté des
--- deux autres. Quand la catégorie entière est à venir, en revanche, la mention
--- évite d'avoir à ouvrir quatre pages pour découvrir qu'aucune n'est allumable.
---@param category table
---@param modules table[]
---@return string
local function categoryLabel(category, modules)
    for i = 1, #modules do
        if not modules[i].preview then return L[category.label] end
    end
    return L[category.label] .. L["Coming soon suffix"]
end

--- Intitulé d'une entrée de module, suivi de la même mention quand celui-ci est
--- une annonce.
---
--- La mention est portée par l'entrée elle-même et pas seulement par sa
--- catégorie : une catégorie qui mêle des modules écrits et des annonces n'en
--- reçoit aucune, et sans cette ligne rien ne distinguerait les secondes des
--- premières.
---@param mod table
---@return string
local function moduleLabel(mod)
    if not mod.preview then return mod.title end
    return mod.title .. L["Coming soon suffix"]
end

--- Construit la liste. Appelé une fois, après PLAYER_LOGIN, quand tous les
--- modules se sont enregistrés.
---@param content table  frame de contenu de la zone défilante de la colonne
---@param onSelect fun(moduleName: string)
function Sidebar:Build(content, onSelect)
    if built then return end
    built = true

    local y = -T.SIZE.PADDING * 0.5

    for _, category in ipairs(BUI.CATEGORIES) do
        local modules = BUI.Modules:GetByCategory(category.key)

        if #modules > 0 then
            local header = W.SidebarItem(content, categoryLabel(category, modules), false)
            header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
            header:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, y)
            y = y - header:GetHeight()

            for _, mod in ipairs(modules) do
                local item = W.SidebarItem(content, moduleLabel(mod), true)
                item:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
                item:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, y)

                -- Une annonce ne s'ouvre pas. Elle occupe sa place dans la
                -- colonne pour dire ce qui vient, et rien de plus : lui donner un
                -- clic mènerait à une page vide, ce qui se lit comme une panne
                -- plutôt que comme une promesse.
                if mod.preview then
                    item:EnableMouse(false)
                else
                    item:SetScript("OnClick", function()
                        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
                        onSelect(mod.name)
                    end)
                end

                items[mod.name] = item
                y = y - item:GetHeight()
            end

            y = y - T.SIZE.ROW_GAP
        end
    end

    content:SetHeight(math.abs(y) + T.SIZE.PADDING)
end

--- Met en évidence l'entrée du module courant.
---@param moduleName string
function Sidebar:SetSelected(moduleName)
    for name, item in pairs(items) do
        item:SetSelected(name == moduleName)
    end
end

--- Nom du premier module de la liste, utilisé comme page par défaut à
--- l'ouverture.
---@return string|nil
function Sidebar:FirstModuleName()
    for _, category in ipairs(BUI.CATEGORIES) do
        local modules = BUI.Modules:GetByCategory(category.key)
        if #modules > 0 then return modules[1].name end
    end
    return nil
end

--- Opacité de l'entrée d'un module.
---
--- Un module **éteint** est grisé : son état se lit dans la navigation, sans
--- avoir à ouvrir la page.
---
--- Un module **en avant-première** l'est aussi, et pour une autre raison : il
--- n'est pas éteint, il n'existe pas encore. Grisé et sans clic, il se lit comme
--- ce qu'il est — une annonce —, là où une entrée pleinement lisible promet une
--- page qui s'ouvrirait.
---
--- Les deux états se ressemblent donc à l'œil, et c'est acceptable tant qu'ils
--- se distinguent au geste : l'un s'ouvre et se rallume, l'autre ne répond pas.
---@param mod table
---@return number
local function itemAlpha(mod)
    if mod.preview then return T.ALPHA.ITEM_OFF end
    return mod:Get("enabled") and 1 or T.ALPHA.ITEM_OFF
end

---@param moduleName string
---@param enabled boolean
function Sidebar:SetModuleEnabled(moduleName, enabled)
    local item = items[moduleName]
    if not item then return end

    local mod = BUI.Modules:Get(moduleName)
    item:SetAlpha(mod and itemAlpha(mod) or (enabled and 1 or T.ALPHA.ITEM_OFF))
end

--- Réapplique l'opacité de toutes les entrées d'après la base.
function Sidebar:RefreshStates()
    for name, item in pairs(items) do
        local mod = BUI.Modules:Get(name)
        if mod then
            item:SetAlpha(itemAlpha(mod))
        end
    end
end
