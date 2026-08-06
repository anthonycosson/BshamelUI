-- =========================================================================
--  Bshamel UI — Modules/RaidCooldowns.lua
--  Les deux réserves que tout le groupe partage : les résurrections de combat
--  et la Furie sanguinaire.
--
--  Elles n'ont pas le même mécanisme et se regardent au même moment, pour la
--  même raison : ce sont les deux ressources dont on veut connaître l'état
--  *avant* d'en avoir besoin, et que le client ne montre nulle part clairement.
--  L'une se lit sous les charges d'un sort de druide, l'autre sous un débuff
--  qu'on porte sans le regarder.
--
--  Le module ne dessine rien : `UI/Widgets/IconTracker.lua` sait poser une icône
--  de sort avec un compteur dans son coin et un décompte en son milieu. Ce
--  fichier dit *quoi* compter. C'est la même séparation que partout ailleurs.
--
--  Les deux suivis vivaient dans *Outils de raid*, qui en tenait quatre. Un
--  palier de migration (`Core/DB.lua`) déplace les réglages de ceux qui les
--  avaient changés.
--
--  Réversibilité (règle 6) : les deux icônes se cachent, et le débuff masqué dans
--  le cadre des affaiblissements est rendu.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local U    = BUI.Util
local W    = BUI.Widgets
local L    = ns.L

local MODULE = "RaidCooldowns"

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
--  Instances
-- =========================================================================

--- Type de l'instance courante, ou `nil` en extérieur.
---@return string|nil
local function instanceType()
    if not GetInstanceInfo then return nil end
    local _, kind = GetInstanceInfo()
    if kind == "none" then return nil end
    return kind
end

---@return boolean
local function inChallenge()
    return C_ChallengeMode ~= nil
        and C_ChallengeMode.IsChallengeModeActive ~= nil
        and C_ChallengeMode.IsChallengeModeActive() == true
end

--- Y a-t-il une réserve partagée à suivre ? Hors instance, ou seul, il n'y en a
--- pas : le suivi n'a rien à dire et se cache.
---@return boolean
local function inGroupContent()
    local kind = instanceType()
    return (kind == "raid" or kind == "party" or inChallenge()) and IsInGroup()
end

-- =========================================================================
--  Suivi des résurrections de combat
-- =========================================================================
-- Le client tient un compteur de résurrections **partagé par le groupe** dans
-- les instances qui en limitent l'usage, et il le publie sous les charges du
-- sort de Rétablissement du druide — pour tout le monde, druide ou non. C'est le
-- seul chemin publié ; voir `dev/docs/API_NOTES.md`.

local BATTLE_RES_SPELL = 20484

local resTracker
--- Relevés rendus au widget. Réutilisés : ils sont relus plusieurs fois par
--- seconde, et un chemin qui bat n'alloue pas (règle 7).
local resInfo = {}
local rawRes  = {}

---@return table|nil
local function readBattleRes()
    if C_Spell and C_Spell.GetSpellCharges then
        local info = C_Spell.GetSpellCharges(BATTLE_RES_SPELL)
        if not info then return nil end

        rawRes.charges  = info.currentCharges
        rawRes.max      = info.maxCharges
        rawRes.start    = info.cooldownStartTime
        rawRes.duration = info.cooldownDuration
        return rawRes
    end

    if GetSpellCharges then
        local charges, max, start, duration = GetSpellCharges(BATTLE_RES_SPELL)
        if not charges then return nil end

        rawRes.charges  = charges
        rawRes.max      = max
        rawRes.start    = start
        rawRes.duration = duration
        return rawRes
    end

    return nil
end

--- Relevé d'exemple du mode aperçu. L'icône ne s'affiche que là où il y a une
--- réserve à compter — c'est-à-dire nulle part au moment précis où l'on cherche
--- où la poser. Même parti pris que le chrono mythique+ (`Modules/MythicTimer.lua`).
local RES_PREVIEW = { charges = 1, maxCharges = 1, remaining = 90, duration = 600 }

---@param mod table
---@return BUI.TrackerInfo|nil
local function battleResSource(mod)
    if not inGroupContent() then
        if mod:Get("battleResPreview") then return RES_PREVIEW end
        return nil
    end

    local raw = readBattleRes()
    if not (raw and raw.max and raw.max > 0) then
        if mod:Get("battleResPreview") then return RES_PREVIEW end
        return nil
    end

    resInfo.charges    = raw.charges or 0
    resInfo.maxCharges = raw.max
    resInfo.remaining  = nil
    resInfo.duration   = nil

    if raw.start and raw.start > 0 and raw.duration and raw.duration > 0 then
        local remaining = raw.start + raw.duration - GetTime()
        if remaining > 0 then
            resInfo.remaining = remaining
            resInfo.duration  = raw.duration
        end
    end

    return resInfo
end

-- =========================================================================
--  Suivi du débuff de Furie sanguinaire
-- =========================================================================
-- Ce qu'on suit n'est pas le buff mais le **débuff** : la Furie sanguinaire dure
-- quarante secondes, son interdiction dix minutes, et c'est celle-ci qui décide
-- du prochain pull. Tant qu'elle court, personne ne peut en relancer une.
--
-- **Toutes les classes qui en donnent une, pas seulement le chaman.** Chaque
-- source pose son propre débuff, sous son propre nom et son propre identifiant,
-- mais tous font la même chose et se remplacent l'un l'autre. C'est une **liste
-- de données**, comme les pierres de foyer du menu de téléportation : un
-- identifiant inconnu ne casse rien, il ne se déclenche simplement jamais, et
-- une extension qui ajoute une source se règle en ajoutant une ligne.
--
-- L'**icône**, elle, est celle du chaman et d'aucune autre. Ce qu'on montre est
-- « une Furie sanguinaire a été lancée », pas « laquelle » : une icône qui
-- changerait selon la classe qui l'a lancée demanderait de la relire à chaque
-- fois pour savoir qu'elle dit toujours la même chose.

--- Le sort dont on emprunte l'image. Le chaman est celui auquel tout le monde
--- pense en disant « BL », y compris quand c'est un mage qui l'a lancée.
local LUST_ICON_SPELL = 2825

--- Les débuffs d'interdiction, par identifiant. Toutes les sources connues :
--- chaman (les deux factions), mage, chasseur (deux familiers), évocateur.
local SATED_DEBUFFS = {
    [57724]  = true,   -- Rassasié (Furie sanguinaire, chaman)
    [57723]  = true,   -- Épuisement (Héroïsme, chaman)
    [80354]  = true,   -- Déplacement temporel (Distorsion temporelle, mage)
    [264689] = true,   -- Fatigué (Rage primitive, familier du chasseur)
    [95809]  = true,   -- Démence (Hystérie ancestrale, familier du chasseur)
    [160455] = true,   -- Fatigué (Vents inférieurs, familier du chasseur)
    [390435] = true,   -- Épuisement (Furie des Aspects, évocateur)
}

local lustTracker
local lustInfo = {}

--- Le débuff porté, s'il y en a un.
---
--- Deux chemins. Le premier interroge le client débuff par débuff, ce qu'il fait
--- le mieux ; le second parcourt ceux du joueur, pour un client qui ne
--- publierait pas le premier. Aucun des deux n'est un pari : une fonction absente
--- rend la main au suivant, et l'absence des deux rend simplement `nil`.
---@return number|nil remaining, number|nil duration
local function readSated()
    local auras = C_UnitAuras
    if not auras then return nil, nil end

    if auras.GetPlayerAuraBySpellID then
        for id in pairs(SATED_DEBUFFS) do
            local aura = auras.GetPlayerAuraBySpellID(id)
            if aura and aura.expirationTime then
                return aura.expirationTime - GetTime(), aura.duration
            end
        end
        return nil, nil
    end

    if auras.GetDebuffDataByIndex then
        for i = 1, 40 do
            local aura = auras.GetDebuffDataByIndex("player", i)
            if not aura then break end
            if aura.spellId and SATED_DEBUFFS[aura.spellId] and aura.expirationTime then
                return aura.expirationTime - GetTime(), aura.duration
            end
        end
    end

    return nil, nil
end

--- Relevé d'exemple. Comme pour les résurrections : on cherche où poser l'icône
--- au moment précis où il n'y a rien à afficher.
local LUST_PREVIEW = { remaining = 420, duration = 600 }

---@param mod table
---@return BUI.TrackerInfo|nil
local function lustSource(mod)
    local remaining, duration = readSated()

    if not remaining or remaining <= 0 then
        if mod:Get("lustPreview") then return LUST_PREVIEW end
        return nil
    end

    -- Pas de compteur : il n'y a rien à compter, seulement un temps à attendre.
    lustInfo.charges   = nil
    lustInfo.remaining = remaining
    lustInfo.duration  = duration
    return lustInfo
end

-- =========================================================================
--  Masquer le débuff dans le cadre des affaiblissements
-- =========================================================================
-- Le suivi affiche déjà le temps restant, en grand et là où on l'a posé : la même
-- information dans la rangée d'affaiblissements est une redite, et elle occupe la
-- place de ce qu'on a vraiment besoin d'y lire.
--
-- On ne masque **que** ce qu'on suit soi-même : le réglage est grisé tant que le
-- suivi est éteint, et le masquage est refait à chaque passe du client. Un cadre
-- d'aura sort d'un pool et sera réutilisé pour une autre aura : on rend donc
-- **tout ce qu'on a masqué** avant de masquer à nouveau, ce qui rattrape de
-- lui-même un cadre recyclé.

--- Cadres qu'on a masqués, pour pouvoir les rendre. Réutilisée (règle 7).
local hiddenAuras = {}

--- Identifiant du sort porté par un cadre d'aura, quand le cadre le porte.
---
--- Relevé sur un client 12.0 : **il ne le porte pas**. Les boutons de la rangée
--- d'affaiblissements n'ont ni `auraInstanceID` ni `spellID` ; ils sont mis à jour
--- par leur position dans la rangée et ne retiennent rien de ce qu'ils affichent.
--- C'est ce qui faisait échouer le masquage en silence : la boucle visitait bien
--- les vingt-deux boutons, et aucun ne savait dire ce qu'il montrait.
---
--- Les chemins restent, parce qu'ils ne coûtent rien et qu'un client qui les
--- publierait donnerait la réponse la plus sûre. Quand ils se taisent tous, c'est
--- l'**icône** qui répond (voir `satedIcons`).
---@param frame table
---@return number|nil
local function auraSpellID(frame)
    if type(frame) ~= "table" then return nil end

    local instance = frame.auraInstanceID
    if instance and C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID then
        local aura = C_UnitAuras.GetAuraDataByAuraInstanceID("player", instance)
        if aura and aura.spellId then return aura.spellId end
    end

    if frame.spellID then return frame.spellID end
    if frame.aura and frame.aura.spellId then return frame.aura.spellId end
    if frame.auraData and frame.auraData.spellId then return frame.auraData.spellId end

    -- Le rang du bouton dans la rangée, sous les trois noms que le client lui a
    -- donnés. C'est un index d'affaiblissement : on redemande au client ce qu'il
    -- y a à cette place-là.
    local index = frame.auraIndex or frame.index or frame.id
    if type(index) == "number" and C_UnitAuras and C_UnitAuras.GetDebuffDataByIndex then
        local aura = C_UnitAuras.GetDebuffDataByIndex("player", index)
        if aura and aura.spellId then return aura.spellId end
    end

    return nil
end

-- =========================================================================
--  Reconnaître un débuff à son image
-- =========================================================================
-- Dernier recours, et sur ce client c'est le **seul** qui réponde : un bouton
-- d'aura ne dit pas quel sort il porte, mais il affiche son icône, et une icône
-- est un identifiant de fichier qu'on peut comparer.
--
-- On ne compare pas à une texture écrite ici : on demande au client l'image de
-- chacun des sept débuffs, et on compare à celles-là. Aucun chemin de fichier
-- n'est donc gravé, et la comparaison suit le jeu quand il retouche une icône.
--
-- Le risque assumé : deux sorts peuvent partager exactement le même fichier, et
-- un tel sort serait masqué avec le nôtre. Il faudrait qu'il porte l'image d'une
-- interdiction de Furie sanguinaire sans en être une, ce qui n'existe pas — et
-- le réglage est de toute façon éteint par défaut.

--- image -> vrai, pour les sept débuffs. Construite au premier besoin : les
--- données de sort ne sont pas toutes chargées à la connexion.
local satedIcons

---@return table|nil
local function satedIconSet()
    if satedIcons then return satedIcons end
    if not (C_Spell and C_Spell.GetSpellTexture) then return nil end

    local found = {}
    local any = false
    for id in pairs(SATED_DEBUFFS) do
        local texture = C_Spell.GetSpellTexture(id)
        if texture then
            found[texture] = true
            any = true
        end
    end

    -- Une table vide n'est pas un résultat : le client n'avait pas encore les
    -- données. On ne la retient pas, et on la redemandera au prochain passage.
    if not any then return nil end

    satedIcons = found
    return satedIcons
end

--- Image affichée par un bouton d'aura, sous les deux noms que le client donne à
--- sa texture selon l'âge du modèle.
---@param frame table
---@return string|number|nil
local function auraTexture(frame)
    local icon = frame.Icon or frame.icon
    if icon and icon.GetTexture then return icon:GetTexture() end
    return nil
end

--- Ce bouton porte-t-il une interdiction de Furie sanguinaire ?
---@param frame table
---@return boolean
local function isSatedFrame(frame)
    local id = auraSpellID(frame)
    if id then return SATED_DEBUFFS[id] == true end

    local icons = satedIconSet()
    if not icons then return false end

    local texture = auraTexture(frame)
    return texture ~= nil and icons[texture] == true
end

--- Rend tout ce qu'on avait masqué.
local function showHiddenAuras()
    for i = #hiddenAuras, 1, -1 do
        local frame = hiddenAuras[i]
        if frame and frame.Show then frame:Show() end
        hiddenAuras[i] = nil
    end
end

--- Cadres qui portent les auras du joueur. `BuffFrame` autant que `DebuffFrame` :
--- on ne filtre pas sur le cadre mais sur l'identifiant du sort, et regarder les
--- deux coûte un parcours de plus là où se tromper de cadre coûte la
--- fonctionnalité entière.
local function auraHosts()
    return { DebuffFrame, BuffFrame }
end

--- Parcourt les cadres d'aura d'un hôte, quel que soit le chemin par lequel le
--- client les tient.
---
--- Quatre chemins, et on les essaie **tous** au lieu de s'arrêter au premier qui
--- répond : le premier essai ne cherchait que `auraFrames` et `auraPools`, et
--- s'arrêtait dès que l'un des deux existait — or le client range ses boutons
--- dans un `auraPool` au singulier, sous un conteneur de disposition. Le doublon
--- n'est pas un problème : on masque un cadre déjà masqué, ce qui ne fait rien.
---@param host table
---@param visit fun(frame: table)
local function forEachAuraFrame(host, visit)
    if not host then return end

    -- `pairs` et non une boucle numérique : cette table n'est **pas une liste**.
    -- Le client l'indexe par identifiant d'instance d'aura, si bien que `#frames`
    -- vaut zéro et qu'un parcours de `1` à `#frames` ne visite rien — c'était la
    -- panne. Une table qui serait quand même une liste se parcourt aussi bien
    -- ainsi, l'ordre en moins, dont on n'a que faire ici.
    local frames = host.auraFrames
    if type(frames) == "table" then
        for _, frame in pairs(frames) do visit(frame) end
    end

    -- Au singulier — c'est le nom du client pour le pool d'un cadre d'auras du
    -- joueur — puis au pluriel, qui est celui des cadres d'unités.
    local pool = host.auraPool or host.auraPools
    if pool and pool.EnumerateActive then
        for frame in pool:EnumerateActive() do visit(frame) end
    end

    -- Le conteneur de disposition : les boutons en sont les enfants, et non ceux
    -- du cadre d'auras lui-même. Il existe sur les clients récents, et c'est le
    -- chemin le plus sûr — un bouton affiché y est, quelle que soit la façon dont
    -- le cadre d'auras le range par ailleurs.
    local container = host.AuraContainer
    if container and container.GetChildren then
        for _, child in ipairs({ container:GetChildren() }) do visit(child) end
    end

    if host.GetChildren then
        for _, child in ipairs({ host:GetChildren() }) do visit(child) end
    end
end

---@param mod table
local function applyHideDebuff(mod)
    showHiddenAuras()

    if not (mod:Get("lustTracker") and mod:Get("hideLustDebuff")) then return end

    local function consider(frame)
        if not (frame and frame.IsShown and frame.Hide and frame:IsShown()) then return end
        if not isSatedFrame(frame) then return end

        frame:Hide()
        hiddenAuras[#hiddenAuras + 1] = frame
    end

    local hosts = auraHosts()
    for i = 1, #hosts do
        forEachAuraFrame(hosts[i], consider)
    end
end

--- S'accroche à la reconstruction des auras du joueur.
---
--- C'est le seul moyen d'être à l'heure, et c'est ce qui manquait : `UNIT_AURA`
--- arrive **avant** que le client n'ait rebâti sa rangée, si bien qu'on masquait
--- un cadre qu'il allait réafficher juste après. Le même piège que les auras de
--- la cible, traité de la même façon (`Modules/DarkMode.lua`).
---
--- `U.GuardedHook` est le seul motif de hook autorisé (règle 6) : posé une fois,
--- il devient inerte quand le module s'éteint.
---@param mod table
local function hookAuraUpdates(mod)
    local guard = function() return mod:IsEnabled() end
    local body  = function() BUI.safecall(applyHideDebuff, mod) end

    -- Trois noms de méthode, parce que le client en a changé : celle qui existe
    -- est branchée, les autres sont sautées.
    local METHODS = { "UpdateAuras", "Update", "UpdateAuraButtons" }

    local hosts = auraHosts()
    for i = 1, #hosts do
        local host = hosts[i]
        if host then
            for m = 1, #METHODS do
                local name = METHODS[m]
                if type(host[name]) == "function" then
                    U.GuardedHook(host, name, body, guard)
                end
            end
        end
    end
end

-- =========================================================================
--  Les deux icônes
-- =========================================================================

--- Image d'un suivi : celle du sort lui-même, demandée au client.
---@param spellID number
---@return number|string|nil
local function spellIcon(spellID)
    if C_Spell and C_Spell.GetSpellTexture then
        return C_Spell.GetSpellTexture(spellID)
    end
    return nil
end

---@param mod table
local function applyBattleRes(mod)
    if not mod:Get("battleResTracker") then
        if resTracker then resTracker:Stop() end
        return
    end

    if not resTracker then
        resTracker = W.IconTracker({
            source   = function() return battleResSource(mod) end,
            isLocked = function() return mod:Get("lockBattleRes") == true end,
            getPos   = function() return mod:Get("battleResX"), mod:Get("battleResY") end,
            setPos   = function(x, y)
                mod:Set("battleResX", x)
                mod:Set("battleResY", y)
            end,
        })
        if not resTracker then return end
        resTracker:SetIcon(spellIcon(BATTLE_RES_SPELL))
    end

    resTracker:SetIconSize(mod:Get("battleResSize"))
    -- Le contour sombre est **son** réglage, pas celui du mode sombre général :
    -- cette icône vit au milieu de l'écran d'un combat de raid, et le choix de
    -- l'y détourer ou non n'a rien à voir avec celui d'assombrir les barres
    -- d'action. Elle se règle donc là où on l'allume.
    resTracker:SetShaded(mod:Get("battleResShaded") == true)
    resTracker:ApplyPosition()
    resTracker:Start()
end

---@param mod table
local function applyLust(mod)
    if not mod:Get("lustTracker") then
        if lustTracker then lustTracker:Stop() end
        showHiddenAuras()
        return
    end

    if not lustTracker then
        lustTracker = W.IconTracker({
            source   = function() return lustSource(mod) end,
            isLocked = function() return mod:Get("lockLust") == true end,
            getPos   = function() return mod:Get("lustX"), mod:Get("lustY") end,
            setPos   = function(x, y)
                mod:Set("lustX", x)
                mod:Set("lustY", y)
            end,
        })
        if not lustTracker then return end
        lustTracker:SetIcon(spellIcon(LUST_ICON_SPELL))
    end

    lustTracker:SetIconSize(mod:Get("lustSize"))
    lustTracker:SetShaded(mod:Get("lustShaded") == true)
    lustTracker:ApplyPosition()
    lustTracker:Start()

    applyHideDebuff(mod)
end

-- =========================================================================
--  Application d'ensemble
-- =========================================================================

---@param mod table
local function applyAll(mod)
    applyBattleRes(mod)
    applyLust(mod)
end

local APPLIERS = {
    battleResTracker = applyBattleRes,
    battleResSize    = applyBattleRes,
    battleResShaded  = applyBattleRes,
    battleResPreview = applyBattleRes,
    lockBattleRes    = applyBattleRes,

    lustTracker    = applyLust,
    lustSize       = applyLust,
    lustShaded     = applyLust,
    lustPreview    = applyLust,
    lockLust       = applyLust,
    hideLustDebuff = applyHideDebuff,
}

-- =========================================================================
--  Déclaration du module
-- =========================================================================

BUI:RegisterModule(MODULE, {
    title    = L["Bloodlust and battle res"],
    category = "MythicRaid",
    order    = 20,

    defaults = {
        battleResTracker = false,
        battleResShaded  = false,
        battleResPreview = false,
        lockBattleRes    = false,
        battleResSize    = T.SIZE.TRACKER_ICON,
        -- Position de l'icône, en décalage de centre à centre. Réglages sans
        -- contrôle : ils se changent en la déplaçant à la souris.
        battleResX = 0,
        battleResY = 0,

        lustTracker    = false,
        lustShaded     = false,
        lustPreview    = false,
        lockLust       = false,
        hideLustDebuff = false,
        lustSize       = T.SIZE.TRACKER_ICON,
        -- Décalée de la largeur d'une icône : les deux suivis allumés ensemble
        -- ne doivent pas se superposer au premier affichage.
        lustX = T.SIZE.TRACKER_ICON + T.SIZE.ROW_GAP,
        lustY = 0,
    },

    options = {
        { type = "header", text = L["Battle resurrections"] },
        {
            type    = "toggle",
            key     = "battleResTracker",
            text    = L["Battle res tracker"],
            tooltip = L["Battle res tracker tip"],
        },
        -- L'aperçu puis le verrou, avant les réglages d'apparence : ce sont les
        -- deux gestes qu'on fait pour **poser** le suivi, et on ne règle sa
        -- taille qu'une fois qu'il est en place et qu'on le voit.
        {
            type     = "toggle",
            key      = "battleResPreview",
            text     = L["Battle res preview"],
            tooltip  = L["Battle res preview tip"],
            disabled = requires("battleResTracker"),
        },
        {
            type     = "toggle",
            key      = "lockBattleRes",
            text     = L["Lock battle res"],
            tooltip  = L["Lock battle res tip"],
            disabled = requires("battleResTracker"),
        },
        {
            type     = "slider",
            key      = "battleResSize",
            text     = L["Battle res size"],
            tooltip  = L["Battle res size tip"],
            min      = T.SIZE.TRACKER_MIN,
            max      = T.SIZE.TRACKER_MAX,
            step     = 2,
            disabled = requires("battleResTracker"),
        },
        {
            type     = "toggle",
            key      = "battleResShaded",
            text     = L["Battle res shaded"],
            tooltip  = L["Battle res shaded tip"],
            disabled = requires("battleResTracker"),
        },

        { type = "header", text = L["Bloodlust"] },
        {
            type    = "toggle",
            key     = "lustTracker",
            text    = L["Lust tracker"],
            tooltip = L["Lust tracker tip"],
        },
        {
            type     = "toggle",
            key      = "lustPreview",
            text     = L["Lust preview"],
            tooltip  = L["Lust preview tip"],
            disabled = requires("lustTracker"),
        },
        {
            type     = "toggle",
            key      = "lockLust",
            text     = L["Lock lust"],
            tooltip  = L["Lock lust tip"],
            disabled = requires("lustTracker"),
        },
        {
            type     = "slider",
            key      = "lustSize",
            text     = L["Lust size"],
            tooltip  = L["Lust size tip"],
            min      = T.SIZE.TRACKER_MIN,
            max      = T.SIZE.TRACKER_MAX,
            step     = 2,
            disabled = requires("lustTracker"),
        },
        {
            type     = "toggle",
            key      = "lustShaded",
            text     = L["Lust shaded"],
            tooltip  = L["Lust shaded tip"],
            disabled = requires("lustTracker"),
        },
        {
            type     = "toggle",
            key      = "hideLustDebuff",
            text     = L["Hide lust debuff"],
            tooltip  = L["Hide lust debuff tip"],
            disabled = requires("lustTracker"),
        },
        { type = "description", text = L["Lust notice"] },
    },

    OnEnable = function(self)
        applyAll(self)
        hookAuraUpdates(self)

        -- Filet de l'accroche ci-dessus : elle traite le moment exact où le
        -- client rebâtit sa rangée, celui-ci rattrape un client qui la rebâtirait
        -- par un chemin qu'on n'a pas su nommer.
        self:RegisterEvent("UNIT_AURA", function(_, unit)
            if unit ~= "player" then return end
            BUI.safecall(applyHideDebuff, self)
        end)

        -- Ce qui décide de l'affichage du suivi des résurrections change au
        -- passage d'une frontière d'instance, et nulle part ailleurs.
        local zoned = function() applyBattleRes(self) end
        self:RegisterEvent("PLAYER_ENTERING_WORLD",    zoned)
        self:RegisterEvent("ZONE_CHANGED_NEW_AREA",    zoned)
        self:RegisterEvent("CHALLENGE_MODE_START",     zoned)
        self:RegisterEvent("CHALLENGE_MODE_COMPLETED", zoned)
        self:RegisterEvent("CHALLENGE_MODE_RESET",     zoned)
    end,

    OnDisable = function()
        if resTracker  then resTracker:Stop()  end
        if lustTracker then lustTracker:Stop() end

        -- Le débuff masqué revient, quoi que dise le réglage : désactiver un
        -- module doit le rendre indétectable (règle 6).
        showHiddenAuras()
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
