-- =========================================================================
--  Bshamel UI — UI/Widgets/NumberBox.lua
--  Une borne : un nombre entier, ou rien du tout.
--
--  **Vide veut dire « pas de borne »**, et c'est ce qui la distingue d'une
--  glissière : une glissière a toujours une valeur, donc filtre toujours, alors
--  que la plupart de ces bornes doivent ne rien faire tant qu'on n'a rien
--  demandé.
--
--  Née dans `GroupFilterPanel.lua`, sortie le jour où la recherche de la liste
--  BIS a voulu les mêmes cases. Deux fabriques : la case seule, pour qui la
--  place lui-même, et les deux lignes qui s'en servent — une borne, ou deux.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local W    = BUI.Widgets
local L    = ns.L

--- Case de saisie d'une borne.
---
--- La valeur ne part que lorsqu'on quitte la case — écrire à chaque frappe
--- filtrerait sur « 1 » pendant qu'on tape « 12 ».
---@param parent table
---@param hint string  « Min », « Max » : posé en filigrane dans la case vide
---@param getValue fun(): number|nil
---@param setValue fun(value: number|nil)
---@return table
function W.BoundBox(parent, hint, getValue, setValue)
    local box = CreateFrame("EditBox", nil, parent, T.Template("EDITBOX"))
    box:SetSize(T.SIZE.SLIDER_VALUE_W, T.SIZE.SLIDER_VALUE_H)
    box:SetAutoFocus(false)
    box:SetJustifyH("CENTER")
    box:SetNumeric(true)

    -- Le corps du nombre de la glissière, pour la même raison qu'elle : le
    -- template du client pose la police du chat, qui détonne sur un panneau.
    local font = _G[T.FONT.LABEL_SMALL]
    if font then box:SetFontObject(font) end

    -- Le filigrane qui dit ce que la case attend. Une case vide sans lui se lit
    -- comme une case cassée : rien n'annonce qu'on y écrit un minimum ou un
    -- maximum. Gris comme un contrôle éteint — c'est une invite, pas une
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

---@class BUI.RangeRowDesc
---@field text string
---@field tooltip? string
---@field indent? boolean
---@field getMin fun(): number|nil
---@field setMin fun(value: number|nil)
---@field getMax fun(): number|nil
---@field setMax fun(value: number|nil)

--- Ligne « libellé + deux bornes » : au moins tant, au plus tant.
---@param parent table
---@param desc BUI.RangeRowDesc
---@return table row
function W.RangeRow(parent, desc)
    local row = W.Row(parent, desc.text, desc.indent)

    -- Les deux cases vivent dans un conteneur : c'est lui que la ligne place à
    -- l'abscisse des contrôles, comme elle le ferait d'une glissière.
    local holder = W.Container(row)
    holder:SetSize(
        T.SIZE.SLIDER_VALUE_W * 2 + T.SIZE.SLIDER_VALUE_GAP,
        T.SIZE.SLIDER_VALUE_H)

    local minBox = W.BoundBox(row, L["Min"], desc.getMin, desc.setMin)
    minBox:SetPoint("LEFT", holder, "LEFT")

    local maxBox = W.BoundBox(row, L["Max"], desc.getMax, desc.setMax)
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

---@class BUI.BoundRowDesc
---@field text string
---@field tooltip? string
---@field indent? boolean
---@field hint string
---@field get fun(): number|nil
---@field set fun(value: number|nil)

--- Ligne « libellé + une borne ». Le filigrane est à l'appelant : c'est lui qui
--- sait si la case attend un plancher ou un plafond.
---@param parent table
---@param desc BUI.BoundRowDesc
---@return table row
function W.BoundRow(parent, desc)
    local row = W.Row(parent, desc.text, desc.indent)

    local box = W.BoundBox(row, desc.hint, desc.get, desc.set)
    W.PlaceControl(row, box)

    row:EnableMouse(true)
    W.Tooltip(row, desc.text, desc.tooltip)

    function row:Refresh()
        box:Refresh()
    end

    row:Refresh()
    return row
end
