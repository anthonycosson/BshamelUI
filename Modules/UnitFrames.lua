-- =========================================================================
--  Bshamel UI — Modules/UnitFrames.lua
--  Les cadres d'unités du client : joueur, cible, cible de la cible, focus,
--  et les cadres de groupe.
--
--  On ne remplace rien. Le client dessine ses cadres, nous les habillons :
--  une couleur de classe sur la barre de vie, une icône de spécialisation au
--  bas du portrait, la couleur de faction retirée derrière le nom de la cible,
--  et une échelle sur les cadres de groupe qui dépasse ce que le mode Édition
--  accepte. Rien de tout cela ne crée de cadre d'unité.
--
--  Réversibilité (CLAUDE.md règle 6) : chaque comportement relève l'état du
--  client **avant** de le changer. Les couleurs de barres sont conservées et
--  reposées, l'échelle des cadres de groupe aussi, les icônes disparaissent, et
--  la couleur de faction est rendue en laissant le client la recalculer — lui
--  seul sait si cette unité a une faction à montrer.
--
--  `secure = true` : les cadres de groupe sont des cadres protégés, et les
--  redimensionner en combat lève une erreur d'action bloquée. Le core diffère
--  donc l'activation à la sortie de combat, et les fonctions qui redimensionnent
--  se gardent en plus elles-mêmes — un réglage peut être changé en combat, pas
--  seulement à l'activation.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local U    = BUI.Util
local L    = ns.L

local MODULE = "UnitFrames"

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
--  Les cadres et ce qu'ils montrent
-- =========================================================================

--- Cadre du client -> unité qu'il affiche.
---
--- Les cadres sont désignés par leur **nom global** et résolus à chaque passage,
--- jamais retenus : le cadre de focus n'existe pas tant qu'il n'y a pas de
--- focus, et un cadre retiré à une extension ne doit rien casser. C'est la forme
--- que prend ici la règle « test de capacité, jamais de numéro de patch », et
--- c'est déjà celle de `UI/Shade.lua`.
local UNIT_FRAMES = {
    { frame = "PlayerFrame",    unit = "player" },
    { frame = "TargetFrame",    unit = "target" },
    { frame = "TargetFrameToT", unit = "targettarget" },
    { frame = "FocusFrame",     unit = "focus" },
    { frame = "FocusFrameToT",  unit = "focustarget" },
}

--- Parcourt les cadres d'unités présents à cet instant.
---@param visit fun(frame: table, unit: string)
local function eachUnitFrame(visit)
    for i = 1, #UNIT_FRAMES do
        local entry = UNIT_FRAMES[i]
        local frame = _G[entry.frame]
        if type(frame) == "table" then visit(frame, entry.unit) end
    end
end

-- =========================================================================
--  Barres de vie aux couleurs de classe
-- =========================================================================

--- Clés sous lesquelles un cadre publie sa barre de vie.
---
--- Deux, et il en faut deux : les cadres montés par `UnitFrame_Initialize`
--- publient `healthbar`, les cadres de cible de la cible publient `HealthBar`.
--- Chercher la seule première laisse les deux petits cadres en vert, ce qui
--- ressemble à un oubli et n'en est pas un.
local HEALTH_KEYS = { "healthbar", "HealthBar" }

---@param frame table
---@return table|nil
local function healthBarOf(frame)
    for i = 1, #HEALTH_KEYS do
        local bar = frame[HEALTH_KEYS[i]]
        if type(bar) == "table" and type(bar.SetStatusBarColor) == "function" then
            return bar
        end
    end
    return nil
end

--- Les deux cadres de cible de la cible, et les unités qu'ils montrent. Sortis
--- de la fonction qui les parcourt parce qu'elle tourne dans un chemin chaud.
local TOT_FRAMES = { "TargetFrameToT", "FocusFrameToT" }
local TOT_UNITS  = { "targettarget", "focustarget" }

--- barre -> couleur qu'elle portait avant qu'on y touche.
local barColors = {}

--- Relève l'état d'une barre, une fois pour toutes : sa couleur et sa
--- désaturation.
---
--- Le client peut rendre des valeurs **secrètes**, qu'on ne saurait ni relire ni
--- reposer : on ne retient alors rien, et on ne teinte pas non plus.
---@param bar table
---@return boolean known
local function remember(bar)
    if barColors[bar] then return true end

    local ok, r, g, b, a = pcall(bar.GetStatusBarColor, bar)
    if not ok or U.IsSecret(r) or type(r) ~= "number" then return false end

    local desaturated = false
    if type(bar.IsStatusBarDesaturated) == "function" then
        local read, value = pcall(bar.IsStatusBarDesaturated, bar)
        desaturated = (read and value) and true or false
    end

    barColors[bar] = { r, g or 1, b or 1, a or 1, desaturated = desaturated }
    return true
end

--- Teinte une barre de vie de la couleur de classe de son unité.
---
--- **La barre est désaturée avant d'être teintée**, et c'est le point qui décide
--- de tout : la texture de remplissage du client n'est pas blanche, elle est
--- verte. Une couleur de sommet posée dessus la *multiplie* au lieu de la
--- remplacer, si bien qu'un bleu de chaman donne un vert sombre — la couleur
--- change bien, mais jamais pour celle qu'on a demandée. Désaturer rend la
--- texture grise, et la couleur de sommet redevient la couleur affichée.
---
--- Les unités qui ne sont pas des joueurs gardent la couleur du client : un
--- sanglier n'a pas de classe, et le vert dit déjà tout ce qu'il y a à dire.
---@param bar table|nil
---@param unit string|nil
local function colorBar(bar, unit)
    if not (bar and unit) then return end
    if not (UnitExists(unit) and UnitIsPlayer(unit)) then return end

    local _, class = UnitClass(unit)
    if U.IsSecret(class) then return end

    local color = T.ClassColor(class)
    if not color then return end
    if not remember(bar) then return end

    if type(bar.SetStatusBarDesaturated) == "function" then
        pcall(bar.SetStatusBarDesaturated, bar, true)
    end
    pcall(bar.SetStatusBarColor, bar, color:GetRGB())
end

--- Repose l'état d'origine de toutes les barres qu'on a teintes.
---
--- La saturation est rendue avant la couleur : les deux ne veulent rien dire
--- l'une sans l'autre, et reposer la couleur sur une texture restée grise
--- laisserait une barre pâle que le client n'a jamais dessinée.
---
--- La couleur relevée est celle que le client posait à ce moment-là — son vert,
--- ou son gris de déconnexion. Si elle se trouvait être exceptionnelle, la
--- première mise à jour du client la recalcule ; on ne laisse donc jamais une
--- barre dans un état qu'il n'a pas voulu.
local function restoreBars()
    for bar, state in pairs(barColors) do
        if type(bar.SetStatusBarDesaturated) == "function" then
            pcall(bar.SetStatusBarDesaturated, bar, state.desaturated)
        end
        pcall(bar.SetStatusBarColor, bar, state[1], state[2], state[3], state[4])
    end
    wipe(barColors)
end

--- Teinte les deux cadres de cible de la cible.
---
--- Ils ne passent pas par `UnitFrameHealthBar_Update` : le client les met à jour
--- autrement, et rien n'annonce leur changement. On les reprend donc à chaque
--- fois qu'une **autre** barre bouge, c'est-à-dire au moment où quelque chose se
--- passe, plutôt qu'en les sondant.
local function colorTargetOfTarget()
    -- Les deux cadres sont relus à chaque passage et la liste, elle, ne l'est
    -- pas : on est dans un chemin chaud (règle 7), une table construite ici
    -- serait construite à chaque battement de la barre de vie de la cible.
    for i = 1, #TOT_UNITS do
        local frame = _G[TOT_FRAMES[i]]
        if type(frame) == "table" then colorBar(healthBarOf(frame), TOT_UNITS[i]) end
    end
end

---@param mod table
local function applyClassColors(mod)
    if not mod:Get("classColorHealth") then
        restoreBars()
        return
    end

    eachUnitFrame(function(frame, unit)
        colorBar(healthBarOf(frame), unit)
    end)

    -- Les cadres de groupe « classiques » ne portent pas de nom global : ils
    -- pendent de leur conteneur. Le style raid, lui, a son propre réglage de
    -- couleurs de classe dans le client, on ne le double pas.
    local party = PartyFrame
    for i = 1, 4 do
        local member = party and party["MemberFrame" .. i]
        if type(member) == "table" then
            colorBar(healthBarOf(member), "party" .. i)
        end
    end
end

--- S'accroche à la mise à jour des barres de vie du client.
---
--- `UnitFrameHealthBar_Update` est le passage obligé de tous les cadres d'unités
--- classiques : joueur, cible, focus, boss, membres du groupe. Se brancher là
--- couvre les cadres d'un coup, et surtout **au bon moment** — le client repose
--- sa propre couleur à chaque mise à jour, un rafraîchissement périodique ne
--- ferait que courir derrière lui.
---
--- `U.GuardedHook` est le seul motif de hook autorisé (règle 6) : posé une fois,
--- il devient inerte dès que le module ou l'option s'éteint.
---@param mod table
local function hookHealthBars(mod)
    if type(UnitFrameHealthBar_Update) ~= "function" then return end

    local guard = function()
        return mod:IsEnabled() and mod:Get("classColorHealth") == true
    end

    U.GuardedHook("UnitFrameHealthBar_Update", function(bar, unit)
        colorBar(bar, unit)
        colorTargetOfTarget()
    end, guard)
end

-- =========================================================================
--  Icône de spécialisation
-- =========================================================================
-- L'icône **remplace le portrait** au lieu de s'ajouter à côté de lui. Le
-- portrait est déjà la case où le joueur va chercher « qui est-ce » : y poser la
-- spécialisation répond à la question au même endroit, alors qu'une pastille de
-- plus en bordure de cadre ajoute une chose à regarder. C'est aussi ce que le
-- client fait lui-même quand on lui demande une icône de classe à la place du
-- visage — on remplace la même texture, par une image plus précise.
--
-- On ne dessine donc rien : `UnitFramePortrait_Update` est le moment où le
-- client peint ce portrait, et c'est là qu'on repasse derrière lui.
--
-- La spécialisation du joueur se demande au client. Celle d'un autre joueur ne
-- se demande qu'au **serveur**, par une inspection, et cela a deux conséquences
-- qu'aucune astuce ne lève :
--
--   · l'unité doit être à portée d'inspection — quelques dizaines de mètres.
--     Hors de portée, il n'y a pas d'icône, et il ne peut pas y en avoir ;
--   · le serveur ne traite qu'une demande à la fois. On garde donc le résultat
--     par GUID, on ne redemande jamais ce qu'on sait déjà, et on espace les
--     demandes.
--
-- C'est la limite de la fonctionnalité, pas un défaut d'implémentation : en
-- donjon, en raid et en arène — là où la spécialisation d'une cible compte — le
-- groupe est à portée et l'icône est là.

--- Délai minimal entre deux demandes d'inspection, en secondes.
---
--- Mesuré sur le comportement du serveur et non déduit d'une constante du
--- client, qui n'en publie aucune : en dessous, les demandes rapprochées sont
--- ignorées en silence.
local INSPECT_INTERVAL = 1.5

--- GUID -> identifiant de spécialisation déjà connu.
--- Une spécialisation ne change qu'au gré du joueur qui la porte : ce cache tient
--- toute la session sans mentir plus d'une poignée de secondes.
local specByGUID = {}

--- date de la dernière demande d'inspection
local lastInspect = 0

--- rendez-vous déjà pris pour retenter une demande refusée
local retryPending = false

--- Identifiant de spécialisation du joueur.
---
--- La fonction a migré dans `C_SpecializationInfo`. La globale existe encore sur
--- les clients plus anciens ; ni l'une ni l'autre n'est garantie pour toujours,
--- on essaie donc les deux dans cet ordre.
---@return number|nil
local function playerSpec()
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

--- Image d'une spécialisation, ou `nil` si elle est inconnue.
---@param specID number|nil
---@return string|number|nil
local function specTexture(specID)
    if not specID or specID == 0 then return nil end

    local api = C_SpecializationInfo
    if api and api.GetSpecializationInfoByID then
        local _, _, _, icon = api.GetSpecializationInfoByID(specID)
        if icon then return icon end
    end
    if GetSpecializationInfoByID then
        local _, _, _, icon = GetSpecializationInfoByID(specID)
        return icon
    end
    return nil
end

--- GUID d'une unité, ou `nil` s'il est secret ou absent.
---@param unit string
---@return string|nil
local function guidOf(unit)
    local guid = UnitGUID(unit)
    if U.IsSecret(guid) or type(guid) ~= "string" then return nil end
    return guid
end

--- Spécialisation connue d'une unité, sans rien demander à personne.
---@param unit string
---@return number|nil
local function knownSpec(unit)
    if not (UnitExists(unit) and UnitIsPlayer(unit)) then return nil end
    if UnitIsUnit(unit, "player") then return playerSpec() end

    local guid = guidOf(unit)
    return guid and specByGUID[guid] or nil
end

--- Spécialisation de l'unité que le serveur vient de nous décrire.
---
--- Comme pour la spécialisation du joueur, deux chemins : l'espace de noms
--- récent d'abord, la globale ensuite.
---@param unit string
---@return number|nil
local function inspectedSpec(unit)
    local api = C_SpecializationInfo
    if api and api.GetInspectSpecialization then
        return api.GetInspectSpecialization(unit)
    end
    if GetInspectSpecialization then
        return GetInspectSpecialization(unit)
    end
    return nil
end

--- Le client sait-il inspecter ?
---@return boolean
local function canAskServer()
    if not (CanInspect and NotifyInspect) then return false end

    local api = C_SpecializationInfo
    return (api and api.GetInspectSpecialization ~= nil)
        or GetInspectSpecialization ~= nil
end

--- Demande au serveur la spécialisation d'une unité.
---
--- Renvoie `false` quand la demande est tombée dans l'intervalle de garde :
--- l'appelant sait alors qu'il lui reste quelque chose à apprendre, et c'est lui
--- qui prend le rendez-vous pour y revenir.
---@param unit string
---@return boolean asked
local function requestSpec(unit)
    if not canAskServer() then return true end
    if not CanInspect(unit, false) then return true end

    local now = GetTime()
    if now - lastInspect < INSPECT_INTERVAL then return false end

    lastInspect = now
    NotifyInspect(unit)
    return true
end

--- Clés sous lesquelles un cadre du client publie son portrait.
local PORTRAIT_KEYS = { "portrait", "Portrait" }

---@param frame table
---@return table|nil
local function portraitOf(frame)
    for i = 1, #PORTRAIT_KEYS do
        local region = frame[PORTRAIT_KEYS[i]]
        if type(region) == "table" and type(region.SetTexture) == "function" then
            return region
        end
    end

    -- Le cadre du joueur range le sien dans un conteneur.
    local container = frame.PlayerFrameContainer
    local portrait  = container and container.PlayerPortrait
    if type(portrait) == "table" and type(portrait.SetTexture) == "function" then
        return portrait
    end
    return nil
end

--- Pose l'icône de spécialisation à la place du portrait.
---
--- Les coordonnées de texture sont **remises à plein cadre**. Le client ne pose
--- pas toujours une image entière dans cette case : quand le joueur préfère une
--- icône de classe au visage, il y découpe une vignette dans une planche
--- commune. Garder son découpage sur notre icône n'en montrerait qu'un coin.
---@param frame table
---@param unit string
---@return boolean painted
local function paintPortrait(frame, unit)
    local portrait = portraitOf(frame)
    if not portrait then return false end

    local file = specTexture(knownSpec(unit))
    if not file then return false end

    pcall(portrait.SetTexture, portrait, file)
    if type(portrait.SetTexCoord) == "function" then
        pcall(portrait.SetTexCoord, portrait, 0, 1, 0, 1)
    end
    return true
end

--- Rend son portrait au client.
---
--- On ne le repeint pas nous-mêmes : `UnitFramePortrait_Update` est la fonction
--- qui décide, selon les réglages du joueur, entre un visage et une icône de
--- classe. La rappeler rend exactement ce qu'il aurait dessiné — reposer une
--- texture à la main choisirait à sa place.
local function restorePortraits()
    if type(UnitFramePortrait_Update) ~= "function" then return end

    eachUnitFrame(function(frame)
        if frame.unit then BUI.safecall(UnitFramePortrait_Update, frame) end
    end)
end

---@param mod table
local function applySpecIcons(mod)
    if not mod:Get("specIcon") then
        restorePortraits()
        return
    end

    local waiting = false

    eachUnitFrame(function(frame, unit)
        paintPortrait(frame, unit)

        -- Rien de connu sur un joueur qu'on peut inspecter : on demande, et on
        -- repassera ici quand le serveur aura répondu.
        if not knownSpec(unit) and UnitExists(unit) and UnitIsPlayer(unit) then
            if not requestSpec(unit) then waiting = true end
        end
    end)

    -- Une demande est tombée dans l'intervalle de garde : sans ce rendez-vous,
    -- une cible prise juste après une autre n'aurait jamais son icône — la
    -- seule demande qui la concernait a été refusée, et plus rien ne la
    -- rappellerait.
    if waiting and not retryPending then
        retryPending = true
        C_Timer.After(INSPECT_INTERVAL, function()
            retryPending = false
            if mod:IsEnabled() then applySpecIcons(mod) end
        end)
    end
end

--- Réponse du serveur à une demande d'inspection.
---
--- L'événement ne dit que le GUID inspecté : on retrouve l'unité en comparant,
--- parce que la spécialisation ne se lit que par une unité. On ne ferme pas
--- l'inspection derrière nous — `ClearInspectPlayer` fermerait aussi la fenêtre
--- d'inspection que le joueur aurait ouverte lui-même.
---@param mod table
---@param guid any
local function inspectReady(mod, guid)
    if U.IsSecret(guid) or type(guid) ~= "string" then return end

    for i = 1, #UNIT_FRAMES do
        local unit = UNIT_FRAMES[i].unit
        if UnitExists(unit) and guidOf(unit) == guid then
            local specID = inspectedSpec(unit)
            if specID and specID > 0 then specByGUID[guid] = specID end
            break
        end
    end

    applySpecIcons(mod)
end

--- S'accroche au moment où le client peint un portrait.
---
--- C'est le seul moment qui vaille. Le portrait est repeint à chaque changement
--- de cible, à chaque entrée en véhicule, à chaque fois que l'unité change sous
--- le cadre — et à chaque fois, notre icône serait effacée. Repasser à
--- intervalles reviendrait à parier sur le moment où il s'y met, et ce pari se
--- perd : on verrait le visage revenir puis disparaître.
---@param mod table
local function hookPortraits(mod)
    if type(UnitFramePortrait_Update) ~= "function" then return end

    local guard = function()
        return mod:IsEnabled() and mod:Get("specIcon") == true
    end

    U.GuardedHook("UnitFramePortrait_Update", function(frame)
        if type(frame) ~= "table" or not frame.unit then return end
        paintPortrait(frame, frame.unit)
    end, guard)
end

-- =========================================================================
--  Couleur de réputation derrière la cible
-- =========================================================================
-- La plaque colorée posée derrière le nom de la cible dit sa faction. Elle est
-- repeinte par le client à chaque changement de cible, et la teindre une fois ne
-- suffit donc pas : on se branche sur le moment où il la repeint.
--
-- **On la rend transparente, on ne la masque pas.** `CheckFaction` recalcule sa
-- *couleur*, et rien d'autre : le client ne la réaffiche jamais, parce qu'il ne
-- l'a jamais cachée. Un `Hide` est donc sans retour — décocher le réglage
-- laissait la plaque disparue jusqu'au rechargement. Une opacité nulle laisse au
-- contraire la visibilité entre ses mains : on rend invisible ce qu'il montre,
-- et reposer l'opacité d'origine rend exactement son état.

local REPUTATION_FRAMES = { "TargetFrame", "FocusFrame" }

--- plaque -> opacité qu'elle portait avant qu'on y touche
local repAlphas = {}

---@param frame table|nil
---@return table|nil
local function reputationColorOf(frame)
    local content = frame and frame.TargetFrameContent
    local main    = content and content.TargetFrameContentMain
    local region  = main and main.ReputationColor

    if type(region) == "table" and type(region.SetAlpha) == "function" then return region end
    return nil
end

--- Efface une plaque, en retenant l'opacité qu'elle avait.
---@param region table
local function fadeReputationColor(region)
    if repAlphas[region] == nil then
        local ok, alpha = pcall(region.GetAlpha, region)
        repAlphas[region] = (ok and type(alpha) == "number") and alpha or 1
    end
    pcall(region.SetAlpha, region, 0)
end

--- Rend leur opacité aux plaques qu'on avait effacées.
local function restoreReputationColor()
    for region, alpha in pairs(repAlphas) do
        pcall(region.SetAlpha, region, alpha)
    end
    wipe(repAlphas)
end

---@param mod table
local function applyReputationColor(mod)
    if not mod:Get("hideReputationColor") then
        restoreReputationColor()
        return
    end

    for i = 1, #REPUTATION_FRAMES do
        local region = reputationColorOf(_G[REPUTATION_FRAMES[i]])
        if region then fadeReputationColor(region) end
    end
end

---@param mod table
local function hookReputationColor(mod)
    local guard = function()
        return mod:IsEnabled() and mod:Get("hideReputationColor") == true
    end

    for i = 1, #REPUTATION_FRAMES do
        local frame = _G[REPUTATION_FRAMES[i]]
        if type(frame) == "table" and type(frame.CheckFaction) == "function" then
            U.GuardedHook(frame, "CheckFaction", function(self)
                local region = reputationColorOf(self)
                if region then fadeReputationColor(region) end
            end, guard)
        end
    end
end

-- =========================================================================
--  Taille des cadres de groupe
-- =========================================================================
-- Le mode Édition règle la taille des cadres de groupe par une échelle, et
-- borne son curseur. On pose la même échelle qu'il poserait, sans la borne.
--
-- C'est une **échelle absolue** et non un multiplicateur de la sienne : le
-- réglage remplace le sien tant qu'il est allumé, et le lui rend quand il
-- s'éteint. Deux valeurs qui se multiplieraient donneraient un résultat que ni
-- l'une ni l'autre des deux fenêtres n'annonce.

--- Les deux styles de cadres de groupe. On agit sur les deux : le mode Édition
--- dit lequel est à l'écran, mais le joueur bascule sans nous prévenir, et
--- redimensionner un cadre caché ne coûte rien.
local PARTY_FRAMES = { "CompactPartyFrame", "PartyFrame" }

--- cadre -> échelle qu'il portait avant qu'on y touche
local partyScales = {}

--- Rend leur échelle aux cadres de groupe.
---
--- L'échelle relevée est reposée, puis le mode Édition est invité à recalculer
--- la sienne s'il sait le faire : il a le dernier mot, parce que le joueur a pu
--- déplacer son curseur pendant que le nôtre tenait la barre.
local function restorePartyScale()
    if InCombatLockdown() then return end

    for frame, scale in pairs(partyScales) do
        BUI.safecall(frame.SetScale, frame, scale)
        if type(frame.UpdateSystemSettingFrameSize) == "function" then
            BUI.safecall(frame.UpdateSystemSettingFrameSize, frame)
        end
    end
    wipe(partyScales)
end

---@param mod table
local function applyPartyScale(mod)
    -- Cadres protégés : les redimensionner en combat lève une erreur d'action
    -- bloquée. Ce qui est refusé ici est rattrapé à la sortie de combat, où
    -- `OnEnable` rappelle cette fonction.
    if InCombatLockdown() then return end

    if not mod:Get("enlargeParty") then
        restorePartyScale()
        return
    end

    local scale = mod:Get("partyScale") / 100

    for i = 1, #PARTY_FRAMES do
        local frame = _G[PARTY_FRAMES[i]]
        if type(frame) == "table" and type(frame.SetScale) == "function" then
            if partyScales[frame] == nil then
                partyScales[frame] = frame:GetScale() or 1
            end
            BUI.safecall(frame.SetScale, frame, scale)
        end
    end
end

--- S'accroche au moment où le mode Édition repose sa taille.
---
--- Sans ce hook, ouvrir puis fermer le mode Édition — ou simplement changer de
--- disposition — ramènerait les cadres à la taille bornée, et le réglage aurait
--- l'air de « ne pas tenir ». Le hook ne rappelle pas la fonction qu'il coiffe :
--- il repose l'échelle directement, il n'y a donc pas de boucle.
---@param mod table
local function hookPartyFrames(mod)
    local guard = function()
        return mod:IsEnabled() and mod:Get("enlargeParty") == true
    end

    for i = 1, #PARTY_FRAMES do
        local frame = _G[PARTY_FRAMES[i]]
        if type(frame) == "table" and type(frame.UpdateSystemSettingFrameSize) == "function" then
            U.GuardedHook(frame, "UpdateSystemSettingFrameSize", function()
                applyPartyScale(mod)
            end, guard)
        end
    end
end

-- =========================================================================
--  Application d'ensemble
-- =========================================================================

---@param mod table
local function applyAll(mod)
    applyClassColors(mod)
    applySpecIcons(mod)
    applyReputationColor(mod)
    applyPartyScale(mod)
end

--- Réglage -> fonction qui le pose.
local APPLIERS = {
    classColorHealth    = applyClassColors,
    specIcon            = applySpecIcons,
    hideReputationColor = applyReputationColor,
    enlargeParty        = applyPartyScale,
    partyScale          = applyPartyScale,
}

-- =========================================================================
--  Déclaration du module
-- =========================================================================

BUI:RegisterModule(MODULE, {
    title    = L["Unit frames"],
    category = "Interface",
    order    = 20,
    secure   = true,

    defaults = {
        classColorHealth    = false,
        hideReputationColor = false,

        specIcon     = false,

        enlargeParty = false,
        -- 100 % : l'échelle que le cadre porte déjà. Allumer l'interrupteur sans
        -- toucher au curseur ne change donc rien à l'écran, ce qui est la seule
        -- valeur de départ honnête — le joueur monte ensuite jusqu'où il veut.
        partyScale   = 100,
    },

    options = {
        { type = "header", text = L["Appearance"] },
        {
            type    = "toggle",
            key     = "classColorHealth",
            text    = L["Class-colored health"],
            tooltip = L["Class-colored health tip"],
        },
        {
            type    = "toggle",
            key     = "hideReputationColor",
            text    = L["Hide reputation color"],
            tooltip = L["Hide reputation color tip"],
        },

        { type = "header", text = L["Specialization"] },
        {
            type    = "toggle",
            key     = "specIcon",
            text    = L["Show spec icon"],
            tooltip = L["Show spec icon tip"],
        },
        { type = "header", text = L["Party frames"] },
        {
            type    = "toggle",
            key     = "enlargeParty",
            text    = L["Enlarge party frames"],
            tooltip = L["Enlarge party frames tip"],
        },
        {
            type     = "slider",
            key      = "partyScale",
            text     = L["Party frame scale"],
            tooltip  = L["Party frame scale tip"],
            min      = 100,
            max      = 250,
            step     = 5,
            disabled = requires("enlargeParty"),
        },

        -- Mode sombre : voir la note du module ActionBars dans `Upcoming.lua`.
        { type = "description", text = L["Dark mode moved"] },
    },

    OnEnable = function(self)
        applyAll(self)

        hookHealthBars(self)
        hookPortraits(self)
        hookReputationColor(self)
        hookPartyFrames(self)

        -- Trois passages, et chacun couvre ce que les autres manquent. C'est le
        -- même motif que le mode sombre, pour exactement la même raison — voir
        -- `refresher` dans `Modules/General.lua` et `dev/docs/API_NOTES.md`.
        --
        -- Le premier applique **à l'instant** du changement de cible. C'est lui
        -- qui manquait : tout partait sur le troisième, et le cadre s'affichait
        -- deux dixièmes de seconde dans son état par défaut avant de prendre nos
        -- réglages. Le délai se voyait d'autant mieux sur l'icône de
        -- spécialisation, dont la demande d'inspection ne partait qu'à ce
        -- moment-là — le retard du rafraîchissement s'ajoutait à celui du
        -- serveur.
        --
        -- Le deuxième rattrape le rhabillage que le client fait *après* avoir
        -- annoncé le changement de cible. Le troisième est le filet : la cible
        -- de la cible n'est pas résolue quand la cible l'est.
        --
        -- Les trois passages sont idempotents — ils relisent l'état voulu et le
        -- reposent — donc repasser ne coûte que le passage, jamais un
        -- clignotement.
        local function pass()
            applyClassColors(self)
            applySpecIcons(self)
            applyReputationColor(self)
        end

        local settle = U.Debounce(T.TIMING.UNIT_SETTLE, pass)

        local function refresh()
            pass()
            C_Timer.After(T.TIMING.UNIT_QUICK, pass)
            settle()
        end

        self:RegisterEvent("PLAYER_TARGET_CHANGED", refresh)
        self:RegisterEvent("PLAYER_FOCUS_CHANGED",  refresh)
        self:RegisterEvent("PLAYER_ENTERING_WORLD", refresh)
        self:RegisterEvent("GROUP_ROSTER_UPDATE",   refresh)
        self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", refresh)

        -- `UNIT_TARGET` parle de **toutes** les unités du groupe : on ne retient
        -- que celles dont on affiche la cible.
        self:RegisterEvent("UNIT_TARGET", function(_, unit)
            if unit == "target" or unit == "focus" then refresh() end
        end)

        self:RegisterEvent("INSPECT_READY", function(_, guid)
            inspectReady(self, guid)
        end)

        -- Un cadre de groupe peut n'exister qu'une fois le groupe formé, et un
        -- hook ne se pose que sur un cadre qui existe : on repasse. `GuardedHook`
        -- ne pose jamais deux fois le même, rappeler ne coûte donc rien.
        local rescale = function()
            hookPartyFrames(self)
            applyPartyScale(self)
        end

        self:RegisterEvent("GROUP_ROSTER_UPDATE",       rescale)
        self:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED", rescale)
        self:RegisterEvent("PLAYER_ENTERING_WORLD",     rescale)

        -- Ce que le combat a refusé est rattrapé ici.
        self:RegisterEvent("PLAYER_REGEN_ENABLED", rescale)
    end,

    OnDisable = function()
        -- On rend sans relire les réglages : le module s'éteint, ce qu'il a
        -- posé doit disparaître même si les interrupteurs restent cochés.
        restoreBars()
        restorePortraits()
        restoreReputationColor()
        restorePartyScale()
    end,

    OnSettingChanged = function(self, key)
        if key == nil then
            applyAll(self)
            return
        end

        local apply = APPLIERS[key]
        if apply then apply(self) end
    end,
})
