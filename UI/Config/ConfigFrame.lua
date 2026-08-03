-- =========================================================================
--  Bshamel UI — UI/Config/ConfigFrame.lua
--  Assemblage de la fenêtre d'options.
--
--      +---------------------------------------------------------+
--      | Bshamel UI                                          [X] |
--      | +------------+                                          |
--      | |▓ GÉNÉRAL ▓ |  Quête                                   |
--      | |   ...      | ---------------------------------------- |
--      | |▓ QOL     ▓ |                                          |
--      | |   Chat     |   Accepter automatiquement les quêtes  ☐ |
--      | | > Quête    |   Rendre automatiquement les quêtes    ☐ |
--      | |   ...      |                                          |
--      | +------------+                                          |
--      +---------------------------------------------------------+
--
--  Un seul creux dans la fenêtre, à gauche, autour de la navigation. La zone de
--  contenu est posée à même le fond translucide et n'est délimitée que par le
--  filet sous le titre de page : deux panneaux encadrés côte à côte se
--  disputeraient le regard.
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
local body             --- tout ce qui vit sous la barre de titre
local pageTitle        --- bloc du titre de page
local contentScroll    --- zone défilante de droite
local contentHolder    --- frame de contenu de cette zone
local currentModule    --- nom du module affiché
local scaleMenu        --- menu d'échelle, dans la barre de titre

-- =========================================================================
--  Échelle du contenu
-- =========================================================================
-- Compacter la fenêtre sans la rétrécir : la taille reste celle qu'on a réglée
-- en tirant le coin, mais ce qu'il y a dedans devient plus petit, donc il en
-- tient davantage. C'est le réglage qu'on cherche quand une page compte quarante
-- lignes.
--
-- **Une seule frame est mise à l'échelle**, celle qui porte tout ce qui vit sous
-- la barre de titre. Elle est ancrée par ses quatre coins à la fenêtre : son
-- emprise à l'écran ne bouge donc pas, seule son unité de mesure change, et tout
-- ce qu'elle contient suit sans qu'aucune pièce ait à le savoir.
--
-- Mettre à l'échelle chaque panneau séparément aurait marché aussi, mais les
-- écarts entre eux seraient restés à la mesure de la fenêtre pendant que leur
-- contenu rétrécissait — une colonne compacte séparée d'une page compacte par
-- une gouttière qui, elle, n'aurait pas bougé.
--
-- La barre de titre, elle, ne suit pas : elle porte la croix de fermeture du
-- client et le bouton qui commande cette échelle. Un bouton qui rapetisse en
-- même temps que ce qu'il règle devient sa propre cible mouvante.

--- Où le réglage est rangé. C'est un réglage sans ligne d'option, comme l'angle
--- du bouton de minicarte : il se change là où il agit — ici, dans la barre de
--- titre — et une case de plus dans une page servirait mal quelque chose qui doit
--- se régler en regardant le résultat.
local SCALE_MODULE, SCALE_KEY = "General", "configScale"

---@return number  pourcentage
local function currentScale()
    local value = BUI.DB:Get(SCALE_MODULE, SCALE_KEY)
    if type(value) ~= "number" then return T.SIZE.CONFIG_SCALE_MAX end
    return value
end

--- Applique l'échelle courante et remesure ce qui en dépend.
local function applyScale()
    if not body then return end

    body:SetScale(currentScale() / 100)
    if scaleMenu then scaleMenu:Refresh() end

    -- Les zones défilantes mesurent leur contenu en unités de la frame qui les
    -- porte : celles-ci viennent de changer de taille, il faut les relire. C'est
    -- aussi ce qui rebascule la page entre une et deux colonnes, la largeur
    -- disponible ayant changé.
    if frame and frame._onResize then frame._onResize() end
end

---@param percent number
local function setScale(percent)
    BUI.DB:Set(SCALE_MODULE, SCALE_KEY, percent)
    applyScale()
end

--- Les valeurs offertes par le menu, du plus grand au plus petit.
---
--- Décroissantes, et c'est le seul ordre juste ici : le menu s'ouvre sur la
--- valeur courante, qui est cent au départ, et ce qu'on cherche en l'ouvrant est
--- **plus petit**. Une liste croissante mettrait ce qu'on veut tout en bas.
---@return table[]
local function scaleValues()
    local S = T.SIZE
    local values = {}

    for percent = S.CONFIG_SCALE_MAX, S.CONFIG_SCALE_MIN, -S.CONFIG_SCALE_STEP do
        values[#values + 1] = {
            value = percent,
            label = string.format(L["Scale percent"], percent),
        }
    end

    return values
end

-- =========================================================================
--  Construction
-- =========================================================================

local function buildFrame()
    frame = W.Window("BshamelUIConfigFrame", L["Bshamel UI"],
                     T.SIZE.WINDOW_W, T.SIZE.WINDOW_H)

    local S = T.SIZE

    -- ----- corps de la fenêtre -----
    -- Une frame nue, tendue entre les quatre coins intérieurs du cadre. Elle ne
    -- se voit pas et ne dessine rien : elle existe pour porter l'échelle du
    -- contenu (voir plus haut). Tout ce qui suit s'ancre sur elle, et non plus
    -- sur la fenêtre — d'où des retraits nuls, le chrome étant déjà déduit ici.
    body = W.Container(frame)
    body:SetPoint("TOPLEFT", frame, "TOPLEFT", S.CHROME_SIDE, -S.CHROME_TOP)
    body:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -S.CHROME_SIDE, S.CHROME_BOTTOM)

    -- ----- colonne de navigation -----
    -- Le panneau est créé avant sa zone défilante : à niveau de frame égal,
    -- c'est l'ordre de création qui décide de l'empilement, et le creux doit
    -- rester sous la liste.
    local sidebarPanel = W.Inset(body)
    sidebarPanel:SetPoint("TOPLEFT", body, "TOPLEFT")
    sidebarPanel:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT")
    sidebarPanel:SetWidth(S.SIDEBAR_W + S.PANEL_PAD * 2)

    -- Colonne sans ascenseur : la liste des modules est courte, une barre y
    -- serait un rappel permanent d'un défilement qui n'a presque jamais lieu.
    -- La molette continue de fonctionner, elle, ce qui suffit si elle déborde.
    local sidebarScroll, sidebarContent = W.ScrollPane(body, true)
    sidebarScroll:SetPoint("TOPLEFT", sidebarPanel, "TOPLEFT", S.PANEL_PAD, -S.PANEL_PAD)
    sidebarScroll:SetPoint("BOTTOMLEFT", sidebarPanel, "BOTTOMLEFT", S.PANEL_PAD, S.PANEL_PAD)
    sidebarScroll:SetWidth(S.SIDEBAR_W)

    -- ----- séparateur -----
    -- Il ne touche ni le haut ni le bas : son dégradé s'éteint aux deux bouts,
    -- il suggère la limite au lieu de couper la fenêtre en deux.
    local divider = W.VerticalDivider(body)
    divider:SetPoint("TOPLEFT", sidebarPanel, "TOPRIGHT", S.GUTTER, 0)
    divider:SetPoint("BOTTOMLEFT", sidebarPanel, "BOTTOMRIGHT", S.GUTTER, 0)

    -- ----- titre de page -----
    pageTitle = W.PageTitle(body)
    pageTitle:SetPoint("TOPLEFT", divider, "TOPRIGHT", S.GUTTER, 0)
    pageTitle:SetPoint("TOPRIGHT", body, "TOPRIGHT")

    -- ----- zone de contenu -----
    contentScroll, contentHolder = W.ScrollPane(body)
    contentScroll:SetPoint("TOPLEFT", pageTitle, "BOTTOMLEFT", 0, -S.GUTTER)
    contentScroll:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -S.SCROLLBAR_W, 0)

    -- ----- barre de titre : l'échelle du contenu -----
    -- À gauche, dans la bande de titre. Le titre du cadre est centré par son
    -- template : la glissière ne le recouvre donc pas, et on n'a rien à déplacer
    -- de ce qui appartient au client.
    --
    -- Ancré par son flanc gauche au **coin** haut-gauche, ce qui le centre
    -- verticalement dans le bandeau sans qu'aucune hauteur soit écrite ici : il
    -- suit la sienne, quel que soit le template retenu.
    scaleMenu = W.TitleDropdown(frame, {
        values = scaleValues(),
        get    = currentScale,
        set    = setScale,
    })
    scaleMenu:SetPoint("LEFT", frame, "TOPLEFT",
                       S.CHROME_SIDE + S.PADDING, -S.CHROME_TOP / 2)
    W.Tooltip(scaleMenu, L["Content scale"], L["Content scale tip"])

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

    -- En dernier : l'échelle relue de la base repasse sur tout ce qui vient
    -- d'être mesuré.
    applyScale()

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

    -- La hauteur du contenu défilant est **écrite**, jamais déduite : déduite,
    -- elle viendrait des rectangles des enfants, et la maquette de barre d'infos
    -- en a de secrets — c'est par là que la plage de défilement s'empoisonnait.
    -- La hauteur de page, elle, est calculée par la mise en page : un nombre
    -- ordinaire, posé par nous.
    local height = page:GetHeight()
    if type(height) == "number" and not BUI.Util.IsSecret(height) and height > 0 then
        contentHolder:SetHeight(height)
    end

    pageTitle:SetTitle(mod.title)
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
        pageTitle:SetTitle(L["Bshamel UI"])
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
