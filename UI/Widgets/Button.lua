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

--- Le même bouton, teinté de rouge.
---
--- **Le bouton du client, pas un bouton à nous.** Sa forme, son relief, son
--- creux au clic et sa surbrillance restent ceux de l'interface ; on ne pose
--- qu'un voile par-dessus, assez transparent pour qu'on voie encore le
--- bouton dessous. Redessiner un bouton rouge en entier aurait donné une pièce
--- rapportée là où l'on voulait exactement le contraire — un bouton du jeu
--- qui se signale.
---
--- **Le libellé passe au-dessus du voile, et il faut le dire aux deux.** Le
--- voile monte au plus haut de la couche `ARTWORK`, ce qui le met par-dessus
--- toutes les textures du template ; le libellé est renvoyé au plus haut de la
--- couche `OVERLAY`, qui est au-dessus. Se fier à l'ordre par défaut ne
--- suffisait pas : le rouge passait sur le doré, et un bouton qu'on ne lit
--- plus n'est plus un bouton.
---@param parent table
---@param label string
---@param onClick fun()
---@param width? number
---@return table
function W.DangerButton(parent, label, onClick, width)
    local button = W.Button(parent, label, onClick, width)

    local tint = button:CreateTexture(nil, "ARTWORK", nil, 7)
    tint:SetTexture(T.TEXTURE.SOLID)
    tint:SetVertexColor(T.COLOR.RED:GetRGB())
    tint:SetAlpha(T.ALPHA.DANGER_TINT)

    -- Le voile s'arrête avant le bord : le relief du template est dessiné sur
    -- ses deux derniers pixels, et le recouvrir aplatirait le bouton.
    tint:SetPoint("TOPLEFT", button, "TOPLEFT", T.SIZE.DANGER_INSET, -T.SIZE.DANGER_INSET)
    tint:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT",
        -T.SIZE.DANGER_INSET, T.SIZE.DANGER_INSET)

    local caption = button.GetFontString and button:GetFontString()
    if caption then caption:SetDrawLayer("OVERLAY", 7) end

    button.Tint = tint
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

        -- Deux bandeaux dégradés, forts au centre et estompés aux deux bouts :
        -- l'un pour le survol, l'autre, plus marqué, pour la sélection. Les deux
        -- sont **masqués** au repos, pas rendus transparents — une entrée qui
        -- n'est ni survolée ni sélectionnée ne porte donc littéralement aucune
        -- texture de fond.
        --
        -- Ils ne vivent que sur les entrées de module. Un en-tête de catégorie
        -- n'en reçoit aucun : il ne porte que son bandeau de pierre, et il n'y a
        -- ainsi rien d'autre à soupçonner s'il grisaille un jour.
        button.Highlight = W.CenterGlow(button, T.COLOR.WHITE, T.ALPHA.ROW_HOVER)
        button.Selected  = W.CenterGlow(button, T.COLOR.WHITE, T.ALPHA.ROW_SELECTED)

        button:SetScript("OnEnter", function(self)
            if not self._selected then self.Highlight:SetShown(true) end
        end)
        button:SetScript("OnLeave", function(self)
            self.Highlight:SetShown(false)
        end)

        --- Marque l'entrée comme sélectionnée : le bandeau apparaît et le
        --- libellé passe du doré au blanc.
        ---@param value boolean
        function button:SetSelected(value)
            self._selected = value
            self.Selected:SetShown(value and true or false)
            self.Highlight:SetShown(false)
            local color = value and T.COLOR.LABEL or T.COLOR.NORMAL
            self.text:SetTextColor(color:GetRGB())
        end
    else
        -- En-tête de catégorie : la **texture de la barre de titre de la
        -- fenêtre**, relevée sur le cadre lui-même par `T.CaptureTitleBar`. Un
        -- en-tête de la colonne et le bandeau « Bshamel UI » sont deux fois la
        -- même chose — un intitulé sur une plaque —, ils portent donc la même
        -- matière, sans que personne ait à la nommer quelque part.
        --
        -- À défaut, on retombe sur la pierre du client. Elle est chaude,
        -- brun-doré : telle quelle sous un titre blanc elle se lirait comme un
        -- surlignage au marqueur, d'où la désaturation **avant** la teinte — la
        -- multiplication seule conserverait la teinte.
        local band = button:CreateTexture(nil, "BACKGROUND")
        band:SetAllPoints()

        if T.ApplyTitleBar(band) then
            -- Multipliée jusqu'au sombre : la barre de titre du client est
            -- prévue pour trancher sur un cadre clair, elle est trop lumineuse
            -- pour une colonne sombre. La teinte suit le curseur d'intensité,
            -- comme le fond de la fenêtre — c'est leur écart qui fait l'en-tête.
            T.BandSurface(band)
        else
            band:SetTexture(T.TEXTURE.SIDEBAR_BAND)
            band:SetDesaturated(true)
            band:SetVertexColor(T.COLOR.BAND:GetRGB())
            -- Tuilée plutôt qu'étirée : une pierre écrasée dans un bandeau de
            -- trente pixels de haut donne une bouillie.
            band:SetHorizTile(true)
            band:SetVertTile(true)
            band:SetAlpha(T.ALPHA.SIDEBAR_BAND)
        end

        button.Band = band

        -- Les deux filets qui bordaient le bandeau sont partis avec tous les
        -- autres (voir `W.Rule`, supprimée). Le bandeau se distingue par sa
        -- texture et par son écart de teinte avec la colonne : c'est déjà ce
        -- qui le faisait, les filets ne faisaient que le souligner.

        -- Blanc, comme le titre de page et comme l'entrée sélectionnée : le
        -- blanc marque ce qui se lit, le doré ce qui range.
        text:SetTextColor(T.COLOR.LABEL:GetRGB())
        button:EnableMouse(false)
    end

    return button
end
