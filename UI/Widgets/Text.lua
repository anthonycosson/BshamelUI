-- =========================================================================
--  Bshamel UI — UI/Widgets/Text.lua
--  Widgets purement textuels.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local W    = BUI.Widgets

--- Encadré du titre de page, en haut du panneau de contenu.
--- C'est l'élément qui donne le repère visuel « je suis sur telle page ».
---@param parent table
---@return table
function W.PageTitleBox(parent)
    local box = W.Inset(parent)
    box:SetHeight(T.SIZE.TITLEBOX_H)

    local text = box:CreateFontString(nil, "ARTWORK", T.FONT.PAGE_TITLE)
    text:SetPoint("LEFT", box, "LEFT", T.SIZE.PADDING, 0)
    text:SetJustifyH("LEFT")
    text:SetTextColor(T.COLOR.NORMAL:GetRGB())

    box.text = text
    box.SetTitle = function(self, value) self.text:SetText(value or "") end
    return box
end

--- En-tête de section à l'intérieur d'une page (« AUTOMATISATION », « FILTRES »).
--- Rendu en majuscules et à la couleur d'accent : la hiérarchie visuelle vient
--- de la casse et de la couleur, pas d'une taille de police supplémentaire.
---@param parent table
---@param label string
---@return table
function W.SectionHeader(parent, label)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(T.SIZE.SECTION_H)

    local text = frame:CreateFontString(nil, "ARTWORK", T.FONT.SECTION)
    text:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", T.SIZE.LABEL_INDENT, 2)
    text:SetJustifyH("LEFT")
    text:SetTextColor(T.COLOR.ACCENT:GetRGB())
    text:SetText(string.upper(label or ""))

    local rule = frame:CreateTexture(nil, "ARTWORK")
    rule:SetHeight(1)
    rule:SetPoint("LEFT", text, "RIGHT", 8, 0)
    rule:SetPoint("RIGHT", frame, "RIGHT", -T.SIZE.LABEL_INDENT, 0)
    rule:SetColorTexture(T.COLOR.ACCENT:GetRGB())
    rule:SetAlpha(0.25)

    frame.text = text
    return frame
end

--- Paragraphe explicatif, pour un réglage qui a besoin de plus qu'une infobulle.
--- Le texte suit la largeur de la ligne (ancré des deux côtés) : il se remet en
--- forme tout seul quand la fenêtre est redimensionnée. Sa hauteur, elle, doit
--- être recalculée après coup — c'est le rôle de `AutoHeight`, que le moteur de
--- pages appelle à chaque mise en page.
---@param parent table
---@param label string
---@return table
function W.Description(parent, label)
    local frame = W.Container(parent)

    local text = frame:CreateFontString(nil, "ARTWORK", T.FONT.HINT)
    text:SetPoint("TOPLEFT", frame, "TOPLEFT", T.SIZE.LABEL_INDENT, 0)
    text:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -T.SIZE.LABEL_INDENT, 0)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(true)
    text:SetSpacing(2)
    text:SetText(label or "")

    function frame:AutoHeight()
        self:SetHeight(math.max(text:GetStringHeight() + 4, T.SIZE.SECTION_H))
    end

    frame:AutoHeight()
    frame.text = text
    return frame
end
