-- =========================================================================
--  Bshamel UI — UI/Config/PageBuilder.lua
--  Traduit la table `options` d'un module en widgets.
--
--  C'est la pièce qui rend le design cohérent par construction : un module ne
--  choisit ni position, ni taille, ni police. Il décrit ses réglages, et cette
--  fonction les dispose toujours de la même façon.
--
--  Descripteurs reconnus :
--      { type = "header",      text = ... }
--      { type = "toggle",      key = ..., text = ..., tooltip = ... }
--      { type = "slider",      key = ..., text = ..., min = , max = , step = , decimals = }
--      { type = "dropdown",    key = ..., text = ..., values = { { value=, label= }, ... } }
--          `values` accepte aussi une **fonction** qui rend cette liste, pour un
--          choix qui dépend du personnage et n'est pas connu à la construction.
--      { type = "color",       key = ..., text = ... }
--          la valeur est une table `{ r = , g = , b = }` ; le sélecteur est
--          celui du client (voir `UI/Widgets/ColorSwatch.lua`).
--      { type = "button",      text = ..., label = ..., onClick = function() end }
--      { type = "description", text = ... }
--      { type = "spacer",      height = 10 }
--      { type = "column" }
--          coupure : tout ce qui suit se pose dans une seconde colonne, à
--          droite — si la page est assez large pour deux (voir `layout`).
--
--  Champs communs facultatifs :
--      indent   = true                               -- sous-option : la ligne
--                                                    -- ne veut rien dire sans
--                                                    -- celle du dessus
--      disabled = function() return true|false end   -- grise la ligne
--      disabledReason = "..." | function(): string   -- expliqué en infobulle
--      hidden   = function() return true|false end   -- retire la ligne du flux
--      get / set                                     -- si le réglage ne vient
--                                                    -- pas de `key`
--
--  Les pages sont créées une fois puis réutilisées : une frame World of Warcraft
--  ne se détruit pas, la recréer à chaque changement de page fuirait.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local W    = BUI.Widgets
local L    = ns.L

local PB = {}
BUI.PageBuilder = PB

--- moduleName -> frame de page
local pages = {}

-- =========================================================================
--  Construction
-- =========================================================================

local function accessors(mod, descriptor)
    local get = descriptor.get
    local set = descriptor.set

    if not get and descriptor.key then
        get = function() return mod:Get(descriptor.key) end
    end
    if not set and descriptor.key then
        set = function(value) mod:Set(descriptor.key, value) end
    end

    return get, set
end

--- Instancie un descripteur. Renvoie la frame créée, ou `nil` pour un
--- descripteur non reconnu (ignoré silencieusement plutôt que fatal).
local function buildWidget(page, mod, descriptor)
    local kind = descriptor.type
    local get, set = accessors(mod, descriptor)

    if kind == "header" then
        return W.SectionHeader(page, descriptor.text)

    elseif kind == "toggle" then
        return W.Toggle(page, {
            text    = descriptor.text,
            tooltip = descriptor.tooltip,
            indent  = descriptor.indent,
            get     = get,
            set     = set,
        })

    elseif kind == "slider" then
        return W.Slider(page, {
            text     = descriptor.text,
            tooltip  = descriptor.tooltip,
            indent   = descriptor.indent,
            min      = descriptor.min or 0,
            max      = descriptor.max or 100,
            step     = descriptor.step,
            decimals = descriptor.decimals,
            get      = get,
            set      = set,
        })

    elseif kind == "dropdown" then
        return W.Dropdown(page, {
            text    = descriptor.text,
            tooltip = descriptor.tooltip,
            indent  = descriptor.indent,
            values  = descriptor.values or {},
            get     = get,
            set     = set,
        })

    elseif kind == "color" then
        return W.ColorSwatch(page, {
            text    = descriptor.text,
            tooltip = descriptor.tooltip,
            indent  = descriptor.indent,
            get     = get,
            set     = set,
        })

    elseif kind == "button" then
        local row = W.Row(page, descriptor.text)
        local button = W.Button(row, descriptor.label or descriptor.text, descriptor.onClick)
        W.PlaceControl(row, button)
        W.Tooltip(button, descriptor.text, descriptor.tooltip)
        return row

    elseif kind == "description" then
        return W.Description(page, descriptor.text)

    elseif kind == "warning" then
        return W.Warning(page, descriptor.text)

    elseif kind == "spacer" then
        local spacer = W.Row(page, nil)
        spacer:SetHeight(descriptor.height or T.SIZE.SECTION_GAP)
        spacer.label:Hide()
        return spacer
    end

    BUI:Warn("descripteur d'option inconnu : " .. tostring(kind))
    return nil
end

--- Place qu'il faudrait à cette ligne pour écrire son libellé en entier.
---
--- La contrainte de largeur est **levée le temps de la mesure**. Une chaîne bornée
--- rend volontiers la largeur qu'on lui a imposée plutôt que la sienne : la
--- colonne mesurerait alors sa propre limite, et ne pourrait jamais s'élargir.
--- `Arrange` repose une largeur juste après, dans la même passe.
---
--- Sans mesure lisible on rend zéro : la colonne garde `CONTROL_X`, c'est-à-dire
--- ce qu'elle faisait avant qu'on sache mesurer.
---@param frame table
---@return number
local function labelReach(frame)
    local label = frame.label
    if not (label and type(label.GetStringWidth) == "function") then return 0 end

    label:SetWidth(0)
    local text = label:GetStringWidth()
    if BUI.Util.IsSecret(text) or type(text) ~= "number" then return 0 end

    return (frame._labelX or 0) + text + T.SIZE.LABEL_INDENT
end

--- Abscisse à laquelle les contrôles s'alignent, une par colonne.
---
--- `CONTROL_X` est le **plancher** autant que la référence : une colonne ne
--- remonte jamais au-dessus, et c'est ce qui fait qu'une case à cocher tombe au
--- même endroit d'une page à l'autre dès que les libellés sont courts. Elle
--- recule quand il le faut, jusqu'au plus long libellé qu'elle porte — « Augmenter
--- la distance maximale de la caméra » ne tenait pas, et un intitulé coupé ne se
--- lit pas.
---
--- **C'est la colonne entière qui bouge, jamais la ligne fautive seule.** Une case
--- décalée au milieu de dix autres se lit comme un défaut d'alignement, ce qui est
--- pire que le texte coupé qu'on voulait réparer.
---
--- Le plafond est la place que le contrôle réclame à droite : une colonne qui
--- reculerait au-delà gagnerait un libellé entier en poussant les glissières hors
--- du cadre.
---@param page table
---@param split boolean
---@param colWidth number
---@return table  { colonne 1, colonne 2 }
local function columnControlX(page, split, colWidth)
    local S       = T.SIZE
    local entries = page._entries
    local at      = { S.CONTROL_X, S.CONTROL_X }
    local col     = 1

    for i = 1, #entries do
        if split and page._breakAt == i - 1 then col = 2 end

        local entry  = entries[i]
        local hidden = entry.descriptor.hidden and entry.descriptor.hidden() or false

        -- Seules les lignes qui portent un contrôle décident de la colonne : un
        -- paragraphe ou un en-tête court sur toute la largeur et n'a rien à
        -- aligner.
        if not hidden and entry.frame.control then
            local reach = labelReach(entry.frame)
            if reach > at[col] then at[col] = reach end
        end
    end

    local ceiling = colWidth - S.CONTROL_RESERVE
    for c = 1, 2 do
        if at[c] > ceiling then
            at[c] = (ceiling > S.CONTROL_X) and ceiling or S.CONTROL_X
        end
    end

    return at
end

--- Empile les widgets et renvoie la hauteur totale utilisée.
---
--- Une page peut demander une **coupure de colonne** : tout ce qui suit se pose
--- alors dans une seconde colonne, à droite. C'est un vœu, pas un ordre — la
--- coupure n'est honorée que si les deux moitiés restent assez larges pour porter
--- un libellé lisible à côté de son contrôle (`COLUMN_MIN_W`). Sinon la page
--- retombe sur une colonne unique et la coupure ne fait rien.
---
--- Ce repli n'est pas une prudence de plus : une fenêtre étroite, ou un joueur
--- qui a réduit l'échelle du contenu, changent la largeur disponible d'un facteur
--- deux. Une découpe imposée y gagnerait de la hauteur en tronquant les
--- intitulés, c'est-à-dire en rendant illisible ce qu'elle voulait rendre plus
--- visible.
local function layout(page)
    local S = T.SIZE
    local entries = page._entries
    local width   = page:GetWidth() or 0

    local split    = page._breakAt ~= nil
                     and width >= S.COLUMN_MIN_W * 2 + S.COLUMN_GAP
    local colWidth = split and (width - S.COLUMN_GAP) / 2 or width

    -- Relevé **avant** de poser quoi que ce soit : chaque ligne a besoin de la
    -- décision de sa colonne pour se répartir, et cette décision se prend en
    -- regardant toutes les lignes.
    local controlX = columnControlX(page, split, colWidth)

    -- Une ordonnée par colonne, et le rang de la première ligne de chacune : un
    -- en-tête respire davantage, sauf en tête de sa propre colonne.
    local y     = { -S.PADDING, -S.PADDING }
    local first = { true, true }
    local col   = 1

    for i = 1, #entries do
        local entry = entries[i]
        local hidden = entry.descriptor.hidden and entry.descriptor.hidden() or false

        if split and page._breakAt == i - 1 then col = 2 end

        if hidden then
            entry.frame:Hide()
        else
            if entry.descriptor.type == "header" and not first[col] then
                y[col] = y[col] - S.SECTION_GAP
            end
            first[col] = false

            local x = (col == 2) and (colWidth + S.COLUMN_GAP) or 0

            entry.frame:Show()
            entry.frame:ClearAllPoints()
            entry.frame:SetPoint("TOPLEFT", page, "TOPLEFT", x, y[col])
            if colWidth > 0 then entry.frame:SetWidth(colWidth) end

            entry.frame._controlX = controlX[col]

            -- La largeur vient d'être posée : les lignes peuvent répartir leur
            -- libellé et leur contrôle, et les paragraphes se mesurer.
            if entry.frame.Arrange    then entry.frame:Arrange()    end
            if entry.frame.AutoHeight then entry.frame:AutoHeight() end

            -- Une hauteur **secrète** empoisonne tout ce qu'on en déduit : la
            -- position de la ligne suivante, celle de la page, puis la course de
            -- l'ascenseur, qui ne se compare alors plus. Un cadre monté depuis un
            -- template du client peut en rendre une ; on l'écarte ici, une fois,
            -- plutôt que de s'en défendre à chaque endroit qui lit une hauteur.
            local height = entry.frame:GetHeight()
            if BUI.Util.IsSecret(height) or type(height) ~= "number" then
                height = T.SIZE.ROW_H
            end

            y[col] = y[col] - height - S.ROW_GAP
        end
    end

    local deepest = math.min(y[1], y[2])
    local height  = math.abs(deepest) + S.PADDING
    page:SetHeight(height)
    return height
end

--- Relit tous les réglages d'une page et réapplique l'état actif de chaque
--- ligne. Définie ici plutôt que dans `GetPage` : une seule fonction partagée
--- par toutes les pages, au lieu d'une fermeture recréée pour chacune.
---@param page table
local function refreshPage(page)
    local mod = page._module
    local preview  = mod.preview == true
    local moduleOn = mod:Get("enabled") and true or false

    for i = 1, #page._entries do
        local entry = page._entries[i]
        local descriptor, frame = entry.descriptor, entry.frame

        if frame.Refresh then frame.Refresh(frame) end

        -- Un module peut être éteint par le code (module sécurisé en attente de
        -- sortie de combat, par exemple) : sa page se grise alors entièrement.
        local enabled = moduleOn
        local reason  = descriptor.disabledReason or L["Module disabled tooltip"]

        -- Une page en avant-première est grisée jusqu'à son interrupteur : il
        -- n'y a rien derrière, promettre qu'on peut l'allumer serait un
        -- mensonge que le premier clic démentirait.
        if preview then
            enabled = false
            reason  = L["Coming soon tooltip"]
        elseif enabled and descriptor.disabled then
            if descriptor.disabled() then
                enabled = false
                reason  = descriptor.disabledReason
                -- Un motif peut être **calculé** : une même ligne se grise
                -- parfois pour deux raisons, et dire laquelle est tout ce qui
                -- distingue un contrôle expliqué d'un contrôle inerte.
                if type(reason) == "function" then reason = reason() end
            end
        end

        if frame.label or frame.control then
            W.SetEnabled(frame, enabled, reason)
        end
    end

    layout(page)
end

--- Construit (une seule fois) la page d'un module.
---@param parent table  frame de contenu de la zone défilante
---@param mod table
---@return table page
function PB:GetPage(parent, mod)
    local existing = pages[mod.name]
    if existing then return existing end

    -- Ancrée par le seul coin haut-gauche : la largeur est imposée par
    -- `Config:SelectModule` d'après la zone défilante, et la hauteur par
    -- `layout`. Ancrer aussi à droite entrerait en conflit avec `SetWidth`.
    local page = W.Container(parent)
    page:SetPoint("TOPLEFT")
    page._entries = {}
    page._module  = mod

    -- Pas d'interrupteur de module en tête de page : chaque réglage est éteint
    -- par défaut, allumer celui qu'on veut suffit. Un interrupteur au-dessus
    -- n'ajouterait qu'une case à cocher de plus à cocher pour rien.
    local descriptors = {}

    -- Un module en avant-première annonce la couleur en tête de page, avant
    -- d'aligner des contrôles gris que rien n'explique autrement.
    if mod.preview then
        descriptors[#descriptors + 1] = { type = "header",      text = L["Coming soon"] }
        descriptors[#descriptors + 1] = { type = "description", text = L["Coming soon notice"] }
    end

    for i = 1, #(mod.options or {}) do
        descriptors[#descriptors + 1] = mod.options[i]
    end

    for i = 1, #descriptors do
        local descriptor = descriptors[i]

        if descriptor.type == "column" then
            -- La coupure ne construit rien : elle retient seulement après quelle
            -- ligne la seconde colonne commence. Une seule par page — deux
            -- coupures voudraient dire trois colonnes, et à trois colonnes il n'y
            -- a plus de place pour un libellé.
            page._breakAt = #page._entries
        else
            local frame = buildWidget(page, mod, descriptor)
            if frame then
                page._entries[#page._entries + 1] = { descriptor = descriptor, frame = frame }
            end
        end
    end

    page.Refresh = refreshPage

    pages[mod.name] = page
    page:Hide()
    return page
end

--- Cache toutes les pages construites. Appelé avant d'en afficher une.
function PB:HideAll()
    for _, page in pairs(pages) do
        page:Hide()
    end
end

--- Reconstruit l'affichage de la page visible, si elle existe.
---@param moduleName string
function PB:RefreshPage(moduleName)
    local page = pages[moduleName]
    if page and page:IsShown() then page:Refresh() end
end
