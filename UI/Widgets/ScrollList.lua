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

--- Crée une zone défilante et renvoie le ScrollFrame et sa frame de contenu.
--- Le contenu s'étend en largeur avec le parent ; c'est à l'appelant de fixer
--- sa hauteur au fur et à mesure qu'il empile des lignes.
---@param parent table
---@return table scrollFrame, table content
function W.ScrollPane(parent)
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, T.Template("SCROLLPANE"))

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(1, 1)
    scrollFrame:SetScrollChild(content)

    --- Recale la largeur du contenu sur celle de la zone visible.
    --- À rappeler après tout redimensionnement de la fenêtre.
    function scrollFrame:UpdateContentWidth()
        content:SetWidth(self:GetWidth())
    end

    scrollFrame:SetScript("OnSizeChanged", function(self)
        self:UpdateContentWidth()
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
