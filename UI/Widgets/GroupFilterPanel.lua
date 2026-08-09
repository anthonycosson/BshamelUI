-- =========================================================================
--  Bshamel UI — UI/Widgets/GroupFilterPanel.lua
--  Panneau de filtres posé contre le bord droit de la recherche de groupe.
--
--  Le widget ne connaît ni la base de données ni l'API de la recherche de
--  groupe : il reçoit des descripteurs (`get`/`set` fournis par l'appelant,
--  comme `W.MinimapButton`) et se contente de les dessiner. C'est le module
--  qui décide quoi filtrer ; ici on décide seulement où sont les cases.
--
--  ## Pages par contexte
--
--  La recherche a trois visages — donjons, raids, arènes — et chacun demande
--  ses propres lignes. Les frames ne se détruisent pas (règle 7) : chaque
--  visage est donc une **page**, bâtie une fois à la première demande et
--  simplement montrée ou cachée ensuite (même principe que
--  `PageBuilder:GetPage`).
--
--  La seule partie mouvante est la liste des instances, remplie d'après les
--  résultats de recherche du moment : elle réserve ses lignes d'avance
--  (`T.SIZE.GF_LIST_MAX`) et les **relie** à de nouvelles entrées au lieu d'en
--  construire. Elle vit dans sa propre colonne, à droite des réglages, avec
--  son en-tête (`text` du descripteur) : empilée sous eux, elle faisait
--  descendre le panneau sous la fenêtre du client. Une par page, au plus.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local W    = BUI.Widgets
local L    = ns.L

---@class BUI.GroupFilterRowDesc
---@field type string            "header" | "toggle" | "range" | "list"
---@field text? string
---@field tooltip? string
---@field indent? boolean
---@field get? fun(): boolean
---@field set? fun(value: boolean)
---@field getMin? fun(): number|nil
---@field setMin? fun(value: number|nil)
---@field getMax? fun(): number|nil
---@field setMax? fun(value: number|nil)

---@class BUI.GroupFilterFooterToggle
---@field text string
---@field tooltip? string
---@field get fun(): boolean
---@field set fun(value: boolean)

---@class BUI.GroupFilterPanelOpts
---@field parent table        la frame du client dont on suit la visibilité
---@field anchor table        celle contre laquelle on se pose (son bord droit)
---@field title string
---@field resetLabel string
---@field resetTooltip? string
---@field onReset fun()       remet les filtres du contexte courant à neutre
---@field searchLabel string
---@field searchTooltip? string
---@field onSearch fun()      relance la recherche du client
---@field footerToggle BUI.GroupFilterFooterToggle  la ligne commune à tous les contextes, posée au pied

--- Case de saisie d'une borne : un nombre entier, ou rien du tout.
---
--- **Vide veut dire « pas de borne »**, et c'est ce qui la distingue d'une
--- glissière : une glissière a toujours une valeur, donc filtre toujours, alors
--- que la plupart de ces bornes doivent ne rien faire tant qu'on n'a rien
--- demandé. La valeur ne part que lorsqu'on quitte la case — écrire à chaque
--- frappe filtrerait sur « 1 » pendant qu'on tape « 12 ».
---@param row table
---@param hint string  « Min » ou « Max », posé en filigrane dans la case vide
---@param getValue fun(): number|nil
---@param setValue fun(value: number|nil)
---@return table
local function boundBox(row, hint, getValue, setValue)
    local box = CreateFrame("EditBox", nil, row, T.Template("EDITBOX"))
    box:SetSize(T.SIZE.SLIDER_VALUE_W, T.SIZE.SLIDER_VALUE_H)
    box:SetAutoFocus(false)
    box:SetJustifyH("CENTER")
    box:SetNumeric(true)

    -- Le corps du nombre de la glissière, pour la même raison qu'elle : le
    -- template du client pose la police du chat, qui détonne sur un panneau.
    local font = _G[T.FONT.LABEL_SMALL]
    if font then box:SetFontObject(font) end

    -- Le filigrane qui dit ce que la case attend. Une case vide sans lui se
    -- lit comme une case cassée : rien n'annonce qu'on y écrit un minimum ou
    -- un maximum. Gris comme un contrôle éteint — c'est une invite, pas une
    -- valeur — et caché dès qu'on écrit ou qu'on entre dans la case.
    local ghost = box:CreateFontString(nil, "ARTWORK", T.FONT.LABEL_SMALL)
    ghost:SetPoint("CENTER")
    ghost:SetText(hint)
    ghost:SetTextColor(T.COLOR.DISABLED:GetRGB())

    local function display()
        local value = getValue()
        box:SetText(value and tostring(value) or "")
        box:SetCursorPosition(0)
        ghost:SetShown(value == nil)
    end

    box:HookScript("OnEditFocusGained", function() ghost:Hide() end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEditFocusLost", function(self)
        local text = self:GetText()
        setValue(text ~= "" and tonumber(text) or nil)
        display()
    end)

    box.Refresh = display
    return box
end

--- Ligne « libellé + deux bornes » : au moins tant, au plus tant.
---@param parent table
---@param desc BUI.GroupFilterRowDesc
---@return table row
local function rangeRow(parent, desc)
    local row = W.Row(parent, desc.text, desc.indent)

    -- Les deux cases vivent dans un conteneur : c'est lui que la ligne place à
    -- l'abscisse des contrôles, comme elle le ferait d'une glissière.
    local holder = W.Container(row)
    holder:SetSize(
        T.SIZE.SLIDER_VALUE_W * 2 + T.SIZE.SLIDER_VALUE_GAP,
        T.SIZE.SLIDER_VALUE_H)

    local minBox = boundBox(row, L["Min"], desc.getMin, desc.setMin)
    minBox:SetPoint("LEFT", holder, "LEFT")

    local maxBox = boundBox(row, L["Max"], desc.getMax, desc.setMax)
    maxBox:SetPoint("RIGHT", holder, "RIGHT")

    W.PlaceControl(row, holder)
    row:EnableMouse(true)
    W.Tooltip(row, desc.text, desc.tooltip)

    function row:Refresh()
        minBox:Refresh()
        maxBox:Refresh()
    end

    row:Refresh()
    return row
end

--- Ligne à cocher **reliable** : ses `get`/`set` et son libellé se remplacent
--- sans reconstruire la frame. C'est ce qui permet à la liste des instances de
--- changer de contenu à chaque recherche avec un jeu de lignes fixe.
---@param parent table
---@return table row
local function listRow(parent)
    local binding = {}

    -- Sans retrait : ces lignes ne sont pas des sous-options de l'en-tête,
    -- elles sont les réglages de leur section, au même bord que tous les
    -- autres — un décalage seul se lit comme un défaut d'alignement.
    local row = W.Toggle(parent, {
        text = "",
        get  = function() return binding.get and binding.get() or false end,
        set  = function(value) if binding.set then binding.set(value) end end,
    })

    --- Relie la ligne à une entrée : libellé, infobulle, lecture, écriture.
    ---@param entry { text: string, tooltip?: string, get: fun(): boolean, set: fun(value: boolean) }
    function row:Bind(entry)
        binding.get = entry.get
        binding.set = entry.set
        row.label:SetText(entry.text or "")
        -- Le libellé peut être tronqué par la colonne : l'infobulle porte le
        -- nom entier, c'est elle qui le rend lisible.
        W.Tooltip(row, entry.text, entry.tooltip)
        row:Refresh()
    end

    return row
end

--- Panneau de filtres, ancré au bord droit d'une fenêtre du client.
---@param opts BUI.GroupFilterPanelOpts
---@return table panel
function W.GroupFilterPanel(opts)
    local S = T.SIZE

    local panel = CreateFrame("Frame", nil, opts.parent)
    panel:SetWidth(S.GF_PANEL_W)

    -- Ancré **par son milieu**, pas par son haut : sa hauteur change avec la
    -- page (voir `fit`), et un panneau accroché par le haut grandit vers le
    -- bas seulement — plus il a de lignes, plus il pend sous la fenêtre du
    -- client. Accroché par le milieu, il grandit des deux côtés et reste en
    -- face d'elle.
    panel:SetPoint("LEFT", opts.anchor, "RIGHT", S.GF_PANEL_OFFSET_X, 0)
    W.PanelChrome(panel)

    local title = W.SectionHeader(panel, opts.title)
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", S.TOOL_PAD, -S.TOOL_PAD)
    title:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -S.TOOL_PAD, -S.TOOL_PAD)

    local rowWidth = S.GF_PANEL_W - S.TOOL_PAD * 2

    -- Les deux gestes du pied de panneau. La réinitialisation reste sous la
    -- colonne des réglages ; la recherche tient le coin bas-droit **du
    -- panneau** — ancrée à son bord, elle le suit quand la colonne des
    -- instances l'élargit. C'est le geste qui conclut, il ferme la lecture.
    local buttonWidth = (rowWidth - S.TOOL_PAD) / 2

    local reset = W.Button(panel, opts.resetLabel, function()
        opts.onReset()
        panel:RefreshCurrent()
    end, buttonWidth)
    reset:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", S.TOOL_PAD, S.TOOL_PAD)
    W.Tooltip(reset, opts.resetLabel, opts.resetTooltip)

    local search = W.Button(panel, opts.searchLabel, opts.onSearch, buttonWidth)
    search:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -S.TOOL_PAD, S.TOOL_PAD)
    W.Tooltip(search, opts.searchLabel, opts.searchTooltip)

    -- La ligne commune à tous les contextes, juste au-dessus des boutons :
    -- elle ne dépend pas de l'onglet, elle n'a donc rien à faire dans une page.
    local footer = W.Toggle(panel, opts.footerToggle)
    W.Tooltip(footer, opts.footerToggle.text, opts.footerToggle.tooltip)
    footer:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT",
        S.TOOL_PAD, S.TOOL_PAD * 2 + (S.ROW_H - 2))

    -- Pas d'`Arrange` ici, et c'est voulu : l'alignement standard réserve la
    -- place d'une glissière et de sa case de saisie, ce qui ne laissait au
    -- libellé qu'une centaine de pixels — tronqué, donc illisible. Cette ligne
    -- est seule sous le panneau, elle n'a aucune colonne avec qui s'aligner :
    -- le libellé part du bord même de la ligne, à sa largeur naturelle — sans
    -- largeur posée, un texte se mesure lui-même —, et la case se colle à sa
    -- fin, comme sur n'importe quelle ligne.
    footer.label:ClearAllPoints()
    footer.label:SetPoint("LEFT", footer, "LEFT", 0, 0)
    -- Largeur nulle = « mesure-toi » : la construction de la ligne lui avait
    -- posé une largeur fixe, et un texte à largeur fixe garde sa boîte — la
    -- case se serait collée au bout de la boîte, pas au bout du texte.
    footer.label:SetWidth(0)
    footer.control:ClearAllPoints()
    footer.control:SetPoint("LEFT", footer.label, "RIGHT", S.LABEL_INDENT, 0)

    --- La ligne du pied suit la **largeur du panneau** : c'est elle qui porte
    --- l'infobulle, sa surface de survol doit couvrir la traverse.
    ---@param width number
    local function fitFooter(width)
        footer:SetWidth(width - S.TOOL_PAD * 2)
    end
    fitFooter(S.GF_PANEL_W)

    --- key -> page. Chaque page est un conteneur de lignes, bâti une fois.
    local pages = {}
    local current

    --- Hauteur hors contenu : titre, ligne du pied, boutons, et les marges qui
    --- les entourent.
    local chromeHeight = S.SECTION_H + S.ROW_H * 2 + S.TOOL_PAD * 3

    --- Repose la taille du panneau d'après la page visible. Les deux
    --- dimensions : la hauteur suit la plus haute des deux colonnes, et la
    --- largeur ne paie la colonne des instances que sur les pages qui en ont
    --- une — l'arène n'a pas à traîner un flanc vide.
    local function fit()
        if not current then return end
        local page = pages[current]

        local contentHeight = page.staticHeight
        local width = S.GF_PANEL_W

        if page.list then
            local listHeight = S.SECTION_H + page.listShown * S.ROW_H
            if listHeight > contentHeight then contentHeight = listHeight end
            width = width + S.GF_LIST_COL_W + S.TOOL_PAD
        end

        panel:SetHeight(chromeHeight + contentHeight)
        panel:SetWidth(width)
        fitFooter(width)
    end

    --- Construit une page d'après ses descripteurs. Voir le contrat en tête de
    --- fichier : une liste au plus, dans sa colonne de droite.
    ---@param descriptors BUI.GroupFilterRowDesc[]
    ---@return table page
    local function buildPage(descriptors)
        local page = W.Container(panel)
        page:SetPoint("TOPLEFT", title, "BOTTOMLEFT")

        -- Largeur posée, jamais déduite des ancres : `Arrange` répartit le
        -- libellé et le contrôle d'après elle, et une largeur d'ancrage ne se
        -- lit qu'une fois le rectangle résolu — c'est-à-dire trop tard pour
        -- une ligne qu'on range à la construction.
        page:SetWidth(rowWidth)

        page.rows = {}
        local y = 0

        local function place(row, height)
            row:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -y)
            row:SetWidth(rowWidth)
            y = y + height
        end

        for i = 1, #descriptors do
            local desc = descriptors[i]

            if desc.type == "header" then
                -- L'écart d'avant-section ne précède pas la toute première
                -- ligne : le titre du panneau fait déjà ce blanc-là.
                if i > 1 then y = y + S.SECTION_GAP end
                place(W.SectionHeader(page, desc.text, true), S.SECTION_H)

            elseif desc.type == "toggle" then
                local row = W.Toggle(page, desc)
                W.Tooltip(row, desc.text, desc.tooltip)
                place(row, S.ROW_H)
                row:Arrange()
                page.rows[#page.rows + 1] = row

            elseif desc.type == "range" then
                local row = rangeRow(page, desc)
                place(row, S.ROW_H)
                row:Arrange()
                page.rows[#page.rows + 1] = row

            elseif desc.type == "list" then
                -- La liste vit dans **sa colonne**, à droite des réglages :
                -- dix lignes empilées sous les rôles faisaient descendre le
                -- panneau sous la fenêtre du client, alors que la place à sa
                -- droite ne coûte rien. Son en-tête est aligné sur le haut de
                -- la page, comme la première section de l'autre colonne.
                local colX = rowWidth + S.TOOL_PAD

                local header = W.SectionHeader(page, desc.text, true)
                header:SetPoint("TOPLEFT", page, "TOPLEFT", colX, 0)
                header:SetWidth(S.GF_LIST_COL_W)

                page.list = {}
                page.listShown = 0
                for slot = 1, S.GF_LIST_MAX do
                    local row = listRow(page)
                    row:SetPoint("TOPLEFT", page, "TOPLEFT",
                        colX, -(S.SECTION_H + (slot - 1) * S.ROW_H))
                    row:SetWidth(S.GF_LIST_COL_W)
                    row:Arrange()
                    row:Hide()
                    page.list[slot] = row
                end
            end
        end

        page.staticHeight = y
        page:SetHeight(y > 0 and y or 1)
        return page
    end

    --- Montre la page `key`, en la bâtissant au premier passage.
    ---@param key string
    ---@param descriptors fun(): BUI.GroupFilterRowDesc[]
    function panel:ShowPage(key, descriptors)
        if not pages[key] then
            pages[key] = buildPage(descriptors())
        end

        for name, page in pairs(pages) do
            page:SetShown(name == key)
        end
        current = key

        self:RefreshCurrent()
        fit()
    end

    --- Relie la liste de la page courante à de nouvelles entrées. Les lignes
    --- au-delà de la dernière entrée — ou du plafond — se cachent.
    ---@param entries { text: string, tooltip?: string, get: fun(): boolean, set: fun(value: boolean) }[]
    function panel:SetListEntries(entries)
        local page = current and pages[current]
        if not (page and page.list) then return end

        local shown = 0
        for slot = 1, #page.list do
            local row   = page.list[slot]
            local entry = entries[slot]
            if entry then
                row:Bind(entry)
                row:Show()
                shown = slot
            else
                row:Hide()
            end
        end

        page.listShown = shown
        fit()
    end

    --- Relit toutes les valeurs de la page visible — après une réinitialisation
    --- ou quand l'état a changé sans passer par le panneau.
    function panel:RefreshCurrent()
        footer:Refresh()

        local page = current and pages[current]
        if not page then return end

        for i = 1, #page.rows do
            page.rows[i]:Refresh()
        end
        if page.list then
            for slot = 1, page.listShown do
                page.list[slot]:Refresh()
            end
        end
    end

    return panel
end
