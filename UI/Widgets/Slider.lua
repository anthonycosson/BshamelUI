-- =========================================================================
--  Bshamel UI — UI/Widgets/Slider.lua
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local U    = BUI.Util
local W    = BUI.Widgets

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
---@param parent table
---@param opts BUI.SliderOpts
---@return table row
function W.Slider(parent, opts)
    local row = W.Row(parent, opts.text, opts.indent)

    local step     = opts.step or 1
    local decimals = opts.decimals or 0

    local slider = CreateFrame("Slider", nil, row, T.Template("SLIDER"))
    slider:SetWidth(T.SIZE.CONTROL_W)
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

    local valueText = row:CreateFontString(nil, "ARTWORK", T.FONT.LABEL_SMALL)
    valueText:SetPoint("LEFT", slider, "RIGHT", 10, 0)
    valueText:SetJustifyH("LEFT")
    valueText:SetWidth(46)

    local function display(value)
        valueText:SetText(string.format("%." .. decimals .. "f", value))
    end

    slider:SetScript("OnValueChanged", function(self, value, userInput)
        value = U.Round(U.Clamp(value, opts.min, opts.max), decimals)
        display(value)
        if userInput then opts.set(value) end
    end)

    row:EnableMouse(true)
    W.Tooltip(row, opts.text, opts.tooltip)
    W.Tooltip(slider, opts.text, opts.tooltip)

    function row:Refresh()
        local value = opts.get()
        if type(value) ~= "number" then value = opts.min end
        slider:SetValue(U.Clamp(value, opts.min, opts.max))
        display(value)
    end

    row:Refresh()
    return row
end
