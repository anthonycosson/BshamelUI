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
--- Les sacs n'y sont pas non plus : le client réancre leurs cadres à chaque
--- recalcul de disposition, et notre réimposition entrerait dans un bras de fer
--- avec lui. Ils demandent un traitement à part, pas une ligne de plus ici.
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
local DRAG_HANDLES = {
    WorldMapFrame = "WorldMapTitleButton",
}

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
    if protectedNow(frame) and InCombatLockdown() then return end

    local scale = host.GetScale(entry.name)
    local pos   = host.GetPosition(entry.name)
    if not (scale or pos) then return end

    captureOrigin(frame, entry)

    if scale then rescale(frame, scale) end
    if pos then place(frame, pos.x, pos.y) end
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

    drag.x = (sx - ucx * ues) / es
    drag.y = (sy - ucy * ues) / es
    place(frame, drag.x, drag.y)
end

---@param frame table
---@param entry table
local function startDrag(frame, entry)
    if protectedNow(frame) and InCombatLockdown() then return end

    local fcx, fcy = frame:GetCenter()
    if not fcx then return end

    local es = frame:GetEffectiveScale()
    if not es then return end

    captureOrigin(frame, entry)

    drag.frame   = frame
    drag.name    = entry.name
    drag.x, drag.y = nil, nil
    drag.cursorX, drag.cursorY = GetCursorPosition()
    drag.startX, drag.startY   = fcx * es, fcy * es

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

    local handle = DRAG_HANDLES[name]
    if handle then attachDrag(_G[handle], frame, entry) end

    -- Le client réancre ses fenêtres à l'ouverture : c'est ici qu'on repose la
    -- nôtre, et pas seulement au démarrage.
    frame:HookScript("OnShow", function()
        if host then applyStored(frame, entry) end
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

        local pos = host.GetPosition(name)
        if not pos then return end
        if protectedNow(frame) and InCombatLockdown() then return end
        place(frame, pos.x, pos.y)
    end, function() return M:IsActive() end)

    -- Même raison pour l'échelle : certaines fenêtres se remettent à l'échelle
    -- toutes seules sur un changement d'état, sans passer par un cycle
    -- masquer/afficher qui aurait rejoué `OnShow`.
    U.GuardedHook(frame, "SetScale", function()
        if applying then return end
        if not host then return end

        local scale = host.GetScale(name)
        if not scale then return end
        if math.abs((frame:GetScale() or 1) - scale) < 0.001 then return end
        if protectedNow(frame) and InCombatLockdown() then return end

        applying = true
        rescale(frame, scale)
        applying = false
    end, function() return M:IsActive() end)

    if frame:IsVisible() then applyStored(frame, entry) end
end

---@param name string
local function tryHook(name)
    hookFrame(_G[name], name)
end

--- Branche les fenêtres qu'un addon de Blizzard vient d'apporter.
--- À appeler sur `ADDON_LOADED`.
---@param addonName string
function M:OnAddonLoaded(addonName)
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
    end

    for i = 1, #hooked do
        local frame = hooked[i]
        local entry = state[frame]
        if entry and usable(frame) then
            BUI.safecall(restoreOrigin, frame, entry)
        end
    end
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
    return count
end
