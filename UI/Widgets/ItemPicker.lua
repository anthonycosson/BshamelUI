-- =========================================================================
--  Bshamel UI — UI/Widgets/ItemPicker.lua
--  Petite liste d'objets qu'on ouvre sur un bouton pour en choisir un.
--
--  Une liste et non un menu du client : ce qu'on y choisit n'est pas une action
--  mais une **donnée** — quelle gemme sertir —, et le geste qui suit est décidé
--  par l'appelant. Un menu sécurisé serait ici une machinerie sans objet
--  (voir `UI/Widgets/SecureMenu.lua`, qui existe pour le cas inverse).
--
--  Elle emprunte la géométrie du menu de téléportation : même largeur, mêmes
--  marges, même hauteur de ligne. Deux listes du même addon qui s'ouvrent sur un
--  bouton n'ont aucune raison de ne pas se ressembler.
--
--  Construite une fois puis réemployée : une frame ne se détruit pas en World of
--  Warcraft (règle 7). `Open` la remplit, `Close` la cache.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local W    = BUI.Widgets

--- Une ligne : son icône, son nom.
---@param list table
---@return table
local function newRow(list)
    local row = CreateFrame("Button", nil, list)
    row:SetHeight(T.SIZE.MENU_ROW_H)

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(T.SIZE.MENU_ICON, T.SIZE.MENU_ICON)
    icon:SetPoint("LEFT", row, "LEFT", T.SIZE.MENU_PAD, 0)

    local label = row:CreateFontString(nil, "ARTWORK", T.FONT.LABEL_SMALL)
    label:SetPoint("LEFT", icon, "RIGHT", T.SIZE.MENU_GAP, 0)
    label:SetPoint("RIGHT", row, "RIGHT", -T.SIZE.MENU_PAD, 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)

    -- La ligne survolée s'éclaire : c'est le seul retour qu'une liste doive à
    -- celui qui la parcourt.
    local hover = row:CreateTexture(nil, "BACKGROUND")
    hover:SetAllPoints()
    T.SetPanelFill(hover, T.COLOR.LABEL, T.ALPHA.ROW_HOVER)
    hover:Hide()

    row:SetScript("OnEnter", function(self)
        hover:Show()
        if not self._link then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(self._link)
        GameTooltip:Show()
    end)

    row:SetScript("OnLeave", function()
        hover:Hide()
        GameTooltip:Hide()
    end)

    row.icon  = icon
    row.label = label
    return row
end

---@class BUI.PickerEntry
---@field link string
---@field name string
---@field icon string|number
---@field onChoose fun()

--- Liste d'objets, masquée au départ.
---@return table
function W.ItemPicker()
    local list = CreateFrame("Frame", nil, UIParent)
    list:SetWidth(T.SIZE.MENU_W)
    list:SetFrameStrata("DIALOG")
    list:Hide()

    W.DialogBorder(list)
    T.SetPanelFill(list, T.COLOR.WINDOW, T.ALPHA.WINDOW_BG)

    local rows = {}

    --- Ferme la liste. Le curseur est rendu au passage : une gemme laissée
    --- dessus après une fermeture serait un objet qu'on croit avoir reposé.
    function list:Close()
        self:Hide()
    end

    W.CloseOnOutsideClick(list, function() list:Close() end)

    --- Remplit la liste et l'ouvre contre un bouton.
    ---@param entries BUI.PickerEntry[]
    ---@param anchor table
    function list:Open(entries, anchor)
        local count = 0

        for i = 1, #entries do
            local entry = entries[i]
            local row   = rows[i]

            if not row then
                row     = newRow(self)
                rows[i] = row
            end

            row.icon:SetTexture(entry.icon)
            row.label:SetText(entry.name or "")
            row._link = entry.link

            row:SetScript("OnClick", function()
                self:Close()
                if entry.onChoose then entry.onChoose() end
            end)

            row:ClearAllPoints()
            if i == 1 then
                row:SetPoint("TOPLEFT",  self, "TOPLEFT",  0, -T.SIZE.MENU_PAD)
                row:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, -T.SIZE.MENU_PAD)
            else
                row:SetPoint("TOPLEFT",  rows[i - 1], "BOTTOMLEFT",  0, 0)
                row:SetPoint("TOPRIGHT", rows[i - 1], "BOTTOMRIGHT", 0, 0)
            end

            row:Show()
            count = i
        end

        for i = count + 1, #rows do rows[i]:Hide() end

        if count == 0 then
            self:Close()
            return
        end

        self:SetHeight(count * T.SIZE.MENU_ROW_H + 2 * T.SIZE.MENU_PAD)

        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -T.SIZE.MENU_GAP)
        self:Show()
    end

    return list
end
