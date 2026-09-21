-- =========================================================================
--  Bshamel UI — sonde des fenêtres
--
--  Elle répond à une seule question, celle que la lecture de la source ne
--  tranche pas : **où, sur une fenêtre du client, un glisser répond-il ?**
--
--  Le moteur de déplacement (`UI/Move.lua`) prend une fenêtre par son
--  `OnMouseDown`. Un enfant qui reçoit la souris et qui couvre le corps de la
--  fenêtre intercepte le clic avant elle : la fenêtre paraît alors « non
--  déplaçable » alors qu'elle est parfaitement branchée. C'est ce qui s'était
--  produit sur la recherche de groupe de *Forever*, dont les trois pages
--  couvrent toute la fenêtre.
--
--  La sonde mesure donc, pour chaque fenêtre :
--
--    · **la prise** — le pourcentage de sa surface où aucun enfant preneur de
--      souris ne se trouve, échantillonné sur une grille. 100 %, le glisser
--      répond partout ; 0 %, il ne répond nulle part, et il faut un point
--      d'accroche (`DRAG_HANDLES`) ;
--    · **les bloqueurs** — les enfants preneurs de souris qui couvrent le plus,
--      avec leur nom, pour savoir *sur quoi* brancher ce point d'accroche ;
--    · l'existence, la visibilité, et si le cadre reçoit la souris lui-même.
--
--  ## Marche à suivre
--
--    1. installer la sonde sur le client à mesurer
--       (`dev/scripts/install-probe.ps1`) ;
--    2. en jeu, **ouvrir les fenêtres une par une** — métiers, grimoire,
--       talents, sacs, hauts faits… La sonde relève chacune au moment où elle
--       s'affiche, sans rien demander. Les fenêtres chargées à la demande
--       n'existent pas avant leur première ouverture : c'est le seul moment où
--       on peut les voir ;
--    3. `/buiwin` pour le résumé en jeu, `/buiwin metier` pour le détail d'une ;
--    4. `/reload`, puis lire `BshamelUIProbeWindowsDB` dans WTF.
--
--  Rien de ce fichier ne part chez un joueur : il vit sous `dev/`, que
--  `.pkgmeta` exclut du zip et `check-design.sh` de ses garde-fous.
-- =========================================================================

-- Ce fichier ne lit rien de `Data.lua` : il n'a pas besoin du namespace de l'addon.

-- -------------------------------------------------------------------------
--  Ce qu'on regarde
-- -------------------------------------------------------------------------

--- Le registre de `UI/Move.lua`, recopié. Il sert **à marquer**, pas à limiter :
--- la sonde regarde aussi tout ce que le client déclare dans `UIPanelWindows`,
--- et c'est comme ça qu'elle trouve les fenêtres qui manquent au registre.
---
--- Pour le régénérer après une modification du registre :
---
---     { sed -n '/^local PRELOADED = {/,/^}/p' UI/Move.lua \
---         | grep -oE '"[A-Za-z_][A-Za-z0-9_]*"' | tr -d '"';
---       sed -n '/^local ON_DEMAND = {/,/^}/p' UI/Move.lua \
---         | grep -oE '\{ *"[^}]*\}' | grep -oE '"[A-Za-z_][A-Za-z0-9_]*"' \
---         | tr -d '"'; } | sort -u
local REGISTRY = {
    "AchievementFrame",
    "AddonList",
    "ArchaeologyFrame",
    "AuctionHouseFrame",
    "BankFrame",
    "BlackMarketFrame",
    "CalendarFrame",
    "ChallengesKeystoneFrame",
    "CharacterFrame",
    "ChatConfigFrame",
    "ClassTrainerFrame",
    "CollectionsJournal",
    "CommunitiesFrame",
    "CurrencyTransferMenu",
    "DelvesCompanionConfigurationFrame",
    "DelvesDifficultyPickerFrame",
    "DressUpFrame",
    "EncounterJournal",
    "FlightMapFrame",
    "FriendsFrame",
    "GenericTraitFrame",
    "GossipFrame",
    "GuildBankFrame",
    "GuildControlUI",
    "GuildInviteFrame",
    "GuildRegistrarFrame",
    "HelpFrame",
    "HouseFinderFrame",
    "HousingDashboardFrame",
    "InspectFrame",
    "ItemInteractionFrame",
    "ItemSocketingFrame",
    "ItemTextFrame",
    "ItemUpgradeFrame",
    "LFGDungeonReadyDialog",
    "LFGParentFrame",
    "LootFrame",
    "MacroFrame",
    "MailFrame",
    "MajorFactionRenownFrame",
    "MerchantFrame",
    "PVEFrame",
    "PetStableFrame",
    "PetitionFrame",
    "PlayerSpellsFrame",
    "ProfessionsBookFrame",
    "ProfessionsCustomerOrdersFrame",
    "ProfessionsFrame",
    "QuestFrame",
    "QuestLogPopupDetailFrame",
    "RaidParentFrame",
    "ReadyCheckFrame",
    "ScrappingMachineFrame",
    "StableFrame",
    "StackSplitFrame",
    "TabardFrame",
    "TradeFrame",
    "TradeSkillFrame",
    "TransmogFrame",
    "WardrobeFrame",
    "WeeklyRewardsFrame",
    "WorldMapFrame",
}

--- Les sacs et la fenêtre de jet de butin ne passent pas par le registre : ils
--- ont leur propre section dans le moteur. On les relève quand même — leur
--- prise se mesure pareil, et un sac qu'on ne peut pas saisir se diagnostique
--- avec les mêmes chiffres.
local EXTRA = {
    "ContainerFrame1", "ContainerFrame2", "ContainerFrame3",
    "ContainerFrameCombinedBags",
    "GroupLootContainer", "GroupLootFrame1",
    -- Écartée du registre à dessein (le module Général la met à l'échelle),
    -- mais sa prise renseigne sur le modèle dont héritent les autres.
    "GameMenuFrame",
}

--- Finesse de la grille d'échantillonnage. Impair des deux côtés : le centre
--- exact de la fenêtre est ainsi toujours un point mesuré, et c'est là qu'on
--- pose le curseur d'instinct.
local GRID_X, GRID_Y = 21, 13

--- En deçà, un bloqueur n'est pas cité : il y a des dizaines de petits boutons
--- sur une fenêtre, et les lister tous noierait celui qui compte.
local BLOCKER_MIN = 0.05

-- -------------------------------------------------------------------------
--  Outils
-- -------------------------------------------------------------------------
-- Tout ce qui vient du client passe par `ask` : la sonde tourne sur des clients
-- inconnus, et une méthode absente ne doit pas l'arrêter en silence. Même
-- doctrine que `UI/Shade.lua`.

---@param obj table
---@param method string
---@return any
local function ask(obj, method, ...)
    local fn = obj and obj[method]
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, obj, ...)
    if ok then return value end
    return nil
end

--- Une valeur **secrète** du client : elle ne se compare pas, ne se calcule pas
--- et ne se convertit pas. Le piège est qu'elle passe `type()` sans se
--- signaler — une chaîne secrète *est* une chaîne — et que c'est l'opération
--- suivante qui lève, ailleurs. Même prédicat que `U.IsSecret` dans l'addon.
---@param value any
---@return boolean
local function isSecret(value)
    return issecretvalue ~= nil and issecretvalue(value) == true
end

--- `true` franc et rien d'autre. Un secret vaut « non » : le client cache cette
--- réponse-là, conclure à sa place serait plus faux que s'abstenir.
---@param value any
---@return boolean
local function isTrue(value)
    if isSecret(value) then return false end
    return value ~= nil and value ~= false
end

--- Un nombre lisible, ou `nil`. Le garde-fou de tout ce qui se calcule ensuite.
---@param value any
---@return number|nil
local function number(value)
    if isSecret(value) then return nil end
    if type(value) ~= "number" then return nil end
    return value
end

--- Une chaîne lisible, ou `nil`. Une chaîne secrète s'écrit `nil` dans les
--- SavedVariables et lève si on la concatène : on l'écarte à la source.
---@param value any
---@return string|nil
local function text(value)
    if isSecret(value) then return nil end
    if type(value) ~= "string" or value == "" then return nil end
    return value
end

--- Rectangle d'un cadre en **pixels d'écran**, donc comparable à celui d'un
--- cadre d'une autre échelle.
---@param frame table
---@return number|nil left, number|nil bottom, number|nil right, number|nil top
local function screenRect(frame)
    local left   = number(ask(frame, "GetLeft"))
    local bottom = number(ask(frame, "GetBottom"))
    local width  = number(ask(frame, "GetWidth"))
    local height = number(ask(frame, "GetHeight"))
    local scale  = number(ask(frame, "GetEffectiveScale"))

    if not (left and bottom and width and height) then return nil end
    if not scale or scale <= 0 then scale = 1 end

    return left * scale, bottom * scale,
           (left + width) * scale, (bottom + height) * scale
end

--- Nom lisible d'un cadre anonyme : son chemin de débogage, dernier segment
--- compris — c'est lui qui dit quoi brancher.
---@param frame table
---@return string
local function label(frame)
    return text(ask(frame, "GetName"))
        or text(ask(frame, "GetDebugName"))
        or "(anonyme)"
end

-- -------------------------------------------------------------------------
--  La mesure
-- -------------------------------------------------------------------------

--- Table de travail, réutilisée d'une fenêtre à l'autre.
local takers = {}

--- Collecte les descendants **preneurs de souris et visibles** de `frame`.
---
--- On descend sous les cadres qui prennent la souris au lieu de s'arrêter à
--- eux : un conteneur preneur peut porter des boutons qui, eux, comptent
--- séparément — et surtout, s'arrêter donnerait une prise juste mais une liste
--- de bloqueurs inutilisable.
---@param frame table
---@param out table
---@param depth integer
local function collectTakers(frame, out, depth)
    if depth > 8 then return end
    if isTrue(ask(frame, "IsForbidden")) then return end

    local children = { }
    local ok, list = pcall(function() return { frame:GetChildren() } end)
    if ok and type(list) == "table" then children = list end

    for i = 1, #children do
        local child = children[i]
        if type(child) == "table" then
            if isTrue(ask(child, "IsVisible")) then
                if isTrue(ask(child, "IsMouseEnabled")) then
                    out[#out + 1] = child
                end
                collectTakers(child, out, depth + 1)
            end
        end
    end
end

--- Le point `x, y` est-il couvert par l'un des preneurs ?
---
--- **Le premier trouvé gagne**, et ce n'est pas un raccourci : la collecte
--- descend en profondeur, donc un conteneur preneur figure avant les boutons
--- qu'il porte. Le point est ainsi attribué au conteneur, et c'est exactement
--- ce qu'on veut lire — c'est sur lui qu'un point d'accroche se branche, pas
--- sur ses trente boutons.
---@param rects table
---@param x number
---@param y number
---@return table|nil  le preneur, quand il y en a un
local function coveredBy(rects, x, y)
    for i = 1, #rects do
        local r = rects[i]
        if x >= r.left and x <= r.right and y >= r.bottom and y <= r.top then
            return r
        end
    end
    return nil
end

--- Relève une fenêtre. Renvoie la fiche, ou `nil` si elle n'est pas mesurable
--- à cet instant (cachée, sans ancrage, interdite).
---@param name string
---@return table|nil
local function measure(name)
    local frame = _G[name]
    if type(frame) ~= "table" then return nil end
    if isTrue(ask(frame, "IsForbidden")) then return nil end

    local record = {
        name    = name,
        shown   = isTrue(ask(frame, "IsShown")),
        visible = isTrue(ask(frame, "IsVisible")),
        mouse   = isTrue(ask(frame, "IsMouseEnabled")),
        kind    = text(ask(frame, "GetObjectType")),
    }

    -- Le glisser du moteur passe par ces deux scripts. Un cadre qui en porte
    -- déjà un n'est pas un problème — on s'ajoute derrière (`HookScript`) —
    -- mais savoir qu'il en a un explique parfois un comportement.
    record.onMouseDown = ask(frame, "GetScript", "OnMouseDown") ~= nil
    record.onDragStart = ask(frame, "GetScript", "OnDragStart") ~= nil

    local left, bottom, right, top = screenRect(frame)
    if not left then
        record.grip = nil
        record.note = "sans rectangle (jamais affichée ?)"
        return record
    end

    record.width  = math.floor(right - left + 0.5)
    record.height = math.floor(top - bottom + 0.5)

    if record.width <= 0 or record.height <= 0 then
        record.note = "rectangle vide"
        return record
    end

    -- Les preneurs, avec leur rectangle relevé une fois.
    wipe(takers)
    collectTakers(frame, takers, 1)

    local rects = {}
    for i = 1, #takers do
        local child = takers[i]
        local cl, cb, cr, ct = screenRect(child)
        if cl then
            rects[#rects + 1] = {
                frame  = child,
                left   = cl, bottom = cb, right = cr, top = ct,
                hits   = 0,
            }
        end
    end

    -- La grille. Un point par case, le centre de la fenêtre toujours dedans.
    local free, total = 0, 0
    for ix = 1, GRID_X do
        local x = left + (right - left) * ((ix - 0.5) / GRID_X)
        for iy = 1, GRID_Y do
            local y = bottom + (top - bottom) * ((iy - 0.5) / GRID_Y)
            total = total + 1
            local hit = coveredBy(rects, x, y)
            if hit then hit.hits = hit.hits + 1 else free = free + 1 end
        end
    end

    record.grip    = math.floor((free / total) * 100 + 0.5)
    record.takers  = #rects

    -- Les bloqueurs qui comptent, du plus couvrant au moins.
    table.sort(rects, function(a, b) return a.hits > b.hits end)

    -- Nos propres cadres, s'il y en a. La bande de saisie de la barre de titre
    -- en est un, et savoir si elle est **là** est la moitié du diagnostic : une
    -- fenêtre qui ne se déplace pas parce que la bande manque et une fenêtre
    -- qui ne se déplace pas malgré elle ne se corrigent pas du tout pareil.
    record.buiGrip = false
    for i = 1, #rects do
        if rects[i].frame.buiOwn == true then record.buiGrip = true end
    end

    local blockers = {}
    for i = 1, #rects do
        local r = rects[i]
        local share = r.hits / total
        -- Les nôtres passent **quel que soit leur poids** : la bande couvre une
        -- vingtaine de pixels sur sept cents, donc bien moins que le seuil, et
        -- c'est justement elle qu'on vient lire.
        if (share >= BLOCKER_MIN or r.frame.buiOwn == true) and #blockers < 10 then
            blockers[#blockers + 1] = {
                name    = label(r.frame),
                kind    = text(ask(r.frame, "GetObjectType")),
                covers  = math.floor(share * 100 + 0.5),
                -- La marque que l'addon pose sur ses propres cadres. C'est par
                -- elle qu'on reconnaît **notre** bande de saisie dans le relevé :
                -- elle apparaît comme un preneur de souris posé sur la barre de
                -- titre, et c'est exactement ce qu'on veut y lire.
                bui     = r.frame.buiOwn == true,
            }
        end
    end
    record.blockers = blockers

    return record
end

-- -------------------------------------------------------------------------
--  Le relevé
-- -------------------------------------------------------------------------

--- nom -> fiche, tenue à jour au fil des ouvertures.
local readings = {}

--- nom -> vrai, pour ne brancher qu'une fois.
local hooked = {}

--- nom -> vrai, pour les fenêtres que le registre de l'addon connaît.
local inRegistry = {}
for i = 1, #REGISTRY do inRegistry[REGISTRY[i]] = true end

--- Toutes les fenêtres à regarder : celles du registre, celles que le client
--- déclare lui-même dans `UIPanelWindows`, et la poignée qu'on suit à part.
---@return table  nom -> vrai
local function candidates()
    local out = {}
    for i = 1, #REGISTRY do out[REGISTRY[i]] = true end
    for i = 1, #EXTRA do out[EXTRA[i]] = true end

    if type(_G.UIPanelWindows) == "table" then
        for name in pairs(_G.UIPanelWindows) do
            if type(name) == "string" then out[name] = true end
        end
    end
    return out
end

--- Écrit ce qu'on sait dans les SavedVariables. Appelé à chaque relevé : une
--- session qui se termine par un plantage a quand même laissé son fichier.
local function publish()
    local list = {}
    for name, record in pairs(readings) do
        record.registry = inRegistry[name] or false
        list[name] = record
    end

    local version, build, _, tocversion = GetBuildInfo()
    BshamelUIProbeWindowsDB = {
        probed  = date and date("%Y-%m-%d %H:%M") or nil,
        client  = {
            version    = version,
            build      = build,
            tocversion = tocversion,
            project    = _G.WOW_PROJECT_ID,
        },
        grid    = GRID_X .. "x" .. GRID_Y,
        windows = list,
    }
end

--- Relève une fenêtre et retient le résultat. Le relevé **remplace** le
--- précédent : une fenêtre rouvre souvent sur un autre onglet, et c'est la
--- dernière image qui vaut — on la reprendra en ouvrant l'onglet qui intéresse.
---@param name string
local function read(name)
    local record = measure(name)
    if not record then return end
    readings[name] = record
    publish()
end

--- Relève **tout ce qui est mesurable à cet instant**.
---@return integer
local function scan()
    local count = 0
    for name in pairs(candidates()) do
        local record = measure(name)
        if record then
            readings[name] = record
            count = count + 1
        end
    end
    publish()
    return count
end

-- -------------------------------------------------------------------------
--  Le branchement
-- -------------------------------------------------------------------------
-- Une fenêtre ne se mesure qu'**affichée** : cachée, elle n'a pas de rectangle,
-- et chargée à la demande, elle n'existe pas du tout. On se pose donc sur son
-- `OnShow` et on relève une fraction de seconde plus tard — le client dispose
-- son contenu *après* avoir montré la fenêtre, et relever tout de suite
-- donnerait une prise mesurée sur une fenêtre encore vide.

local DELAY = 0.15

---@param name string
local function hook(name)
    if hooked[name] then return end

    local frame = _G[name]
    if type(frame) ~= "table" then return end
    if type(frame.HookScript) ~= "function" then return end
    if isTrue(ask(frame, "IsForbidden")) then return end

    hooked[name] = true
    pcall(frame.HookScript, frame, "OnShow", function()
        C_Timer.After(DELAY, function() read(name) end)
    end)

    -- Déjà ouverte au moment où on se branche : on ne l'attend pas.
    if isTrue(ask(frame, "IsVisible")) then
        C_Timer.After(DELAY, function() read(name) end)
    end
end

local function hookAll()
    for name in pairs(candidates()) do hook(name) end
end

-- -------------------------------------------------------------------------
--  Le résumé en jeu
-- -------------------------------------------------------------------------

local function say(msg) print("|cff00aeef[fenêtres]|r " .. msg) end

---@param grip number|nil
---@return string
local function tint(grip)
    if grip == nil then return "|cff808080" end
    if grip >= 60 then return "|cff40d060" end
    if grip >= 25 then return "|cffe0c040" end
    if grip > 0   then return "|cffe08040" end
    return "|cffe05050"
end

--- Les fiches, la plus mauvaise prise d'abord : c'est là qu'est la décision.
---@return table[]
local function sorted()
    local out = {}
    for _, record in pairs(readings) do out[#out + 1] = record end
    table.sort(out, function(a, b)
        local ga = a.grip or 999
        local gb = b.grip or 999
        if ga ~= gb then return ga < gb end
        return a.name < b.name
    end)
    return out
end

---@param record table
local function line(record)
    -- Une fenêtre que le registre ne connaît pas est signalée : sa prise a beau
    -- être parfaite, le moteur ne la branche pas, et c'est l'autre moitié de la
    -- question qu'on est venu poser.
    local mark = inRegistry[record.name] and "" or " |cffe0c040[hors registre]|r"

    if record.grip == nil then
        say(string.format("|cff808080%-34s   — %s|r%s", record.name,
            record.note or "non mesurée", mark))
        return
    end

    say(string.format("%s%3d %%|r prise  %-34s |cff808080%dx%d, %d preneur(s), bande %s%s|r%s",
        tint(record.grip), record.grip, record.name,
        record.width or 0, record.height or 0, record.takers or 0,
        record.buiGrip and "posée" or "ABSENTE",
        record.mouse and "" or ", NE PREND PAS LA SOURIS", mark))
end

---@param needle string
local function detail(needle)
    local found = 0
    for _, record in ipairs(sorted()) do
        if string.find(string.lower(record.name), needle, 1, true) then
            found = found + 1
            line(record)
            if record.blockers then
                for i = 1, #record.blockers do
                    local b = record.blockers[i]
                    print(string.format("      %3d %%  %s%s |cff808080(%s)|r",
                        b.covers,
                        b.bui and "|cff00aeef" or "",
                        b.name, b.kind or "?"))
                end
            end
        end
    end
    if found == 0 then say("rien de relevé à ce nom-là.") end
end

---@param arg string
local function report(arg)
    if arg ~= "" and arg ~= "tout" and arg ~= "all" then
        detail(arg)
        return
    end

    local all = sorted()
    if #all == 0 then
        say("rien de relevé. Ouvrez des fenêtres, ou tapez |cffffffff/buiwin scan|r.")
        return
    end

    local shown = 0
    for i = 1, #all do
        local record = all[i]
        -- Le résumé ne montre que ce qui pose question : une fenêtre qui se
        -- prend partout n'a rien à dire, et la liste complète est dans WTF.
        if arg == "tout" or arg == "all" or (record.grip or 100) < 60 then
            line(record)
            shown = shown + 1
        end
    end

    if shown == 0 then
        say("toutes les fenêtres relevées se prennent partout. |cff40d060Rien à corriger.|r")
    end

    say(string.format("|cff808080%d fenêtre(s) relevée(s). Détail : /buiwin <nom>. "
        .. "Tout : /buiwin tout.|r", #all))
    say("puis |cffffffff/reload|r, et lire BshamelUIProbeWindowsDB dans WTF.")
end

-- -------------------------------------------------------------------------
--  Amorçage
-- -------------------------------------------------------------------------

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        hookAll()
        say("posée. Ouvrez vos fenêtres, puis |cffffffff/buiwin|r.")
        return
    end

    -- Une fenêtre chargée à la demande vient d'arriver : elle n'existait pas au
    -- branchement, elle existe maintenant.
    hookAll()
end)

_G.SLASH_BSHAMELUIWINDOWS1 = "/buiwin"
SlashCmdList["BSHAMELUIWINDOWS"] = function(msg)
    local arg = string.lower((string.gsub(msg or "", "^%s*(.-)%s*$", "%1")))

    if arg == "scan" then
        hookAll()
        local count = scan()
        say(string.format("%d fenêtre(s) mesurable(s) à cet instant.", count))
        arg = ""
    end

    report(arg)
end
