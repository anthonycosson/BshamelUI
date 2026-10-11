-- =========================================================================
--  Bshamel UI — Modules/BisIndex.lua
--  L'index des objets du jeu : ce qui répond à « montre-moi toutes les têtes
--  en mailles qui donnent de l'agilité ». Rien d'affiché ici — ce fichier
--  **sait**, `UI/Widgets/Bis*.lua` dessine, `Modules/BisList.lua` décide.
--
--  *Forever* seulement (sa ligne du `.toc` l'écarte de retail).
--
--  ## Pourquoi un index, et pas une requête
--
--  Aucune API ne cherche parmi les objets du jeu : `GetItemInfo` répond sur un
--  identifiant qu'on lui donne, jamais sur un critère. Il n'y a donc pas de
--  question à poser au client, il y a une liste à se constituer. On la
--  constitue en deux passes, qui ne coûtent pas du tout la même chose :
--
--  1. **Le balayage.** `C_Item.GetItemInfoInstant(id)` lit la table d'objets
--     livrée avec le client : emplacement, classe, sous-classe, icône. C'est
--     local, c'est instantané, ça ne demande rien au serveur. On passe donc
--     tous les identifiants en revue et on ne garde que ce qui s'équipe —
--     quelques milliers d'objets sur des centaines de milliers d'identifiants.
--  2. **L'hydratation.** Le nom, le niveau d'objet, le niveau requis et les
--     stats ne sont pas dans cette table : ils arrivent du serveur, un objet à
--     la fois, et `GET_ITEM_INFO_RECEIVED` dit quand. C'est la passe qui coûte,
--     et c'est elle qu'on étrangle : un paquet par battement, jamais plus.
--
--  Le résultat se range dans la base de **compte** : la liste des objets du jeu
--  ne dépend pas du personnage, et la reconstituer à chaque connexion serait
--  payer deux fois. Ce qui dépend du personnage, c'est ce qu'on en choisit, et
--  ça vit ailleurs (`Modules/BisList.lua`, `CharData`).
--
--  ## Pourquoi le balayage repasse à chaque allumage
--
--  Il est gratuit, et il est la seule chose qui sache que le client a changé.
--  Une bêta ajoute et retire des objets : plutôt que d'estampiller l'index d'un
--  numéro de version — qu'on ne saurait lire sans brancher sur un numéro de
--  patch, ce que CLAUDE.md §1 interdit —, on compare la liste cachée à celle du
--  client. Ce qui est nouveau s'hydrate, ce qui a disparu s'oublie. L'index se
--  répare donc tout seul, sans rien savoir du client.
--
--  `FORMAT` est l'autre moitié : il décrit la **disposition** d'un
--  enregistrement. Le changer jette tout et recommence, parce qu'une chaîne
--  relue avec la mauvaise disposition est pire qu'absente.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local U    = BUI.Util
local L    = ns.L

local Index = {}
ns.BisIndex = Index

--- Disposition d'un enregistrement. Incrémenter = reconstruire tout l'index.
local FORMAT = 1

--- Borne haute du balayage. Large exprès : les objets de *Forever* ne sont pas
--- forcément dans la plage de vanilla, et un identifiant inexistant ne coûte
--- qu'un appel qui ne rend rien.
local MAX_ITEM_ID = 250000

--- Identifiants testés par battement (passe locale) et objets demandés au
--- serveur par battement (passe réseau). Le second est petit : une salve de
--- requêtes d'objets fait décrocher le client.
local SWEEP_CHUNK = 2000
local LOAD_BATCH  = 25

--- Nombre de demandes avant d'abandonner un objet qui ne répond pas.
local MAX_ATTEMPTS = 3

-- =========================================================================
--  Ce qu'on indexe
-- =========================================================================

--- Emplacements retenus, dans l'ordre : un enregistrement porte l'**index** de
--- son emplacement dans cette liste, pas la chaîne. Ajouter une entrée se fait
--- donc à la fin, jamais au milieu.
---
--- Chemise, tabard et sacs n'y sont pas : ils s'équipent, mais personne n'en
--- cherche le meilleur.
local EQUIP_LOCS = {
    "INVTYPE_HEAD", "INVTYPE_NECK", "INVTYPE_SHOULDER", "INVTYPE_CLOAK",
    "INVTYPE_CHEST", "INVTYPE_ROBE", "INVTYPE_WRIST", "INVTYPE_HAND",
    "INVTYPE_WAIST", "INVTYPE_LEGS", "INVTYPE_FEET", "INVTYPE_FINGER",
    "INVTYPE_TRINKET", "INVTYPE_WEAPON", "INVTYPE_2HWEAPON",
    "INVTYPE_WEAPONMAINHAND", "INVTYPE_WEAPONOFFHAND", "INVTYPE_SHIELD",
    "INVTYPE_HOLDABLE", "INVTYPE_RANGED", "INVTYPE_RANGEDRIGHT",
    "INVTYPE_THROWN", "INVTYPE_RELIC",
}

--- Emplacement -> son index. Table de travail du balayage : c'est elle qui dit
--- en un test si un objet nous intéresse.
local LOC_INDEX = {}
for i = 1, #EQUIP_LOCS do LOC_INDEX[EQUIP_LOCS[i]] = i end

--- Les lignes de la liste BIS, dans l'ordre où elles s'affichent. `locs` dit
--- quels emplacements tombent dans cette ligne — une arme à une main va dans
--- les deux mains, un anneau occupe deux lignes pour un seul emplacement.
---
--- Les intitulés sont les nôtres (`L[…]`) et non ceux du client : deux lignes
--- sur dix-sept portent un numéro, que le client ne publie pas.
local SLOTS = {
    { key = "HEAD",     label = "Head",      locs = { "INVTYPE_HEAD" } },
    { key = "NECK",     label = "Neck",      locs = { "INVTYPE_NECK" } },
    { key = "SHOULDER", label = "Shoulder",  locs = { "INVTYPE_SHOULDER" } },
    { key = "BACK",     label = "Back",      locs = { "INVTYPE_CLOAK" } },
    { key = "CHEST",    label = "Chest",     locs = { "INVTYPE_CHEST", "INVTYPE_ROBE" } },
    { key = "WRIST",    label = "Wrist",     locs = { "INVTYPE_WRIST" } },
    { key = "HANDS",    label = "Hands",     locs = { "INVTYPE_HAND" } },
    { key = "WAIST",    label = "Waist",     locs = { "INVTYPE_WAIST" } },
    { key = "LEGS",     label = "Legs",      locs = { "INVTYPE_LEGS" } },
    { key = "FEET",     label = "Feet",      locs = { "INVTYPE_FEET" } },
    { key = "FINGER1",  label = "Ring 1",    locs = { "INVTYPE_FINGER" } },
    { key = "FINGER2",  label = "Ring 2",    locs = { "INVTYPE_FINGER" } },
    { key = "TRINKET1", label = "Trinket 1", locs = { "INVTYPE_TRINKET" } },
    { key = "TRINKET2", label = "Trinket 2", locs = { "INVTYPE_TRINKET" } },
    { key = "MAINHAND", label = "Main hand",
      locs = { "INVTYPE_WEAPON", "INVTYPE_WEAPONMAINHAND", "INVTYPE_2HWEAPON" } },
    { key = "OFFHAND",  label = "Off hand",
      locs = { "INVTYPE_WEAPON", "INVTYPE_WEAPONOFFHAND", "INVTYPE_SHIELD", "INVTYPE_HOLDABLE" } },
    { key = "RANGED",   label = "Ranged",
      locs = { "INVTYPE_RANGED", "INVTYPE_RANGEDRIGHT", "INVTYPE_THROWN", "INVTYPE_RELIC" } },
}

--- Les stats qu'on sait filtrer, dans l'ordre de la colonne de filtres.
---
--- La clé est celle que rend `GetItemStats`, et c'est **aussi** le nom d'une
--- chaîne globale du client : `_G["ITEM_MOD_STRENGTH_SHORT"]` vaut « Force »
--- dans la langue du joueur. On la lit donc plutôt que de la traduire, et
--- `label` n'est qu'un repli pour le jour où le client ne la publierait plus —
--- un filtre sans intitulé ne se coche pas.
---
--- L'ordre compte comme celui des emplacements : un enregistrement porte des
--- index. Ajouter une stat ailleurs qu'à la fin exige de changer `FORMAT`.
---
--- Ce que cette liste ne verra jamais : les effets « à l'équipement » de
--- vanilla (« augmente votre chance de toucher de 1 % »). Ce sont des sorts
--- attachés à l'objet, pas des stats, et `GetItemStats` n'en sait rien.
local STATS = {
    { key = "ITEM_MOD_STRENGTH_SHORT",             label = "Strength" },
    { key = "ITEM_MOD_AGILITY_SHORT",              label = "Agility" },
    { key = "ITEM_MOD_STAMINA_SHORT",              label = "Stamina" },
    { key = "ITEM_MOD_INTELLECT_SHORT",            label = "Intellect" },
    { key = "ITEM_MOD_SPIRIT_SHORT",               label = "Spirit" },
    { key = "RESISTANCE0_NAME",                    label = "Armor" },
    { key = "ITEM_MOD_ATTACK_POWER_SHORT",         label = "Attack power" },
    { key = "ITEM_MOD_RANGED_ATTACK_POWER_SHORT",  label = "Ranged attack power" },
    { key = "ITEM_MOD_SPELL_POWER_SHORT",          label = "Spell power" },
    { key = "ITEM_MOD_SPELL_PENETRATION_SHORT",    label = "Spell penetration" },
    { key = "ITEM_MOD_CRIT_RATING_SHORT",          label = "Critical strike" },
    { key = "ITEM_MOD_HIT_RATING_SHORT",           label = "Hit" },
    { key = "ITEM_MOD_HASTE_RATING_SHORT",         label = "Haste" },
    { key = "ITEM_MOD_MANA_REGENERATION_SHORT",    label = "Mana per 5 sec" },
    { key = "ITEM_MOD_HEALTH_REGENERATION_SHORT",  label = "Health per 5 sec" },
    { key = "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT", label = "Defense" },
    { key = "ITEM_MOD_DODGE_RATING_SHORT",         label = "Dodge" },
    { key = "ITEM_MOD_PARRY_RATING_SHORT",         label = "Parry" },
    { key = "ITEM_MOD_BLOCK_RATING_SHORT",         label = "Block" },
    { key = "ITEM_MOD_BLOCK_VALUE_SHORT",          label = "Block value" },
    { key = "RESISTANCE1_NAME",                    label = "Holy resistance" },
    { key = "RESISTANCE2_NAME",                    label = "Fire resistance" },
    { key = "RESISTANCE3_NAME",                    label = "Nature resistance" },
    { key = "RESISTANCE4_NAME",                    label = "Frost resistance" },
    { key = "RESISTANCE5_NAME",                    label = "Shadow resistance" },
    { key = "RESISTANCE6_NAME",                    label = "Arcane resistance" },
}

--- Sorts de maîtrise d'armure et d'arme. Le client dit si le personnage les
--- connaît (`IsPlayerSpell`), ce qui est un test de capacité et non une table
--- de ce que chaque classe porte — une telle table serait fausse le jour où
--- *Forever* change une classe, et elle n'a pas à exister.
---
--- Un sort que le client ne connaît pas ne filtre rien : on n'exclut jamais
--- sur une donnée absente.
local PROFICIENCY_ARMOR = {
    [1] = 9078,   -- Tissu
    [2] = 9077,   -- Cuir
    [3] = 8737,   -- Mailles
    [4] = 750,    -- Plaques
    [6] = 9116,   -- Boucliers
}

local PROFICIENCY_WEAPON = {
    [0]  = 196,   -- Haches à une main
    [1]  = 197,   -- Haches à deux mains
    [2]  = 264,   -- Arcs
    [3]  = 266,   -- Armes à feu
    [4]  = 198,   -- Masses à une main
    [5]  = 199,   -- Masses à deux mains
    [6]  = 200,   -- Armes d'hast
    [7]  = 201,   -- Épées à une main
    [8]  = 202,   -- Épées à deux mains
    [10] = 227,   -- Bâtons
    [13] = 15590, -- Armes de pugilat
    [15] = 1180,  -- Dagues
    [16] = 2567,  -- Armes de jet
    [18] = 5011,  -- Arbalètes
    [19] = 5009,  -- Baguettes
}

---@return number
local function armorClassID()
    return (Enum and Enum.ItemClass and Enum.ItemClass.Armor) or 4
end

---@return number
local function weaponClassID()
    return (Enum and Enum.ItemClass and Enum.ItemClass.Weapon) or 2
end

-- =========================================================================
--  État
-- =========================================================================

--- La table sauvegardée : `itemID -> chaîne encodée`. Nil tant que la base n'a
--- pas été ouverte.
local store

--- Les mêmes, décodés, en mémoire vive : `itemID -> enregistrement`. Bâti une
--- fois par session, à la première recherche.
local records

--- Avancement. `phase` vaut "idle", "sweep", "load" ou "ready".
local phase    = "idle"
local cursor   = 1
local pending  = {}   -- entrées qui attendent leur fiche
local waiting  = {}   -- identifiants demandés au serveur, en vol
local attempts = {}   -- identifiant -> nombre de demandes déjà faites
local seen            -- ensemble du balayage en cours
local counted  = 0    -- objets retenus par le balayage
local hydrated = 0    -- fiches écrites pendant cette passe
local ticker

-- =========================================================================
--  Encodage
-- =========================================================================
-- Un objet tient dans une chaîne, et non dans une table : la sauvegarde est du
-- texte Lua, et dix mille tables de neuf champs y pèsent plusieurs fois ce que
-- pèsent dix mille lignes. Le décodage, lui, ne se paie qu'une fois par
-- session.
--
--     nom|emplacement|classe|sous-classe|qualité|ilvl|niveau|stats
--
-- `stats` est une liste `index=valeur` séparée par des virgules, vide quand
-- l'objet n'en porte aucune.

--- Lit les stats d'un objet sous la forme d'une liste `index=valeur`.
---@param itemID integer
---@return string
local function encodeStats(itemID)
    local read = (C_Item and C_Item.GetItemStats) or GetItemStats
    if not read then return "" end

    local ok, stats = pcall(read, "item:" .. itemID)
    if not ok or type(stats) ~= "table" then return "" end

    local parts
    for i = 1, #STATS do
        local value = stats[STATS[i].key]
        if type(value) == "number" and value ~= 0 then
            parts = parts or {}
            parts[#parts + 1] = i .. "=" .. value
        end
    end

    return parts and table.concat(parts, ",") or ""
end

--- Reconstitue un enregistrement depuis sa chaîne.
---@param itemID integer
---@param text string
---@return table|nil
local function decode(itemID, text)
    local name, rest = text:match("^(.-)|(.*)$")
    if not rest then return nil end

    local loc, classID, subClassID, quality, itemLevel, minLevel, stats =
        strsplit("|", rest)

    local record = {
        id         = itemID,
        name       = name,
        lower      = strlower(name),
        loc        = tonumber(loc) or 0,
        classID    = tonumber(classID) or 0,
        subClassID = tonumber(subClassID) or 0,
        quality    = tonumber(quality) or 0,
        itemLevel  = tonumber(itemLevel) or 0,
        minLevel   = tonumber(minLevel) or 0,
    }

    if stats and stats ~= "" then
        record.stats = {}
        for key, value in stats:gmatch("(%d+)=(%-?%d+)") do
            record.stats[tonumber(key)] = tonumber(value)
        end
    end

    return record
end

--- Écrit l'enregistrement d'un objet, ou rend `false` si le client ne sait pas
--- encore répondre.
---@param entry table  { id, loc, classID, subClassID }
---@return boolean
local function write(entry)
    local info = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not info then return false end

    local name, _, quality, itemLevel, minLevel = info(entry.id)
    if type(name) ~= "string" or name == "" then return false end
    if U.IsSecret(name) then return false end

    -- La barre verticale sépare les champs : un nom qui en porterait une
    -- couperait l'enregistrement en deux. Aucun nom d'objet n'en porte, et
    -- c'est précisément pour ça qu'on la retire sans scrupule.
    name = name:gsub("|", "")

    local text = table.concat({
        name,
        entry.loc,
        entry.classID or 0,
        entry.subClassID or 0,
        quality or 0,
        itemLevel or 0,
        minLevel or 0,
        encodeStats(entry.id),
    }, "|")

    store[entry.id] = text
    hydrated = hydrated + 1

    -- Si l'index est déjà déplié en mémoire, le nouvel objet y entre tout de
    -- suite. Sans ça, une recherche faite **pendant** l'indexation figerait
    -- l'état du moment : ce qui arrive après ne se verrait qu'au prochain
    -- `/reload`, et la fenêtre dirait « aucun objet » devant un index qui se
    -- remplit sous ses yeux.
    if records then records[entry.id] = decode(entry.id, text) end

    return true
end

-- =========================================================================
--  La base
-- =========================================================================

--- Ouvre (et nettoie) la table sauvegardée.
---@return table
local function openStore()
    if store then return store end

    local data = BUI.DB:AccountData("BisIndex")
    if data.format ~= FORMAT then
        -- Disposition changée : ce qui est en base ne se relit pas, et une
        -- chaîne mal relue vaut moins que pas de chaîne.
        data.format = FORMAT
        data.items  = {}
    end
    data.items = data.items or {}

    store = data.items
    return store
end

--- Décode tout l'index, une fois par session.
---@return table
local function ensureRecords()
    if records then return records end

    records = {}
    for itemID, text in pairs(openStore()) do
        local record = decode(itemID, text)
        if record then records[itemID] = record end
    end
    return records
end

-- =========================================================================
--  Les deux passes
-- =========================================================================

local function stopTicker()
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
end

local function finish()
    phase    = "ready"
    attempts = {}
    stopTicker()

    -- Le nombre de fiches écrites part avec le message : c'est lui qui dit si
    -- cette passe a travaillé. Un allumage où rien n'a changé — le cas de tous
    -- les jours — n'a rien à annoncer, et c'est à l'écouteur d'en décider.
    BUI:SendMessage("BIS_INDEX_READY", hydrated)
end

--- Dit où en est l'indexation, au plus une fois par `BIS_ANNOUNCE`.
---
--- Étranglé parce que le battement est dix fois plus rapide que ce qu'un œil
--- lit : un nombre qui change deux fois par seconde se lit comme un travail en
--- cours, dix fois par seconde comme un scintillement.
local announce = U.Throttle(T.TIMING.BIS_ANNOUNCE, function()
    BUI:SendMessage("BIS_INDEX_PROGRESS")
end)

--- Hydrate ce qui attend, un paquet par battement.
local function loadTick()
    local taken = 0

    while taken < LOAD_BATCH and #pending > 0 do
        local entry = table.remove(pending)
        taken = taken + 1

        if not waiting[entry.id] and not write(entry) then
            local tries = (attempts[entry.id] or 0) + 1
            attempts[entry.id] = tries

            if tries <= MAX_ATTEMPTS then
                -- La fiche n'est pas là : on la demande et on garde l'entrée de
                -- côté. `GET_ITEM_INFO_RECEIVED` la remettra dans la file.
                waiting[entry.id] = entry
                if C_Item and C_Item.RequestLoadItemDataByID then
                    C_Item.RequestLoadItemDataByID(entry.id)
                end
            end
        end
    end

    if #pending == 0 and not next(waiting) then finish() end
end

--- Balaie la table d'objets du client, un morceau par battement. Gratuit :
--- `GetItemInfoInstant` ne demande rien au serveur.
local function sweepTick()
    local instant = C_Item and C_Item.GetItemInfoInstant
    if not instant then
        finish()
        return
    end

    local last = math.min(cursor + SWEEP_CHUNK - 1, MAX_ITEM_ID)

    for itemID = cursor, last do
        local _, _, _, equipLoc, _, classID, subClassID = instant(itemID)
        local locIndex = equipLoc and LOC_INDEX[equipLoc]

        if locIndex then
            counted = counted + 1
            seen[itemID] = true

            if not store[itemID] then
                pending[#pending + 1] = {
                    id         = itemID,
                    loc        = locIndex,
                    classID    = classID,
                    subClassID = subClassID,
                }
            end
        end
    end

    cursor = last + 1
    if cursor <= MAX_ITEM_ID then return end

    -- Ce que le client ne connaît plus ne doit pas rester en base : un objet
    -- retiré par une mise à jour de bêta ne se cherche plus.
    for itemID in pairs(store) do
        if not seen[itemID] then store[itemID] = nil end
    end
    seen    = nil
    records = nil

    if #pending > 0 then
        phase = "load"
    else
        finish()
    end
end

local function tick()
    if phase == "sweep" then
        sweepTick()
    elseif phase == "load" then
        loadTick()
    else
        stopTicker()
        return
    end

    -- Après le travail, et pas avant : le message doit porter l'état d'après
    -- le battement, sans quoi l'avancement affiché aurait toujours un tour de
    -- retard. `finish` a déjà envoyé le sien si la phase vient de se terminer.
    if phase ~= "ready" then announce() end
end

--- Remet le battement en marche si une phase est en cours sans lui.
---
--- Deux appelants : le démarrage, et la fiche qui arrive **après** la fin de
--- l'indexation — elle rouvre la phase d'hydratation, et sans ce rattrapage
--- elle resterait dans une file que plus rien ne vide.
---
--- Sans minuteur dans le client, l'indexation ne peut pas avoir lieu : on se
--- déclare prêt avec ce qu'on a plutôt que de laisser une phase en suspens.
local function resume()
    if ticker then return end
    if phase ~= "sweep" and phase ~= "load" then return end

    if not (C_Timer and C_Timer.NewTicker) then
        phase = "ready"
        return
    end

    ticker = C_Timer.NewTicker(T.TIMING.BIS_TICK, tick)
end

--- Démarre l'indexation si elle n'est pas déjà en cours.
function Index:Start()
    if phase == "sweep" or phase == "load" then return end

    openStore()

    phase    = "sweep"
    cursor   = 1
    counted  = 0
    hydrated = 0
    seen     = {}
    pending  = {}
    waiting  = {}
    attempts = {}

    stopTicker()
    resume()
end

--- Jette l'index et recommence. Le geste du joueur quand il soupçonne l'index
--- d'avoir vieilli — il ne devrait jamais être nécessaire, le balayage répare
--- de lui-même, et il est là parce que « reconstruire » est la seule réponse
--- qu'on puisse donner à qui ne fait plus confiance au contenu.
function Index:Rebuild()
    stopTicker()
    phase = "idle"

    local data = BUI.DB:AccountData("BisIndex")
    data.format = FORMAT
    data.items  = {}
    store   = data.items
    records = nil

    self:Start()
end

--- Arrête tout : un module éteint ne fait rien tourner (règle 6).
function Index:Stop()
    stopTicker()
    if phase == "sweep" or phase == "load" then phase = "idle" end
end

--- Une fiche vient d'arriver. Appelée par le module, qui seul s'abonne aux
--- événements (règle 6).
---@param itemID integer
---@param success any
function Index:OnItemInfoReceived(itemID, success)
    local entry = waiting[itemID]
    if not entry then return end

    waiting[itemID] = nil

    if U.IsTrue(success) then
        -- Remis dans la file plutôt qu'écrit ici : l'écriture appartient au
        -- battement, qui est le seul endroit étranglé.
        pending[#pending + 1] = entry
        if phase == "ready" then phase = "load" end
        resume()
        return
    end

    if phase == "load" and #pending == 0 and not next(waiting) then finish() end
end

-- =========================================================================
--  Ce que l'interface demande
-- =========================================================================

--- Avancement : la phase, ce qui est fait, ce qu'il y a à faire.
---@return string phase, number done, number total
function Index:Progress()
    if phase == "sweep" then
        return phase, cursor - 1, MAX_ITEM_ID
    end
    if phase == "load" then
        return phase, counted - #pending, counted
    end
    return phase, counted, counted
end

-- -------------------------------------------------------------------------
--  Ce que la sonde demande
-- -------------------------------------------------------------------------
-- Quatre lectures qui ne servent qu'à `/bui bis`. Elles vivent ici et non dans
-- le module parce qu'elles regardent l'intérieur de l'index — et un diagnostic
-- qui n'a pas accès à l'intérieur ne diagnostique rien.

--- Combien d'objets sont en base, et combien de fiches cette passe a écrites.
---@return integer stored, integer written
function Index:Counts()
    local stored = 0
    for _ in pairs(openStore()) do stored = stored + 1 end
    return stored, hydrated
end

--- Ce que le client sait d'une plage d'identifiants **sans rien demander au
--- serveur**. C'est la mesure qui décide de tout : zéro objet connu ici, et le
--- principe même de l'index est faux sur ce client — il faudrait alors le
--- nourrir autrement qu'en balayant.
---@param from integer
---@param to integer
---@return integer known, integer equippable
function Index:Probe(from, to)
    local instant = C_Item and C_Item.GetItemInfoInstant
    if not instant then return 0, 0 end

    local known, equippable = 0, 0
    for itemID = from, to do
        local _, _, _, equipLoc = instant(itemID)
        if equipLoc then
            known = known + 1
            if LOC_INDEX[equipLoc] then equippable = equippable + 1 end
        end
    end

    return known, equippable
end

--- L'emplacement que le client écrit pour cet objet, et ce que l'index en a
--- fait. Les deux côte à côte : un jeton qu'on ne reconnaît pas est la seule
--- chose qui puisse remplir le balayage sans rien mettre en base.
---@param itemID integer
---@return string|nil equipLoc, boolean indexed
function Index:Trace(itemID)
    local instant = C_Item and C_Item.GetItemInfoInstant
    local equipLoc = instant and select(4, instant(itemID)) or nil
    return equipLoc, openStore()[itemID] ~= nil
end

---@return integer
function Index:Bound()
    return MAX_ITEM_ID
end

---@return table[]  { key, label, locs }
function Index:Slots()
    return SLOTS
end

--- Les emplacements d'une ligne, en index.
---@param slotKey string
---@return table|nil  ensemble d'index d'emplacements
function Index:SlotLocs(slotKey)
    for i = 1, #SLOTS do
        if SLOTS[i].key == slotKey then
            local set = {}
            for j = 1, #SLOTS[i].locs do
                set[LOC_INDEX[SLOTS[i].locs[j]]] = true
            end
            return set
        end
    end
    return nil
end

--- Les stats filtrables, intitulé résolu : la chaîne du client si elle existe,
--- la nôtre sinon.
---@return table[]  { index, label }
function Index:Stats()
    local out = {}
    for i = 1, #STATS do
        local label = _G[STATS[i].key]
        if type(label) ~= "string" or label == "" then label = L[STATS[i].label] end
        out[i] = { index = i, label = label }
    end
    return out
end

--- Les types d'armure, intitulés par le client : c'est lui qui sait dire
--- « Mailles » dans la langue du joueur.
---@return table[]  { value, label }
function Index:ArmorTypes()
    local armor = armorClassID()
    local out   = { { value = false, label = L["Any armor type"] } }

    local subClasses = { 1, 2, 3, 4, 6 }
    for i = 1, #subClasses do
        local label
        if C_Item and C_Item.GetItemSubClassInfo then
            label = C_Item.GetItemSubClassInfo(armor, subClasses[i])
        end
        if type(label) == "string" and label ~= "" then
            out[#out + 1] = { value = subClasses[i], label = label }
        end
    end

    return out
end

---@param itemID integer
---@return table|nil
function Index:Record(itemID)
    return ensureRecords()[itemID]
end

-- =========================================================================
--  « Équipable par ce personnage »
-- =========================================================================

--- Maîtrises du personnage : classe d'objet -> sous-classe -> vrai/faux.
--- Relevées une fois par session, à la première recherche qui les demande.
local proficient

---@param spells table
---@return table
local function readSkills(spells)
    local map   = {}
    local known = IsPlayerSpell

    for subClassID, spellID in pairs(spells) do
        -- Sort inconnu du client : on ne conclut rien, donc on autorise.
        local exists = C_Spell and C_Spell.GetSpellName
                       and C_Spell.GetSpellName(spellID)
        if not known or type(exists) ~= "string" then
            map[subClassID] = true
        else
            map[subClassID] = U.IsTrue(known(spellID))
        end
    end

    return map
end

---@return table
local function readProficiency()
    if proficient then return proficient end

    proficient = {
        [armorClassID()]  = readSkills(PROFICIENCY_ARMOR),
        [weaponClassID()] = readSkills(PROFICIENCY_WEAPON),
    }
    return proficient
end

--- Le motif qui reconnaît la ligne « Classes : … » d'une infobulle, bâti sur
--- la chaîne du client pour rester vrai dans toutes les langues.
local classesPattern

--- Échappe ce qui, dans un motif Lua, voudrait dire autre chose que lui-même.
--- Le `%` en fait partie, et il est le piège : la chaîne du client en contient
--- un (`%s`), et l'oublier donne un motif qui cherche une **espace** là où on
--- croyait avoir mis une capture.
---@param text string
---@return string
local function escapePattern(text)
    return (text:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))
end

---@return string|false
local function readClassesPattern()
    if classesPattern ~= nil then return classesPattern end

    local text = ITEM_CLASSES_ALLOWED
    if type(text) ~= "string" then
        classesPattern = false
        return classesPattern
    end

    -- Deux valeurs de retour, donc pas de `and` : il n'en garderait que la
    -- première, et le suffixe arriverait nil à l'échappement.
    local prefix, suffix = text:match("^(.-)%%s(.*)$")
    if not prefix then
        classesPattern = false
        return classesPattern
    end

    -- La chaîne est coupée **autour** du `%s` avant d'échapper : on ne cherche
    -- donc jamais à reconnaître un `%s` déjà échappé, ce qui était l'erreur.
    classesPattern = "^" .. escapePattern(prefix) .. "(.+)" .. escapePattern(suffix) .. "$"
    return classesPattern
end

--- Noms de la classe du joueur, les deux genres : la ligne d'infobulle porte
--- l'un ou l'autre selon le client.
local myClassNames

---@return table
local function readClassNames()
    if myClassNames then return myClassNames end
    myClassNames = {}

    local class = UnitClassBase and UnitClassBase("player")
    if type(class) ~= "string" then return myClassNames end

    local sources = { LOCALIZED_CLASS_NAMES_MALE, LOCALIZED_CLASS_NAMES_FEMALE }
    for i = 1, #sources do
        local names = sources[i]
        if type(names) == "table" and type(names[class]) == "string" then
            myClassNames[names[class]] = true
        end
    end

    return myClassNames
end

--- Restriction de classe, lue dans l'infobulle. Mémorisée : la question se
--- repose à chaque recherche sur les mêmes objets.
local classAllowed = {}

---@param itemID integer
---@return boolean
local function classPermits(itemID)
    local cached = classAllowed[itemID]
    if cached ~= nil then return cached end

    -- Sans motif — le client ne publie pas la ligne « Classes : … » — on
    -- n'exclut rien : la retenue de partout ailleurs, et la sortie tôt garde
    -- `pattern` sûrement une chaîne pour la suite.
    local pattern = readClassesPattern()
    if not pattern then
        classAllowed[itemID] = true
        return true
    end

    local data
    if C_TooltipInfo and C_TooltipInfo.GetItemByID then
        data = C_TooltipInfo.GetItemByID(itemID)
    end

    local allowed = true

    if data and type(data.lines) == "table" then
        local mine = readClassNames()

        for i = 1, #data.lines do
            local line = data.lines[i]
            if TooltipUtil and TooltipUtil.SurfaceArgs then
                TooltipUtil.SurfaceArgs(line)
            end

            local text = line.leftText
            if type(text) == "string" and not U.IsSecret(text) then
                local list = text:match(pattern)
                if list then
                    allowed = false
                    for name in list:gmatch("[^,]+") do
                        if mine[strtrim(name)] then allowed = true end
                    end
                    break
                end
            end
        end
    end

    classAllowed[itemID] = allowed
    return allowed
end

--- Ce personnage peut-il porter cet objet ? La maîtrise d'abord — c'est le
--- test qui ne coûte rien —, la restriction de classe ensuite.
---@param record table
---@return boolean
function Index:CanEquip(record)
    local byClass = readProficiency()[record.classID]
    if byClass and byClass[record.subClassID] == false then return false end

    return classPermits(record.id)
end

-- =========================================================================
--  La recherche
-- =========================================================================

--- Tri : le plus haut niveau d'objet d'abord, puis l'ordre alphabétique — à
--- niveau égal, une liste qui change d'ordre d'une recherche à l'autre se lit
--- comme une liste cassée.
local function byItemLevel(a, b)
    if a.itemLevel ~= b.itemLevel then return a.itemLevel > b.itemLevel end
    if a.name ~= b.name then return a.name < b.name end
    return a.id < b.id
end

--- Tout ce qui se décide sans lire d'infobulle.
---@param record table
---@param filters table
---@return boolean
local function matches(record, filters)
    if filters.locs and not filters.locs[record.loc] then return false end
    if filters.maxLevel and record.minLevel > filters.maxLevel then return false end
    if filters.minItemLevel and record.itemLevel < filters.minItemLevel then return false end
    if filters.maxItemLevel and record.itemLevel > filters.maxItemLevel then return false end

    if filters.armorType then
        if record.classID ~= armorClassID()
           or record.subClassID ~= filters.armorType then
            return false
        end
    end

    if filters.stats then
        local stats = record.stats
        if not stats then return false end
        for i = 1, #filters.stats do
            if not stats[filters.stats[i]] then return false end
        end
    end

    if filters.text and not record.lower:find(filters.text, 1, true) then
        return false
    end

    return true
end

--- Table de travail du filtrage, réutilisée d'une recherche à l'autre.
local sieve = {}

--- Cherche, trie, et rend au plus `limit` objets.
---
--- « Équipable » s'applique **après** le tri et non pendant : il lit une
--- infobulle, donc il coûte, et on ne le paie que sur ce qui va s'afficher. Le
--- tri portant sur tout le reste, la liste obtenue est bien celle des
--- meilleurs — jamais une tranche arbitraire.
---@param filters table
---@param limit integer
---@param out table  rempli sur place
---@return table out, integer total
function Index:Search(filters, limit, out)
    ensureRecords()
    wipe(sieve)
    wipe(out)

    for _, record in pairs(records) do
        if matches(record, filters) then
            sieve[#sieve + 1] = record
        end
    end

    table.sort(sieve, byItemLevel)

    local total = 0
    for i = 1, #sieve do
        local record = sieve[i]
        if not filters.equippable or self:CanEquip(record) then
            total = total + 1
            if #out < limit then out[#out + 1] = record end
        end
    end

    return out, total
end
