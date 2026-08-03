-- =========================================================================
--  Bshamel UI — UI/Widgets/Toggle.lua
--  Case à cocher : le widget le plus utilisé, donc celui qui décide de
--  l'alignement général des pages.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local W    = BUI.Widgets

---@class BUI.ToggleOpts
---@field text string
---@field tooltip? string
---@field indent? boolean  sous-option : en retrait, d'un corps plus petit
---@field get fun(): boolean
---@field set fun(value: boolean)

--- Ligne « libellé + case à cocher ».
---
---     W.Toggle(parent, {
---         text     = L["Auto-accept quests"],
---         tooltip  = L["Auto-accept quests tip"],
---         get      = function() return mod:Get("autoAccept") end,
---         set      = function(v) mod:Set("autoAccept", v) end,
---     })
---
---@param parent table
---@param opts BUI.ToggleOpts
---@return table row
function W.Toggle(parent, opts)
    local row = W.Row(parent, opts.text, opts.indent)

    local check = CreateFrame("CheckButton", nil, row, T.Template("CHECKBOX"))
    check:SetSize(T.SIZE.CHECK_SIZE, T.SIZE.CHECK_SIZE)
    W.PlaceControl(row, check)

    check:SetScript("OnClick", function(self)
        local value = self:GetChecked() and true or false
        PlaySound(value and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON
                        or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        opts.set(value)
    end)

    -- L'infobulle est portée par la ligne entière, pas par la seule case :
    -- survoler le libellé doit suffire à obtenir l'explication.
    row:EnableMouse(true)
    W.Tooltip(row, opts.text, opts.tooltip)
    W.Tooltip(check, opts.text, opts.tooltip)

    --- Relit la valeur en base et met la case à jour.
    function row:Refresh()
        check:SetChecked(opts.get() and true or false)
    end

    row:Refresh()
    return row
end
