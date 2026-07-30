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

    SIDEBAR_W      = 230,   -- colonne de navigation

    PADDING        = 16,    -- marge intérieure d'un pane
    GUTTER         = 10,    -- écart entre deux panes
    PANEL_PAD      = 6,     -- retrait du contenu à l'intérieur d'un panneau creusé

    PAGE_TITLE_H   = 46,    -- bloc du titre de page : le texte et son filet
    RULE_H         = 1,     -- épaisseur d'un filet de séparation

    ROW_H          = 30,    -- hauteur d'une ligne d'option
    ROW_GAP        = 6,     -- écart vertical entre deux lignes
    SECTION_GAP    = 16,    -- écart avant un en-tête de section
    SECTION_H      = 26,

    CONTROL_X      = 340,   -- abscisse du contrôle dans une ligne : c'est ce
                            -- nombre, et lui seul, qui aligne les cases à
                            -- cocher entre toutes les pages
    CONTROL_W      = 160,   -- largeur des dropdowns / sliders
    LABEL_INDENT   = 8,

    SIDEBAR_CAT_H  = 30,    -- bandeau d'en-tête de catégorie
    SIDEBAR_ITEM_H = 26,    -- entrée de module
    SIDEBAR_INDENT = 18,

    ICON            = 16,
    SCROLLBAR_W     = 24,   -- réservé à droite du contenu défilant
    THUMB_MIN       = 20,   -- hauteur plancher du curseur d'ascenseur

    EDGE_SHADE      = 64,   -- profondeur du voile sombre aux bords de la fenêtre

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
--
-- Comme pour les templates, on déclare des candidats par ordre de préférence.
-- Les variantes `Medium` et `Large2` sont récentes et ne sont garanties par
-- aucun contrat : une police inconnue passée à `CreateFontString` ne dégrade
-- pas, elle lève une erreur. On résout donc une fois au chargement, et on se
-- rabat sur la variante de base.

local FONT_CANDIDATES = {
    WINDOW_TITLE = { "GameFontNormal" },

    -- Titre de page en blanc et non en doré : c'est le repère principal de la
    -- zone de droite, il doit primer sur les en-têtes de section.
    PAGE_TITLE   = { "GameFontHighlightLarge2", "GameFontHighlightHuge", "GameFontHighlightLarge" },

    SECTION      = { "GameFontNormalMedium", "GameFontNormal" },
    LABEL        = { "GameFontHighlightMedium", "GameFontHighlight" },
    LABEL_SMALL  = { "GameFontHighlight", "GameFontHighlightSmall" },
    HINT         = { "GameFontDisableSmall" },
    SIDEBAR_CAT  = { "GameFontNormalMedium", "GameFontNormal" },
    SIDEBAR_ITEM = { "GameFontHighlightMedium", "GameFontHighlight" },
}

T.FONT = {}
for key, candidates in pairs(FONT_CANDIDATES) do
    local resolved = candidates[#candidates]
    for i = 1, #candidates do
        if _G[candidates[i]] then
            resolved = candidates[i]
            break
        end
    end
    T.FONT[key] = resolved
end

-- =========================================================================
--  Couleurs
-- =========================================================================
-- On réutilise les couleurs du client pour tout ce qui est structurel, et on
-- n'introduit qu'une seule couleur propre à l'addon : l'accent.

-- Répartition, calquée sur le panneau Options du client :
--   doré   → tout ce qui structure (catégories, en-têtes de section, entrées
--            de navigation au repos) ;
--   blanc  → ce qui est lu (titre de page, libellés d'options) et ce qui est
--            sélectionné, qui ressort ainsi sur le doré ambiant.
-- L'accent bleu reste la couleur de la marque — il vit dans le nom de l'addon,
-- pas dans le chrome de la fenêtre, où il jurerait avec l'interface du jeu.

T.COLOR = {
    ACCENT   = CreateColor(0.00, 0.68, 0.94),           -- le bleu de « Bshamel »
    NORMAL   = NORMAL_FONT_COLOR,                        -- doré Blizzard
    LABEL    = HIGHLIGHT_FONT_COLOR,                     -- blanc
    DISABLED = DISABLED_FONT_COLOR,                      -- gris
    WHITE    = WHITE_FONT_COLOR,
    RED      = RED_FONT_COLOR,
    GREEN    = GREEN_FONT_COLOR,
    SHADE    = CreateColor(0.00, 0.00, 0.00),            -- voile des bords
}

-- =========================================================================
--  Opacités
-- =========================================================================
-- Une seule table pour toutes les transparences de l'interface. Elles se
-- règlent les unes par rapport aux autres — le fond d'une fenêtre, la teinte
-- d'une ligne survolée et celle d'une ligne sélectionnée forment une échelle —,
-- donc elles se lisent au même endroit.

T.ALPHA = {
    WINDOW_BG      = 0.80,  -- fond de la fenêtre : le jeu transparaît derrière

    -- Zéro, et ce n'est pas un oubli : un panneau creusé pose sa bordure mais
    -- pas de fond. Un second voile empilé sur celui de la fenêtre rendrait la
    -- colonne de navigation plus sombre que la zone de contenu, alors que les
    -- deux doivent se lire sur exactement la même teinte.
    PANEL_BG       = 0.00,

    EDGE_SHADE     = 0.55,  -- voile sombre au bord de la fenêtre, dégradé vers
                            -- l'intérieur

    SIDEBAR_BAND   = 0.16,  -- bandeau d'une catégorie de la navigation
    SIDEBAR_RULE   = 0.35,  -- filets qui bordent ce bandeau
    ROW_HOVER      = 0.10,  -- entrée de navigation survolée
    ROW_SELECTED   = 0.30,  -- entrée de navigation sélectionnée
    ITEM_OFF       = 0.45,  -- entrée d'un module éteint

    RULE           = 0.35,  -- filet sous le titre de page
    SECTION_RULE   = 0.30,  -- filet d'un en-tête de section

    CONTROL_OFF    = 0.50,  -- contrôle grisé
    GRIP           = 0.70,  -- poignée de redimensionnement au repos
    GRIP_HOVER     = 1.00,
}

--- Applique un dégradé « voile sombre » à une texture : opaque du côté du bord
--- de la fenêtre, transparent de l'autre.
---
--- Renvoie `false` si le client ne sait pas dégrader une texture — l'appelant
--- doit alors renoncer au voile plutôt que de laisser une bande noire pleine.
---@param texture table
---@param orientation string  "HORIZONTAL" (min = gauche) ou "VERTICAL" (min = bas)
---@param edgeAtMax boolean   le bord est-il du côté « max » du dégradé ?
---@return boolean applied
function T.ApplyShade(texture, orientation, edgeAtMax)
    if not texture.SetGradient then return false end

    local r, g, b = T.COLOR.SHADE:GetRGB()
    texture:SetColorTexture(r, g, b)

    local opaque = CreateColor(r, g, b, T.ALPHA.EDGE_SHADE)
    local clear  = CreateColor(r, g, b, 0)

    if edgeAtMax then
        texture:SetGradient(orientation, clear, opaque)
    else
        texture:SetGradient(orientation, opaque, clear)
    end
    return true
end

--- Rend un panneau translucide sans toucher à son contenu.
---
--- On ne baisse jamais l'alpha de la frame elle-même : cela ferait pâlir ses
--- enfants avec elle. On n'agit que sur les textures de fond. `Bg` est la clé
--- qu'exposent les templates du client ; le repli parcourt le calque
--- `BACKGROUND` pour les templates qui ne la publient pas — ce qui évite d'avoir
--- à connaître leur structure interne, susceptible de changer à tout patch.
---@param frame table
---@param alpha number
function T.SetPanelAlpha(frame, alpha)
    if frame.Bg then
        frame.Bg:SetAlpha(alpha)
        return
    end

    for _, region in ipairs({ frame:GetRegions() }) do
        if region.GetDrawLayer and region:GetDrawLayer() == "BACKGROUND" then
            region:SetAlpha(alpha)
        end
    end
end

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
