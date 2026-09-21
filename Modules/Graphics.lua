-- =========================================================================
--  Bshamel UI — Modules/Graphics.lua
--  Les réglages graphiques que le panneau Options ne montre pas.
--
--  Le client en connaît des dizaines qui ne se règlent qu'à la console. Ils ne
--  sont pas cachés par accident — ils ne conviennent pas à tout le monde, et
--  Blizzard ne veut pas les défendre — mais quelques-uns changent assez la
--  lisibilité du jeu pour valoir une case.
--
--  Aucune frame, aucune couleur : ce module ne fait qu'écrire des CVars et se
--  souvenir de ce qu'il a trouvé.
--
--  ## Rendre ce qu'on a pris (CLAUDE.md règle 6)
--
--  Une CVar n'est pas un réglage de l'addon : **le client l'écrit dans
--  `Config.wtf` et la relit à la session suivante**. Éteindre le module doit
--  donc rendre la valeur d'origine, et pas seulement cesser d'écrire — sans
--  quoi le brouillard resterait coupé pour toujours chez quelqu'un qui a
--  désinstallé l'addon.
--
--  Le piège est dans la deuxième session. Au démarrage, la CVar porte déjà la
--  valeur qu'on avait posée hier ; la relever comme « valeur d'origine »
--  reviendrait à mémoriser la nôtre, et la rendre ne rendrait rien. On écarte
--  donc ce cas nommément : quand ce qu'on trouve est indiscernable de ce qu'on
--  écrit, c'est le **défaut du client** qui fait foi.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local U    = BUI.Util
local L    = ns.L

local MODULE = "Graphics"

-- =========================================================================
--  Les CVars
-- =========================================================================

--- Le brouillard volumétrique. Il n'a pas de case dans le panneau Options : il
--- se pose à la console (`/console volumeFog 0`), et c'est tout ce que fait la
--- ligne ci-dessous.
local CVAR_FOG = "volumeFog"

--- Ce qu'on écrit quand la case est cochée.
local OFF = "0"

--- CVar -> valeur relevée avant qu'on y touche. `nil` veut dire « on n'a rien
--- changé », ce qui n'est pas la même chose que « la valeur d'origine était
--- vide ».
local saved = {}

--- Le défaut du client pour cette CVar, quand il sait le dire. Les deux chemins
--- existent et aucun n'est garanti : test de capacité, pas de pari (règle 1).
---@param name string
---@return string|nil
local function defaultOf(name)
    if C_CVar and C_CVar.GetCVarDefault then
        local ok, value = pcall(C_CVar.GetCVarDefault, name)
        if ok then return value end
    end
    if GetCVarDefault then
        local ok, value = pcall(GetCVarDefault, name)
        if ok then return value end
    end
    return nil
end

--- Pose `value` sur une CVar, ou rend ce qu'on y avait trouvé quand `value` est
--- `nil`.
---
--- Chaque écriture est isolée : une CVar que ce client ne connaît pas, ou qu'il
--- refuse de laisser écrire, ne coûte qu'elle-même.
---@param name string
---@param value string|nil
local function override(name, value)
    if value ~= nil then
        if saved[name] == nil then
            local found = U.GetCVar(name)

            -- La valeur d'hier, rendue par `Config.wtf`, est la nôtre : la
            -- retenir reviendrait à ne rien avoir à rendre. Le défaut du client
            -- est alors le seul repère honnête.
            if found == nil or found == value then
                found = defaultOf(name)
            end

            -- `false` marque « relevé impossible » et n'est pas `nil` : sans
            -- cette distinction, on relèverait de nouveau au passage suivant,
            -- et on finirait par mémoriser notre propre valeur.
            saved[name] = found or false
        end

        pcall(U.SetCVar, name, value)
        return
    end

    local found = saved[name]
    saved[name] = nil
    if type(found) == "string" then
        pcall(U.SetCVar, name, found)
    end
end

---@param mod table
local function applyAll(mod)
    if mod:IsEnabled() and mod:Get("disableFog") then
        override(CVAR_FOG, OFF)
    else
        override(CVAR_FOG, nil)
    end
end

-- =========================================================================
--  Déclaration du module
-- =========================================================================

BUI:RegisterModule(MODULE, {
    title    = L["Graphics"],
    category = "QoL",
    -- Juste avant « Nuisances », et pour la même raison qu'elle ferme la
    -- liste : on ne descend pas jusqu'ici en cherchant un réglage de confort,
    -- on y descend en ayant fini de régler le jeu lui-même.
    order    = 85,

    defaults = {
        disableFog = false,
    },

    -- L'en-tête s'appelle « Général » et non « Graphismes » : la page porte
    -- déjà ce nom-là, et le répéter juste en dessous donne une page qui a l'air
    -- cassée. Même choix que le mode sombre et la ressource de classe.
    options = {
        { type = "header", text = L["General"] },
        {
            type    = "toggle",
            key     = "disableFog",
            text    = L["Disable fog"],
            tooltip = L["Disable fog tip"],
        },
    },

    OnEnable = applyAll,

    OnDisable = function()
        -- Sans relire les réglages : le module s'éteint, ce qu'il a posé doit
        -- disparaître même si la case reste cochée.
        override(CVAR_FOG, nil)
    end,

    OnSettingChanged = applyAll,
})
