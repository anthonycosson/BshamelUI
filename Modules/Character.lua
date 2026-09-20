-- =========================================================================
--  Bshamel UI — Modules/Character.lua
--  Ce que la fiche de personnage ne dit pas.
--
--  Le client affiche un niveau d'objet moyen et rien d'autre : pour savoir
--  quelle pièce traîne, laquelle n'est pas enchantée et quelle châsse est
--  restée vide, il faut survoler seize emplacements l'un après l'autre. Ce
--  module pose la réponse à côté de chaque emplacement.
--
--  **Une pastille par question, verte ou rouge.** C'est la couleur qui informe,
--  le mot ne fait que nommer la question. Écrire le nom de l'enchantement en
--  toutes lettres — ce que faisait la première version — donnait six lignes de
--  texte en travers du modèle du personnage : lisible pièce par pièce,
--  illisible d'un coup d'œil, alors que « d'un coup d'œil » est tout ce qu'on
--  demande à cette fiche.
--
--  Le corollaire est qu'**on affiche aussi quand c'est bon**. Ne montrer que
--  les manques donne une fiche qui a l'air correcte dès qu'une lecture échoue :
--  l'absence de rouge ne se distingue plus de l'absence d'information.
--
--  La même chose vaut pour la fiche d'**inspection**, et c'est la même fiche :
--  mêmes emplacements, même disposition, même question — « qu'est-ce qui
--  manque ? ». Les réglages sont donc les mêmes aussi : allumer le niveau
--  d'objet l'allume des deux côtés. Un jeu de cases à cocher par fiche ferait
--  régler deux fois un seul geste de lecture.
--
--  Réversibilité (règle 6) : rien n'est modifié sur les cadres du client. Le
--  module **ajoute** une frame par emplacement et la cache à la désactivation ;
--  la fiche redevient alors exactement celle de Blizzard.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local U    = BUI.Util
local W    = BUI.Widgets
local L    = ns.L

local MODULE = "Character"

-- =========================================================================
--  Les emplacements
-- =========================================================================

--- Emplacements porteurs d'équipement, par leur nom de suffixe.
---
--- Le nom, et pas l'identifiant numérique : `GetInventorySlotInfo` donne le
--- numéro, et le bouton du client s'appelle `Character` + ce nom. Un seul nom à
--- écrire au lieu de deux valeurs à garder d'accord.
---
--- Chemise et tabard sont absents : ils n'ont ni niveau d'objet, ni
--- enchantement, ni châsse. Une pastille en face d'eux ne dirait rien.
---
--- L'arme à distance n'a de case que sur *Forever*. Retail n'a plus de bouton
--- `CharacterRangedSlot` : l'emplacement y est simplement sauté, comme tout
--- nom dont le client n'a pas le bouton.
local SLOT_NAMES = {
    "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot",
    "WristSlot", "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot",
    "Finger0Slot", "Finger1Slot", "Trinket0Slot", "Trinket1Slot",
    "MainHandSlot", "SecondaryHandSlot", "RangedSlot",
}

--- Emplacements qui acceptent un enchantement.
---
--- **Fait de jeu, pas déduction** : aucune API ne dit « cet emplacement peut
--- être enchanté ». Cette liste et la suivante sont donc les deux seules choses
--- du module à revoir quand une extension ouvre ou ferme un emplacement — et les
--- deux seules qui puissent afficher du rouge à tort.
---
--- Elle ne se devine pas d'une extension à l'autre : la cape et les bracelets
--- s'enchantaient hier et ne s'enchantent plus, le casque et les épaules font le
--- chemin inverse. Elle se relève en jeu, et c'est ce qui a été fait.
---
--- Trois valeurs :
---   · `true`       — l'emplacement s'enchante, quoi qu'il porte ;
---   · `"weapon"`   — seulement s'il porte une arme (voir `isWeapon`) ;
---   · `"engineer"` — seulement chez un ingénieur (voir `isEngineer`).
---
--- *Forever* a la sienne, relevée dans les tables de sa bêta et publiée par
--- `Core/Forever.lua` : elle remplace celle-ci entière, parce que c'est un
--- autre jeu et pas une variante de celui-ci.
local ENCHANTABLE = ns.ENCHANTABLE or {
    HeadSlot          = true,
    ShoulderSlot      = true,
    ChestSlot         = true,
    LegsSlot          = true,
    FeetSlot          = true,
    Finger0Slot       = true,
    Finger1Slot       = true,
    MainHandSlot      = true,
    SecondaryHandSlot = "weapon",
}

--- Numéro d'un emplacement, ou `nil` si le client ne connaît pas ce nom.
---
--- Sous `pcall` : `GetInventorySlotInfo` **lève** sur un nom inconnu au lieu
--- de rendre `nil`, et `SLOT_NAMES` en cite un que retail n'a plus.
---@param name string
---@return integer|nil
local function slotIDOf(name)
    if not GetInventorySlotInfo then return nil end
    local ok, slotID = pcall(GetInventorySlotInfo, name)
    if ok then return slotID end
    return nil
end

--- Ingénierie, par l'identifiant de sa ligne de compétence. Un identifiant de
--- jeu, pas une chaîne affichée : il ne se traduit pas.
local ENGINEERING_SKILL = 202

--- Où poser la colonne de pastilles de chaque emplacement : toujours **du côté
--- opposé au modèle**, celui qui donne sur le vide.
---
--- Une liste et non une déduction géométrique, après avoir essayé l'inverse.
--- Comparer l'abscisse d'un bouton à celle de la fiche paraît plus robuste
--- qu'une liste — sauf que `CharacterFrame` **englobe le panneau de
--- caractéristiques**. Son centre ne tombe donc pas au milieu du modèle mais
--- entre le modèle et les statistiques, si bien que la colonne de droite se
--- retrouve à quelques pixels de cet axe et passe pour une arme. Il aurait fallu
--- mesurer la scène du modèle, ce qui revient à nommer un cadre du client —
--- c'est-à-dire à faire exactement ce qu'on croyait éviter, en moins lisible.
---
--- La disposition de la fiche n'a pas bougé depuis vingt ans. Cette liste-là
--- vieillira mieux qu'un seuil.
local PLACEMENT = {
    HeadSlot     = "RIGHT", NeckSlot    = "RIGHT", ShoulderSlot = "RIGHT",
    BackSlot     = "RIGHT", ChestSlot   = "RIGHT", WristSlot    = "RIGHT",

    HandsSlot    = "LEFT",  WaistSlot   = "LEFT",  LegsSlot     = "LEFT",
    FeetSlot     = "LEFT",  Finger0Slot = "LEFT",  Finger1Slot  = "LEFT",
    Trinket0Slot = "LEFT",  Trinket1Slot = "LEFT",

    -- Les deux armes empilent leur colonne au-dessus de leur case (voir
    -- `buildSlots`) ; leur entrée ici ne dit pas un côté de rangement mais leur
    -- **côté libre** — celui qui donne sur le vide, pas sur l'autre arme. C'est
    -- vers lui qu'une ligne plus large que l'icône déborde : la main droite est
    -- à gauche de l'écran, son vide est à gauche, et l'inverse pour la main
    -- gauche. Centrées, les deux lignes débordaient l'une vers l'autre et
    -- s'écrivaient l'une sur l'autre. `levelLine` lit aussi cette entrée pour
    -- ordonner « (rang) niveau » : le niveau reste ainsi contre la case.
    MainHandSlot = "LEFT", SecondaryHandSlot = "RIGHT",

    -- *Forever* seulement : la troisième case, à droite de la main gauche. Son
    -- vide est à droite comme celui de la main gauche — sans rang
    -- d'amélioration sur ce client, les lignes tiennent sur la largeur d'une
    -- case et ne débordent pas l'une vers l'autre.
    RangedSlot   = "RIGHT",
}

--- Les deux emplacements qui ouvrent les colonnes, de gauche à droite à l'écran.
---
--- Ils bornent la zone d'équipement, et le milieu de cette largeur est le milieu
--- du modèle : c'est là que se pose le niveau d'objet du personnage. Se centrer
--- sur le cadre du client donnerait autre chose — il englobe le panneau de
--- caractéristiques, et son milieu tombe entre le modèle et les statistiques.
local HEADLINE_ANCHORS = { "HeadSlot", "HandsSlot" }

--- Les deux emplacements qui n'ont pas de voisin au-dessus d'eux.
---
--- Ce sont les seuls dont la colonne peut s'empiler vers le haut sans recouvrir
--- la case suivante : les quatorze autres sont en file le long du modèle.
local WEAPON_SLOTS = {
    MainHandSlot      = true,
    SecondaryHandSlot = true,
    RangedSlot        = true,
}

--- Cet emplacement porte-t-il une arme ?
---
--- Ne se pose que pour la main gauche, qui reçoit indifféremment une arme, un
--- bouclier ou un objet tenu. Les deux derniers n'acceptent ni enchantement ni
--- noyau : leur réclamer l'un ou l'autre serait reprocher au joueur quelque
--- chose qui n'existe pas.
---@param link string
---@return boolean
local function isWeapon(link)
    if not (C_Item and C_Item.GetItemInfoInstant) then return false end
    local classID = select(6, C_Item.GetItemInfoInstant(link))
    return classID == (Enum and Enum.ItemClass and Enum.ItemClass.Weapon or 2)
end

--- L'unité est-elle ingénieur ?
---
--- Ne se sait que du joueur : le client ne dit pas les métiers d'un personnage
--- inspecté. Pour lui, la réponse est « non » — un emplacement qu'on ne sait
--- pas réclamer ne doit pas s'afficher en rouge.
---@param unit string
---@return boolean
local function isEngineer(unit)
    if unit ~= "player" then return false end

    if C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID then
        local ok, info = pcall(C_SkillInfo.GetSkillLineInfoByID, ENGINEERING_SKILL)
        if ok and type(info) == "table" then
            return type(info.rank) == "number" and info.rank > 0
        end
    end

    if GetProfessions and GetProfessionInfo then
        local first, second = GetProfessions()
        for _, index in ipairs({ first, second }) do
            local skillLine = select(7, GetProfessionInfo(index))
            if skillLine == ENGINEERING_SKILL then return true end
        end
    end
    return false
end

--- L'arme est-elle à deux mains ? Elle occupe alors aussi la main gauche, et
--- le niveau d'objet moyen la compte pour les deux emplacements.
---@param link string
---@return boolean
local function isTwoHanded(link)
    if not (C_Item and C_Item.GetItemInfoInstant) then return false end
    return select(4, C_Item.GetItemInfoInstant(link)) == "INVTYPE_2HWEAPON"
end

---@param slotName string
---@param link string
---@param unit string
---@return boolean
local function expectsEnchant(slotName, link, unit)
    local rule = ENCHANTABLE[slotName]
    if rule == "weapon"   then return isWeapon(link) end
    if rule == "engineer" then return isEngineer(unit) end
    return rule == true
end

-- =========================================================================
--  Châsses
-- =========================================================================

--- Nombre de châsses qu'un objet peut porter au maximum.
---
--- Le lien d'objet réserve quatre champs de gemme, et il n'existe pas de
--- fonction qui dise « combien en a celui-ci ». On les interroge donc tous les
--- quatre : ce sont quatre appels côté client, sur un chemin déjà groupé.
local MAX_SOCKETS = 4

--- Châsses d'un objet : combien il en a, combien sont serties.
---
--- Deux lectures indépendantes, et c'est volontaire :
---
---   * `GetItemStats` donne le **total**. Malgré leur nom, les clés
---     `EMPTY_SOCKET_*` comptent les châsses serties **aussi** : une châsse
---     remplie y figure encore. Les vides ne s'en déduisent donc pas seules ;
---   * `GetItemGem` donne les **serties**, une par une.
---
--- Le total retenu est le plus grand des deux. C'est ce qui fait que des gemmes
--- visibles restent affichées même si le décompte des châsses échoue — on perd
--- alors la connaissance des châsses vides, pas l'affichage entier.
---
--- On n'essaie **pas** de tendre une table de travail à `GetItemStats` : c'est le
--- contrat de l'ancienne globale, pas nécessairement celui de la variante
--- `C_Item`, et le pari échoue en silence. Seize tables par relecture, sur un
--- chemin groupé et qui ne tourne que la fiche ouverte, est le prix honnête de
--- cette certitude.
---@param link string
---@return integer total
---@return integer filled
local function sockets(link)
    local total = 0

    -- La fonction a migré dans `C_Item` ; la globale existe encore. On essaie les
    -- deux plutôt que de parier sur l'une (CLAUDE.md règle 1).
    local readStats = (C_Item and C_Item.GetItemStats) or GetItemStats
    if readStats then
        local stats = readStats(link)
        if stats then
            for key, count in pairs(stats) do
                if type(count) == "number" and count > 0 and key:find("^EMPTY_SOCKET_") then
                    total = total + count
                end
            end
        end
    end

    local readGem = (C_Item and C_Item.GetItemGem) or GetItemGem
    if not readGem then return total, 0 end

    local filled = 0
    for index = 1, MAX_SOCKETS do
        if select(2, readGem(link, index)) then filled = filled + 1 end
    end

    if filled > total then total = filled end
    return total, filled
end

-- =========================================================================
--  Infobulle
-- =========================================================================

--- Retire d'une ligne d'infobulle ce qui n'est pas du texte : les couleurs, et
--- les icônes en ligne — l'étoile de rang d'un enchantement en est une, et elle a
--- déjà été lue au moment où l'on nettoie (voir `enchantInfo`).
---@param value string
---@return string
local function plain(value)
    value = value:gsub("|cn.-:(.-)|r", "%1")   -- couleurs nommées, forme récente
    value = value:gsub("|c%x%x%x%x%x%x%x%x", "")
    value = value:gsub("|A.-|a", "")           -- icône d'atlas en ligne
    value = value:gsub("|T.-|t", "")           -- texture en ligne
    return (value:gsub("|r", ""))
end

-- =========================================================================
--  Niveau d'objet et amélioration
-- =========================================================================

--- Type de ligne d'infobulle qui porte un enchantement permanent.
---
--- **Un type, pas une couleur ni un texte.** Le client marque cette ligne-là
--- structurellement : elle porte son `enchantID` et, dans son texte, l'étoile de
--- rang du métier. On la reconnaît donc sans lire un mot — la reconnaître au vert
--- marcherait aussi, mais le vert sert également aux bonus d'ensemble.
---
--- Le nombre est relevé sur le client faute d'énumération publiée sous un nom
--- stable ; on tente d'abord celle-ci, et on retombe sur la valeur relevée.
local ENCHANT_LINE = (Enum and Enum.TooltipDataLineType
                      and Enum.TooltipDataLineType.ItemEnchantmentPermanent) or 15

--- L'enchantement porté par une pièce : l'étoile de son rang, et son intitulé.
---
--- **L'étoile est celle du client, reprise telle quelle.** Il l'écrit au bout de
--- la ligne sous la forme `|A:nom-d-atlas:h:l|a`, et on garde ce nom entier. Un
--- nom d'atlas ne se traduit pas : la lecture ne dépend donc pas de la langue,
--- là où le nom de l'enchantement en dépendrait.
---
--- Surtout, elle est juste par construction. Lire seulement le chiffre du nom et
--- reconstruire l'atlas autour paraît plus propre et ne l'est pas : le jeu a
--- plusieurs familles d'étoiles, et le rang d'un enchantement ne se compte pas
--- sur la même échelle que la qualité d'une pièce d'équipement. Le numéro seul ne
--- dit donc pas de quelle icône il parle.
---
--- L'intitulé est **le texte du client sans les échappements** — un enchantement
--- n'a pas de lien d'objet, donc rien à tendre à une infobulle du client : c'est
--- cette ligne-là ou rien.
---
--- Le premier retour dit seulement si la pièce est enchantée, et il vaut `true`
--- même quand la ligne est illisible : la pièce **est** enchantée, on ne sait
--- simplement rien de plus.
---@param unit string
---@param slotID integer
---@return boolean|nil enchanted
---@return string|nil atlas
---@return string|nil label
local function enchantInfo(unit, slotID)
    if not (C_TooltipInfo and C_TooltipInfo.GetInventoryItem) then return nil end

    local data = C_TooltipInfo.GetInventoryItem(unit, slotID)
    if not data then return nil end

    if TooltipUtil and TooltipUtil.SurfaceArgs then TooltipUtil.SurfaceArgs(data) end

    for _, line in ipairs(data.lines or {}) do
        if line.type == ENCHANT_LINE then
            local text = line.leftText
            if type(text) ~= "string" or U.IsSecret(text) then return true end

            -- **On reprend le nom d'atlas entier, pas son numéro.** L'étoile de
            -- rang est écrite dans la ligne sous la forme `|A:nom:h:l|a` : la
            -- prendre telle quelle garantit qu'on affiche exactement ce que le
            -- joueur voit dans l'infobulle, sans rien avoir à savoir de l'échelle.
            --
            -- N'en lire que le chiffre et reconstruire le nom autour, comme on le
            -- faisait, revenait à parier sur la famille d'icônes — et à se
            -- tromper de famille : le jeu en a plusieurs, et le rang 1 d'un
            -- enchantement n'est pas le rang 1 d'une pièce d'équipement.
            return true, text:match("|A:([^:|]+)"), plain(text)
        end
    end

    return nil
end

--- Niveau d'objet réel de la pièce équipée.
---
--- Pour le joueur, par l'emplacement et non par le lien : c'est le seul chemin
--- qui tienne compte de la mise à l'échelle. Un objet de bas niveau monté par
--- une affinité ou une pièce de raid mise à l'échelle affiche sinon le niveau
--- écrit dans son lien, qui n'est pas celui que le personnage porte.
---
--- Pour quelqu'un d'autre, ce chemin n'existe pas : `ItemLocation` ne sait
--- désigner que l'inventaire du joueur. Il reste le lien, qui porte les
--- identifiants de bonus et donc le niveau effectif de la pièce — c'est ce que
--- le serveur envoie de l'inspection, et il n'y a rien de plus juste à lire.
---@param unit string
---@param slotID integer
---@param link string
---@return integer|nil
local function itemLevel(unit, slotID, link)
    if unit == "player" and ItemLocation and C_Item and C_Item.GetCurrentItemLevel then
        local location = ItemLocation:CreateFromEquipmentSlot(slotID)
        if location and C_Item.DoesItemExist and C_Item.DoesItemExist(location) then
            local level = C_Item.GetCurrentItemLevel(location)
            if level and level > 0 then return level end
        end
    end

    local read = (C_Item and C_Item.GetDetailedItemLevelInfo) or GetDetailedItemLevelInfo
    if not read then return nil end

    local level = read(link)
    if not level or level <= 0 then return nil end
    return level
end

--- Rang d'amélioration sous la forme « 6/8 », et la piste qui le porte.
---
--- La piste est rendue par son **identifiant**, pas par son intitulé : le client
--- publie les deux, et seul l'identifiant survit à un changement de langue (voir
--- `T.TrackColor`).
---@param link string
---@return string|nil text
---@return boolean maxed
---@return number|nil trackID
local function upgradeOf(link)
    if not (C_Item and C_Item.GetItemUpgradeInfo) then return nil, false, nil end

    local info = C_Item.GetItemUpgradeInfo(link)
    if not info then return nil, false, nil end

    local current, max = info.currentLevel, info.maxLevel
    if not (current and max and max > 0) then return nil, false, info.trackStringID end

    return current .. "/" .. max, current >= max, info.trackStringID
end

-- =========================================================================
--  Sacs, banque, banque de bataillon
-- =========================================================================
-- Le même nombre que sur la fiche, posé sur les objets rangés. C'est la même
-- question — « celle-là vaut-elle mieux que ce que je porte ? » — et elle se
-- pose surtout devant un sac.
--
-- Le module s'appelle « Fiche de personnage » et déborde donc un peu de son
-- nom. C'est assumé : éclater deux affichages du même nombre dans deux pages
-- obligerait à les régler à deux endroits pour un seul geste de lecture.

--- Cadres à parcourir pour trouver des boutons d'objet.
---
--- `BankFrame` couvre normalement la banque du personnage **et** la banque de
--- bataillon : depuis leur refonte, les deux sont des onglets d'une même
--- fenêtre. Les deux noms de panneau qui suivent sont cités par prudence, au cas
--- où le contenu ne serait pas descendant du cadre — une racine absente ne coûte
--- rien, une racine manquante coûte un affichage muet.
local CONTAINER_ROOTS = {
    "ContainerFrameCombinedBags",
    "BankFrame", "BankPanel", "AccountBankPanel",
}
for i = 1, 13 do
    CONTAINER_ROOTS[#CONTAINER_ROOTS + 1] = "ContainerFrame" .. i
end

--- Profondeur de descente dans l'arbre d'un conteneur.
---
--- Les boutons ne sont pas tous des enfants directs. Un sac les tient à un ou
--- deux niveaux ; la **banque** les enterre bien plus bas — cadre, panneau,
--- zone défilante, cible de défilement, puis le bouton. Cinq niveaux ne
--- suffisaient pas, et l'échec était muet : un bouton hors de portée ne se
--- distingue pas d'un bouton absent.
---
--- Huit laisse de la marge sans ouvrir la porte à un parcours sans fin. La
--- borne n'est pas là pour économiser du temps de calcul, elle est là parce
--- qu'un parcours d'arbre sans borne est un pari sur une structure qui ne nous
--- appartient pas.
local WALK_DEPTH = 8

--- Sac et emplacement que désigne un bouton, ou `nil`.
---
--- Trois conventions coexistent selon l'âge du cadre : le bouton publie son sac,
--- son parent le publie, ou il le porte en champ. On les essaie dans cet ordre.
--- Rien n'est deviné pour autant — le couple obtenu n'est retenu que si le
--- client y reconnaît un objet.
---@param button table
---@return integer|nil bag
---@return integer|nil slot
local function containerSlotOf(button)
    local bag
    if button.GetBagID then bag = button:GetBagID() end

    -- La banque refondue ne parle pas de sac mais d'**onglet**, et ses boutons
    -- publient donc autre chose. Un onglet de banque est pourtant un sac comme
    -- un autre pour `C_Container` : seul le nom du chemin change.
    if bag == nil and button.GetBankTabID then bag = button:GetBankTabID() end
    if bag == nil then bag = button.bankTabID end

    if bag == nil then
        local parent = button.GetParent and button:GetParent()
        if parent and parent.GetBagID then bag = parent:GetBagID() end
    end

    if bag == nil then bag = button.bagID end
    if bag == nil then return nil end

    -- L'emplacement se demande **avant** `GetID`, et pas après : un bouton sorti
    -- d'un pool porte volontiers dans son `GetID` son rang dans le pool, qui
    -- n'est pas son emplacement dans le conteneur. Prendre le mauvais des deux
    -- ne donnerait pas une case vide mais une case **fausse**.
    local slot
    if button.GetContainerSlotID then slot = button:GetContainerSlotID() end
    if slot == nil then slot = button.containerSlotID end
    if slot == nil and button.GetID then slot = button:GetID() end

    if not slot or slot < 1 then return nil end

    return bag, slot
end

--- Pose — ou retire — le niveau d'objet sur un bouton.
---
--- Aucun test préalable ne cherche à reconnaître un bouton d'objet, et c'est
--- délibéré : le seul juge est le client. Si le couple sac/emplacement lu sur le
--- cadre désigne un objet, c'en est un ; sinon on ne touche à rien. Un test de
--- forme — « a-t-il telle méthode ? », « est-il de tel type ? » — n'aurait fait
--- qu'ajouter une façon d'écarter un vrai bouton en silence.
---@param button table
---@return boolean handled  le cadre est-il un vrai bouton de conteneur ?
local function tagButton(button)
    local bag, slot = containerSlotOf(button)
    if not bag then return false end

    local link = C_Container and C_Container.GetContainerItemLink
                 and C_Container.GetContainerItemLink(bag, slot)

    local tag = W.ItemLevelTag(button)
    if not tag then return true end

    if not link then
        tag:Hide()
        return true
    end

    -- Seul l'équipement porte un niveau d'objet qui veuille dire quelque chose.
    -- Un nombre sur une potion ou un minerai serait du bruit sur toute la grille.
    if not (C_Item and C_Item.GetItemInfoInstant) then
        tag:Hide()
        return true
    end

    local _, _, _, equipLoc, _, classID = C_Item.GetItemInfoInstant(link)
    local weapon = Enum and Enum.ItemClass and Enum.ItemClass.Weapon or 2
    local armor  = Enum and Enum.ItemClass and Enum.ItemClass.Armor  or 4

    local equippable = (classID == weapon or classID == armor)
                       and equipLoc and equipLoc ~= "" and equipLoc ~= "INVTYPE_NON_EQUIP"
    if not equippable then
        tag:Hide()
        return true
    end

    -- Trois chemins vers le niveau d'objet, du plus juste au plus disponible.
    -- Le premier tient compte de la mise à l'échelle et c'est pour ça qu'il
    -- passe en premier ; les deux autres lisent le lien, ce qui suffit pour un
    -- objet rangé. En avoir trois n'est pas de la superstition : un seul chemin
    -- qui rend `nil` donne une case muette, et une case muette ne se distingue
    -- pas d'un réglage éteint.
    local level
    if ItemLocation and C_Item.GetCurrentItemLevel then
        local location = ItemLocation:CreateFromBagAndSlot(bag, slot)
        if location and C_Item.DoesItemExist and C_Item.DoesItemExist(location) then
            level = C_Item.GetCurrentItemLevel(location)
        end
    end
    if not level and C_Item.GetDetailedItemLevelInfo then
        level = C_Item.GetDetailedItemLevelInfo(link)
    end
    if not level and GetDetailedItemLevelInfo then
        level = GetDetailedItemLevelInfo(link)
    end

    if not level or level <= 0 then
        tag:Hide()
        return true
    end

    local quality = C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(link)
    tag:SetText(tostring(level))
    tag:SetTextColor(T.ItemQualityColor(quality))
    tag:Show()

    return true
end

--- Met un bouton sous surveillance, pour qu'il annonce lui-même ses changements.
---
--- C'est le seul moyen de suivre un **changement d'onglet de banque**. Le client
--- n'émet aucun événement : il se contente de repeupler les mêmes boutons avec
--- le contenu de l'autre onglet. Sans ce guet, le nombre de l'onglet précédent
--- reste affiché sur une case qui montre désormais autre chose — un chiffre
--- faux, ce qui est pire qu'un chiffre absent.
---
--- On s'accroche à la pose de la texture parce que c'est le geste que le client
--- fait **à chaque fois** qu'une case change de contenu, quel que soit le
--- conteneur : changer d'onglet, trier, déplacer un objet. Un bouton n'est
--- accroché qu'une fois — `U.GuardedHook` retient ce qu'il a déjà posé —, et les
--- boutons sortant d'un pool borné, leur nombre l'est aussi.
---@param button table
local function watchButton(button)
    if type(button.SetItemButtonTexture) ~= "function" then return end

    U.GuardedHook(button, "SetItemButtonTexture", function(self)
        local mod = BUI.Modules:Get(MODULE)
        if not (mod and mod:Get("showBagItemLevel")) then return end
        BUI.safecall(tagButton, self)
    end, function()
        local mod = BUI.Modules:Get(MODULE)
        return mod and mod:IsEnabled()
    end)
end

--- Descend dans un cadre et étiquette tous les boutons d'objet rencontrés.
---@param frame table
---@param depth integer
local function walkContainer(frame, depth)
    if depth <= 0 or not frame.GetChildren then return end

    for _, child in ipairs({ frame:GetChildren() }) do
        -- Un cadre qui s'est révélé être un bouton de conteneur est mis sous
        -- surveillance : le parcours ne repassera pas forcément par lui, mais
        -- lui saura se signaler.
        local ok, handled = BUI.safecall(tagButton, child)
        if ok and handled then watchButton(child) end

        walkContainer(child, depth - 1)
    end
end

--- Repasse sur tous les conteneurs ouverts.
---@param mod table
local function updateContainers(mod)
    if not mod:Get("showBagItemLevel") then
        W.ClearItemLevelTags()
        return
    end

    for i = 1, #CONTAINER_ROOTS do
        local root = _G[CONTAINER_ROOTS[i]]
        -- Un conteneur fermé n'a rien à montrer, et son parcours coûte autant
        -- que celui d'un conteneur ouvert.
        if root and root.IsShown and root:IsShown() then
            walkContainer(root, WALK_DEPTH)
        end
    end
end

-- =========================================================================
--  Bandeaux
-- =========================================================================

--- Les deux fiches, décrites de la même façon.
---
--- Elles ne diffèrent que par trois choses : le préfixe de leurs boutons, le
--- cadre qui les porte, et l'unité qu'elles montrent. Tout le reste — les seize
--- emplacements, la disposition des colonnes, la lecture de chaque pièce — est
--- commun, et c'est pour ça que cette table existe plutôt qu'un second module.
---
--- La fiche d'inspection vit dans un addon **chargé à la demande** : son cadre
--- et ses boutons n'existent pas au démarrage, d'où le champ `addon` et la
--- construction différée.
local SHEETS = {
    {
        prefix = "Character",
        slots  = {},
        Frame  = function() return CharacterFrame end,
        Unit   = function() return "player" end,
    },
    {
        prefix = "Inspect",
        addon  = "Blizzard_InspectUI",
        slots  = {},
        Frame  = function() return InspectFrame end,
        -- Le cadre publie l'unité qu'il montre, et c'est en général « target ».
        -- On la relit à chaque passage plutôt que de la retenir : le client
        -- suit lui-même les changements de cible pendant que la fenêtre est
        -- ouverte, et une unité retenue montrerait l'équipement de quelqu'un
        -- que la fiche n'affiche plus.
        Unit   = function()
            local unit = InspectFrame and InspectFrame.unit
            if unit and UnitExists(unit) then return unit end
            return nil
        end,
    },
}

--- Construit une colonne par emplacement. Rend `false` tant que la fiche du
--- client n'est pas là — elle peut être chargée à la demande.
---
--- La position se pose ici, une fois pour toutes : elle ne dépend que du nom de
--- l'emplacement, donc d'aucune mesure, donc d'aucun moment.
---@param sheet table
---@return boolean
local function buildSlots(sheet)
    if #sheet.slots > 0 then return true end
    if not (sheet.Frame() and GetInventorySlotInfo) then return false end

    for i = 1, #SLOT_NAMES do
        local name   = SLOT_NAMES[i]
        local button = _G[sheet.prefix .. name]
        local slotID = button and slotIDOf(name)

        if button and slotID then
            local info = W.SlotInfo(button)
            if info then
                -- **Toutes les colonnes s'accrochent par le haut.** Centrée sur
                -- sa case, une colonne fait descendre sa première ligne d'un
                -- demi-cran chaque fois qu'une ligne s'ajoute : une pièce sans
                -- gemme et sa voisine qui en a trois n'écrivaient plus leur
                -- niveau d'objet à la même hauteur, et la fiche perdait l'usage
                -- qu'on en attend — parcourir seize nombres d'un seul coup d'œil.
                -- Accrochées par le haut, ces seize lignes tombent au même
                -- endroit, et ce sont les icônes qui descendent plus ou moins.
                --
                -- Les armes empilent leur colonne **au-dessus** de la case.
                -- Elles sont côte à côte sous le modèle : les ranger sur les
                -- côtés mettait celle de droite contre les statistiques et
                -- celle de gauche dans le vide, deux voisinages différents pour
                -- deux pièces qu'on lit ensemble. Au-dessus, elles se
                -- ressemblent, et la place est libre depuis que le niveau
                -- d'objet du personnage est monté en tête de fiche.
                --
                -- Chacune passe son côté libre : sans lui, les deux lignes se
                -- centrent sur des cases collées et débordent l'une sur l'autre.
                info:SetPlacement(WEAPON_SLOTS[name] and "ABOVE"
                                  or PLACEMENT[name] or "RIGHT", true,
                                  WEAPON_SLOTS[name] and PLACEMENT[name] or nil)
                sheet.slots[#sheet.slots + 1] = { id = slotID, name = name, info = info }
            end

            if name == HEADLINE_ANCHORS[1] then sheet.topLeft  = button end
            if name == HEADLINE_ANCHORS[2] then sheet.topRight = button end
        end
    end

    sheet.headline = W.SheetItemLevel(sheet.topLeft, sheet.topRight)

    return #sheet.slots > 0
end

--- Table de travail du décompte des pistes, réutilisée d'un passage à l'autre.
local trackTally = {}

--- La couleur du niveau d'objet du personnage : celle de la piste **la plus
--- portée**.
---
--- Un niveau moyen n'a pas de piste à lui — c'est un nombre, pas une pièce. On ne
--- peut donc pas la lire, il faut la déduire, et deux façons de le faire ont été
--- écartées avant celle-ci :
---
---   * **par paliers de niveau d'objet** : il faudrait une table de seuils, qui
---     est fausse au premier jour d'une saison et qu'il faudrait tenir à chaque
---     patch. C'est exactement le genre de nombre que ce dépôt refuse d'écrire ;
---   * **par la piste la plus haute** : une seule pièce mythique suffirait alors
---     à peindre toute la fiche en orange, ce qui dit le contraire de la vérité.
---
--- La plus fréquente, elle, décrit ce que le personnage porte vraiment. À égalité
--- c'est la plus haute qui gagne : entre deux moitiés, la fiche annonce la
--- meilleure — un personnage à moitié mythique n'est pas un personnage héroïque.
---
--- Sans aucune piste lisible, `nil` remonte et l'appelant garde le doré des
--- libellés, qui n'affirme rien.
---@param sheet table
---@param unit string
---@return number r, number g, number b
local function headlineColor(sheet, unit)
    wipe(trackTally)

    for i = 1, #sheet.slots do
        local link = GetInventoryItemLink(unit, sheet.slots[i].id)
        local track = link and select(3, upgradeOf(link))
        if track then trackTally[track] = (trackTally[track] or 0) + 1 end
    end

    local best, bestCount
    for track, count in pairs(trackTally) do
        if not bestCount or count > bestCount or (count == bestCount and track > best) then
            best, bestCount = track, count
        end
    end

    local r, g, b = T.TrackColor(best)
    if r then return r, g, b end
    return T.COLOR.NORMAL:GetRGB()
end

--- Décimales que le réglage laisse demander.
---
--- Deux, parce que c'est là que le nombre cesse de dire quelque chose : le niveau
--- d'objet moyen est une somme de seize entiers divisée par seize, donc un
--- multiple de 0,0625 — la troisième décimale existe, mais elle ne distingue
--- aucune paire d'équipements qu'on puisse porter.
local MAX_LEVEL_DECIMALS = 2

--- Écrit le niveau d'objet du personnage, ou l'efface.
---
--- **Celui qu'il porte, pas celui qu'il possède**, et on le **calcule** : la somme
--- des pièces que la fiche affiche, divisée par le nombre d'emplacements — un
--- emplacement vide compte zéro, comme chez le client. Une arme à deux mains
--- compte deux fois quand la main gauche est vide.
---
--- `GetAverageItemLevel` a servi ici, et il est parti : sur *Forever*, son
--- second retour — l'équipé — ne suivait pas les pièces qu'on retire, et
--- la fiche annonçait un équipement qu'on ne portait plus. Calculé, le nombre est celui
--- des colonnes, au même instant, sur les deux clients et sur la fiche
--- d'inspection — qui n'a jamais eu d'autre chemin.
---@param mod table
---@param sheet table
---@param unit string
local function paintHeadline(mod, sheet, unit)
    local headline = sheet.headline
    if not headline then return end

    if not mod:Get("showAverageLevel") then
        headline:Hide()
        return
    end

    local total, worn, mainHand, offHandEmpty = 0, 0, nil, false
    for i = 1, #sheet.slots do
        local slot = sheet.slots[i]
        local link = GetInventoryItemLink(unit, slot.id)
        local each = link and itemLevel(unit, slot.id, link)
        if each then
            total = total + each
            worn  = worn + 1
        end
        if slot.name == "MainHandSlot" and link and isTwoHanded(link) then
            mainHand = each
        end
        if slot.name == "SecondaryHandSlot" and not link then offHandEmpty = true end
    end

    if worn == 0 then
        headline:Hide()
        return
    end
    if mainHand and offHandEmpty then total = total + mainHand end

    local level = total / #sheet.slots

    -- Le format du nombre se construit à partir du réglage. Ce n'est pas une
    -- chaîne affichée : il ne dit que la précision, et c'est l'intitulé qui porte
    -- le texte traduisible autour.
    local decimals = mod:Get("levelDecimals") or 0
    headline:SetText(L["Item level headline"]
                     :format(string.format("%." .. decimals .. "f", level)))
    headline:SetTextColor(headlineColor(sheet, unit))
    headline:Show()
end

--- La première ligne de la colonne : le niveau d'objet et le rang d'amélioration,
--- ensemble.
---
--- **Ensemble, et non l'un sur l'icône et l'autre à côté.** Ce sont deux mesures
--- de la même chose — ce que vaut la pièce — et on les compare l'une par l'autre :
--- un 289 au rang 6/6 ne se lit pas comme un 289 au rang 1/8, le second ayant
--- encore de la marge. Séparés, il fallait porter l'œil à deux endroits pour
--- répondre à une seule question.
---
--- **L'ordre s'inverse d'un côté à l'autre.** Le niveau se range toujours contre
--- l'icône, le rang toujours vers l'extérieur : la colonne de gauche lit donc
--- « (6/6) 289 » et celle de droite « 289 (6/6) ». C'est ce qui aligne les
--- niveaux d'objet des deux colonnes contre le modèle, où l'œil les parcourt.
---
--- **La couleur est celle de la piste**, pas de la qualité de l'objet. Toutes les
--- pièces de fin de saison sont épiques : la qualité ne distingue plus rien à ce
--- stade, là où la piste dit exactement d'où vient la pièce. Faute de piste
--- connue, on retombe sur la qualité (voir `T.TrackColor`).
---@param mod table
---@param slot table
---@param unit string
---@param link string
---@return string|nil text
---@return number|nil r, number|nil g, number|nil b
local function levelLine(mod, slot, unit, link)
    local level = mod:Get("showItemLevel") and itemLevel(unit, slot.id, link) or nil
    local rank, _, trackID

    if mod:Get("showUpgradeLevel") then
        rank, _, trackID = upgradeOf(link)
    end

    if not (level or rank) then return nil end

    local text
    if level and rank then
        text = (PLACEMENT[slot.name] == "LEFT")
               and ("(" .. rank .. ") " .. level)
               or  (level .. " (" .. rank .. ")")
    elseif level then
        text = tostring(level)
    else
        text = "(" .. rank .. ")"
    end

    local r, g, b = T.TrackColor(trackID)
    if not r then
        local quality = C_Item and C_Item.GetItemQualityByID
                        and C_Item.GetItemQualityByID(link)
        r, g, b = T.ItemQualityColor(quality)
    end

    return text, r, g, b
end

--- L'icône d'enchantement d'un emplacement : l'étoile de rang que le client
--- affiche lui-même, ou le grimoire éteint quand la pièce n'est pas enchantée.
---@param unit string
---@param slotID integer
---@return BUI.SlotIcon
local function enchantIcon(unit, slotID)
    local enchanted, atlas, label = enchantInfo(unit, slotID)

    if not enchanted then
        return {
            texture     = T.TEXTURE.ENCHANT_NONE,
            desaturated = true,
            title       = L["Enchant badge"],
            hint        = L["No enchant hint"],
        }
    end

    -- L'intitulé du client tel qu'il l'écrit, débarrassé de ses échappements :
    -- c'est le seul texte qui existe pour un enchantement, faute de lien d'objet
    -- à tendre à une infobulle.
    --
    -- **L'icône du métier en repli, et surtout pas une étoile choisie par nous.**
    -- Une étoile posée faute de mieux affirme un rang qu'on n'a pas lu ; le
    -- grimoire dit exactement ce qu'on sait : la pièce est enchantée.
    return {
        title   = L["Enchant badge"],
        hint    = label,
        atlas   = atlas,
        texture = T.TEXTURE.ENCHANT_NONE,
    }
end

--- Ajoute une icône par châsse : la gemme sertie, ou la châsse vide.
---
--- **Une par châsse, et non un compte.** Trois châsses dont une vide se lisent
--- d'un coup d'œil quand on voit deux gemmes et un trou ; un « 2/3 » demande de
--- savoir ce que valent les deux nombres.
---@param info table
---@param link string
local function addGemIcons(info, link)
    local total = sockets(link)
    if total <= 0 then return end

    local readGem = (C_Item and C_Item.GetItemGem) or GetItemGem
    local icons   = (C_Item and C_Item.GetItemIconByID) or GetItemIcon

    for index = 1, total do
        local gemLink = readGem and select(2, readGem(link, index))
        local texture = gemLink and icons and icons(gemLink)

        info:AddIcon({
            texture = texture or T.TEXTURE.EMPTY_SOCKET,

            -- L'infobulle de la gemme quand il y en a une : ce qu'on veut savoir
            -- devant elle est ce qu'elle apporte, et le client le dit mieux que
            -- nous. Devant un trou il n'y a rien à demander au client — c'est à
            -- nous de dire que la châsse est vide.
            link  = gemLink,
            title = not gemLink and L["Empty socket"] or nil,
        })
    end
end
--- Relit un emplacement et repeint son bandeau.
---@param mod table
---@param slot table
---@param unit string
local function updateSlot(mod, slot, unit)
    local info = slot.info
    local link = GetInventoryItemLink(unit, slot.id)

    if not link then
        info:Clear()
        return
    end

    -- Le niveau d'objet ne vit plus **sur** l'icône : il ouvre la colonne, collé
    -- au rang d'amélioration (voir `levelLine`).
    info:SetLevel(nil)

    -- ---- pastilles, à côté de la case ------------------------------------
    -- Une pastille ne se pose que si la question se pose : une pièce sans châsse
    -- n'a pas de gemme manquante, et un emplacement qui n'accepte pas
    -- d'enchantement n'en attend aucun. Une pastille grise « sans objet » ferait
    -- du bruit sur seize lignes.
    info:BeginBadges()

    local text, r, g, b = levelLine(mod, slot, unit, link)
    if text then info:AddBadge(text, r, g, b) end

    info:EndBadges()

    -- ---- rangée d'icônes -------------------------------------------------
    -- L'enchantement d'abord, les gemmes ensuite, sur une seule rangée. Les mots
    -- « Enchantement » et « Gemme » ont vécu ici : ils nommaient la question et
    -- laissaient la couleur y répondre, ce qui obligeait à lire pour savoir de
    -- quoi on parlait. Une étoile de rang et une gemme se reconnaissent sans être
    -- lues, et disent en plus **laquelle** — ce qu'un mot ne disait pas.
    info:BeginIcons()

    if mod:Get("showEnchants") and expectsEnchant(slot.name, link, unit) then
        info:AddIcon(enchantIcon(unit, slot.id))
    end

    if mod:Get("showGems") then addGemIcons(info, link) end

    info:EndIcons()
end

--- Vide les seize bandeaux d'une fiche.
---@param sheet table
local function clearSheet(sheet)
    for i = 1, #sheet.slots do
        sheet.slots[i].info:Clear()
    end
    if sheet.headline then sheet.headline:Hide() end
end

--- Repeint les seize bandeaux d'une fiche.
---@param mod table
---@param sheet table
local function updateAll(mod, sheet)
    if not buildSlots(sheet) then return end

    -- Une fenêtre d'inspection ouverte sur personne : la cible a disparu, ou le
    -- serveur n'a pas encore répondu. On vide plutôt que de laisser en place ce
    -- qu'on avait lu de quelqu'un d'autre — un nombre périmé se croit.
    local unit = sheet.Unit()
    if not unit then
        clearSheet(sheet)
        return
    end

    for i = 1, #sheet.slots do
        BUI.safecall(updateSlot, mod, sheet.slots[i], unit)
    end

    BUI.safecall(paintHeadline, mod, sheet, unit)
end

--- Repeint les fiches ouvertes, et elles seules.
---
--- Le garde sur la visibilité est ce qui rend le reste bon marché : l'équipement
--- change surtout quand la fiche est fermée, et rien de ce qu'on affiche n'a de
--- valeur tant qu'on ne la regarde pas.
local function repaint()
    local mod = BUI.Modules:Get(MODULE)
    if not (mod and mod:IsEnabled()) then return end

    for i = 1, #SHEETS do
        local frame = SHEETS[i].Frame()
        if frame and frame:IsShown() then
            updateAll(mod, SHEETS[i])
        end
    end
end

--- Groupé (règle 7) : équiper une pièce émet coup sur coup
--- `PLAYER_EQUIPMENT_CHANGED` et `UNIT_INVENTORY_CHANGED`, et chacun relit seize
--- objets.
local refresh = U.Debounce(T.TIMING.SLOT_INFO, repaint)

--- Même repeinte, à cadence lâche.
---
--- `GET_ITEM_INFO_RECEIVED` est émis pour **n'importe quel** objet interrogé
--- n'importe où dans l'interface : survoler un sac ou une page d'hôtel des
--- ventes en tire une rafale, et la fiche peut être ouverte pendant ce temps.
--- À la cadence courte, ce seul événement relirait seize objets dix fois par
--- seconde pour ne rien changer. Ici rien ne presse : il ne sert qu'à rattraper
--- des données arrivées en retard.
local refreshLater = U.Debounce(T.TIMING.SLOT_INFO_SETTLE, repaint)

--- Repeinte des conteneurs.
---
--- Elle n'est **pas** conditionnée à la fiche de personnage, contrairement aux
--- deux précédentes : les sacs s'ouvrent seuls, c'est même leur usage courant.
local refreshBags = U.Debounce(T.TIMING.BAG_TAG, function()
    local mod = BUI.Modules:Get(MODULE)
    if not (mod and mod:IsEnabled()) then return end

    updateContainers(mod)
end)

--- Deux passages à l'ouverture de la banque.
---
--- Elle n'est pas remplie quand elle s'annonce : son interface se charge à la
--- demande, son panneau se peuple ensuite, et ses boutons sortent d'un pool qui
--- grandit au fur et à mesure. Un seul passage arrive donc trop tôt, et rien ne
--- prévient une seconde fois. Le retardataire est le filet — c'est le même motif
--- que le mode sombre applique aux cadres qui se rhabillent après coup.
local function refreshBank()
    refreshBags()
    C_Timer.After(T.TIMING.SLOT_INFO_SETTLE, refreshBags)
end

-- =========================================================================
--  Veille sur la banque
-- =========================================================================
-- **Changer d'onglet de banque n'émet aucun signal.** Ni événement, ni appel
-- qu'on puisse intercepter : le client repeuple les mêmes boutons avec le
-- contenu de l'autre onglet, et rien ne l'annonce. Deux tentatives ont échoué —
-- s'abonner à ce qui touche aux sacs (le contenu ne change pas), et s'accrocher
-- à la pose de texture des boutons (ces boutons-là ne passent pas par elle).
--
-- Le symptôme était le pire des trois possibles : non pas une case muette, mais
-- une case portant le **nombre de l'onglet précédent**. Un chiffre faux se croit.
--
-- Faute de signal, on regarde. La veille ne tourne **que pendant que la banque
-- est ouverte**, elle s'arrête d'elle-même à la fermeture, et elle ne fait que
-- redemander la relecture groupée — qui, elle, est déjà limitée par son propre
-- regroupement. C'est le seul endroit de l'addon qui scrute au lieu d'écouter,
-- et ce commentaire est là pour qu'on le remplace le jour où le client publiera
-- de quoi écouter.

local bankTicker

local function stopBankWatch()
    if bankTicker then
        bankTicker:Cancel()
        bankTicker = nil
    end
end

local function startBankWatch()
    if bankTicker then return end

    bankTicker = C_Timer.NewTicker(T.TIMING.BANK_WATCH, function()
        local mod = BUI.Modules:Get(MODULE)
        local wanted = mod and mod:IsEnabled() and mod:Get("showBagItemLevel")

        -- La veille se coupe seule dès qu'elle n'a plus lieu d'être : banque
        -- fermée, réglage décoché, module éteint.
        if not wanted or not (BankFrame and BankFrame:IsShown()) then
            stopBankWatch()
            return
        end

        refreshBags()
    end)
end

--- Montre ou cache tous les bandeaux des deux fiches d'un coup.
---@param shown boolean
local function setShown(shown)
    for i = 1, #SHEETS do
        local sheet = SHEETS[i]
        for j = 1, #sheet.slots do
            sheet.slots[j].info:SetShown(shown)
        end
    end
end

--- Guette l'ouverture d'une fiche.
---
--- C'est le seul moment où ces bandeaux servent, et le seul où l'on soit sûr que
--- ses boutons existent. `U.GuardedScript` ne pose le hook qu'une fois et le rend
--- inerte quand le module s'éteint (règle 6) : appeler cette fonction deux fois
--- sur la même fiche ne coûte rien.
---
--- **Le script `OnShow`, jamais la méthode `Show`.** Accrocher `Show` remplace
--- la méthode du cadre par une fonction à nous ; le client, lui, ouvre sa fiche
--- par `frame:Show()` depuis son gestionnaire de panneaux. Il appelle donc
--- notre fonction, et toute la suite de cet appel — son propre `OnShow`
--- compris — porte notre teinte, même si le corps du hook ne fait rien. Sa
--- fiche lit alors des valeurs secrètes (les points de vie du joueur, affichés
--- en chiffres quand la fiche s'ouvre) et lève « attempt to compare a secret
--- number value ». `OnShow` n'a pas ce défaut : le client tient la main, et nos
--- gestionnaires ne passent qu'après les siens.
---@param sheet table
---@param guard fun(): boolean
local function watchSheet(sheet, guard)
    local frame = sheet.Frame()
    if not frame then return end

    buildSlots(sheet)
    U.GuardedScript(frame, "OnShow", refresh, guard)
end

-- =========================================================================
--  Déclaration du module
-- =========================================================================

BUI:RegisterModule(MODULE, {
    title    = L["Character sheet"],
    category = "Interface",
    order    = 30,

    defaults = {
        showAverageLevel = false,
        levelDecimals    = 1,

        showItemLevel    = false,
        showUpgradeLevel = false,
        showEnchants     = false,
        showGems         = false,

        showBagItemLevel = false,
    },

    options = {
        -- Le niveau d'objet du personnage ouvre la page, avant les seize autres
        -- nombres : c'est le seul qui parle du personnage entier, et c'est celui
        -- qu'on vient chercher en premier sur une fiche.
        { type = "header", text = L["General"] },
        {
            type    = "toggle",
            key     = "showAverageLevel",
            text    = L["Show average item level"],
            tooltip = L["Show average item level tip"],
        },
        {
            type     = "slider",
            key      = "levelDecimals",
            text     = L["Item level decimals"],
            tooltip  = L["Item level decimals tip"],
            min      = 0,
            max      = MAX_LEVEL_DECIMALS,
            step     = 1,
            disabled = function()
                local mod = BUI.Modules:Get(MODULE)
                return not (mod and mod:Get("showAverageLevel"))
            end,
        },

        { type = "header", text = L["Item details"] },
        {
            type    = "toggle",
            key     = "showItemLevel",
            text    = L["Show item level"],
            tooltip = L["Show item level on slots tip"],
        },
        {
            type    = "toggle",
            key     = "showUpgradeLevel",
            text    = L["Show upgrade level"],
            tooltip = L["Show upgrade level tip"],
        },
        {
            type    = "toggle",
            key     = "showEnchants",
            text    = L["Show enchants"],
            tooltip = L["Show enchants tip"],
        },
        {
            type    = "toggle",
            key     = "showGems",
            text    = L["Show gems"],
            tooltip = L["Show gems tip"],
        },

        { type = "header", text = L["Bags and bank"] },
        {
            type    = "toggle",
            key     = "showBagItemLevel",
            text    = L["Show item level in bags"],
            tooltip = L["Show item level in bags tip"],
        },
    },

    --- `/bui fiche` : pourquoi l'icône d'enchantement porte l'image qu'elle porte.
    ---
    --- L'étoile de rang n'est pas une icône qu'on choisit : on la **récupère**
    --- dans la ligne d'infobulle du client, sous la forme `|A:nom:h:l|a`, et la
    --- chaîne est le seul endroit où elle existe (voir `enchantInfo`). Quatre
    --- choses peuvent manquer entre l'infobulle et l'écran, aucune ne lève, et
    --- les quatre donnent le même symptôme — le grimoire du métier à la place de
    --- l'étoile.
    ---
    --- Elles s'écrivent ici dans l'ordre où elles se posent, sur l'unité de la
    --- fenêtre ouverte : la fiche d'inspection si elle est là, la sienne sinon.
    ---
    --- Les noms de fonctions et de champs sont ceux de l'API : ils ne se
    --- traduisent pas.
    DiagnoseSheet = function(self)
        self:Print(L["Sheet diagnostic"])

        -- L'unité de la fenêtre ouverte : celle d'inspection si elle est là, la
        -- sienne sinon. Cherchée par son préfixe et non par son rang dans la
        -- table — `SHEETS` se lit de haut en bas, elle ne se numérote pas.
        local unit = "player"
        for i = 1, #SHEETS do
            local sheet = SHEETS[i]
            local frame = sheet.prefix == "Inspect" and sheet.Frame()
            if frame and frame:IsShown() then unit = sheet.Unit() or unit end
        end
        self:Print("unit:", unit,
            "| C_TooltipInfo.GetInventoryItem:",
            (C_TooltipInfo and C_TooltipInfo.GetInventoryItem) and L["On"] or L["Off"],
            "| ItemEnchantmentPermanent:", tostring(ENCHANT_LINE))

        -- Le premier emplacement enchantable qui porte quelque chose : un seul
        -- suffit à répondre, et seize lignes de chat n'apprendraient rien de
        -- plus. On le nomme, pour que la réponse se rapporte à une pièce.
        for i = 1, #SLOT_NAMES do
            local name   = SLOT_NAMES[i]
            local slotID = slotIDOf(name)
            local link   = slotID and GetInventoryItemLink(unit, slotID)

            if slotID and link and expectsEnchant(name, link, unit) then
                local data = C_TooltipInfo and C_TooltipInfo.GetInventoryItem
                             and C_TooltipInfo.GetInventoryItem(unit, slotID)
                if data and TooltipUtil and TooltipUtil.SurfaceArgs then
                    TooltipUtil.SurfaceArgs(data)
                end

                -- Tous les types de ligne rendus, dans l'ordre, et le texte
                -- **brut** de celle qu'on guette. Le relevé dit si la ligne
                -- d'enchantement est simplement absente ou si elle arrive sous
                -- un autre numéro que le nôtre — deux causes qu'aucun autre
                -- affichage ne distingue.
                local types, raw = {}, nil
                for _, line in ipairs(data and data.lines or {}) do
                    types[#types + 1] = tostring(line.type)
                    if line.type == ENCHANT_LINE then raw = line.leftText end
                end

                self:Print(name, "| data:", data and L["On"] or L["Off"],
                    "| lines:", table.concat(types, ","))

                local _, atlas = enchantInfo(unit, slotID)
                self:Print("enchant line:", raw ~= nil and L["On"] or L["Off"],
                    "| atlas:", tostring(atlas),
                    "| GetAtlasInfo:",
                    (atlas and C_Texture and C_Texture.GetAtlasInfo
                     and C_Texture.GetAtlasInfo(atlas)) and L["On"] or L["Off"])

                -- Le texte **brut**, barres verticales doublées : le chat rend
                -- `||` comme une seule barre littérale, et c'est le seul moyen
                -- de **voir** l'échappement `|A:…|a` au lieu de le laisser se
                -- dessiner en icône. L'intitulé nettoyé ne conviendrait pas —
                -- `plain` retire précisément l'étoile qu'on vient chercher.
                --
                -- Le garde de secret avant toute manipulation : une chaîne
                -- secrète ne s'indexe pas plus qu'elle ne se raconte.
                self:Print("leftText:",
                    U.IsSecret(raw) and L["Refused"]
                    or (type(raw) == "string" and (raw:gsub("|", "||")) or tostring(raw)))
                return
            end
        end

        self:Print(L["No enchantable slot"])
    end,

    OnEnable = function(self)
        local guard = function() return self:IsEnabled() end

        for i = 1, #SHEETS do
            watchSheet(SHEETS[i], guard)
        end
        setShown(true)

        -- La fiche d'inspection vit dans un addon chargé à la demande : elle
        -- n'existe pas encore ici, et la première inspection est aussi le
        -- premier moment où l'on peut lui accrocher quoi que ce soit.
        self:RegisterEvent("ADDON_LOADED", function(_, addonName)
            for i = 1, #SHEETS do
                if SHEETS[i].addon == addonName then
                    watchSheet(SHEETS[i], guard)
                    setShown(true)
                    refresh()
                end
            end
        end)

        -- L'équipement d'un autre joueur est une réponse du serveur : il n'y a
        -- rien à lire avant, et tout à relire après. Le client suit par ailleurs
        -- la cible pendant que la fenêtre reste ouverte — il repeuple les mêmes
        -- emplacements avec quelqu'un d'autre, et sans ce rattrapage les
        -- bandeaux gardent l'équipement du précédent jusqu'à la réponse.
        --
        -- Les deux sont conditionnés à la fenêtre d'inspection, et pas seulement
        -- au regroupement : `INSPECT_READY` tombe pour l'inspection de
        -- n'importe qui, la nôtre comme celle d'un autre addon, et changer de
        -- cible n'a aucune raison de faire relire les seize pièces du joueur.
        local onInspect = function()
            if InspectFrame and InspectFrame:IsShown() then refresh() end
        end
        self:RegisterEvent("INSPECT_READY",         onInspect)
        self:RegisterEvent("PLAYER_TARGET_CHANGED", onInspect)

        self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", refresh)
        self:RegisterEvent("PLAYER_ENTERING_WORLD",    refresh)
        self:RegisterEvent("SOCKET_INFO_UPDATE",       refresh)

        -- **Le niveau d'objet moyen ne suit pas l'équipement, il le suit d'un
        -- cran derrière.** Au changement de pièce, `GetAverageItemLevel` rend
        -- encore l'ancienne valeur : le client recalcule et prévient ensuite. La
        -- fiche repeinte sur le seul `PLAYER_EQUIPMENT_CHANGED` réaffichait donc
        -- le nombre d'avant, et il fallait la fermer et la rouvrir pour le voir
        -- bouger — ce qui donnait l'impression qu'elle ne se mettait jamais à
        -- jour, alors que les seize pièces, elles, étaient bien à jour.
        self:RegisterEvent("PLAYER_AVG_ITEM_LEVEL_UPDATE", refresh)

        -- Un objet dont les données ne sont pas encore descendues du serveur rend
        -- un lien sans gemme et sans qualité. Le client prévient quand elles
        -- arrivent ; sans cet abonnement, les pastilles fausses le restent
        -- jusqu'à la prochaine ouverture de la fiche.
        self:RegisterEvent("GET_ITEM_INFO_RECEIVED",   refreshLater)

        -- L'unité inspectée aussi : elle change d'équipement sous nos yeux, et
        -- c'est le seul signal qui le dise pendant que la fenêtre reste ouverte.
        self:RegisterEvent("UNIT_INVENTORY_CHANGED", function(_, unit)
            if unit == "player" or unit == (InspectFrame and InspectFrame.unit) then
                refresh()
            end
        end)

        -- Conteneurs. `BAG_UPDATE_DELAYED` est le regroupé du client : il tombe
        -- une fois quand la rafale de `BAG_UPDATE` est retombée, ce qui est
        -- exactement ce qu'on veut d'un tri ou d'un vidage de sacoche.
        self:RegisterEvent("BAG_UPDATE_DELAYED",          refreshBags)
        self:RegisterEvent("BANKFRAME_OPENED", function()
            refreshBank()
            startBankWatch()
        end)
        self:RegisterEvent("BANKFRAME_CLOSED", stopBankWatch)
        self:RegisterEvent("PLAYERBANKSLOTS_CHANGED",     refreshBags)
        -- Les emplacements de **sacs** de banque ont eu leur propre événement, que
        -- la refonte de la banque a retiré : le client le refuse maintenant, et le
        -- core l'écrit dans le chat à chaque connexion. On le demande donc au
        -- client avant de s'y abonner — test de capacité, jamais de numéro de
        -- patch (règle 1). `PLAYERBANKSLOTS_CHANGED`, lui, couvre déjà le cas sur
        -- un client où celui-ci n'existe plus.
        if not C_EventUtils or not C_EventUtils.IsEventValid
           or C_EventUtils.IsEventValid("PLAYERBANKBAGSLOTS_CHANGED") then
            self:RegisterEvent("PLAYERBANKBAGSLOTS_CHANGED", refreshBags)
        end
        self:RegisterEvent("ITEM_LOCK_CHANGED",           refreshBags)
        self:RegisterEvent("GET_ITEM_INFO_RECEIVED",      refreshBags)

        -- Ouvrir un sac ne change rien à son contenu : aucun événement ne
        -- l'annonce. Ces quatre fonctions sont les seules portes d'entrée, et
        -- `U.GuardedHook` les rend inertes quand le module s'éteint (règle 6).
        local BAG_TOGGLES ={ "ToggleBackpack", "ToggleBag", "ToggleAllBags", "OpenAllBags" }
        for i = 1, #BAG_TOGGLES do
            if type(_G[BAG_TOGGLES[i]]) == "function" then
                U.GuardedHook(BAG_TOGGLES[i], refreshBags, guard)
            end
        end

        refresh()
        refreshBags()
    end,

    -- Rien ne se détruit — aucune frame ne se détruit dans ce jeu —, tout se
    -- cache. La fiche et les sacs redeviennent ceux du client, au pixel près.
    OnDisable = function()
        setShown(false)
        W.ClearItemLevelTags()
        -- Le niveau d'objet du personnage, en tête de fiche. Il a sa propre
        -- fabrique et son propre effacement : `setShown` ne couvre que les
        -- bandeaux des emplacements, et l'oublier ici laissait un nombre posé
        -- sur la fiche d'un module éteint (règle 6).
        W.ClearSheetItemLevels()
        stopBankWatch()
    end,

    OnSettingChanged = function()
        refresh()
        refreshBags()
    end,
})
