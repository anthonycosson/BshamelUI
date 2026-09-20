-- =========================================================================
--  Bshamel UI — Modules/PersonalResource.lua
--  La ressource personnelle : les barres de vie et de ressource affichées
--  sous le personnage.
--
--  Depuis Midnight, ce n'est plus une barre de nom : `C_NamePlate` ne la rend
--  plus, même affichée, et le cadre vit sous un nom global à lui —
--  `PersonalResourceDisplayFrame` — relevé en jeu (voir `dev/docs/API_NOTES.md`).
--  Chaque barre porte déjà les trois textes du client (`TextString`,
--  `LeftText`, `RightText`), commandés par le réglage « texte de statut » du
--  jeu : tout ou rien, et à la place que le client a choisie.
--
--  Ce module rend ce choix au joueur, **barre par barre** : la valeur, le
--  pourcentage, ou les deux, chacun posé au bord gauche, au centre ou au bord
--  droit, au corps qu'on veut — la barre de vie et la barre de ressource se
--  règlent séparément. Quand une barre a au moins une case cochée, nos textes
--  **remplacent** les siens — deux textes au même endroit ne se liraient pas —
--  et ceux du client reviennent dès qu'on décoche tout sur cette barre.
--
--  L'interrupteur en tête de page est **le réglage du jeu lui-même**
--  (`nameplateShowSelf`), repris ici pour n'avoir plus qu'un endroit où aller.
--  On ne le possède pas : le CVar est le rangement, lu et écrit en direct —
--  même partage que la section « Paramètres Blizzard » des barres d'infos, et
--  pour les mêmes raisons.
--
--  Le module ne dessine rien : `UI/Widgets/BarText.lua` sait poser deux textes
--  sur une barre. Ce fichier dit lesquels, et ce qu'ils racontent.
--
--  La vie et la ressource du joueur sont des valeurs **secrètes** en jeu : on
--  ne les lit pas, on les **fait passer** — `SetText` accepte un secret et
--  sait l'afficher (relevé en jeu). Ce qui exige un calcul, comme le
--  pourcentage, vit sous `pcall` et se tait quand le client refuse : une barre
--  muette est une réponse honnête là où une erreur Lua n'en est pas une.
--
--  Réversibilité (règle 6) : nos textes se cachent, et les textes du client
--  que nous avions cachés sont remontrés. Les hooks qui les faisaient taire
--  passent par `U.GuardedHook` et deviennent inertes avec le module.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local U    = BUI.Util
local W    = BUI.Widgets
local L    = ns.L

local MODULE = "PersonalResource"

-- =========================================================================
--  Le réglage du jeu, repris dans la page
-- =========================================================================

--- L'affichage lui-même : le CVar du client, lu et écrit en direct. Refusé en
--- combat par le client, d'où la ligne grisée pendant l'engagement.
local CVAR_SHOW = "nameplateShowSelf"

---@return boolean
local function readShow()
    return U.GetCVar(CVAR_SHOW) == "1"
end

---@param value boolean
local function writeShow(value)
    if InCombatLockdown() then return end
    U.SetCVar(CVAR_SHOW, value and "1" or "0")
end

--- Un réglage du client se grise en combat : il ne prendrait pas.
---@return boolean
local function inCombat()
    return InCombatLockdown() and true or false
end

-- =========================================================================
--  Les deux barres du client
-- =========================================================================
-- Chaque maillon est testé : le client peut renommer ou déplacer n'importe
-- lequel, et une clé absente vaut « pas de barre », jamais une erreur (règle 1).

---@return table|nil
local function healthBar()
    local frame = PersonalResourceDisplayFrame
    if type(frame) ~= "table" then return nil end

    local container = frame.HealthBarsContainer
    if type(container) ~= "table" then return nil end

    local bar = container.healthBar
    if type(bar) ~= "table" then return nil end
    return bar
end

---@return table|nil
local function powerBar()
    local frame = PersonalResourceDisplayFrame
    if type(frame) ~= "table" then return nil end

    local bar = frame.PowerBar
    if type(bar) ~= "table" then return nil end
    return bar
end

--- Clés sous lesquelles une barre du client publie ses textes. Les trois vont
--- ensemble : « les deux » les répartit sur `LeftText` et `RightText`, les
--- autres modes écrivent dans `TextString`.
local CLIENT_TEXTS = { "TextString", "LeftText", "RightText" }

--- Barre -> ses clés de réglage. Les deux barres portent les mêmes cinq
--- réglages, chacune les siens : c'est la table qui évite d'écrire deux fois
--- la même logique. `none` fait taire le texte du jeu sans rien écrire à la
--- place — et prime sur les deux autres cases, qu'il grise.
local BAR_KEYS = {
    health = {
        none = "healthNoText",
        value = "healthValue", valueAnchor = "healthValueAnchor",
        percent = "healthPercent", percentAnchor = "healthPercentAnchor",
    },
    power = {
        none = "powerNoText",
        value = "powerValue", valueAnchor = "powerValueAnchor",
        percent = "powerPercent", percentAnchor = "powerPercentAnchor",
    },
}

-- =========================================================================
--  État
-- =========================================================================

--- "health" / "power" -> les textes posés sur la barre. Construits une fois,
--- cachés/remontrés ensuite (règle 7).
local texts = {}

--- Textes du client que **nous** avons cachés — eux seuls sont remontrés à
--- l'extinction : rendre un texte que le réglage du jeu cachait déjà serait
--- décider à la place du joueur.
local muted = {}

--- Dernières valeurs peintes, pour ne pas réécrire un texte qui n'a pas bougé
--- (règle 7). `-1` force le prochain passage — c'est ce qui rattrape un
--- changement de réglage.
local paintedHealth, paintedHealthMax = -1, -1
local paintedPower,  paintedPowerMax  = -1, -1

--- Les repères posés sur la barre de ressource, montés au premier besoin. Une
--- frame ne se détruit pas en World of Warcraft : on la construit une fois,
--- puis on la cache et on la réaffiche (règle 7).
---@type table|nil
local powerMarkers
--- Table de travail rendue au widget : trois nombres relus à chaque
--- application, jamais une table neuve.
local markerScratch = {}

-- =========================================================================
--  Le texte
-- =========================================================================

--- Abrège comme le client — « 385 k » — quand il sait le faire, et rend la
--- valeur **telle quelle** sinon. Telle quelle, y compris secrète : la vie et
--- la ressource du joueur sont des secrets en jeu, mais un secret se fait
--- passer sans se lire, et `SetText` sait l'afficher (relevé en jeu, voir
--- `dev/docs/API_NOTES.md`). C'est ce passage de bout en bout qui fait que le
--- texte s'écrit là où toute lecture est refusée.
---
--- `type(text) ~= "nil"` et non `text ~= nil` : comparer un secret à `nil`
--- lève aussi, alors que `type` répond toujours.
---@param value any
---@return any  une chaîne, un nombre, ou un secret à passer tel quel
local function shorten(value)
    if type(AbbreviateNumbers) == "function" then
        local ok, text = pcall(AbbreviateNumbers, value)
        if ok and type(text) ~= "nil" then return text end
    end
    return value
end

--- Le pourcentage se **demande**, il ne se calcule pas : l'arithmétique sur un
--- secret est refusée — jusqu'à l'arrondi —, et le client publie exactement ce
--- qu'il faut : `UnitHealthPercent` et `UnitPowerPercent`, qui rendent le
--- nombre — secret — que le widget sait afficher (relevé en jeu, voir
--- `dev/docs/API_NOTES.md`).
---@param fn any  `UnitHealthPercent` ou `UnitPowerPercent`, si le client les a
---@return any  nombre 0..100, éventuellement secret, ou nil
local function readPercent(fn)
    if type(fn) ~= "function" then return nil end
    local ok, pct = pcall(fn, "player")
    if ok then return pct end
    return nil
end

--- Écrit les deux textes d'une barre.
---@param mod table
---@param widget table
---@param keys table  entrée de `BAR_KEYS`
---@param value any
---@param pct any
local function write(mod, widget, keys, value, pct)
    widget:SetValue(mod:Get(keys.value) and shorten(value) or "")
    widget:SetPercent(mod:Get(keys.percent) and pct or nil)
end

--- Repeint la barre de vie, si la valeur a bougé.
---@param mod table
local function refreshHealth(mod)
    local widget = texts.health
    if not (widget and widget:IsShown()) then return end

    local value, max = UnitHealth("player"), UnitHealthMax("player")
    if not (U.IsSecret(value) or U.IsSecret(max)) then
        if value == paintedHealth and max == paintedHealthMax then return end
        paintedHealth, paintedHealthMax = value, max
    end
    write(mod, widget, BAR_KEYS.health, value, readPercent(UnitHealthPercent))
end

--- Même chose pour la barre de ressource. `UnitPower` sans type rend la
--- ressource **affichée**, celle que la barre du client montre — mana, énergie,
--- rage, ce que la forme du moment impose.
---@param mod table
local function refreshPower(mod)
    local widget = texts.power
    if not (widget and widget:IsShown()) then return end

    local value, max = UnitPower("player"), UnitPowerMax("player")
    if not (U.IsSecret(value) or U.IsSecret(max)) then
        if value == paintedPower and max == paintedPowerMax then return end
        paintedPower, paintedPowerMax = value, max
    end
    write(mod, widget, BAR_KEYS.power, value, readPercent(UnitPowerPercent))
end

-- =========================================================================
--  Pose et remplacement
-- =========================================================================

--- Cette barre-là a-t-elle un texte à dire ? « Aucun texte » prime : une barre
--- réduite au silence n'écrit rien, quelles que soient les cases du dessous.
---@param mod table
---@param key string  "health" | "power"
---@return boolean
local function barSpeaks(mod, key)
    local keys = BAR_KEYS[key]
    if mod:Get(keys.none) then return false end
    return mod:Get(keys.value) == true or mod:Get(keys.percent) == true
end

--- Les textes du client doivent-ils se taire sur cette barre ? Deux motifs, un
--- seul silence : soit les nôtres parlent à leur place, soit « Aucun texte »
--- demande le vide.
---@param mod table
---@param key string  "health" | "power"
---@return boolean
local function barMutes(mod, key)
    return mod:Get(BAR_KEYS[key].none) == true or barSpeaks(mod, key)
end

--- Pose nos textes sur une barre et fait taire ceux du client — ou l'inverse.
---
--- Le silence tient par deux gestes : cacher maintenant, et **re-cacher à
--- chaque fois que le client remontre** — il repasse sur ses textes à chaque
--- battement de la valeur, et un simple `Hide` ne survivrait pas au premier.
--- Se brancher sur l'écriture plutôt que courir après ses moments est le parti
--- pris de tout l'addon (voir `hookNameColor` dans les barres d'infos).
---@param mod table
---@param bar table
---@param key string  "health" | "power"
local function setupBar(mod, bar, key)
    local keys = BAR_KEYS[key]
    local on   = mod:IsEnabled() and barSpeaks(mod, key)
    local mute = mod:IsEnabled() and barMutes(mod, key)

    local widget = texts[key]
    if not widget and on then
        widget = W.BarText(bar)
        texts[key] = widget
    end
    if widget then
        widget:SetAnchors(mod:Get(keys.valueAnchor), mod:Get(keys.percentAnchor))
        widget:SetTextSize(mod:Get("textSize") or T.SIZE.BAR_TEXT_SIZE)
        widget:SetShown(on)
    end

    for i = 1, #CLIENT_TEXTS do
        local fs = bar[CLIENT_TEXTS[i]]
        if type(fs) == "table" and type(fs.Hide) == "function" then
            if mute then
                if U.IsTrue(fs:IsShown()) then muted[fs] = true end
                fs:Hide()
                -- Les deux chemins d'affichage, pas un : n'en guetter qu'un
                -- laisse passer la moitié des réapparitions — même leçon que
                -- les hooks doubles des barres d'infos (`SetFont` et
                -- `SetFontObject`, voir `dev/docs/API_NOTES.md`).
                local guard = function()
                    return mod:IsEnabled() and barMutes(mod, key)
                end
                U.GuardedHook(fs, "Show", function(self) self:Hide() end, guard)
                U.GuardedHook(fs, "SetShown", function(self, shown)
                    if U.IsTrue(shown) then self:Hide() end
                end, guard)
            elseif muted[fs] then
                muted[fs] = nil
                fs:Show()
            end
        end
    end
end

--- Pose les repères de la barre de ressource.
---
--- Les glissières parlent en **points de ressource**, le widget en fraction de
--- largeur : la conversion se fait ici, contre le maximum du moment.
--- `UnitPowerMax` se lit en clair — seule la valeur courante est secrète (voir
--- `dev/docs/API_NOTES.md`) — mais un client qui le rendrait secret à son tour
--- ne doit rien casser : le garde éteint alors tous les repères, un trait
--- absent étant plus honnête qu'un trait posé au hasard. Un repère au-delà du
--- maximum du moment s'éteint pour la même raison : il désigne un point que la
--- barre ne contient pas.
---
--- Le widget est monté au premier besoin et sur la barre du moment : le client
--- peut avoir reconstruit son affichage entre deux passages, auquel cas la barre
--- n'est plus la même frame et les repères d'avant sont sur un cadre mort.
---@param mod table
---@param bar table
local function applyMarkers(mod, bar)
    local max = UnitPowerMax("player")
    local readable = not U.IsSecret(max) and type(max) == "number" and max > 0

    for i = 1, T.SIZE.BAR_MARKER_MAX do
        local value = tonumber(mod:Get("powerMarker" .. i)) or 0
        if readable and value > 0 and value <= max then
            markerScratch[i] = value / max * 100
        else
            markerScratch[i] = 0
        end
    end

    if powerMarkers and powerMarkers.Owner ~= bar then
        powerMarkers.Hide()
        powerMarkers = nil
    end

    if not powerMarkers then
        powerMarkers = W.BarMarkers(bar)
        if not powerMarkers then return end
        powerMarkers.Owner = bar
    end

    powerMarkers.Set(markerScratch)
end

--- Reconstruit tout : ancrages, corps, visibilité, silence du client. Ne
--- tourne que sur changement de réglage ou d'arrivée en jeu — jamais depuis un
--- chemin qui bat.
---@param mod table
local function apply(mod)
    local health = healthBar()
    if health then setupBar(mod, health, "health") end

    local power = powerBar()
    if power then
        setupBar(mod, power, "power")
        applyMarkers(mod, power)
    end

    paintedHealth, paintedHealthMax = -1, -1
    paintedPower,  paintedPowerMax  = -1, -1
    refreshHealth(mod)
    refreshPower(mod)
end

-- =========================================================================
--  Déclaration du module
-- =========================================================================

BUI:RegisterModule(MODULE, {
    title    = L["Personal resources"],
    category = "Interface",
    -- Juste au-dessus de la ressource de classe : les deux pages parlent de ce
    -- qui s'affiche sous le personnage, et celle-ci porte l'interrupteur de
    -- l'affichage — ce qui commande se lit avant ce qui décore.
    order    = 14,

    defaults = {
        -- La valeur à droite, le pourcentage à gauche : c'est la répartition
        -- du client quand il écrit les deux, celle que l'œil connaît déjà. Un
        -- ancrage n'est pas une case : aucun n'agit tant que rien n'est coché
        -- au-dessus de lui.
        healthNoText        = false,
        healthValue         = false,
        healthValueAnchor   = "RIGHT",
        healthPercent       = false,
        healthPercentAnchor = "LEFT",

        powerNoText         = false,
        powerValue          = false,
        powerValueAnchor    = "RIGHT",
        powerPercent        = false,
        powerPercentAnchor  = "LEFT",

        textSize            = T.SIZE.BAR_TEXT_SIZE,

        -- Repères de la barre de ressource, en points de ressource — 30 vaut
        -- trente points, quel que soit le maximum du moment. **Zéro éteint le
        -- repère** : c'est la glissière elle-même qui s'annule, sans case à
        -- cocher de plus (même motif que le seuil de brillance de la rangée de
        -- ressource de classe). Aucun n'agit donc à l'installation.
        powerMarker1        = 0,
        powerMarker2        = 0,
        powerMarker3        = 0,
    },

    options = (function()
        --- Grise une ligne dès que « Aucun texte » est coché sur sa barre.
        ---@param noneKey string
        ---@return fun(): boolean
        local function silenced(noneKey)
            return function()
                local mod = BUI.Modules:Get(MODULE)
                return not mod or mod:Get(noneKey) == true
            end
        end

        --- Une ligne d'ancrage, sous la case qui la commande — grisée si la
        --- case est décochée, ou si sa barre est réduite au silence.
        ---@param key string
        ---@param text string
        ---@param needs string
        ---@param noneKey string
        ---@param reason string
        ---@return table
        local function anchorRow(key, text, needs, noneKey, reason)
            return {
                type     = "dropdown",
                key      = key,
                text     = text,
                tooltip  = L["Personal anchor tip"],
                indent   = true,
                values   = {
                    { value = "LEFT",   label = L["Anchor left"] },
                    { value = "CENTER", label = L["Anchor center"] },
                    { value = "RIGHT",  label = L["Anchor right"] },
                },
                disabled = function()
                    local mod = BUI.Modules:Get(MODULE)
                    if not mod then return true end
                    if mod:Get(noneKey) then return true end
                    return not mod:Get(needs)
                end,
                disabledReason = reason,
            }
        end

        --- Une glissière de repère. Les trois sont identiques à leur numéro
        --- près : elles se fabriquent donc, comme les lignes d'ancrage.
        ---
        --- **Zéro éteint le repère**, et c'est ce que dit le libellé de la
        --- valeur : sans cela il faudrait une case à cocher par trait, soit
        --- trois cases pour trois glissières qui savent déjà s'annuler.
        ---
        --- La borne haute couvre toutes les ressources à jauge — énergie,
        --- puissance runique, maelström… plafonnent sous les deux cents, talents
        --- compris. Une glissière ne peut pas suivre le maximum du personnage,
        --- qui bouge avec la forme et le moment ; un repère poussé au-delà du
        --- maximum courant reste simplement éteint.
        ---@param index number
        ---@return table
        local function markerRow(index)
            return {
                type     = "slider",
                key      = "powerMarker" .. index,
                text     = L["Personal marker"]:format(index),
                tooltip  = L["Personal marker tip"],
                indent   = true,
                min      = 0,
                max      = 200,
                step     = 5,
            }
        end

        return {
            { type = "header", text = L["General"] },
            {
                type     = "toggle",
                text     = L["Show personal resources"],
                tooltip  = L["Show personal resources tip"],
                get      = readShow,
                set      = writeShow,
                disabled = inCombat,
            },
            {
                type     = "slider",
                key      = "textSize",
                text     = L["Personal text size"],
                tooltip  = L["Personal text size tip"],
                min      = T.SIZE.BAR_TEXT_SIZE_MIN,
                max      = T.SIZE.BAR_TEXT_SIZE_MAX,
                step     = 1,
                disabled = function()
                    local mod = BUI.Modules:Get(MODULE)
                    return not (mod and (barSpeaks(mod, "health")
                                         or barSpeaks(mod, "power")))
                end,
                disabledReason = L["Personal text needs one"],
            },

            { type = "header", text = L["Health bar"] },
            {
                type    = "toggle",
                key     = "healthNoText",
                text    = L["Personal no text"],
                tooltip = L["Personal no text tip"],
            },
            -- En rouge sous la case, et non dans son infobulle : c'est une
            -- limite qui se constate en jeu, pas une précision qu'on va
            -- chercher. Faire taire le client ne se voit que s'il parlait —
            -- et il ne parle sur ces barres que si le mode Édition le lui
            -- demande. Sans cette ligne, la case a l'air cassée.
            --
            -- La note est répétée sous la case de l'autre barre : le mode
            -- Édition n'a qu'un seul réglage pour les deux, mais une ligne
            -- posée sous la seule barre de vie se lirait comme ne valant que
            -- pour elle.
            { type = "alert", text = L["Personal no text needs bar text"] },
            {
                type     = "toggle",
                key      = "healthValue",
                text     = L["Personal value text"],
                tooltip  = L["Personal value text tip"],
                disabled = silenced("healthNoText"),
                disabledReason = L["No text active"],
            },
            anchorRow("healthValueAnchor", L["Personal value anchor"],
                      "healthValue", "healthNoText", L["Needs value text"]),
            {
                type     = "toggle",
                key      = "healthPercent",
                text     = L["Personal percent text"],
                tooltip  = L["Personal percent text tip"],
                disabled = silenced("healthNoText"),
                disabledReason = L["No text active"],
            },
            anchorRow("healthPercentAnchor", L["Personal percent anchor"],
                      "healthPercent", "healthNoText", L["Needs percent text"]),

            { type = "header", text = L["Resource bar"] },
            {
                type    = "toggle",
                key     = "powerNoText",
                text    = L["Personal no text"],
                tooltip = L["Personal no text tip"],
            },
            { type = "alert", text = L["Personal no text needs bar text"] },
            {
                type     = "toggle",
                key      = "powerValue",
                text     = L["Personal value text"],
                tooltip  = L["Personal value text tip"],
                disabled = silenced("powerNoText"),
                disabledReason = L["No text active"],
            },
            anchorRow("powerValueAnchor", L["Personal value anchor"],
                      "powerValue", "powerNoText", L["Needs value text"]),
            {
                type     = "toggle",
                key      = "powerPercent",
                text     = L["Personal percent text"],
                tooltip  = L["Personal percent text tip"],
                disabled = silenced("powerNoText"),
                disabledReason = L["No text active"],
            },
            anchorRow("powerPercentAnchor", L["Personal percent anchor"],
                      "powerPercent", "powerNoText", L["Needs percent text"]),

            { type = "header", text = L["Personal markers"], indent = true },
            markerRow(1), markerRow(2), markerRow(3),
        }
    end)(),

    OnEnable = function(self)
        apply(self)

        -- Ce qui fait bouger les nombres. Les événements d'unité sont émis
        -- pour tout le groupe : le filtre sur le joueur est la première chose
        -- que fait chaque abonnement, avant tout calcul (règle 7).
        local healthChanged = function(_, unit)
            if unit ~= "player" then return end
            refreshHealth(self)
        end
        self:RegisterEvent("UNIT_HEALTH",    healthChanged)
        self:RegisterEvent("UNIT_MAXHEALTH", healthChanged)

        local powerChanged = function(_, unit)
            if unit ~= "player" then return end
            refreshPower(self)
        end
        self:RegisterEvent("UNIT_POWER_UPDATE",   powerChanged)
        self:RegisterEvent("UNIT_POWER_FREQUENT", powerChanged)

        -- Les repères sont posés contre le maximum : quand il bouge — forme,
        -- talents, ressource affichée qui change avec la spécialisation — ils
        -- se reposent avec lui. Événements rares, jamais le chemin qui bat.
        local maxChanged = function(_, unit)
            if unit ~= "player" then return end
            refreshPower(self)
            local bar = powerBar()
            if bar then applyMarkers(self, bar) end
        end
        self:RegisterEvent("UNIT_MAXPOWER",     maxChanged)
        -- La barre change de ressource avec la forme : le maximum repart de
        -- zéro, le texte aussi.
        self:RegisterEvent("UNIT_DISPLAYPOWER", maxChanged)

        -- L'arrivée en jeu reconstruit : c'est là qu'un cadre du client qui
        -- n'existait pas encore finit par exister.
        self:RegisterEvent("PLAYER_ENTERING_WORLD", function() apply(self) end)
    end,

    OnDisable = function()
        for _, widget in pairs(texts) do
            widget:Hide()
        end

        if powerMarkers then powerMarkers.Hide() end
        -- On ne rend que ce qu'on a pris : les textes que le réglage du jeu
        -- cachait déjà restent cachés (voir `muted`).
        for fs in pairs(muted) do
            muted[fs] = nil
            fs:Show()
        end
    end,

    OnSettingChanged = function(self)
        apply(self)
    end,
})
