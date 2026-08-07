-- =========================================================================
--  Bshamel UI — UI/Widgets/SlotInfo.lua
--  Bandeau d'informations posé sur un emplacement de la fiche de personnage.
--
--  Deux zones, et la distinction entre les deux est le cœur du widget :
--
--    * le **niveau d'objet**, posé sur l'icône. C'est un nombre qu'on lit en
--      descendant la colonne, il doit rester collé à la pièce ;
--    * une colonne de **pastilles**, posée à côté de l'emplacement — ou
--      au-dessus, pour ceux qui n'ont pas de côté libre —, **une par ligne**.
--      Chacune dit d'un mot si quelque chose est fait ou ne l'est pas, et le dit
--      par sa couleur — vert ou rouge. C'est le mot qui nomme, c'est la couleur
--      qui informe.
--
--  Des pastilles et non des phrases : la première version écrivait le nom de
--  l'enchantement en toutes lettres, ce qui faisait courir six lignes de texte
--  en travers du modèle du personnage. Un mot de quatre lettres tient à côté de
--  la case et se lit d'un coup d'œil, ce qui est tout ce qu'on lui demande.
--
--  Une colonne et non une file : alignées horizontalement, quatre pastilles
--  formaient une phrase qu'il fallait lire ; empilées, elles se comparent d'un
--  emplacement à l'autre — c'est la colonne de couleurs qu'on parcourt, pas
--  chaque ligne l'une après l'autre.
--
--  Le widget ne sait rien des objets : on lui donne un nombre et des couples
--  (texte, couleur). C'est le module qui décide de ce que ça veut dire.
--
--  Réversibilité : une frame World of Warcraft ne se détruit pas. `Clear` vide
--  le bandeau sans rien libérer, et cacher la frame suffit à rendre
--  l'emplacement identique à ce que le client dessine (CLAUDE.md règle 6).
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local W    = BUI.Widgets

--- Empile les pastilles, une par ligne, alignées sur le bord qui touche la case.
---
--- **La colonne s'empile toujours en s'éloignant de la case, jamais vers elle.**
--- C'est la règle unique dont tout le reste découle : la première ligne — le
--- niveau d'objet — se pose contre l'emplacement et n'en bouge plus, et ce sont
--- les icônes qui s'écartent selon qu'il y en a zéro ou quatre.
---
--- Sur un côté, s'éloigner veut dire **descendre** : la colonne part du haut de
--- la case, le niveau d'objet en tête. C'est ce qui fait que seize niveaux
--- d'objet se lisent d'un seul coup d'œil au lieu de danser d'un demi-cran par
--- gemme.
---
--- Au-dessus, s'éloigner veut dire **monter**, et la colonne s'inverse donc de
--- bout en bout : le niveau d'objet contre la case, les icônes par-dessus. Elle
--- ne s'inversait pas, et les deux armes en payaient le prix — la main droite,
--- enchantée et sertie, écrivait son niveau deux crans plus haut que la main
--- gauche portant un bouclier. Deux nombres qu'on lit ensemble, jamais sur la
--- même ligne.
---
--- Chaque pastille porte une hauteur imposée plutôt que celle de son texte : des
--- lignes régulières se lisent en colonne, des lignes qui suivent la police
--- donnent un pas irrégulier d'un emplacement à l'autre.
---@param info table
local function arrange(info)
    -- `edge` vaut `nil` quand la colonne est centrée : « TOP » tout court est
    -- déjà le milieu du bord haut.
    local edge   = info._edge
    local top    = edge and ("TOP" .. edge) or "TOP"
    local bottom = edge and ("BOTTOM" .. edge) or "BOTTOM"

    -- `head` est le bord par lequel la colonne s'accroche — celui qui touche la
    -- case —, `tail` celui par lequel la ligne suivante s'y attache. Les deux
    -- s'échangent quand on empile vers le haut, et c'est **tout** ce que le sens
    -- change : la boucle qui suit ne sait pas dans quel sens elle travaille.
    local up   = info._upward
    local head = up and bottom or top
    local tail = up and top or bottom
    local gap  = up and T.SIZE.SLOT_STRIP_GAP or -T.SIZE.SLOT_STRIP_GAP

    local strips = info._icons > 0 and 1 or 0
    local lines  = info._count + strips
    info.row:SetHeight(math.max(lines, 1) * T.SIZE.SLOT_LINE_H
                       + strips * T.SIZE.SLOT_STRIP_GAP)

    local previous
    for i = 1, info._count do
        local badge = info._badges[i]
        badge:ClearAllPoints()
        if previous then
            badge:SetPoint(head, previous, tail, 0, 0)
        else
            badge:SetPoint(head, info.row, head, 0, 0)
        end
        previous = badge
    end

    -- La rangée d'icônes ferme la colonne : elle compte pour une ligne de plus,
    -- et s'aligne sur le même bord que les textes.
    --
    -- Elle prend un peu d'air entre elle et la ligne de texte, ce que les lignes
    -- de texte entre elles n'ont pas besoin d'avoir : du texte porte ses propres
    -- marges, une icône va bord à bord et se collerait à sa voisine.
    local strip = info.strip
    strip:ClearAllPoints()
    if previous then
        strip:SetPoint(head, previous, tail, 0, gap)
    else
        strip:SetPoint(head, info.row, head, 0, 0)
    end
    strip:SetShown(info._icons > 0)
end

--- Bandeau attaché à un bouton d'emplacement du client.
---@param button table
---@return table|nil
function W.SlotInfo(button)
    if not button then return nil end

    local info = CreateFrame("Frame", nil, button)
    info:SetAllPoints(button)
    info:SetFrameLevel(button:GetFrameLevel() + T.SIZE.SLOT_INFO_LEVEL)

    -- Le niveau d'objet reste sur l'icône, en bas à droite : c'est le seul
    -- endroit où il se lit sans quitter la pièce des yeux.
    local level = info:CreateFontString(nil, "OVERLAY", T.FONT.SLOT_BADGE)
    level:SetPoint("BOTTOMRIGHT", info, "BOTTOMRIGHT",
                   -T.SIZE.SLOT_TEXT_INSET, T.SIZE.SLOT_TEXT_INSET)

    local row = CreateFrame("Frame", nil, info)
    row:SetSize(T.SIZE.SLOT_INFO_W, T.SIZE.SLOT_LINE_H)

    -- La rangée d'icônes, posée sous les textes. Un cadre à elle, parce qu'elle
    -- s'aligne d'un bloc sur le bord de la colonne : ce sont ses icônes qui se
    -- rangent en son sein, pas chacune contre la colonne.
    local strip = CreateFrame("Frame", nil, row)
    strip:SetHeight(T.SIZE.SLOT_ICON)
    strip:Hide()

    info.row      = row
    info.strip    = strip
    info._badges  = {}
    info._buttons = {}
    info._count   = 0
    info._icons   = 0
    info._edge    = "LEFT"
    info._upward  = false

    --- Où la colonne se pose par rapport à l'emplacement.
    ---
    --- `"LEFT"` et `"RIGHT"` disent de quel côté ; `"ABOVE"` empile au-dessus,
    --- centré. Le bord d'alignement des pastilles est toujours celui qui touche
    --- la case : à gauche de l'icône elles s'alignent à droite, et inversement.
    ---
    --- `top` accroche la colonne par le **haut** de la case au lieu de la centrer
    --- sur elle. Centrée, la première ligne descend d'un demi-cran chaque fois
    --- qu'une ligne s'ajoute : deux emplacements voisins n'ayant ni le même
    --- nombre d'enchantements ni le même nombre de gemmes, leurs niveaux d'objet
    --- ne se lisent plus sur une ligne commune. Accrochée par le haut, la
    --- première ligne ne bouge plus et ce sont les icônes qui descendent.
    ---
    --- Ce n'est pas le bon choix partout : sur les quatorze emplacements qui
    --- bordent le modèle, les cases sont serrées et une colonne qui ne grandit
    --- que vers le bas déborde sur la suivante. Les armes, elles, ont le vide
    --- sous elles.
    ---
    --- `"ABOVE"` **ignore `top` et empile toujours vers le haut** : c'est la même
    --- promesse, tenue par l'autre bout. Une colonne posée au-dessus d'une case
    --- ne peut s'accrocher que par son bas — s'accrocher par le haut la ferait
    --- redescendre sur l'icône dès la deuxième ligne — et la ligne fixe est donc
    --- celle du bas (voir `arrange`).
    ---@param where string  "LEFT", "RIGHT" ou "ABOVE"
    ---@param top? boolean  accrocher par le haut plutôt que centrer
    function info:SetPlacement(where, top)
        row:ClearAllPoints()
        self._upward = where == "ABOVE"

        if where == "ABOVE" then
            self._edge = nil
            row:SetPoint("BOTTOM", button, "TOP", 0, T.SIZE.SLOT_INFO_GAP)
        elseif where == "LEFT" then
            self._edge = "RIGHT"
            row:SetPoint(top and "TOPRIGHT" or "RIGHT", button,
                         top and "TOPLEFT" or "LEFT", -T.SIZE.SLOT_INFO_GAP,
                         top and -T.SIZE.SLOT_TOP_DROP or 0)
        else
            self._edge = "LEFT"
            row:SetPoint(top and "TOPLEFT" or "LEFT", button,
                         top and "TOPRIGHT" or "RIGHT", T.SIZE.SLOT_INFO_GAP,
                         top and -T.SIZE.SLOT_TOP_DROP or 0)
        end

        arrange(self)
    end

    --- Niveau d'objet, posé sur l'icône. `nil` l'efface.
    ---@param value? string
    ---@param r? number
    ---@param g? number
    ---@param b? number
    function info:SetLevel(value, r, g, b)
        if not value then
            level:Hide()
            return
        end
        level:SetText(value)
        if r then level:SetTextColor(r, g, b) end
        level:Show()
    end

    --- Ouvre une nouvelle file de pastilles. Les précédentes restent en place
    --- jusqu'à `EndBadges` : les `FontString` sont réutilisées, jamais recréées.
    function info:BeginBadges()
        self._count = 0
    end

    --- Ajoute une pastille à la file en cours.
    ---@param text string
    ---@param r number
    ---@param g number
    ---@param b number
    function info:AddBadge(text, r, g, b)
        if not text or text == "" then return end

        local index = self._count + 1
        local badge = self._badges[index]
        if not badge then
            badge = row:CreateFontString(nil, "OVERLAY", T.FONT.SLOT_INFO)
            badge:SetWordWrap(false)
            -- Hauteur imposée, largeur laissée au texte : c'est ce couple qui
            -- donne une colonne au pas régulier sans tronquer les libellés.
            badge:SetHeight(T.SIZE.SLOT_LINE_H)
            self._badges[index] = badge
        end

        badge:SetText(text)
        badge:SetTextColor(r, g, b)
        badge:Show()

        self._count = index
    end

    --- Ferme la file : cache ce qui reste de la précédente et remet en place.
    function info:EndBadges()
        for i = self._count + 1, #self._badges do
            self._badges[i]:Hide()
        end
        arrange(self)
    end

    -- ---------------------------------------------------------------------
    --  Rangée d'icônes
    -- ---------------------------------------------------------------------
    -- Des **boutons** et non des textures, alors qu'aucune icône n'est cliquable
    -- par nature : une châsse l'est, et une châsse ne se distingue pas des autres
    -- à la construction. Un bouton qui ne réagit à rien coûte le même dessin
    -- qu'une texture ; en faire deux sortes coûterait deux chemins.

    --- Ouvre une nouvelle rangée d'icônes.
    function info:BeginIcons()
        self._icons = 0
    end

    ---@class BUI.SlotIcon
    ---@field atlas? string
    ---@field texture? string|number
    ---@field desaturated? boolean
    ---@field link? string      lien d'objet ; son infobulle prime sur le reste
    ---@field title? string
    ---@field hint? string

    --- Ajoute une icône à la rangée en cours.
    ---@param spec BUI.SlotIcon
    function info:AddIcon(spec)
        if not (spec and (spec.atlas or spec.texture)) then return end

        local index  = self._icons + 1
        local cell = self._buttons[index]

        if not cell then
            cell = CreateFrame("Button", nil, strip)
            cell:SetSize(T.SIZE.SLOT_ICON, T.SIZE.SLOT_ICON)

            local icon = cell:CreateTexture(nil, "ARTWORK")
            icon:SetAllPoints()
            cell.icon = icon

            -- **L'infobulle de l'objet quand il y en a un, la nôtre sinon.**
            -- Devant une gemme sertie, ce qu'on veut savoir est ce qu'elle
            -- apporte — et cela, le client le dit déjà mieux que nous. Devant une
            -- châsse vide il n'y a pas d'objet, donc rien à demander au client :
            -- c'est à nous de dire ce qu'il manque.
            --
            -- Écrite une fois à la construction : ce sont les champs du bouton
            -- qui changent d'un emplacement à l'autre, pas ses scripts.
            cell:SetScript("OnEnter", function(hovered)
                GameTooltip:SetOwner(hovered, "ANCHOR_RIGHT")

                if hovered._link then
                    GameTooltip:SetHyperlink(hovered._link)
                else
                    if hovered._title then GameTooltip_SetTitle(GameTooltip, hovered._title) end
                    if hovered._hint then
                        GameTooltip_AddNormalLine(GameTooltip, hovered._hint, true)
                    end
                end

                GameTooltip:Show()
            end)

            cell:SetScript("OnLeave", function() GameTooltip:Hide() end)

            self._buttons[index] = cell
        end

        cell._link  = spec.link
        cell._title = spec.title
        cell._hint  = spec.hint

        -- L'atlas d'abord, la texture en repli — et le repli sert vraiment : le
        -- nom d'atlas peut venir du client, auquel cas rien ne garantit qu'il
        -- existe encore. `T.TrySetAtlas` le dit plutôt que de laisser une icône
        -- vide.
        if not (spec.atlas and T.TrySetAtlas(cell.icon, spec.atlas)) then
            cell.icon:SetTexture(spec.texture)
        end
        cell.icon:SetDesaturated(spec.desaturated and true or false)

        cell:ClearAllPoints()
        if index == 1 then
            cell:SetPoint("LEFT", strip, "LEFT", 0, 0)
        else
            cell:SetPoint("LEFT", self._buttons[index - 1], "RIGHT",
                            T.SIZE.SLOT_ICON_GAP, 0)
        end
        cell:Show()

        self._icons = index
    end

    --- Ferme la rangée : cache ce qui reste de la précédente, et lui donne sa
    --- largeur — c'est elle qui permet à la rangée de se caler sur le bord de la
    --- colonne, à droite comme à gauche.
    function info:EndIcons()
        for i = self._icons + 1, #self._buttons do
            self._buttons[i]:Hide()
        end

        local count = self._icons
        strip:SetWidth(math.max(1,
            count * T.SIZE.SLOT_ICON + math.max(0, count - 1) * T.SIZE.SLOT_ICON_GAP))

        arrange(self)
    end

    --- Vide le bandeau sans rien libérer.
    function info:Clear()
        self:SetLevel(nil)
        self:BeginBadges()
        self:EndBadges()
        self:BeginIcons()
        self:EndIcons()
    end

    info:Clear()
    info:SetPlacement("RIGHT")
    return info
end
