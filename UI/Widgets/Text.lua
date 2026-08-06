-- =========================================================================
--  Bshamel UI — UI/Widgets/Text.lua
--  Widgets purement textuels.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local W    = BUI.Widgets

-- =========================================================================
--  Plus aucun filet
-- =========================================================================
-- L'addon n'en trace plus : ni sous le titre de page, ni à droite d'une
-- catégorie, ni autour d'un bandeau de navigation. `W.Rule` a disparu avec eux.
--
-- Ce n'est pas un renoncement esthétique, c'est un constat technique. Un trait
-- d'un pixel ne tient pas sur un écran dont l'échelle d'interface n'est pas
-- entière : il tombe entre deux rangées de la grille et s'y dessine tantôt net,
-- tantôt étalé, tantôt pas du tout — et comme chaque ligne d'une page atterrit à
-- une phase différente, deux catégories voisines ne se ressemblaient jamais. On
-- a arrondi l'épaisseur, puis la position, puis celle des lignes ; il restait le
-- défilement, qui décale tout d'une fraction à chaque cran de molette.
--
-- Ce qui hiérarchise reste : la casse, la couleur, le corps, le retrait et
-- l'espace avant un titre. Ce sont eux qui portaient déjà la structure — le
-- filet ne faisait que la souligner, et il la soulignait mal.

--- Titre de la page affichée, en haut de la zone de contenu.
--- C'est l'élément qui donne le repère visuel « je suis sur telle page ».
---
--- Pas d'encadré : le titre est posé à même la fenêtre, en grand et en blanc.
--- L'encadrement est réservé à la colonne de navigation — un seul creux par
--- fenêtre, sinon les deux zones se disputent le regard.
---@param parent table
---@return table
function W.PageTitle(parent)
    local block = W.Container(parent)
    block:SetHeight(T.SIZE.PAGE_TITLE_H)

    local text = block:CreateFontString(nil, "ARTWORK", T.FONT.PAGE_TITLE)
    text:SetPoint("TOPLEFT", block, "TOPLEFT", T.SIZE.LABEL_INDENT, -T.SIZE.ROW_GAP)
    text:SetJustifyH("LEFT")

    block.text = text
    block.SetTitle = function(self, value) self.text:SetText(value or "") end
    return block
end

--- En-tête de section à l'intérieur d'une page (« AUTOMATISATION », « FILTRES »).
---
--- Rendu en majuscules et en doré : **toute** la hiérarchie tient là, plus un
--- corps au-dessus des libellés et l'espace qui le précède. Le doré est celui
--- qui structure le panneau Options du client ; le titre de page, lui, reste
--- blanc et garde donc le dessus.
---
--- Le filet qui courait à sa droite est parti (voir « Plus aucun filet »). Ce
--- qu'il ajoutait était de la confirmation, pas de l'information : un mot en
--- capitales dorées, seul de sa ligne et précédé d'un blanc, se lit déjà comme
--- un titre.
---
--- Le titre n'est plus tronqué non plus : il ne cédait sa fin que pour laisser
--- de la place au filet.
---
--- `indent` le range **sous** le titre précédent, au même retrait que les
--- sous-options. C'est ce qui reste pour dire la subordination depuis que les
--- filets sont partis, et c'est le vocabulaire que la page emploie déjà partout
--- ailleurs : ce qui dépend de ce qui est au-dessus est décalé.
---@param parent table
---@param label string
---@param indent? boolean
---@return table
function W.SectionHeader(parent, label, indent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(T.SIZE.SECTION_H)

    local left = T.SIZE.LABEL_INDENT
    if indent then left = left + T.SIZE.LABEL_SUB_INDENT end

    local text = frame:CreateFontString(nil, "ARTWORK", T.FONT.SECTION)
    text:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", left, 2)
    text:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -T.SIZE.LABEL_INDENT, 2)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    text:SetTextColor(T.COLOR.NORMAL:GetRGB())
    text:SetText(string.upper(label or ""))

    frame.text = text
    return frame
end

-- `W.SubHeader` vivait ici : un en-tête de rang moindre, sans filet et en
-- retrait, pour une section vivant à l'intérieur d'une autre. Il est parti avec
-- les filets — ce qui le distinguait d'un en-tête majeur était précisément de ne
-- pas en avoir, et cette distinction-là n'existe plus. Aucune page ne s'en
-- servait au moment de le retirer.

--- Paragraphe explicatif, pour un réglage qui a besoin de plus qu'une infobulle.
--- Le texte suit la largeur de la ligne (ancré des deux côtés) : il se remet en
--- forme tout seul quand la fenêtre est redimensionnée. Sa hauteur, elle, doit
--- être recalculée après coup — c'est le rôle de `AutoHeight`, que le moteur de
--- pages appelle à chaque mise en page.
---@param parent table
---@param label string
---@param font? string  objet de police du thème, à défaut celui d'une infobulle
---@return table
function W.Description(parent, label, font)
    local frame = W.Container(parent)

    local text = frame:CreateFontString(nil, "ARTWORK", font or T.FONT.HINT)
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

--- Le même paragraphe, en orange : ce qu'il dit engage quelque chose qui ne se
--- rattrape pas.
---
--- L'orange et non le rouge : le rouge dit « c'est cassé », or rien ne l'est —
--- le réglage marche exactement comme annoncé, c'est ce qu'il autorise qui
--- demande d'y penser. C'est le même orange que le troisième terme du feu
--- tricolore, et il garde ici le même sens : ni interdit, ni anodin.
---@param parent table
---@param label string
---@return table
function W.Warning(parent, label)
    local frame = W.Description(parent, label)
    frame.text:SetTextColor(T.COLOR.ORANGE:GetRGB())
    return frame
end

--- Note d'ouverture d'une moitié de page : **d'où viennent les réglages qui
--- suivent**. En rouge, et d'un corps au-dessus du paragraphe ordinaire.
---
--- Le rouge ne dit pas « c'est cassé » ici. Une page qui montre côte à côte les
--- réglages du jeu et ceux de l'addon a besoin d'une ligne qui se lit avant
--- tout le reste : les deux moitiés se ressemblent ligne pour ligne, et deux
--- titres seuls ne disent pas assez vite laquelle on regarde. Le corps plus
--- grand va avec — une note qu'il faut lire d'abord ne peut pas être écrite en
--- caractères d'infobulle.
---
--- Les deux moitiés portent la leur, à la même taille et de la même couleur :
--- ce n'est pas un avertissement sur l'une d'elles, c'est l'étiquette de chacune.
---@param parent table
---@param label string
---@return table
function W.Alert(parent, label)
    local frame = W.Description(parent, label, T.FONT.NOTICE)
    frame.text:SetTextColor(T.COLOR.RED:GetRGB())
    return frame
end
