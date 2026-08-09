-- =========================================================================
--  Bshamel UI — UI/Widgets/BarText.lua
--  Deux textes posés sur une barre de statut du client : la valeur et le
--  pourcentage, chacun à son ancrage.
--
--  Le widget ne sait pas ce qu'il écrit : le module lui donne des chaînes
--  toutes faites, lui sait où les poser — bord gauche, centre, bord droit — et
--  avec quelle police. C'est le partage habituel de la fabrique : le module
--  décrit, le widget dessine (CLAUDE.md règle 2).
--
--  L'objet rendu est un cadre qui recouvre la barre : il suit donc sa taille et
--  sa visibilité sans rien écouter — une barre que le client cache emporte ses
--  textes avec elle.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local W    = BUI.Widgets

--- Ancrages admis. Toute autre valeur retombe sur le centre : un réglage
--- inconnu doit dégrader vers quelque chose de visible, jamais lever.
local SPOTS = {
    LEFT   = { point = "LEFT",   sign =  1, justify = "LEFT"   },
    CENTER = { point = "CENTER", sign =  0, justify = "CENTER" },
    RIGHT  = { point = "RIGHT",  sign = -1, justify = "RIGHT"  },
}

---@param text table  FontString
---@param anchor string
local function place(text, anchor)
    local spot = SPOTS[anchor] or SPOTS.CENTER
    text:ClearAllPoints()
    text:SetPoint(spot.point, spot.sign * T.SIZE.BAR_TEXT_PAD, 0)
    text:SetJustifyH(spot.justify)
end

--- Textes posés sur une barre de statut du client.
---@param bar table
---@return table|nil
function W.BarText(bar)
    if type(bar) ~= "table" or type(bar.GetFrameLevel) ~= "function" then
        return nil
    end

    local overlay = CreateFrame("Frame", nil, bar)
    overlay:SetAllPoints(bar)
    -- Au-dessus des textes du client : les nôtres les remplacent, ils ne
    -- doivent pas se battre avec eux pour l'avant-plan.
    overlay:SetFrameLevel(bar:GetFrameLevel() + T.SIZE.BAR_TEXT_LEVEL)

    local value   = overlay:CreateFontString(nil, "OVERLAY", T.FONT.BAR_TEXT)
    local percent = overlay:CreateFontString(nil, "OVERLAY", T.FONT.BAR_TEXT)
    value:SetPoint("RIGHT", -T.SIZE.BAR_TEXT_PAD, 0)
    percent:SetPoint("LEFT", T.SIZE.BAR_TEXT_PAD, 0)

    ---@param valueAnchor string    "LEFT" | "CENTER" | "RIGHT"
    ---@param percentAnchor string  idem
    function overlay:SetAnchors(valueAnchor, percentAnchor)
        place(value, valueAnchor)
        place(percent, percentAnchor)
    end

    -- Sous `pcall`, parce que ce qui arrive ici peut être **secret** : la vie
    -- du joueur en est un, le module la passe telle quelle, et `SetText`
    -- l'affiche. Si une écriture est refusée quand même, le texte s'efface au
    -- lieu de lever — une barre muette plutôt qu'une erreur.
    ---@param text any  chaîne, nombre ou secret
    function overlay:SetValue(text)
        if not pcall(value.SetText, value, text) then
            value:SetText("")
        end
    end

    -- Le pourcentage arrive en **nombre brut**, éventuellement secret : aucune
    -- arithmétique n'est permise sur lui, pas même l'arrondi. C'est le format
    -- qui arrondit — `%.0f` — et `SetFormattedText` qui accepte le secret.
    ---@param raw any  nombre 0..100, éventuellement secret, ou nil pour taire
    function overlay:SetPercent(raw)
        if type(raw) == "nil" then
            percent:SetText("")
            return
        end
        if not pcall(percent.SetFormattedText, percent, "%.0f%%", raw) then
            percent:SetText("")
        end
    end

    -- Le corps se change par `T.SetTextSize`, qui relit la police posée au
    -- lieu d'en nommer une : le texte reste celui du client, en plus grand ou
    -- plus petit.
    ---@param size number
    function overlay:SetTextSize(size)
        T.SetTextSize(value, size)
        T.SetTextSize(percent, size)
    end

    overlay:Hide()
    return overlay
end
