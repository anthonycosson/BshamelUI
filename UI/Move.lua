-- =========================================================================
--  Bshamel UI — UI/Move.lua
--  Moteur de déplacement des fenêtres du client, et de leur mise à l'échelle.
--
--  Ce fichier décide *quoi* déplacer et *où le reposer*. Les frames dont il a
--  besoin lui sont fournies par `UI/Widgets/Mover.lua`, seul endroit autorisé à
--  en créer (CLAUDE.md règle 2). Il ne lit ni n'écrit aucun réglage : le module
--  `Modules/Windows.lua` lui passe un *hôte* qui sait le faire (`M:SetHost`).
--  Un moteur qui écrirait en base serait un module déguisé.
--
--  ---------------------------------------------------------------------
--  Trois décisions structurent tout le reste.
--  ---------------------------------------------------------------------
--
--  **1. Une position est un décalage de centre à centre, jamais un ancrage.**
--  On ne relit pas l'ancrage que le client avait posé, on ne le rejoue pas non
--  plus : on mémorise de combien le *centre* de la fenêtre s'écarte du centre de
--  `UIParent`, et on repose toujours en `CENTER`/`CENTER`. Cela vaut trois
--  choses d'un coup : le chemin protégé et le chemin ordinaire deviennent
--  identiques, un changement d'échelle se rattrape par une simple division, et
--  aucun ancrage relatif à un cadre tiers ne vient nous surprendre.
--
--  **2. On ne rend jamais un cadre du client déplaçable.**
--  `SetMovable` / `StartMoving` sont des écritures d'état d'entrée : sur un
--  cadre protégé, elles *taintent* son arbre — l'erreur tombe plus tard, sur une
--  comparaison de valeur secrète, sans rien qui la relie à nous. On suit donc le
--  curseur nous-mêmes et on repose la fenêtre à chaque image. C'est le chemin
--  qu'un cadre protégé imposait de toute façon ; l'utiliser pour *tous* les
--  cadres supprime la moitié du code et, surtout, ne laisse rien à défaire à
--  l'extinction (règle 6).
--
--  **3. Le client repositionne ses fenêtres tout seul.**
--  Son gestionnaire de panneaux réancre les cadres à l'ouverture, au changement
--  d'onglet, à l'apparition d'un panneau voisin. Une position posée une fois ne
--  tient pas : elle doit être **réimposée** depuis un hook sur `SetPoint`.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local U    = BUI.Util
local W    = BUI.Widgets
local L    = ns.L

local M = {}
BUI.Move = M

-- =========================================================================
--  Bornes de l'échelle
-- =========================================================================
-- Ce ne sont pas des valeurs de thème : elles ne décrivent aucune apparence,
-- elles bornent un réglage. Même statut que `min` / `max` sur un slider.

local SCALE_MIN  = 0.5
local SCALE_MAX  = 2.0
local SCALE_STEP = 0.05

--- Modificateur qui arme la molette. Fixe, et distinct du modificateur de
--- déplacement, qui se règle : les deux gestes ne se marchent pas dessus (l'un
--- est un glisser, l'autre une molette), et « Ctrl pour redimensionner » est la
--- convention à laquelle le joueur s'attend.
local SCALE_MODIFIER = "CTRL"

-- =========================================================================
--  Registre des fenêtres
-- =========================================================================
-- Des **noms globaux**, résolus à chaque tentative de branchement. Un nom absent
-- ne coûte rien : c'est la forme que prend ici la règle « test de capacité,
-- jamais de numéro de patch » (règle 1). Une fenêtre retirée à une extension
-- disparaît d'elle-même, une fenêtre pas encore chargée sera reprise plus tard.

--- Fenêtres présentes dès la connexion.
---
--- `GameMenuFrame` n'y est **pas**, et l'omission est délibérée : le module
--- Général sait déjà le mettre à l'échelle (`compactGameMenu`). Deux moteurs sur
--- la même frame se contrediraient à chaque ouverture.
---
--- Les sacs n'y sont pas non plus, et c'est pour une autre raison : ils ne sont
--- pas des fenêtres indépendantes mais une **pile**, que le client redispose en
--- entier à chaque ouverture. Une ligne de plus ici les épinglerait chacun au
--- même endroit. Ils ont leur propre section, plus bas.
local PRELOADED = {
    "CharacterFrame",
    "FriendsFrame",
    "PVEFrame",
    "DressUpFrame",
    "BankFrame",
    "MailFrame",
    "GossipFrame",
    "QuestFrame",
    "QuestLogPopupDetailFrame",
    "MerchantFrame",
    "TradeFrame",
    "LootFrame",
    "AddonList",
    "ChatConfigFrame",
    "ItemTextFrame",
    "GuildInviteFrame",
    "GuildRegistrarFrame",
    "TabardFrame",
    "PetStableFrame",
    "ReadyCheckFrame",
    "StackSplitFrame",
    "LFGDungeonReadyDialog",
}

--- Fenêtres chargées à la demande, par l'addon de Blizzard qui les apporte.
local ON_DEMAND = {
    ["Blizzard_AchievementUI"]      = { "AchievementFrame" },
    ["Blizzard_ArchaeologyUI"]      = { "ArchaeologyFrame" },
    ["Blizzard_AuctionHouseUI"]     = { "AuctionHouseFrame" },
    ["Blizzard_BlackMarketUI"]      = { "BlackMarketFrame" },
    ["Blizzard_Calendar"]           = { "CalendarFrame" },
    ["Blizzard_ChallengesUI"]       = { "ChallengesKeystoneFrame" },
    ["Blizzard_Collections"]        = { "CollectionsJournal", "WardrobeFrame" },
    ["Blizzard_Communities"]        = { "CommunitiesFrame" },
    ["Blizzard_EncounterJournal"]   = { "EncounterJournal" },
    ["Blizzard_FlightMap"]          = { "FlightMapFrame" },
    ["Blizzard_GenericTraitUI"]     = { "GenericTraitFrame" },
    -- La recherche de groupe de *Forever* : une autre fenêtre que `PVEFrame`,
    -- apportée par un addon chargé à la demande. Sur retail, ce nom d'addon
    -- n'arrive jamais, la ligne ne coûte donc rien.
    ["Blizzard_GroupFinder_VanillaStyle"] = { "LFGParentFrame" },
    ["Blizzard_GuildBankUI"]        = { "GuildBankFrame" },
    ["Blizzard_InspectUI"]          = { "InspectFrame" },
    ["Blizzard_ItemInteractionUI"]  = { "ItemInteractionFrame" },
    ["Blizzard_ItemSocketingUI"]    = { "ItemSocketingFrame" },
    ["Blizzard_ItemUpgradeUI"]      = { "ItemUpgradeFrame" },
    ["Blizzard_MacroUI"]            = { "MacroFrame" },
    ["Blizzard_MajorFactions"]      = { "MajorFactionRenownFrame" },
    ["Blizzard_PlayerSpells"]       = { "PlayerSpellsFrame" },
    ["Blizzard_Professions"]        = { "ProfessionsFrame" },
    ["Blizzard_ProfessionsBook"]    = { "ProfessionsBookFrame" },
    ["Blizzard_ScrappingMachineUI"] = { "ScrappingMachineFrame" },
    ["Blizzard_StableUI"]           = { "StableFrame" },
    ["Blizzard_TokenUI"]            = { "CurrencyTransferMenu" },
    ["Blizzard_TradeSkillUI"]       = { "TradeSkillFrame" },
    ["Blizzard_TrainerUI"]          = { "ClassTrainerFrame" },
    ["Blizzard_Transmog"]           = { "TransmogFrame" },
    ["Blizzard_WeeklyRewards"]      = { "WeeklyRewardsFrame" },
    ["Blizzard_WorldMap"]           = { "WorldMapFrame" },

    ["Blizzard_ProfessionsCustomerOrders"]         = { "ProfessionsCustomerOrdersFrame" },
    ["Blizzard_DelvesCompanionConfigurationFrame"] = { "DelvesCompanionConfigurationFrame" },
    ["Blizzard_DelvesDifficultyPicker"]            = { "DelvesDifficultyPickerFrame" },

    -- Logement (Midnight). Absents d'un client plus ancien, donc jamais résolus.
    ["Blizzard_HousingDashboard"]   = { "HousingDashboardFrame" },
    ["Blizzard_HousingHouseFinder"] = { "HouseFinderFrame" },
}

--- Fenêtres dont le corps est cliquable, et qui se prennent donc par un enfant.
---
--- La carte du monde se déplace au glisser et zoome à la molette : un glisser
--- posé sur son corps ferait les deux à la fois. On la prend par sa barre de
--- titre, comme le fait le client lui-même.
--- Une entrée vaut un nom, ou plusieurs.
---
--- La recherche de groupe de *Forever* est le cas à plusieurs : ses trois
--- pages — recherche, annonce, liste des joueurs — sont des cadres à part,
--- posés sur toute la fenêtre (`setAllPoints`) et **preneurs de souris**. La
--- fenêtre elle-même ne reçoit donc jamais un clic, alors que la molette, qui
--- passe par « le curseur est-il au-dessus ? », fonctionnait très bien : d'où
--- une fenêtre qu'on pouvait redimensionner sans pouvoir la déplacer.
local DRAG_HANDLES = {
    WorldMapFrame  = "WorldMapTitleButton",
    LFGParentFrame = { "LFGListingFrame", "LFGBrowseFrame", "LFGWhoListFrame" },
}

--- Fenêtres qui possèdent, en plus de leur mode fenêtre, une disposition
--- **plein écran** pilotée par le client. La carte du monde agrandie remplit
--- l'écran : sa taille se calcule dans les unités de son parent — un calcul
--- juste seulement à l'échelle d'origine — et son ancrage vient du
--- gestionnaire de panneaux. Réimposer notre position la décale, notre
--- échelle la fait déborder : dans les deux cas elle sort de l'écran, donc
--- tronquée aux bords.
---
--- Tant que `active` répond vrai, le moteur ne touche à rien. Les deux
--- méthodes sont crochetées pour les deux transitions : `enter` rend au cadre
--- son échelle d'origine — la disposition du client se calcule pour elle —,
--- `leave` repose ce qui est mémorisé, car le client ne repasse pas par
--- `OnShow` en revenant au mode fenêtre. Tests de capacité partout : un cadre
--- sans ces méthodes n'a simplement pas de plein écran.
local FULLSCREEN_MODES = {
    WorldMapFrame = {
        active = function(frame)
            return frame.IsMaximized ~= nil and frame:IsMaximized() == true
        end,
        enter = "Maximize",
        leave = "Minimize",
    },
}

--- La disposition plein écran du client est-elle en vigueur sur ce cadre ?
---@param entry table
---@param frame table
---@return boolean
local function fullscreenNow(entry, frame)
    local mode = entry.mode
    return mode ~= nil and mode.active(frame) == true
end

-- =========================================================================
--  Hôte
-- =========================================================================

---@class BUI.MoveHost
---@field CanMove fun(): boolean
---@field CanScale fun(): boolean
---@field Modifier fun(): string            "NONE" | "SHIFT" | "CTRL" | "ALT"
---@field GetPosition fun(name: string): table|nil
---@field SetPosition fun(name: string, x: number|nil, y: number|nil)
---@field GetScale fun(name: string): number|nil
---@field SetScale fun(name: string, scale: number|nil)
---@field PlaceLoot fun(): boolean          l'emplacement du butin est-il à nous ?
---@field LootLocked fun(): boolean         l'aperçu refuse-t-il le glisser ?
---@field LootPreview fun(): boolean        l'aperçu est-il demandé ?

---@type BUI.MoveHost|nil
local host

--- Branche le moteur sur le module qui détient les réglages. `nil` l'éteint :
--- tous les hooks posés deviennent inertes à la ligne suivante.
---@param newHost BUI.MoveHost|nil
function M:SetHost(newHost)
    host = newHost
end

--- Le moteur est-il branché ? Sert de garde à tous les hooks (règle 6).
---@return boolean
function M:IsActive()
    return host ~= nil
end

-- =========================================================================
--  État par cadre
-- =========================================================================

--- cadre -> { name, points, scale }
---
--- `points` et `scale` sont l'état **d'origine**, relevé juste avant qu'on
--- touche au cadre pour la première fois. C'est ce qui permet à `Restore` de
--- rendre la fenêtre indétectable de notre passage (règle 6).
local state = {}

--- ordre de branchement, pour retrouver la fenêtre survolée
local hooked = {}

--- Vrai pendant nos propres écritures de position, pour que le hook posé sur
--- `SetPoint` ne se rappelle pas lui-même.
local applying = false

-- =========================================================================
--  Outils
-- =========================================================================

--- Un cadre interdit lève à la moindre sollicitation : on ne le touche jamais.
---@param frame table|nil
---@return boolean
local function usable(frame)
    if not frame or type(frame.GetCenter) ~= "function" then return false end
    if frame.IsForbidden and frame:IsForbidden() then return false end
    return true
end

--- Un cadre protégé se repositionne par l'environnement restreint, et pas du
--- tout en combat.
---@param frame table
---@return boolean
local function protectedNow(frame)
    return frame.IsProtected ~= nil and frame:IsProtected() == true
end

--- Décalage du centre de `frame` par rapport au centre de `UIParent`, exprimé en
--- pixels d'écran — donc indépendant de toute échelle.
---@param frame table
---@return number|nil x, number|nil y
local function screenOffset(frame)
    local fcx, fcy = frame:GetCenter()
    local ucx, ucy = UIParent:GetCenter()
    if not (fcx and ucx) then return nil, nil end

    local es  = frame:GetEffectiveScale()
    local ues = UIParent:GetEffectiveScale()
    if not (es and ues) then return nil, nil end

    return fcx * es - ucx * ues, fcy * es - ucy * ues
end

-- =========================================================================
--  Écriture de la position et de l'échelle
-- =========================================================================

--- Relève l'état d'origine d'un cadre, une seule fois.
---
--- Au moment du relevé, le cadre porte l'ancrage que le client lui a donné :
--- c'est exactement ce qu'il faudra reposer. Le relevé est donc **différé**
--- jusqu'à la première écriture, et non fait au branchement — un cadre pas
--- encore affiché n'a pas toujours d'ancrage.
---@param frame table
---@param entry table
local function captureOrigin(frame, entry)
    -- Une capture **vide** n'en est pas une : le cadre n'était pas encore ancré
    -- au moment où on l'a lue. Le cas est réel — le gestionnaire de panneaux du
    -- client affiche certaines fenêtres avant de les ancrer, si bien qu'un relevé
    -- fait sur `OnShow` peut tomber trop tôt. On la refait au passage suivant
    -- plutôt que de graver « ce cadre n'a rien à rendre ».
    if entry.points and #entry.points > 0 then return end

    -- L'échelle, elle, ne se relève qu'une fois : au deuxième passage on l'aura
    -- peut-être déjà changée, et on mémoriserait la nôtre comme étant la sienne.
    if entry.scale == nil then entry.scale = frame:GetScale() or 1 end

    local points = {}
    for i = 1, (frame:GetNumPoints() or 0) do
        local point, relativeTo, relPoint, x, y = frame:GetPoint(i)
        if point then
            points[#points + 1] = {
                point      = point,
                relativeTo = relativeTo or frame:GetParent() or UIParent,
                relPoint   = relPoint or point,
                x          = x or 0,
                y          = y or 0,
            }
        end
    end

    entry.points = points
end

--- Ancre un cadre, quel qu'il soit.
---
--- `applying` est levé **ici** et pas chez l'appelant : toute écriture de
--- position du fichier passe par cette fonction, c'est donc le seul endroit où
--- la garde ne peut pas être oubliée. Sans elle, notre propre écriture
--- réveillerait le hook posé sur `SetPoint`, qui réécrirait par-dessus.
---@param frame table
---@param point string
---@param relative table
---@param relPoint string
---@param x number
---@param y number
---@return boolean applied
local function anchor(frame, point, relative, relPoint, x, y)
    applying = true

    local ok
    if protectedNow(frame) then
        local secure = W.SecureMover()
        ok = secure ~= nil and secure:Place(frame, point, relative, relPoint, x, y)
    else
        frame:ClearAllPoints()
        frame:SetPoint(point, relative, relPoint, x, y)
        ok = true
    end

    applying = false
    return ok
end

--- Pose le cadre à `x, y` du centre de l'écran.
---@param frame table
---@param x number
---@param y number
---@return boolean applied
local function place(frame, x, y)
    return anchor(frame, "CENTER", UIParent, "CENTER", x, y)
end

--- Même garde que `anchor`, pour la même raison : le client remet certaines
--- fenêtres à l'échelle tout seul, on a donc un hook sur `SetScale` aussi.
---@param frame table
---@param scale number
---@return boolean applied
local function rescale(frame, scale)
    applying = true

    local ok
    if protectedNow(frame) then
        local secure = W.SecureMover()
        ok = secure ~= nil and secure:Rescale(frame, scale)
    else
        frame:SetScale(scale)
        ok = true
    end

    applying = false
    return ok
end

--- Applique à un cadre ce que la base dit de lui : d'abord l'échelle, puis la
--- position.
---
--- L'ordre n'est pas indifférent. Un décalage est mémorisé en unités **locales**
--- du cadre, donc sa traduction en pixels dépend de l'échelle en vigueur :
--- poser la position avant l'échelle la ferait glisser d'autant.
---@param frame table
---@param entry table
local function applyStored(frame, entry)
    if not host then return end
    if fullscreenNow(entry, frame) then return end
    if protectedNow(frame) and InCombatLockdown() then return end

    local scale = host.GetScale(entry.name)
    local pos   = host.GetPosition(entry.name)
    if not (scale or pos) then return end

    captureOrigin(frame, entry)

    if scale then rescale(frame, scale) end
    if pos then place(frame, pos.x, pos.y) end
end

--- Cadres dont la repose est déjà programmée : cadre -> vrai. Le client appelle
--- `SetPoint` plusieurs fois par ouverture, et une repose suffit.
local scheduled = {}

--- Repose le cadre **à l'image suivante**, jamais dans l'appel du client.
---
--- Deux raisons, et la première suffirait. Le client réancre ses fenêtres
--- plusieurs fois par ouverture : reposer à chaque `SetPoint` fait autant de
--- reposes que d'ancrages, dont une seule sert — celle d'après.
---
--- La seconde tient à la teinte. Nos hooks s'exécutent *à l'intérieur* de
--- l'appel qu'ils coiffent, et déplacer une fenêtre depuis là, c'est faire
--- passer le travail du client par du code d'addon. Une image plus tard,
--- l'exécution n'appartient qu'à nous et ne prête plus à conséquence. La
--- fenêtre paraît une image à la place que le client lui donnait : invisible,
--- et c'est le prix de ne pas se mêler de son ouverture.
---@param frame table
---@param entry table
local function applySoon(frame, entry)
    if not host then return end
    if scheduled[frame] then return end

    scheduled[frame] = true
    C_Timer.After(0, function()
        scheduled[frame] = nil
        if host then applyStored(frame, entry) end
    end)
end

--- Rend un cadre à l'état où on l'a trouvé.
---
--- Le chemin protégé ne repose que le **premier** ancrage : l'environnement
--- restreint en pose un par exécution, et aucune fenêtre rencontrée n'en portait
--- plusieurs. Une fenêtre qui en aurait plusieurs retrouverait donc sa place
--- sans retrouver ses attaches — le client la réancre de toute façon à sa
--- prochaine ouverture.
---@param frame table
---@param entry table
local function restoreOrigin(frame, entry)
    local points = entry.points
    if not points then return end

    -- En plein écran, la disposition à l'écran est déjà celle du client, et
    -- l'échelle d'origine lui a été rendue en y entrant : reposer les ancrages
    -- mémorisés — ceux du mode fenêtre — la déplacerait. Il n'y a rien à
    -- défaire ; le client reposera lui-même son mode fenêtre à la sortie.
    if fullscreenNow(entry, frame) then
        entry.points = nil
        entry.scale  = nil
        return
    end

    if protectedNow(frame) and InCombatLockdown() then return end

    if entry.scale then rescale(frame, entry.scale) end

    if #points == 0 then
        -- Rien n'avait été relevé : le cadre n'était pas encore ancré quand on
        -- l'a pris. Le laisser sans ancrage le ferait disparaître ; on le remet
        -- au centre, d'où le client le déplacera à sa prochaine ouverture.
        place(frame, 0, 0)
        entry.points = nil
        entry.scale  = nil
        return
    end

    local first = points[1]
    anchor(frame, first.point, first.relativeTo, first.relPoint, first.x, first.y)

    -- Les ancrages suivants s'ajoutent au premier, sans le remplacer : ils ne
    -- passent donc pas par `anchor`, qui commence par tout effacer.
    if not protectedNow(frame) then
        applying = true
        for i = 2, #points do
            local p = points[i]
            frame:SetPoint(p.point, p.relativeTo, p.relPoint, p.x, p.y)
        end
        applying = false
    end

    entry.points = nil
    entry.scale  = nil
end

-- =========================================================================
--  Glisser
-- =========================================================================

--- Table de travail unique, réutilisée d'un glisser à l'autre (règle 7).
local drag = {}

local dragTicker

--- Renseignées par la section « sacs », plus bas. Le glisser doit savoir
--- déplacer une pile, et la pile a besoin du glisser : l'un des deux doit être
--- annoncé avant l'autre.
local placeBagsAt, bagCornerScreen

--- Le geste demandé est-il fait ?
---@return boolean
local function gestureHeld()
    if not host then return false end
    local modifier = host.Modifier()
    if modifier == "NONE" then return true end
    return U.IsModifierHeld(modifier)
end

local function stopDrag()
    if dragTicker then dragTicker:Hide() end

    local frame = drag.frame
    if not frame then return end
    drag.frame = nil
    drag.bags  = nil

    -- On n'écrit le réglage qu'ici, et pas à chaque image : un message de
    -- changement par image inonderait tout ce qui écoute la base.
    if host and drag.x then
        host.SetPosition(drag.name, drag.x, drag.y)
    end
end

--- Suit le curseur. Cadencée par `T.TIMING.DRAG`, comme le bouton de minicarte.
local function followCursor()
    local frame = drag.frame
    if not frame then
        if dragTicker then dragTicker:Hide() end
        return
    end

    -- Le bouton a pu être relâché hors du cadre, où l'`OnMouseUp` ne nous
    -- parvient pas. C'est ce test-là, et non l'événement, qui termine le geste.
    if not IsMouseButtonDown("LeftButton") then
        stopDrag()
        return
    end

    if protectedNow(frame) and InCombatLockdown() then
        stopDrag()
        return
    end

    local cx, cy = GetCursorPosition()
    local ucx, ucy = UIParent:GetCenter()
    local es  = frame:GetEffectiveScale()
    local ues = UIParent:GetEffectiveScale()
    if not (cx and ucx and es and es > 0 and ues) then return end

    local sx = drag.startX + (cx - drag.cursorX)
    local sy = drag.startY + (cy - drag.cursorY)

    -- Le centre reste à l'écran. On ne se sert pas de `SetClampedToScreen` : ce
    -- serait une écriture d'état de plus sur un cadre du client, à défaire
    -- ensuite, pour un résultat qu'une borne donne aussi bien.
    sx = U.Clamp(sx, 0, GetScreenWidth() * ues)
    sy = U.Clamp(sy, 0, GetScreenHeight() * ues)

    -- Une pile de sacs se mesure en unités de l'écran et non de l'un de ses
    -- cadres : ce qu'on suit est son coin, qui n'appartient à aucun d'eux.
    local unit = drag.bags and ues or es

    drag.x = (sx - ucx * ues) / unit
    drag.y = (sy - ucy * ues) / unit

    if drag.bags then
        placeBagsAt(drag.x, drag.y)
    else
        place(frame, drag.x, drag.y)
    end
end

---@param frame table
---@param entry table
local function startDrag(frame, entry)
    if fullscreenNow(entry, frame) then return end
    if protectedNow(frame) and InCombatLockdown() then return end

    -- Le point suivi n'est pas le même selon ce qu'on tient. Une fenêtre est
    -- suivie par son centre ; une pile de sacs par son **coin bas-droit**, celui
    -- que le client lui-même prend pour appui — c'est le seul repère qui ne
    -- bouge pas quand on ouvre ou ferme un sac de plus.
    local startX, startY
    if entry.bags then
        startX, startY = bagCornerScreen()
    else
        local fcx, fcy = frame:GetCenter()
        local es = frame:GetEffectiveScale()
        if fcx and es then startX, startY = fcx * es, fcy * es end
    end
    if not startX then return end

    -- Pas de relevé d'origine pour une pile : ce n'est pas un ancrage qu'on lui
    -- rendra, c'est la disposition du client qu'on laissera reprendre la main.
    if not entry.bags then captureOrigin(frame, entry) end

    drag.frame   = frame
    drag.name    = entry.name
    drag.bags    = entry.bags
    drag.x, drag.y = nil, nil
    drag.cursorX, drag.cursorY = GetCursorPosition()
    drag.startX, drag.startY   = startX, startY

    if not dragTicker then
        dragTicker = W.Ticker(T.TIMING.DRAG, followCursor)
    end
    dragTicker:Show()
end

-- =========================================================================
--  Molette
-- =========================================================================

local catcher
local hoverTicker

--- Applique un cran de molette à une fenêtre.
---
--- La fenêtre ne doit pas bouger de l'écran : mettre à l'échelle la fait grandir
--- depuis son ancrage, donc son centre se déplace. On relève ce centre **avant**
--- en pixels d'écran, et on le retraduit **après** dans les unités de la
--- nouvelle échelle. Un cadre jamais déplacé se voit ainsi attribuer une
--- position à l'instant où on le redimensionne : sans elle, le gestionnaire de
--- panneaux du client le rassoirait à sa place d'origine au prochain recalcul,
--- et la fenêtre sauterait sans raison visible.
---@param frame table
---@param delta number
local function stepScale(frame, delta)
    local entry = state[frame]
    if not (host and entry) then return end
    if fullscreenNow(entry, frame) then return end
    if protectedNow(frame) and InCombatLockdown() then return end

    local current = host.GetScale(entry.name) or frame:GetScale() or 1
    local target  = U.Clamp(U.Round(current + SCALE_STEP * delta, 2), SCALE_MIN, SCALE_MAX)
    if target == current then return end

    captureOrigin(frame, entry)

    local sx, sy = screenOffset(frame)
    if not rescale(frame, target) then return end
    host.SetScale(entry.name, target)

    if sx then
        local es = frame:GetEffectiveScale()
        if es and es > 0 then
            host.SetPosition(entry.name, sx / es, sy / es)
        end
    end

    local pos = host.GetPosition(entry.name)
    if pos then place(frame, pos.x, pos.y) end
end

--- Première fenêtre branchée, visible, sous le curseur.
---@return table|nil
local function frameUnderCursor()
    for i = 1, #hooked do
        local frame = hooked[i]
        if usable(frame) and frame:IsVisible() and frame:IsMouseOver() then
            return frame
        end
    end
    return nil
end

--- Arme ou désarme le capteur de molette selon ce qui est survolé.
---
--- Sondé plutôt que branché sur un événement, et c'est voulu : le modificateur
--- peut être pressé *avant* que le curseur n'arrive sur la fenêtre. Le sondage
--- ne tourne que pendant que le modificateur est tenu, et il s'arrête tout seul.
local function updateWheelTarget()
    if not (host and host.CanScale() and U.IsModifierHeld(SCALE_MODIFIER)) then
        if catcher then catcher:Park() end
        if hoverTicker then hoverTicker:Hide() end
        return
    end

    if not catcher then
        catcher = W.WheelCatcher(function(target, delta) stepScale(target, delta) end)
    end

    local frame = frameUnderCursor()
    if frame then catcher:Cover(frame) else catcher:Park() end
end

--- À appeler sur `MODIFIER_STATE_CHANGED`.
function M:OnModifierChanged()
    if not (host and host.CanScale()) then
        updateWheelTarget()
        return
    end

    if U.IsModifierHeld(SCALE_MODIFIER) then
        if not hoverTicker then
            hoverTicker = W.Ticker(T.TIMING.HOVER, updateWheelTarget)
        end
        hoverTicker:Show()
    end
    updateWheelTarget()
end

-- =========================================================================
--  Branchement d'un cadre
-- =========================================================================

--- Pose sur `target` les deux scripts qui commencent et terminent un glisser.
---
--- `HookScript` et non `SetScript` : on ne remplace pas le comportement du
--- client, on s'ajoute derrière lui. Et on n'appelle **jamais** `EnableMouse` —
--- une fenêtre qui ne reçoit pas la souris ne sera pas déplaçable, ce qui vaut
--- mieux que de tainter son arbre pour la rendre telle.
---@param target table
---@param frame table
---@param entry table
local function attachDrag(target, frame, entry)
    if not (target and type(target.HookScript) == "function") then return end

    target:HookScript("OnMouseDown", function(_, button)
        if not (host and host.CanMove()) then return end
        if button ~= "LeftButton" then return end
        if not gestureHeld() then return end
        startDrag(frame, entry)
    end)

    target:HookScript("OnMouseUp", function(_, button)
        if button ~= "LeftButton" then return end
        if drag.frame == frame then stopDrag() end
    end)
end

--- Branche une fenêtre. Idempotent : rebrancher un cadre déjà connu ne fait rien.
---@param frame table
---@param name string
local function hookFrame(frame, name)
    if state[frame] then return end
    if not usable(frame) then return end

    local entry = { name = name }
    state[frame] = entry
    hooked[#hooked + 1] = frame

    attachDrag(frame, frame, entry)

    local handles = DRAG_HANDLES[name]
    if type(handles) == "string" then
        attachDrag(_G[handles], frame, entry)
    elseif type(handles) == "table" then
        for i = 1, #handles do
            attachDrag(_G[handles[i]], frame, entry)
        end
    end

    -- Les deux bascules du plein écran, quand le cadre en a un. À l'entrée,
    -- l'échelle d'origine est rendue **après** que le client a calculé sa
    -- disposition : elle a été calculée pour cette échelle-là, jamais pour la
    -- nôtre. À la sortie, ce qui est mémorisé se repose — le client ne
    -- repasse pas par `OnShow`, et sa bascule ne touche pas à l'échelle.
    local mode = FULLSCREEN_MODES[name]
    if mode then
        entry.mode = mode

        if type(frame[mode.enter]) == "function" then
            U.GuardedHook(frame, mode.enter, function()
                if not host then return end
                if entry.scale
                   and math.abs((frame:GetScale() or 1) - entry.scale) >= 0.001 then
                    rescale(frame, entry.scale)
                end
            end, function() return M:IsActive() end)
        end

        if type(frame[mode.leave]) == "function" then
            U.GuardedHook(frame, mode.leave, function()
                if not host then return end
                applyStored(frame, entry)
            end, function() return M:IsActive() end)
        end
    end

    -- Le client réancre ses fenêtres à l'ouverture : c'est ici qu'on repose la
    -- nôtre, et pas seulement au démarrage.
    frame:HookScript("OnShow", function()
        applySoon(frame, entry)
    end)

    frame:HookScript("OnHide", function()
        if drag.frame == frame then stopDrag() end
    end)

    -- Réimposition. `U.GuardedHook` est le seul motif de hook autorisé (règle 6) :
    -- posé une fois, rendu inerte quand le module s'éteint.
    U.GuardedHook(frame, "SetPoint", function()
        if applying then return end
        if drag.frame == frame then return end       -- ne pas se battre avec le glisser
        if not host then return end
        if fullscreenNow(entry, frame) then return end

        if not host.GetPosition(name) then return end
        applySoon(frame, entry)
    end, function() return M:IsActive() end)

    -- Même raison pour l'échelle : certaines fenêtres se remettent à l'échelle
    -- toutes seules sur un changement d'état, sans passer par un cycle
    -- masquer/afficher qui aurait rejoué `OnShow`.
    U.GuardedHook(frame, "SetScale", function()
        if applying then return end
        if not host then return end
        if fullscreenNow(entry, frame) then return end

        local scale = host.GetScale(name)
        if not scale then return end
        if math.abs((frame:GetScale() or 1) - scale) < 0.001 then return end

        applySoon(frame, entry)
    end, function() return M:IsActive() end)

    if frame:IsVisible() then applyStored(frame, entry) end
end

---@param name string
local function tryHook(name)
    hookFrame(_G[name], name)
end

-- =========================================================================
--  Les sacs : une pile, et non des fenêtres
-- =========================================================================
-- Les sacs ne passent pas par `hookFrame`, et c'est le sujet entier de cette
-- section.
--
-- **Ce ne sont pas des fenêtres indépendantes.** Le client les dispose en pile
-- depuis le coin bas-droit de l'écran, chacune ancrée à `UIParent` avec un
-- décalage qu'il recalcule à chaque ouverture, fermeture, ou changement de
-- réglage de sacs. Épingler chaque cadre séparément les empilerait tous au même
-- endroit : ce qu'on déplace est la **pile**, et un seul réglage la décrit.
--
-- **On ne refait pas sa disposition, on la translate.** Après chaque passe du
-- client, tous les cadres portent une disposition cohérente ; il suffit de
-- mesurer l'écart entre le coin qu'il a choisi et celui que le joueur veut, et
-- de décaler tout le monde d'autant. Rien de la mise en page n'est réécrit —
-- nombre de colonnes, sens de remplissage, sacs combinés ou non : tout continue
-- de venir de lui, et une prochaine extension qui la change ne casse rien.
--
-- **On se branche sur la passe, pas sur les cadres.** C'est la raison pour
-- laquelle les sacs n'ont jamais pu marcher avec le hook sur `SetPoint` des
-- autres fenêtres : celui-ci se déclenche cadre par cadre, donc *au milieu* de
-- la disposition, quand la moitié de la pile est encore à l'ancienne place. Le
-- décalage y serait mesuré sur un état incohérent. On attend donc la fin de la
-- passe, une seule fois, et on décale.
--
-- **Le coin et non le centre.** Une pile change de taille dès qu'on ouvre un sac
-- de plus ; son centre bouge alors, son coin bas-droit non. C'est aussi l'appui
-- que le client prend lui-même.
--
-- Ce qui n'est **pas** fait : la molette. Les écarts entre sacs sont calculés
-- par le client pour leur taille d'origine ; agrandir les cadres sans agrandir
-- les écarts les ferait se chevaucher, et recalculer les écarts serait refaire
-- sa disposition — exactement ce que cette section évite. Les sacs se déplacent,
-- ils ne se redimensionnent pas.

--- Clé de la pile dans les réglages. Une seule pour tous les cadres.
local BAGS_NAME = "Bags"

--- Fonction de disposition du client. Le nom est un test de capacité comme un
--- autre : absente, les sacs ne sont simplement pas déplaçables.
local BAG_LAYOUT_FUNC = "UpdateContainerFrameAnchors"

--- Cadre unique du mode « sacs combinés ». Quand il est affiché, c'est lui la
--- pile entière.
local COMBINED_BAGS = "ContainerFrameCombinedBags"

--- Repli quand le client ne publie pas son propre compte. Une borne, pas une
--- liste : un numéro qui n'existe pas rend `nil` et ne coûte rien.
local BAG_FRAMES_MAX = 13

--- Table de travail : la pile est relue à chaque passe de disposition (règle 7).
local bags = {}

--- Cadres de la pile actuellement affichés.
---@return table[]
local function bagFrames()
    wipe(bags)

    local combined = _G[COMBINED_BAGS]
    if usable(combined) and combined:IsShown() then
        bags[1] = combined
        return bags
    end

    local count = NUM_CONTAINER_FRAMES or BAG_FRAMES_MAX
    for i = 1, count do
        local frame = _G["ContainerFrame" .. i]
        if usable(frame) and frame:IsShown() then
            bags[#bags + 1] = frame
        end
    end
    return bags
end

--- Coin bas-droit de la pile, en pixels d'écran absolus.
--- `nil` quand aucun sac n'est ouvert : il n'y a alors pas de pile.
---@return number|nil right, number|nil bottom
function bagCornerScreen()
    local frames = bagFrames()
    local right, bottom

    for i = 1, #frames do
        local frame = frames[i]
        local es = frame:GetEffectiveScale()
        local r, b = frame:GetRight(), frame:GetBottom()

        if es and r and b then
            r, b = r * es, b * es
            if not right or r > right then right = r end
            if not bottom or b < bottom then bottom = b end
        end
    end

    return right, bottom
end

--- Le coin, exprimé comme les autres positions : un décalage depuis le centre de
--- `UIParent`, dans ses unités à lui.
---@return number|nil x, number|nil y
local function bagCornerOffset()
    local right, bottom = bagCornerScreen()
    if not right then return nil, nil end

    local ucx, ucy = UIParent:GetCenter()
    local ues = UIParent:GetEffectiveScale()
    if not (ucx and ues and ues > 0) then return nil, nil end

    return (right - ucx * ues) / ues, (bottom - ucy * ues) / ues
end

--- Décale toute la pile pour que son coin tombe sur `x, y`.
---
--- Idempotente : rappelée sans que le client ait redisposé, l'écart est nul et
--- rien ne bouge.
---@param x number
---@param y number
function placeBagsAt(x, y)
    local cx, cy = bagCornerOffset()
    if not cx then return end

    local ues = UIParent:GetEffectiveScale()
    if not (ues and ues > 0) then return end

    local dx, dy = (x - cx) * ues, (y - cy) * ues
    if dx == 0 and dy == 0 then return end

    local frames = bagFrames()
    for i = 1, #frames do
        local frame = frames[i]
        local es = frame:GetEffectiveScale()
        local sx, sy = screenOffset(frame)

        if sx and es and es > 0 then
            place(frame, (sx + dx) / es, (sy + dy) / es)
        end
    end
end

--- Où le **client** avait posé chaque sac, en unités du cadre. C'est ce qu'on
--- lui rendra : on ne rappelle pas sa fonction de disposition pour cela, car
--- l'appeler depuis notre code tainterait l'arbre des sacs, qui portent des
--- boutons sécurisés.
---
--- Tables réutilisées d'une passe à l'autre (règle 7).
local bagOrigin = {}

--- Relève la disposition du client.
---@param fresh boolean  vrai quand le client vient d'écrire, donc que ce qu'on
---                      lit est bien de lui et non de nous
local function captureBagLayout(fresh)
    if not fresh and next(bagOrigin) then return end

    local frames = bagFrames()
    for i = 1, #frames do
        local frame = frames[i]
        local es = frame:GetEffectiveScale()
        local sx, sy = screenOffset(frame)

        if sx and es and es > 0 then
            local origin = bagOrigin[frame] or {}
            origin.x, origin.y = sx / es, sy / es
            bagOrigin[frame] = origin
        end
    end
end

--- Repose la pile là où le joueur l'a mise.
local function applyBags()
    if not host then return end

    local pos = host.GetPosition(BAGS_NAME)
    if not pos then return end
    if drag.bags then return end            -- ne pas se battre avec le glisser

    captureBagLayout(false)
    placeBagsAt(pos.x, pos.y)
end

--- Fin d'une passe de disposition du client : ce que portent les cadres est le
--- sien, on le relève avant de le décaler.
local function onBagLayout()
    captureBagLayout(true)
    applyBags()
end

--- Pièces du haut d'un sac par lesquelles on doit pouvoir le prendre.
---
--- La barre de titre d'un sac **prend la souris pour elle** : un clic dessus
--- n'atteint jamais l'`OnMouseDown` du cadre parent, si bien que le seul endroit
--- où le glisser répondait était le fond de la grille — c'est-à-dire partout sauf
--- là où l'on est tenté de saisir une fenêtre.
---
--- Même remède que la carte du monde (`DRAG_HANDLES`) : on branche aussi le
--- glisser sur l'enfant qui intercepte. Les noms sont des tests de capacité, un
--- champ absent est simplement sauté.
local BAG_HANDLES = { "TitleContainer", "PortraitContainer", "TopTileStreaks" }

--- Branche la pile. Idempotent : `U.GuardedHook` ne pose jamais deux fois le
--- même hook, et `attachDrag` est repoussé par `bagsHooked`.
local bagsHooked = {}

local function hookBags()
    -- La disposition d'abord : sans elle, un glisser poserait la pile une fois
    -- et le client la reprendrait à la première ouverture de sac.
    U.GuardedHook(BAG_LAYOUT_FUNC, onBagLayout, function() return M:IsActive() end)

    local count = NUM_CONTAINER_FRAMES or BAG_FRAMES_MAX
    for i = 0, count do
        local name  = (i == 0) and COMBINED_BAGS or ("ContainerFrame" .. i)
        local frame = _G[name]

        if usable(frame) and not bagsHooked[frame] then
            bagsHooked[frame] = true

            -- Une seule entrée d'état pour toute la pile : c'est le même réglage
            -- qu'on écrit, quel que soit le sac qu'on a attrapé.
            local entry = { name = BAGS_NAME, bags = true }
            state[frame] = entry
            attachDrag(frame, frame, entry)

            for h = 1, #BAG_HANDLES do
                attachDrag(frame[BAG_HANDLES[h]], frame, entry)
            end

            frame:HookScript("OnHide", function()
                if drag.frame == frame then stopDrag() end
            end)
        end
    end
end

--- Rend chaque sac là où le client l'avait posé, sans rien effacer en base.
local function restoreBags()
    for frame, origin in pairs(bagOrigin) do
        if usable(frame) and frame:IsShown() then
            BUI.safecall(place, frame, origin.x, origin.y)
        end
    end
    wipe(bagOrigin)
end

-- =========================================================================
--  La fenêtre de jet de butin : un cadre qu'on n'a pas le temps d'attraper
-- =========================================================================
-- Elle ne passe pas par `hookFrame`, et trois choses l'en écartent.
--
-- **On ne peut pas la prendre au glisser.** Une fenêtre du client s'ouvre et
-- attend qu'on en ait fini ; celle-ci dure le temps d'un jet, arrive sans
-- prévenir et repart. Le geste « tenir un modificateur et glisser » suppose
-- qu'on ait le loisir de viser, et ici on ne l'a pas. D'où un **aperçu** : un
-- cadre à nous, de la taille exacte d'un jet, qu'on pose à froid et qui ne sert
-- qu'à cela.
--
-- **Le client la range dans une colonne, il ne l'ancre pas.** Elle est *gérée*
-- — un conteneur de disposition l'empile au-dessus des barres d'action chaque
-- fois qu'elle s'affiche, et un ancrage posé par-dessus ne tiendrait pas une
-- image. Le client a prévu la sortie : un cadre qui porte
-- `ignoreFramePositionManager` n'est pas pris en charge. On la pose plutôt que
-- de lutter, et le hook sur `SetPoint` couvre le reste, comme pour les fenêtres.
--
-- **Elle grandit d'un cran par jet.** Le conteneur réserve une hauteur fixe par
-- jet et empile les cadres depuis son **bas**. Ancré par son centre — ce que
-- font toutes les autres fenêtres de ce fichier —, le premier jet descendrait à
-- l'arrivée du deuxième. On l'ancre donc par le bas, et la pile monte comme
-- elle monte chez le client. Ce qui est rangé en base reste un décalage de
-- centre à centre, mais c'est celui du **premier jet**, pas celui du
-- conteneur : c'est ce cadre-là que le joueur a sous les yeux, et c'est lui que
-- l'aperçu représente.
--
-- Effet de bord assumé : tant qu'un jet est affiché, le client enchaîne ses
-- annonces de butin au-dessus de cette fenêtre. Les déplacer n'est pas demandé,
-- mais elles suivent pendant ces quelques secondes.

--- Nom de la fenêtre de jet dans les réglages. Comme la pile de sacs : une
--- position, rangée avec celles des fenêtres.
local LOOT_NAME = "LootRoll"

--- Le conteneur du client, par son nom global — résolu à chaque fois, comme le
--- reste du registre. Un client qui ne l'a pas ignore simplement la section.
local LOOT_FRAME = "GroupLootContainer"

--- Hauteur que le client réserve à un jet. Elle se lit sur le cadre
--- (`reservedSize`) ; ce nombre n'est que le repli du jour où la clé changerait
--- de nom, et il vaut ce que le client réserve aujourd'hui.
local LOOT_SLOT = 100

--- État d'origine du conteneur, de la même forme que celui des fenêtres : c'est
--- lui qui permet de le rendre tel qu'on l'a trouvé (règle 6).
local lootEntry = { name = LOOT_NAME }

--- L'aperçu, bâti au premier besoin et jamais détruit (règle 7).
local lootPanel

local lootHooked    = false
local lootScheduled = false

---@return table|nil
local function lootContainer()
    local frame = _G[LOOT_FRAME]
    if not usable(frame) then return nil end
    return frame
end

--- Position demandée pour le **premier jet**, ou `nil` quand l'emplacement
--- reste celui du client.
---@return table|nil pos
---@return number|nil scale
local function lootWanted()
    if not host then return nil, nil end
    if host.PlaceLoot() ~= true then return nil, nil end
    return host.GetPosition(LOOT_NAME), host.GetScale(LOOT_NAME)
end

--- Pose le conteneur pour que le premier jet tombe sur la position rangée, à
--- la taille rangée.
---
--- **Les deux sont indépendants.** Un joueur peut tirer le coin de l'aperçu
--- sans l'avoir déplacé : il y a alors une échelle et pas de position, et le
--- cadre doit quand même changer de taille là où le client l'a mis.
local function applyLoot()
    local frame = lootContainer()
    if not frame then return end

    local pos, scale = lootWanted()
    if not (pos or scale) then return end

    captureOrigin(frame, lootEntry)

    -- **L'échelle avant la position**, comme pour les fenêtres (voir
    -- `applyStored`) : un décalage d'ancrage s'exprime dans l'échelle du cadre
    -- ancré, et le poser d'abord le ferait glisser d'autant.
    if scale then rescale(frame, scale) end
    if not pos then return end

    -- Posé ici et non au branchement : tant que le joueur n'a pas déplacé quoi
    -- que ce soit, l'emplacement reste entièrement au client.
    frame.ignoreFramePositionManager = true

    local slot = tonumber(frame.reservedSize) or LOOT_SLOT

    -- **Et la conversion, qui n'est pas celle des fenêtres.** Ce qui est rangé
    -- ici vient de l'aperçu, qui est un `W.Panel` : il écrit en unités de
    -- `UIParent`, pas dans les siennes. On applique donc le même facteur que
    -- `W.Panel:ApplyPosition`, faute de quoi le conteneur agrandi irait deux
    -- fois moins loin que l'aperçu qu'on vient de poser.
    --
    -- La hauteur réservée, elle, appartient au conteneur : elle est déjà dans
    -- la bonne échelle et ne se convertit pas.
    local factor = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
    anchor(frame, "BOTTOM", UIParent, "CENTER",
        pos.x * factor, pos.y * factor - slot / 2)
end

--- Repose à l'image suivante, jamais dans l'appel du client. Mêmes deux raisons
--- que `applySoon` pour les fenêtres, qui les explique.
local function applyLootSoon()
    if lootScheduled then return end

    lootScheduled = true
    C_Timer.After(0, function()
        lootScheduled = false
        if host then BUI.safecall(applyLoot) end
    end)
end

--- Branche le conteneur. Idempotent : rebrancher ne fait rien.
local function hookLoot()
    if lootHooked then return end

    local frame = lootContainer()
    if not frame then return end
    lootHooked = true

    frame:HookScript("OnShow", applyLootSoon)

    U.GuardedHook(frame, "SetPoint", function()
        if applying then return end
        local pos = lootWanted()
        if not pos then return end
        applyLootSoon()
    end, function() return M:IsActive() end)
end

--- Rend le conteneur au client : sa prise en charge d'abord, son ancrage
--- ensuite. L'ordre compte — tant que le drapeau est posé, le conteneur de
--- disposition passe son tour et l'ancrage rendu resterait seul à décider.
local function restoreLoot()
    local frame = lootContainer()
    if not frame then return end

    frame.ignoreFramePositionManager = nil
    BUI.safecall(restoreOrigin, frame, lootEntry)
end

--- L'aperçu. Il ne connaît pas la base : il rend et reçoit un décalage de centre
--- à centre, et c'est l'hôte qui le range.
---@return table|nil
local function lootPreview()
    if lootPanel then return lootPanel end

    lootPanel = W.Panel({
        width  = T.SIZE.LOOT_PREVIEW_W,
        height = T.SIZE.LOOT_PREVIEW_H,
        title  = L["Loot roll"],
        -- La vraie fenêtre vit dans cette strate : un aperçu qui se glisserait
        -- sous ce qu'elle recouvrira ne dirait pas la vérité sur la place
        -- qu'on lui choisit.
        strata = "DIALOG",

        isLocked = function() return host ~= nil and host.LootLocked() == true end,

        getPos = function()
            local pos = host and host.GetPosition(LOOT_NAME)
            if not pos then return 0, 0 end
            return pos.x, pos.y
        end,

        setPos = function(x, y)
            if not host then return end
            host.SetPosition(LOOT_NAME, x, y)
            BUI.safecall(applyLoot)
        end,

        -- **La poignée d'échelle retaille la vraie fenêtre, pas l'aperçu.**
        -- Les deux portent la même échelle, prise au même endroit : c'est ce
        -- qui garde l'aperçu honnête — il occupe la place que la fenêtre
        -- occupera, quelle que soit la taille qu'on lui donne.
        --
        -- Les mêmes bornes que la molette des fenêtres du client, et pour la
        -- même raison : une fenêtre de jet n'a pas à se régler autrement que
        -- les autres.
        minScale = SCALE_MIN,
        maxScale = SCALE_MAX,

        getScale = function()
            return (host and host.GetScale(LOOT_NAME)) or 1
        end,

        setScale = function(scale)
            if not host then return end
            host.SetScale(LOOT_NAME, scale)
            BUI.safecall(applyLoot)
        end,
    })

    return lootPanel
end

--- Montre ou cache l'aperçu.
local function applyLootPreview()
    local wanted = host ~= nil
                   and host.PlaceLoot() == true
                   and host.LootPreview() == true

    if not wanted then
        if lootPanel then lootPanel:Hide() end
        return
    end

    local panel = lootPreview()
    if not panel then return end

    -- L'échelle d'abord, la position en découle (voir `W.Panel:ApplyScale`).
    panel:ApplyScale()
    panel:ApplyLock()
    panel:Show()
end

--- Branchement, pose et aperçu de la fenêtre de jet. À rappeler à chaque
--- changement de réglage qui la concerne.
function M:RefreshLoot()
    hookLoot()

    local pos, scale = lootWanted()
    if pos or scale then
        BUI.safecall(applyLoot)
    else
        BUI.safecall(restoreLoot)
    end

    BUI.safecall(applyLootPreview)
end

--- Branche les fenêtres qu'un addon de Blizzard vient d'apporter.
--- À appeler sur `ADDON_LOADED`.
---@param addonName string
function M:OnAddonLoaded(addonName)
    -- Les cadres de sacs sont là dès la connexion, mais rebrancher ne coûte rien
    -- et couvre un client qui en créerait un de plus en cours de session.
    hookBags()

    local frames = ON_DEMAND[addonName]
    if not frames then return end
    for i = 1, #frames do tryHook(frames[i]) end
end

-- =========================================================================
--  Cycle de vie
-- =========================================================================

--- Branche tout ce qui est déjà là et applique ce que la base dit.
--- Rappelable sans dommage : chaque étape est idempotente.
function M:Start()
    for i = 1, #PRELOADED do
        tryHook(PRELOADED[i])
    end

    for addonName, frames in pairs(ON_DEMAND) do
        if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(addonName) then
            for i = 1, #frames do tryHook(frames[i]) end
        end
    end

    hookBags()

    self:Refresh()
end

--- Repose sur chaque fenêtre visible ce que la base dit d'elle. À rappeler après
--- un changement de profil, ou à la sortie d'un combat qui avait tout différé.
function M:Refresh()
    if not host then return end
    for i = 1, #hooked do
        local frame = hooked[i]
        local entry = state[frame]
        if entry and usable(frame) and frame:IsVisible() then
            BUI.safecall(applyStored, frame, entry)
        end
    end

    -- La pile de sacs n'est pas dans `hooked` : elle ne se repose pas cadre par
    -- cadre, mais d'un seul geste (voir la section « sacs »).
    BUI.safecall(applyBags)

    -- La fenêtre de jet non plus : elle s'ancre par le bas et porte son aperçu.
    self:RefreshLoot()
end

--- Rend toutes les fenêtres à leur état d'origine et range les frames de
--- travail. Les hooks restent posés mais deviennent inertes : leur garde
--- interroge `M:IsActive()`, qui devient faux dès que l'hôte est retiré.
---
--- N'efface **pas** les positions enregistrées : rallumer le module doit
--- retrouver la disposition du joueur. C'est `M:ResetAll` qui les efface.
---
--- L'hôte est retiré **en dernier**, par cette fonction et non par l'appelant :
--- rendre les fenêtres puis débrancher est le seul ordre correct, autant qu'il
--- ne soit pas à retenir.
function M:Stop()
    stopDrag()
    if catcher then catcher:Park() end
    if hoverTicker then hoverTicker:Hide() end

    for i = 1, #hooked do
        local frame = hooked[i]
        local entry = state[frame]
        if entry and usable(frame) then
            BUI.safecall(restoreOrigin, frame, entry)
        end
    end

    host = nil

    -- **Après** le débranchement, et l'ordre est l'inverse de celui des autres
    -- fenêtres. Rendre la pile, c'est faire redisposer le client ; tant que
    -- l'hôte est là, notre propre hook sur sa disposition la reprendrait aussitôt.
    restoreBags()

    -- La fenêtre de jet, pour la même raison : rendre sa prise en charge au
    -- client pendant que le hook sur `SetPoint` est encore vivant reviendrait à
    -- la lui reprendre dans la foulée.
    if lootPanel then lootPanel:Hide() end
    BUI.safecall(restoreLoot)
end

--- Rend toutes les fenêtres **et** efface ce que la base sait d'elles.
---
--- La base est vidée **avant** la restitution, et l'ordre compte : tant qu'une
--- position y figure, le hook posé sur `SetPoint` la réimpose, et il défait la
--- restitution à mesure qu'on la fait.
function M:ResetAll()
    stopDrag()

    if host then
        for i = 1, #hooked do
            local entry = state[hooked[i]]
            if entry then
                host.SetPosition(entry.name, nil, nil)
                host.SetScale(entry.name, nil)
            end
        end
        host.SetPosition(BAGS_NAME, nil, nil)
        host.SetPosition(LOOT_NAME, nil, nil)
        host.SetScale(LOOT_NAME, nil)
    end

    for i = 1, #hooked do
        local frame = hooked[i]
        local entry = state[frame]
        if entry and usable(frame) then
            BUI.safecall(restoreOrigin, frame, entry)
        end
    end

    -- La position de la pile vient d'être effacée : `applyBags` ne trouvera plus
    -- rien à reposer, et la disposition du client reprend la main pour de bon.
    restoreBags()

    -- Celle de la fenêtre de jet aussi. L'aperçu, lui, reste affiché si le
    -- joueur l'avait demandé : il revient au centre, prêt à être reposé.
    BUI.safecall(restoreLoot)
    BUI.safecall(applyLootPreview)
end

--- Nombre de fenêtres actuellement épinglées, pour l'affichage des options.
---@return integer
function M:CountPinned()
    if not host then return 0 end

    local count = 0
    for i = 1, #hooked do
        local entry = state[hooked[i]]
        if entry and (host.GetPosition(entry.name) or host.GetScale(entry.name)) then
            count = count + 1
        end
    end

    -- La pile compte pour une : c'est une position, et c'est ainsi qu'on la
    -- déplace et qu'on la remet en place. La fenêtre de jet compte de même.
    if host.GetPosition(BAGS_NAME) then count = count + 1 end
    if host.GetPosition(LOOT_NAME) then count = count + 1 end

    return count
end
