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

--- La liste des catégories vit dans son propre conteneur, pour pouvoir céder
--- la place aux résultats de recherche d'un seul `Hide` — et la reprendre de
--- même. Les deux vivent côte à côte dans la zone défilante ; un seul des deux
--- est visible à la fois.
local content        --- frame de contenu de la zone défilante
local list           --- conteneur de la liste des catégories
local listHeight = 0
local resultsFrame   --- conteneur des résultats de recherche
local resultHeaders = {}   --- pool d'en-têtes de module (réutilisés, règle 7)
local resultRows    = {}   --- pool de lignes de résultat
local resultsHint          --- « aucun résultat » / « affinez la recherche »

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
---@param parent table  frame de contenu de la zone défilante de la colonne
---@param onSelect fun(moduleName: string)
function Sidebar:Build(parent, onSelect)
    if built then return end
    built = true

    content = parent
    list = W.Container(content)
    list:SetPoint("TOPLEFT")
    list:SetPoint("TOPRIGHT")

    local y = -T.SIZE.PADDING * 0.5

    for _, category in ipairs(BUI.CATEGORIES) do
        local modules = BUI.Modules:GetByCategory(category.key)

        if #modules > 0 then
            local header = W.SidebarItem(list, categoryLabel(category, modules), false)
            header:SetPoint("TOPLEFT", list, "TOPLEFT", 0, y)
            header:SetPoint("TOPRIGHT", list, "TOPRIGHT", 0, y)
            y = y - header:GetHeight()

            for _, mod in ipairs(modules) do
                local item = W.SidebarItem(list, moduleLabel(mod), true)
                item:SetPoint("TOPLEFT", list, "TOPLEFT", 0, y)
                item:SetPoint("TOPRIGHT", list, "TOPRIGHT", 0, y)

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

    listHeight = math.abs(y) + T.SIZE.PADDING
    list:SetHeight(listHeight)
    content:SetHeight(listHeight)
end

-- =========================================================================
--  Résultats de recherche
-- =========================================================================
-- La liste des résultats emprunte les pièces de la liste ordinaire : un en-tête
-- de module porte la matière d'un en-tête de catégorie, une ligne de résultat
-- est une entrée de module. Même vocabulaire, donc rien de nouveau à apprendre
-- en la lisant.
--
-- Les lignes sont **réutilisées** d'une frappe à l'autre (une frame ne se
-- détruit pas, règle 7) : on en crée au fil du besoin, on cache le surplus.

---@return table
local function resultsContainer()
    if resultsFrame then return resultsFrame end

    resultsFrame = W.Container(content)
    resultsFrame:SetPoint("TOPLEFT")
    resultsFrame:SetPoint("TOPRIGHT")
    resultsFrame:Hide()

    resultsHint = resultsFrame:CreateFontString(nil, "ARTWORK", T.FONT.HINT)
    resultsHint:SetJustifyH("LEFT")
    resultsHint:SetWordWrap(true)

    return resultsFrame
end

--- Pose la ligne d'appoint à l'ordonnée courante et rend la place qu'elle
--- occupe. Elle suit la liste qu'elle commente : sous le dernier résultat, ou
--- seule en haut quand il n'y en a aucun.
---@param text string
---@param y number
---@return number height
local function placeHint(text, y)
    resultsHint:ClearAllPoints()
    resultsHint:SetPoint("TOPLEFT", resultsFrame, "TOPLEFT", T.SIZE.LABEL_INDENT, y)
    resultsHint:SetPoint("RIGHT", resultsFrame, "RIGHT", -T.SIZE.LABEL_INDENT, 0)
    resultsHint:SetText(text)
    resultsHint:Show()
    return resultsHint:GetStringHeight() + T.SIZE.PADDING
end

--- Une pièce du pool demandé, créée si le pool est trop court.
---@param pool table
---@param i number
---@param indented boolean
---@return table
local function pooled(pool, i, indented)
    local piece = pool[i]
    if not piece then
        piece = W.SidebarItem(resultsFrame, "", indented)
        pool[i] = piece
    end
    return piece
end

--- Affiche les résultats d'une recherche à la place de la liste.
---@param groups table[]   voir `Search:Find`
---@param truncated boolean
---@param onPick fun(moduleName: string, descriptor: table)
function Sidebar:ShowResults(groups, truncated, onPick)
    if not built then return end

    local frame = resultsContainer()
    list:Hide()
    frame:Show()

    local y = -T.SIZE.PADDING * 0.5
    local headerCount, rowCount = 0, 0

    for g = 1, #groups do
        local group = groups[g]
        local mod   = group.module

        headerCount = headerCount + 1
        local header = pooled(resultHeaders, headerCount, false)
        header.text:SetText(mod.title)
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, y)
        header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, y)
        header:Show()
        y = y - header:GetHeight()

        for e = 1, #group.entries do
            local entry = group.entries[e]

            rowCount = rowCount + 1
            local row = pooled(resultRows, rowCount, true)
            row.text:SetText(entry.label)
            row:SetSelected(false)

            -- L'état du module se lit sur ses résultats comme sur son entrée
            -- de la liste : un module éteint reste trouvable, en grisé.
            row:SetAlpha(mod:Get("enabled") and 1 or T.ALPHA.ITEM_OFF)

            -- L'infobulle de la ligne de résultat est celle du réglage
            -- lui-même : on sait ce qu'on va ouvrir avant de cliquer.
            W.Tooltip(row, entry.label, entry.descriptor.tooltip)

            row:SetScript("OnClick", function()
                PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
                onPick(mod.name, entry.descriptor)
            end)

            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, y)
            row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, y)
            row:Show()
            y = y - row:GetHeight()
        end

        y = y - T.SIZE.ROW_GAP
    end

    for i = headerCount + 1, #resultHeaders do resultHeaders[i]:Hide() end
    for i = rowCount + 1, #resultRows do resultRows[i]:Hide() end

    -- La ligne d'appoint ne dit que ce que la liste ne montre pas d'elle-même :
    -- qu'il n'y a rien, ou qu'il y a plus que ce qu'elle affiche.
    if rowCount == 0 then
        y = y - placeHint(L["No results"], y)
    elseif truncated then
        y = y - placeHint(L["More results hint"], y)
    else
        resultsHint:Hide()
    end

    local height = math.abs(y) + T.SIZE.PADDING
    frame:SetHeight(height)
    content:SetHeight(height)
end

--- Rend la place à la liste des catégories.
function Sidebar:ClearResults()
    if not built then return end
    if resultsFrame then resultsFrame:Hide() end
    list:Show()
    content:SetHeight(listHeight)
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
