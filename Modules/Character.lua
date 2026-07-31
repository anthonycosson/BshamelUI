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
local SLOT_NAMES = {
    "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot",
    "WristSlot", "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot",
    "Finger0Slot", "Finger1Slot", "Trinket0Slot", "Trinket1Slot",
    "MainHandSlot", "SecondaryHandSlot",
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
local ENCHANTABLE = {
    HeadSlot          = true,
    ShoulderSlot      = true,
    ChestSlot         = true,
    LegsSlot          = true,
    FeetSlot          = true,
    Finger0Slot       = true,
    Finger1Slot       = true,
    MainHandSlot      = true,
    SecondaryHandSlot = true,
}

--- Emplacements qui acceptent un noyau du vide : les armes et les bijoux.
local VOID_SLOTS = {
    Trinket0Slot      = true,
    Trinket1Slot      = true,
    MainHandSlot      = true,
    SecondaryHandSlot = true,
}

--- Où poser la colonne de pastilles de chaque emplacement : du côté opposé au
--- modèle, et au-dessus pour les armes, qui n'ont pas de côté libre.
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

    MainHandSlot = "ABOVE", SecondaryHandSlot = "ABOVE",
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

---@param slotName string
---@param link string
---@return boolean
local function expectsEnchant(slotName, link)
    if not ENCHANTABLE[slotName] then return false end
    if slotName == "SecondaryHandSlot" then return isWeapon(link) end
    return true
end

---@param slotName string
---@param link string
---@return boolean
local function expectsVoidCore(slotName, link)
    if not VOID_SLOTS[slotName] then return false end
    if slotName == "SecondaryHandSlot" then return isWeapon(link) end
    return true
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

--- Retire les échappements de couleur d'une ligne d'infobulle.
---@param value string
---@return string
local function plain(value)
    value = value:gsub("|cn.-:(.-)|r", "%1")   -- couleurs nommées, forme récente
    value = value:gsub("|c%x%x%x%x%x%x%x%x", "")
    return (value:gsub("|r", ""))
end

--- La pièce porte-t-elle un noyau du vide ?
---
--- Le noyau ne se lit **ni dans le lien de l'objet, ni dans ses statistiques** :
--- il se manifeste par un effet nommé, que seule l'infobulle publie. On y
--- cherche donc son intitulé, `L["Void core marker"]`, en ignorant la casse et
--- les échappements de couleur.
---
--- C'est le seul endroit du module où une **chaîne traduite décide** d'un
--- affichage, et c'est un défaut assumé faute de mieux : il n'existe aucun
--- identifiant stable exposé côté objet. La conséquence est qu'une locale sans
--- intitulé juste montre l'emplacement en rouge à tort — d'où la clé isolée, à
--- corriger en un seul endroit.
---
--- `C_TooltipInfo` et non une infobulle cachée : il rend des **données**, donc
--- sans créer la moindre frame.
---@param slotID integer
---@return boolean
local function hasVoidCore(slotID)
    if not (C_TooltipInfo and C_TooltipInfo.GetInventoryItem) then return false end

    local data = C_TooltipInfo.GetInventoryItem("player", slotID)
    if not data then return false end

    -- Les champs d'une ligne ne sont peuplés qu'après ce passage : sans lui,
    -- `line.leftText` est absent et la boucle ne trouve jamais rien.
    if TooltipUtil and TooltipUtil.SurfaceArgs then TooltipUtil.SurfaceArgs(data) end

    local marker = strlower(L["Void core marker"])

    for _, line in ipairs(data.lines or {}) do
        local text = line.leftText
        if text and strfind(strlower(plain(text)), marker, 1, true) then
            return true
        end
    end

    return false
end

-- =========================================================================
--  Niveau d'objet et amélioration
-- =========================================================================

--- Identifiant d'enchantement porté par un lien d'objet, ou `nil`.
--- Le lien s'écrit `item:<objet>:<enchantement>:…`, et le champ est vide — pas
--- absent — quand il n'y a pas d'enchantement.
---@param link string
---@return integer|nil
local function enchantOf(link)
    local id = tonumber(link:match("item:%d+:(%d*)"))
    if id == 0 then return nil end
    return id
end

--- Niveau d'objet réel de la pièce équipée.
---
--- Par l'emplacement et non par le lien : c'est le seul chemin qui tienne compte
--- de la mise à l'échelle. Un objet de bas niveau monté par une affinité ou une
--- pièce de raid mise à l'échelle affiche sinon le niveau écrit dans son lien,
--- qui n'est pas celui que le personnage porte.
---@param slotID integer
---@return integer|nil
local function itemLevel(slotID)
    if not (ItemLocation and C_Item and C_Item.GetCurrentItemLevel) then return nil end

    local location = ItemLocation:CreateFromEquipmentSlot(slotID)
    if not (location and C_Item.DoesItemExist and C_Item.DoesItemExist(location)) then return nil end

    return C_Item.GetCurrentItemLevel(location)
end

--- Rang d'amélioration, sous la forme « 6/8 ».
---@param link string
---@return string|nil text
---@return boolean maxed
local function upgradeOf(link)
    if not (C_Item and C_Item.GetItemUpgradeInfo) then return nil, false end

    local info = C_Item.GetItemUpgradeInfo(link)
    if not info then return nil, false end

    local current, max = info.currentLevel, info.maxLevel
    if not (current and max and max > 0) then return nil, false end

    return current .. "/" .. max, current >= max
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

--- { id, name, info } pour chaque emplacement, construit une fois.
local slots = {}

--- Construit une colonne par emplacement. Rend `false` tant que la fiche du
--- client n'est pas là — elle peut être chargée à la demande.
---
--- La position se pose ici, une fois pour toutes : elle ne dépend que du nom de
--- l'emplacement, donc d'aucune mesure, donc d'aucun moment.
---@return boolean
local function buildSlots()
    if #slots > 0 then return true end
    if not (CharacterFrame and GetInventorySlotInfo) then return false end

    for i = 1, #SLOT_NAMES do
        local name   = SLOT_NAMES[i]
        local button = _G["Character" .. name]
        local slotID = GetInventorySlotInfo(name)

        if button and slotID then
            local info = W.SlotInfo(button)
            if info then
                info:SetPlacement(PLACEMENT[name] or "RIGHT")
                slots[#slots + 1] = { id = slotID, name = name, info = info }
            end
        end
    end

    return #slots > 0
end

--- Relit un emplacement et repeint son bandeau.
---@param mod table
---@param slot table
local function updateSlot(mod, slot)
    local info = slot.info
    local link = GetInventoryItemLink("player", slot.id)

    if not link then
        info:Clear()
        return
    end

    -- ---- niveau d'objet, sur l'icône -------------------------------------
    if mod:Get("showItemLevel") then
        local level = itemLevel(slot.id)
        if level then
            local quality = C_Item and C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(link)
            info:SetLevel(tostring(level), T.ItemQualityColor(quality))
        else
            info:SetLevel(nil)
        end
    else
        info:SetLevel(nil)
    end

    -- ---- pastilles, à côté de la case ------------------------------------
    -- Une pastille ne se pose que si la question se pose : une pièce sans châsse
    -- n'a pas de gemme manquante, et un emplacement qui n'accepte pas
    -- d'enchantement n'en attend aucun. Une pastille grise « sans objet » ferait
    -- du bruit sur seize lignes.
    info:BeginBadges()

    if mod:Get("showUpgradeLevel") then
        local text, maxed = upgradeOf(link)
        if text then
            info:AddBadge(text, T.UpgradeColor(maxed, mod:Get("warnPartialUpgrade")))
        end
    end

    if mod:Get("showEnchants") and expectsEnchant(slot.name, link) then
        info:AddBadge(L["Enchant badge"], T.StatusColor(enchantOf(link) ~= nil))
    end

    if mod:Get("showGems") then
        local total, filled = sockets(link)
        if total > 0 then
            info:AddBadge(L["Gem badge"], T.StatusColor(filled >= total))
        end
    end

    if mod:Get("showVoidCore") and expectsVoidCore(slot.name, link) then
        info:AddBadge(L["Void core badge"], T.StatusColor(hasVoidCore(slot.id)))
    end

    info:EndBadges()
end

--- Repeint les seize bandeaux.
---@param mod table
local function updateAll(mod)
    if not buildSlots() then return end

    for i = 1, #slots do
        BUI.safecall(updateSlot, mod, slots[i])
    end
end

--- Repeint, mais seulement si la fiche est ouverte.
---
--- Le garde sur la visibilité est ce qui rend le reste bon marché : l'équipement
--- change surtout quand la fiche est fermée, et rien de ce qu'on affiche n'a de
--- valeur tant qu'on ne la regarde pas.
local function repaint()
    local mod = BUI.Modules:Get(MODULE)
    if not (mod and mod:IsEnabled()) then return end
    if not (CharacterFrame and CharacterFrame:IsShown()) then return end

    updateAll(mod)
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

--- Montre ou cache tous les bandeaux d'un coup.
---@param shown boolean
local function setShown(shown)
    for i = 1, #slots do
        slots[i].info:SetShown(shown)
    end
end

-- =========================================================================
--  Déclaration du module
-- =========================================================================

BUI:RegisterModule(MODULE, {
    title    = L["Character sheet"],
    category = "Game",
    order    = 20,

    defaults = {
        showItemLevel    = false,
        showUpgradeLevel = false,
        showEnchants     = false,
        showGems         = false,
        showVoidCore     = false,

        -- Coché d'avance, contrairement aux cinq réglages ci-dessus : il ne
        -- décide pas d'un affichage mais de la teinte de l'un d'eux. Allumer le
        -- rang d'amélioration doit donc distinguer tout de suite ce qui est fini
        -- de ce qui ne l'est pas — décocher ensuite est le geste rare.
        warnPartialUpgrade = true,

        showBagItemLevel = false,
    },

    options = {
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
            type     = "toggle",
            key      = "warnPartialUpgrade",
            text     = L["Warn partial upgrade"],
            tooltip  = L["Warn partial upgrade tip"],
            -- Sans rang affiché, il n'y a rien à teindre.
            disabled = function()
                local mod = BUI.Modules:Get(MODULE)
                return not (mod and mod:Get("showUpgradeLevel"))
            end,
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
        {
            type    = "toggle",
            key     = "showVoidCore",
            text    = L["Show void core"],
            tooltip = L["Show void core tip"],
        },

        { type = "header", text = L["Bags and bank"] },
        {
            type    = "toggle",
            key     = "showBagItemLevel",
            text    = L["Show item level in bags"],
            tooltip = L["Show item level in bags tip"],
        },
    },

    OnEnable = function(self)
        if buildSlots() then setShown(true) end

        -- La fiche s'ouvre : c'est le seul moment où ces bandeaux servent, et le
        -- seul où l'on peut mesurer de quel côté les poser.
        if CharacterFrame then
            U.GuardedHook(CharacterFrame, "Show", refresh, function()
                return self:IsEnabled()
            end)
        end

        self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", refresh)
        self:RegisterEvent("PLAYER_ENTERING_WORLD",    refresh)
        self:RegisterEvent("SOCKET_INFO_UPDATE",       refresh)

        -- Un objet dont les données ne sont pas encore descendues du serveur rend
        -- un lien sans gemme et sans qualité. Le client prévient quand elles
        -- arrivent ; sans cet abonnement, les pastilles fausses le restent
        -- jusqu'à la prochaine ouverture de la fiche.
        self:RegisterEvent("GET_ITEM_INFO_RECEIVED",   refreshLater)

        self:RegisterEvent("UNIT_INVENTORY_CHANGED", function(_, unit)
            if unit == "player" then refresh() end
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
        self:RegisterEvent("PLAYERBANKBAGSLOTS_CHANGED",  refreshBags)
        self:RegisterEvent("ITEM_LOCK_CHANGED",           refreshBags)
        self:RegisterEvent("GET_ITEM_INFO_RECEIVED",      refreshBags)

        -- Ouvrir un sac ne change rien à son contenu : aucun événement ne
        -- l'annonce. Ces quatre fonctions sont les seules portes d'entrée, et
        -- `U.GuardedHook` les rend inertes quand le module s'éteint (règle 6).
        local guard = function() return self:IsEnabled() end
        local BAG_TOGGLES = { "ToggleBackpack", "ToggleBag", "ToggleAllBags", "OpenAllBags" }
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
        stopBankWatch()
    end,

    OnSettingChanged = function()
        refresh()
        refreshBags()
    end,
})
