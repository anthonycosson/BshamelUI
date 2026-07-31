-- =========================================================================
--  Bshamel UI — UI/Widgets/SecureMenu.lua
--  Menu dont chaque ligne lance réellement une action du jeu.
--
--  Lancer un sort ou utiliser un objet depuis du code Lua est refusé par le
--  client : la seule voie est un bouton bâti sur son template sécurisé, à qui
--  l'on décrit l'action par des **attributs**. Le clic part alors du moteur, pas
--  de nous, et rien n'est automatisable.
--
--  Deux conséquences, et elles façonnent tout le fichier :
--
--  1. **Aucun attribut ne s'écrit en combat.** `SetEntries` refuse et rend
--     `false` ; l'appelant reconstruit à la sortie de combat. Le menu déjà bâti
--     reste utilisable — ce qui est interdit, c'est de le changer.
--  2. **Un bouton sécurisé ne se montre ni ne se cache en combat.** Le menu ne
--     s'ouvre donc pas pendant un combat. Ce n'est pas une privation : aucune
--     téléportation ne se lance en combat de toute façon.
--
--  Les lignes sont mises en réserve et réutilisées : une frame ne se détruit pas
--  (règle 7), et une ligne recyclée doit voir **tous** ses attributs d'action
--  réécrits, y compris ceux qu'elle n'utilise plus — sans quoi un clic
--  déclencherait l'action du contenu précédent.
--
--  Une entrée peut aussi ouvrir un **sous-menu** au survol. Le sous-menu est un
--  menu comme les autres, construit par cette même fabrique : c'est ce qui lui
--  donne les mêmes lignes sécurisées et les mêmes règles de combat.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local U    = BUI.Util
local W    = BUI.Widgets

---@class BUI.MenuEntry
---@field header? string    ligne de titre ; les autres champs sont alors ignorés
---@field submenu? table    { name, icon, entries } ; ouvre au survol
---@field kind? string      "item" | "toy" | "spell"
---@field id? number        identifiant, pour l'infobulle
---@field payload? any      valeur écrite dans l'attribut d'action
---@field name? string
---@field icon? number|string

--- Attributs d'action qu'une ligne peut porter. Ils sont tous réécrits à chaque
--- réemploi : ce qui n'est pas utilisé est remis à `nil`.
local PAYLOADS = { "item", "toy", "spell" }

-- =========================================================================
--  Pièces communes à toutes les lignes
-- =========================================================================

--- Icône à gauche, libellé à sa droite : la disposition d'une ligne, quelle que
--- soit sa nature.
---@param row table
local function dressRow(row)
    row:SetHeight(T.SIZE.MENU_ROW_H)

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(T.SIZE.MENU_ICON, T.SIZE.MENU_ICON)
    icon:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.icon = icon

    local label = row:CreateFontString(nil, "ARTWORK", T.FONT.LABEL_SMALL)
    label:SetPoint("LEFT", icon, "RIGHT", T.SIZE.MENU_GAP, 0)
    label:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    row.label = label

    row.Highlight = W.CenterGlow(row, T.COLOR.WHITE, T.ALPHA.ROW_HOVER)
end

-- =========================================================================
--  Temps de recharge
-- =========================================================================
-- Une ligne dit ce qu'elle lance ; elle doit aussi dire si elle peut le lancer.
-- Sans ce nombre, la seule façon de savoir qu'une pierre de foyer est en
-- recharge est de cliquer et de voir qu'il ne se passe rien.
--
-- Il ne s'affiche **que lorsqu'il y en a un** : une ligne prête ne porte rien.
-- C'est la présence du nombre qui est le signal, pas sa valeur — on lit le menu
-- pour choisir, pas pour compter.

--- Durée en deçà de laquelle un temps de recharge n'en est pas un.
---
--- Le temps de recharge **global** court sur presque tout ce que le personnage
--- connaît, et il dure une seconde et demie. L'afficher ferait clignoter le menu
--- entier à chaque sort lancé, pour une information que personne n'attend.
local GLOBAL_COOLDOWN = 1.5

--- Secondes restantes sur l'action d'une ligne, ou `nil` si elle est prête.
---
--- Un **jouet est un objet** : son temps de recharge se demande comme celui d'un
--- objet, avec son identifiant. C'est la même raison qui fait que le menu
--- résout ses entrées en demandant au client plutôt qu'en les écrivant.
---@param kind string|nil
---@param id number|nil
---@return number|nil
local function remainingCooldown(kind, id)
    if not (kind and id) then return nil end

    local start, duration

    if kind == "spell" then
        local get = C_Spell and C_Spell.GetSpellCooldown
        if get then
            -- Une table sur les clients récents, deux valeurs sur les autres :
            -- on accepte les deux formes plutôt que de parier sur celle du jour.
            local first, second = get(id)
            if type(first) == "table" then
                start, duration = first.startTime, first.duration
            else
                start, duration = first, second
            end
        end
    else
        local get = (C_Item and C_Item.GetItemCooldown) or GetItemCooldown
        if get then start, duration = get(id) end
    end

    if type(start) ~= "number" or type(duration) ~= "number" then return nil end
    if duration <= GLOBAL_COOLDOWN then return nil end

    local left = start + duration - GetTime()
    if left <= 0 then return nil end
    return left
end

-- =========================================================================
--  Lignes d'action
-- =========================================================================

---@param menu table
---@return table
local function newActionRow(menu)
    local template = T.Template("SECURE_ACTION")

    -- Une ligne n'est ancrée que par ses deux coins **hauts**, posés au moment
    -- du remplissage : ancrer aussi à gauche et à droite fixerait son centre
    -- vertical sur celui du menu, et une ligne contrainte en haut *et* au centre
    -- s'étire au lieu de garder sa hauteur.
    local row = CreateFrame("Button", nil, menu, template)
    dressRow(row)

    -- Le temps de recharge se lit à droite, en gris : c'est une précision sur la
    -- ligne, pas ce qu'on y cherche. Le libellé s'arrête avant lui, sans quoi un
    -- nom long passerait dessous.
    local cooldown = row:CreateFontString(nil, "ARTWORK", T.FONT.HINT)
    cooldown:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    cooldown:SetJustifyH("RIGHT")
    cooldown:SetTextColor(T.COLOR.DISABLED:GetRGB())
    row.cooldown = cooldown

    row.label:ClearAllPoints()
    row.label:SetPoint("LEFT", row.icon, "RIGHT", T.SIZE.MENU_GAP, 0)
    row.label:SetPoint("RIGHT", cooldown, "LEFT", -T.SIZE.MENU_GAP, 0)

    -- Le clic est pris au **relâchement** seulement. Enregistrer les deux
    -- phases fait partir l'action deux fois quand le joueur a demandé au client
    -- de lancer ses actions à l'enfoncement (voir `Modules/ActionBars.lua`), et
    -- la seconde annule la téléportation que la première avait commencée.
    row:RegisterForClicks("AnyUp")
    row:SetAttribute("useOnKeyDown", false)

    -- Pas d'infobulle sur une ligne : le menu **est** la réponse à la question
    -- qu'une infobulle poserait. Le nom et l'icône y sont déjà, et la fiche
    -- complète d'un sort n'apprend rien à qui cherche où se téléporter.
    row:SetScript("OnEnter", function(self)
        self.Highlight:SetShown(true)
        menu:CloseSubmenus()
    end)

    row:SetScript("OnLeave", function(self)
        self.Highlight:SetShown(false)
    end)

    -- `PostClick` et non `OnClick` : le second remplacerait le gestionnaire du
    -- template, c'est-à-dire l'action elle-même. Le premier s'exécute après.
    -- C'est le menu **racine** qu'on ferme : une ligne cliquée dans un sous-menu
    -- doit tout refermer, pas seulement le tiroir où elle se trouvait.
    row:SetScript("PostClick", function()
        menu:GetRoot():Close()
    end)

    return row
end

-- =========================================================================
--  Lignes de titre
-- =========================================================================

---@param menu table
---@return table
local function newHeaderRow(menu)
    local row = W.Container(menu)
    row:SetHeight(T.SIZE.MENU_ROW_H)

    local label = row:CreateFontString(nil, "ARTWORK", T.FONT.SECTION)
    label:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 2)
    label:SetJustifyH("LEFT")
    label:SetTextColor(T.COLOR.NORMAL:GetRGB())
    row.label = label

    return row
end

-- =========================================================================
--  Lignes qui ouvrent un sous-menu
-- =========================================================================

--- Ferme le sous-menu si le curseur n'est ni sur la ligne, ni dedans.
---
--- Le délai est ce qui rend le survol utilisable : entre la ligne et son
--- sous-menu il y a un écart, et sans lui le menu se refermerait sous le curseur
--- pendant la traversée.
---@param row table
local function closeIfLeft(row)
    C_Timer.After(T.TIMING.MENU_HOVER, function()
        local sub = row.submenu
        if not (sub and sub:IsShown()) then return end
        if row:IsMouseOver() or sub:IsMouseOver() then return end
        sub:Close()
    end)
end

---@param menu table
---@return table
local function newSubmenuRow(menu)
    local row = W.Container(menu)
    dressRow(row)
    row:EnableMouse(true)

    -- La flèche du client, celle de ses propres sous-menus. Sans elle, rien ne
    -- distingue une ligne qui ouvre d'une ligne qui agit.
    local arrow = row:CreateTexture(nil, "ARTWORK")
    arrow:SetSize(T.SIZE.MENU_ARROW, T.SIZE.MENU_ARROW)
    if not T.TrySetAtlas(arrow, T.ATLAS.ARROW_RIGHT) then arrow:Hide() end

    --- Range la flèche du côté où le sous-menu s'ouvrira, et la fait pointer
    --- dans cette direction. Une flèche qui vise à droite pendant que le tiroir
    --- part à gauche est pire qu'aucune flèche : elle indique le mauvais côté.
    ---
    --- La flèche du client ne pointe qu'à droite ; on la retourne d'un demi-tour
    --- plutôt que de nommer un second atlas qui pourrait ne pas exister.
    ---@param toLeft boolean
    function row:SetSide(toLeft)
        arrow:ClearAllPoints()
        self.icon:ClearAllPoints()
        self.label:ClearAllPoints()

        if toLeft then
            arrow:SetPoint("LEFT", self, "LEFT", 0, 0)
            arrow:SetRotation(math.pi)
            self.icon:SetPoint("LEFT", arrow, "RIGHT", T.SIZE.MENU_GAP, 0)
            self.label:SetPoint("RIGHT", self, "RIGHT", 0, 0)
        else
            arrow:SetPoint("RIGHT", self, "RIGHT", 0, 0)
            arrow:SetRotation(0)
            self.icon:SetPoint("LEFT", self, "LEFT", 0, 0)
            -- Le libellé s'arrête avant la flèche, sinon un nom long passe
            -- dessous.
            self.label:SetPoint("RIGHT", arrow, "LEFT", -T.SIZE.MENU_GAP, 0)
        end

        self.label:SetPoint("LEFT", self.icon, "RIGHT", T.SIZE.MENU_GAP, 0)
    end

    row:SetSide(false)

    row:SetScript("OnEnter", function(self)
        self.Highlight:SetShown(true)
        menu:CloseSubmenus(self)
        if self.submenu then
            self.submenu:PlaceBeside(self)
            self.submenu:Open()
        end
    end)

    row:SetScript("OnLeave", function(self)
        self.Highlight:SetShown(false)
        closeIfLeft(self)
    end)

    return row
end

-- =========================================================================
--  Fabrique
-- =========================================================================

--- Menu vertical d'actions du jeu, fermé au départ.
--- Renvoie `nil` si le client n'expose pas de template d'action sécurisée :
--- l'appelant doit alors se passer de menu plutôt qu'échouer.
---@param parent table
---@param root? table  menu racine, pour un sous-menu
---@return table|nil
function W.SecureMenu(parent, root)
    if not T.Template("SECURE_ACTION") then return nil end

    local menu = CreateFrame("Frame", nil, parent)
    menu:SetFrameStrata("DIALOG")
    menu:SetWidth(T.SIZE.MENU_W)
    menu:SetHeight(T.SIZE.MENU_ROW_H)
    menu:SetClampedToScreen(true)
    menu:Hide()

    -- Un sous-menu se dessine au-dessus du menu qui l'ouvre.
    if root then menu:SetFrameLevel(parent:GetFrameLevel() + 10) end

    local background = menu:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    T.WindowSurface(background)

    local border = W.Inset(menu)
    border:SetAllPoints()

    menu._root = root

    -- Seul le menu racine surveille les clics extérieurs : il ferme ses tiroirs
    -- avec lui, et deux veilles se disputeraient le même clic.
    if not root then
        W.CloseOnOutsideClick(menu, function() menu:Close() end, function()
            if menu:IsMouseOverTree() then return true end
            return menu._opener ~= nil and menu._opener:IsMouseOver()
        end)
    end

    local actionRows  = {}
    local headerRows  = {}
    local submenuRows = {}

    ---@return table
    function menu:GetRoot()
        return self._root or self
    end

    --- Côté vers lequel ce menu et ses tiroirs s'ouvrent. Décidé une fois, au
    --- moment où le menu se place : tout ce qui s'ouvrira ensuite part du même
    --- côté, sans quoi un sous-menu repartirait vers l'écran qu'on vient de
    --- quitter.
    ---@param toLeft boolean
    function menu:SetSide(toLeft)
        self._toLeft = toLeft
        for i = 1, #submenuRows do
            submenuRows[i]:SetSide(toLeft)
        end
    end

    --- Le curseur est-il sur ce menu **ou sur l'un de ses tiroirs ouverts** ?
    --- Un sous-menu est un cadre à part, posé à côté : il sort du rectangle de
    --- son parent, et la question doit donc descendre l'arbre.
    ---@return boolean
    function menu:IsMouseOverTree()
        if self:IsMouseOver() then return true end

        for i = 1, #submenuRows do
            local sub = submenuRows[i].submenu
            if sub and sub:IsShown() and sub:IsMouseOverTree() then return true end
        end
        return false
    end

    --- Repose le temps de recharge des lignes visibles.
    ---
    --- Les lignes cachées sont ignorées : elles ne montrent rien, et le menu en
    --- garde en réserve autant qu'il en a affiché au maximum (règle 7).
    local function refreshCooldowns()
        for i = 1, #actionRows do
            local row = actionRows[i]
            if row:IsShown() then
                local left = remainingCooldown(row._kind, row._id)
                row.cooldown:SetText(left and U.Clock(left) or "")
            end
        end
    end

    -- Le seul `OnUpdate` du menu, et il ne tourne que pendant qu'il est ouvert —
    -- un cadre caché n'en reçoit pas. Bridé, comme tout `OnUpdate` (règle 7).
    menu:SetScript("OnUpdate", U.Throttle(T.TIMING.MENU_COOLDOWN, refreshCooldowns))

    --- Ferme tous les sous-menus ouverts, sauf celui de `keep`.
    ---@param keep? table
    function menu:CloseSubmenus(keep)
        for i = 1, #submenuRows do
            local row = submenuRows[i]
            if row ~= keep and row.submenu then row.submenu:Close() end
        end
    end

    --- Décrit une action sur une ligne recyclée. Tous les attributs de charge
    --- sont réécrits, y compris ceux qui ne servent pas à cette entrée-là.
    ---@param row table
    ---@param entry BUI.MenuEntry
    local function describe(row, entry)
        row:SetAttribute("type", entry.kind)
        for i = 1, #PAYLOADS do
            local payload = PAYLOADS[i]
            row:SetAttribute(payload, payload == entry.kind and entry.payload or nil)
        end

        row._kind = entry.kind
        row._id   = entry.id
        row.icon:SetTexture(entry.icon)
        row.label:SetText(entry.name or "")
    end

    --- Remplit le menu. Rend `false` si le client est en combat : les attributs
    --- d'un bouton sécurisé ne s'y écrivent pas, et le menu reste alors tel
    --- qu'il était.
    ---@param entries BUI.MenuEntry[]
    ---@return boolean applied
    function menu:SetEntries(entries)
        if InCombatLockdown() then return false end

        local actions, headers, submenus = 0, 0, 0
        local y = -T.SIZE.MENU_PAD

        for i = 1, #entries do
            local entry = entries[i]
            local row

            if entry.header then
                headers = headers + 1
                row = headerRows[headers]
                if not row then
                    row = newHeaderRow(self)
                    headerRows[headers] = row
                end
                row.label:SetText(string.upper(entry.header))

            elseif entry.submenu then
                submenus = submenus + 1
                row = submenuRows[submenus]
                if not row then
                    row = newSubmenuRow(self)
                    submenuRows[submenus] = row
                end

                row.submenu = row.submenu or W.SecureMenu(self, self:GetRoot())
                row.icon:SetTexture(entry.submenu.icon)
                row.label:SetText(entry.submenu.name or "")
                if row.submenu then row.submenu:SetEntries(entry.submenu.entries) end

            else
                actions = actions + 1
                row = actionRows[actions]
                if not row then
                    row = newActionRow(self)
                    actionRows[actions] = row
                end
                describe(row, entry)
            end

            row:ClearAllPoints()
            row:SetPoint("TOPLEFT",  self, "TOPLEFT",   T.SIZE.MENU_PAD, y)
            row:SetPoint("TOPRIGHT", self, "TOPRIGHT", -T.SIZE.MENU_PAD, y)
            row:Show()
            y = y - T.SIZE.MENU_ROW_H
        end

        -- Les lignes en trop sont cachées, jamais détruites : le menu se
        -- reconstruit à chaque objet qui entre dans les sacs.
        for i = actions  + 1, #actionRows  do actionRows[i]:Hide() end
        for i = headers  + 1, #headerRows  do headerRows[i]:Hide() end
        for i = submenus + 1, #submenuRows do submenuRows[i]:Hide() end

        -- Les lignes créées à l'instant ignorent le côté déjà choisi : on le
        -- leur repose, plutôt que de le retenir dans chaque fabrique de ligne.
        self:SetSide(self._toLeft == true)

        self:SetHeight(math.abs(y) + T.SIZE.MENU_PAD)
        self._filled = (actions + submenus) > 0

        -- Tout de suite, et pas au prochain passage : une ligne recyclée porte
        -- encore le temps de recharge de ce qu'elle affichait avant.
        refreshCooldowns()
        return true
    end

    ---@return boolean
    function menu:HasEntries()
        return self._filled == true
    end

    --- Ancre le menu à côté du bouton qui l'ouvre, du côté où il y a la place.
    ---@param button table
    function menu:PlaceNear(button)
        -- Retenu pour la fermeture au clic extérieur : le bouton qui ouvre n'est
        -- pas « ailleurs ».
        self._opener = button

        local centerX = button:GetCenter()
        local toLeft  = (centerX or 0) > (GetScreenWidth() / 2)
        self:SetSide(toLeft)

        self:ClearAllPoints()
        if toLeft then
            self:SetPoint("TOPRIGHT", button, "TOPLEFT", -T.SIZE.MENU_GAP, 0)
        else
            self:SetPoint("TOPLEFT", button, "TOPRIGHT", T.SIZE.MENU_GAP, 0)
        end
    end

    --- Ancre un sous-menu contre la ligne qui l'ouvre, du même côté que le menu
    --- qui la porte : un sous-menu qui repartirait vers la droite alors que le
    --- menu s'est ouvert vers la gauche sortirait de l'écran.
    ---@param row table
    function menu:PlaceBeside(row)
        -- Le côté est celui du menu racine, pas celui de la ligne : c'est le
        -- premier placement qui a décidé de la direction, et tout ce qui s'ouvre
        -- ensuite la suit.
        local toLeft = self:GetRoot()._toLeft == true
        self:SetSide(toLeft)

        self:ClearAllPoints()
        if toLeft then
            self:SetPoint("TOPRIGHT", row, "TOPLEFT", -T.SIZE.MENU_GAP, T.SIZE.MENU_PAD)
        else
            self:SetPoint("TOPLEFT", row, "TOPRIGHT", T.SIZE.MENU_GAP, T.SIZE.MENU_PAD)
        end
    end

    --- Ferme le menu et ce qu'il a ouvert. Sans effet en combat : ses lignes
    --- sont des cadres protégés, que le client refuse de cacher tant que le
    --- combat dure.
    function menu:Close()
        if InCombatLockdown() then return end
        self:CloseSubmenus()
        self:Hide()
    end

    function menu:Open()
        if InCombatLockdown() then return end
        self:Show()
    end

    --- Ouvre ou ferme. Rend `false` si le combat l'interdit, pour que l'appelant
    --- puisse le dire au joueur plutôt que de paraître ne rien faire.
    ---@return boolean acted
    function menu:Toggle()
        if InCombatLockdown() then return false end
        if self:IsShown() then self:Close() else self:Open() end
        return true
    end

    return menu
end
