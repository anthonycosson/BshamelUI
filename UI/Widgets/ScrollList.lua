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

---@param bar table
---@return table|nil
local function thumbOf(bar)
    return bar.ThumbTexture or bar.Thumb
end

--- Dépouille l'ascenseur du client : ni boutons de fin, ni fond de piste, ni
--- cadre. Il ne reste qu'un curseur.
---
--- Un ascenseur n'a qu'une chose à dire — où l'on est et quelle part on voit —
--- et un curseur seul la dit entièrement. Les deux flèches ne servent qu'à
--- défiler d'un cran, ce que la molette fait mieux.
---
--- Écrit défensivement : la structure interne des ascenseurs de Blizzard a déjà
--- changé plusieurs fois. Toute pièce absente est simplement sautée.
---
--- Publié : toute zone défilante de l'addon doit avoir le même ascenseur, y
--- compris celles qui ne passent pas par `W.ScrollPane` (voir `W.CopyWindow`,
--- dont l'enfant défilant est une zone de saisie et non une frame de contenu).
---@param bar table
function W.StripScrollBar(bar)
    if bar.ScrollUpButton then bar.ScrollUpButton:Hide() end
    if bar.ScrollDownButton then bar.ScrollDownButton:Hide() end

    local thumb = thumbOf(bar)

    -- Toutes les textures de la barre sauf le curseur : ce sont les pièces de
    -- la piste. Le curseur en est une aussi, d'où l'exclusion explicite.
    for _, region in ipairs({ bar:GetRegions() }) do
        if region ~= thumb and region.GetObjectType and region:GetObjectType() == "Texture" then
            region:Hide()
        end
    end

    bar:SetWidth(T.SIZE.THUMB_W)

    if thumb then
        thumb:SetTexture(T.TEXTURE.SIDEBAR_BAND)
        thumb:SetDesaturated(true)
        thumb:SetVertexColor(T.COLOR.BAND:GetRGB())
        thumb:SetAlpha(T.ALPHA.THUMB)
        thumb:SetWidth(T.SIZE.THUMB_W)
    end
end

--- Ajuste l'ascenseur à ce qu'il y a à montrer.
---
--- Deux choses à la fois, parce qu'elles répondent à la même question — quelle
--- part de la page voit-on ?
---
--- 1. Rien à faire défiler : l'ascenseur disparaît. Une barre qui ne sert à rien
---    est une barre qui ment.
--- 2. Sinon, le curseur prend la hauteur de la part visible. Le template du
---    client donne un curseur de taille fixe, qui n'informe de rien.
---
--- Publié pour la même raison que `W.StripScrollBar`.
---@param scrollFrame table
function W.UpdateScrollThumb(scrollFrame)
    local bar = scrollFrame.ScrollBar
    if not bar then return end

    local visible = scrollFrame:GetHeight()
    local range   = scrollFrame:GetVerticalScrollRange()

    bar:SetShown(range > 0)
    if range <= 0 then return end

    local thumb = thumbOf(bar)
    if not (thumb and thumb.SetHeight) then return end

    local total = visible + range
    if visible <= 0 or total <= 0 then return end

    -- La piste, c'est la barre elle-même : dans le template du client, les deux
    -- boutons de fin sont ancrés **en dehors** du curseur, ils ne mangent pas
    -- sa course.
    local track = bar:GetHeight()
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
            W.StripScrollBar(bar)

            -- `OnScrollRangeChanged` appartient au template ; on s'y accroche.
            -- Notre gestionnaire passe donc **après** le sien, et c'est le nôtre
            -- qui décide en dernier si la barre se montre.
            -- `OnSizeChanged` est à nous, on l'écrit plus bas — un HookScript
            -- ici serait effacé par le SetScript qui suit.
            scrollFrame:HookScript("OnScrollRangeChanged", W.UpdateScrollThumb)
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
        if self._sizeThumb then W.UpdateScrollThumb(self) end
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
