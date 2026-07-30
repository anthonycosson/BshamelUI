-- =========================================================================
--  Bshamel UI — UI/Widgets/ScrollList.lua
--  Zone défilante générique : une frame de contenu à hauteur variable dans un
--  ScrollFrame du client.
--
--  Pas de virtualisation (`WowScrollBoxList`) : nos pages contiennent quelques
--  dizaines de lignes, pas des milliers. La complexité ne serait pas payée.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local W    = BUI.Widgets

--- Redimensionne le curseur de l'ascenseur au prorata de ce qui est visible :
--- sa hauteur dit alors quelle part de la page on a sous les yeux. Le template
--- du client, lui, donne un curseur de taille fixe, qui n'informe de rien.
---
--- Écrit défensivement de bout en bout : la structure interne des ascenseurs de
--- Blizzard a déjà changé plusieurs fois. À la moindre pièce manquante on
--- renonce au calcul et on garde le curseur du client.
---@param scrollFrame table
local function updateThumb(scrollFrame)
    local bar = scrollFrame.ScrollBar
    if not bar then return end

    local thumb = bar.ThumbTexture or bar.Thumb
    if not (thumb and thumb.SetHeight) then return end

    local visible = scrollFrame:GetHeight()
    local total   = visible + scrollFrame:GetVerticalScrollRange()
    if visible <= 0 or total <= 0 then return end

    -- La piste, c'est la barre moins ses deux boutons de fin quand elle en a.
    local track = bar:GetHeight()
    if bar.ScrollUpButton and bar.ScrollDownButton then
        track = track - bar.ScrollUpButton:GetHeight() - bar.ScrollDownButton:GetHeight()
    end
    if track <= 0 then return end

    local height = track * (visible / total)
    height = math.max(T.SIZE.THUMB_MIN, math.min(height, track))
    thumb:SetHeight(height)
end

--- Crée une zone défilante et renvoie le ScrollFrame et sa frame de contenu.
--- Le contenu s'étend en largeur avec le parent ; c'est à l'appelant de fixer
--- sa hauteur au fur et à mesure qu'il empile des lignes.
---@param parent table
---@param hideBar? boolean  masque l'ascenseur ; la molette continue de défiler
---@return table scrollFrame, table content
function W.ScrollPane(parent, hideBar)
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, T.Template("SCROLLPANE"))

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(1, 1)
    scrollFrame:SetScrollChild(content)

    local bar = scrollFrame.ScrollBar
    if bar then
        if hideBar then
            -- Le template rappelle `Show` à chaque changement de plage : masquer
            -- une fois ne suffit pas, il faut rendre l'appel inerte.
            bar:Hide()
            bar.Show = bar.Hide
        else
            -- `OnScrollRangeChanged` appartient au template ; on s'y accroche.
            -- `OnSizeChanged` est à nous, on l'écrit plus bas — un HookScript
            -- ici serait effacé par le SetScript qui suit.
            scrollFrame:HookScript("OnScrollRangeChanged", updateThumb)
            scrollFrame._sizeThumb = true
        end
    end

    --- Recale la largeur du contenu sur celle de la zone visible.
    --- À rappeler après tout redimensionnement de la fenêtre.
    function scrollFrame:UpdateContentWidth()
        content:SetWidth(self:GetWidth())
    end

    scrollFrame:SetScript("OnSizeChanged", function(self)
        self:UpdateContentWidth()
        if self._sizeThumb then updateThumb(self) end
    end)

    --- Remet le défilement en haut. Appelé à chaque changement de page pour que
    --- l'utilisateur n'atterrisse pas au milieu d'une page qu'il vient d'ouvrir.
    function scrollFrame:ResetScroll()
        self:SetVerticalScroll(0)
        if self.ScrollBar and self.ScrollBar.SetValue then
            self.ScrollBar:SetValue(0)
        end
    end

    scrollFrame.content = content
    return scrollFrame, content
end

--- Largeur utile pour les lignes d'une zone défilante.
--- `UIPanelScrollFrameTemplate` ancre sa barre de défilement **à l'extérieur**
--- du ScrollFrame : la place lui est réservée par l'ancrage du ScrollFrame
--- lui-même (cf. `T.SIZE.SCROLLBAR_W`), pas ici. La largeur utile est donc
--- exactement celle de la zone visible.
---@param scrollFrame table
---@return number
function W.ContentWidth(scrollFrame)
    return math.max(1, scrollFrame:GetWidth())
end
