-- =========================================================================
--  Bshamel UI — UI/Widgets/Dropdown.lua
--
--  Utilise le système de menus actuel (`SetupMenu` + `rootDescription`), pas
--  l'ancien `UIDropDownMenu`. Si le client ne l'expose pas, le widget se
--  dégrade en bouton qui fait défiler les valeurs — l'option reste réglable.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local W    = BUI.Widgets

--- Valeurs proposées. `opts.values` peut être une **fonction** : la liste est
--- alors relue à chaque ouverture du menu et à chaque rafraîchissement. C'est
--- pour les listes qui dépendent du personnage — les pierres de foyer qu'il
--- possède, par exemple —, qui ne sont pas connues à la construction de la page.
---@param opts BUI.DropdownOpts
---@return BUI.DropdownEntry[]
local function valuesOf(opts)
    local values = opts.values
    if type(values) == "function" then return values() or {} end
    return values or {}
end

--- Libellé associé à une valeur.
---@param values BUI.DropdownEntry[]
---@param value any
---@return string
local function labelFor(values, value)
    for i = 1, #values do
        if values[i].value == value then return values[i].label end
    end
    return tostring(value)
end

local function setButtonText(control, text)
    if control.SetDefaultText then
        control:SetDefaultText(text)
    elseif control.SetText then
        control:SetText(text)
    end
end

--- Menu déroulant moderne.
local function modernDropdown(row, opts)
    local control = CreateFrame("DropdownButton", nil, row, T.Template("DROPDOWN"))
    control:SetSize(T.SIZE.CONTROL_W, T.SIZE.ROW_H - 2)
    W.PlaceControl(row, control)

    control:SetupMenu(function(_, rootDescription)
        local values = valuesOf(opts)
        for i = 1, #values do
            local entry = values[i]
            rootDescription:CreateRadio(
                entry.label,
                function() return opts.get() == entry.value end,
                function() opts.set(entry.value) end
            )
        end
    end)

    return control
end

--- Repli : un bouton qui passe à la valeur suivante à chaque clic.
local function cyclingButton(row, opts)
    local control = W.Button(row, "", function()
        local values = valuesOf(opts)
        if #values == 0 then return end

        local current = opts.get()
        local index = 1
        for i = 1, #values do
            if values[i].value == current then
                index = i
                break
            end
        end
        opts.set(values[(index % #values) + 1].value)
    end)
    W.PlaceControl(row, control)
    return control
end

---@class BUI.DropdownEntry
---@field value any
---@field label string

---@class BUI.DropdownOpts
---@field text string
---@field tooltip? string
---@field values BUI.DropdownEntry[]|fun(): BUI.DropdownEntry[]
---@field get fun(): any
---@field set fun(value: any)

--- Ligne « libellé + menu déroulant ».
---@param parent table
---@param opts BUI.DropdownOpts
---@return table row
function W.Dropdown(parent, opts)
    local row = W.Row(parent, opts.text)

    local canUseModern = T.Template("DROPDOWN") ~= nil
    local control = canUseModern and modernDropdown(row, opts) or cyclingButton(row, opts)

    row:EnableMouse(true)
    W.Tooltip(row, opts.text, opts.tooltip)
    W.Tooltip(control, opts.text, opts.tooltip)

    function row:Refresh()
        setButtonText(control, labelFor(valuesOf(opts), opts.get()))
    end

    row:Refresh()
    return row
end
