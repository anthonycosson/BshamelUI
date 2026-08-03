-- =========================================================================
--  Bshamel UI — UI/Widgets/CopyWindow.lua
--  Fenêtre de copie : du texte qu'on peut sélectionner et emporter.
--
--  Le client ne laisse rien sélectionner dans une fenêtre de chat : ses lignes
--  sont dessinées, pas saisies. La seule façon d'en sortir du texte est de le
--  reposer ailleurs, dans une zone de saisie — c'est tout ce que fait ce
--  widget, et c'est pour cela qu'il ne ressemble pas au chat.
--
--  La zone de saisie est **l'enfant défilant lui-même**, et non une frame de
--  contenu comme dans `W.ScrollPane` : une zone de saisie multiligne calcule sa
--  propre hauteur d'après son texte. Lui donner un parent intermédiaire
--  obligerait à mesurer ce texte à sa place.
--
--  **Elle sert aussi à faire entrer du texte**, et c'est le même widget parce
--  que c'est le même geste : une liste qu'on emporte et une liste qu'on colle
--  se présentent pareil, se sélectionnent pareil, et se lisent dans la même
--  fenêtre. `onSubmit` ajoute le seul bouton qui les distingue — sans lui, la
--  fenêtre est en lecture et rien ne peut être validé par mégarde.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local W    = BUI.Widgets

--- Construit une fenêtre de copie. L'appelant la garde et la rouvre avec un
--- autre contenu — une par usage, chacune sous son propre nom global : deux
--- cadres portant le même nom se recouvriraient l'un l'autre.
---@param globalName string     nom global (préfixé `BshamelUI`), requis par UISpecialFrames
---@param titleText string
---@param hintText string       rappel du raccourci de copie, sous la zone de texte
---@param submitLabel? string   intitulé du bouton de validation ; sans lui, aucun bouton
---@param onSubmit? fun(text: string)
---@return table
function W.CopyWindow(globalName, titleText, hintText, submitLabel, onSubmit)
    local S = T.SIZE

    local frame = W.Window(globalName, titleText, S.COPY_W, S.COPY_H)

    -- Le rappel du raccourci est **hors** du panneau : dans la zone de texte, il
    -- serait sélectionné avec le reste et se retrouverait dans le presse-papier.
    local hint = frame:CreateFontString(nil, "OVERLAY", T.FONT.HINT)
    hint:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", S.CHROME_SIDE + S.PADDING, S.CHROME_BOTTOM)
    hint:SetText(hintText)

    local panel = W.Inset(frame)
    panel:SetPoint("TOPLEFT", frame, "TOPLEFT", S.CHROME_SIDE, -S.CHROME_TOP)
    panel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -S.CHROME_SIDE, S.CHROME_BOTTOM + S.ROW_H)

    -- Le template ancre son ascenseur **à l'extérieur** du ScrollFrame : la place
    -- est réservée ici, pas en rétrécissant le texte (voir `API_NOTES.md`).
    local scroll = CreateFrame("ScrollFrame", nil, frame, T.Template("SCROLLPANE"))
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", S.PANEL_PAD, -S.PANEL_PAD)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -S.PANEL_PAD - S.SCROLLBAR_W, S.PANEL_PAD)

    if scroll.ScrollBar then
        W.StripScrollBar(scroll.ScrollBar)
        scroll:HookScript("OnScrollRangeChanged", W.UpdateScrollThumb)
    end

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(0)

    local font = _G[T.FONT.COPY]
    if font then edit:SetFontObject(font) end

    edit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        frame:Hide()
    end)

    scroll:SetScrollChild(edit)

    -- Le bouton de validation, quand la fenêtre en a un. Il vit sur la même
    -- ligne que le rappel de raccourci, à l'autre bout : c'est la bande basse,
    -- hors du panneau, et donc hors de ce qui part dans le presse-papier.
    if submitLabel and onSubmit then
        local submit = W.Button(frame, submitLabel, function()
            local text = edit:GetText()
            frame:Hide()
            onSubmit(text or "")
        end)
        submit:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT",
            -(S.CHROME_SIDE + S.PADDING), S.CHROME_BOTTOM)
    end

    --- La largeur du texte suit celle de la zone visible ; sa hauteur, elle,
    --- est calculée par la zone de saisie elle-même.
    local function fit()
        edit:SetWidth(math.max(1, scroll:GetWidth()))
        W.UpdateScrollThumb(scroll)
    end

    scroll:SetScript("OnSizeChanged", fit)
    frame._onResize = fit
    fit()

    frame:HookScript("OnHide", function() edit:ClearFocus() end)

    --- Affiche la fenêtre sur un texte, tout sélectionné et prêt à être copié.
    ---
    --- Le texte est présenté par son début : c'est le sens de lecture, et la
    --- sélection porte de toute façon sur l'intégralité.
    ---@param text string
    function frame:Open(text)
        self:Show()

        edit:SetText(text or "")
        edit:SetCursorPosition(0)
        edit:HighlightText()
        scroll:SetVerticalScroll(0)
        edit:SetFocus()
    end

    return frame
end
