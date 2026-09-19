-- =========================================================================
--  Bshamel UI — UI/Widgets/BuffList.lua
--  Une liste de buffs posée à même l'écran : un nom par ligne, en vert quand
--  on l'a, en blanc quand il manque.
--
--  Le widget ne sait rien des buffs : l'appelant lui donne des lignes toutes
--  faites — un texte, un état, une infobulle — et il les écrit. C'est le
--  partage habituel : `Modules/BuffTracker.lua` sait quoi suivre et d'où ça
--  vient, ce fichier sait l'afficher.
--
--  Les lignes se construisent une fois et se réutilisent (règle 7) : une
--  frame ne se détruit pas, une ligne en trop se cache.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local U    = BUI.Util
local W    = BUI.Widgets

---@class BUI.BuffLine
---@field text string
---@field active boolean
---@field tipTitle? string
---@field tip? string

--- Panneau de suivi, masqué au départ.
---@param opts table  { title, getPos, setPos, isLocked }
---@return table
function W.BuffList(opts)
    local S   = T.SIZE
    local pad = S.TOOL_PAD

    local panel = W.Panel({
        width    = S.BUFF_PANEL_W,
        height   = pad * 2 + S.BUFF_ROW_H,
        title    = opts.title,
        getPos   = opts.getPos,
        setPos   = opts.setPos,
        isLocked = opts.isLocked,
    })

    -- Le titre occupe une ligne en tête ; la liste commence dessous.
    local top = pad + (panel.title and S.BUFF_ROW_H or 0)

    local rows = {}

    ---@param index integer
    ---@return table
    local function rowAt(index)
        local row = rows[index]
        if row then return row end

        -- Une frame par ligne, et non une simple chaîne : c'est elle qui
        -- prend la souris, pour l'infobulle qui dit d'où vient le buff.
        row = CreateFrame("Frame", nil, panel)
        row:SetHeight(S.BUFF_ROW_H)
        row:SetPoint("TOPLEFT", panel, "TOPLEFT", pad, -(top + (index - 1) * S.BUFF_ROW_H))
        row:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -pad, -(top + (index - 1) * S.BUFF_ROW_H))
        row:EnableMouse(true)

        local text = row:CreateFontString(nil, "ARTWORK", T.FONT.LABEL_SMALL)
        text:SetAllPoints(row)
        text:SetJustifyH("LEFT")
        text:SetWordWrap(false)
        row.text = text

        -- Le panneau se déplace en le tirant : une ligne qui prend la souris
        -- ne doit pas lui voler le geste.
        row:SetScript("OnMouseDown", function(_, button)
            local onDown = panel:GetScript("OnDragStart")
            if button == "LeftButton" and onDown then onDown(panel) end
        end)
        row:SetScript("OnMouseUp", function()
            local onUp = panel:GetScript("OnDragStop")
            if onUp then onUp(panel) end
        end)

        rows[index] = row
        return row
    end

    --- Écrit la liste. Une liste vide cache le panneau : il n'a rien à dire.
    ---@param lines BUI.BuffLine[]
    function panel:SetLines(lines)
        -- Le panneau s'élargit à la plus longue ligne : une ligne porte le buff
        -- **et** ce qui le remplace, et tronquée elle perdrait justement la fin.
        local widest = 0

        for i = 1, #lines do
            local line = lines[i]
            local row  = rowAt(i)
            local color = line.active and T.COLOR.GREEN or T.COLOR.WHITE

            row.text:SetText(line.text)
            row.text:SetTextColor(color:GetRGB())
            W.Tooltip(row, line.tipTitle, line.tip)
            row:Show()

            local width = row.text:GetUnboundedStringWidth()
            if type(width) == "number" and not U.IsSecret(width) and width > widest then
                widest = width
            end
        end
        for i = #lines + 1, #rows do
            rows[i]:Hide()
        end

        self:SetWidth(math.max(S.BUFF_PANEL_W, math.ceil(widest) + pad * 2))
        self:SetHeight(top + #lines * S.BUFF_ROW_H + pad)
    end

    return panel
end
