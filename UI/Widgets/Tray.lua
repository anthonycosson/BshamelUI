-- =========================================================================
--  Bshamel UI — UI/Widgets/Tray.lua
--  Tiroir : un panneau qui **emprunte** les boutons d'autres addons.
--
--  Le tiroir ne crée aucun bouton. Il prend ceux qui existent déjà autour de la
--  minicarte, les range en grille, et sait tout rendre exactement où il les a
--  trouvés. C'est ce dernier point qui décide de la forme du fichier : chaque
--  emprunt relève le parent, les ancrages, la strate et le niveau du cadre avant
--  d'y toucher, et `ReleaseAll` les repose (CLAUDE.md règle 6).
--
--  **Verrouiller les ancrages fait partie de l'emprunt.** Un bouton de
--  bibliothèque se replace tout seul sur le pourtour de la minicarte, sans
--  prévenir : il suffit qu'il rafraîchisse sa position pour ressortir du tiroir
--  et se reposer sur la carte, alors même qu'il est notre enfant. On masque donc
--  `SetPoint` et `ClearAllPoints` sur le cadre emprunté, et on garde les vraies
--  méthodes pour notre propre mise en page. Le masquage se retire au retour :
--  une méthode qui n'appartenait pas au cadre redevient absente, une méthode
--  qu'il portait lui-même lui est rendue.
--
--  Le tiroir ne connaît pas la base de données et ne choisit pas *quels* boutons
--  il range : l'appelant lui donne une liste (voir `UI/MinimapDock.lua`).
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local W    = BUI.Widgets

--- Remplace une méthode d'ancrage le temps de l'emprunt. Ne rien faire est le
--- comportement voulu : le cadre est rangé, sa position ne lui appartient plus.
local function locked() end

-- =========================================================================
--  Le nom de l'addon, tiré du nom du cadre
-- =========================================================================
-- Un bouton de minicarte ne publie nulle part l'addon auquel il appartient. Son
-- **nom de cadre**, en revanche, le contient presque toujours — les
-- bibliothèques d'icônes le construisent à partir de lui. On le débarrasse donc
-- de ce qui est de la plomberie et pas du nom : le préfixe de la bibliothèque, et
-- le « MinimapButton » que tout le monde colle au bout.
--
-- Le résultat n'est pas garanti joli. Il est garanti **stable et reconnaissable**,
-- ce qui est ce qu'on demande à une liste où l'on cherche un addon des yeux.

local NAME_PREFIXES = { "^LibDBIcon10_", "^Lib_GPI_Minimap_" }
local NAME_SUFFIXES = {
    "[_%-]?[Mm]inimap[_%-]?[Bb]utton$",
    "[_%-]?[Mm]inimap[_%-]?[Ii]con$",
    "[_%-]?[Mm]inimap[_%-]?[Ff]rame$",
    "[_%-]?[Mm]inimap$",
    "[_%-]?[Bb]utton$",
}

---@param name string
---@return string
local function addonLabel(name)
    local label = name

    for i = 1, #NAME_PREFIXES do label = label:gsub(NAME_PREFIXES[i], "") end
    for i = 1, #NAME_SUFFIXES do label = label:gsub(NAME_SUFFIXES[i], "") end

    label = label:gsub("[_%-]+", " "):gsub("^%s+", ""):gsub("%s+$", "")

    -- Tout retirer laisserait une ligne muette : le nom brut vaut mieux que rien.
    if label == "" then return name end
    return label
end

-- =========================================================================
--  Rejouer les gestes du bouton emprunté
-- =========================================================================
-- Cliquer le nom doit faire ce que fait cliquer l'icône, et le survoler doit
-- montrer la même infobulle. On ne réimplémente donc rien : on **rejoue** les
-- scripts du bouton, qui restent les siens.

--- Rejoue un script du cadre emprunté (`OnEnter`, `OnLeave`).
---@param entry? table
---@param script string
local function replay(entry, script)
    local frame = entry and entry.frame
    if not frame then return end

    local handler = frame:GetScript(script)
    if handler then handler(frame) end
end

--- Clique le cadre emprunté.
---
--- **Il y a deux façons de brancher un clic, et les deux sont utilisées.** La
--- normale est `OnClick` ; l'autre est d'écouter la souris (`OnMouseUp`), ce que
--- font les boutons écrits à la main plutôt qu'avec une bibliothèque d'icônes.
--- `Click` ne déclenche que la première : sur un bouton de la seconde sorte,
--- elle ne fait **rien du tout**, sans erreur ni signe — le nom paraît mort
--- alors que l'icône, elle, répond.
---
--- On regarde donc ce que le bouton écoute avant de le solliciter. Jamais les
--- deux : un bouton qui porte les deux scripts agirait deux fois.
---@param entry? table
---@param mouseButton string
local function press(entry, mouseButton)
    local frame = entry and entry.frame
    if not frame then return end

    local click = frame:GetScript("OnClick")
    if click then
        -- `Click` plutôt que le script : elle traverse aussi ce que l'addon a
        -- posé avant et après (`PreClick`, `PostClick`).
        if frame.Click then frame:Click(mouseButton) else click(frame, mouseButton, false) end
        return
    end

    -- L'appui **et** le relâchement, dans cet ordre : un bouton qui n'écoute que
    -- l'un des deux reçoit ce qu'il attend, un bouton qui écoute les deux reçoit
    -- la séquence complète.
    local down = frame:GetScript("OnMouseDown")
    local up   = frame:GetScript("OnMouseUp")

    if down then down(frame, mouseButton) end
    if up   then up(frame, mouseButton) end
end

-- =========================================================================
--  Emprunt et restitution d'un cadre
-- =========================================================================

--- Relève tout ce qu'il faudra reposer, puis range le cadre sous le tiroir.
---@param panel table
---@param frame table
---@return table entry
local function capture(panel, frame)
    local name  = frame:GetName() or tostring(frame)
    local entry = {
        frame  = frame,
        name   = name,
        label  = addonLabel(name),
        parent = frame:GetParent(),
        level  = frame:GetFrameLevel(),
        points = {},

        -- Les vraies méthodes, prises **avant** d'être masquées : c'est par
        -- elles que le tiroir place ses cases.
        setPoint       = frame.SetPoint,
        clearAllPoints = frame.ClearAllPoints,

        -- Le cadre portait-il ces méthodes lui-même, ou les tenait-il de sa
        -- métatable ? La question ne se pose qu'au retour : dans le second cas
        -- il faut les effacer, pas les réécrire.
        ownSetPoint    = rawget(frame, "SetPoint") ~= nil,
        ownClearPoints = rawget(frame, "ClearAllPoints") ~= nil,
    }

    for i = 1, frame:GetNumPoints() do
        -- Cinq valeurs fixes, et non la longueur de la table : `relativeTo` vaut
        -- `nil` pour un cadre ancré sans référence, et un trou au milieu rendrait
        -- `unpack` imprévisible à la restitution.
        entry.points[i] = { frame:GetPoint(i) }
    end

    -- **La strate du cadre emprunté n'est pas touchée.** C'est le tiroir qui
    -- s'aligne sur la sienne (voir la fabrique), et pas l'inverse : un bouton de
    -- minicarte porte souvent son icône sur un sous-cadre à lui, dont la strate
    -- est fixée séparément. Relever le bouton sans relever ses enfants faisait
    -- passer l'icône **sous le fond du tiroir** — on ne voyait plus que
    -- l'anneau, avec un disque noir au milieu.
    --
    -- Le niveau, lui, est imposé : dix au-dessus du panneau, la bordure en
    -- occupant un et le reste servant à ce que le client ajouterait au template.
    frame:SetParent(panel)
    frame:SetFrameLevel(panel:GetFrameLevel() + 10)

    -- Les vraies méthodes tant qu'elles sont encore en place ; le masquage vient
    -- juste après, et à partir de là c'est le relevé qui sert.
    frame:ClearAllPoints()
    frame.SetPoint       = locked
    frame.ClearAllPoints = locked

    return entry
end

---@param entry table
local function restore(entry)
    local frame = entry.frame

    -- Le masquage se retire d'abord : à partir d'ici le cadre répond de nouveau
    -- lui-même, et c'est lui qu'on repositionne.
    frame.SetPoint       = entry.ownSetPoint and entry.setPoint or nil
    frame.ClearAllPoints = entry.ownClearPoints and entry.clearAllPoints or nil

    frame:ClearAllPoints()
    frame:SetParent(entry.parent)
    frame:SetFrameLevel(entry.level)

    for i = 1, #entry.points do
        frame:SetPoint(unpack(entry.points[i], 1, 5))
    end
end

-- =========================================================================
--  Fabrique
-- =========================================================================

--- Tiroir, fermé au départ. Il se place contre le bouton qui l'ouvre
--- (`PlaceNear`), et non à une position fixe : c'est ce bouton-là qui décide de
--- l'endroit, et il se déplace autour de la minicarte.
---@param parent table
---@param emptyText string  ce qu'on lit quand il n'y a rien à ranger
---@return table
function W.Tray(parent, emptyText)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetSize(T.SIZE.TRAY_CELL, T.SIZE.TRAY_CELL)
    panel:SetClampedToScreen(true)
    panel:Hide()

    -- Le tiroir se met à la strate des boutons qu'il accueille, celle de la
    -- minicarte : c'est la seule façon de garantir que leurs icônes se dessinent
    -- au-dessus de son fond sans avoir à relever chaque sous-cadre de chacun.
    -- Une strate plus haute pour le tiroir remonterait le fond et laisserait les
    -- icônes dessous.
    panel:SetFrameStrata(Minimap and Minimap:GetFrameStrata() or "MEDIUM")

    -- Même fond que la fenêtre d'options, bordure du client par-dessus : le
    -- tiroir est une petite fenêtre, il se lit comme le reste de l'addon.
    local background = panel:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    T.WindowSurface(background)

    local border = W.Inset(panel)
    border:SetAllPoints()

    -- Un tiroir vide s'ouvre quand même, et le dit. Une fenêtre qui refuse de
    -- s'ouvrir ne se distingue pas d'un bouton cassé — alors qu'« aucune icône
    -- d'addon à afficher » est une réponse, et souvent la bonne nouvelle.
    local empty = panel:CreateFontString(nil, "ARTWORK", T.FONT.LABEL_SMALL)
    empty:SetPoint("TOPLEFT", panel, "TOPLEFT", T.SIZE.TRAY_PAD, -T.SIZE.TRAY_PAD)
    empty:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -T.SIZE.TRAY_PAD, -T.SIZE.TRAY_PAD)
    empty:SetJustifyH("LEFT")
    empty:SetWordWrap(true)
    empty:SetTextColor(T.COLOR.DISABLED:GetRGB())
    empty:SetText(emptyText or "")
    empty:Hide()

    --- cadre emprunté -> son relevé
    local entries = {}
    --- les mêmes, dans l'ordre d'affichage
    local order = {}
    --- lignes en réserve : une frame ne se détruit pas (règle 7)
    local rows = {}

    --- Ligne du tiroir : le bouton emprunté à gauche, le nom de son addon à
    --- droite. Même disposition et même police que le menu de téléportation —
    --- c'est la même liste, avec des icônes qui ne nous appartiennent pas.
    ---
    --- **Toute la ligne agit comme le bouton.** Le nom n'est pas une étiquette
    --- posée à côté d'une cible minuscule : il est cliquable et survolable comme
    --- l'icône, et ce qu'il déclenche est le geste du bouton lui-même — on
    --- rejoue ses scripts, on ne réimplémente pas ce qu'il fait.
    ---@param index integer
    ---@return table
    local function rowAt(index)
        local row = rows[index]
        if row then return row end

        row = CreateFrame("Button", nil, panel)
        row:SetHeight(T.SIZE.TRAY_CELL)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        local label = row:CreateFontString(nil, "ARTWORK", T.FONT.LABEL_SMALL)
        label:SetPoint("LEFT", row, "LEFT", T.SIZE.TRAY_CELL + T.SIZE.MENU_GAP, 0)
        label:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)
        row.label = label

        row.Highlight = W.CenterGlow(row, T.COLOR.WHITE, T.ALPHA.ROW_HOVER)

        row:SetScript("OnEnter", function(self)
            self.Highlight:SetShown(true)
            -- L'infobulle est celle de l'addon, telle qu'il l'écrit : elle
            -- s'ancre à son bouton, donc à gauche de la ligne survolée.
            replay(self.entry, "OnEnter")
        end)

        row:SetScript("OnLeave", function(self)
            self.Highlight:SetShown(false)
            replay(self.entry, "OnLeave")
        end)

        row:SetScript("OnClick", function(self, mouseButton)
            press(self.entry, mouseButton)
        end)

        rows[index] = row
        return row
    end

    --- Empile les lignes. Trié sur le nom **affiché** : `GetChildren` ne garantit
    --- aucun ordre, et une liste qui se réarrange à chaque session serait
    --- illisible.
    local function layout()
        table.sort(order, function(a, b) return a.label < b.label end)

        local count = #order
        local y     = -T.SIZE.TRAY_PAD

        panel:SetWidth(T.SIZE.MENU_W)
        empty:SetShown(count == 0)

        if count == 0 then
            for i = 1, #rows do rows[i]:Hide() end
            panel:SetHeight(T.SIZE.TRAY_PAD * 2 + math.max(empty:GetStringHeight(), T.SIZE.TRAY_CELL))
            return
        end

        for i = 1, count do
            local entry = order[i]
            local row   = rowAt(i)

            row:ClearAllPoints()
            row:SetPoint("TOPLEFT",  panel, "TOPLEFT",   T.SIZE.TRAY_PAD, y)
            row:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -T.SIZE.TRAY_PAD, y)
            row.label:SetText(entry.label)
            row.entry = entry
            row:Show()

            -- Le bouton est rangé **dans** sa ligne : elle devient son parent,
            -- donc il la suit sans qu'on ait à le replacer à chaque tri. Il est
            -- centré sur la colonne d'icônes, dont la largeur est celle d'un
            -- bouton de minicarte : ils n'ont pas tous la même taille, et c'est
            -- le centre qui les aligne, pas le bord.
            entry.frame:SetParent(row)
            entry.clearAllPoints(entry.frame)
            entry.setPoint(entry.frame, "CENTER", row, "LEFT", T.SIZE.TRAY_CELL / 2, 0)

            y = y - T.SIZE.TRAY_CELL
        end

        for i = count + 1, #rows do rows[i]:Hide() end

        panel:SetHeight(math.abs(y) + T.SIZE.TRAY_PAD)
    end

    --- Range les cadres qui ne le sont pas encore. Les cadres déjà rangés qui ne
    --- sont plus dans la liste y restent : un addon qui cache son bouton un
    --- instant ne doit pas le voir ressortir sur la carte.
    ---@param frames table[]
    function panel:Hold(frames)
        local changed = false

        for i = 1, #frames do
            local frame = frames[i]
            if frame and not entries[frame] then
                local entry = capture(self, frame)
                entries[frame] = entry
                order[#order + 1] = entry
                changed = true
            end
        end

        -- Un addon peut reprendre son bouton sans rien nous dire — une
        -- bibliothèque le rattache à la minicarte quand elle le rafraîchit. Le
        -- bouton sortirait alors du tiroir avec ses ancrages masqués, c'est-à-dire
        -- posé n'importe où et impossible à bouger. On le reprend.
        for i = 1, #order do
            local frame = order[i].frame
            if frame:GetParent() ~= self then
                frame:SetParent(self)
                changed = true
            end
        end

        if changed then layout() end
    end

    --- Rend chaque cadre à l'endroit exact où il a été pris.
    function panel:ReleaseAll()
        for i = 1, #order do
            restore(order[i])
        end
        wipe(order)
        wipe(entries)
        self:Hide()
    end

    ---@param frame table
    ---@return boolean
    function panel:IsHolding(frame)
        return entries[frame] ~= nil
    end

    ---@return integer
    function panel:Count()
        return #order
    end

    --- Ancre le tiroir à côté du bouton qui l'ouvre, du côté où il y a la place.
    --- Même geste que le menu de téléportation : les deux s'ouvrent depuis le
    --- pourtour de la minicarte, qui est un bord d'écran une fois sur deux.
    ---@param button table
    function panel:PlaceNear(button)
        -- Retenu pour la fermeture au clic extérieur : le bouton qui ouvre n'est
        -- pas « ailleurs ».
        self._opener = button

        local centerX = button:GetCenter()
        local toLeft  = (centerX or 0) > (GetScreenWidth() / 2)

        self:ClearAllPoints()
        if toLeft then
            self:SetPoint("TOPRIGHT", button, "TOPLEFT", -T.SIZE.TRAY_GAP, 0)
        else
            self:SetPoint("TOPLEFT", button, "TOPRIGHT", T.SIZE.TRAY_GAP, 0)
        end
    end

    function panel:Toggle()
        self:SetShown(not self:IsShown())
    end

    W.CloseOnOutsideClick(panel, function() panel:Hide() end, function()
        return panel._opener ~= nil and panel._opener:IsMouseOver()
    end)

    -- Une première mise en page, tiroir vide : sans elle le panneau garde la
    -- taille d'une case et son message d'attente reste caché, si bien qu'un
    -- tiroir qui n'a **jamais** rien reçu s'ouvre sur un carré muet.
    layout()

    return panel
end
