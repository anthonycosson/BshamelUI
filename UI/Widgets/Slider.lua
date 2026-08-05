-- =========================================================================
--  Bshamel UI — UI/Widgets/Slider.lua
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local U    = BUI.Util
local W    = BUI.Widgets
local L    = ns.L

---@class BUI.SliderOpts
---@field text string
---@field tooltip? string
---@field indent? boolean  sous-option : en retrait, d'un corps plus petit
---@field min number
---@field max number
---@field step? number
---@field decimals? integer
---@field get fun(): number
---@field set fun(value: number)

--- Ligne « libellé + glissière + valeur ».
---
--- La valeur vit dans une **case de saisie**, et non dans un texte posé à côté
--- de la glissière. Une glissière règle vite mais mal : à cent crans sur cent
--- soixante pixels, viser un nombre précis se fait au pixel près, et certaines
--- pages en alignent une dizaine. Le clavier passe outre.
---
--- Le cadre du client autour du nombre n'est pas une décoration : c'est le seul
--- endroit où l'on peut dire que le nombre se saisit. Une infobulle ne se lit
--- que sur ce qu'on soupçonne déjà d'être cliquable.
---@param parent table
---@param opts BUI.SliderOpts
---@return table row
function W.Slider(parent, opts)
    local S   = T.SIZE
    local row = W.Row(parent, opts.text, opts.indent)

    local step     = opts.step or 1
    local decimals = opts.decimals or 0

    local slider = CreateFrame("Slider", nil, row, T.Template("SLIDER"))
    slider:SetWidth(S.CONTROL_W)
    slider:SetMinMaxValues(opts.min, opts.max)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    W.PlaceControl(row, slider)

    -- Le template `OptionsSliderTemplate` fournit trois FontStrings nommées.
    -- On neutralise les libellés min/max : la valeur courante affichée à droite
    -- suffit et garde les lignes visuellement calmes.
    if slider.Low  then slider.Low:SetText("")  end
    if slider.High then slider.High:SetText("") end
    if slider.Text then slider.Text:SetText("") end

    local valueBox = CreateFrame("EditBox", nil, row, T.Template("EDITBOX"))
    valueBox:SetSize(S.SLIDER_VALUE_W, S.SLIDER_VALUE_H)
    valueBox:SetPoint("LEFT", slider, "RIGHT", S.SLIDER_VALUE_GAP, 0)
    valueBox:SetAutoFocus(false)
    valueBox:SetJustifyH("CENTER")

    -- Le corps du nombre qu'elle remplace. Le template du client en pose un
    -- autre — celui du chat —, qui détonne au milieu d'une page d'options.
    local font = _G[T.FONT.LABEL_SMALL]
    if font then valueBox:SetFontObject(font) end

    --- Écrit la valeur dans la case — sauf pendant qu'on y tape : l'écraser sous
    --- les doigts de celui qui la saisit est le seul moyen de rendre la case
    --- inutilisable.
    ---@param value number
    local function display(value)
        if valueBox:HasFocus() then return end
        valueBox:SetText(string.format("%." .. decimals .. "f", value))
        valueBox:SetCursorPosition(0)
    end

    slider:SetScript("OnValueChanged", function(_, value, userInput)
        value = U.Round(U.Clamp(value, opts.min, opts.max), decimals)
        display(value)
        if userInput then opts.set(value) end
    end)

    -- Rendre le focus rappelle `OnEditFocusLost`, donc la validation. Sans ce
    -- drapeau, valider se rappellerait lui-même, et Échap repartirait valider ce
    -- qu'il vient d'annuler.
    local leaving = false

    --- Prend ce qui est tapé, ou rend la valeur courante si ce n'en est pas une.
    ---
    --- La virgule est acceptée au même titre que le point : un client français
    --- écrit « 2,9 » dans ses propres réglages, et le pavé numérique donne la
    --- virgule. Refuser la saisie qu'on affiche soi-même serait la seule
    --- surprise possible ici.
    local function commit()
        if leaving then return end
        leaving = true

        -- En deux temps : `gsub` rend aussi son nombre de remplacements, et le
        -- passer à `tonumber` en ferait une base de numération.
        local text  = (valueBox:GetText() or ""):gsub(",", ".")
        local typed = tonumber(text)

        valueBox:ClearFocus()

        if typed then
            -- On repasse par la glissière plutôt que d'écrire le réglage
            -- directement : c'est elle qui borne, et c'est elle qui décide si la
            -- valeur tombe sur un cran. On relit donc ce qu'elle a retenu, et
            -- c'est ce nombre-là — jamais celui qui a été tapé — qui part au
            -- réglage et qui s'affiche.
            slider:SetValue(U.Clamp(typed, opts.min, opts.max))

            local applied = U.Round(slider:GetValue(), decimals)
            display(applied)
            leaving = false
            opts.set(applied)
            return
        end

        leaving = false
        row:Refresh()
    end

    valueBox:SetScript("OnEnterPressed",  commit)
    valueBox:SetScript("OnEditFocusLost", commit)
    valueBox:SetScript("OnEscapePressed", function(self)
        leaving = true
        self:ClearFocus()
        leaving = false
        row:Refresh()
    end)

    -- Le clic droit est le geste annoncé, mais rien n'oblige à s'y tenir : une
    -- case de saisie prend le focus au clic gauche toute seule, et le lui
    -- retirer ferait une case qui refuse le geste qu'elle appelle. Les deux
    -- mènent au même endroit ; seul le droit avait besoin d'être écrit.
    valueBox:SetScript("OnMouseDown", function(self, button)
        if button == "RightButton" then self:SetFocus() end
    end)

    -- Tout est sélectionné à la prise de focus : on remplace un nombre, on ne
    -- l'édite pas caractère par caractère.
    valueBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)

    row:EnableMouse(true)
    W.Tooltip(row, opts.text, opts.tooltip)
    W.Tooltip(slider, opts.text, opts.tooltip)
    W.Tooltip(valueBox, opts.text, L["Slider value tip"])

    --- La case suit l'état de la ligne. Une glissière grisée dont le nombre
    --- reste saisissable est un contrôle éteint qui marche encore.
    ---@param enabled boolean
    function row:OnEnabled(enabled)
        if not enabled then valueBox:ClearFocus() end
        W.SetControlEnabled(valueBox, enabled)
    end

    function row:Refresh()
        local value = opts.get()
        if type(value) ~= "number" then value = opts.min end
        slider:SetValue(U.Clamp(value, opts.min, opts.max))
        display(value)
    end

    row:Refresh()
    return row
end
