-- =========================================================================
--  Bshamel UI — UI/Config/ConfigFrame.lua
--  Assemblage de la fenêtre d'options.
--
--      +---------------------------------------------------------+
--      | Bshamel UI                                          [X] |
--      +--------------+------------------------------------------+
--      | GÉNÉRAL      | +--------------------------------------+ |
--      |   ...        | | Quête                                | |
--      | QOL          | +--------------------------------------+ |
--      |   Chat       |                                          |
--      | > Quête      |   Accepter automatiquement les quêtes  ☐ |
--      | MYTHIQUE+    |   Rendre automatiquement les quêtes    ☐ |
--      |   ...        |                                          |
--      +--------------+------------------------------------------+
--
--  Construction paresseuse : la fenêtre n'existe qu'au premier `/bui`. Se
--  connecter sans ouvrir les options ne coûte donc aucune frame.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local W    = BUI.Widgets
local L    = ns.L
local PB   = BUI.PageBuilder

local Config = {}
BUI.Config = Config

local frame            --- fenêtre principale
local titleBox         --- encadré du titre de page
local contentScroll    --- zone défilante de droite
local contentHolder    --- frame de contenu de cette zone
local currentModule    --- nom du module affiché

-- =========================================================================
--  Construction
-- =========================================================================

local function buildFrame()
    frame = W.Window("BshamelUIConfigFrame", L["Bshamel UI"],
                     T.SIZE.WINDOW_W, T.SIZE.WINDOW_H)

    local S = T.SIZE

    -- ----- colonne de navigation -----
    local sidebarScroll, sidebarContent = W.ScrollPane(frame)
    sidebarScroll:SetPoint("TOPLEFT", frame, "TOPLEFT", S.CHROME_SIDE, -S.CHROME_TOP)
    sidebarScroll:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", S.CHROME_SIDE, S.CHROME_BOTTOM)
    sidebarScroll:SetWidth(S.SIDEBAR_W)

    -- Séparateur vertical plutôt qu'un second panneau creusé : la maquette
    -- sépare les deux zones par un simple trait.
    -- L'écart vaut `SCROLLBAR_W + GUTTER` : la barre de défilement de la colonne
    -- se pose à l'extérieur du ScrollFrame, il faut donc lui laisser la place
    -- avant le trait.
    local divider = W.VerticalDivider(frame)
    divider:SetPoint("TOPLEFT", sidebarScroll, "TOPRIGHT", S.SCROLLBAR_W + S.GUTTER, 0)
    divider:SetPoint("BOTTOMLEFT", sidebarScroll, "BOTTOMRIGHT", S.SCROLLBAR_W + S.GUTTER, 0)

    -- ----- encadré du titre de page -----
    titleBox = W.PageTitleBox(frame)
    titleBox:SetPoint("TOPLEFT", divider, "TOPRIGHT", S.GUTTER, 0)
    titleBox:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -S.CHROME_SIDE, -S.CHROME_TOP)

    -- ----- zone de contenu -----
    contentScroll, contentHolder = W.ScrollPane(frame)
    contentScroll:SetPoint("TOPLEFT", titleBox, "BOTTOMLEFT", 0, -S.GUTTER)
    contentScroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT",
                           -S.CHROME_SIDE - S.SCROLLBAR_W, S.CHROME_BOTTOM)

    -- ----- pied de fenêtre : version -----
    local version = frame:CreateFontString(nil, "OVERLAY", T.FONT.HINT)
    version:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -S.CHROME_SIDE - 18, S.CHROME_BOTTOM - 6)
    version:SetText(BUI.VERSION)

    frame._onResize = function()
        sidebarScroll:UpdateContentWidth()
        contentScroll:UpdateContentWidth()
        if currentModule then PB:RefreshPage(currentModule) end
    end

    BUI.Sidebar:Build(sidebarContent, function(moduleName)
        Config:SelectModule(moduleName)
    end)

    sidebarScroll:UpdateContentWidth()
    contentScroll:UpdateContentWidth()

    return frame
end

-- =========================================================================
--  Navigation
-- =========================================================================

--- Affiche la page d'un module.
---@param moduleName string
function Config:SelectModule(moduleName)
    local mod = BUI.Modules:Get(moduleName)
    if not mod then return end

    currentModule = moduleName

    PB:HideAll()
    local page = PB:GetPage(contentHolder, mod)
    page:SetWidth(W.ContentWidth(contentScroll))
    page:Show()
    page:Refresh()

    titleBox:SetTitle(mod.title)
    BUI.Sidebar:SetSelected(moduleName)
    contentScroll:ResetScroll()
end

-- =========================================================================
--  Ouverture / fermeture
-- =========================================================================

function Config:Show()
    if not frame then buildFrame() end

    frame:Show()
    BUI.Sidebar:RefreshStates()

    local target = currentModule or BUI.Sidebar:FirstModuleName()
    if target then
        self:SelectModule(target)
    else
        titleBox:SetTitle(L["Bshamel UI"])
    end
end

function Config:Hide()
    if frame then frame:Hide() end
end

function Config:Toggle()
    if frame and frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

---@return boolean
function Config:IsShown()
    return frame ~= nil and frame:IsShown()
end

-- =========================================================================
--  Réaction aux changements d'état
-- =========================================================================

BUI:RegisterMessage(BUI.MESSAGES.SETTING_CHANGED, function(_, moduleName)
    if not Config:IsShown() then return end
    if moduleName == currentModule then PB:RefreshPage(moduleName) end
end)

BUI:RegisterMessage(BUI.MESSAGES.MODULE_STATE, function(_, moduleName, enabled)
    BUI.Sidebar:SetModuleEnabled(moduleName, enabled)
end)

BUI:RegisterMessage(BUI.MESSAGES.PROFILE_CHANGED, function()
    if not Config:IsShown() then return end
    BUI.Sidebar:RefreshStates()
    if currentModule then PB:RefreshPage(currentModule) end
end)

-- =========================================================================
--  Entrée dans les options du client
-- =========================================================================
-- On n'essaie pas de reconstruire nos pages dans le panneau Blizzard : on y
-- pose un simple bouton. Ouvrir notre fenêtre depuis le panneau du client
-- demande de fermer celui-ci **puis** d'ouvrir la nôtre à la frame suivante ;
-- l'enchaîner dans le même appel propage le taint du panneau à notre code.

BUI:RegisterEventOnce("PLAYER_LOGIN", function()
    if not (Settings and Settings.RegisterCanvasLayoutCategory) then return end

    local panel = W.Container()
    panel.name = L["Bshamel UI"]

    local button = W.Button(panel, L["Open Bshamel UI"], function()
        if SettingsPanel and SettingsPanel:IsShown() then
            HideUIPanel(SettingsPanel)
        end
        C_Timer.After(0, function() Config:Show() end)
    end, 200)
    button:SetPoint("TOPLEFT", T.SIZE.PADDING, -T.SIZE.PADDING)

    local category = Settings.RegisterCanvasLayoutCategory(panel, L["Bshamel UI"])
    Settings.RegisterAddOnCategory(category)
end)
