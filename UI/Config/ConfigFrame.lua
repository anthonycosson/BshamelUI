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
local currentPage      --- page affichée, celle du module ci-dessus
local scaleMenu        --- menu d'échelle, dans la barre de titre
local searchBox        --- zone de recherche, en tête de la colonne
local editButton       --- bascule du mode édition, sous la recherche

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

-- =========================================================================
--  La largeur qu'une page réclame
-- =========================================================================
-- Une page peut **exiger** ses deux colonnes — celle des barres d'infos les
-- exige : ses deux moitiés sont les réglages du jeu et les nôtres, et les lire
-- l'une sous l'autre revient à ne plus pouvoir les comparer, ce qui est tout ce
-- qu'on lui demande. La coupure ne se replie donc pas sur une colonne unique
-- (voir `PageBuilder.layout`), et c'est la **fenêtre** qui s'adapte.
--
-- La largeur qui manque n'est pas calculée d'après les mesures du thème : on
-- mesure ce que la zone de contenu offre à cet instant, et on ajoute au cadre ce
-- qui lui manque. Tout ce qui se tient entre le bord de la fenêtre et cette
-- zone — la colonne de navigation, le filet, l'ascenseur, l'échelle du contenu —
-- est ainsi compté sans qu'aucun de ces nombres ait à être écrit ici.

--- Largeur réglée par le joueur, mise de côté le temps d'une page large. `nil`
--- quand il n'y a rien à rendre.
local playerWidth

--- Une mesure dont on peut faire quelque chose, ou `nil`.
---
--- Trois refus, et le premier est le seul qui compte : **une mesure secrète ne
--- s'additionne pas**. Un cadre monté depuis un template du client peut en
--- rendre une, et l'arithmétique lève alors dans notre code — c'est le piège que
--- cette page a déjà tendu deux fois, à la hauteur de page et à la plage de
--- défilement.
---@param value any
---@return number|nil
local function measure(value)
    if type(value) ~= "number" then return nil end
    if BUI.Util.IsSecret(value) then return nil end
    if value ~= value then return nil end                 -- NaN
    return value
end

--- Ramène la fenêtre dans l'écran après un élargissement.
---
--- `SetClampedToScreen` ne joue qu'au **déplacement** : une fenêtre qu'on
--- élargit franchit le bord droit sans que rien ne la retienne, et ce qui sort
--- est la moitié droite de la page — la nôtre. On la décale de ce qui dépasse,
--- jamais au-delà du bord gauche, et seulement quand elle dépasse : une fenêtre
--- qui tient dans l'écran ne bouge pas d'un pixel.
local function keepOnScreen()
    local screen = measure(UIParent:GetWidth())
    local width  = measure(frame:GetWidth())
    local left   = measure(frame:GetLeft())
    local top    = measure(frame:GetTop())
    if not (screen and width and left and top) then return end

    local overflow = (left + width) - screen
    if overflow <= 0 then return end

    -- Reposée en coordonnées d'écran : c'est le seul ancrage qui garde la
    -- fenêtre là où elle est, quel que soit le point que le joueur lui a donné
    -- en la déplaçant.
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT",
                   math.max(left - overflow, 0), top)
end

--- Élargit la fenêtre pour la page qu'on ouvre, ou lui rend la largeur du
--- joueur en la quittant. **Rend la largeur à laquelle la page doit se
--- disposer**, ou `nil` si rien n'était mesurable.
---
--- Ce retour n'est pas une commodité. Un cadre qui vient de changer de taille ne
--- la propage pas à ses enfants dans la même image : lire la zone de contenu
--- juste après avoir élargi la fenêtre rend la largeur **d'avant**, et la page
--- se dispose alors pour la fenêtre qu'on vient de quitter — paragraphes coupés,
--- filets éteints, jusqu'à ce qu'un autre geste refasse la mise en page. On
--- déduit donc la largeur à venir au lieu de la lire : on sait exactement de
--- combien on a poussé le cadre.
---
--- Aucune mesure illisible ne l'arrête à moitié : elle renonce, et la fenêtre
--- garde la taille qu'elle a. Rien de ce qui affiche la page ne dépend d'elle —
--- une page à la mauvaise largeur reste une page qu'on lit, une page qui ne
--- s'affiche pas n'est rien.
---@param page table|nil
---@return number|nil
local function fitPage(page)
    if not (frame and body and contentScroll and page) then return nil end

    local width     = measure(frame:GetWidth())
    local available = measure(W.ContentWidth(contentScroll))
    local scale     = measure(body:GetScale())
    local screen    = measure(UIParent:GetWidth())
    if not (width and available and scale and screen) then return nil end
    if width <= 0 or scale <= 0 or screen <= 0 then return nil end

    local wanted = PB:MinWidth(page)
    local target

    if not wanted then
        -- La page ne réclame rien : on rend au joueur ce qu'on lui avait pris.
        if not playerWidth then return available end
        target, playerWidth = playerWidth, nil
    else
        local missing = wanted - available
        if missing <= 0 and not playerWidth then return available end

        -- Relevée au premier passage seulement : les suivants se font sur une
        -- fenêtre que nous avons déjà élargie, et la mesurer alors reviendrait à
        -- prendre notre largeur pour la sienne.
        playerWidth = playerWidth or width

        -- Le manque est mesuré dans les unités du corps, qui porte l'échelle du
        -- contenu ; le cadre, lui, n'a pas d'échelle. La largeur du joueur est un
        -- plancher : une page large ne rétrécit jamais une fenêtre qu'on lui
        -- avait donnée plus grande.
        target = math.min(math.max(width + missing * scale, playerWidth), screen)
    end

    if math.abs(target - width) < 1 then return available end

    frame:SetWidth(target)
    keepOnScreen()
    contentScroll:UpdateContentWidth()

    return available + (target - width) / scale
end

--- Applique l'échelle courante et remesure ce qui en dépend.
local function applyScale()
    if not body then return end

    body:SetScale(currentScale() / 100)
    if scaleMenu then scaleMenu:Refresh() end

    -- L'échelle change la largeur disponible dans la page : une page qui exige
    -- deux colonnes peut réclamer plus de fenêtre, ou en rendre.
    fitPage(currentPage)

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

    -- ----- recherche -----
    -- En tête de la colonne, au-dessus de la liste qu'elle filtre : c'est là
    -- que les yeux vont chercher quoi ouvrir, c'est donc là qu'on cherche.
    -- Le retrait gauche loge les textures que le template de saisie du client
    -- dessine à gauche de sa zone.
    searchBox = W.SearchBox(body, {
        placeholder = L["Search settings"],
        onChanged   = function(text) Config:OnSearchChanged(text) end,
    })
    searchBox:SetPoint("TOPLEFT", sidebarPanel, "TOPLEFT",
        S.PANEL_PAD + S.LABEL_INDENT, -S.PANEL_PAD)
    searchBox:SetPoint("TOPRIGHT", sidebarPanel, "TOPRIGHT",
        -S.PANEL_PAD, -S.PANEL_PAD)

    -- ----- mode édition -----
    -- Sous la recherche et au-dessus de la liste : c'est un geste qui porte sur
    -- **toutes** les pages, il n'appartient donc à aucune. Rouge, parce qu'il
    -- ne se range pas tout seul — ce qu'il allume reste à l'écran tant qu'on
    -- n'a pas recliqué, fenêtre fermée comprise, et un bouton qui laisse
    -- quelque chose derrière lui doit se voir.
    editButton = W.DangerButton(body, L["Edit mode"], function()
        BUI:ToggleEditMode()
        Config:RefreshEditButton()
    end)
    editButton:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", 0, -S.PANEL_PAD)
    editButton:SetPoint("TOPRIGHT", searchBox, "BOTTOMRIGHT", 0, -S.PANEL_PAD)
    W.Tooltip(editButton, L["Edit mode"], L["Edit mode tip"])

    -- Colonne sans ascenseur : la liste des modules est courte, une barre y
    -- serait un rappel permanent d'un défilement qui n'a presque jamais lieu.
    -- La molette continue de fonctionner, elle, ce qui suffit si elle déborde.
    local sidebarScroll, sidebarContent = W.ScrollPane(body, true)
    sidebarScroll:SetPoint("TOPLEFT", editButton, "BOTTOMLEFT",
        -S.LABEL_INDENT, -S.PANEL_PAD)
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

    --- `byPlayer` : le coin a été tiré à la main. La fenêtre qu'on avait mise de
    --- côté n'a plus lieu d'être rendue — le joueur vient d'en choisir une autre,
    --- ici, et la lui reprendre en changeant de page serait défaire son geste.
    --- On ne la réélargit pas non plus dans la foulée : la page garde ses deux
    --- colonnes, plus serrées, plutôt que de reprendre la largeur qu'il refuse.
    frame._onResize = function(_, byPlayer)
        if byPlayer then playerWidth = nil end

        sidebarScroll:UpdateContentWidth()
        contentScroll:UpdateContentWidth()

        -- **La page suit la fenêtre.** Sa largeur est écrite, jamais héritée —
        -- elle est posée une fois quand on ouvre la page —, et rien ne la
        -- reposait ensuite : une fenêtre retaillée laissait la page se disposer
        -- pour l'ancienne. Les colonnes gardaient leur largeur, les paragraphes
        -- se coupaient à la mauvaise mesure, et le filet des en-têtes s'éteignait
        -- ou revenait selon un calcul fait pour une fenêtre qui n'existait plus.
        if currentPage then
            currentPage:SetWidth(W.ContentWidth(contentScroll))
        end
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
    currentPage = page

    -- **La page est montrée avant d'être ajustée**, et l'ordre est le tout de
    -- cette fonction : la largeur de la fenêtre est un confort, l'affichage de
    -- la page est la fonction. Ce qui suit ne doit jamais pouvoir empêcher ce
    -- qui précède — une page à la mauvaise largeur reste une page qu'on lit.
    pageTitle:SetTitle(mod.title)
    BUI.Sidebar:SetSelected(moduleName)
    page:Show()

    -- La fenêtre ensuite, la page se disposant d'après la largeur de la zone de
    -- contenu : c'est ici que cette largeur est décidée, et `fitPage` la rend —
    -- la relire ici donnerait celle d'avant son élargissement.
    page:SetWidth(fitPage(page) or W.ContentWidth(contentScroll))
    page:Refresh()

    -- La hauteur du contenu défilant est **écrite**, jamais déduite : déduite,
    -- elle viendrait des rectangles des enfants, et la maquette de barre d'infos
    -- en a de secrets — c'est par là que la plage de défilement s'empoisonnait.
    -- La hauteur de page, elle, est calculée par la mise en page : un nombre
    -- ordinaire, posé par nous.
    local height = measure(page:GetHeight())
    if height and height > 0 then contentHolder:SetHeight(height) end

    contentScroll:ResetScroll()
end

-- =========================================================================
--  Recherche
-- =========================================================================

--- Réagit à chaque frappe dans la zone de recherche.
---
--- En dessous du seuil, la colonne reprend sa liste : effacer sa saisie **est**
--- le geste qui referme la recherche, il n'y a pas de bouton pour ça.
---@param text string
function Config:OnSearchChanged(text)
    local query = strtrim(text or "")

    if #query < BUI.Search.MIN_CHARS then
        BUI.Sidebar:ClearResults()
        return
    end

    local groups, truncated = BUI.Search:Find(query)
    BUI.Sidebar:ShowResults(groups, truncated, function(moduleName, descriptor)
        -- Le clic referme la recherche : la colonne montre alors la liste, avec
        -- la page atteinte sélectionnée — l'état exact qu'aurait laissé une
        -- navigation à la main.
        if searchBox then searchBox:Clear() end
        Config:SelectOption(moduleName, descriptor)
    end)
end

--- Ouvre la page d'un module et amène une de ses lignes sous les yeux.
---
--- Le défilement et l'éclairage attendent **l'image suivante** : la page vient
--- d'être disposée, et les rectangles qu'on mesure ne sont justes qu'après le
--- passage de mise en page du client — lus tout de suite, ils décrivent la page
--- d'avant. C'est le même motif que la fenêtre de copie (`CopyWindow:Open`).
---@param moduleName string
---@param descriptor table
function Config:SelectOption(moduleName, descriptor)
    self:SelectModule(moduleName)

    local row = BUI.PageBuilder:RowFor(moduleName, descriptor)
    if not row then return end

    C_Timer.After(0, function()
        if not (currentPage and currentPage:IsShown() and row:IsShown()) then return end

        local pageTop = measure(currentPage:GetTop())
        local rowTop  = measure(row:GetTop())
        local range   = measure(contentScroll:GetVerticalScrollRange())

        -- Une mesure illisible n'empêche que le défilement : la ligne est
        -- éclairée quand même, et elle est peut-être déjà visible.
        if pageTop and rowTop and range and range > 0 then
            -- Deux lignes d'air au-dessus : une ligne collée au bord haut se
            -- cherche autant qu'une ligne hors de vue.
            local offset = pageTop - rowTop - T.SIZE.ROW_H * 2
            offset = math.max(0, math.min(range, offset))

            pcall(contentScroll.SetVerticalScroll, contentScroll, offset)
            if contentScroll.ScrollBar and contentScroll.ScrollBar.SetValue then
                pcall(contentScroll.ScrollBar.SetValue, contentScroll.ScrollBar, offset)
            end
        end

        W.FlashRow(row)
    end)
end

-- =========================================================================
--  Ouverture / fermeture
-- =========================================================================

--- Repose le libellé du bouton de mode édition sur l'état courant.
---
--- Appelé au clic **et** à l'ouverture : le mode édition survit à la fermeture
--- de la fenêtre, et c'est tout son intérêt — on ferme pour aller déplacer ce
--- qu'on vient d'allumer. Un bouton qui rouvrirait en disant « Mode édition »
--- ferait ressortir du mode à qui croirait y entrer.
function Config:RefreshEditButton()
    if not editButton then return end
    editButton:SetText(BUI:IsEditMode() and L["Leave edit mode"] or L["Edit mode"])
end

function Config:Show()
    if not frame then buildFrame() end

    -- Le rappel de connexion a fait son office : la fenêtre est ouverte, et par
    -- quelque chemin que ce soit — la commande, le bouton de minicarte, le
    -- compartiment d'addons, les options du jeu. C'est ce qui vaut à cette
    -- marque d'être posée ici et non dans chacun d'eux.
    BUI.DB:MarkSeen(BUI.DB.HINT_LOGIN)

    frame:Show()
    self:RefreshEditButton()
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
