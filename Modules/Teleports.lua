-- =========================================================================
--  Bshamel UI — Modules/Teleports.lua
--  Un menu qui rassemble tout ce qui déplace le personnage.
--
--  Le menu tient en deux sections : les **pierres de foyer** — celle qu'on a
--  choisie, plus celles qui ont leur propre temps de recharge —, et les
--  **donjons de la saison en cours**, dans un sous-menu qui s'ouvre au survol.
--  La rotation vient du client, pas d'une liste écrite ici : elle suit donc les
--  saisons sans qu'on y revienne.
--
--  Il s'ouvre par un bouton posé sur le pourtour de la minicarte, ou par une
--  macro que le module sait créer — c'est la raison pour laquelle le réglage vit
--  ici et non dans une page de minicarte : ce qu'on règle, c'est le menu, pas la
--  carte à côté de laquelle son bouton se pose.
--
--  Le module ne dessine rien : il dit *quoi* mettre dans le menu, et
--  `UI/Widgets/SecureMenu.lua` sait faire cliquer une action du jeu.
--
--  `secure = true` : le menu est fait de boutons d'action **sécurisés**, qui ne
--  se touchent pas en combat. Le core diffère donc l'allumage et l'extinction du
--  module à la sortie de combat.
--
--  Réversibilité : le bouton se cache et le menu se ferme.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local U    = BUI.Util
local W    = BUI.Widgets
local L    = ns.L

local MODULE = "Teleports"

-- =========================================================================
--  Ce que le menu propose
-- =========================================================================
-- Des identifiants, et rien d'autre : le nom et l'icône viennent du client, donc
-- dans la langue du joueur et avec l'illustration du patch courant.
--
-- Une entrée dont l'identifiant serait faux ne s'affiche pas — tout est filtré
-- par « le joueur l'a-t-il ? ». C'est ce qui rend ces listes sûres à étendre :
-- ajouter un identifiant ne peut pas casser le menu, au pire il ne sert à rien.
--
-- Ce sont des **listes de données**, pas du code : elles vieillissent avec le
-- jeu et c'est le seul endroit à toucher quand une extension ajoute sa pierre.

--- La pierre de foyer que tout le monde a. Sert de repli quand le réglage
--- désigne une pierre que ce personnage-ci ne possède pas.
local BASE_HEARTHSTONE = 6948

--- Pierres de foyer à **temps de recharge partagé**. Elles font toutes la même
--- chose — retourner au point de liaison — et ne diffèrent que par l'animation :
--- en lister trente reviendrait à écrire trente fois la même ligne. Le menu n'en
--- montre donc qu'une, celle que le joueur choisit ; cette liste est le
--- catalogue dans lequel il choisit, et rien d'autre.
local HEARTHSTONE_POOL = {
    BASE_HEARTHSTONE,
    64488, 28585, 54452, 93672, 142298, 142542, 168907,
    162973, 163045, 165669, 165670, 165802, 166746, 166747,
    172179, 180290, 182773, 183716, 184353, 188952, 190196, 190237,
    193588, 200630, 235016, 236687,
    208704, 209035, 210455, 212337, 228940, 245970, 246565, 257736,
    263489, 263933, 264367, 265100,
}

--- Pierres à **temps de recharge propre**. Chacune va ailleurs et se recharge
--- pour elle seule : elles sont donc toutes listées, dès lors qu'on les possède.
--- C'est ce qui les distingue de la liste précédente, pas leur nom.
local TRAVEL_STONES = {
    140192,  -- Pierre de foyer de Dalaran
    253629,  -- Clé de l'Arcantina
    110560,  -- Pierre de foyer du fief
}

--- Sorts de retour, listés quand la classe les connaît. Les **portails** et les
--- téléportations de ville du mage n'y sont pas : un portail est un service
--- rendu au groupe, il se lance là où le groupe se tient. Ce menu-ci sert à se
--- déplacer soi-même.
local TRAVEL_SPELLS = {
    556,     -- Rappel astral (chaman)
}

--- Le joueur possède-t-il cet objet, et sous quelle forme ? Jouet et objet de
--- sac ne se lancent pas par le même chemin, et le même identifiant a changé de
--- camp d'une extension à l'autre : on le redemande au client plutôt que de
--- l'écrire dans les listes.
---@param id number
---@return BUI.MenuEntry|nil
local function resolveItem(id)
    if PlayerHasToy and PlayerHasToy(id) and C_ToyBox and C_ToyBox.GetToyInfo then
        local _, name, icon = C_ToyBox.GetToyInfo(id)
        if name then
            return { kind = "toy", id = id, payload = id, name = name, icon = icon }
        end
    end

    local count = C_Item and C_Item.GetItemCount and C_Item.GetItemCount(id) or 0
    if count > 0 then
        local name = C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
        local icon = C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)
        if name then
            -- La charge est un lien d'objet, pas un nombre : passé tel quel, le
            -- nombre serait lu comme un emplacement d'inventaire.
            return { kind = "item", id = id, payload = "item:" .. id, name = name, icon = icon }
        end
    end

    return nil
end

--- Le personnage connaît-il ce sort ? Les deux questions du client ne couvrent
--- pas la même chose : l'une répond pour un sort appris, l'autre pour un sort
--- que le talent ou la spécialisation accorde.
---@param id? number
---@return boolean
local function knowsSpell(id)
    if not id then return false end
    if IsPlayerSpell and IsPlayerSpell(id) then return true end
    return (IsSpellKnown and IsSpellKnown(id)) == true
end

--- Nom et icône d'un sort, dans la langue du client.
---@param id number
---@return string|nil name, number|nil icon
local function spellLook(id)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(id)
        if info and info.name then return info.name, info.iconID end
    end
    if GetSpellInfo then
        local name, _, icon = GetSpellInfo(id)
        if name then return name, icon end
    end
    return nil, nil
end

---@param id number
---@return BUI.MenuEntry|nil
local function resolveSpell(id)
    if not knowsSpell(id) then return nil end

    local name, icon = spellLook(id)
    if not name then return nil end
    return { kind = "spell", id = id, payload = id, name = name, icon = icon }
end

-- =========================================================================
--  Saison en cours : de quoi savoir laquelle c'est
-- =========================================================================
-- On ne nomme **jamais** la saison. Le client publie la liste des donjons de la
-- rotation en cours (`C_ChallengeMode.GetMapTable`) et, sur les versions qui le
-- font, la téléportation de chacun. On s'en sert pour une seule chose : savoir
-- lequel des tiroirs du grimoire est celui de la saison, pour le poser en tête
-- de menu. Son **nom et son icône restent ceux du grimoire** — c'est le jeu qui
-- l'appelle « Midnight – Saison 1 », pas nous, et il l'appellera autrement à la
-- saison suivante sans qu'on ait à y revenir.
--
-- Rien ne dépend de cette liste : si le client ne publie pas les sorts, aucun
-- tiroir n'est reconnu comme celui de la saison et ils s'ordonnent simplement
-- par nom. Le contenu, lui, est le même dans les deux cas.

--- Deux signaux, et il suffit qu'un seul réponde. Le sort de téléportation
--- n'est publié que par les clients récents ; le **nom du donjon**, lui, l'est
--- toujours. Un tiroir dont les destinations portent les noms de la rotation est
--- celui de la saison, même quand aucun identifiant de sort n'a été publié.
local seasonSpells = {}
local seasonNames  = {}

local function seasonTeleports()
    wipe(seasonSpells)
    wipe(seasonNames)

    if not (C_ChallengeMode and C_ChallengeMode.GetMapTable and C_ChallengeMode.GetMapUIInfo) then
        return
    end

    local maps = C_ChallengeMode.GetMapTable()
    if type(maps) ~= "table" then return end

    for i = 1, #maps do
        -- Le septième retour est la téléportation du donjon. Il n'existe pas
        -- partout : sur un client qui ne le rend pas il vaut `nil`, et c'est le
        -- nom qui prend le relais — test de capacité, pas pari sur la version.
        local name, _, _, _, _, _, published = C_ChallengeMode.GetMapUIInfo(maps[i])
        if published then seasonSpells[published] = true end
        if type(name) == "string" then seasonNames[name:lower()] = true end
    end
end

--- Cette destination est-elle de la rotation en cours ?
---@param spellID number
---@param name string   nom affiché, déjà débarrassé du préfixe de famille
---@return boolean
local function isSeasonDungeon(spellID, name)
    return seasonSpells[spellID] == true or seasonNames[name:lower()] == true
end

-- =========================================================================
--  Le nom du donjon, et non celui de la voie qui y mène
-- =========================================================================
-- « Voie de Coursevent » est un nom de sort. Ce qu'on cherche dans une liste de
-- téléportations, c'est le **donjon** : c'est sous ce nom-là qu'on le connaît,
-- qu'on en parle en groupe et qu'il apparaît partout ailleurs dans le jeu.
--
-- Le client sait nommer ses donjons ; toute la difficulté est de relier le sort
-- au donjon. Deux chemins, du plus sûr au plus large :
--
--   1. la carte de mode défi publie parfois **son** sort de téléportation. Le
--      lien est alors donné, il n'y a rien à interpréter ;
--   2. sinon, la **description du sort** nomme le donjon (« Vous téléporte à
--      l'entrée de… »). On y cherche lequel des donjons connus est nommé —
--      débarrassé de son article de tête, que la phrase contracte (voir
--      `searchKey`). C'est du texte du client comparé à du texte du client :
--      aucune langue n'est écrite ici, et une description muette ne fait que
--      rendre la main.
--
-- Le nom du sort reste le dernier recours. Rien ne dépend donc de ce mécanisme :
-- au pire, la ligne s'appelle comme avant.

--- Jusqu'où chercher les cartes de mode défi. Une **borne**, pas une liste :
--- on ne sait pas quels numéros le jeu a distribués, seulement qu'ils sont
--- petits et qu'il en ajoute une poignée par extension. Ce qui vivrait au-delà
--- retombe sur le nom du sort, comme tout le reste.
local MAX_CHALLENGE_MAP = 1200

--- sort de téléportation -> nom du donjon, quand le client publie le lien.
local dungeonBySpell = {}

--- Articles par lesquels un nom de donjon peut commencer, en minuscules. Le
--- client nomme ses cartes avec leur article (« Le val Aveuglant ») mais ses
--- descriptions le contractent (« Vous téléporte aux abords **du** val
--- Aveuglant ») : le nom entier n'y figure alors jamais tel quel, et la
--- recherche échouait sur tous les donjons à article — la ligne gardait le nom
--- du sort. On cherche donc le nom **sans** lui, la part qui survit à la
--- contraction. Chaînes du client, rangées en locale comme les préfixes de
--- familles, avec le même contrat : une liste fausse ne coûte que des
--- rapprochements en moins.
local articles = {}
local articlesRead = false

---@return string[]
local function nameArticles()
    if articlesRead then return articles end
    articlesRead = true

    local declared = L["Dungeon name articles"]
    if type(declared) ~= "string" then return articles end

    for article in declared:gmatch("[^,]+") do
        article = strtrim(article):lower()
        if article ~= "" then articles[#articles + 1] = article end
    end
    return articles
end

--- Ce qui se cherche de ce nom dans une description : minuscules, sans
--- l'article de tête. Un article élidé (« L' ») colle au mot qu'il précède,
--- les autres s'en séparent par une espace.
---@param name string
---@return string
local function searchKey(name)
    local key = name:lower()
    local list = nameArticles()

    for i = 1, #list do
        local head = list[i]
        if head:sub(-1) ~= "'" then head = head .. " " end
        if key:sub(1, #head) == head then
            return key:sub(#head + 1)
        end
    end
    return key
end

--- Tous les donjons connus — `name` tel que le client l'affiche, `key` tel
--- qu'il se cherche —, de la clé la plus longue à la plus courte :
--- « tazavesh : le gambit de so'leah » doit l'emporter sur « tazavesh », que
--- la même description contient aussi.
local dungeonNames = {}

local mapsScanned = false

--- Relève une fois pour toutes les donjons que le client sait nommer.
local function scanChallengeMaps()
    if mapsScanned then return end
    if not (C_ChallengeMode and C_ChallengeMode.GetMapUIInfo) then return end
    mapsScanned = true

    for id = 1, MAX_CHALLENGE_MAP do
        -- Sous `pcall` : on interroge des numéros qui n'existent pas, et un
        -- refus ne doit coûter que l'appel qui a été refusé.
        local ok, name, _, _, _, _, _, spell = pcall(C_ChallengeMode.GetMapUIInfo, id)
        -- `U.IsSecret` avant la comparaison, jamais après : une chaîne secrète a
        -- le type `string`, et c'est `~= ""` qui lèverait.
        if ok and type(name) == "string" and not U.IsSecret(name) and name ~= "" then
            dungeonNames[#dungeonNames + 1] = { name = name, key = searchKey(name) }
            if type(spell) == "number" then dungeonBySpell[spell] = name end
        end
    end

    table.sort(dungeonNames, function(a, b) return #a.key > #b.key end)
end

--- sort -> nom du donjon, ou `false` quand la question a été posée sans réponse.
--- Retenu : le menu se reconstruit à chaque objet qui entre dans les sacs, et
--- une description ne change pas d'une reconstruction à l'autre (règle 7).
local resolvedDungeons = {}

---@param spellID number
---@return string|nil
local function dungeonName(spellID)
    local known = resolvedDungeons[spellID]
    if known ~= nil then return known or nil end

    scanChallengeMaps()

    local name = dungeonBySpell[spellID]
    if name then
        resolvedDungeons[spellID] = name
        return name
    end

    local ok, text = pcall(function()
        if C_Spell and C_Spell.GetSpellDescription then
            return C_Spell.GetSpellDescription(spellID)
        end
        return nil
    end)

    -- Une description vide n'est pas une absence de donjon : le client charge
    -- celle d'un sort à la demande. On la réclame et on rend la main **sans rien
    -- retenir**, pour que la prochaine reconstruction du menu retrouve la
    -- question posée.
    if not ok or type(text) ~= "string" or U.IsSecret(text) or text == "" then
        if C_Spell and C_Spell.RequestLoadSpellData then
            C_Spell.RequestLoadSpellData(spellID)
        end
        return nil
    end

    local lowered = text:lower()
    for i = 1, #dungeonNames do
        if lowered:find(dungeonNames[i].key, 1, true) then
            name = dungeonNames[i].name
            break
        end
    end

    resolvedDungeons[spellID] = name or false
    return name
end

-- =========================================================================
--  Les tiroirs du grimoire
-- =========================================================================
-- Une extension = un tiroir, et c'est le **grimoire** qui les tient à jour. On
-- ne tient donc aucune liste de donjons : ni pour la saison, ni pour les autres.
--
-- Le seul point de reconnaissance est le nom : ces sorts **commencent** tous par
-- le nom de leur famille (« Voie héroïque : … », « Voie temporelle : … »). C'est
-- donc une chaîne du **client** qu'on cherche, rangée en locale comme toute
-- chaîne dépendant de la langue — même motif que le marqueur de noyau du vide de
-- la fiche de personnage. Une locale dont le préfixe est faux ne casse rien : la
-- section est simplement vide.
--
-- Plusieurs préfixes par locale, séparés par des virgules : le français les
-- réunit sous « Voie », l'anglais nomme chaque famille autrement. Un préfixe
-- large ramasse un peu plus que les téléportations — une classe peut avoir un
-- sort qui commence pareil — et c'est le compromis voulu : mieux vaut une ligne
-- de trop qu'un donjon manquant.

local SPELLBOOK_PLAYER = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
local SPELLBOOK_SPELL  = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell

--- Ce qu'on affiche d'un nom de sort quand le donjon n'a pas pu être nommé
--- (voir `dungeonName`). La famille se nomme « préfixe : donjon » ; on garde ce
--- qui suit le deux-points, sinon le nom entier. C'est aussi ce qui nomme les
--- **tiroirs**, qui sont des extensions et n'ont pas de donjon à retrouver.
---@param name string
---@return string
local function dungeonPart(name)
    return name:match("^[^:]+:%s*(.+)$") or name
end

--- Rang d'une extension, d'après le nom que porte son tiroir.
---
--- Le client publie ses extensions **dans l'ordre**, sous `EXPANSION_NAME0`,
--- `EXPANSION_NAME1`… et il en ajoute une à chaque fois qu'il en sort une. Un
--- tiroir qui s'appelle « Dragonflight » vaut donc exactement le rang que le jeu
--- donne à Dragonflight, et la prochaine extension prendra sa place en tête sans
--- que rien ne soit touché ici.
---
--- C'est ce qui remplace le tri par identifiant de sort, qui paraissait mesurer
--- un âge et n'en mesurait pas un : les identifiants d'un tiroir grandissent
--- quand un de ses donjons **revient** en saison, si bien que Legion passait
--- devant Dragonflight parce que le Siège du Triumvirat a reçu une nouvelle
--- téléportation à Midnight.
---
--- La comparaison se fait dans les deux sens : le tiroir de la saison porte le
--- nom de l'extension **plus** un suffixe (« Midnight – Saison 1 »), et une
--- extension peut être écrite sans son article (« Burning Crusade » pour « The
--- Burning Crusade »). Le rang le plus élevé gagne.
--- Vaut -1 quand aucune extension ne correspond : ces tiroirs-là finissent en
--- bas, ce qui est la bonne place pour ce qu'on n'a pas su dater.
---@param name string
---@return integer rank
local function expansionRank(name)
    local lowered = name:lower()
    local last    = (GetNumExpansions and GetNumExpansions()) or 20
    local rank    = -1

    for i = 0, last do
        local label = _G["EXPANSION_NAME" .. i]
        if type(label) == "string" and label ~= "" then
            label = label:lower()
            if lowered:find(label, 1, true) or label:find(lowered, 1, true) then
                if i > rank then rank = i end
            end
        end
    end

    return rank
end

--- Préfixes à reconnaître, en minuscules. Relus à chaque reconstruction : la
--- locale ne change pas en cours de session, mais la table est de toute façon
--- réutilisée.
local prefixes = {}

---@return table[]
local function teleportPrefixes()
    wipe(prefixes)

    local declared = L["Teleport spell prefixes"]
    if type(declared) ~= "string" then return prefixes end

    for prefix in declared:gmatch("[^,]+") do
        prefix = strtrim(prefix):lower()
        if prefix ~= "" then prefixes[#prefixes + 1] = prefix end
    end
    return prefixes
end

--- Le nom commence-t-il par l'une des familles ?
---@param name string
---@return boolean
local function isTeleportName(name)
    local lowered = name:lower()
    for i = 1, #prefixes do
        if lowered:find(prefixes[i], 1, true) == 1 then return true end
    end
    return false
end

-- Une extension = **un tiroir du grimoire**, pas un sort. C'est ce qui manquait
-- au premier essai : « Voie héroïque : Dragonflight » n'est pas une
-- téléportation, c'est un `flyout` qui en contient une par donjon. Un parcours
-- qui ne retient que les sorts ne trouve donc rien, et la section reste vide
-- alors que le grimoire en est plein.

local SPELLBOOK_FLYOUT = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Flyout

--- Les deux fonctions de tiroir, du chemin récent au chemin ancien. Elles
--- rendent plusieurs valeurs sur un client, une table sur un autre : on accepte
--- les deux formes plutôt que de parier sur celle d'aujourd'hui.
---@param flyoutID number
---@return integer slots, boolean known
local function flyoutShape(flyoutID)
    local get = (C_SpellBook and C_SpellBook.GetFlyoutInfo) or GetFlyoutInfo
    if not get then return 0, false end

    local first, _, slots, known = get(flyoutID)
    if type(first) == "table" then
        return first.numSlots or 0, first.isKnown == true
    end
    return slots or 0, known == true
end

--- Sort d'un emplacement de tiroir, ou `nil` s'il n'est pas connu.
---@param flyoutID number
---@param slot integer
---@return number|nil
local function flyoutSpell(flyoutID, slot)
    local get = (C_SpellBook and C_SpellBook.GetFlyoutSlotInfo) or GetFlyoutSlotInfo
    if not get then return nil end

    local first, override, known = get(flyoutID, slot)
    if type(first) == "table" then
        if not first.isKnown then return nil end
        return first.overrideSpellID or first.spellID
    end

    if not known then return nil end
    return override or first
end

--- Téléportations d'un tiroir, dans l'ordre du grimoire.
--- Une table neuve par tiroir : ils sont tous affichés en même temps, il n'y a
--- donc rien à réutiliser.
---@param flyoutID number
---@return BUI.MenuEntry[], integer seasonMatches, integer newestSpell
local function flyoutDungeons(flyoutID)
    local out = {}
    local slots, known = flyoutShape(flyoutID)
    if not known then return out, 0, 0 end

    -- On **compte** les destinations de la rotation au lieu d'exiger qu'elles y
    -- soient toutes : le tiroir de la saison les a toutes, celui de l'extension
    -- courante en a une partie, les autres n'en ont aucune. Un compte départage
    -- les trois cas, là où un « toutes ou rien » ne dit rien dès qu'un seul
    -- donjon manque à l'appel.
    local matches = 0

    -- Le plus grand identifiant de sort du tiroir. Les identifiants sont
    -- attribués dans l'ordre où le jeu les crée : le plus grand désigne donc la
    -- téléportation la plus récemment ajoutée, et de proche en proche l'extension
    -- la plus récente. C'est un âge, obtenu sans rien demander à personne.
    local newest = 0

    for slot = 1, slots do
        local id = flyoutSpell(flyoutID, slot)
        if id then
            local name, icon = spellLook(id)
            if name then
                -- Le donjon d'abord, le sort ensuite : « Voie de Coursevent »
                -- est le nom du chemin, pas celui de l'endroit où il mène.
                local label = dungeonName(id) or dungeonPart(name)
                out[#out + 1] = {
                    kind = "spell", id = id, payload = id,
                    name = label, icon = icon,
                }
                if isSeasonDungeon(id, label) then matches = matches + 1 end
                if id > newest then newest = id end
            end
        end
    end

    return out, matches, newest
end

--- Un tiroir par extension, plus la desserte des téléportations isolées.
local expansions = {}
local loose      = {}

---@return table[] packs, BUI.MenuEntry[] loose
local function expansionMenus()
    wipe(expansions)
    wipe(loose)

    if not (C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines
            and C_SpellBook.GetSpellBookSkillLineInfo and C_SpellBook.GetSpellBookItemInfo) then
        return expansions, loose
    end

    if #teleportPrefixes() == 0 then return expansions, loose end
    seasonTeleports()

    for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local skillLine = C_SpellBook.GetSpellBookSkillLineInfo(line)

        if skillLine and skillLine.itemIndexOffset and skillLine.numSpellBookItems then
            local first = skillLine.itemIndexOffset + 1
            local last  = skillLine.itemIndexOffset + skillLine.numSpellBookItems

            for index = first, last do
                local item = C_SpellBook.GetSpellBookItemInfo(index, SPELLBOOK_PLAYER)

                -- Le grimoire publie déjà le nom et l'icône : on ne redemande
                -- rien tant qu'il les donne. Le parcours passe sur tous les
                -- sorts du personnage (règle 7).
                if item and item.name and isTeleportName(item.name) then
                    if item.itemType == SPELLBOOK_FLYOUT and item.actionID then
                        local list, matches, newest = flyoutDungeons(item.actionID)

                        if #list > 0 then
                            local label = dungeonPart(item.name)
                            expansions[#expansions + 1] = {
                                name    = label,
                                icon    = item.iconID,
                                entries = list,
                                rank    = expansionRank(label),
                                newest  = newest,
                                -- Le tiroir de la saison est celui dont **toutes**
                                -- les destinations sont dans la rotation. Le test
                                -- doit rester strict : un donjon d'une vieille
                                -- extension revient régulièrement dans la saison,
                                -- et « au moins une » ferait remonter Legion.
                                season  = matches == #list,
                            }
                        end

                    elseif item.itemType == SPELLBOOK_SPELL and item.spellID
                           and not seasonSpells[item.spellID] then
                        -- Une téléportation seule, sans tiroir autour d'elle.
                        loose[#loose + 1] = {
                            kind = "spell", id = item.spellID, payload = item.spellID,
                            name = dungeonName(item.spellID) or dungeonPart(item.name),
                            icon = item.iconID,
                        }
                        seasonSpells[item.spellID] = true
                    end
                end
            end
        end
    end

    -- De la plus récente extension à la plus ancienne, la saison en cours en
    -- tête. Quatre critères, dans cet ordre :
    --
    --   1. le **rang d'extension** publié par le client. C'est le critère qui
    --      porte tout : il est juste par construction, et la prochaine extension
    --      s'insère devant les autres sans qu'on touche à quoi que ce soit ;
    --   2. à rang égal — l'extension courante et sa saison —, le tiroir dont le
    --      nom est le plus long passe devant : c'est celui qui porte un suffixe,
    --      donc « Midnight – Saison 1 » et non « Midnight » ;
    --   3. le tiroir reconnu comme celui de la rotation, filet du précédent si
    --      un jour la saison cessait de se nommer d'après son extension ;
    --   4. le plus grand identifiant de sort, puis le nom : de quoi ordonner un
    --      tiroir dont le nom ne ressemble à aucune extension connue. Ceux-là
    --      finissent en bas, ce qui est la bonne place pour l'inconnu.
    table.sort(expansions, function(a, b)
        if a.rank ~= b.rank then return a.rank > b.rank end
        if #a.name ~= #b.name then return #a.name > #b.name end
        if a.season ~= b.season then return a.season end
        if a.newest ~= b.newest then return a.newest > b.newest end
        return a.name < b.name
    end)
    table.sort(loose, function(a, b) return a.name < b.name end)
    return expansions, loose
end

-- =========================================================================
--  Contenu du menu
-- =========================================================================

--- Pierres de foyer que ce personnage possède, pour le menu déroulant du
--- réglage. Une table neuve à chaque appel : la liste ne se lit qu'à l'ouverture
--- du menu déroulant, jamais dans un chemin chaud.
---@return table[]
local function hearthstoneChoices()
    local out = {}

    for i = 1, #HEARTHSTONE_POOL do
        local id = HEARTHSTONE_POOL[i]
        local entry = resolveItem(id)
        if entry then out[#out + 1] = { value = id, label = entry.name } end
    end

    return out
end

--- Contenu du menu. Réutilisée d'une reconstruction à l'autre : le menu se
--- refait à chaque objet qui entre dans les sacs.
local entries = {}

---@param mod table
---@return BUI.MenuEntry[]
local function buildEntries(mod)
    wipe(entries)

    -- La pierre choisie, ou celle de base si le choix n'est pas (ou plus)
    -- possédé : un personnage fraîchement créé n'a que celle-là.
    local chosen = resolveItem(mod:Get("hearthstone")) or resolveItem(BASE_HEARTHSTONE)
    if chosen then entries[#entries + 1] = chosen end

    for i = 1, #TRAVEL_STONES do
        local entry = resolveItem(TRAVEL_STONES[i])
        if entry then entries[#entries + 1] = entry end
    end

    for i = 1, #TRAVEL_SPELLS do
        local entry = resolveSpell(TRAVEL_SPELLS[i])
        if entry then entries[#entries + 1] = entry end
    end

    -- Le titre n'est posé qu'une fois qu'on sait que la section a du contenu :
    -- un intitulé qui ne coiffe rien est une ligne vide.
    if #entries > 0 then
        table.insert(entries, 1, { header = L["Hearthstones"] })
    end

    -- Un tiroir par extension, nommés et illustrés comme dans le grimoire, la
    -- saison en cours en tête.
    local packs, others = expansionMenus()

    if #packs > 0 or #others > 0 then
        entries[#entries + 1] = { header = L["Teleports"] }
    end

    for i = 1, #packs do
        local pack = packs[i]
        entries[#entries + 1] = {
            submenu = {
                name    = pack.name,
                icon    = pack.icon or T.TEXTURE.MENU_TIMEWAYS,
                entries = pack.entries,
            },
        }
    end

    if #others > 0 then
        entries[#entries + 1] = {
            submenu = { name = L["Other expansions"], icon = T.TEXTURE.MENU_TIMEWAYS, entries = others },
        }
    end

    return entries
end

-- =========================================================================
--  Le bouton et le menu
-- =========================================================================

-- Le menu ne dépend **pas** du bouton de minicarte. Le réglage `teleport` ne
-- décide que de l'affichage de ce bouton-là ; le menu, lui, s'ouvre aussi depuis
-- une macro, et qui a rangé son bouton doit garder sa macro.
--
-- Il se construit donc à la demande : tant que personne ne l'a ouvert et que le
-- bouton est éteint, il n'existe pas et ne coûte rien — ni parcours du grimoire,
-- ni boutons sécurisés.

local teleportButton, menu, clickTarget

---@param mod table
local function refreshMenu(mod)
    if not menu then return end

    -- Rien à faire si le client refuse : les attributs seront réécrits à la
    -- sortie de combat, où cette même fonction est rappelée.
    menu:SetEntries(buildEntries(mod))
end

--- Construit le menu au premier besoin. Renvoie `nil` si le client n'expose pas
--- de template d'action sécurisée — il n'y a alors rien à ouvrir.
---@param mod table
---@return table|nil
local function ensureMenu(mod)
    if menu then return menu end

    menu = W.SecureMenu(UIParent)
    if not menu then return nil end

    refreshMenu(mod)
    return menu
end

-- ---------------------------------------------------------------------------
--  Ouverture depuis une barre d'action
-- ---------------------------------------------------------------------------
-- Un emplacement de barre d'action n'accepte que ce que le jeu y range : sort,
-- objet, macro, monture, tenue. Jamais le cadre d'un addon. La **macro**, elle,
-- est un contenu accepté — et elle peut cliquer un bouton nommé. C'est par là
-- que le menu arrive sur une barre.
--
-- Le menu s'ouvre alors contre le cadre survolé, c'est-à-dire l'emplacement
-- cliqué : posé à côté de la minicarte alors qu'on vient de cliquer en bas de
-- l'écran, il paraîtrait ne pas s'être ouvert.

--- Nom global du bouton que la macro clique. Exception « noms de frames » de la
--- règle 3, d'où le préfixe.
local CLICK_TARGET = "BshamelUITeleportMenu"

---@return table|nil
local function frameUnderCursor()
    if GetMouseFoci then
        local focus = GetMouseFoci()
        return type(focus) == "table" and focus[1] or nil
    end
    if GetMouseFocus then return GetMouseFocus() end
    return nil
end

--- Cadre contre lequel poser le menu quand il est ouvert par la macro.
---@return table|nil
local function macroAnchor()
    local frame = frameUnderCursor()

    -- L'écran et le monde sont des cadres comme les autres pour cette question,
    -- mais s'y ancrer poserait le menu dans un coin : on les écarte.
    if frame and frame ~= UIParent and frame ~= WorldFrame
       and frame.GetCenter and frame:GetCenter() then
        return frame
    end

    return teleportButton
end

---@param mod table
local function openMenu(mod, anchor)
    if not (ensureMenu(mod) and anchor) then return end

    menu:PlaceNear(anchor)
    -- Le menu refuse de s'ouvrir en combat : on le dit, plutôt que de paraître
    -- ne rien faire.
    if not menu:Toggle() then mod:Print(L["Teleport in combat"]) end
end

--- Macro qui ouvre le menu, à glisser sur une barre d'action.
---
--- On la **crée** au lieu d'expliquer comment l'écrire : le nom du bouton à
--- cliquer est un détail d'implémentation, et le premier joueur qui le recopie
--- de travers croira que la fonctionnalité ne marche pas.
---@param mod table
local function createMacro(mod)
    if not (CreateMacro and GetMacroIndexByName) then return end
    if InCombatLockdown() then
        mod:Print(L["Teleport in combat"])
        return
    end

    local name = L["Teleport macro name"]

    -- `#showtooltip` sans rien derrière : le client cherche alors l'infobulle de
    -- l'action que la macro lancerait, n'en trouve aucune — `/click` n'est ni un
    -- sort ni un objet — et n'affiche rien. C'est le seul moyen de faire taire
    -- l'infobulle d'un emplacement de barre d'action, qui ne nous appartient pas.
    local body = "#showtooltip\n/click " .. CLICK_TARGET

    -- L'icône de la pierre de foyer, prise sur l'objet : le client rend un
    -- identifiant de fichier, que la fenêtre de macros comprend mieux qu'un
    -- chemin.
    local icon = (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(BASE_HEARTHSTONE))
                 or T.TEXTURE.MINIMAP_TELEPORT

    local existing = GetMacroIndexByName(name)
    if existing and existing > 0 then
        -- Déjà là : on la remet à jour plutôt que d'en créer une seconde du même
        -- nom, que le joueur ne saurait plus distinguer.
        if EditMacro then EditMacro(existing, name, icon, body) end
        mod:Print(string.format(L["Teleport macro updated"], name))
        return
    end

    -- Macro de compte et non de personnage : le menu n'a rien de propre à un
    -- personnage, et les emplacements de compte sont les plus nombreux.
    local index = CreateMacro(name, icon, body, false)
    if not index or index == 0 then
        mod:Print(L["Teleport macro failed"])
        return
    end

    mod:Print(string.format(L["Teleport macro created"], name))
end

--- La cible de la macro vit tant que le module est allumé, **sans** le menu :
--- c'est un cadre invisible et vide, et le menu ne se construit qu'au premier
--- clic. La macro fonctionne donc pour qui n'affiche aucun bouton de minicarte.
---@param mod table
local function ensureClickTarget(mod)
    clickTarget = clickTarget or W.ClickTarget(CLICK_TARGET, function()
        openMenu(mod, macroAnchor())
    end)
end

---@param mod table
local function applyTeleport(mod)
    if not mod:Get("teleport") then
        if menu then menu:Close() end
        if teleportButton then teleportButton:Hide() end
        return
    end

    if not teleportButton then
        -- Le menu d'abord : sans template d'action sécurisée, il n'y a rien à
        -- ouvrir, et un bouton qui ne fait rien vaut moins qu'aucun bouton.
        if not ensureMenu(mod) then return end

        -- Aucune infobulle : ce bouton n'a rien à expliquer qu'un clic ne
        -- montre, et une infobulle qui s'ouvre sous le curseur au moment où le
        -- menu s'ouvre au même endroit se disputent la place.
        teleportButton = W.MinimapButton({
            icon       = T.TEXTURE.MINIMAP_TELEPORT,
            squareIcon = true,
            onClick    = function() openMenu(mod, teleportButton) end,
            getAngle   = function() return mod:Get("teleportAngle") end,
            setAngle   = function(angle) mod:Set("teleportAngle", angle) end,
        })
        if not teleportButton then return end
    end

    teleportButton:Refresh()
    teleportButton:Show()
    refreshMenu(mod)
end

local APPLIERS = {
    teleport    = applyTeleport,
    hearthstone = refreshMenu,
}

-- =========================================================================
--  Déclaration du module
-- =========================================================================

BUI:RegisterModule(MODULE, {
    title    = L["Teleports"],
    category = "QoL",
    order    = 80,
    secure   = true,

    defaults = {
        teleport = false,
        -- Angle sur le pourtour, en degrés. Réglage sans contrôle : il se change
        -- en déplaçant le bouton, pas dans cette fenêtre. Une valeur distincte de
        -- celle du bouton de l'addon, pour que les deux allumés ensemble ne se
        -- superposent pas au premier affichage.
        teleportAngle = 160,

        -- Pierre de foyer montrée par le menu. Toutes celles qui partagent le
        -- même temps de recharge font la même chose : en lister trente serait
        -- écrire trente fois la même ligne, alors on en choisit une.
        hearthstone   = BASE_HEARTHSTONE,
    },

    options = {
        { type = "header", text = L["Buttons"] },
        {
            type    = "toggle",
            key     = "teleport",
            text    = L["Teleport menu"],
            tooltip = L["Teleport menu tip"],
        },

        { type = "header", text = L["Menu"] },
        {
            -- Pas de `disabled`, pour la même raison que la macro plus bas : le
            -- menu ne dépend pas du bouton de minicarte. Qui l'ouvre par sa
            -- macro choisit sa pierre comme les autres.
            type    = "dropdown",
            key     = "hearthstone",
            text    = L["Hearthstone choice"],
            tooltip = L["Hearthstone choice tip"],
            -- Une fonction et non une liste : ce que le personnage possède n'est
            -- pas connu quand la page se construit, et change en cours de partie.
            values  = hearthstoneChoices,
        },
        {
            -- Pas de `disabled` : la macro ne dépend pas du bouton de minicarte.
            -- C'est même son intérêt — elle remplace le bouton pour qui ne veut
            -- rien de plus autour de sa carte.
            type    = "button",
            text    = L["Teleport macro"],
            label   = L["Create"],
            tooltip = L["Teleport macro tip"],
            onClick = function()
                local mod = BUI.Modules:Get(MODULE)
                if mod then createMacro(mod) end
            end,
        },
    },

    OnEnable = function(self)
        -- La macro doit trouver sa cible même quand aucun bouton n'est affiché.
        ensureClickTarget(self)
        applyTeleport(self)

        -- Le menu suit ce que le personnage possède et connaît.
        local rebuild = U.Debounce(T.TIMING.MENU_SETTLE, function() refreshMenu(self) end)
        self:RegisterEvent("BAG_UPDATE_DELAYED", rebuild)
        self:RegisterEvent("TOYS_UPDATED",       rebuild)
        self:RegisterEvent("SPELLS_CHANGED",     rebuild)
        -- La rotation de donjons n'est pas forcément connue à la connexion :
        -- elle arrive avec le reste des données de mode défi.
        self:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE", rebuild)
        self:RegisterEvent("PLAYER_ENTERING_WORLD",      rebuild)

        -- Les attributs d'un bouton sécurisé ne se posent pas en combat : ce qui
        -- a été refusé pendant le combat est rattrapé ici.
        self:RegisterEvent("PLAYER_REGEN_ENABLED", function() refreshMenu(self) end)
    end,

    OnDisable = function()
        if menu then menu:Close() end
        if teleportButton then teleportButton:Hide() end
    end,

    OnSettingChanged = function(self, key)
        if key == nil then
            applyTeleport(self)
            return
        end

        local apply = APPLIERS[key]
        if apply then apply(self) end
    end,
})
