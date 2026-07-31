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
local U    = BUI.Util
local W    = BUI.Widgets

---@class BUI.PanelOpts
---@field width number
---@field height number
---@field title? string
---@field strata? string
---@field chrome? string                  "inset" (défaut), "dialog" ou "none"
---@field getPos? fun(): number, number   décalage du centre, en pixels d'écran
---@field setPos? fun(x: number, y: number)
---@field isLocked? fun(): boolean        gèle la position et retire la poignée
---@field minScale? number                donne une poignée d'échelle
---@field maxScale? number
---@field getScale? fun(): number|nil
---@field setScale? fun(scale: number)
---@field canScale? fun(): boolean        refuse la poignée quand elle rendrait faux

--- Panneau autonome, masqué au départ.
---@param opts BUI.PanelOpts
---@return table
function W.Panel(opts)
    local panel = CreateFrame("Frame", nil, UIParent)
    panel:SetSize(opts.width, opts.height)
    panel:SetFrameStrata(opts.strata or "MEDIUM")
    panel:SetClampedToScreen(true)
    panel:Hide()

    -- **Trois habillages, un seul socle.** Un panneau qui affiche un nombre est un
    -- creux posé sur l'écran ; un panneau dont on clique les pièces porte le
    -- contour ouvragé des dialogues du client ; et un panneau qui n'est **qu'une
    -- icône** n'a rien du tout — un cadre autour d'une icône de sort en ferait
    -- une pièce rapportée là où le jeu n'en met jamais. Aucun des trois n'apporte
    -- de barre de titre : ces panneaux tiennent en une rangée, et une bande vide
    -- au-dessus n'aurait fait que les allonger.
    --
    -- Le fond est la **pierre** de la fenêtre d'options, pas un aplat : c'est ce
    -- qui fait son noir profond, la couleur y multipliant une matière déjà sombre
    -- au lieu de se poser telle quelle (voir `T.WindowStone`).
    local chrome = opts.chrome or "inset"

    if chrome ~= "none" then
        local background = panel:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        T.WindowStone(background)
        panel.background = background

        local border = (chrome == "dialog") and W.DialogBorder(panel) or W.Inset(panel)
        border:SetAllPoints()
    end

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
    ---
    --- **Le décalage d'un ancrage s'exprime dans l'échelle du cadre ancré**, pas
    --- dans celle de son point d'accrochage : à l'échelle double, un décalage de
    --- cent vaut deux cents pixels d'écran. La position rangée, elle, est en
    --- unités de `UIParent` — c'est la seule qui reste vraie quand l'échelle
    --- change. On la convertit donc ici, et un panneau agrandi grandit autour de
    --- son centre au lieu de partir en diagonale.
    function panel:ApplyPosition()
        local x, y = 0, 0
        if opts.getPos then x, y = opts.getPos() end

        local factor = UIParent:GetEffectiveScale() / self:GetEffectiveScale()

        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "CENTER", (x or 0) * factor, (y or 0) * factor)
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

    ---@return boolean
    local function locked()
        return opts.isLocked ~= nil and opts.isLocked() == true
    end

    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function(self)
        -- Verrouillé, le panneau ne bouge pas d'un pixel : c'est tout l'intérêt
        -- du réglage. On refuse le geste plutôt que de reposer le panneau après
        -- coup, ce qui le ferait sauter sous le curseur.
        if locked() then return end
        self:StartMoving()
    end)
    panel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        savePosition()
        -- Reposé tout de suite en centre à centre : `StartMoving` laisse le
        -- cadre ancré par le coin que le moteur a choisi, et un ancrage par un
        -- coin ferait glisser le panneau dès que son contenu change de taille.
        self:ApplyPosition()
    end)

    -- ---------------------------------------------------------------------
    --  Échelle
    -- ---------------------------------------------------------------------
    -- La disposition d'un panneau est arrêtée à sa construction ; ce que le
    -- joueur règle, c'est de quelle **taille** il la voit. L'échelle emporte
    -- tout d'un coup — vignettes, libellés, bordure —, là où retailler le cadre
    -- aurait laissé les textes au corps où ils sont.

    ---@param scale number
    ---@return number
    local function clampScale(scale)
        if opts.minScale and scale < opts.minScale then return opts.minScale end
        if opts.maxScale and scale > opts.maxScale then return opts.maxScale end
        return scale
    end

    if opts.minScale and opts.maxScale and opts.setScale then
        W.ScaleGrip(panel, {
            min      = opts.minScale,
            max      = opts.maxScale,
            setScale = opts.setScale,
            -- Pendant le geste, le panneau se repose à chaque cran : sans cela
            -- il grandirait à partir du coin que l'ancrage lui donne à l'échelle
            -- courante, et glisserait sous le curseur au lieu de gonfler sur
            -- place.
            onScale  = function() panel:ApplyPosition() end,
            allow    = function()
                if locked() then return false end
                return opts.canScale == nil or opts.canScale() == true
            end,
        })
    end

    --- Repose l'échelle que l'appelant a rangée, et la position avec elle : la
    --- seconde se convertit dans la première (voir `ApplyPosition`).
    function panel:ApplyScale()
        if not opts.getScale then return end
        self:SetScale(clampScale(opts.getScale() or 1))
        self:ApplyPosition()
    end

    --- Gèle ou libère la position. Le panneau reste utilisable : verrouiller
    --- range la prise, pas les boutons.
    function panel:ApplyLock()
        if not self.ResizeGrip then return end
        self.ResizeGrip:SetShown(not locked())
    end

    -- ---------------------------------------------------------------------
    --  Effacement au repos
    -- ---------------------------------------------------------------------
    -- Un panneau d'outils sert par intermittence : entre deux pulls il n'a rien
    -- à dire et occupe pourtant sa place. L'effacer tant que le curseur n'est
    -- pas dessus le rend invisible sans le rendre inaccessible — il garde sa
    -- souris, c'est le survol qui le rallume.
    --
    -- **Sondage plutôt qu'`OnEnter`/`OnLeave`.** Le curseur qui passe de la marge
    -- à un bouton *sort* du panneau au sens du client : le panneau s'éteindrait
    -- sous la main qui va cliquer. `IsMouseOver` répond pour le cadre **et** ce
    -- qu'il contient. Bridé, comme tout `OnUpdate` (règle 7), et un cadre caché
    -- n'en reçoit pas — au repos complet il ne coûte rien.

    local watch = U.Throttle(T.TIMING.HOVER, function()
        panel:SetAlpha(panel:IsMouseOver() and 1 or 0)
    end)

    --- Efface le panneau tant que le curseur n'est pas dessus.
    ---@param enabled boolean
    function panel:SetRevealOnHover(enabled)
        if not enabled then
            self:SetScript("OnUpdate", nil)
            self:SetAlpha(1)
            return
        end

        self:SetScript("OnUpdate", watch)
        -- Tout de suite, et pas au prochain passage : le réglage vient d'être
        -- coché, le panneau doit s'effacer sous les yeux de qui l'a coché.
        self:SetAlpha(self:IsMouseOver() and 1 or 0)
    end

    panel:ApplyPosition()
    panel:ApplyLock()
    return panel
end
