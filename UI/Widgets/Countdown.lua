-- =========================================================================
--  Bshamel UI — UI/Widgets/Countdown.lua
--  Décompte affiché par-dessus une fenêtre du client.
--
--  Le widget ne sait pas ce qu'il décompte : on lui donne une fonction qui rend
--  les secondes restantes, il l'interroge et l'affiche. Quand elle rend `nil`,
--  il s'arrête. C'est ce qui permet de coiffer aussi bien une fenêtre de
--  proposition de donjon (échéance déduite) qu'une invitation de champ de
--  bataille (échéance donnée par le client) avec le même objet.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local U    = BUI.Util
local W    = BUI.Widgets

--- Texte de décompte, ancré par l'appelant.
---@param parent table
---@return table
function W.Countdown(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(T.SIZE.ROW_H, T.SIZE.ROW_H)

    local text = frame:CreateFontString(nil, "OVERLAY", T.FONT.COUNTDOWN)
    text:SetPoint("CENTER")
    frame.text = text

    local function update()
        local remaining = frame._source and frame._source()
        if not remaining then
            frame:Stop()
            return
        end

        if remaining < 0 then remaining = 0 end
        text:SetFormattedText("%d", math.floor(remaining + 0.5))

        -- Sans durée totale, le décompte reste à la couleur d'échéance : mieux
        -- vaut un rouge constant qu'un vert qui ne voudrait rien dire.
        local total = frame._total
        local ratio = (total and total > 0) and (remaining / total) or 0
        text:SetTextColor(T.CountdownColor(ratio))
    end

    -- Le décompte s'affiche à la seconde : le rafraîchir à chaque image serait
    -- payer soixante fois le même texte (CLAUDE.md règle 7).
    local tick = U.Throttle(T.TIMING.COUNTDOWN, update)

    --- Branche le décompte sur une source de secondes restantes.
    ---@param source fun(): number|nil
    ---@param total? number  durée pleine, qui donne sa couleur au décompte
    function frame:Watch(source, total)
        self._source = source
        self._total  = total
        self:SetScript("OnUpdate", tick)
        self:Show()
        update()
    end

    function frame:Stop()
        self:SetScript("OnUpdate", nil)
        self._source = nil
        self._total  = nil
        self:Hide()
    end

    -- La fenêtre coiffée disparaît : le décompte n'a plus rien à compter.
    frame:SetScript("OnHide", function(self) self:Stop() end)

    frame:Hide()
    return frame
end
