-- =========================================================================
--  Bshamel UI — Modules/Timers.lua
--  Suivi des temps restants : le vol, et le craft.
--
--  **Une seule page pour deux attentes qui n'ont rien à voir**, et c'est
--  voulu : ce qu'elles ont en commun est exactement ce qui les rend utiles —
--  le jeu les impose sans jamais dire combien elles durent, et on les regarde
--  dans le même état d'esprit, celui de savoir quand on pourra reprendre la
--  main. Deux pages voisines n'auraient dit que cela, deux fois.
--
--  Elles ont vécu dans leur propre catégorie, au même rang qu'*Outils*. Elle
--  ne tenait que deux pages de trois cases, et la barre latérale n'a que deux
--  étages : une catégorie pour si peu se lisait comme une section vide.
--
--  ## Ce que le client publie, et ce qu'il tait
--
--  Les deux moitiés de ce fichier ne se ressemblent pas, et la différence est
--  toute dans ce que le client accepte de dire.
--
--  **Le vol ne se lit pas.** Ni l'ancienne fenêtre (`TaxiFrame.lua`) ni la
--  nouvelle carte (`Blizzard_FlightMap`) ne publient de durée : un coût, des
--  positions, rien d'autre (voir `dev/docs/API_NOTES.md`). Le temps affiché
--  vient donc de deux voies qui ne se mélangent jamais dans un même vol : une
--  **estimation** par distance à l'envol, puis une **mesure** — le temps réel
--  entre l'envol et l'atterrissage, retenu par paire de points et qui remplace
--  l'estimation au vol suivant sur le même trajet.
--
--  **Le craft se lit entièrement.** `UnitCastingInfo` donne le début et la fin
--  de chaque incantation, et `C_TradeSkillUI.CraftRecipe` la taille du lot au
--  moment du clic. Aucune constante supposée nulle part, et un décompte exact
--  dès le premier objet.
--
--  Le cadre, lui, ne fait pas la différence : un temps restant se lit pareil
--  quelle que soit sa provenance. C'est l'infobulle de chaque réglage qui la
--  dit, parce que c'est là qu'elle a des conséquences.
--
--  ## Les deux clients
--
--  La page charge partout. Le vol a d'abord été réservé à *Forever*, faute
--  d'avoir été demandé ailleurs ; l'API est pourtant la même des deux côtés, et
--  écarter retail aurait demandé de deviner le client dans le code — ce que la
--  règle 1 interdit, et à juste titre : rien ici ne dépend du client, tout
--  dépend de ce que le client publie.
--
--  Le module ne dessine rien : `UI/Widgets/TimerBar.lua` pose les deux cadres.
--
--  Réversibilité (règle 6) : les cadres se cachent, les suivis s'arrêtent.
--  Rien n'est modifié ailleurs — seulement lu.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local U    = BUI.Util
local W    = BUI.Widgets
local L    = ns.L

local MODULE = "Timers"

-- =========================================================================
--  VOL — ce que le client ne publie pas
-- =========================================================================

--- Vitesse supposée d'un griffon ou d'une wyverne, en unités de carte par
--- seconde (yards). Personne ne la publie : c'est une hypothèse de départ, pas
--- une mesure. Elle ne sert qu'au tout premier vol d'un trajet, et c'est ce qui
--- la rend tolérable ; dès le second, la durée réellement mesurée prend sa
--- place et cette valeur ne compte plus pour lui.
local ASSUMED_SPEED = 20

--- Délai au-delà duquel un embarquement relevé ne vaut plus confirmation de
--- décollage.
---
--- **`UnitOnTaxi("player")` ne peut pas servir de garde ici.** Le client le
--- teste lui-même sur cet événement (`EventImplementation.lua`), mais sur
--- *Forever* il vaut encore `false` quand `PLAYER_CONTROL_LOST` arrive —
--- relevé en jeu par `/bui vol`, et c'est ce qui empêchait le cadre de
--- paraître une fois la carte de vol corrigée. Le drapeau se pose plus tard.
---
--- Ce qui confirme le décollage est donc l'**enchaînement** : on vient de
--- cliquer sur un nœud, et le contrôle est perdu dans la foulée. Rien d'autre
--- ne produit cette suite — on n'est pas étourdi dans un griffon. Le délai est
--- celui d'un aller-retour serveur, large ; au-delà, une perte de contrôle
--- parle d'autre chose.
local BOARDING_GRACE = 10

--- Exemple d'aperçu, pour régler la position du cadre sans attendre un vol.
local FLIGHT_PREVIEW = 185

--- Ce que le dernier embarquement a donné, étape par étape.
---
--- Cette moitié du fichier échoue **en silence** : chacune de ses lectures peut
--- se taire, et le seul symptôme est un cadre qui ne vient pas — ce qui est
--- arrivé deux fois en jeu, d'abord faute d'interroger la bonne carte, ensuite
--- à cause du drapeau ci-dessus. Cette trace est ce que `/bui vol` relit, et
--- elle dit laquelle des étapes a manqué.
---
--- Déclarée avant tout ce qui l'écrit : une locale déclarée plus bas ne serait
--- pas visible des fonctions d'au-dessus, qui écriraient alors une globale.
local trace = {}

--- La carte à qui demander les nœuds de vol.
---
--- **`GetTaxiMapID()`, et surtout pas la carte du joueur.** Les deux ne sont
--- presque jamais la même : le réseau de vol est décrit sur la carte du
--- **continent**, pendant qu'un joueur debout chez le maître de vol est sur
--- celle de sa zone. Demander les nœuds à la seconde les demande à une carte
--- qui n'en porte aucun — la liste revient vide, le trajet n'est pas lu, et le
--- cadre reste muet sans que rien ne le dise.
---
--- C'est la fonction que le client emploie lui-même pour ouvrir sa carte de
--- vol (`Blizzard_FlightMap.lua`). Elle ne répond que pendant que cette carte
--- est ouverte, ce qui tombe bien : c'est précisément le moment où l'on
--- embarque. La carte du joueur reste en repli, faute de mieux.
---@return number|nil
local function currentMap()
    if GetTaxiMapID then
        local mapID = GetTaxiMapID()
        if mapID then return mapID end
    end

    if C_Map and C_Map.GetBestMapForUnit then
        return C_Map.GetBestMapForUnit("player")
    end
    return nil
end

--- Le nœud de départ (état « actuel ») et celui du numéro embarqué, sur la
--- carte de vol ouverte. Rend `nil` si l'un des deux manque : un trajet qu'on
--- ne sait pas situer ne se mesure ni ne s'estime.
---@param slot number
---@return number|nil fromID, number|nil toID, table|nil fromPos, table|nil toPos, number|nil uiMapID
local function readRoute(slot)
    local uiMapID = currentMap()
    trace.mapID = uiMapID
    if not uiMapID then return nil end
    if not (C_TaxiMap and C_TaxiMap.GetAllTaxiNodes) then return nil end
    if not (Enum and Enum.FlightPathState) then return nil end

    local ok, nodes = pcall(C_TaxiMap.GetAllTaxiNodes, uiMapID)
    if not (ok and type(nodes) == "table") then return nil end
    trace.nodes = #nodes

    local fromID, toID, fromPos, toPos
    for i = 1, #nodes do
        local node = nodes[i]
        if node.state == Enum.FlightPathState.Current then
            fromID, fromPos = node.nodeID, node.position
        end
        if node.slotIndex == slot then
            toID, toPos = node.nodeID, node.position
        end
    end

    trace.from, trace.to = fromID, toID

    if not (fromID and toID) then return nil end
    return fromID, toID, fromPos, toPos, uiMapID
end

---@param fromID number
---@param toID number
---@return string
local function routeKey(fromID, toID)
    return fromID .. ":" .. toID
end

--- Distance entre les deux points d'un trajet, en unités de jeu — la seule
--- chose qu'on puisse réellement calculer : `C_Map.GetMapWorldSize` donne la
--- taille de la carte, et les positions des nœuds y sont normalisées.
---@param uiMapID number|nil
---@param fromPos table|nil
---@param toPos table|nil
---@return number|nil
local function estimateSeconds(uiMapID, fromPos, toPos)
    if not (uiMapID and fromPos and toPos) then return nil end
    if not (C_Map and C_Map.GetMapWorldSize) then return nil end

    local ok, width, height = pcall(C_Map.GetMapWorldSize, uiMapID)
    trace.worldW, trace.worldH = width, height
    if not (ok and type(width) == "number" and type(height) == "number") then
        return nil
    end

    local dx = (fromPos.x - toPos.x) * width
    local dy = (fromPos.y - toPos.y) * height
    local distance = math.sqrt(dx * dx + dy * dy)
    trace.distance = distance
    if distance <= 0 then return nil end

    return distance / ASSUMED_SPEED
end

--- Relevé au clic sur un nœud, avant même que `UnitOnTaxi` ne devienne vrai :
--- la carte de vol est encore ouverte, c'est le seul moment où le trajet se
--- laisse lire.
local flightPending = {}

--- Le vol qui court, ou rien.
local flight = {}

---@param slot any
local function onBoard(slot)
    trace.slot = slot

    -- Horodaté avant toute lecture, et quoi qu'elles donnent : c'est ce
    -- moment-là — et non le trajet, qui peut rester illisible — qui confirmera
    -- le décollage à la perte de contrôle.
    flightPending.at = GetTime()

    if type(slot) ~= "number" then return end

    local fromID, toID, fromPos, toPos, uiMapID = readRoute(slot)
    if fromID and toID then
        flightPending.key      = routeKey(fromID, toID)
        flightPending.estimate = estimateSeconds(uiMapID, fromPos, toPos)
    else
        flightPending.key      = nil
        flightPending.estimate = nil
    end
end

---@param mod table
local function startFlight(mod)
    flight.active   = true
    flight.start    = GetTime()
    flight.key      = flightPending.key
    flight.estimate = flightPending.estimate

    local routes = flight.key and mod:AccountData().routes
    flight.duration = routes and routes[flight.key] or nil

    trace.key      = flight.key
    trace.estimate = flight.estimate
    trace.duration = flight.duration

    flightPending.key, flightPending.estimate, flightPending.at = nil, nil, nil
end

--- L'atterrissage : c'est ici que la mesure se retient.
---
--- Au **compte** (`AccountData`) et non au personnage : un trajet ne dépend
--- d'aucun des deux, et la bêta de *Forever* ne relit de toute façon jamais le
--- SavedVariables d'un personnage (voir `dev/docs/API_NOTES.md`).
---@param mod table
local function endFlight(mod)
    if flight.key then
        local elapsed = GetTime() - flight.start
        if elapsed > 0 then
            local data = mod:AccountData()
            data.routes = data.routes or {}
            data.routes[flight.key] = elapsed
        end
    end

    flight.active, flight.key, flight.duration, flight.estimate = false, nil, nil, nil
end

-- =========================================================================
--  CRAFT — ce que le client publie entièrement
-- =========================================================================

--- Exemple d'aperçu : l'ordre de grandeur d'un lot ordinaire, quelques
--- dizaines d'objets à deux ou trois secondes pièce.
local CRAFT_PREVIEW = 95

--- Secondes restantes et durée pleine de l'incantation de métier en cours.
---
--- Rend `nil` dans trois cas qui ne se ressemblent pas mais se traitent
--- pareil : rien n'est incanté, ce qui l'est n'est pas un craft, ou le client
--- masque ses horaires (valeur secrète). On préfère ne rien afficher plutôt
--- qu'un nombre qu'on ne sait pas justifier.
---@return number|nil remaining, number|nil duration
local function readCraftCast()
    if not UnitCastingInfo then return nil, nil end

    local _, _, _, startMs, endMs, isTradeskill = UnitCastingInfo("player")
    if not isTradeskill then return nil, nil end
    if type(startMs) ~= "number" or type(endMs) ~= "number" then return nil, nil end
    if U.IsSecret(startMs) or U.IsSecret(endMs) then return nil, nil end

    local duration = (endMs - startMs) / 1000
    if duration <= 0 then return nil, nil end

    return (endMs / 1000) - GetTime(), duration
end

--- Taille du lot, relevée au lancement — avant que la première incantation ne
--- commence. C'est le seul moment où le client la dit.
local craftPending = {}

--- Le lot qui court, ou rien.
local batch = {}

local function stopBatch()
    batch.active, batch.left, batch.castEnd, batch.castDuration = false, nil, nil, nil
end

--- Le joueur vient de lancer un lot : on retient combien d'objets il a
--- demandés. La première incantation s'en saisira.
---@param numCasts any
local function onCraftLaunched(numCasts)
    craftPending.total = (type(numCasts) == "number" and numCasts > 0) and numCasts or nil
end

--- Une incantation de métier vient de commencer.
---
--- Deux lectures d'un même événement : elle **ouvre** le lot si aucun ne
--- court, et elle en **retranche un** sinon — une incantation qui commence
--- veut dire que la précédente est finie. Le client ne publie aucun compteur
--- de ce qui reste ; celui-ci se tient donc tout seul, à partir de la taille
--- demandée et du nombre d'incantations vues.
---@return boolean crafting  faux si ce n'était pas une incantation de métier
local function onCraftCastStart()
    local remaining, duration = readCraftCast()
    if not remaining then return false end

    if batch.active and batch.left then
        batch.left = batch.left - 1
    else
        batch.active = true
        batch.left   = craftPending.total or 1
    end
    craftPending.total = nil

    batch.castEnd      = GetTime() + remaining
    batch.castDuration = duration
    return true
end

-- =========================================================================
--  Les deux cadres
-- =========================================================================

local flightBar, craftBar

---@param mod table
---@return number|nil remaining
local function flightSource(mod)
    if flight.active then
        -- La mesure d'abord, l'estimation à défaut.
        local total = flight.duration or flight.estimate
        if not total then return nil end

        local remaining = total - (GetTime() - flight.start)
        if remaining < 0 then remaining = 0 end
        return remaining
    end

    if mod:Get("previewFlightBar") then return FLIGHT_PREVIEW end
end

---@param mod table
---@return number|nil remaining
local function craftSource(mod)
    if batch.active and batch.left and batch.castEnd then
        local current = batch.castEnd - GetTime()
        if current < 0 then current = 0 end

        local remaining = current + (batch.left - 1) * (batch.castDuration or 0)

        -- Le dernier objet est sorti : on referme soi-même, sans attendre
        -- l'événement de fin. Il arrive, mais s'en remettre à lui seul
        -- laisserait un lot fantôme le jour où il manquerait.
        if remaining <= 0 then
            stopBatch()
            return nil
        end

        return remaining
    end

    if mod:Get("previewCraftBar") then return CRAFT_PREVIEW end
end

---@param mod table
local function applyFlightBar(mod)
    if not mod:Get("showFlightBar") then
        if flightBar then flightBar:Stop() end
        return
    end

    if not flightBar then
        flightBar = W.TimerBar({
            title    = L["Time remaining"],
            source   = function() return flightSource(mod) end,
            isLocked = function() return mod:Get("lockFlightBar") == true end,
            getPos   = function() return mod:Get("flightBarX"), mod:Get("flightBarY") end,
            setPos   = function(x, y)
                mod:Set("flightBarX", x)
                mod:Set("flightBarY", y)
            end,
            getScale = function() return mod:Get("flightBarScale") end,
            setScale = function(scale) mod:Set("flightBarScale", scale) end,
        })
        if not flightBar then return end
    end

    flightBar:ApplyScale()
    flightBar:ApplyLock()
    flightBar:ApplyPosition()
    flightBar:Start()
end

---@param mod table
local function applyCraftBar(mod)
    if not mod:Get("showCraftBar") then
        if craftBar then craftBar:Stop() end
        return
    end

    if not craftBar then
        craftBar = W.TimerBar({
            title    = L["Time remaining"],
            source   = function() return craftSource(mod) end,
            isLocked = function() return mod:Get("lockCraftBar") == true end,
            getPos   = function() return mod:Get("craftBarX"), mod:Get("craftBarY") end,
            setPos   = function(x, y)
                mod:Set("craftBarX", x)
                mod:Set("craftBarY", y)
            end,
            getScale = function() return mod:Get("craftBarScale") end,
            setScale = function(scale) mod:Set("craftBarScale", scale) end,
        })
        if not craftBar then return end
    end

    craftBar:ApplyScale()
    craftBar:ApplyLock()
    craftBar:ApplyPosition()
    craftBar:Start()
end

---@param mod table
local function applyAll(mod)
    applyFlightBar(mod)
    applyCraftBar(mod)
end

-- =========================================================================
--  Déclaration du module
-- =========================================================================

--- Les trois portes d'entrée d'un lot de craft. Toutes portent `numCasts` en
--- deuxième argument, et le bouton « Tout créer » du client y arrive par
--- `ProfessionsRecipeTransactionMixin:CraftRecipe`, qui ne fait que les
--- appeler : coiffer les trois suffit à tout couvrir.
local CRAFT_CALLS = { "CraftRecipe", "CraftEnchant", "CraftSalvage" }

--- Grise une ligne tant que l'interrupteur qui la commande est éteint.
---@param key string
---@return fun(): boolean
local function requires(key)
    return function()
        local mod = BUI.Modules:Get(MODULE)
        return not (mod and mod:Get(key))
    end
end

BUI:RegisterModule(MODULE, {
    title    = L["Remaining times"],
    category = "QoL",
    order    = 85,

    defaults = {
        showFlightBar    = false,
        previewFlightBar = false,
        lockFlightBar    = false,
        -- Position des cadres, en décalage de centre à centre, et leur échelle.
        -- Réglages sans contrôle dans la page : ils se changent en faisant
        -- glisser le cadre, ou en tirant son coin.
        flightBarX     = 0,
        flightBarY     = 0,
        flightBarScale = 1,

        showCraftBar    = false,
        previewCraftBar = false,
        lockCraftBar    = false,
        -- Le cadre du craft démarre une hauteur plus bas que celui du vol. En
        -- jeu les deux ne s'affichent jamais ensemble — on ne fabrique pas sur
        -- un griffon —, mais leurs deux **aperçus** s'allument bien en même
        -- temps, et c'est précisément le moment où l'on cherche où les poser.
        craftBarX      = 0,
        craftBarY      = -(T.SIZE.COUNTDOWN_TEXT + T.SIZE.SECTION_H + T.SIZE.TOOL_PAD * 2),
        craftBarScale  = 1,
    },

    options = {
        { type = "header", text = L["Flight"] },
        {
            type    = "toggle",
            key     = "showFlightBar",
            text    = L["Flight timer"],
            tooltip = L["Flight timer tip"],
        },
        {
            type     = "toggle",
            key      = "previewFlightBar",
            text     = L["Flight timer preview"],
            tooltip  = L["Flight timer preview tip"],
            disabled = requires("showFlightBar"),
        },
        {
            type     = "toggle",
            key      = "lockFlightBar",
            text     = L["Lock flight timer"],
            tooltip  = L["Lock flight timer tip"],
            disabled = requires("showFlightBar"),
        },

        { type = "header", text = L["Crafting"] },
        {
            type    = "toggle",
            key     = "showCraftBar",
            text    = L["Craft timer"],
            tooltip = L["Craft timer tip"],
        },
        {
            type     = "toggle",
            key      = "previewCraftBar",
            text     = L["Craft timer preview"],
            tooltip  = L["Craft timer preview tip"],
            disabled = requires("showCraftBar"),
        },
        {
            type     = "toggle",
            key      = "lockCraftBar",
            text     = L["Lock craft timer"],
            tooltip  = L["Lock craft timer tip"],
            disabled = requires("showCraftBar"),
        },
    },

    OnEnable = function(self)
        applyAll(self)

        local live = function() return self:IsEnabled() end

        -- ---------------------------------------------------------------
        --  Vol
        -- ---------------------------------------------------------------

        U.GuardedHook("TakeTaxiNode", function(slot) onBoard(slot) end, live)

        self:RegisterEvent("PLAYER_CONTROL_LOST", function()
            -- On vient d'embarquer, ou le client dit déjà qu'on est en vol :
            -- l'un des deux suffit. Le premier est le signal fiable sur
            -- *Forever* (voir `BOARDING_GRACE`), le second reste accepté pour
            -- le client qui poserait son drapeau à temps.
            local boarded = flightPending.at ~= nil
                and (GetTime() - flightPending.at) <= BOARDING_GRACE
            local onTaxi = (UnitOnTaxi and UnitOnTaxi("player")) or false

            trace.controlLost = true
            trace.onTaxi      = onTaxi
            trace.boarded     = boarded

            if flight.active then return end
            if not (boarded or onTaxi) then return end
            startFlight(self)

            -- Ce rappel n'est pas redondant avec celui d'`OnEnable` : un cadre
            -- caché ne reçoit plus d'`OnUpdate`, et c'est lui qui le rouvre
            -- (voir `W.TimerBar`).
            applyFlightBar(self)
        end)

        self:RegisterEvent("PLAYER_CONTROL_GAINED", function()
            if not flight.active then return end
            endFlight(self)
        end)

        -- ---------------------------------------------------------------
        --  Craft
        -- ---------------------------------------------------------------

        if C_TradeSkillUI then
            for i = 1, #CRAFT_CALLS do
                local name = CRAFT_CALLS[i]
                if type(C_TradeSkillUI[name]) == "function" then
                    U.GuardedHook(C_TradeSkillUI, name, function(_, numCasts)
                        onCraftLaunched(numCasts)
                    end, live)
                end
            end
        end

        -- L'événement arrive pour **tout** ce que le joueur incante ; seul un
        -- craft ouvre le cadre. Même raison qu'au-dessus pour le rappel.
        self:RegisterEvent("UNIT_SPELLCAST_START", function(_, unit)
            if unit ~= "player" then return end
            if onCraftCastStart() then applyCraftBar(self) end
        end)

        -- La fin du lot, par les trois chemins que le client emprunte : la
        -- séquence s'arrête, elle est interrompue, ou elle échoue. Les deux
        -- derniers sont exactement ceux que la page des métiers écoute.
        self:RegisterEvent("UPDATE_TRADESKILL_CAST_STOPPED", stopBatch)

        local failed = function(_, unit)
            if unit ~= "player" then return end
            stopBatch()
        end
        self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED", failed)
        self:RegisterEvent("UNIT_SPELLCAST_FAILED",      failed)
    end,

    OnDisable = function()
        stopBatch()
        if flightBar then flightBar:Stop() end
        if craftBar  then craftBar:Stop()  end
    end,

    OnSettingChanged = function(self)
        applyAll(self)
    end,

    --- `/bui vol` : ce que le dernier embarquement a donné, étape par étape.
    ---
    --- Quatre choses peuvent se taire sans qu'aucune ne lève, et le symptôme
    --- est le même pour les quatre — un cadre qui ne vient pas. Les voici dans
    --- l'ordre où elles arrivent : le crochet d'embarquement, la carte du
    --- réseau de vol, le trajet lu dessus, et la perte de contrôle qui dit
    --- qu'on a vraiment décollé.
    DiagnoseFlight = function(self)
        self:Print(L["Flight diagnostic"])

        if trace.slot == nil then
            -- Rien du tout : le crochet n'a jamais vu passer d'embarquement.
            self:Print(L["Flight diagnostic none"])
            return
        end

        self:Print("TakeTaxiNode:", tostring(trace.slot),
            "— GetTaxiMapID:", tostring(trace.mapID),
            "— GetAllTaxiNodes:", tostring(trace.nodes))
        self:Print(L["Flight diagnostic route"],
            tostring(trace.from), "→", tostring(trace.to),
            "— " .. L["Flight diagnostic estimate"], tostring(trace.estimate),
            "— " .. L["Flight diagnostic measured"], tostring(trace.duration))

        -- Les trois nombres qui font l'estimation. Une taille de carte nulle
        -- ou absente est le cas qu'on soupçonne : elle rend la distance
        -- incalculable sans rien lever.
        self:Print("GetMapWorldSize:",
            tostring(trace.worldW), "x", tostring(trace.worldH),
            "— " .. L["Flight diagnostic distance"], tostring(trace.distance))

        self:Print("PLAYER_CONTROL_LOST:", tostring(trace.controlLost or false),
            "— UnitOnTaxi:", tostring(trace.onTaxi or false),
            "— " .. L["Flight diagnostic boarded"], tostring(trace.boarded or false))
    end,
})
