-- =========================================================================
--  Bshamel UI — UI/Widgets/BisSearch.lua
--  La recherche d'objets de la liste BIS : une colonne de filtres à gauche,
--  les résultats à droite.
--
--  Le widget ne connaît ni la base de données ni l'index : il reçoit des
--  descripteurs et une fonction qui cherche (`opts.search`), comme
--  `W.GroupFilterPanel` reçoit ses `get`/`set`. C'est `Modules/BisList.lua` qui
--  décide quoi chercher ; ici on décide seulement où sont les cases.
--
--  ## Les filtres sont des vœux, pas des réglages
--
--  Rien de ce qui se coche ici ne va en base : une recherche est un geste, pas
--  un état. La table `filters` vit dans le panneau et meurt avec la session —
--  elle ne passe donc pas par `Get`/`Set`, et la règle des défauts éteints ne
--  la concerne pas (il n'y a pas de défaut, il y a une case vide).
--
--  ## Pourquoi les résultats sont plafonnés
--
--  Les frames ne se détruisent pas (règle 7) : la liste bâtit ses lignes une
--  fois (`T.SIZE.BIS_RESULT_MAX`) et les **relie** ensuite à de nouveaux
--  objets. Le plafond n'est donc pas une limite technique qu'on subit, c'est la
--  réponse à « que fait-on de huit mille résultats » : on les trie par niveau
--  d'objet, on en montre cent, et on dit combien il y en avait. Qui cherche
--  mieux affine son filtre ; personne ne fait défiler huit mille lignes.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local U    = BUI.Util
local W    = BUI.Widgets
local L    = ns.L

---@class BUI.BisSearchOpts
---@field slots table[]       { key, label } — les emplacements, pour le menu
---@field slotLocs fun(slotKey: string): table|nil  les emplacements d'une ligne
---@field stats table[]       { index, label } — les stats filtrables
---@field armorTypes table[]  { value, label } — les types d'armure
---@field search fun(filters: table, limit: integer, out: table): table, integer
---@field onPick fun(itemID: integer)
---@field onBack fun()
---@field progress fun(): string, number, number

--- Infobulle d'un objet, par l'identifiant. Deux chemins, parce que le client
--- a les deux et qu'aucun n'est garanti : `SetItemByID` d'abord, le lien
--- ensuite — un lien bâti à la main reste un lien valide pour l'infobulle.
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

--- Une ligne de résultat : icône, nom à la couleur de sa qualité, niveau
--- d'objet. Reliable — c'est ce qui permet au plafond de lignes de servir
--- toutes les recherches.
---@param parent table
---@return table row
local function resultRow(parent)
    local S = T.SIZE
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(S.BIS_RESULT_H)
    row:RegisterForClicks("LeftButtonUp")

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(S.BIS_ICON, S.BIS_ICON)
    icon:SetPoint("LEFT", row, "LEFT", 0, 0)

    local name = row:CreateFontString(nil, "ARTWORK", T.FONT.LABEL)
    name:SetPoint("LEFT", icon, "RIGHT", S.BIS_CELL_GAP, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)

    -- Le niveau d'objet est ancré à droite, et le nom s'arrête où il commence :
    -- c'est la seule colonne qu'on compare d'une ligne à l'autre, elle doit
    -- s'aligner même quand les noms n'ont pas la même longueur.
    local level = row:CreateFontString(nil, "ARTWORK", T.FONT.LABEL_SMALL)
    level:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    level:SetJustifyH("RIGHT")
    name:SetPoint("RIGHT", level, "LEFT", -S.BIS_CELL_GAP, 0)

    row:SetHighlightTexture(T.TEXTURE.ICON_HIGHLIGHT)

    row.icon  = icon
    row.name  = name
    row.level = level

    row:SetScript("OnEnter", function(self)
        if self.itemID then showItemTooltip(self, self.itemID) end
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)

    return row
end

--- Relie une ligne à un objet de l'index.
---@param row table
---@param record table
local function bindResult(row, record)
    row.itemID = record.id

    local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(record.id)
    row.icon:SetTexture(icon or T.TEXTURE.QUESTION_MARK)

    row.name:SetText(record.name)
    local color = T.ItemQualityColor(record.quality)
    if color then row.name:SetTextColor(color:GetRGB()) end

    -- Niveau d'objet, puis niveau requis : le premier dit la puissance, le
    -- second dit quand on y a droit, et les deux décident ensemble.
    row.level:SetText(L["Item row levels"]:format(record.itemLevel, record.minLevel))
    row:Show()
end

--- Panneau de recherche.
---@param parent table
---@param opts BUI.BisSearchOpts
---@return table pane
function W.BisSearchPane(parent, opts)
    local S    = T.SIZE
    local pane = W.Container(parent)

    --- Les vœux du moment, dans le vocabulaire que la recherche attend : cette
    --- table **est** la requête, et elle se remplit sur place. `checked` est à
    --- part — c'est l'ensemble des cases cochées, dont `stats` n'est que la
    --- liste, reconstruite au moment de chercher.
    local filters = { checked = {}, stats = {} }
    pane.filters = filters

    --- Les résultats, et combien il y en avait avant le plafond.
    local results = {}
    local total   = 0

    local rows = {}
    local countText

    -- -------------------------------------------------------------------
    --  Chercher
    -- -------------------------------------------------------------------

    --- La liste des stats voulues, refaite dans la **même** table à chaque
    --- recherche : taper un nom en relance une par frappe groupée, et aucune
    --- d'elles n'a à construire de table (règle 7).
    local wanted = filters.stats

    local function runSearch()
        wipe(wanted)
        for index in pairs(filters.checked) do wanted[#wanted + 1] = index end

        results, total = opts.search(filters, S.BIS_RESULT_MAX, results)

        for i = 1, #rows do
            local record = results[i]
            if record then
                bindResult(rows[i], record)
            else
                rows[i].itemID = nil
                rows[i]:Hide()
            end
        end

        local phase = opts.progress()
        local shown = #results
        local text

        if total == 0 then
            text = (phase == "ready") and L["No item matches"]
                                       or L["Indexing in progress"]
        elseif shown < total then
            text = L["Results capped"]:format(shown, total)
        else
            text = L["Results count"]:format(total)
        end

        -- Tant que l'index se remplit, le décompte est vrai **de ce qu'on a** et
        -- non du jeu : le dire ici est la seule façon qu'une liste courte ne se
        -- lise pas comme une liste complète.
        if phase ~= "ready" and total > 0 then
            text = text .. L["Still indexing suffix"]
        end

        countText:SetText(text)
    end

    -- Une frappe au clavier ne lance pas une recherche : huit mille objets se
    -- parcourent vite, mais pas soixante fois par seconde (règle 7).
    local searchLater = U.Debounce(T.TIMING.BIS_TICK, runSearch)

    function pane:Refresh()
        runSearch()
    end

    -- -------------------------------------------------------------------
    --  La colonne des filtres
    -- -------------------------------------------------------------------

    local back = W.Button(pane, L["Back to list"], function() opts.onBack() end,
        S.BIS_FILTER_W)
    back:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, 0)

    local filterScroll, filterContent = W.ScrollPane(pane)
    filterScroll:SetPoint("TOPLEFT", back, "BOTTOMLEFT", 0, -S.TOOL_PAD)
    filterScroll:SetPoint("BOTTOMLEFT", pane, "BOTTOMLEFT", 0, 0)
    filterScroll:SetWidth(S.BIS_FILTER_W)

    --- Empile une ligne dans la colonne des filtres.
    local filterY = 0
    local function stack(row, height)
        row:SetPoint("TOPLEFT", filterContent, "TOPLEFT", 0, -filterY)
        row:SetWidth(S.BIS_FILTER_W - S.SCROLLBAR_W)
        if row.Arrange then row:Arrange() end
        filterY = filterY + (height or S.ROW_H)
    end

    --- Menu des emplacements. « Tous » en tête : on cherche parfois sans savoir
    --- où ça se porte — une arme à une main ou un bijou se compare rarement à
    --- une ligne précise de la liste.
    local slotValues = { { value = false, label = L["Any slot"] } }
    for i = 1, #opts.slots do
        slotValues[#slotValues + 1] = {
            value = opts.slots[i].key,
            label = opts.slots[i].label,
        }
    end

    local slotRow = W.Dropdown(filterContent, {
        text    = L["Slot"],
        tooltip = L["Slot filter tip"],
        values  = slotValues,
        get     = function() return filters.slotKey or false end,
        set     = function(value)
            pane:SetSlot(value or nil)
            runSearch()
        end,
    })
    stack(slotRow)

    local armorRow = W.Dropdown(filterContent, {
        text    = L["Armor type"],
        tooltip = L["Armor type tip"],
        values  = opts.armorTypes,
        get     = function() return filters.armorType or false end,
        set     = function(value)
            filters.armorType = value or nil
            runSearch()
        end,
    })
    stack(armorRow)

    local levelRow = W.BoundRow(filterContent, {
        text    = L["Required level at most"],
        tooltip = L["Required level at most tip"],
        hint    = L["Max"],
        get     = function() return filters.maxLevel end,
        set     = function(value)
            filters.maxLevel = value
            runSearch()
        end,
    })
    stack(levelRow)

    local itemLevelRow = W.RangeRow(filterContent, {
        text    = L["Item level"],
        tooltip = L["Item level filter tip"],
        getMin  = function() return filters.minItemLevel end,
        setMin  = function(value)
            filters.minItemLevel = value
            runSearch()
        end,
        getMax  = function() return filters.maxItemLevel end,
        setMax  = function(value)
            filters.maxItemLevel = value
            runSearch()
        end,
    })
    stack(itemLevelRow)

    local equipRow = W.Toggle(filterContent, {
        text    = L["Equippable only"],
        tooltip = L["Equippable only tip"],
        get     = function() return filters.equippable == true end,
        set     = function(value)
            filters.equippable = value or nil
            runSearch()
        end,
    })
    stack(equipRow)

    local nameRow = W.Row(filterContent, L["Name contains"])
    local nameBox = W.SearchBox(nameRow, {
        placeholder = L["Name contains hint"],
        onChanged   = function(text)
            text = strtrim(text or "")
            filters.text = (text ~= "") and strlower(text) or nil
            searchLater()
        end,
    })
    -- La zone de recherche est faite pour la colonne de navigation, plus haute
    -- qu'une ligne d'option : ramenée à la hauteur d'une borne, elle ne mord
    -- plus sur ses voisines.
    nameBox:SetWidth(S.SLIDER_VALUE_W * 2 + S.SLIDER_VALUE_GAP)
    nameBox:SetHeight(S.SLIDER_VALUE_H)
    W.PlaceControl(nameRow, nameBox)
    stack(nameRow)

    stack(W.SectionHeader(filterContent, L["Wanted stats"]), S.SECTION_H + S.SECTION_GAP)

    local statRows = {}
    for i = 1, #opts.stats do
        local stat = opts.stats[i]
        local row = W.Toggle(filterContent, {
            text   = stat.label,
            indent = true,
            get    = function() return filters.checked[stat.index] == true end,
            set    = function(value)
                filters.checked[stat.index] = value or nil
                runSearch()
            end,
        })
        stack(row)
        statRows[#statRows + 1] = row
    end

    filterContent:SetHeight(filterY)

    -- -------------------------------------------------------------------
    --  La colonne des résultats
    -- -------------------------------------------------------------------

    countText = pane:CreateFontString(nil, "ARTWORK", T.FONT.LABEL_SMALL)
    countText:SetPoint("TOPLEFT", filterScroll, "TOPRIGHT", S.PADDING, 0)
    countText:SetPoint("RIGHT", pane, "RIGHT", 0, 0)
    countText:SetJustifyH("LEFT")

    local resultScroll, resultContent = W.ScrollPane(pane)
    resultScroll:SetPoint("TOPLEFT", countText, "BOTTOMLEFT", 0, -S.TOOL_PAD)
    resultScroll:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -S.SCROLLBAR_W, 0)

    for i = 1, S.BIS_RESULT_MAX do
        local row = resultRow(resultContent)
        row:SetPoint("TOPLEFT", resultContent, "TOPLEFT", 0, -(i - 1) * S.BIS_RESULT_H)
        row:SetPoint("TOPRIGHT", resultContent, "TOPRIGHT", 0, -(i - 1) * S.BIS_RESULT_H)
        row:SetScript("OnClick", function(self)
            if self.itemID then opts.onPick(self.itemID) end
        end)
        row:Hide()
        rows[i] = row
    end
    resultContent:SetHeight(S.BIS_RESULT_MAX * S.BIS_RESULT_H)

    -- -------------------------------------------------------------------
    --  Ce que la fenêtre commande
    -- -------------------------------------------------------------------

    --- Restreint la recherche à un emplacement, ou la rouvre à tous.
    ---@param slotKey string|nil
    function pane:SetSlot(slotKey)
        filters.slotKey = slotKey
        filters.locs    = slotKey and opts.slotLocs(slotKey) or nil
        slotRow:Refresh()
    end

    --- Remet tous les vœux à vide. Appelée à chaque ouverture : une recherche
    --- qui garderait les filtres de la fois d'avant répondrait à une question
    --- qu'on ne se souvient plus d'avoir posée.
    function pane:Reset()
        wipe(filters.checked)
        filters.maxLevel     = nil
        filters.minItemLevel = nil
        filters.maxItemLevel = nil
        filters.armorType    = nil
        filters.equippable   = nil
        filters.text         = nil

        nameBox:Clear()
        armorRow:Refresh()
        levelRow:Refresh()
        itemLevelRow:Refresh()
        equipRow:Refresh()
        for i = 1, #statRows do statRows[i]:Refresh() end
    end

    --- Recale les largeurs après un redimensionnement de la fenêtre.
    function pane:Resize()
        filterScroll:UpdateContentWidth()
        resultScroll:UpdateContentWidth()
    end

    return pane
end
