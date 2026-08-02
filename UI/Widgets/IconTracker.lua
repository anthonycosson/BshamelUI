-- =========================================================================
--  Bshamel UI — UI/Widgets/IconTracker.lua
--  Une icône de sort, un compteur, un décompte.
--
--  **Une icône de sort, et rien autour.** Le compteur se pose dans son coin, le
--  temps restant en son milieu — exactement comme le client habille un bouton
--  d'action. Un cadre, un fond, un panneau : c'est ce que le jeu ne met jamais
--  autour d'une icône, et c'est ce qui faisait ressembler ce suivi à une pièce
--  rapportée.
--
--  Deux suivis s'en servent : les **résurrections de combat**, qui ont un
--  compteur de charges et un temps avant la suivante, et le **débuff de
--  Bloodlust**, qui n'a qu'un temps. Le compteur se tait de lui-même quand la
--  source n'en donne pas — c'est ce qui permet au widget de servir les deux sans
--  rien savoir de ce qu'il compte.
--
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

---@class BUI.TrackerInfo
---@field charges? number        compteur du coin ; absent, le coin reste vide
---@field maxCharges? number
---@field remaining? number      secondes restantes, affichées au centre
---@field duration? number       durée pleine

--- Suivi posé sur une icône de sort, masqué au départ.
---@param opts table  { getPos, setPos, isLocked, source: fun(): BUI.TrackerInfo|nil }
---@return table
function W.IconTracker(opts)
    -- Le panneau **est** l'icône : mêmes bords, aucune marge. Il ne sert plus
    -- qu'à ce que `W.Panel` sait faire et qu'une texture ne sait pas — prendre la
    -- souris, se déplacer, retenir sa position.
    local panel = W.Panel({
        width    = T.SIZE.TRACKER_ICON,
        height   = T.SIZE.TRACKER_ICON,
        chrome   = "none",
        getPos   = opts.getPos,
        setPos   = opts.setPos,
        isLocked = opts.isLocked,
    })

    local icon = panel:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    panel.icon = icon

    -- Le compteur est posé **sur** l'icône, dans son coin : c'est la valeur
    -- qu'on lit d'un coup d'œil, et c'est là que le jeu met déjà le nombre de
    -- charges d'un sort. Un suivi qui n'a rien à compter le laisse vide.
    local count = panel:CreateFontString(nil, "OVERLAY", T.FONT.TRACKER)
    count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0)
    count:SetJustifyH("RIGHT")
    panel.count = count

    -- Le temps restant au milieu, là encore comme un temps de recharge de barre
    -- d'action. Il ne s'affiche que lorsqu'il y en a un : une réserve pleine ne
    -- porte aucun nombre au centre.
    --
    -- **Blanc, et d'une seule couleur.** Ce qui alerte ici est le nombre de
    -- charges, pas le temps qui reste : une réserve vide est un problème dès la
    -- première seconde, et un chiffre qui vire au rouge en fin de recharge dirait
    -- l'inverse — que le danger arrive quand la charge, elle, approche.
    local timer = panel:CreateFontString(nil, "OVERLAY", T.FONT.TRACKER)
    timer:SetPoint("CENTER", icon, "CENTER", 0, 0)
    timer:SetJustifyH("CENTER")
    timer:SetTextColor(T.COLOR.LABEL:GetRGB())
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

        -- `nil` et non zéro : un suivi sans compteur — le débuff de Bloodlust —
        -- ne doit pas afficher « 0 » dans le coin de son icône, ce qui se lirait
        -- comme une réserve vide.
        if info.charges then
            count:SetText(tostring(info.charges))
            count:SetTextColor(T.StatusColor(info.charges > 0))
        else
            count:SetText("")
        end

        local remaining = info.remaining
        if not remaining or remaining <= 0 then
            timer:SetText("")
            return
        end

        local minutes = math.floor(remaining / 60)
        local seconds = math.floor(remaining % 60)
        timer:SetFormattedText("%d:%02d", minutes, seconds)
    end

    local tick = U.Throttle(T.TIMING.TRACKER, update)

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

    --- Côté de l'icône, en pixels.
    ---@param side number
    function panel:SetIconSize(side)
        side = U.Clamp(side or T.SIZE.TRACKER_ICON, T.SIZE.TRACKER_MIN, T.SIZE.TRACKER_MAX)
        self:SetSize(side, side)

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
