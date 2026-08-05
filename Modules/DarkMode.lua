-- =========================================================================
--  Bshamel UI — Modules/DarkMode.lua
--  Assombrir l'interface du client, élément par élément.
--
--  Le module ne teint rien : `UI/Shade.lua` sait assombrir une texture et la
--  rendre, ce fichier sait *quoi* assombrir et *quand y revenir*. C'est la même
--  séparation que le déplacement de fenêtres — `UI/Move.lua` sait déplacer,
--  `Modules/Windows.lua` sait quoi.
--
--  Le mode sombre vivait dans **Général**, où il occupait à lui seul la moitié
--  de la page et tout le haut de la colonne de réglages. Il a sa page depuis, et
--  un palier de migration (`Core/DB.lua`) déplace les réglages de ceux qui les
--  avaient changés. Le nom d'un module est une clé de base de données : déplacer
--  un réglage d'un module à l'autre se migre, ça ne se renomme pas.
--
--  Toute la difficulté est le **moment**. Beaucoup de cadres n'existent pas quand
--  le réglage est posé : les auras se recréent sans arrêt, le cadre de focus se
--  rhabille quand le focus change, les emplacements d'une visionneuse de temps de
--  recharge naissent à la première amélioration. D'où les rafraîchisseurs et les
--  deux hooks gardés ci-dessous, qui sont l'essentiel de ce fichier.
--
--  `secure = true` : le module touche aux textures des barres d'action et des
--  cadres d'unités. Teinter une texture n'est pas une action protégée, mais la
--  règle est de le déclarer dès qu'on touche à ces cadres — le core diffère alors
--  l'activation à la sortie de combat, ce qui ne coûte rien ici.
--
--  Réversibilité (CLAUDE.md règle 6) : `RestoreAll` rend chaque texture teinte à
--  sa couleur d'origine, et les hooks posés par `U.GuardedHook` deviennent
--  inertes dès que le module s'éteint.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local U    = BUI.Util
local L    = ns.L

local MODULE = "DarkMode"

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
--  Ce qui s'assombrit
-- =========================================================================

--- Clé de réglage -> élément du moteur d'assombrissement, dans l'ordre où les
--- lignes se lisent sur la page.
local DARK_ELEMENTS = {
    { key = "darkUnitFrames",      element = "unitFrames" },
    { key = "darkActionBars",      element = "actionBars" },
    { key = "darkCastBar",         element = "castBar" },
    { key = "darkAuras",           element = "auras" },
    { key = "darkCooldownManager", element = "cooldownManager" },
    { key = "darkTooltip",         element = "tooltip" },
}

---@param mod table
local function applyDarkMode(mod)
    local shade = BUI.Shade
    if not shade then return end

    local on = mod:Get("darkMode")

    for i = 1, #DARK_ELEMENTS do
        local entry = DARK_ELEMENTS[i]

        -- Chaque élément est traité pour lui seul. Sans cela, un unique cadre
        -- récalcitrant sur le premier élément emporte tous les suivants dans sa
        -- chute, et le symptôme — « seule la barre d'action réagit » — ne
        -- ressemble en rien à sa cause.
        if on and mod:Get(entry.key) then
            BUI.safecall(shade.Apply, shade, entry.element, T.SHADE_FACTOR)
        else
            BUI.safecall(shade.Restore, shade, entry.element)
        end
    end
end

--- Repasse la teinte sur un élément, en groupant les rafales (règle 7).
--- Beaucoup de cadres n'existent pas au moment où le réglage est posé : les
--- auras se recréent sans arrêt, le cadre de focus se rhabille quand le focus
--- change, et une frontière de zone reconstruit une partie de l'interface.
---@param element? string
---@param now? boolean  repasser aussi tout de suite, sans attendre
---@return function
local function refresher(element, now)
    local settle = U.Debounce(T.TIMING.SHADE_SETTLE, function()
        if BUI.Shade then BUI.Shade:Refresh(element) end
    end)

    if not now then return settle end

    local function pass()
        if BUI.Shade then BUI.Shade:Refresh(element) end
    end

    -- Trois passages, et chacun couvre ce que les autres manquent. Le premier
    -- assombrit à l'instant du clic. Le deuxième, cinq centièmes plus tard,
    -- rattrape le rhabillage que le client fait **après** avoir annoncé le
    -- changement de cible — c'est lui qui supprime le contour qui « met un temps
    -- à charger ». Le troisième est le filet : il repasse une fois la rafale
    -- retombée, quoi qu'il se soit produit entre-temps.
    return function(...)
        pass()
        C_Timer.After(T.TIMING.SHADE_QUICK, pass)
        settle(...)
    end
end

local refreshAuras      = refresher("auras")
local refreshUnitFrames = refresher("unitFrames", true)

local refreshBars       = refresher("actionBars")
local refreshShade      = refresher(nil)

-- Groupé, et non traité cadre par cadre comme les auras : `RefreshLayout`
-- reconstruit l'ensemble d'un coup, et un passage complet sur quatre
-- visionneuses reste bon marché. Surtout, `Refresh` **remplace** la liste des
-- textures teintes là où `ApplyTo` y ajoute — à cette fréquence-là, ajouter
-- ferait grossir la liste sans fin (règle 7).
local refreshCooldowns  = refresher("cooldownManager")

--- Les unités dont les auras sont dessinées par l'élément « auras ».
---
--- `UNIT_AURA` n'est pas l'événement d'une unité qu'on regarde : le client
--- l'émet pour **tout ce qui porte une aura**, donc pour les dix-neuf autres
--- membres d'un raid, leurs familiers et chaque mob du pull. Aucun de ceux-là
--- n'a la moindre texture dans cet élément — il ne couvre que les cadres de
--- buffs et de débuffs du joueur, les pools de la cible et du focus, et la
--- plaque personnelle (voir `NESTED.auras` dans `UI/Shade.lua`).
---
--- Sans ce filtre, chaque aura qui bat quelque part dans le raid arme le
--- regroupement, et le parcours complet de l'élément tourne à cinq passages par
--- seconde du début à la fin du combat — pour reteindre les mêmes textures. Le
--- filtre est la première ligne du handler, avant tout calcul (règle 7).
local AURA_UNITS = {
    player = true,
    target = true,
    focus  = true,
}

---@param unit string
local function auraChanged(_, unit)
    if not AURA_UNITS[unit] then return end
    refreshAuras()
end

--- La barre de nom du **joueur**, et elle seule : c'est là que vivent les auras
--- posées sous le personnage. Les autres plaques n'ont rien qui nous concerne,
--- et une pull en monte une par mob.
---@param unit string
local function plateAdded(_, unit)
    if not U.IsTrue(UnitIsUnit(unit, "player")) then return end
    refreshAuras()
end

--- S'accroche à la reconstruction des auras d'un cadre d'unité.
---
--- C'est le seul moyen d'être à l'heure. Les auras de la cible sortent d'un pool
--- que le client remplit dans `UpdateAuras`, **sans émettre d'événement** : rien
--- n'annonce leur arrivée. Repasser à intervalles après un changement de cible
--- ne fait que parier sur le moment où il s'y mettra, et ce pari se perd — d'où
--- un contour qui mettait plusieurs secondes, jusqu'à ce qu'une aura batte
--- quelque part et déclenche `UNIT_AURA`.
---
--- `U.GuardedHook` est le seul motif de hook autorisé (CLAUDE.md règle 6) : posé
--- une fois, il devient inerte quand le module s'éteint.
---
--- Le corps traite **les auras de ce cadre-là, et tout de suite**. Un
--- rafraîchissement groupé de tout l'élément serait à la fois trop cher pour
--- être immédiat et trop lent pour être invisible ; à cette granularité-là, la
--- question ne se pose pas.
---@param mod table
local function hookAuraUpdates(mod)
    local guard = function() return mod:IsEnabled() end

    local function styleAuras(frame)
        local shade = BUI.Shade
        local pools = frame and frame.auraPools
        if not (shade and pools and pools.EnumerateActive) then return end

        for aura in pools:EnumerateActive() do
            shade:ApplyTo("auras", aura)
        end
    end

    local frames = { TargetFrame, FocusFrame }
    for i = 1, #frames do
        local frame = frames[i]
        if frame and type(frame.UpdateAuras) == "function" then
            U.GuardedHook(frame, "UpdateAuras", styleAuras, guard)
        end
    end
end

--- Visionneuses du gestionnaire de temps de recharge, par nom global.
---
--- La liste double celle de `UI/Shade.lua`, et c'est assumé : là-bas elle dit
--- *quoi teinter*, ici *quand y revenir*. Les deux se remplissent en regardant le
--- même client, mais rien n'oblige la seconde à couvrir la première — une
--- visionneuse qui ne reconstruit jamais rien n'aurait pas sa place ici.
local COOLDOWN_VIEWERS = {
    "EssentialCooldownViewer", "UtilityCooldownViewer",
    "BuffIconCooldownViewer", "BuffBarCooldownViewer",
}

--- S'accroche à la reconstruction des visionneuses de temps de recharge.
---
--- Même piège que pour les auras de la cible, et il coûte plus cher ici parce
--- qu'il est plus discret. Les visionneuses sortent leurs emplacements d'un
--- pool, et **un pool crée ses cadres au moment où il en a besoin** : ceux du
--- suivi des améliorations apparaissent quand une amélioration monte, donc bien
--- après la connexion. Un cadre qui n'existe pas encore n'est l'enfant de
--- personne, aucun parcours ne peut le trouver, et rien n'annonce sa naissance.
---
--- Les visionneuses à liste fixe — essentielle, utilitaire — masquaient le
--- défaut : leurs cadres existent tous dès la connexion, donc le passage de
--- `PLAYER_ENTERING_WORLD` les attrapait et tout semblait fonctionner.
---
--- `RefreshLayout` et non `RefreshData` : la première ne s'exécute que lorsque
--- l'ensemble affiché change, la seconde à chaque tic de temps de recharge. On
--- se raccroche à ce qui bouge, pas à ce qui bat.
---@param mod table
local function hookCooldownViewers(mod)
    local guard = function() return mod:IsEnabled() end

    for i = 1, #COOLDOWN_VIEWERS do
        local viewer = _G[COOLDOWN_VIEWERS[i]]
        if viewer and type(viewer.RefreshLayout) == "function" then
            U.GuardedHook(viewer, "RefreshLayout", refreshCooldowns, guard)
        end
    end
end

-- =========================================================================
--  Déclaration du module
-- =========================================================================

BUI:RegisterModule(MODULE, {
    title    = L["Dark mode"],
    -- En tête de la catégorie, sous « Général » : il décide de l'allure de tout ce
    -- qui suit dans la liste, et un réglage qui commande les autres se lit avant
    -- eux.
    category = "Interface",
    order    = 5,
    secure   = true,

    defaults = {
        -- Le mode sombre est éteint, mais la liste de ce qu'il assombrit est
        -- cochée d'avance : l'allumer doit produire un effet visible tout de
        -- suite, décocher ensuite ce qu'on veut garder clair est le geste rare.
        -- Il n'y a pas de dosage — c'est la liste qui se règle, pas la
        -- profondeur du noir (voir `T.SHADE_FACTOR`).
        darkMode            = false,
        darkUnitFrames      = true,
        darkActionBars      = true,
        darkCastBar         = true,
        darkAuras           = true,
        darkCooldownManager = true,
        darkTooltip         = true,
    },

    -- L'en-tête au-dessus de l'interrupteur s'appelle « Général » et non
    -- « Mode sombre » : la page porte déjà ce nom-là, et le répéter juste en
    -- dessous donne une page qui a l'air cassée. C'est le même intitulé que sur
    -- la page de la ressource de classe, pour la même raison — une case seule
    -- sous rien du tout se lit comme un reste, pas comme un début.
    options = {
        { type = "header", text = L["General"] },
        {
            type    = "toggle",
            key     = "darkMode",
            text    = L["Enable dark mode"],
            tooltip = L["Dark mode tip"],
        },

        { type = "header", text = L["What it darkens"] },
        {
            type     = "toggle",
            key      = "darkUnitFrames",
            text     = L["Unit frames"],
            tooltip  = L["Dark unit frames tip"],
            disabled = requires("darkMode"),
        },
        {
            type     = "toggle",
            key      = "darkActionBars",
            text     = L["Action bars"],
            tooltip  = L["Dark action bars tip"],
            disabled = requires("darkMode"),
        },
        {
            type     = "toggle",
            key      = "darkCastBar",
            text     = L["Cast bar"],
            tooltip  = L["Dark cast bar tip"],
            disabled = requires("darkMode"),
        },
        {
            type     = "toggle",
            key      = "darkAuras",
            text     = L["Buffs and debuffs"],
            tooltip  = L["Dark auras tip"],
            disabled = requires("darkMode"),
        },
        {
            type     = "toggle",
            key      = "darkCooldownManager",
            text     = L["Cooldown manager"],
            tooltip  = L["Dark cooldown manager tip"],
            disabled = requires("darkMode"),
        },
        {
            type     = "toggle",
            key      = "darkTooltip",
            text     = L["Tooltip"],
            tooltip  = L["Dark tooltip tip"],
            disabled = requires("darkMode"),
        },
    },

    OnEnable = function(self)
        applyDarkMode(self)
        hookAuraUpdates(self)
        hookCooldownViewers(self)

        -- Le mode sombre se repose sur ce qui apparaît après lui : les auras se
        -- recréent sans cesse, les fenêtres chargées à la demande arrivent en
        -- cours de session, et une frontière de zone reconstruit une partie de
        -- l'interface.
        -- Les deux abonnements filtrent sur l'unité avant toute chose : voir
        -- `AURA_UNITS`, qui explique pourquoi s'en passer coûtait si cher.
        self:RegisterEvent("UNIT_AURA",             auraChanged)
        -- Les auras posées sous le personnage apparaissent avec la barre de nom
        -- du joueur, pas avec le joueur : elles arrivent donc par cet
        -- événement-là et par aucun autre.
        self:RegisterEvent("NAME_PLATE_UNIT_ADDED", plateAdded)
        self:RegisterEvent("ADDON_LOADED",          refreshShade)
        self:RegisterEvent("PLAYER_ENTERING_WORLD", refreshShade)

        self:RegisterEvent("PLAYER_TARGET_CHANGED", refreshUnitFrames)
        self:RegisterEvent("PLAYER_FOCUS_CHANGED",  refreshUnitFrames)
        self:RegisterEvent("UNIT_PET",              refreshUnitFrames)

        -- Les auras de la cible ne sont pas rafraîchies ici : `hookAuraUpdates`
        -- les traite au moment exact où le client les reconstruit, une par une.
        -- Un passage de plus sur le changement de cible ne ferait que repasser
        -- derrière lui.

        self:RegisterEvent("ACTIONBAR_PAGE_CHANGED",  refreshBars)
        self:RegisterEvent("ACTIONBAR_SLOT_CHANGED",  refreshBars)
        self:RegisterEvent("UPDATE_SHAPESHIFT_FORMS", refreshBars)
    end,

    OnDisable = function()
        if BUI.Shade then BUI.Shade:RestoreAll() end
    end,

    OnSettingChanged = function(self)
        applyDarkMode(self)
    end,
})
