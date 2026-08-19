-- =========================================================================
--  Bshamel UI — Modules/PvP.lua
--  Ce qu'on regarde quand l'adversaire est un joueur.
--
--  Une seule chose pour l'instant, et c'est la plus chère : **le soigneur du
--  groupe est sous contrôle**. En arène comme en donjon, c'est l'information qui
--  décide de la seconde qui suit — on pousse, on temporise, on brise l'entrave —
--  et le jeu ne la montre nulle part. Elle est écrite au milieu d'un cadre de
--  groupe, dans une rangée d'auras haute de quinze pixels, à côté de six autres.
--
--  **Le groupe, pas le raid.** Le module lit `party1` à `party4` et rien
--  d'autre : c'est là que vivent l'arène, le donjon et le groupe extérieur. Un
--  raid n'a pas un soigneur mais cinq, une alerte qui ne dit pas lequel ne dit
--  rien, et un champ de bataille est un raid — d'où son absence de la liste des
--  lieux.
--
--  Ce que le module dessine tient en une rangée d'icônes posée sur l'écran :
--  l'entrave elle-même, avec son horloge. Pas de texte. L'icône d'un
--  Métamorphose dit « métamorphose » plus vite qu'une phrase, et elle le dit
--  dans la langue du joueur sans qu'on ait rien à traduire.
--
--  Réversibilité (règle 6) : la rangée se cache, la lueur s'arrête, et il ne
--  reste rien — le module ne touche à aucun cadre du jeu.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local U    = BUI.Util
local W    = BUI.Widgets
local L    = ns.L

local MODULE = "PvP"

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
--  Qui est le soigneur, et où l'on regarde
-- =========================================================================

--- Les jetons d'un groupe, écrits une fois. Les concaténer à chaque passage
--- allouerait quatre chaînes par événement d'aura (règle 7).
local PARTY_UNITS = { "party1", "party2", "party3", "party4" }

--- Le réglage de lieu qui commande, par type d'instance. Ce que la table ne
--- nomme pas — raid, champ de bataille, scénario — n'est pas offert : le module
--- ne lit que des jetons de groupe, et ces contenus-là n'en ont pas.
local PLACE_KEY = {
    arena = "inArena",
    party = "inDungeon",
}

--- Le réglage de lieu en vigueur ici, ou `nil` là où le module ne s'affiche pas.
---@return string|nil
local function placeKey()
    if not GetInstanceInfo then return "inWorld" end

    local _, kind = GetInstanceInfo()
    if U.IsSecret(kind) then return nil end
    if kind == nil or kind == "none" then return "inWorld" end

    return PLACE_KEY[kind]
end

--- L'unité existe-t-elle ? Une réponse secrète compte pour « oui » : c'est le
--- rôle, juste en dessous, qui écarte ce qui n'a rien à faire ici, et écarter
--- une unité sur un secret reviendrait à perdre un vrai soigneur.
---@param unit string
---@return boolean
local function exists(unit)
    local answer = UnitExists(unit)
    if U.IsSecret(answer) then return true end
    return answer ~= nil and answer ~= false
end

--- Le rôle assigné, et rien d'autre. Une réponse secrète compte pour « non » :
--- ici l'erreur inverse coûte plus cher — un rôle qu'on ne sait pas lire ferait
--- de tout le groupe des soigneurs, et la rangée montrerait les entraves de
--- quatre personnes dont trois n'en sont pas une.
---@param unit string
---@return boolean
local function isHealer(unit)
    local role = UnitGroupRolesAssigned(unit)
    if U.IsSecret(role) then return false end
    return role == "HEALER"
end

--- Le module a-t-il quelque chose à regarder, ici et maintenant ?
---@param mod table
---@return boolean
local function watching(mod)
    if not mod:Get("healerCC") then return false end

    local key = placeKey()
    if not (key and mod:Get(key)) then return false end

    -- `IsInRaid` avant `IsInGroup` : un raid **est** un groupe, et c'est le
    -- raid qu'on écarte. Un champ de bataille passe par là.
    if U.IsTrue(IsInRaid()) then return false end

    return U.IsTrue(IsInGroup())
end

-- =========================================================================
--  Les entraves du soigneur
-- =========================================================================
-- La lecture est celle des barres d'infos, et pour la même raison : le filtre
-- classé du client (`HARMFUL|CROWD_CONTROL`) sait mieux que nous ce qui
-- immobilise, et il n'exige de lire aucune valeur. Ce qu'on relève de l'aura est
-- **son icône**, qui peint juste même secrète, et son horloge, qui est un objet
-- opaque que le balayage consomme tel quel (voir `dev/docs/API_NOTES.md`).

--- Liste de travail rendue au widget, et son bornage. Réutilisée : elle se
--- remplit à chaque événement d'aura du groupe (règle 7).
local list = { n = 0, max = T.SIZE.HEALER_CC_MAX }

--- Les auras d'une unité pour un filtre, ou `nil` si le client refuse le filtre.
---@param unit string
---@param filter string
---@return table|nil
local function bulkAuras(unit, filter)
    if not (C_UnitAuras and C_UnitAuras.GetUnitAuras) then return nil end

    local ok, auras = pcall(C_UnitAuras.GetUnitAuras, unit, filter)
    if not ok or type(auras) ~= "table" then return nil end

    return auras
end

--- Range une aura dans la liste, si elle a encore de la place.
---
--- **Une valeur secrète se transmet, elle ne s'inspecte pas.** L'icône est le
--- seul champ dont on ait besoin, et elle peint l'image exacte quand on la passe
--- telle quelle : absente, elle ne peint rien — c'est le seul refus.
---@param unit string
---@param aura table
local function admit(unit, aura)
    if list.n >= list.max then return end

    local icon = aura.icon
    if not U.IsSecret(icon) and icon == nil then return end

    -- Le garde vient **avant** le premier test : sans lui, `if id` suffirait à
    -- lever sur un identifiant secret. Illisible, on perd l'horloge de cette
    -- aura-là, pas la rangée.
    local id = not U.IsSecret(aura.auraInstanceID) and aura.auraInstanceID or nil

    local durationObject
    if id and C_UnitAuras.GetAuraDuration then
        local ok, answer = pcall(C_UnitAuras.GetAuraDuration, unit, id)
        if ok then durationObject = answer end
    end

    local n = list.n + 1
    local entry = list[n]
    if not entry then entry = {} list[n] = entry end

    entry.icon           = icon
    entry.kind           = "CC"
    entry.count          = nil
    entry.durationObject = durationObject
    -- Les deux nombres sont ceux de l'aperçu : une entrée réutilisée les
    -- porterait encore, et le balayage repartirait sur une durée inventée.
    entry.duration       = nil
    entry.expirationTime = nil

    list.n = n
end

--- Remplit la liste avec les entraves de tous les soigneurs du groupe.
---
--- Tous, et non le premier : un groupe de cinq n'en a qu'un, mais une arène en
--- trois contre trois peut en avoir deux, et une rangée qui n'en montrerait
--- qu'un mentirait précisément le jour où les deux sont pris.
local function collect()
    list.n = 0

    for i = 1, #PARTY_UNITS do
        local unit = PARTY_UNITS[i]

        if exists(unit) and isHealer(unit) then
            local auras = bulkAuras(unit, "HARMFUL|CROWD_CONTROL")
            if auras then
                for a = 1, #auras do
                    admit(unit, auras[a])
                end
            end
        end
    end
end

-- =========================================================================
--  L'aperçu
-- =========================================================================
-- Une entrave d'exemple, prise **dans la liste des contrôles** pour qu'elle
-- passe par le même classement qu'une vraie. Sans lui, on règle la taille et la
-- position d'une icône qu'on n'a encore jamais vue : elle n'apparaît que le jour
-- où le soigneur est pris, c'est-à-dire au pire moment pour la déplacer.

--- Métamorphose : l'entrave que tout le monde reconnaît, et sa durée pleine est
--- assez longue pour qu'un balayage se lise.
local SAMPLE_SPELL = 118

--- L'exemple **repart** à chaque cycle. Sans cela il s'éteint au bout de sa
--- durée et ne revient jamais : on règle alors une icône sans horloge, ce qui
--- est justement ce que l'aperçu doit montrer.
local function fillSample()
    list.n = 0

    if not (C_Spell and C_Spell.GetSpellTexture) then return end

    local icon = C_Spell.GetSpellTexture(SAMPLE_SPELL)
    if not icon then return end

    local entry = list[1]
    if not entry then entry = {} list[1] = entry end

    local cycle = T.TIMING.PLATE_AURA_CYCLE

    entry.icon           = icon
    entry.kind           = "CC"
    entry.count          = nil
    -- L'inverse de `admit` : ici l'horloge est à nous, donc deux nombres, et pas
    -- d'objet de durée à traîner d'un passage à l'autre.
    entry.durationObject = nil
    entry.duration       = cycle
    entry.expirationTime = GetTime() + cycle

    list.n = 1
end

-- =========================================================================
--  L'affichage
-- =========================================================================

---@type table|nil
local panel
---@type table|nil
local row
---@type table|nil
local glow
---@type table|nil
local sampleTicker
---@type table|nil
local tintTicker

--- Y avait-il quelque chose à l'écran au passage précédent ? C'est ce qui fait
--- du son une **alerte** : il se joue au moment où l'entrave tombe, pas à chaque
--- fois que le client réannonce les auras du soigneur.
local wasShowing = false

---@param mod table
local function playAlert(mod)
    if not mod:Get("healerCCSound") then return end

    T.PlayAlertSound()
end

---@param mod table
local function build(mod)
    if panel then return end

    panel = W.Panel({
        width    = T.SIZE.HEALER_CC_ICON,
        height   = T.SIZE.HEALER_CC_ICON,
        chrome   = "none",
        getPos   = function() return mod:Get("healerCCX"), mod:Get("healerCCY") end,
        setPos   = function(x, y)
            mod:Set("healerCCX", x)
            mod:Set("healerCCY", y)
        end,
        isLocked = function() return mod:Get("lockHealerCC") == true end,
    })

    -- La rangée se centre sur le panneau : c'est le panneau qu'on déplace, et il
    -- doit grandir autour de son centre quand une seconde entrave s'ajoute, pas
    -- s'étendre vers la droite en laissant le point posé derrière lui.
    row = W.AuraRow(panel)
    if row then
        row:ClearAllPoints()
        row:SetPoint("CENTER", panel, "CENTER", 0, 0)

        -- **Pas de balayage sombre.** Il tourne dans l'image du sort et
        -- l'assombrit d'autant : sur une barre de nom, où l'icône est petite et
        -- se lit de loin, c'est ce qui dit qu'une aura s'achève. Ici le chiffre
        -- le dit déjà, en couleur et en gros — le balayage ne ferait que salir
        -- l'icône qu'on veut reconnaître.
        --
        -- La couleur du décompte à la place : celle du décompte d'une file
        -- d'attente, verte au départ et rouge à l'échéance.
        -- **Ni liseré non plus.** Il dit la nature de l'aura, et ici tout est
        -- entrave : ce ne serait qu'un cadre bleu autour d'une icône de sort,
        -- là où le jeu n'en met jamais.
        --
        -- `scaled` : la rangée suit l'échelle du panneau. C'est ce qui la rend
        -- de la **même taille physique** que lui — sans quoi elle est dessinée
        -- en pixels d'écran pendant que le panneau vit à l'échelle de
        -- l'interface, donc plus grande que lui, et tout ce qui se mesure sur le
        -- panneau tombe à l'intérieur des icônes.
        W.AuraRowStyle(row, {
            swipe  = false,
            edge   = false,
            tint   = true,
            scaled = true,
        })

        -- Elle ne repeint que des couleurs, sur quatre vignettes au plus, et
        -- seulement quand une entrave est à l'écran : c'est le prix d'un
        -- décompte qui change de teinte au lieu de rester blanc.
        tintTicker = W.Ticker(T.TIMING.COUNTDOWN, function()
            if row and row:IsShown() then W.AuraRowTint(row) end
        end)
    end

    -- La lueur de l'addon, la même que celle de la rangée de ressource de classe
    -- (`UI/Widgets/TrackGlow.lua`). Posée sur le panneau et non sur chaque
    -- icône : ce qui alerte est « le soigneur est pris », pas « cette entrave-ci
    -- plutôt que celle-là ».
    --
    -- Elle est **au-dessus de la rangée**, qui se pose dix crans au-dessus de son
    -- parent (`W.AuraRow`) : un contour dessiné au ras des icônes passerait
    -- sinon dessous, et on ne verrait rien.
    glow = W.TrackGlow(panel, {
        outset    = T.SIZE.HEALER_CC_GLOW_OUT,
        thickness = T.SIZE.HEALER_CC_GLOW_TH,
    })

    local rowLevel = row and row:GetFrameLevel()
    if type(rowLevel) == "number" and not U.IsSecret(rowLevel) then
        glow:SetFrameLevel(rowLevel + 1)
    end
end

--- Repeint la rangée et rend le nombre d'icônes affichées.
---@param mod table
---@return number
local function paint(mod)
    if not (panel and row) then return 0 end

    local side = U.Clamp(mod:Get("healerCCSize") or T.SIZE.HEALER_CC_ICON,
                         T.SIZE.TRACKER_MIN, T.SIZE.TRACKER_MAX)
    local gap  = T.SIZE.HEALER_CC_GAP

    local timer = U.Clamp(mod:Get("healerCCTimerSize") or T.SIZE.HEALER_CC_TIMER,
                          T.SIZE.HEALER_CC_TIMER_MIN, T.SIZE.HEALER_CC_TIMER_MAX)

    W.AuraRowSet(row, list, side, gap, timer, false)

    local shown = math.min(list.n, list.max)
    if shown <= 0 then
        panel:Hide()
        return 0
    end

    -- La taille du panneau se **calcule**, elle ne se relève pas sur la rangée :
    -- les deux nombres viennent d'être posés par la ligne ci-dessus, et les
    -- relire ne ferait qu'ajouter deux lectures à un chemin qui bat.
    --
    -- La **position**, elle, ne se repose pas ici : le panneau est ancré par son
    -- centre, une seconde entrave l'élargit donc sans le déplacer — et un
    -- repositionnement qui tomberait au milieu d'un glissé ramènerait le
    -- panneau sous le curseur à l'endroit d'où on essaie de le sortir.
    panel:SetSize(shown * side + (shown - 1) * gap, side)
    panel:Show()

    return shown
end

--- Un passage complet : ce qu'il y a à montrer, puis la lueur et le son.
---@param mod table
local function refresh(mod)
    if not panel then return end

    local previewing = mod:Get("healerCC") and mod:Get("healerCCPreview")

    if previewing then
        fillSample()
    elseif watching(mod) then
        collect()
    else
        list.n = 0
    end

    local shown = paint(mod)

    if glow then
        -- Le contour se repose à chaque passage : il est celui du panneau, qui
        -- s'élargit d'une icône quand une seconde entrave tombe.
        glow:SetTrack(panel:GetWidth(), panel:GetHeight())
        glow:SetRunning(shown > 0 and mod:Get("healerCCGlow") == true)
    end

    -- L'aperçu ne sonne pas : il tourne en boucle, et une alerte qui se répète
    -- toutes les quinze secondes pendant qu'on règle une position n'alerte plus
    -- de rien. Le son se fait entendre en cochant sa case, une fois.
    if shown > 0 and not wasShowing and not previewing then
        playAlert(mod)
    end

    -- La couleur du décompte suit ce qu'il reste, et ce qu'il reste diminue
    -- sans qu'aucun événement ne le dise : elle a sa propre minuterie, armée
    -- exactement tant qu'il y a une icône à colorer.
    if tintTicker then tintTicker:SetShown(shown > 0) end

    wasShowing = shown > 0
end

--- Arme ou range la minuterie de l'aperçu.
---@param mod table
local function applySample(mod)
    local wanted = mod:Get("healerCC") and mod:Get("healerCCPreview")

    if not wanted then
        if sampleTicker then sampleTicker:Hide() end
        return
    end

    sampleTicker = sampleTicker or W.Ticker(T.TIMING.PLATE_AURA_CYCLE, function()
        local mine = BUI.Modules:Get(MODULE)
        if mine and mine:IsEnabled() then BUI.safecall(refresh, mine) end
    end)

    if sampleTicker then sampleTicker:Show() end
end

--- Rend l'écran tel qu'il était : la rangée se cache, la lueur s'arrête. Rien
--- d'autre n'a été touché (règle 6).
local function teardown()
    if sampleTicker then sampleTicker:Hide() end
    if tintTicker   then tintTicker:Hide()   end
    if glow then glow:SetRunning(false) end
    if row then row:Hide() end
    if panel then panel:Hide() end
    wasShowing = false
end

---@param mod table
local function apply(mod)
    -- Les cadres ne se montent qu'une fois l'alerte allumée : ils ne se
    -- détruisent pas en World of Warcraft (règle 7), et un joueur qui n'ouvrira
    -- jamais cette page n'a aucune raison d'en porter trois.
    if not mod:Get("healerCC") then
        teardown()
        return
    end

    build(mod)
    if not panel then return end

    panel:ApplyLock()
    applySample(mod)
    refresh(mod)
end

-- =========================================================================
--  Déclaration du module
-- =========================================================================

BUI:RegisterModule(MODULE, {
    title    = L["PvP"],
    category = "MythicRaid",
    order    = 25,

    defaults = {
        healerCC        = false,
        healerCCPreview = false,
        lockHealerCC    = false,
        healerCCGlow    = false,
        healerCCSound   = false,
        healerCCSize    = T.SIZE.HEALER_CC_ICON,
        healerCCTimerSize = T.SIZE.HEALER_CC_TIMER,
        -- Position de la rangée, en décalage de centre à centre. Réglages sans
        -- contrôle : ils se changent en la déplaçant à la souris.
        healerCCX = 0,
        healerCCY = 0,

        -- Les lieux. Tous éteints, comme tout le reste : l'interrupteur du
        -- dessus ne fait donc rien tant qu'on n'a pas dit où (règle 4). C'est
        -- son libellé qui le dit, pas un défaut qui déciderait à la place.
        inWorld   = false,
        inDungeon = false,
        inArena   = false,
    },

    options = {
        { type = "header", text = L["Healer crowd control"] },
        {
            type    = "toggle",
            key     = "healerCC",
            text    = L["Healer CC alert"],
            tooltip = L["Healer CC alert tip"],
        },
        -- L'aperçu puis le verrou avant l'apparence : ce sont les deux gestes
        -- qu'on fait pour **poser** la rangée, et on ne règle sa taille qu'une
        -- fois qu'elle est en place et qu'on la voit.
        {
            type     = "toggle",
            key      = "healerCCPreview",
            text     = L["Healer CC preview"],
            tooltip  = L["Healer CC preview tip"],
            disabled = requires("healerCC"),
        },
        {
            type     = "toggle",
            key      = "lockHealerCC",
            text     = L["Lock healer CC"],
            tooltip  = L["Lock healer CC tip"],
            disabled = requires("healerCC"),
        },
        {
            type     = "slider",
            key      = "healerCCSize",
            text     = L["Healer CC size"],
            tooltip  = L["Healer CC size tip"],
            min      = T.SIZE.TRACKER_MIN,
            max      = T.SIZE.TRACKER_MAX,
            step     = 2,
            disabled = requires("healerCC"),
        },
        {
            type     = "slider",
            key      = "healerCCTimerSize",
            text     = L["Healer CC timer size"],
            tooltip  = L["Healer CC timer size tip"],
            min      = T.SIZE.HEALER_CC_TIMER_MIN,
            max      = T.SIZE.HEALER_CC_TIMER_MAX,
            step     = 1,
            disabled = requires("healerCC"),
        },
        {
            type     = "toggle",
            key      = "healerCCGlow",
            text     = L["Healer CC glow"],
            tooltip  = L["Healer CC glow tip"],
            disabled = requires("healerCC"),
        },
        {
            type     = "toggle",
            key      = "healerCCSound",
            text     = L["Healer CC sound"],
            tooltip  = L["Healer CC sound tip"],
            disabled = requires("healerCC"),
        },

        { type = "header", text = L["Healer CC places"] },
        {
            type     = "toggle",
            key      = "inWorld",
            text     = L["Healer CC outdoors"],
            tooltip  = L["Healer CC outdoors tip"],
            disabled = requires("healerCC"),
        },
        {
            type     = "toggle",
            key      = "inDungeon",
            text     = L["Healer CC dungeons"],
            tooltip  = L["Healer CC dungeons tip"],
            disabled = requires("healerCC"),
        },
        {
            type     = "toggle",
            key      = "inArena",
            text     = L["Healer CC arenas"],
            tooltip  = L["Healer CC arenas tip"],
            disabled = requires("healerCC"),
        },
    },

    --- `/bui pvp` : ce que le client publie de la lueur et du son, et ce que le
    --- module en a retenu.
    ---
    --- Rien de tout cela ne se voit depuis le jeu. Un son qui ne se joue pas a
    --- deux causes qui se ressemblent — le nom rangé ne désigne plus rien, ou
    --- l'addon qui prêtait le fichier n'est plus là — et une lueur éteinte peut
    --- l'être parce qu'il n'y a rien à entourer. Même motif que `/bui glow` et
    --- `/bui auras` : la prose est traduite, les noms d'API sont bruts, parce
    --- que c'est sous ce nom-là qu'on les cherche.
    DiagnosePvP = function(self)
        self:Print(L["PvP diagnostic"])

        self:Print(L["PvP diagnostic glow built"],
            glow and L["On"] or L["Off"],
            "—", L["PvP diagnostic glow lit"],
            (glow and glow:IsShown()) and L["On"] or L["Off"])

        -- Les trois cadres empilés, avec leur échelle **effective**. C'est le
        -- seul moyen de voir qu'ils ne vivent pas dans le même espace : trois
        -- largeurs identiques à des échelles différentes ne font pas trois
        -- cadres de même taille à l'écran, et c'est exactement le défaut qui a
        -- fait passer la lueur sous les icônes.
        local function measure(label, frame)
            if not frame then return end

            local w = frame:GetWidth()
            local s = frame:GetEffectiveScale()
            if U.IsSecret(w) or U.IsSecret(s) then return end

            self:Print(label, string.format("%.0f x%.2f -> %.0f px", w, s, w * s))
        end

        measure(L["PvP diagnostic panel"], panel)
        measure(L["PvP diagnostic row"],   row)
        measure(L["PvP diagnostic glow"],  glow)

        -- Les quatre chemins du son, écrits dans l'ordre exact où ils sont
        -- essayés (voir `T.ALERT_SOUND`). Le premier qui répond est celui qu'on
        -- entend ; aucun ne répondant, c'est l'avertissement de raid.
        self:Print(L["PvP diagnostic sound file"], T.ALERT_SOUND.Own)

        self:Print("LibSharedMedia-3.0:", T.SharedMedia() and L["On"] or L["Off"],
            "->", tostring(T.SharedMediaSound(T.ALERT_SOUND.Media)))

        for i = 1, #T.ALERT_SOUND.Files do
            self:Print(L["PvP diagnostic sound file"], T.ALERT_SOUND.Files[i])
        end
    end,

    OnEnable = function(self)
        BUI.safecall(apply, self)

        -- Le seul événement qui apporte une entrave.
        --
        -- **Filtré sur le soigneur, pas sur le groupe.** Le client émet
        -- `UNIT_AURA` pour tout ce qu'il affiche, et les auras d'un tank en
        -- combat changent plusieurs fois par seconde pour rien : ce test, qui ne
        -- coûte qu'une lecture de rôle, retire l'essentiel du trafic d'un chemin
        -- qui bat (règle 7).
        --
        -- Ce qui reste n'est **ni bridé ni amorti**, et c'est voulu : une alerte
        -- amortie arrive après la seconde qu'elle devait faire gagner, et une
        -- alerte bridée s'éteint en retard — la rangée resterait affichée après
        -- la fin de l'entrave.
        self:RegisterEvent("UNIT_AURA", function(_, unit)
            if not unit then return end

            for i = 1, #PARTY_UNITS do
                if unit == PARTY_UNITS[i] then
                    if isHealer(unit) then BUI.safecall(refresh, self) end
                    return
                end
            end
        end)

        -- Ce qui décide de **qui** est le soigneur, et de savoir si l'on est
        -- encore dans un endroit où le module parle.
        local again = function() BUI.safecall(refresh, self) end
        self:RegisterEvent("GROUP_ROSTER_UPDATE",   again)
        self:RegisterEvent("PLAYER_ROLES_ASSIGNED", again)
        self:RegisterEvent("PLAYER_ENTERING_WORLD", again)
        self:RegisterEvent("ZONE_CHANGED_NEW_AREA", again)
    end,

    OnDisable = function()
        BUI.safecall(teardown)
    end,

    OnSettingChanged = function(self, key)
        -- Le son se fait entendre en cochant sa case : c'est la seule façon de
        -- savoir ce qu'on vient d'allumer sans attendre qu'un soigneur soit pris.
        if key == "healerCCSound" and self:Get("healerCCSound") then
            BUI.safecall(playAlert, self)
        end

        BUI.safecall(apply, self)
    end,
})
