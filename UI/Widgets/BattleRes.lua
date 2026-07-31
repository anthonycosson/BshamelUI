-- =========================================================================
--  Bshamel UI — UI/Widgets/BattleRes.lua
--  Suivi des résurrections de combat.
--
--  Une icône, un compteur de charges, et le temps avant la charge suivante.
--  Comme `W.Countdown`, le widget ne sait pas d'où vient l'information : on lui
--  donne une fonction qui la rend, il l'interroge et l'affiche. Quand elle rend
--  `nil` — hors instance, hors groupe —, il se cache.
--
--  **L'icône est celle du client**, demandée au sort de résurrection lui-même :
--  c'est l'image que le joueur associe déjà à ce qu'on compte, et elle suit le
--  jeu quand il la retouche. On ne dessine donc rien qui ressemble à un sort,
--  on emprunte le sort.
--
--  Le mode sombre s'y applique comme sur une icône d'aura : l'icône est nue, il
--  n'y a aucun contour à teinter, donc on en pose un (`W.ShadeBorder`). C'est le
--  même vocabulaire que le reste de l'addon — une icône bordée de sombre —, et
--  c'est la seule façon d'assombrir une icône sans la rendre illisible.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local U    = BUI.Util
local W    = BUI.Widgets

---@class BUI.BattleResInfo
---@field charges number         charges disponibles
---@field maxCharges number
---@field remaining? number      secondes avant la charge suivante
---@field duration? number       durée pleine de cette recharge

--- Suivi des résurrections de combat, masqué au départ.
---@param opts table  { getPos, setPos, source: fun(): BUI.BattleResInfo|nil }
---@return table
function W.BattleResTracker(opts)
    local panel = W.Panel({
        width  = T.SIZE.BATTLE_RES_ICON + T.SIZE.TOOL_PAD * 2,
        height = T.SIZE.BATTLE_RES_ICON + T.SIZE.TOOL_PAD * 2 + T.SIZE.KEY_ROW_H,
        getPos = opts.getPos,
        setPos = opts.setPos,
    })

    local icon = panel:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOP", panel, "TOP", 0, -T.SIZE.TOOL_PAD)
    icon:SetSize(T.SIZE.BATTLE_RES_ICON, T.SIZE.BATTLE_RES_ICON)
    panel.icon = icon

    -- Le nombre de charges est posé **sur** l'icône, dans son coin : c'est la
    -- valeur qu'on lit d'un coup d'œil, et la sortir de l'icône la ferait
    -- disputer la place au temps restant.
    local count = panel:CreateFontString(nil, "OVERLAY", T.FONT.SLOT_BADGE)
    count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0)
    count:SetJustifyH("RIGHT")
    panel.count = count

    local timer = panel:CreateFontString(nil, "ARTWORK", T.FONT.LABEL_SMALL)
    timer:SetPoint("BOTTOM", panel, "BOTTOM", 0, T.SIZE.TOOL_PAD / 2)
    timer:SetJustifyH("CENTER")
    panel.timer = timer

    local border = W.ShadeBorder(icon)

    -- ---------------------------------------------------------------------
    --  Rafraîchissement
    -- ---------------------------------------------------------------------

    local function update()
        local info = opts.source and opts.source()
        if not info then
            panel:Hide()
            return
        end

        panel:Show()

        count:SetText(tostring(info.charges or 0))
        count:SetTextColor(T.StatusColor((info.charges or 0) > 0))

        local remaining = info.remaining
        if not remaining or remaining <= 0 then
            timer:SetText("")
            return
        end

        local minutes = math.floor(remaining / 60)
        local seconds = math.floor(remaining % 60)
        timer:SetFormattedText("%d:%02d", minutes, seconds)

        -- Sans durée pleine, le temps restant garde la couleur d'échéance : un
        -- rouge constant vaut mieux qu'un dégradé qui ne mesure rien.
        local total = info.duration
        local ratio = (total and total > 0) and (1 - remaining / total) or 0
        timer:SetTextColor(T.CountdownColor(ratio))
    end

    local tick = U.Throttle(T.TIMING.BATTLE_RES, update)

    --- Branche le suivi sur sa source et l'allume.
    function panel:Start()
        self:SetScript("OnUpdate", tick)
        update()
    end

    --- Éteint le suivi. La position, la taille et le contour restent tels quels :
    --- rallumer ne redemande rien.
    function panel:Stop()
        self:SetScript("OnUpdate", nil)
        self:Hide()
    end

    --- Côté de l'icône, en pixels. Le panneau se remesure autour d'elle.
    ---@param side number
    function panel:SetIconSize(side)
        side = U.Clamp(side or T.SIZE.BATTLE_RES_ICON, T.SIZE.BATTLE_RES_MIN, T.SIZE.BATTLE_RES_MAX)
        icon:SetSize(side, side)
        self:SetSize(side + T.SIZE.TOOL_PAD * 2,
                     side + T.SIZE.TOOL_PAD * 2 + T.SIZE.KEY_ROW_H)

        -- Le débordement du contour est proportionnel à l'icône : il se retrace
        -- après chaque changement de taille, sinon l'anneau reste calé sur
        -- l'ancienne (voir `T.ShadeBorderPad`).
        if border and self._shaded then border:Draw(T.SHADE_FACTOR) end
    end

    --- Image de l'icône. C'est l'appelant qui sait quel sort compte ici.
    ---@param texture number|string
    function panel:SetIcon(texture)
        icon:SetTexture(texture)
    end

    --- Mode sombre : l'icône reçoit le contour commun de l'addon, ou le perd.
    ---@param on boolean
    function panel:SetShaded(on)
        self._shaded = on and true or false
        if not border then return end
        if on then border:Draw(T.SHADE_FACTOR) else border.Hide() end
    end

    panel:SetShaded(false)
    return panel
end
