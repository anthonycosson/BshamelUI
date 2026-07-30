-- =========================================================================
--  Bshamel UI — UI/Theme.lua
--  Source unique de vérité pour l'apparence.
--
--  Règle : aucune couleur, police, taille ou espacement littéral ailleurs que
--  dans ce fichier (voir CLAUDE.md, règle 2 — le job `lint` de la CI le
--  vérifie). Une valeur ajustée ici se propage à toute l'interface.
--
--  Parti pris : on n'invente presque rien. Les polices sont les objets de
--  police du client, les couleurs sont celles du client. Quand Blizzard
--  retouche sa direction artistique à un patch, l'addon suit sans code.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI

--- Objet couleur du client, renvoyé par `CreateColor` et par les globales
--- `*_FONT_COLOR`. Déclaré ici parce que l'analyse statique locale ne dispose
--- pas des annotations de l'API World of Warcraft.
---@class ColorMixin
---@field GetRGB fun(self: ColorMixin): number, number, number
---@field GetRGBA fun(self: ColorMixin): number, number, number, number
---@field WrapTextInColorCode fun(self: ColorMixin, text: string): string

local T = {}
BUI.Theme = T

-- =========================================================================
--  Géométrie
-- =========================================================================

T.SIZE = {
    WINDOW_W       = 900,   -- fenêtre d'options
    WINDOW_H       = 620,
    WINDOW_MIN_W   = 760,
    WINDOW_MIN_H   = 480,

    SIDEBAR_W      = 210,   -- colonne de navigation

    PADDING        = 16,    -- marge intérieure d'un pane
    GUTTER         = 10,    -- écart entre deux panes

    TITLEBOX_H     = 38,    -- encadré du titre de page

    ROW_H          = 26,    -- hauteur d'une ligne d'option
    ROW_GAP        = 6,     -- écart vertical entre deux lignes
    SECTION_GAP    = 14,    -- écart avant un en-tête de section
    SECTION_H      = 22,

    CONTROL_X      = 330,   -- abscisse du contrôle dans une ligne : c'est ce
                            -- nombre, et lui seul, qui aligne les cases à
                            -- cocher entre toutes les pages
    CONTROL_W      = 160,   -- largeur des dropdowns / sliders
    LABEL_INDENT   = 6,

    SIDEBAR_CAT_H  = 24,    -- en-tête de catégorie
    SIDEBAR_ITEM_H = 22,    -- entrée de module
    SIDEBAR_INDENT = 14,

    ICON            = 16,
    SCROLLBAR_W     = 24,   -- réservé à droite du contenu défilant

    -- Retraits imposés par le cadre du client : barre de titre en haut, bordure
    -- nine-slice sur les côtés. Mesurés une fois, réutilisés partout.
    CHROME_TOP     = 30,
    CHROME_SIDE    = 10,
    CHROME_BOTTOM  = 10,
}

-- =========================================================================
--  Polices
-- =========================================================================
-- Objets de police du client, jamais de chemin de fichier .ttf.

T.FONT = {
    WINDOW_TITLE = "GameFontNormal",
    PAGE_TITLE   = "GameFontNormalLarge",
    SECTION      = "GameFontNormal",
    LABEL        = "GameFontHighlight",
    LABEL_SMALL  = "GameFontHighlightSmall",
    HINT         = "GameFontDisableSmall",
    SIDEBAR_CAT  = "GameFontNormalSmall",
    SIDEBAR_ITEM = "GameFontHighlightSmall",
}

-- =========================================================================
--  Couleurs
-- =========================================================================
-- On réutilise les couleurs du client pour tout ce qui est structurel, et on
-- n'introduit qu'une seule couleur propre à l'addon : l'accent.

T.COLOR = {
    ACCENT   = CreateColor(0.00, 0.68, 0.94),           -- le bleu de « Bshamel »
    NORMAL   = NORMAL_FONT_COLOR,                        -- doré Blizzard
    LABEL    = HIGHLIGHT_FONT_COLOR,                     -- blanc
    DISABLED = DISABLED_FONT_COLOR,                      -- gris
    WHITE    = WHITE_FONT_COLOR,
    RED      = RED_FONT_COLOR,
    GREEN    = GREEN_FONT_COLOR,
}

--- Code couleur inline, pour les chaînes concaténées.
---@param color ColorMixin
---@param text string
---@return string
function T.Colorize(color, text)
    return color:WrapTextInColorCode(text)
end

--- Teinte du texte d'un widget selon son état actif/inactif.
---@param fontString table
---@param enabled boolean
function T.SetTextEnabled(fontString, enabled)
    local color = enabled and T.COLOR.LABEL or T.COLOR.DISABLED
    fontString:SetTextColor(color:GetRGB())
end

-- =========================================================================
--  Atlas / textures
-- =========================================================================
-- Uniquement des atlas du client (`SetAtlas`), jamais de chemin en dur.

T.ATLAS = {
    DIVIDER_V   = "!UI-HUD-ActionBar-Divider",   -- séparateur vertical fin
    ARROW_RIGHT = "NPE_ArrowRight",
    CHECK       = "common-icon-checkmark",
}

--- Chemins de texture, pour les rares cas sans atlas équivalent.
--- Toute nouvelle entrée passe par ici : aucun chemin littéral dans un widget.
T.TEXTURE = {
    RESIZE_GRIP = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up",
}

--- Applique un atlas si le client le connaît. Renvoie `false` sinon, sans
--- lever d'erreur : un atlas retiré à un patch ne casse pas l'interface.
---@param texture table
---@param atlasName string
---@return boolean applied
function T.TrySetAtlas(texture, atlasName)
    if not atlasName then return false end
    if C_Texture and C_Texture.GetAtlasInfo and not C_Texture.GetAtlasInfo(atlasName) then
        return false
    end
    texture:SetAtlas(atlasName)
    return true
end

-- =========================================================================
--  Templates du client
-- =========================================================================
-- Les widgets s'appuient sur des templates XML de Blizzard. Ils peuvent
-- disparaître ou être renommés d'une extension à l'autre : on déclare donc
-- des candidats par ordre de préférence, et le premier disponible gagne.
-- C'est la forme concrète de la règle « capability check, pas test de version ».

T.TEMPLATES = {
    -- `BasicFrameTemplate` d'abord : il fournit le cadre, la barre de titre et
    -- le bouton de fermeture sans le panneau creusé pleine surface de la
    -- variante `WithInset`, dont on n'a pas besoin puisqu'on pose nos deux
    -- panneaux nous-mêmes.
    WINDOW     = { "BasicFrameTemplate", "BasicFrameTemplateWithInset", "UIPanelDialogTemplate" },
    INSET      = { "InsetFrameTemplate3", "InsetFrameTemplate2", "InsetFrameTemplate" },
    BUTTON     = { "UIPanelButtonTemplate" },
    CHECKBOX   = { "UICheckButtonTemplate", "InterfaceOptionsCheckButtonTemplate" },
    SLIDER     = { "OptionsSliderTemplate" },
    DROPDOWN   = { "WowStyle1DropdownTemplate" },
    SCROLLPANE = { "UIPanelScrollFrameTemplate" },
    EDITBOX    = { "InputBoxTemplate" },
}

local templateCache = {}

--- Le client connaît-il ce template ?
---@param name string
---@return boolean
function T.HasTemplate(name)
    local cached = templateCache[name]
    if cached ~= nil then return cached end

    local exists
    if C_XMLUtil and C_XMLUtil.GetTemplateInfo then
        exists = C_XMLUtil.GetTemplateInfo(name) ~= nil
    else
        -- Client sans C_XMLUtil : on tente la création dans un pcall.
        local ok = pcall(CreateFrame, "Frame", nil, nil, name)
        exists = ok
    end

    templateCache[name] = exists
    return exists
end

--- Premier template disponible dans la liste `T.TEMPLATES[kind]`.
--- Renvoie `nil` si aucun ne l'est — l'appelant doit alors se passer de
--- template plutôt que de lever une erreur.
---@param kind string  clé de T.TEMPLATES
---@return string|nil
function T.Template(kind)
    local candidates = T.TEMPLATES[kind]
    if not candidates then return nil end
    for i = 1, #candidates do
        if T.HasTemplate(candidates[i]) then return candidates[i] end
    end
    BUI:Warn("aucun template disponible pour « " .. kind .. " »")
    return nil
end
