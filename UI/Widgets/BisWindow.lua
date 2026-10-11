-- =========================================================================
--  Bshamel UI — UI/Widgets/BisWindow.lua
--  La fenêtre de la liste BIS : un emplacement par ligne, et à sa droite les
--  objets qu'on a choisis pour lui — BIS 1, BIS 2, BIS 3.
--
--  Deux vues dans une fenêtre, et non deux fenêtres : la liste, et la recherche
--  qui sert à la remplir. On passe de l'une à l'autre en cliquant une case, on
--  revient par un bouton. Les frames ne se détruisent pas (règle 7) : les deux
--  vues sont des pages bâties une fois, montrées ou cachées ensuite.
--
--  Le widget ne connaît pas la base : il lit et écrit par les `getPick` /
--  `setPick` que l'appelant lui donne. C'est `Modules/BisList.lua` qui sait que
--  ces choix appartiennent au personnage.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local W    = BUI.Widgets
local L    = ns.L

---@class BUI.BisWindowOpts
---@field slots table[]       { key, label } — les lignes, dans l'ordre
---@field slotLocs fun(slotKey: string): table|nil
---@field ranks integer       nombre de colonnes de choix
---@field stats table[]
---@field armorTypes table[]
---@field getPick fun(slotKey: string, rank: integer): integer|nil
---@field setPick fun(slotKey: string, rank: integer, itemID: integer|nil)
---@field search fun(filters: table, limit: integer, out: table): table, integer
---@field progress fun(): string, number, number

--- Infobulle d'un objet, par l'identifiant (voir `BisSearch.lua`, même raison :
--- deux chemins parce que le client a les deux et qu'aucun n'est garanti).
---@param anchor table
---@param itemID integer
local function showItemTooltip(anchor, itemID)
    GameTooltip:SetOwner(anchor, "ANCHOR_RIGHT")

    if GameTooltip.SetItemByID then
        GameTooltip:SetItemByID(itemID)
    elseif GameTooltip.SetHyperlink then
        GameTooltip:SetHyperlink("item:" .. itemID)
    end

    GameTooltip:Show()
end

--- Une case de choix : l'icône de l'objet et son nom, ou l'invite quand la
--- case est vide.
---
--- Trois gestes, et c'est le maximum qu'une case puisse porter sans qu'on ait à
--- l'écrire quelque part : clic gauche pour choisir ou remplacer, clic droit
--- pour vider, Maj + clic pour coller le lien dans le chat.
---@param parent table
---@return table cell
local function pickCell(parent)
    local S    = T.SIZE
    local cell = CreateFrame("Button", nil, parent)
    cell:SetSize(S.BIS_CELL_W, S.BIS_CELL_H)
    cell:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local icon = cell:CreateTexture(nil, "ARTWORK")
    icon:SetSize(S.BIS_ICON, S.BIS_ICON)
    icon:SetPoint("LEFT", cell, "LEFT", 0, 0)

    local name = cell:CreateFontString(nil, "ARTWORK", T.FONT.LABEL_SMALL)
    name:SetPoint("LEFT", icon, "RIGHT", S.BIS_CELL_GAP, 0)
    name:SetPoint("RIGHT", cell, "RIGHT", 0, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)

    cell:SetHighlightTexture(T.TEXTURE.ICON_HIGHLIGHT)

    cell.icon = icon
    cell.name = name

    -- L'infobulle n'est pas posée par `W.Tooltip` : son contenu change avec la
    -- case. Pleine, c'est l'objet qu'on veut lire ; vide, c'est ce qu'un clic
    -- y ferait.
    cell:SetScript("OnEnter", function(self)
        if self.itemID then
            showItemTooltip(self, self.itemID)
            return
        end

        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip_SetTitle(GameTooltip, L["Empty pick"])
        GameTooltip_AddNormalLine(GameTooltip, L["Empty pick tip"])
        GameTooltip:Show()
    end)
    cell:SetScript("OnLeave", function() GameTooltip:Hide() end)

    --- Montre un objet, ou l'invite si `itemID` est nil.
    ---@param itemID integer|nil
    function cell:SetItem(itemID)
        self.itemID = itemID

        if not itemID then
            icon:SetTexture(T.TEXTURE.QUESTION_MARK)
            icon:SetDesaturated(true)
            name:SetText(L["Choose an item"])
            name:SetTextColor(T.COLOR.DISABLED:GetRGB())
            return
        end

        icon:SetDesaturated(false)

        local texture = C_Item and C_Item.GetItemIconByID
                        and C_Item.GetItemIconByID(itemID)
        icon:SetTexture(texture or T.TEXTURE.QUESTION_MARK)

        -- Le nom passe par l'index et non par le client : l'index l'a retenu,
        -- et le client ne le rend qu'une fois l'objet en cache. Un nom vide se
        -- lirait comme un choix perdu.
        local record = ns.BisIndex and ns.BisIndex:Record(itemID)
        if record then
            name:SetText(record.name)
            local color = T.ItemQualityColor(record.quality)
            if color then name:SetTextColor(color:GetRGB()) end
        else
            name:SetText(L["Unknown item"]:format(itemID))
            name:SetTextColor(T.COLOR.DISABLED:GetRGB())
        end
    end

    return cell
end

--- Fenêtre de la liste BIS.
---@param globalName string
---@param opts BUI.BisWindowOpts
---@return table window
function W.BisWindow(globalName, opts)
    local S = T.SIZE

    local window = W.Window(globalName, L["BIS list"], S.BIS_WINDOW_W, S.BIS_WINDOW_H)

    -- -------------------------------------------------------------------
    --  La liste
    -- -------------------------------------------------------------------

    local listPage = W.Container(window)
    --- Les deux vues occupent la même surface : tout l'intérieur de la fenêtre,
    --- une fois son habillage retiré.
    ---@param page table
    local function fillWindow(page)
        page:SetPoint("TOPLEFT", window, "TOPLEFT",
            S.CHROME_SIDE + S.PANEL_PAD, -S.CHROME_TOP)
        page:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT",
            -S.CHROME_SIDE - S.PANEL_PAD, S.CHROME_BOTTOM + S.PANEL_PAD)
    end

    fillWindow(listPage)

    --- Abscisse de la colonne `rank`, mesurée depuis le bord de la page.
    ---@param rank integer
    ---@return number
    local function columnX(rank)
        return S.BIS_SLOT_LABEL_W + (rank - 1) * (S.BIS_CELL_W + S.BIS_CELL_GAP)
    end

    -- En-tête des colonnes. Il n'y a rien à cliquer dessus : il dit seulement
    -- quelle case est le premier choix, ce qu'aucune case ne peut dire d'elle.
    for rank = 1, opts.ranks do
        local header = W.SectionHeader(listPage, L["BIS rank"]:format(rank))
        -- Reculé du retrait qu'un en-tête s'applique à lui-même : son texte
        -- doit tomber sur l'icône de la colonne, pas un cran à sa droite.
        header:SetPoint("TOPLEFT", listPage, "TOPLEFT",
            columnX(rank) - S.LABEL_INDENT, 0)
        header:SetWidth(S.BIS_CELL_W)
    end

    local cells = {}
    local y = S.SECTION_H + S.SECTION_GAP

    for i = 1, #opts.slots do
        local slot = opts.slots[i]

        cells[slot.key] = {}
        for rank = 1, opts.ranks do
            local cell = pickCell(listPage)
            cell:SetPoint("TOPLEFT", listPage, "TOPLEFT", columnX(rank), -y)
            cell.slotKey = slot.key
            cell.rank    = rank
            cells[slot.key][rank] = cell
        end

        -- L'intitulé se cale sur la **hauteur de la première case** plutôt que
        -- sur une arithmétique de milieu de ligne : un texte posé entre deux
        -- bords s'y centre tout seul, et le jour où la case change de hauteur
        -- il n'y a rien à corriger.
        local label = listPage:CreateFontString(nil, "ARTWORK", T.FONT.LABEL)
        label:SetPoint("LEFT", listPage, "LEFT", 0, 0)
        label:SetPoint("TOP", cells[slot.key][1], "TOP")
        label:SetPoint("BOTTOM", cells[slot.key][1], "BOTTOM")
        label:SetWidth(S.BIS_SLOT_LABEL_W)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)
        label:SetText(slot.label)

        y = y + S.BIS_CELL_H + S.BIS_CELL_GAP
    end

    -- La ligne d'avancement, au pied : c'est le seul endroit où l'indexation se
    -- montre. Elle ne demande rien au joueur, elle dit pourquoi une recherche
    -- faite tout de suite peut ne pas tout trouver.
    local progress = listPage:CreateFontString(nil, "ARTWORK", T.FONT.HINT)
    progress:SetPoint("BOTTOMLEFT", listPage, "BOTTOMLEFT", 0, 0)
    progress:SetPoint("RIGHT", listPage, "RIGHT", 0, 0)
    progress:SetJustifyH("LEFT")

    -- -------------------------------------------------------------------
    --  La recherche
    -- -------------------------------------------------------------------

    local searchPage, pane
    local picking = {}   -- l'emplacement et le rang qu'on est en train de remplir

    --- Bâtit la page de recherche au premier besoin.
    ---@return table
    local function searchPane()
        if pane then return pane end

        searchPage = W.Container(window)
        fillWindow(searchPage)

        pane = W.BisSearchPane(searchPage, {
            slots      = opts.slots,
            slotLocs   = opts.slotLocs,
            stats      = opts.stats,
            armorTypes = opts.armorTypes,
            search     = opts.search,
            progress   = opts.progress,

            onPick = function(itemID)
                if picking.slotKey then
                    opts.setPick(picking.slotKey, picking.rank, itemID)
                end
                window:ShowList()
            end,

            onBack = function() window:ShowList() end,
        })
        pane:SetAllPoints(searchPage)

        return pane
    end

    -- -------------------------------------------------------------------
    --  Les deux vues
    -- -------------------------------------------------------------------

    --- Relit tous les choix et l'avancement de l'indexation.
    --- Réécrit la seule ligne d'avancement.
    ---
    --- Séparée de `Refresh` parce qu'elle est appelée bien plus souvent : deux
    --- fois par seconde pendant l'indexation, là où relire les cinquante et une
    --- cases à cette cadence ne servirait à rien.
    function window:RefreshProgress()
        local phase, done, total = opts.progress()

        if phase == "ready" then
            progress:SetText(L["Index ready"]:format(total))
        elseif phase == "sweep" then
            progress:SetText(L["Index sweeping"]:format(done, total))
        elseif phase == "load" then
            progress:SetText(L["Index loading"]:format(done, total))
        else
            progress:SetText(L["Index idle"])
        end
    end

    function window:Refresh()
        for i = 1, #opts.slots do
            local slot = opts.slots[i]
            for rank = 1, opts.ranks do
                cells[slot.key][rank]:SetItem(opts.getPick(slot.key, rank))
            end
        end

        self:RefreshProgress()

        if pane and searchPage:IsShown() then pane:Refresh() end
    end

    function window:ShowList()
        if searchPage then searchPage:Hide() end
        listPage:Show()
        self:Refresh()
        self:Show()
    end

    --- Ouvre la recherche pour une case. Les filtres repartent de zéro, sauf
    --- l'emplacement, qui est justement la question qu'on vient de poser en
    --- cliquant cette ligne-là.
    ---@param slotKey string
    ---@param rank integer
    function window:ShowSearch(slotKey, rank)
        picking.slotKey = slotKey
        picking.rank    = rank

        local search = searchPane()
        listPage:Hide()
        searchPage:Show()

        search:Reset()
        search:SetSlot(slotKey)
        search:Resize()
        search:Refresh()

        self:Show()
    end

    function window:Toggle()
        if self:IsShown() then
            self:Hide()
        else
            self:ShowList()
        end
    end

    -- Les gestes des cases ont besoin de la fenêtre : ils se posent une fois
    -- celle-ci complète.
    for i = 1, #opts.slots do
        local slot = opts.slots[i]
        for rank = 1, opts.ranks do
            local cell = cells[slot.key][rank]

            cell:SetScript("OnClick", function(self, button)
                if button == "RightButton" then
                    opts.setPick(self.slotKey, self.rank, nil)
                    window:Refresh()
                    return
                end

                -- Maj + clic gauche sur une case remplie : le lien part dans la
                -- zone de saisie du chat, s'il y en a une d'ouverte. C'est le
                -- geste du jeu entier pour partager un objet, et le refuser ici
                -- obligerait à ressortir l'objet d'ailleurs.
                if self.itemID and IsShiftKeyDown() and ChatEdit_InsertLink then
                    local info = (C_Item and C_Item.GetItemInfo) or GetItemInfo
                    local link = info and select(2, info(self.itemID))
                    if link and ChatEdit_InsertLink(link) then return end
                end

                window:ShowSearch(self.slotKey, self.rank)
            end)
        end
    end

    -- Le redimensionnement de la fenêtre n'est pas interdit — elle vient de
    -- `W.Window`, qui le donne —, mais la liste ne s'étire pas : elle est faite
    -- de colonnes à largeur fixe. Seules les zones défilantes de la recherche
    -- ont à se recaler.
    window._onResize = function()
        if pane then pane:Resize() end
    end

    window:Hide()
    return window
end
