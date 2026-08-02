-- =========================================================================
--  Bshamel UI — Modules/Windows.lua
--  Déplacer et redimensionner les fenêtres du client, et s'en souvenir.
--
--  Ce fichier ne déplace rien : il déclare des réglages et les rend lisibles au
--  moteur, `UI/Move.lua`. Le moteur ne connaît pas la base de données, le module
--  ne connaît pas les cadres du client, et l'un ne parle à l'autre que par
--  l'*hôte* construit ci-dessous. C'est la même séparation que le mode sombre :
--  `UI/Shade.lua` sait teinter, `Modules/General.lua` sait ce qu'il faut teindre.
--
--  `secure = true` : le moteur repositionne des cadres **protégés** (le cadre de
--  recherche de groupe en est un). Il le fait par l'environnement restreint,
--  jamais par un appel direct — mais la règle 6 demande de le déclarer dès qu'on
--  y touche, et le core diffère alors l'activation à la sortie de combat.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local W    = BUI.Widgets
local L    = ns.L

local MODULE = "Windows"

--- Grise une ligne tant que l'interrupteur qui la commande est éteint.
---@param key string
---@return fun(): boolean
local function requires(key)
    return function()
        local mod = BUI.Modules:Get(MODULE)
        return not (mod and mod:Get(key))
    end
end

-- =========================================================================
--  Réglages enregistrés par fenêtre
-- =========================================================================
-- Deux tables associatives, indexées par le nom global du cadre :
--
--     positions = { CharacterFrame = { x = -180, y = 40 } }
--     scales    = { CharacterFrame = 1.15 }
--
-- Elles sont **mutées en place** plutôt que réécrites par `self:Set`. Ce n'est
-- pas un contournement de la règle 4, qui interdit d'aller lire `BshamelUIDB` en
-- direct : la table vient bien de `self:Get`, donc du profil actif, avec la
-- fusion des défauts et le nettoyage à la déconnexion que cela implique.
--
-- Ce qu'on évite en n'appelant pas `Set` : reconstruire une table de soixante
-- entrées à chaque cran de molette, et surtout émettre un message de changement
-- de réglage à chaque image d'un glisser. Aucun widget n'affiche ces valeurs —
-- il n'y a donc personne à prévenir.

---@param mod table
---@return table
local function positions(mod)
    return mod:Get("positions") or {}
end

---@param mod table
---@return table
local function scales(mod)
    return mod:Get("scales") or {}
end

--- Construit l'hôte que le moteur interroge.
---@param mod table
---@return BUI.MoveHost
local function makeHost(mod)
    return {
        CanMove  = function() return mod:Get("movable") == true end,
        CanScale = function() return mod:Get("scalable") == true end,
        Modifier = function() return mod:Get("moveModifier") or "SHIFT" end,

        GetPosition = function(name)
            return positions(mod)[name]
        end,

        SetPosition = function(name, x, y)
            local stored = positions(mod)
            if x == nil or y == nil then
                stored[name] = nil
                return
            end

            -- La table d'une fenêtre déjà déplacée est réutilisée : un glisser
            -- en produirait une par image (règle 7).
            local pos = stored[name]
            if pos then
                pos.x, pos.y = x, y
            else
                stored[name] = { x = x, y = y }
            end
        end,

        GetScale = function(name)
            return scales(mod)[name]
        end,

        SetScale = function(name, scale)
            scales(mod)[name] = scale
        end,
    }
end

-- =========================================================================
--  Réinitialisation
-- =========================================================================

---@param mod table
local function resetLayout(mod)
    W.Confirm(L["Reset windows confirm"], function()
        BUI.Move:ResetAll()

        -- `ResetAll` a vidé les entrées une à une, par l'hôte. Les tables
        -- elles-mêmes sont vidées ici : une fenêtre retirée du registre entre
        -- deux versions y aurait laissé une entrée que le moteur ne connaît plus
        -- et ne peut donc pas effacer.
        wipe(positions(mod))
        wipe(scales(mod))

        mod:Print(L["Window layout reset"])
    end)
end

-- =========================================================================
--  Déclaration du module
-- =========================================================================

BUI:RegisterModule(MODULE, {
    title    = L["Windows"],
    category = "QoL",
    order    = 10,
    secure   = true,

    defaults = {
        -- Éteint par défaut, comme tout le reste de l'addon : installer Bshamel
        -- UI ne doit rien changer tant qu'on n'a rien coché.
        movable  = false,
        scalable = false,

        -- Un modificateur par défaut, et non « aucun » : sans lui, un glisser
        -- dans le corps d'une fenêtre la déplace, y compris quand on voulait
        -- seulement faire glisser autre chose. Le choix « aucun » reste offert à
        -- qui le préfère.
        moveModifier = "SHIFT",

        positions = {},
        scales    = {},
    },

    options = {
        { type = "header", text = L["Moving"] },
        {
            type    = "toggle",
            key     = "movable",
            text    = L["Move windows"],
            tooltip = L["Move windows tip"],
        },
        {
            type     = "dropdown",
            key      = "moveModifier",
            text     = L["Move modifier"],
            tooltip  = L["Move modifier tip"],
            disabled = requires("movable"),
            values   = {
                { value = "SHIFT", label = L["Shift"] },
                { value = "CTRL",  label = L["Ctrl"] },
                { value = "ALT",   label = L["Alt"] },
                { value = "NONE",  label = L["No modifier"] },
            },
        },

        { type = "header", text = L["Size"] },
        {
            type    = "toggle",
            key     = "scalable",
            text    = L["Scale windows"],
            tooltip = L["Scale windows tip"],
        },

        { type = "header", text = L["Reset"] },
        {
            type    = "button",
            text    = L["Reset window layout"],
            label   = L["Reset"],
            tooltip = function()
                return string.format(L["Reset window layout tip"], BUI.Move:CountPinned())
            end,
            onClick = function()
                local mod = BUI.Modules:Get(MODULE)
                if mod then resetLayout(mod) end
            end,
        },
    },

    OnEnable = function(self)
        BUI.Move:SetHost(makeHost(self))
        BUI.Move:Start()

        -- La moitié des fenêtres du client vit dans un addon chargé à la
        -- demande : elles n'existent pas encore ici.
        self:RegisterEvent("ADDON_LOADED", function(_, addonName)
            BUI.Move:OnAddonLoaded(addonName)
        end)

        -- Le capteur de molette ne s'arme que pendant que le modificateur est
        -- tenu. Hors de ces instants-là, il n'existe pas.
        self:RegisterEvent("MODIFIER_STATE_CHANGED", function()
            BUI.Move:OnModifierChanged()
        end)

        -- Un cadre protégé ne se repositionne pas en combat : ce qui a été
        -- refusé pendant le combat est rattrapé ici.
        self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
            BUI.Move:Refresh()
        end)
    end,

    OnDisable = function()
        -- Rend chaque fenêtre à l'ancrage et à l'échelle où on l'a trouvée, puis
        -- débranche le moteur. Les positions restent en base : rallumer le
        -- module doit retrouver la disposition, pas la redemander.
        BUI.Move:Stop()
    end,

    OnSettingChanged = function(self, key)
        if key == nil then
            -- Changement de profil : la disposition n'est plus la même. On rend
            -- d'abord les fenêtres à leur état d'origine, sans quoi celles que
            -- l'ancien profil déplaçait et que le nouveau ignore resteraient là
            -- où le profil précédent les avait mises.
            BUI.Move:Stop()
            BUI.Move:SetHost(makeHost(self))
            BUI.Move:Start()
            return
        end

        if key == "scalable" then
            -- Décocher pendant que le modificateur est tenu doit rendre la
            -- molette au jeu tout de suite, pas au relâchement.
            BUI.Move:OnModifierChanged()
        end
    end,
})
