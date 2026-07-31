-- =========================================================================
--  Bshamel UI — UI/Widgets/Panel.lua
--  Petit panneau posé à même l'écran, déplaçable à la souris.
--
--  Quatre pièces de l'addon vivent en dehors de la fenêtre d'options : le suivi
--  des résurrections de combat, la barre de marqueurs, le chrono mythique+ et le
--  rappel de file. Elles ont toutes le même besoin — un fond, une bordure, un
--  titre facultatif, et une position que le joueur pose une fois pour toutes.
--  Écrire quatre fois ce socle donnerait quatre marges et quatre façons de
--  retenir une position ; il vit donc ici, et chaque pièce n'écrit que ce qui la
--  distingue.
--
--  **Une position est un décalage de centre à centre**, jamais un ancrage. C'est
--  la même règle que pour les fenêtres du client (voir `UI/Move.lua` et
--  `dev/docs/API_NOTES.md`) : le panneau se repose toujours en `CENTER`/`CENTER`,
--  ce qui reste juste quel que soit son contenu — un panneau qui grandit vers le
--  bas ne se déplace pas parce qu'une ligne s'y est ajoutée.
--
--  Le panneau ne connaît pas la base de données : l'appelant lui donne deux
--  fonctions, `getPos` et `setPos`, et c'est le module qui décide où la position
--  est rangée.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local W    = BUI.Widgets

---@class BUI.PanelOpts
---@field width number
---@field height number
---@field title? string
---@field strata? string
---@field getPos? fun(): number, number   décalage du centre, en pixels d'écran
---@field setPos? fun(x: number, y: number)

--- Panneau autonome, masqué au départ.
---@param opts BUI.PanelOpts
---@return table
function W.Panel(opts)
    local panel = CreateFrame("Frame", nil, UIParent)
    panel:SetSize(opts.width, opts.height)
    panel:SetFrameStrata(opts.strata or "MEDIUM")
    panel:SetClampedToScreen(true)
    panel:Hide()

    -- Même fond que la fenêtre d'options et que le tiroir de la minicarte : ces
    -- panneaux sont de petites fenêtres de l'addon, ils se lisent comme le reste.
    local background = panel:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    T.WindowSurface(background)
    panel.background = background

    local border = W.Inset(panel)
    border:SetAllPoints()

    if opts.title then
        local title = panel:CreateFontString(nil, "ARTWORK", T.FONT.SECTION)
        title:SetPoint("TOPLEFT", panel, "TOPLEFT", T.SIZE.TOOL_PAD, -T.SIZE.TOOL_PAD)
        title:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -T.SIZE.TOOL_PAD, -T.SIZE.TOOL_PAD)
        title:SetJustifyH("LEFT")
        title:SetWordWrap(false)
        title:SetTextColor(T.COLOR.NORMAL:GetRGB())
        title:SetText(opts.title)
        panel.title = title
    end

    --- Change le titre. Sans titre déclaré à la construction, sans effet : un
    --- panneau qui n'en avait pas n'a pas réservé la hauteur pour en porter un.
    ---@param text string
    function panel:SetTitle(text)
        if self.title then self.title:SetText(text or "") end
    end

    -- ---------------------------------------------------------------------
    --  Position
    -- ---------------------------------------------------------------------

    --- Repose le panneau à la position que l'appelant a rangée.
    function panel:ApplyPosition()
        local x, y = 0, 0
        if opts.getPos then x, y = opts.getPos() end

        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "CENTER", x or 0, y or 0)
    end

    --- Relève la position courante et la rend à l'appelant, en décalage de
    --- centre à centre et en pixels d'écran.
    local function savePosition()
        if not opts.setPos then return end

        local x, y   = panel:GetCenter()
        local px, py = UIParent:GetCenter()
        if not (x and px) then return end

        -- Les deux centres sont exprimés chacun dans l'échelle de son cadre : on
        -- les ramène en pixels d'écran avant de les soustraire, sinon un panneau
        -- mis à l'échelle par le joueur se décale de la différence.
        local scale  = panel:GetEffectiveScale()
        local parent = UIParent:GetEffectiveScale()

        opts.setPos((x * scale - px * parent) / parent,
                    (y * scale - py * parent) / parent)
    end

    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        savePosition()
        -- Reposé tout de suite en centre à centre : `StartMoving` laisse le
        -- cadre ancré par le coin que le moteur a choisi, et un ancrage par un
        -- coin ferait glisser le panneau dès que son contenu change de taille.
        self:ApplyPosition()
    end)

    panel:ApplyPosition()
    return panel
end
