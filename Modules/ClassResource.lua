-- =========================================================================
--  Bshamel UI — Modules/ClassResource.lua
--  La ressource qui se compte : points de combo, puissance sacrée, chi,
--  fragments d'âme, charges des arcanes, essence, runes, cumuls d'Arme-tempête.
--
--  Ces sept-là n'ont en commun ni leur classe, ni leur mécanisme, ni la façon
--  dont le client les publie. Elles ont en commun **la seule chose qui compte
--  ici** : ce sont des ressources entières, qu'on lit en les comptant et qu'on
--  dépense par unités. Le jeu les affiche sous le personnage, à la taille qu'il
--  a choisie et à l'endroit où il a décidé — ce qui est exactement le regard
--  qu'on ne peut pas se permettre au milieu d'un combat.
--
--  Le module ne dessine rien : `UI/Widgets/ResourceBar.lua` sait poser une
--  rangée de cases. Ce fichier dit **laquelle** des sept le personnage porte, et
--  combien de cases sont pleines.
--
--  Deux mécanismes, pas un. Six ressources sont des *powers* du client, lues par
--  `UnitPower` ; les cumuls d'Arme-tempête du chaman améliorations sont une
--  **aura**, que le client ne range dans aucune ressource. Le module les traite
--  côte à côte parce que le joueur, lui, les regarde de la même façon.
--
--  Réversibilité (règle 6) : la rangée se cache, et rien d'autre n'est touché —
--  on ne masque aucune barre du client, on en ajoute une à côté.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local U    = BUI.Util
local W    = BUI.Widgets
local L    = ns.L

local MODULE = "ClassResource"

--- Grise une ligne tant que l'interrupteur qui la commande est éteint.
---@param key string
---@return fun(): boolean
local function requires(key)
    return function()
        local mod = BUI.Modules:Get(MODULE)
        return not (mod and mod:Get(key))
    end
end

--- Grise une ligne tant qu'un palier n'est pas posé — et, avant tout, tant que la
--- rangée elle-même est éteinte. Les deux conditions vont toujours ensemble ici :
--- séparer une couleur de palier de la rangée qui la porte n'a pas de sens.
---@param key string
---@return fun(): boolean
local function needsStep(key)
    return function()
        local mod = BUI.Modules:Get(MODULE)
        if not (mod and mod:Get("show")) then return true end
        return (mod:Get(key) or 0) <= 0
    end
end

-- =========================================================================
--  Les sept ressources
-- =========================================================================
-- **L'ordre est celui de la détection, et il n'est pas indifférent.** On retient
-- la première dont le personnage a une réserve non nulle. Les points de combo
-- ferment la marche : c'est la ressource que le client déclare le plus
-- volontiers en dehors des spécialisations qui s'en servent — un druide qui
-- change de forme en est le cas courant — et la placer en dernier fait qu'une
-- ressource franche l'emporte toujours sur elle.
--
-- `field` est le nom dans `Enum.PowerType`, `token` celui sous lequel le client
-- publie sa teinte. Une entrée dont le client ne connaît pas le champ est sautée
-- sans bruit : c'est le test de capacité de la règle 1, appliqué à une liste.

local POWERS = {
    { field = "HolyPower",     token = "HOLY_POWER"     },
    { field = "Chi",           token = "CHI"            },
    { field = "SoulShards",    token = "SOUL_SHARDS"    },
    { field = "ArcaneCharges", token = "ARCANE_CHARGES" },
    { field = "Essence",       token = "ESSENCE"        },
    { field = "Runes",         token = "RUNES"          },
    { field = "ComboPoints",   token = "COMBO_POINTS"   },
}

--- Arme-tempête, l'aura à cumuls du chaman améliorations.
---
--- `max` est écrit ici parce que rien ne le publie : ce n'est pas une réserve du
--- client, c'est un plafond de cumuls. Une valeur fausse ne casse rien, elle
--- dessine une case de trop ou de moins.
local MAELSTROM = { spell = 344179, max = 10, aura = true }

--- Numéro de la spécialisation Améliorations du chaman.
---
--- **C'est le passif qu'on voulait interroger, et il ne se laisse pas
--- interroger.** Le cumul (344179) et le passif qui le donne sont deux sorts
--- distincts : demander au client s'il « connaît » le cumul rend toujours non,
--- un buff ne se connaissant pas. C'est ce qui laissait la rangée éteinte sur un
--- chaman améliorations.
---
--- Un numéro de spécialisation est une **donnée de jeu**, au même titre que les
--- listes de sorts du menu de téléportation — pas un test de version (règle 1) :
--- rien ici ne dépend du numéro de build. Faux, il ne casse rien ; il rend
--- seulement la rangée muette, et le filet de `usesMaelstrom` la rallume au
--- premier cumul.
local ENHANCEMENT = 263

--- Spécialisation courante, ou `nil`. Deux chemins, du plus récent au plus
--- ancien : la fonction a migré dans `C_SpecializationInfo`, les globales
--- existent encore, et aucun des deux n'est garanti pour toujours.
---@return number|nil
local function specID()
    local api = C_SpecializationInfo

    local index
    if api and api.GetSpecialization then
        index = api.GetSpecialization()
    elseif GetSpecialization then
        index = GetSpecialization()
    end
    if not index then return nil end

    if api and api.GetSpecializationInfo then
        return (api.GetSpecializationInfo(index))
    end
    if GetSpecializationInfo then
        return (GetSpecializationInfo(index))
    end
    return nil
end

--- Type de ressource du client pour une entrée, ou `nil` s'il ne le connaît pas.
---@param source table
---@return number|nil
local function powerType(source)
    local kinds = Enum and Enum.PowerType
    local kind  = kinds and kinds[source.field]
    if type(kind) ~= "number" then return nil end
    return kind
end

--- Cumuls d'une aura du joueur, ou zéro.
---
--- Trois noms de champ, du plus récent au plus ancien : le client a renommé le
--- compteur de cumuls en cours de route. Une valeur **secrète** vaut zéro et non
--- « on ne sait pas » : elle ne se compare ni ne s'additionne (voir
--- `U.IsSecret`), et une rangée vide est une réponse honnête là où une erreur
--- Lua n'en est pas une.
---@param spellID number
---@return number
local function auraStacks(spellID)
    local auras = C_UnitAuras
    if not (auras and auras.GetPlayerAuraBySpellID) then return 0 end

    local aura = auras.GetPlayerAuraBySpellID(spellID)
    if type(aura) ~= "table" then return 0 end

    local count = aura.applications or aura.charges or aura.count
    if U.IsSecret(count) or type(count) ~= "number" then return 0 end
    return count
end

--- Le personnage compte-t-il des cumuls d'Arme-tempête ?
---
--- La spécialisation d'abord : c'est la seule réponse qui vaille aussi quand la
--- rangée est **vide**, c'est-à-dire au moment précis où l'on doit décider de
--- l'afficher. L'aura ensuite, en filet — elle ne répond que tant qu'il y a au
--- moins un cumul, donc elle ne peut pas être le test principal, mais elle
--- rattrape un numéro de spécialisation devenu faux. Le module la relit à chaque
--- aura du joueur tant qu'aucune ressource n'a été retenue (voir `OnEnable`).
---@return boolean
local function usesMaelstrom()
    if specID() == ENHANCEMENT then return true end
    return auraStacks(MAELSTROM.spell) > 0
end

--- La ressource que le personnage porte en ce moment, ou `nil`.
---
--- Recalculée aux seuls moments où elle peut changer — connexion, changement de
--- spécialisation, de talents ou de forme —, jamais depuis un chemin qui bat.
---@return table|nil
local function detect()
    if usesMaelstrom() then return MAELSTROM end

    for i = 1, #POWERS do
        local source = POWERS[i]
        local kind   = powerType(source)
        if kind and (UnitPowerMax("player", kind) or 0) > 0 then
            source.power = kind
            return source
        end
    end

    return nil
end

---@param source table
---@return number
local function readValue(source)
    if source.aura then return auraStacks(source.spell) end
    return UnitPower("player", source.power) or 0
end

---@param source table
---@return number
local function readMax(source)
    if source.aura then return source.max end
    return UnitPowerMax("player", source.power) or 0
end

-- =========================================================================
--  Teintes
-- =========================================================================

---@return ColorMixin|nil
local function classColor()
    local _, class = UnitClass("player")
    return T.ClassColor(class)
end

--- Teinte des cases pleines, d'après le mode choisi.
---
--- Le mode « du jeu » a **deux replis**, et le premier n'est pas une prudence :
--- Arme-tempête n'est pas une ressource du client, il n'en publie donc aucune
--- teinte, et c'est le cas normal pour un chaman améliorations. La couleur de
--- classe prend le relais — elle dit au moins de qui est la rangée.
---@param mod table
---@param source table|nil
---@return ColorMixin
local function fillColor(mod, source)
    local mode = mod:Get("colorMode")

    if mode == "custom" then
        return T.ColorFrom(mod:Get("fillColor"), T.COLOR.RESOURCE_FILL)
    end
    if mode == "class" then
        return classColor() or T.COLOR.RESOURCE_FILL
    end

    return (source and T.PowerColor(source.token, source.power))
        or classColor()
        or T.COLOR.RESOURCE_FILL
end

--- Les trois paliers de couleur, dans l'ordre où la page les présente.
---
--- Trois, et pas une liste ouverte : au-delà, on décrit une teinte par point et
--- ce n'est plus un palier, c'est un dégradé qu'on ne saurait plus lire. Trois
--- suffisent à dire « ça monte, c'est bien, c'est plein » sur la plus longue des
--- ressources.
local STEPS = {
    { at = "threshold",  color = "thresholdColor",  fallback = "RESOURCE_ALERT"  },
    { at = "threshold2", color = "thresholdColor2", fallback = "RESOURCE_ALERT2" },
    { at = "threshold3", color = "thresholdColor3", fallback = "RESOURCE_ALERT3" },
}

--- Table de travail des paliers passés au widget, ses cases comprises. Leur
--- nombre ne change jamais : on les remplit à nouveau plutôt que de les refaire.
local levels = { {}, {}, {} }

--- Les paliers **tels qu'ils sont réglés**, dans l'ordre de la page. Le tri et
--- l'écart des paliers éteints sont l'affaire du widget : c'est lui qui les lit.
---@param mod table
---@return table
local function paletteSteps(mod)
    for i = 1, #STEPS do
        local step = STEPS[i]
        local slot = levels[i]

        slot.at    = mod:Get(step.at) or 0
        slot.color = T.ColorFrom(mod:Get(step.color), T.COLOR[step.fallback])
    end

    return levels
end

-- =========================================================================
--  La rangée
-- =========================================================================

local bar
--- Ressource active, ou `nil` : le personnage n'en a aucune qui se compte.
local active
--- Dernière valeur peinte. `-1` force le prochain passage à peindre, quelle que
--- soit la valeur lue — c'est ce qui rattrape un changement de réglage.
local painted = -1

---@param mod table
local function updateShown(mod)
    if not bar then return end

    -- Le seul endroit qui décide si la rangée se voit, y compris quand le
    -- réglage vient d'être décoché : les abonnements aux événements de ressource,
    -- eux, restent en place tant que le module tourne.
    if not mod:Get("show") then
        bar:Hide()
        return
    end

    -- L'aperçu prime sur tout : c'est le seul moment où l'on cherche la rangée
    -- au lieu de la lire, et une rangée qui se cache pendant qu'on la place ne
    -- se place pas.
    if mod:Get("preview") then
        bar:Show()
        return
    end

    if not active then
        bar:Hide()
        return
    end

    if mod:Get("hideWhenEmpty") and painted <= 0 then
        bar:Hide()
        return
    end

    bar:Show()
end

--- Relit la ressource et repeint, si elle a bougé.
---
--- Appelée depuis les événements de ressource du client, qui sont émis pour
--- **toutes** les unités : le filtre sur le joueur est donc la première chose que
--- fait l'abonnement, avant d'arriver ici. Le test sur `painted` ferme la marche
--- — une ressource qui n'a pas changé ne se repeint pas (règle 7).
---@param mod table
local function refresh(mod)
    if not (bar and active) then return end
    if not mod:Get("show") then return end
    if mod:Get("preview") then return end

    local value = readValue(active)
    if value == painted then return end

    painted = value
    bar:SetValue(value)
    updateShown(mod)
end

--- Reconstruit tout : quelle ressource, combien de cases, quelles teintes.
--- C'est le seul chemin qui alloue des couleurs, et il ne tourne que sur
--- changement de réglage ou de spécialisation.
---@param mod table
local function apply(mod)
    if not mod:Get("show") then
        if bar then
            bar:SetPreview(false)
            bar:Hide()
        end
        return
    end

    if not bar then
        bar = W.ResourceBar({
            isLocked = function() return mod:Get("locked") == true end,
            getPos   = function() return mod:Get("x"), mod:Get("y") end,
            setPos   = function(x, y)
                mod:Set("x", x)
                mod:Set("y", y)
            end,
        })
        if not bar then return end
    end

    active = detect()

    -- Sans ressource, la rangée d'aperçu prend la longueur la plus courante
    -- plutôt que de disparaître : on règle la position d'un chaman améliorations
    -- sur son mage, et une rangée d'une seule case ne se place pas.
    local cells = (active and readMax(active)) or 0
    if cells <= 0 then cells = T.SIZE.RESOURCE_PREVIEW_CELLS end

    bar:SetLayout(cells, mod:Get("cellWidth"), mod:Get("cellHeight"), mod:Get("gap"),
        mod:Get("cellCount") or 0)
    bar:SetPalette(fillColor(mod, active), paletteSteps(mod))
    bar:SetShowCount(mod:Get("showCount") == true)

    -- La case commande, le curseur dit à partir de quand. Décochée, le seuil ne
    -- se lit pas — un zéro éteint l'effet côté widget.
    bar:SetGlow(mod:Get("thresholdGlow") and (mod:Get("glowAt") or 0) or 0)
    bar:SetPreview(mod:Get("preview") == true)

    painted = -1
    refresh(mod)
    updateShown(mod)
end

-- =========================================================================
--  Déclaration du module
-- =========================================================================

BUI:RegisterModule(MODULE, {
    title    = L["Class resource"],
    category = "Interface",
    order    = 15,

    defaults = {
        show          = false,
        locked        = false,
        preview       = false,
        showCount     = false,
        hideWhenEmpty = false,

        colorMode      = "power",
        fillColor      = T.ColorTable(T.COLOR.RESOURCE_FILL),
        -- Trois paliers, tous éteints d'origine : la rangée s'ouvre d'une seule
        -- teinte, et qui veut une montée l'écrit lui-même. Les couleurs, elles,
        -- sont posées d'avance — un palier qu'on allume doit se voir tout de
        -- suite, pas obliger à ouvrir un sélecteur pour exister.
        threshold       = 0,
        thresholdColor  = T.ColorTable(T.COLOR.RESOURCE_ALERT),
        threshold2      = 0,
        thresholdColor2 = T.ColorTable(T.COLOR.RESOURCE_ALERT2),
        threshold3      = 0,
        thresholdColor3 = T.ColorTable(T.COLOR.RESOURCE_ALERT3),

        thresholdGlow  = false,
        -- Cinq : la longueur de la ressource la plus courante, donc « quand c'est
        -- plein » pour la plupart des personnages. Le curseur ne part jamais de
        -- zéro — ce serait une case cochée qui ne fait rien.
        glowAt         = 5,

        cellWidth  = T.SIZE.RESOURCE_CELL_W,
        cellHeight = T.SIZE.RESOURCE_CELL_H,
        gap        = T.SIZE.RESOURCE_GAP,

        -- Zéro : une case par point, tout d'un tenant. C'est la disposition que
        -- le jeu donne à ses propres ressources, et celle qu'on attend en
        -- arrivant.
        cellCount  = 0,

        -- Position de départ, en décalage de centre à centre : sous le
        -- personnage, là où le jeu pose déjà ses propres ressources. Réglage sans
        -- contrôle — il se change en déplaçant la rangée à la souris.
        x = 0,
        y = -T.SIZE.RESOURCE_DROP,
    },

    options = {
        { type = "description", text = L["Class resource notice"] },

        { type = "header", text = L["General"] },
        {
            type    = "toggle",
            key     = "show",
            text    = L["Show resource bar"],
            tooltip = L["Show resource bar tip"],
        },
        {
            type     = "toggle",
            key      = "preview",
            text     = L["Resource preview"],
            tooltip  = L["Resource preview tip"],
            disabled = requires("show"),
        },
        {
            type     = "toggle",
            key      = "locked",
            text     = L["Lock resource bar"],
            tooltip  = L["Lock resource bar tip"],
            disabled = requires("show"),
        },

        { type = "header", text = L["Resource shape"] },
        {
            type     = "slider",
            key      = "cellWidth",
            text     = L["Resource cell width"],
            tooltip  = L["Resource cell width tip"],
            min      = T.SIZE.RESOURCE_CELL_MIN,
            max      = T.SIZE.RESOURCE_CELL_MAX,
            step     = 1,
            disabled = requires("show"),
        },
        {
            type     = "slider",
            key      = "cellHeight",
            text     = L["Resource cell height"],
            tooltip  = L["Resource cell height tip"],
            min      = T.SIZE.RESOURCE_CELL_MIN,
            max      = T.SIZE.RESOURCE_CELL_MAX,
            step     = 1,
            disabled = requires("show"),
        },
        {
            type     = "slider",
            key      = "gap",
            text     = L["Resource cell gap"],
            tooltip  = L["Resource cell gap tip"],
            min      = 0,
            max      = T.SIZE.RESOURCE_GAP_MAX,
            step     = 1,
            disabled = requires("show"),
        },
        {
            type     = "slider",
            key      = "cellCount",
            text     = L["Resource cell count"],
            tooltip  = L["Resource cell count tip"],
            min      = 0,
            max      = T.SIZE.RESOURCE_MAX_CELLS,
            step     = 1,
            disabled = requires("show"),
        },
        {
            type     = "toggle",
            key      = "showCount",
            text     = L["Resource count"],
            tooltip  = L["Resource count tip"],
            disabled = requires("show"),
        },
        {
            type     = "toggle",
            key      = "hideWhenEmpty",
            text     = L["Hide empty resource"],
            tooltip  = L["Hide empty resource tip"],
            disabled = requires("show"),
        },

        { type = "header", text = L["Resource colours"] },
        {
            type     = "dropdown",
            key      = "colorMode",
            text     = L["Resource colour source"],
            tooltip  = L["Resource colour source tip"],
            values   = {
                { value = "power",  label = L["Game resource colour"] },
                { value = "class",  label = L["Class colour"] },
                { value = "custom", label = L["Custom colour"] },
            },
            disabled = requires("show"),
        },
        {
            type     = "color",
            key      = "fillColor",
            text     = L["Resource fill colour"],
            tooltip  = L["Resource fill colour tip"],
            indent   = true,
            disabled = function()
                local mod = BUI.Modules:Get(MODULE)
                if not (mod and mod:Get("show")) then return true end
                return mod:Get("colorMode") ~= "custom"
            end,
            disabledReason = L["Resource fill colour needs custom"],
        },
        {
            type     = "slider",
            key      = "threshold",
            text     = L["Resource threshold"],
            tooltip  = L["Resource threshold tip"],
            min      = 0,
            max      = T.SIZE.RESOURCE_MAX_CELLS,
            step     = 1,
            disabled = requires("show"),
        },
        {
            type     = "color",
            key      = "thresholdColor",
            text     = L["Resource threshold colour"],
            tooltip  = L["Resource threshold colour tip"],
            indent   = true,
            disabled = needsStep("threshold"),
            disabledReason = L["Resource threshold colour needs threshold"],
        },
        {
            type     = "slider",
            key      = "threshold2",
            text     = L["Resource threshold 2"],
            tooltip  = L["Resource threshold 2 tip"],
            min      = 0,
            max      = T.SIZE.RESOURCE_MAX_CELLS,
            step     = 1,
            -- Grisé tant que le palier du dessus n'est pas posé : un deuxième
            -- palier sans premier n'est pas un deuxième palier, c'est le premier
            -- écrit sur la mauvaise ligne.
            disabled = needsStep("threshold"),
            disabledReason = L["Resource threshold needs previous"],
        },
        {
            type     = "color",
            key      = "thresholdColor2",
            text     = L["Resource threshold colour 2"],
            tooltip  = L["Resource threshold colour tip"],
            indent   = true,
            disabled = needsStep("threshold2"),
            disabledReason = L["Resource threshold colour needs threshold"],
        },
        {
            type     = "slider",
            key      = "threshold3",
            text     = L["Resource threshold 3"],
            tooltip  = L["Resource threshold 3 tip"],
            min      = 0,
            max      = T.SIZE.RESOURCE_MAX_CELLS,
            step     = 1,
            disabled = needsStep("threshold2"),
            disabledReason = L["Resource threshold needs previous"],
        },
        {
            type     = "color",
            key      = "thresholdColor3",
            text     = L["Resource threshold colour 3"],
            tooltip  = L["Resource threshold colour tip"],
            indent   = true,
            disabled = needsStep("threshold3"),
            disabledReason = L["Resource threshold colour needs threshold"],
        },

        -- L'effet brillant est **au même niveau** que les paliers de couleur, et
        -- non en dessous de l'un d'eux : il ne suit aucun, il a son propre seuil.
        -- Deux façons indépendantes de dire « c'est prêt », et rien n'oblige à ce
        -- qu'elles tombent au même endroit.
        {
            type     = "toggle",
            key      = "thresholdGlow",
            text     = L["Resource threshold glow"],
            tooltip  = L["Resource threshold glow tip"],
            disabled = requires("show"),
        },
        {
            type     = "slider",
            key      = "glowAt",
            text     = L["Resource glow threshold"],
            tooltip  = L["Resource glow threshold tip"],
            min      = 1,
            max      = T.SIZE.RESOURCE_MAX_CELLS,
            step     = 1,
            disabled = function()
                local mod = BUI.Modules:Get(MODULE)
                if not (mod and mod:Get("show")) then return true end
                return not mod:Get("thresholdGlow")
            end,
        },
    },

    OnEnable = function(self)
        apply(self)

        -- Ce qui fait bouger le **nombre**. Les deux premiers sont émis pour
        -- toutes les unités du groupe : le filtre sur le joueur est la première
        -- chose qu'ils font, avant tout calcul (règle 7).
        local changed = function(_, unit)
            if unit ~= "player" then return end
            refresh(self)
        end
        self:RegisterEvent("UNIT_POWER_UPDATE",   changed)
        self:RegisterEvent("UNIT_POWER_FREQUENT", changed)

        -- Les runes ne passent pas par les événements de ressource : le client
        -- les annonce à part, parce que chacune a son propre temps de recharge.
        -- Ce qu'on en affiche est le nombre de prêtes, que `UnitPower` rend.
        self:RegisterEvent("RUNE_POWER_UPDATE", function() refresh(self) end)

        -- Arme-tempête est une aura : elle n'émet aucun événement de ressource.
        --
        -- Le second cas est le filet de `usesMaelstrom` : aucune ressource n'a
        -- été retenue, et un cumul vient d'apparaître. On redétecte, la rangée
        -- s'allume, et le passage cesse — il ne coûte qu'une lecture d'aura, et
        -- seulement sur les personnages où l'on n'a rien trouvé.
        self:RegisterEvent("UNIT_AURA", function(_, unit)
            if unit ~= "player" then return end
            if not self:Get("show") then return end

            if active then
                if active.aura then refresh(self) end
                return
            end

            if auraStacks(MAELSTROM.spell) > 0 then apply(self) end
        end)

        -- Ce qui fait changer la **ressource elle-même**, ou la longueur de la
        -- rangée : spécialisation, talents, forme du druide, plafond relevé par
        -- un talent. Rares, et chacun oblige à tout reconstruire.
        --
        -- **Deux abonnements et non un**, parce que le premier argument n'a pas
        -- le même sens d'un événement à l'autre : les trois derniers annoncent
        -- une unité, `PLAYER_ENTERING_WORLD` annonce s'il s'agit d'une première
        -- connexion. Un filtre unique sur « player » écarterait donc la moitié
        -- des tirs — dont celui de l'arrivée en jeu.
        local rebuild = function() apply(self) end
        self:RegisterEvent("PLAYER_ENTERING_WORLD", rebuild)
        self:RegisterEvent("PLAYER_TALENT_UPDATE",  rebuild)

        local rebuildUnit = function(_, unit)
            if unit ~= "player" then return end
            apply(self)
        end
        self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", rebuildUnit)
        self:RegisterEvent("UNIT_DISPLAYPOWER",             rebuildUnit)
        self:RegisterEvent("UNIT_MAXPOWER",                 rebuildUnit)
    end,

    OnDisable = function()
        if not bar then return end
        bar:SetPreview(false)
        bar:Hide()
    end,

    OnSettingChanged = function(self)
        -- Tous les réglages de cette page décident de la même chose — à quoi
        -- ressemble la rangée —, et la reconstruire coûte une poignée d'ancrages.
        -- Une table d'appliqueurs par clé n'aurait fait qu'une liste de plus à
        -- tenir à jour, pour le même résultat.
        apply(self)
    end,
})
