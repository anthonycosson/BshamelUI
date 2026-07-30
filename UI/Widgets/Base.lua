-- =========================================================================
--  Bshamel UI — UI/Widgets/Base.lua
--  Fabrique de widgets : primitives partagées.
--
--  `UI/Widgets/` est le seul endroit du dépôt autorisé à appeler `CreateFrame`
--  (avec Core/Init.lua pour la frame d'événements). Tout le reste du code
--  déclare, ne dessine pas.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T   = BUI.Theme
local L   = ns.L

local W = {}
BUI.Widgets = W

-- =========================================================================
--  Infobulle
-- =========================================================================

--- Attache une infobulle à une frame. `text` peut être une fonction, évaluée à
--- l'affichage — utile pour un texte qui dépend de l'état courant.
---@param frame table
---@param title string
---@param text? string|fun(): string
function W.Tooltip(frame, title, text)
    frame._tooltipTitle = title
    frame._tooltipText  = text

    if frame._tooltipHooked then return end
    frame._tooltipHooked = true

    frame:HookScript("OnEnter", function(self)
        if not self._tooltipTitle and not self._tooltipText then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self._tooltipTitle then
            GameTooltip_SetTitle(GameTooltip, self._tooltipTitle)
        end

        local body = self._tooltipText
        if type(body) == "function" then body = body() end
        if body then
            GameTooltip_AddNormalLine(GameTooltip, body, true)
        end

        if self._disabledReason then
            GameTooltip_AddErrorLine(GameTooltip, self._disabledReason, true)
        end
        GameTooltip:Show()
    end)

    frame:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

-- =========================================================================
--  Panneaux
-- =========================================================================

--- Frame nue, sans habillage. Sert de conteneur quand on a besoin d'une frame
--- pour des raisons structurelles (page, panneau d'options du client) et non
--- pour son apparence.
---@param parent? table
---@return table
function W.Container(parent)
    return CreateFrame("Frame", nil, parent)
end

--- Panneau creusé, comme les zones de contenu de l'interface Blizzard.
---@param parent table
---@return table
function W.Inset(parent)
    local template = T.Template("INSET")
    local inset = CreateFrame("Frame", nil, parent, template)
    return inset
end

--- Séparateur vertical entre deux panneaux.
---@param parent table
---@return table
function W.VerticalDivider(parent)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetWidth(1)
    if not T.TrySetAtlas(line, T.ATLAS.DIVIDER_V) then
        line:SetColorTexture(T.COLOR.DISABLED:GetRGB())
        line:SetAlpha(0.4)
    end
    return line
end

-- =========================================================================
--  État actif / inactif
-- =========================================================================

--- Applique l'état actif à un widget produit par cette fabrique.
--- Un widget inactif reste visible et survolable : l'infobulle explique
--- pourquoi il est grisé, ce qui vaut mieux qu'un contrôle qui disparaît.
---@param widget table
---@param enabled boolean
---@param reason? string
function W.SetEnabled(widget, enabled, reason)
    widget._disabledReason = (not enabled) and reason or nil

    if widget.label then
        T.SetTextEnabled(widget.label, enabled)
    end

    local control = widget.control
    if control then
        if control.SetEnabled then
            control:SetEnabled(enabled)
        elseif enabled and control.Enable then
            control:Enable()
        elseif control.Disable then
            control:Disable()
        end
        control:SetAlpha(enabled and 1 or 0.5)
    end
end

-- =========================================================================
--  Ligne d'option
-- =========================================================================

--- Conteneur d'une ligne : un libellé à gauche, un contrôle à `CONTROL_X`.
--- Toutes les lignes de toutes les pages passent par ici, c'est ce qui garantit
--- que les contrôles restent alignés en colonne d'une page à l'autre.
---@param parent table
---@param labelText string
---@return table row
function W.Row(parent, labelText)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(T.SIZE.ROW_H)

    local label = row:CreateFontString(nil, "ARTWORK", T.FONT.LABEL)
    label:SetPoint("LEFT", row, "LEFT", T.SIZE.LABEL_INDENT, 0)
    label:SetJustifyH("LEFT")
    label:SetWidth(T.SIZE.CONTROL_X - T.SIZE.LABEL_INDENT * 2)
    label:SetWordWrap(false)
    label:SetText(labelText or "")

    row.label = label
    return row
end

--- Ancre un contrôle dans la colonne de droite d'une ligne.
---@param row table
---@param control table
function W.PlaceControl(row, control)
    control:ClearAllPoints()
    control:SetPoint("LEFT", row, "LEFT", T.SIZE.CONTROL_X, 0)
    row.control = control
end

-- =========================================================================
--  Confirmation
-- =========================================================================

--- Boîte de confirmation modale, sur le modèle des dialogues du client.
---@param message string
---@param onAccept fun()
function W.Confirm(message, onAccept)
    local KEY = "BSHAMELUI_CONFIRM"
    StaticPopupDialogs[KEY] = {
        text         = message,
        button1      = L["Yes"],
        button2      = L["Cancel"],
        OnAccept     = onAccept,
        timeout      = 0,
        whileDead    = true,
        hideOnEscape = true,
        showAlert    = true,
        preferredIndex = 3, -- évite le bug de taint des index bas
    }
    StaticPopup_Show(KEY)
end
