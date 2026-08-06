-- =========================================================================
--  Bshamel UI — Modules/ActionBars.lua
--  Les barres d'action.
--
--  Un seul comportement pour l'instant : décider si une action part à
--  l'enfoncement de la touche ou à son relâchement. Le client sait déjà le
--  faire — c'est une de ses CVar —, il ne l'expose simplement pas là où on le
--  cherche.
--
--  **Trois états et non deux**, et c'est ce qui rend le réglage honnête. Le
--  client a son propre défaut, et d'autres addons écrivent cette CVar : une
--  simple case à cocher, éteinte, prétendrait « les actions partent au
--  relâchement » alors qu'elle ne ferait que ne rien faire. Les trois états
--  disent la vérité — ne pas y toucher, forcer l'enfoncement, forcer le
--  relâchement — et « ne pas y toucher » reste le défaut, comme partout ailleurs
--  dans l'addon.
--
--  On passe par la CVar et non par l'attribut `useOnKeyDown` de chaque bouton :
--  la CVar est *le* réglage du client, elle vaut pour toutes les barres, y
--  compris celles qui n'existent pas encore quand le module s'allume, et elle
--  se rend à sa valeur d'origine en une ligne. Écrire l'attribut bouton par
--  bouton reviendrait à réimplémenter ce que le moteur fait déjà, en moins bien
--  et en combat interdit.
--
--  Réversibilité (règle 6) : la valeur d'origine est relevée avant d'être
--  changée, et reposée à la désactivation — y compris quand c'est nous qui
--  avions forcé le relâchement.
--
--  `secure = true` : le réglage décide de la façon dont des cadres protégés
--  répondent au clavier. Le core diffère alors l'activation à la sortie de
--  combat, ce qui est exactement ce qu'il faut — le client refuse ce changement
--  pendant un combat.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local U    = BUI.Util
local L    = ns.L

local MODULE = "ActionBars"

--- Nom de la CVar du client. Un seul endroit où elle est écrite.
local CVAR_KEY_DOWN = "ActionButtonUseKeyDown"

-- =========================================================================
--  CVar
-- =========================================================================

--- Valeur relevée avant modification. `nil` signifie « on n'a rien changé », ce
--- qui n'est pas la même chose que « la valeur d'origine était vide ».
local saved

---@param value string|nil  valeur à poser, ou `nil` pour rendre l'originale
local function overrideCVar(value)
    -- Le client refuse ce changement en combat, et il a raison : il décide de la
    -- réponse de cadres protégés. Ce qui est refusé ici est rattrapé à la sortie
    -- de combat, où `applyKeyDown` est rappelée.
    if InCombatLockdown() then return end

    if value ~= nil then
        if saved == nil then saved = U.GetCVar(CVAR_KEY_DOWN) end
        U.SetCVar(CVAR_KEY_DOWN, value)
    elseif saved ~= nil then
        U.SetCVar(CVAR_KEY_DOWN, saved)
        saved = nil
    end
end

--- Réglage -> valeur de CVar. L'absence d'entrée (« game ») veut dire « rendre
--- la valeur d'origine », ce qui n'est pas la même chose que poser un zéro.
local CVAR_VALUES = {
    down = "1",
    up   = "0",
}

---@param mod table
local function applyKeyDown(mod)
    overrideCVar(CVAR_VALUES[mod:Get("keyPress")])
end

--- Repose notre choix quand quelqu'un d'autre a écrit la CVar après nous.
---
--- Ce n'est pas de la paranoïa : plusieurs suites d'addons posent leur liste de
--- CVar à la connexion, et l'ordre de chargement décide alors du gagnant. Un
--- réglage qui obéit une fois sur deux selon les addons installés ne vaut rien.
---
--- Bridée : si un autre addon tient l'inverse aussi fermement, les deux se
--- répondent. La bride ne règle pas le conflit — rien ne le peut — mais elle le
--- rend lent et visible au lieu d'en faire une boucle.
---@param mod table
local function enforceKeyDown(mod)
    local wanted = CVAR_VALUES[mod:Get("keyPress")]
    if not wanted then return end            -- « défaut du jeu » : rien à tenir
    if InCombatLockdown() then return end
    if U.GetCVar(CVAR_KEY_DOWN) == wanted then return end

    applyKeyDown(mod)
end

-- =========================================================================
--  Déclaration du module
-- =========================================================================

BUI:RegisterModule(MODULE, {
    title    = L["Action bars"],
    category = "Interface",
    order    = 20,
    secure   = true,

    defaults = {
        keyPress = "game",
    },

    options = {
        { type = "header", text = L["Input"] },
        {
            type    = "dropdown",
            key     = "keyPress",
            text    = L["Cast on key down"],
            tooltip = L["Cast on key down tip"],
            values  = {
                { value = "game", label = L["Game default"] },
                { value = "down", label = L["Key down"] },
                { value = "up",   label = L["Key up"] },
            },
        },
    },

    OnEnable = function(self)
        applyKeyDown(self)

        -- Ce qui a été refusé pendant le combat est posé ici.
        self:RegisterEvent("PLAYER_REGEN_ENABLED", function() applyKeyDown(self) end)

        -- Le client annonce chaque écriture de CVar, la nôtre comprise : on ne
        -- repose que si la valeur ne convient pas, sinon on se répondrait à
        -- soi-même. La bride couvre le cas où c'est un autre addon qui insiste.
        self:RegisterEvent("CVAR_UPDATE", U.Throttle(T.TIMING.CVAR_SETTLE, function()
            enforceKeyDown(self)
        end))
    end,

    OnDisable = function()
        overrideCVar(nil)
    end,

    OnSettingChanged = function(self)
        applyKeyDown(self)
    end,
})
