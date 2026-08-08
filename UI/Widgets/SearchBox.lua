-- =========================================================================
--  Bshamel UI — UI/Widgets/SearchBox.lua
--  La zone de recherche de la fenêtre d'options, et la mise en évidence de la
--  ligne qu'elle fait atteindre.
--
--  Deux pièces dans le même fichier parce qu'elles servent le même geste :
--  taper un mot, cliquer un résultat, retrouver la ligne des yeux au milieu
--  d'une page qu'on vient d'ouvrir.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local W    = BUI.Widgets

--- Zone de saisie de recherche.
---
--- L'invite vit **dans** la zone, en caractères d'infobulle, et disparaît dès
--- qu'on écrit : une ligne de libellé à côté prendrait la place que la colonne
--- n'a pas.
---
--- Échap vide la zone avant de rendre le focus : le premier appui annule la
--- recherche, ce qui est ce qu'on demande à Échap — un champ qui garde son
--- texte obligerait à l'effacer à la main pour revoir la liste.
---@param parent table
---@param opts { placeholder: string, onChanged: fun(text: string) }
---@return table
function W.SearchBox(parent, opts)
    local box = CreateFrame("EditBox", nil, parent, T.Template("EDITBOX"))
    box:SetHeight(T.SIZE.SIDEBAR_SEARCH_H)
    box:SetAutoFocus(false)
    box:SetMaxLetters(60)

    -- Le template du client pose sa propre police ; sans lui, on donne la nôtre,
    -- sans quoi la zone serait muette — un EditBox nu n'affiche rien.
    if not box:GetFontObject() then
        local font = _G[T.FONT.LABEL]
        if font then box:SetFontObject(font) end
    end

    local placeholder = box:CreateFontString(nil, "ARTWORK", T.FONT.HINT)
    placeholder:SetPoint("LEFT", box, "LEFT", 0, 0)
    placeholder:SetPoint("RIGHT", box, "RIGHT", 0, 0)
    placeholder:SetJustifyH("LEFT")
    placeholder:SetWordWrap(false)
    placeholder:SetText(opts.placeholder or "")

    box:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)

    box:SetScript("OnTextChanged", function(self)
        local text = self:GetText() or ""
        placeholder:SetShown(text == "")
        if opts.onChanged then opts.onChanged(text) end
    end)

    --- Vide la zone sans voler le focus. Sert au retour à la liste quand la
    --- fenêtre change de page par un autre chemin que la recherche.
    function box:Clear()
        if (self:GetText() or "") ~= "" then self:SetText("") end
    end

    return box
end

-- =========================================================================
--  Mise en évidence d'une ligne
-- =========================================================================

--- Éclaire brièvement une ligne d'option, pour qu'elle se retrouve des yeux
--- après le saut qu'un résultat de recherche vient de faire faire à la page.
---
--- Le bandeau est celui des entrées de la navigation (`W.CenterGlow`) : même
--- vocabulaire, même matière, seulement plus fort — il doit se voir au milieu
--- d'une page entière, pas dans une colonne.
---
--- Un jeton par allumage : si la ligne est éclairée deux fois coup sur coup, le
--- premier minuteur qui expire ne doit pas éteindre le second éclairage.
---@param row table  ligne produite par la fabrique (`W.Row` ou parente)
function W.FlashRow(row)
    if not row._flashGlow then
        row._flashGlow = W.CenterGlow(row, T.COLOR.WHITE, T.ALPHA.ROW_FLASH)
    end

    local token = (row._flashToken or 0) + 1
    row._flashToken = token

    row._flashGlow:SetShown(true)
    C_Timer.After(T.TIMING.ROW_FLASH, function()
        if row._flashToken == token then
            row._flashGlow:SetShown(false)
        end
    end)
end
