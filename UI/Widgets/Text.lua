-- =========================================================================
--  Bshamel UI — UI/Widgets/Text.lua
--  Widgets purement textuels.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local W    = BUI.Widgets

--- Titre de la page affichée, en haut de la zone de contenu.
--- C'est l'élément qui donne le repère visuel « je suis sur telle page ».
---
--- Pas d'encadré : le titre est posé à même la fenêtre, en grand et en blanc,
--- souligné d'un filet qui court sur toute la largeur. L'encadrement est réservé
--- à la colonne de navigation — un seul creux par fenêtre, sinon les deux zones
--- se disputent le regard.
---@param parent table
---@return table
function W.PageTitle(parent)
    local block = W.Container(parent)
    block:SetHeight(T.SIZE.PAGE_TITLE_H)

    local text = block:CreateFontString(nil, "ARTWORK", T.FONT.PAGE_TITLE)
    text:SetPoint("TOPLEFT", block, "TOPLEFT", T.SIZE.LABEL_INDENT, -T.SIZE.ROW_GAP)
    text:SetJustifyH("LEFT")

    local rule = W.Rule(block, T.COLOR.LABEL, T.ALPHA.RULE)
    rule:SetPoint("BOTTOMLEFT", block, "BOTTOMLEFT", 0, 0)
    rule:SetPoint("BOTTOMRIGHT", block, "BOTTOMRIGHT", 0, 0)

    block.text = text
    block.SetTitle = function(self, value) self.text:SetText(value or "") end
    return block
end

--- En-tête de section à l'intérieur d'une page (« AUTOMATISATION », « FILTRES »).
--- Rendu en majuscules et en doré : la hiérarchie visuelle vient de la casse et
--- de la couleur, pas d'une taille de police supplémentaire. Le doré est celui
--- qui structure le panneau Options du client ; le titre de page, lui, reste
--- blanc et garde donc le dessus.
---@param parent table
---@param label string
---@return table
function W.SectionHeader(parent, label)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(T.SIZE.SECTION_H)

    local text = frame:CreateFontString(nil, "ARTWORK", T.FONT.SECTION)
    text:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", T.SIZE.LABEL_INDENT, 2)
    text:SetJustifyH("LEFT")
    text:SetTextColor(T.COLOR.NORMAL:GetRGB())
    text:SetText(string.upper(label or ""))

    local rule = W.Rule(frame, T.COLOR.NORMAL, T.ALPHA.SECTION_RULE)
    rule:SetPoint("LEFT", text, "RIGHT", T.SIZE.GUTTER, 0)
    rule:SetPoint("RIGHT", frame, "RIGHT", -T.SIZE.LABEL_INDENT, 0)

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
