-- =========================================================================
--  Bshamel UI — Modules/GameSettings.lua
--  Les réglages du jeu d'un personnage, relevés pour être importés ailleurs.
--
--  Un personnage neuf oblige à refaire tous les réglages du jeu à la main —
--  cases des barres d'action, plaques, butin automatique, caméra. Les
--  réglages de l'addon voyagent déjà par les profils, la disposition du mode
--  Édition est déjà chez Blizzard ; restaient les réglages du jeu **propres
--  au personnage**, que rien ne transporte. Cette page les transporte.
--
--  ## Ce qu'est un relevé
--
--  Les CVars **stockées par personnage** que le joueur a changées — celles
--  que le panneau Options range côté serveur, personnage par personnage.
--
--  La liste s'obtient en traversant **le registre du panneau Options**
--  (`SettingsPanel` : catégories → mise en page → réglages → variable), pas
--  par la console : `C_Console` a disparu du monde des addons (voir
--  `dev/docs/API_NOTES.md`). C'est un meilleur périmètre, d'ailleurs — on ne
--  relève que ce que le panneau montre vraiment. Chaque variable est ensuite
--  interrogée (`C_CVar.GetCVarInfo`, signature vérifiée en jeu), et on ne
--  garde que l'écart au défaut : quelques dizaines d'entrées.
--
--  Les cases « Barre d'action 2.. » s'y ajoutent nommément : elles passent
--  par leur propre paire d'API (`GetActionBarToggles`/`SetActionBarToggles`),
--  pas forcément par une CVar — et c'est l'exemple n° 1 de la demande.
--
--  ## Ce qu'un relevé n'est pas
--
--  Un réglage. Les relevés sont des **données au compte** (`AccountData`) :
--  hors profils — basculer ou exporter un profil ne les emporte pas —, hors
--  défauts, visibles de tous les personnages. C'est leur raison d'être : on
--  relève ici, on importe là.
--
--  Importer est un geste explicite, confirmé, refusé en combat, et chaque
--  écriture est isolée sous `pcall` : une CVar disparue depuis le relevé ne
--  s'écrit pas, elle ne coûte qu'elle-même (règle 1 — capacité, pas pari).
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local U    = BUI.Util
local W    = BUI.Widgets
local L    = ns.L

local MODULE = "GameSettings"

---@return table|nil
local function module()
    return BUI.Modules:Get(MODULE)
end

-- =========================================================================
--  Qui est ce personnage
-- =========================================================================

--- « Nom - Royaume », la clé d'un relevé. Le nom complet d'abord, les deux
--- moitiés séparées en repli : les deux chemins existent, aucun n'est garanti.
---@return string|nil
local function characterKey()
    local name, realm

    if UnitFullName then
        local ok, n, r = pcall(UnitFullName, "player")
        if ok then name, realm = n, r end
    end
    if type(name) ~= "string" or name == "" then
        name = UnitName and UnitName("player") or nil
    end
    if type(realm) ~= "string" or realm == "" then
        realm = GetRealmName and GetRealmName() or nil
    end

    if type(name) ~= "string" or name == "" then return nil end
    if type(realm) == "string" and realm ~= "" then
        return name .. " - " .. realm
    end
    return name
end

-- =========================================================================
--  Les relevés
-- =========================================================================

---@param mod table
---@return table  clé de personnage -> { at, cvars, bars }
local function snapshots(mod)
    local data = mod:AccountData()
    data.snapshots = data.snapshots or {}
    return data.snapshots
end

--- Passe chaque catégorie du panneau Options à `fn`, sous-catégories
--- comprises. Chaque maillon est un test de capacité : le panneau peut
--- renommer n'importe quelle méthode, et une clé absente ne rend rien.
---@param fn fun(category: table)
---@return boolean  la traversée a-t-elle pu commencer ?
local function eachCategory(fn)
    local ok, categories = pcall(SettingsPanel.GetAllCategories, SettingsPanel)
    if not (ok and type(categories) == "table") then return false end

    local function visit(category)
        if type(category) ~= "table" then return end
        fn(category)

        if type(category.GetSubcategories) == "function" then
            local okSub, subs = pcall(category.GetSubcategories, category)
            if okSub and type(subs) == "table" then
                for i = 1, #subs do visit(subs[i]) end
            end
        end
    end

    for _, category in pairs(categories) do
        visit(category)
    end
    return true
end

--- Passe à `fn` la variable de chaque réglage d'une catégorie : sa mise en
--- page, ses lignes, et le réglage que chaque ligne porte. Une ligne sans
--- réglage — un en-tête, un bouton — ne rend rien et ne coûte rien.
---@param category table
---@param fn fun(variable: string)
local function eachVariable(category, fn)
    local okL, layout = pcall(SettingsPanel.GetLayout, SettingsPanel, category)
    if not (okL and type(layout) == "table") then return end
    if type(layout.GetInitializers) ~= "function" then return end

    local okI, initializers = pcall(layout.GetInitializers, layout)
    if not (okI and type(initializers) == "table") then return end

    for i = 1, #initializers do
        local init = initializers[i]
        local setting

        if type(init) == "table" then
            if type(init.GetSetting) == "function" then
                local okS, value = pcall(init.GetSetting, init)
                if okS then setting = value end
            end
            -- Le repli : certaines lignes rangent leur réglage dans leurs
            -- données de construction plutôt que derrière une méthode.
            if type(setting) ~= "table" and type(init.data) == "table" then
                setting = init.data.setting
            end
        end

        if type(setting) == "table" and type(setting.GetVariable) == "function" then
            local okV, variable = pcall(setting.GetVariable, setting)
            if okV and type(variable) == "string" and not U.IsSecret(variable) then
                fn(variable)
            end
        end
    end
end

--- Relève les CVars du personnage dans `out`, en traversant le registre du
--- panneau Options.
---
--- Le tri est fait de refus : pas stockée par personnage (celles du compte
--- voyagent déjà toutes seules), verrouillée, égale à son défaut, ou
--- illisible — le client rend des valeurs secrètes dès que l'exécution est
--- teintée, et un doute se tranche en ne relevant pas. Les variables des
--- réglages « relais » — les cases qui passent par une fonction et non par
--- une CVar — ne répondent pas à `GetCVarInfo` et s'écartent toutes seules ;
--- les cases de barres d'action, qui en font partie, ont leur relevé nommé.
---@param out table
---@return number|nil  le nombre relevé, ou `nil` si la traversée est cassée
local function collectCVars(out)
    if not (C_CVar and C_CVar.GetCVarInfo) then return nil end
    if not (SettingsPanel
            and type(SettingsPanel.GetAllCategories) == "function"
            and type(SettingsPanel.GetLayout) == "function") then
        return nil
    end

    local count = 0
    local seen  = {}

    local walked = eachCategory(function(category)
        eachVariable(category, function(variable)
            if seen[variable] then return end
            seen[variable] = true

            local okInfo, value, default, _, perCharacter, locked =
                pcall(C_CVar.GetCVarInfo, variable)

            if okInfo and perCharacter == true and locked ~= true
               and type(value) == "string" and not U.IsSecret(value)
               and type(default) == "string" and not U.IsSecret(default)
               and value ~= default then
                out[variable] = value
                count = count + 1
            end
        end)
    end)

    if not walked then return nil end

    -- Une traversée qui n'a vu **aucune variable** est une traversée cassée —
    -- un maillon a changé de nom — et non un joueur aux réglages vierges :
    -- refuser vaut mieux qu'enregistrer un relevé vide qui a l'air vrai.
    if next(seen) == nil then return nil end

    return count
end

--- Relève ce personnage : ses CVars, ses cases de barres d'action, la date.
---@param mod table
---@param silent? boolean  le relevé de déconnexion ne parle pas
local function takeSnapshot(mod, silent)
    local key = characterKey()
    if not key then return end

    local cvars = {}
    local count = collectCVars(cvars)
    if not count then
        -- Le client ne sait pas lister ses CVars : rien n'est relevé, et on
        -- le dit — un relevé vide qui s'enregistre serait un mensonge.
        if not silent then BUI:Print(L["Snapshot refused"]) end
        return
    end

    local snap = { at = time(), cvars = cvars }

    -- Les cases « Barre d'action 2.. ». Le nombre de valeurs rendues a déjà
    -- changé avec les extensions : on emballe ce qui vient, sans le compter.
    if GetActionBarToggles then
        local results = { pcall(GetActionBarToggles) }
        if results[1] then
            local bars = {}
            for i = 2, #results do
                bars[i - 1] = results[i] and true or false
            end
            if #bars > 0 then snap.bars = bars end
        end
    end

    snapshots(mod)[key] = snap

    if not silent then
        BUI:Print(BUI:Lf("Snapshot taken", count))
        BUI.PageBuilder:RefreshPage(MODULE)
    end
end

-- =========================================================================
--  La source de l'import
-- =========================================================================
-- Un choix d'interface, pas un réglage : il ne survit ni au rechargement ni à
-- la fenêtre (même motif que le profil « autre » de `Modules/Profiles.lua`).

local source

---@param mod table
---@return table|nil
local function sourceSnapshot(mod)
    if type(source) ~= "string" then return nil end
    if source == characterKey() then return nil end
    return snapshots(mod)[source]
end

---@return boolean
local function sourceReady()
    local mod = module()
    return mod ~= nil and sourceSnapshot(mod) ~= nil
end

--- Les personnages relevés, ce personnage-ci exclu — s'importer sur soi-même
--- n'est pas un geste. La date dit si le relevé est frais.
---@return BUI.DropdownEntry[]
local function sourceValues()
    local mod = module()
    if not mod then return {} end

    local snaps  = snapshots(mod)
    local me     = characterKey()
    local values = {}

    for _, key in ipairs(U.SortedKeys(snaps)) do
        if key ~= me then
            local at    = snaps[key].at
            local when  = at and date("%d/%m %H:%M", at) or "?"
            values[#values + 1] = {
                value = key,
                label = key .. " (" .. when .. ")",
            }
        end
    end
    return values
end

---@return boolean
local function nothingToImport()
    return #sourceValues() == 0
end

-- =========================================================================
--  L'import
-- =========================================================================

---@param mod table
local function applySnapshot(mod)
    local snap = sourceSnapshot(mod)
    if not snap then return end
    if InCombatLockdown() then return end

    -- On n'écrit que l'écart : une CVar déjà à la bonne valeur n'émet pas de
    -- `CVAR_UPDATE`, et une CVar que ce client ne connaît plus (`nil`) ne
    -- s'invente pas.
    local applied = 0
    if type(snap.cvars) == "table" then
        for name, value in pairs(snap.cvars) do
            local current = U.GetCVar(name)
            if current ~= nil and current ~= value then
                if pcall(U.SetCVar, name, value) then
                    applied = applied + 1
                end
            end
        end
    end

    if type(snap.bars) == "table" and SetActionBarToggles then
        pcall(SetActionBarToggles, unpack(snap.bars))
    end

    BUI:Print(BUI:Lf("Snapshot applied", applied, source))
end

local function confirmApply()
    local mod = module()
    if not (mod and sourceSnapshot(mod)) then return end

    W.Confirm(BUI:Lf("Apply snapshot confirm", source), function()
        local m = module()
        if m then applySnapshot(m) end
    end)
end

local function deleteSnapshot()
    local mod = module()
    if not (mod and sourceSnapshot(mod)) then return end

    W.Confirm(BUI:Lf("Delete snapshot confirm", source), function()
        local m = module()
        if not m then return end
        snapshots(m)[source] = nil
        source = nil
        BUI.PageBuilder:RefreshPage(MODULE)
    end)
end

-- =========================================================================
--  Déclaration du module
-- =========================================================================

BUI:RegisterModule(MODULE, {
    title    = L["Game settings"],
    category = "Sharing",
    order    = 10,

    defaults = {
        autoSnapshot = false,
    },

    options = {
        { type = "header", text = L["Snapshot"] },
        {
            type    = "button",
            text    = L["Record game settings"],
            label   = L["Record"],
            tooltip = L["Record game settings tip"],
            onClick = function()
                local mod = module()
                if mod then takeSnapshot(mod) end
            end,
        },
        {
            type    = "toggle",
            key     = "autoSnapshot",
            text    = L["Auto snapshot"],
            tooltip = L["Auto snapshot tip"],
        },

        { type = "header", text = L["Import"] },
        {
            type     = "dropdown",
            text     = L["Source character"],
            tooltip  = L["Source character tip"],
            values   = sourceValues,
            get      = function() return source or L["No snapshot picked"] end,
            set      = function(value)
                source = value
                -- Un choix hors base n'émet pas de message : la page se
                -- rafraîchit ici pour que les boutons suivent le menu.
                BUI.PageBuilder:RefreshPage(MODULE)
            end,
            disabled = nothingToImport,
            disabledReason = L["No snapshot yet"],
        },
        {
            type     = "button",
            text     = L["Apply snapshot"],
            label    = L["Apply"],
            tooltip  = L["Apply snapshot tip"],
            indent   = true,
            onClick  = confirmApply,
            disabled = function()
                return not sourceReady() or InCombatLockdown()
            end,
            disabledReason = function()
                if InCombatLockdown() then return L["Cannot change in combat"] end
                return L["Pick a snapshot first"]
            end,
        },
        {
            type     = "button",
            text     = L["Delete snapshot"],
            label    = L["Delete"],
            tooltip  = L["Delete snapshot tip"],
            indent   = true,
            onClick  = deleteSnapshot,
            disabled = function() return not sourceReady() end,
            disabledReason = L["Pick a snapshot first"],
        },
    },

    OnEnable = function(self)
        -- Le relevé de déconnexion : silencieux, et seulement si demandé. Les
        -- SavedVariables s'écrivent après cet événement, le relevé part avec.
        self:RegisterEvent("PLAYER_LOGOUT", function()
            if self:Get("autoSnapshot") then takeSnapshot(self, true) end
        end)
    end,

    -- Rien à rendre : la page ne fait que des gestes, et les relevés sont des
    -- données — désactiver le module les laisse en place, comme l'historique
    -- de chat survit à sa case.
    OnDisable = nil,
})
