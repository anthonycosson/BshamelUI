-- =========================================================================
--  Bshamel UI — UI/Widgets/KeyTimer.lua
--  Chrono mythique+ : temps restant, paliers, comparatif.
--
--  Le client affiche déjà un chrono, et il ne dit que le temps restant. Ce qui
--  décide d'une clé, c'est autre chose : les deux **paliers** de bonus, et ce
--  qu'on avait mis la dernière fois. Ce panneau montre ces trois lignes-là.
--
--  Comme `W.Countdown` et comme le suivi des résurrections, le widget ne sait
--  pas d'où vient l'information : on lui donne une fonction qui rend un relevé,
--  il l'interroge dix fois par seconde et l'affiche. Elle rend `nil` quand il n'y
--  a pas de clé en cours, et le panneau se cache.
--
--  Les paliers ne sont pas un réglage : ce sont les fractions du chrono que le
--  jeu applique pour accorder un ou deux niveaux de plus. Elles vivent donc dans
--  ce fichier comme une donnée de jeu, à un seul endroit.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local U    = BUI.Util
local W    = BUI.Widgets

---@class BUI.KeyTimerData
---@field name string          nom du donjon
---@field level number         niveau de la clé
---@field elapsed number       secondes écoulées
---@field limit number         chrono du donjon, en secondes
---@field best? number         meilleur temps de la saison sur ce donjon
---@field bestLevel? number    niveau de ce meilleur temps
---@field done? boolean        la clé est terminée : le temps affiché est final

--- Fractions du chrono qui accordent des niveaux supplémentaires. Deux entrées,
--- de la plus dure à la plus facile — c'est l'ordre dans lequel on les perd.
local TIERS = {
    { bonus = 3, fraction = 0.6 },
    { bonus = 2, fraction = 0.8 },
}

--- Ligne « libellé à gauche, valeur à droite ».
---@param panel table
---@param offset number  ordonnée, négative
---@return table
local function newRow(panel, offset)
    local row = {}

    row.label = panel:CreateFontString(nil, "ARTWORK", T.FONT.LABEL_SMALL)
    row.label:SetPoint("TOPLEFT", panel, "TOPLEFT", T.SIZE.TOOL_PAD, offset)
    row.label:SetJustifyH("LEFT")

    row.value = panel:CreateFontString(nil, "ARTWORK", T.FONT.LABEL_SMALL)
    row.value:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -T.SIZE.TOOL_PAD, offset)
    row.value:SetJustifyH("RIGHT")

    return row
end

--- Chrono mythique+, masqué au départ.
---@param opts table  { getPos, setPos, source: fun(): BUI.KeyTimerData|nil, bestLabel: string }
---@return table
function W.KeyTimer(opts)
    local rows   = #TIERS + 1                       -- les paliers, plus le comparatif
    local height = T.SIZE.TOOL_PAD * 2
                   + T.SIZE.TOOL_TITLE_H            -- nom du donjon et niveau
                   + T.SIZE.ROW_H                   -- temps restant, en grand
                   + rows * T.SIZE.KEY_ROW_H

    local panel = W.Panel({
        width  = T.SIZE.KEY_TIMER_W,
        height = height,
        title  = "",
        getPos = opts.getPos,
        setPos = opts.setPos,
    })

    local clock = panel:CreateFontString(nil, "ARTWORK", T.FONT.KEY_TIMER)
    clock:SetPoint("TOP", panel, "TOP", 0, -(T.SIZE.TOOL_PAD + T.SIZE.TOOL_TITLE_H))
    panel.clock = clock

    local top = -(T.SIZE.TOOL_PAD + T.SIZE.TOOL_TITLE_H + T.SIZE.ROW_H)

    local tierRows = {}
    for i = 1, #TIERS do
        tierRows[i] = newRow(panel, top - (i - 1) * T.SIZE.KEY_ROW_H)
        tierRows[i].label:SetText("+" .. TIERS[i].bonus)
        tierRows[i].label:SetTextColor(T.COLOR.NORMAL:GetRGB())
    end

    local bestRow = newRow(panel, top - #TIERS * T.SIZE.KEY_ROW_H)
    bestRow.label:SetText(opts.bestLabel or "")
    bestRow.label:SetTextColor(T.COLOR.NORMAL:GetRGB())

    -- ---------------------------------------------------------------------
    --  Affichage
    -- ---------------------------------------------------------------------

    ---@param data BUI.KeyTimerData
    local function draw(data)
        panel:SetTitle(string.format("%s  +%d", data.name or "", data.level or 0))

        local remaining = (data.limit or 0) - (data.elapsed or 0)

        -- Au-delà du chrono, on affiche le dépassement précédé d'un plus : c'est
        -- ce qui se lit sur la fiche de résultat, et un « 0:00 » qui reste
        -- immobile ne dit pas depuis combien de temps la clé est perdue.
        if remaining >= 0 then
            clock:SetText(U.Clock(remaining))
        else
            clock:SetText("+" .. U.Clock(remaining))
        end

        local ratio = (data.limit and data.limit > 0) and (remaining / data.limit) or 0
        clock:SetTextColor(T.CountdownColor(ratio))

        for i = 1, #TIERS do
            local row  = tierRows[i]
            local left = (data.limit or 0) * TIERS[i].fraction - (data.elapsed or 0)

            if left > 0 then
                row.value:SetText(U.Clock(left))
                row.value:SetTextColor(T.COLOR.LABEL:GetRGB())
            else
                -- Le palier est passé : on montre de combien il a été manqué
                -- plutôt qu'un tiret. C'est l'information qu'on cherche à la fin
                -- d'une clé ratée de peu.
                row.value:SetText("+" .. U.Clock(left))
                row.value:SetTextColor(T.COLOR.RED:GetRGB())
            end
        end

        if not data.best then
            bestRow.value:SetText("")
            return
        end

        local text = U.Clock(data.best)
        if data.bestLevel and data.bestLevel > 0 then
            text = string.format("%s  +%d", text, data.bestLevel)
        end

        -- La clé est terminée : le comparatif devient un écart, signé, teinté du
        -- vert de ce qui est gagné ou du rouge de ce qui est perdu.
        if data.done then
            local delta = (data.elapsed or 0) - data.best
            local sign  = (delta <= 0) and "-" or "+"
            bestRow.value:SetFormattedText("%s  (%s%s)", text, sign, U.Clock(delta))
            bestRow.value:SetTextColor(T.StatusColor(delta <= 0))
            return
        end

        bestRow.value:SetText(text)
        bestRow.value:SetTextColor(T.COLOR.LABEL:GetRGB())
    end

    local function update()
        local data = opts.source and opts.source()
        if not data then
            panel:Hide()
            return
        end

        panel:Show()
        draw(data)
    end

    local tick = U.Throttle(T.TIMING.KEY_TIMER, update)

    function panel:Start()
        self:SetScript("OnUpdate", tick)
        update()
    end

    function panel:Stop()
        self:SetScript("OnUpdate", nil)
        self:Hide()
    end

    return panel
end
