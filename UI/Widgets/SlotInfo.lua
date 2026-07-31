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
--- Posée sur un côté, la colonne est **centrée sur l'emplacement** : c'est la
--- hauteur du conteneur qui s'ajuste au nombre de pastilles, et comme il est
--- ancré par son milieu, la colonne grandit des deux côtés à la fois. Empiler
--- vers le bas à partir d'un haut fixe ferait descendre le bloc sur la case
--- suivante dès qu'il y a trois lignes.
---
--- Posée au-dessus, elle est ancrée par le **bas** et grandit donc uniquement
--- vers le haut, ce qui est la même idée : quel que soit le nombre de pastilles,
--- aucune ne vient jamais recouvrir l'icône.
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

    info.row:SetHeight(math.max(info._count, 1) * T.SIZE.SLOT_LINE_H)

    local previous
    for i = 1, info._count do
        local badge = info._badges[i]
        badge:ClearAllPoints()
        if previous then
            badge:SetPoint(top, previous, bottom, 0, 0)
        else
            badge:SetPoint(top, info.row, top, 0, 0)
        end
        previous = badge
    end
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

    info.row      = row
    info._badges  = {}
    info._count   = 0
    info._edge    = "LEFT"

    --- Où la colonne se pose par rapport à l'emplacement.
    ---
    --- `"LEFT"` et `"RIGHT"` disent de quel côté ; `"ABOVE"` empile au-dessus,
    --- centré. Le bord d'alignement des pastilles est toujours celui qui touche
    --- la case : à gauche de l'icône elles s'alignent à droite, et inversement.
    ---@param where string  "LEFT", "RIGHT" ou "ABOVE"
    function info:SetPlacement(where)
        row:ClearAllPoints()

        if where == "ABOVE" then
            self._edge = nil
            row:SetPoint("BOTTOM", button, "TOP", 0, T.SIZE.SLOT_INFO_GAP)
        elseif where == "LEFT" then
            self._edge = "RIGHT"
            row:SetPoint("RIGHT", button, "LEFT", -T.SIZE.SLOT_INFO_GAP, 0)
        else
            self._edge = "LEFT"
            row:SetPoint("LEFT", button, "RIGHT", T.SIZE.SLOT_INFO_GAP, 0)
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

    --- Vide le bandeau sans rien libérer.
    function info:Clear()
        self:SetLevel(nil)
        self:BeginBadges()
        self:EndBadges()
    end

    info:Clear()
    info:SetPlacement("RIGHT")
    return info
end
