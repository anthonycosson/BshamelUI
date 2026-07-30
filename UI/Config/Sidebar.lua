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
            local header = W.SidebarItem(content, L[category.label], false)
            header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
            header:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, y)
            y = y - header:GetHeight()

            for _, mod in ipairs(modules) do
                local item = W.SidebarItem(content, mod.title, true)
                item:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
                item:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, y)
                item:SetScript("OnClick", function()
                    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
                    onSelect(mod.name)
                end)
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

--- Grise l'entrée d'un module éteint : l'état du module se lit dans la
--- navigation, sans avoir à ouvrir la page.
---@param moduleName string
---@param enabled boolean
function Sidebar:SetModuleEnabled(moduleName, enabled)
    local item = items[moduleName]
    if not item then return end
    item:SetAlpha(enabled and 1 or T.ALPHA.ITEM_OFF)
end

--- Réapplique l'opacité de toutes les entrées d'après la base.
function Sidebar:RefreshStates()
    for name, item in pairs(items) do
        local mod = BUI.Modules:Get(name)
        if mod then
            item:SetAlpha(mod:Get("enabled") and 1 or T.ALPHA.ITEM_OFF)
        end
    end
end
