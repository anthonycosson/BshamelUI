-- =========================================================================
--  Bshamel UI — UI/Widgets/MarkerBar.lua
--  Panneau d'outils de groupe : marqueurs au sol, retrait des marqueurs,
--  vérification de présence, pull.
--
--  **Poser un marqueur au sol est une action protégée.** Le client refuse
--  `PlaceRaidMarker` depuis du code Lua ordinaire, exactement comme il refuse de
--  lancer un sort : la seule voie est un bouton bâti sur son template sécurisé,
--  à qui l'on décrit l'action par des attributs (`type = "worldmarker"`,
--  `marker`, `action`). Le clic part alors du moteur, pas de nous.
--
--  Conséquences, les mêmes que pour le menu de téléportation
--  (`UI/Widgets/SecureMenu.lua`) : les attributs sont écrits **une fois**, à la
--  construction — un bouton de marqueur porte le même numéro toute sa vie —, et
--  le panneau ne se montre ni ne se cache en combat. D'où `SetShownOutOfCombat`,
--  qui diffère ce que le client refuse au lieu de laisser l'appelant croire
--  qu'il a agi.
--
--  La vérification de présence et le pull, eux, ne sont pas protégés : ce sont
--  des boutons ordinaires, et c'est l'appelant qui décide ce qu'ils font.
--
--  **La disposition est fixe, seule l'échelle se règle.** Neuf cases sur une
--  rangée, deux boutons sous elles : ces proportions sont arrêtées ici, et la
--  poignée ne fait que dire de quelle taille on les regarde. Un panneau qu'on
--  retaillait laissait ses libellés au corps où ils étaient pendant que ses
--  vignettes grossissaient ; l'échelle emporte tout d'un coup. C'est aussi ce
--  qui la rend inoffensive au milieu de boutons sécurisés : rien n'est mesuré ni
--  réancré sur eux.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local W    = BUI.Widgets

--- Nombre de marqueurs au sol. Huit depuis toujours, comme les icônes de
--- ciblage dont ils empruntent les vignettes.
local MARKER_COUNT = 8

--- Cases de la rangée : les huit marqueurs, plus le retrait de tous.
local CELL_COUNT = MARKER_COUNT + 1

--- Largeur de la rangée de cases, et donc du contenu du panneau.
local INNER_W = CELL_COUNT * T.SIZE.MARKER_CELL + (CELL_COUNT - 1) * T.SIZE.MARKER_GAP

--- Largeur du panneau, marges comprises.
local PANEL_W = INNER_W + T.SIZE.TOOL_PAD * 2

--- Les deux boutons du bas se partagent la rangée **moins la place de la
--- poignée** : elle vit dans le même coin et se dessine au-dessus. Sans ce
--- retrait, le dernier centimètre du bouton de pull changerait l'échelle du
--- panneau au lieu de lancer le décompte.
local BUTTON_W = (INNER_W - T.SIZE.GRIP - T.SIZE.MARKER_GAP) / 2

--- Une case de marqueur : un bouton sécurisé qui porte sa vignette.
---@param panel table
---@param index number|nil  numéro du marqueur au sol, ou `nil` pour « tout effacer »
---@return table|nil
local function newMarkerButton(panel, index)
    local template = T.Template("SECURE_ACTION")
    if not template then return nil end

    local button = CreateFrame("Button", nil, panel, template)
    button:SetSize(T.SIZE.MARKER_CELL, T.SIZE.MARKER_CELL)

    -- Même précaution que dans le menu de téléportation : le clic est pris au
    -- relâchement seulement, sans quoi la CVar « lancer à l'enfoncement » ferait
    -- partir l'action deux fois.
    button:RegisterForClicks("AnyUp")
    button:SetAttribute("useOnKeyDown", false)

    button:SetAttribute("type", "worldmarker")
    button:SetAttribute("marker", index or 0)
    button:SetAttribute("action", index and "set" or "clear")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()

    if index then
        icon:SetTexture(T.TEXTURE.RAID_MARKERS)
        icon:SetTexCoord(T.RaidMarkerCoords(T.WORLD_MARKER_ICON[index] or index))
    else
        -- Le rond barré du passage sur un butin : le signe de refus du jeu. Une
        -- croix aurait été l'icône de ciblage n° 7, posée juste à côté de sa
        -- propre case — on aurait lu « poser la croix », pas « tout retirer ».
        icon:SetTexture(T.TEXTURE.LOOT_PASS)
    end

    button.Highlight = W.CenterGlow(button, T.COLOR.WHITE, T.ALPHA.ROW_HOVER)
    button:SetScript("OnEnter", function(self) self.Highlight:SetShown(true) end)
    button:SetScript("OnLeave", function(self) self.Highlight:SetShown(false) end)

    return button
end

--- Panneau d'outils de groupe, masqué au départ.
---@param opts table  { getPos, setPos, getScale, setScale, isLocked, libellés, onReadyCheck, onPull }
---@return table
function W.MarkerBar(opts)
    local panel = W.Panel({
        width  = PANEL_W,
        -- Hauteur provisoire : la rangée de boutons tient sa taille du thème par
        -- l'intermédiaire de `W.Button`, on la relève donc sur le bouton une fois
        -- construit plutôt que de réécrire ici la formule qui l'a produite.
        height = PANEL_W,
        chrome = "dialog",

        getPos   = opts.getPos,
        setPos   = opts.setPos,
        isLocked = opts.isLocked,

        getScale  = opts.getScale,
        setScale  = opts.setScale,
        minScale  = T.SIZE.MARKER_SCALE_MIN,
        maxScale  = T.SIZE.MARKER_SCALE_MAX,
        canScale  = function() return not InCombatLockdown() end,
    })

    -- ---------------------------------------------------------------------
    --  Rangée des marqueurs
    -- ---------------------------------------------------------------------

    local step = T.SIZE.MARKER_CELL + T.SIZE.MARKER_GAP
    local top  = -T.SIZE.TOOL_PAD
    local placed = 0

    ---@param button table
    local function placeCell(button)
        button:SetPoint("TOPLEFT", panel, "TOPLEFT",
            T.SIZE.TOOL_PAD + placed * step, top)
        placed = placed + 1
    end

    for i = 1, MARKER_COUNT do
        local button = newMarkerButton(panel, i)
        if button then
            placeCell(button)
            -- Le titre porte le numéro du marqueur : huit vignettes identiques
            -- au survol ne diraient pas laquelle on s'apprête à poser.
            W.Tooltip(button, string.format(opts.markerLabel or "%d", i), opts.markerTip)
        end
    end

    if placed > 0 then
        local clear = newMarkerButton(panel, nil)
        if clear then
            placeCell(clear)
            W.Tooltip(clear, opts.clearLabel, opts.clearTip)
        end
    end

    -- ---------------------------------------------------------------------
    --  Vérification de présence et pull
    -- ---------------------------------------------------------------------

    local buttonY = top - T.SIZE.MARKER_CELL - T.SIZE.MARKER_ROW_GAP

    local ready = W.Button(panel, opts.readyLabel, opts.onReadyCheck, BUTTON_W)
    ready:SetPoint("TOPLEFT", panel, "TOPLEFT", T.SIZE.TOOL_PAD, buttonY)
    W.Tooltip(ready, opts.readyLabel, opts.readyTip)
    panel.readyButton = ready

    local pull = W.Button(panel, opts.pullLabel, opts.onPull, BUTTON_W)
    pull:SetPoint("TOPLEFT", ready, "TOPRIGHT", T.SIZE.MARKER_GAP, 0)
    W.Tooltip(pull, opts.pullLabel, opts.pullTip)
    panel.pullButton = pull

    panel:SetHeight(T.SIZE.TOOL_PAD + T.SIZE.MARKER_CELL + T.SIZE.MARKER_ROW_GAP
        + ready:GetHeight() + T.SIZE.TOOL_PAD)

    --- Libellé du bouton de pull, qui porte la durée choisie.
    ---@param text string
    function panel:SetPullLabel(text)
        pull:SetText(text or "")
    end

    --- Montre ou cache le panneau. Rend `false` si le combat l'interdit : les
    --- cases de marqueurs sont des cadres protégés, que le client refuse de
    --- montrer comme de cacher tant que le combat dure. L'appelant rappelle à la
    --- sortie de combat.
    ---@param shown boolean
    ---@return boolean applied
    function panel:SetShownOutOfCombat(shown)
        if InCombatLockdown() then return false end
        self:SetShown(shown)
        return true
    end

    panel:ApplyScale()
    return panel
end
