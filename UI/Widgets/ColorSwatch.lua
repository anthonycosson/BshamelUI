-- =========================================================================
--  Bshamel UI — UI/Widgets/ColorSwatch.lua
--  Pastille de couleur : un aplat qu'on clique pour ouvrir le sélecteur du
--  client.
--
--  **On n'écrit pas de sélecteur de couleur.** Le client en a un, tout le monde
--  l'a déjà vu ailleurs, et il sait déjà faire la roue, les valeurs numériques
--  et l'historique des dernières teintes. Ce widget n'est donc qu'un aplat et le
--  geste qui ouvre le sien.
--
--  Le sélecteur du client a changé d'interface : on posait autrefois des champs
--  sur la frame avant de l'afficher, on lui passe aujourd'hui une table. Les
--  deux chemins sont essayés dans cet ordre — test de capacité, jamais de
--  numéro de patch (règle 1).
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local W    = BUI.Widgets

---@class BUI.ColorOpts
---@field text string
---@field tooltip? string
---@field indent? boolean  sous-option : en retrait, d'un corps plus petit
---@field get fun(): table    { r = , g = , b = }
---@field set fun(color: table)

--- Ouvre le sélecteur du client sur une couleur.
---
--- `restore` est rappelé si le joueur annule : le sélecteur du client applique
--- la couleur **au fil du geste**, ce qui est exactement ce qu'on veut — la
--- barre de nom change sous les yeux pendant qu'on tourne la roue — mais oblige
--- à savoir revenir en arrière.
---
--- Pas d'opacité : une barre de nom translucide n'est pas une couleur, c'est le
--- réglage d'opacité d'à côté. Deux chemins pour le même résultat rendraient
--- l'un des deux faux.
---@param color table            { r = , g = , b = }
---@param apply fun(r: number, g: number, b: number)
local function openPicker(color, apply)
    local picker = ColorPickerFrame
    if not picker then return end

    local restore = { r = color.r, g = color.g, b = color.b }

    local function onChange()
        apply(picker:GetColorRGB())
    end

    local function onCancel()
        apply(restore.r, restore.g, restore.b)
    end

    -- Chemin récent : tout se passe par la table, y compris l'affichage.
    if type(picker.SetupColorPickerAndShow) == "function" then
        picker:SetupColorPickerAndShow({
            r = color.r, g = color.g, b = color.b,
            hasOpacity   = false,
            swatchFunc   = onChange,
            cancelFunc   = onCancel,
        })
        return
    end

    -- Chemin ancien : les champs sont posés sur la frame, puis on l'affiche.
    picker.func       = onChange
    picker.swatchFunc = onChange
    picker.cancelFunc = onCancel
    picker.opacityFunc = nil
    picker.hasOpacity  = false
    picker:SetColorRGB(color.r, color.g, color.b)
    picker:Hide()   -- forcer un `OnShow`, sans quoi la couleur de départ colle
    picker:Show()
end

--- Ligne « libellé + pastille de couleur ».
---
---     W.ColorSwatch(parent, {
---         text = L["Boss"],
---         get  = function() return mod:Get("bossColor") end,
---         set  = function(c) mod:Set("bossColor", c) end,
---     })
---
---@param parent table
---@param opts BUI.ColorOpts
---@return table row
function W.ColorSwatch(parent, opts)
    local row = W.Row(parent, opts.text, opts.indent)

    local button = CreateFrame("Button", nil, row)
    button:SetSize(T.SIZE.SWATCH_W, T.SIZE.SWATCH_H)
    W.PlaceControl(row, button)

    -- Liseré sombre, puis l'aplat rentré d'un pixel : sans lui, une couleur
    -- sombre choisie par le joueur se fondrait dans le fond de la fenêtre et la
    -- pastille disparaîtrait au moment précis où il faut la retrouver.
    local edge = button:CreateTexture(nil, "BACKGROUND")
    edge:SetAllPoints()
    edge:SetColorTexture(T.COLOR.SHADE:GetRGB())

    local fill = button:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", T.SIZE.SWATCH_EDGE, -T.SIZE.SWATCH_EDGE)
    fill:SetPoint("BOTTOMRIGHT", -T.SIZE.SWATCH_EDGE, T.SIZE.SWATCH_EDGE)

    --- Peint la pastille. Ne touche pas à la base : c'est le seul endroit qui
    --- *montre*, et le sélecteur s'en sert aussi pendant le geste, avant que la
    --- couleur soit acquise.
    local function paint(r, g, b)
        fill:SetColorTexture(r, g, b)
    end

    local function current()
        local color = opts.get()
        if type(color) ~= "table" or type(color.r) ~= "number" then
            return { r = 1, g = 1, b = 1 }
        end
        return color
    end

    button:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        openPicker(current(), function(r, g, b)
            paint(r, g, b)
            opts.set({ r = r, g = g, b = b })
        end)
    end)

    row:EnableMouse(true)
    W.Tooltip(row, opts.text, opts.tooltip)
    W.Tooltip(button, opts.text, opts.tooltip)

    function row:Refresh()
        local color = current()
        paint(color.r, color.g, color.b)
    end

    row:Refresh()
    return row
end
