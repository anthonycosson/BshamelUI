-- =========================================================================
--  Bshamel UI — UI/Widgets/MarkerBar.lua
--  Barre d'outils de groupe : marqueurs au sol, vérification de présence, pull.
--
--  **Poser un marqueur au sol est une action protégée.** Le client refuse
--  `PlaceRaidMarker` depuis du code Lua ordinaire, exactement comme il refuse de
--  lancer un sort : la seule voie est un bouton bâti sur son template sécurisé,
--  à qui l'on décrit l'action par des attributs (`type = "worldmarker"`,
--  `marker`, `action`). Le clic part alors du moteur, pas de nous.
--
--  Conséquences, les mêmes que pour le menu de téléportation
--  (`UI/Widgets/SecureMenu.lua`) : les attributs sont écrits **une fois**, à la
--  construction — ils ne changent jamais, un bouton de marqueur porte le même
--  numéro toute sa vie —, et la barre ne se montre ni ne se cache en combat.
--  D'où `SetShownOutOfCombat`, qui diffère ce que le combat refuse au lieu de
--  laisser l'appelant croire qu'il a caché quelque chose.
--
--  La vérification de présence et le pull, eux, ne sont pas protégés : ce sont
--  des boutons ordinaires, et c'est l'appelant qui décide ce qu'ils font.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local W    = BUI.Widgets

--- Nombre de marqueurs au sol. Huit depuis toujours, comme les icônes de
--- ciblage dont ils empruntent les vignettes.
local MARKER_COUNT = 8

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
    elseif not T.TrySetAtlas(icon, T.ATLAS.CLEAR) then
        -- Sans vignette, le bouton reste utilisable : c'est son infobulle qui
        -- dit ce qu'il fait.
        icon:Hide()
    end

    button.Highlight = W.CenterGlow(button, T.COLOR.WHITE, T.ALPHA.ROW_HOVER)
    button:SetScript("OnEnter", function(self) self.Highlight:SetShown(true) end)
    button:SetScript("OnLeave", function(self) self.Highlight:SetShown(false) end)

    return button
end

--- Barre d'outils de groupe, masquée au départ.
---@param opts table  { getPos, setPos, onReadyCheck, onPull, pullLabel, readyLabel }
---@return table
function W.MarkerBar(opts)
    local cells = MARKER_COUNT + 1  -- les huit marqueurs, plus « tout effacer »
    local width = T.SIZE.TOOL_PAD * 2
                  + cells * T.SIZE.MARKER_CELL + (cells - 1) * T.SIZE.MARKER_GAP

    local panel = W.Panel({
        width  = width,
        height = T.SIZE.TOOL_PAD * 2 + T.SIZE.MARKER_CELL
                 + T.SIZE.MARKER_ROW_GAP + T.SIZE.ROW_H,
        getPos = opts.getPos,
        setPos = opts.setPos,
    })

    -- ---------------------------------------------------------------------
    --  Rangée des marqueurs
    -- ---------------------------------------------------------------------

    local step = T.SIZE.MARKER_CELL + T.SIZE.MARKER_GAP
    local placed = 0

    for i = 1, MARKER_COUNT do
        local button = newMarkerButton(panel, i)
        if button then
            button:SetPoint("TOPLEFT", panel, "TOPLEFT",
                T.SIZE.TOOL_PAD + (i - 1) * step, -T.SIZE.TOOL_PAD)
            -- Le titre porte le numéro du marqueur : huit vignettes identiques
            -- au survol ne diraient pas laquelle on s'apprête à poser.
            W.Tooltip(button, string.format(opts.markerLabel or "%d", i), opts.markerTip)
            placed = placed + 1
        end
    end

    if placed > 0 then
        local clear = newMarkerButton(panel, nil)
        if clear then
            clear:SetPoint("TOPLEFT", panel, "TOPLEFT",
                T.SIZE.TOOL_PAD + MARKER_COUNT * step, -T.SIZE.TOOL_PAD)
            W.Tooltip(clear, opts.clearLabel, opts.clearTip)
        end
    end

    -- ---------------------------------------------------------------------
    --  Vérification de présence et pull
    -- ---------------------------------------------------------------------

    local top = -(T.SIZE.TOOL_PAD + T.SIZE.MARKER_CELL + T.SIZE.MARKER_ROW_GAP)

    local ready = W.Button(panel, opts.readyLabel, opts.onReadyCheck, T.SIZE.MARKER_BUTTON_W)
    ready:SetPoint("TOPLEFT", panel, "TOPLEFT", T.SIZE.TOOL_PAD, top)
    W.Tooltip(ready, opts.readyLabel, opts.readyTip)
    panel.readyButton = ready

    local pull = W.Button(panel, opts.pullLabel, opts.onPull, T.SIZE.MARKER_BUTTON_W)
    pull:SetPoint("TOPLEFT", ready, "TOPRIGHT", T.SIZE.MARKER_GAP, 0)
    W.Tooltip(pull, opts.pullLabel, opts.pullTip)
    panel.pullButton = pull

    --- Libellé du bouton de pull, qui porte la durée choisie.
    ---@param text string
    function panel:SetPullLabel(text)
        pull:SetText(text or "")
    end

    --- Montre ou cache la barre. Rend `false` si le combat l'interdit : les
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

    return panel
end
