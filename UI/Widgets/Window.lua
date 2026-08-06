-- =========================================================================
--  Bshamel UI — UI/Widgets/Window.lua
--  Fenêtre principale : cadre du client, déplaçable, redimensionnable,
--  fermable à Échap.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local W    = BUI.Widgets

--- Récupère le FontString du titre, dont l'emplacement a changé selon les
--- versions du template (`frame.TitleText` puis `frame.TitleContainer.TitleText`).
---@param frame table
---@return table|nil
local function findTitleText(frame)
    if frame.TitleText then return frame.TitleText end
    if frame.TitleContainer and frame.TitleContainer.TitleText then
        return frame.TitleContainer.TitleText
    end
    return nil
end

--- Crée la fenêtre principale de l'addon.
---@param globalName string   nom global (préfixé `BshamelUI`), requis par UISpecialFrames
---@param titleText string
---@param width number
---@param height number
---@return table
function W.Window(globalName, titleText, width, height)
    local template = T.Template("WINDOW")
    local frame = CreateFrame("Frame", globalName, UIParent, template)

    frame:SetSize(width, height)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:Hide()

    -- Fond sombre et translucide, bordure laissée pleine : le jeu reste visible
    -- derrière la fenêtre sans que le cadre perde son contour. Le voile des
    -- bords lui redonne du poids là où il en faut, sans fermer le centre.
    T.WindowSurface(frame)
    W.EdgeShade(frame)

    -- On relève la texture de la barre de titre avant que quoi que ce soit
    -- d'autre ne soit dessiné : les en-têtes de la navigation s'en serviront.
    T.CaptureTitleBar(frame)

    -- Déplacement par la barre de titre.
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if self._onMoveStop then self._onMoveStop(self) end
    end)
    frame:SetClampedToScreen(true)

    -- Redimensionnement.
    frame:SetResizable(true)
    if frame.SetResizeBounds then
        frame:SetResizeBounds(T.SIZE.WINDOW_MIN_W, T.SIZE.WINDOW_MIN_H)
    end
    -- Le second argument dit **qui** a redimensionné : le joueur, en tirant le
    -- coin. La fenêtre est aussi remesurée pour d'autres raisons — une échelle
    -- de contenu, une page qui réclame de la place — et ce qui se règle à la
    -- main ne se traite pas comme ce qui se règle tout seul.
    W.ResizeGrip(frame, {
        onStop = function()
            if frame._onResize then frame._onResize(frame, true) end
        end,
    })

    -- Titre.
    local title = findTitleText(frame)
    if not title then
        title = frame:CreateFontString(nil, "OVERLAY", T.FONT.WINDOW_TITLE)
        title:SetPoint("TOP", frame, "TOP", 0, -5)
    end
    title:SetText(titleText)
    frame.Title = title

    -- Échap ferme la fenêtre. Nécessite un nom global, d'où `globalName`.
    if globalName then
        tinsert(UISpecialFrames, globalName)
    end

    -- Le template fournit déjà un bouton de fermeture ; sinon on en pose un.
    if not frame.CloseButton then
        local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -2, -2)
        frame.CloseButton = close
    end

    return frame
end
