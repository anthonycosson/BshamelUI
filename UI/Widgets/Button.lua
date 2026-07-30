-- =========================================================================
--  Bshamel UI — UI/Widgets/Button.lua
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local W    = BUI.Widgets

--- Bouton d'action standard du client.
---@param parent table
---@param label string
---@param onClick fun()
---@param width? number
---@return table
function W.Button(parent, label, onClick, width)
    local button = CreateFrame("Button", nil, parent, T.Template("BUTTON"))
    button:SetSize(width or T.SIZE.CONTROL_W, T.SIZE.ROW_H - 2)
    button:SetText(label or "")
    button:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        if onClick then onClick() end
    end)
    return button
end

--- Bouton de navigation de la barre latérale.
--- Pas de template : une entrée de liste a besoin d'un fond de survol et d'un
--- fond de sélection, ce que les templates de bouton du client ne donnent pas
--- sans lutter contre leurs textures.
---@param parent table
---@param label string
---@param indented boolean  entrée de module (indentée) ou en-tête de catégorie
---@return table
function W.SidebarItem(parent, label, indented)
    local button = CreateFrame("Button", nil, parent)
    button:SetHeight(indented and T.SIZE.SIDEBAR_ITEM_H or T.SIZE.SIDEBAR_CAT_H)

    local highlight = button:CreateTexture(nil, "BACKGROUND")
    highlight:SetAllPoints()
    highlight:SetColorTexture(T.COLOR.WHITE:GetRGB())
    highlight:SetAlpha(0)
    button.Highlight = highlight

    local selected = button:CreateTexture(nil, "BACKGROUND")
    selected:SetAllPoints()
    selected:SetColorTexture(T.COLOR.NORMAL:GetRGB())
    selected:SetAlpha(0)
    button.Selected = selected

    local text = button:CreateFontString(nil, "ARTWORK",
        indented and T.FONT.SIDEBAR_ITEM or T.FONT.SIDEBAR_CAT)
    text:SetPoint("LEFT", button, "LEFT", indented and T.SIZE.SIDEBAR_INDENT or 6, 0)
    text:SetPoint("RIGHT", button, "RIGHT", -6, 0)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    text:SetText(label or "")
    button.text = text

    if indented then
        -- Au repos, une entrée de module est dorée comme dans la liste du
        -- panneau Options : c'est la sélection qui passera au blanc, et qui
        -- ressort donc sur ses voisines.
        text:SetTextColor(T.COLOR.NORMAL:GetRGB())

        button:SetScript("OnEnter", function(self)
            if not self._selected then self.Highlight:SetAlpha(T.ALPHA.ROW_HOVER) end
        end)
        button:SetScript("OnLeave", function(self)
            self.Highlight:SetAlpha(0)
        end)
    else
        -- En-tête de catégorie : un bandeau doré, borné en haut et en bas d'un
        -- filet. C'est la même construction que les intitulés « Jeu » ou
        -- « Système » du client — la hiérarchie de la colonne se lit alors sans
        -- avoir à comparer les indentations.
        local band = button:CreateTexture(nil, "BACKGROUND")
        band:SetAllPoints()
        band:SetColorTexture(T.COLOR.NORMAL:GetRGB())
        band:SetAlpha(T.ALPHA.SIDEBAR_BAND)
        button.Band = band

        local top = W.Rule(button, T.COLOR.NORMAL, T.ALPHA.SIDEBAR_RULE)
        top:SetPoint("TOPLEFT")
        top:SetPoint("TOPRIGHT")

        local bottom = W.Rule(button, T.COLOR.NORMAL, T.ALPHA.SIDEBAR_RULE)
        bottom:SetPoint("BOTTOMLEFT")
        bottom:SetPoint("BOTTOMRIGHT")

        text:SetTextColor(T.COLOR.NORMAL:GetRGB())
        button:EnableMouse(false)
    end

    --- Marque l'entrée comme sélectionnée.
    ---@param value boolean
    function button:SetSelected(value)
        self._selected = value
        self.Selected:SetAlpha(value and T.ALPHA.ROW_SELECTED or 0)
        self.Highlight:SetAlpha(0)
        local color = value and T.COLOR.LABEL or T.COLOR.NORMAL
        self.text:SetTextColor(color:GetRGB())
    end

    return button
end
