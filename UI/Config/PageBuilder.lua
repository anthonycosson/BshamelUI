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
--      { type = "button",      text = ..., label = ..., onClick = function() end }
--      { type = "description", text = ... }
--      { type = "spacer",      height = 10 }
--
--  Champs communs facultatifs :
--      disabled = function() return true|false end   -- grise la ligne
--      disabledReason = "..."                        -- expliqué en infobulle
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
            get     = get,
            set     = set,
        })

    elseif kind == "slider" then
        return W.Slider(page, {
            text     = descriptor.text,
            tooltip  = descriptor.tooltip,
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
            values  = descriptor.values or {},
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

    elseif kind == "spacer" then
        local spacer = W.Row(page, nil)
        spacer:SetHeight(descriptor.height or T.SIZE.SECTION_GAP)
        spacer.label:Hide()
        return spacer
    end

    BUI:Warn("descripteur d'option inconnu : " .. tostring(kind))
    return nil
end

--- Empile les widgets et renvoie la hauteur totale utilisée.
local function layout(page)
    local y = -T.SIZE.PADDING
    local entries = page._entries

    for i = 1, #entries do
        local entry = entries[i]
        local hidden = entry.descriptor.hidden and entry.descriptor.hidden() or false

        if hidden then
            entry.frame:Hide()
        else
            -- Un en-tête de section respire davantage, sauf en tête de page.
            if entry.descriptor.type == "header" and i > 1 then
                y = y - T.SIZE.SECTION_GAP
            end

            entry.frame:Show()
            entry.frame:ClearAllPoints()
            entry.frame:SetPoint("TOPLEFT", page, "TOPLEFT", 0, y)
            entry.frame:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, y)

            -- Les widgets à hauteur variable (paragraphes) se mesurent une fois
            -- leur largeur connue, donc après l'ancrage.
            if entry.frame.AutoHeight then entry.frame:AutoHeight() end

            y = y - entry.frame:GetHeight() - T.SIZE.ROW_GAP
        end
    end

    local height = math.abs(y) + T.SIZE.PADDING
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
        local frame = buildWidget(page, mod, descriptor)
        if frame then
            page._entries[#page._entries + 1] = { descriptor = descriptor, frame = frame }
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
