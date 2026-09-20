-- =========================================================================
--  Bshamel UI — Modules/Annoyances.lua
--  Ce que le jeu impose et qu'on préfère ne pas voir.
--
--  Quatre choses sans rapport technique, et une seule raison de les rassembler :
--  ce sont les réglages qu'on cherche en se disant « comment je fais taire
--  ça ? ». Les trois premières vivaient dans *Général*, qui n'était pas cet
--  endroit-là. Un palier de migration (`Core/DB.lua`) suit les réglages de ceux
--  qui les avaient changés.
--
--  Réversibilité (règle 6) : la CVar des erreurs Lua retrouve sa valeur d'origine,
--  les deux hooks de touches passent par `U.GuardedScript` et celui des toasts
--  par `U.GuardedHook`, donc tous deviennent inertes dès que le module s'éteint.
--  Rien n'est laissé derrière.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local U    = BUI.Util
local L    = ns.L

local MODULE = "Annoyances"

-- =========================================================================
--  CVar
-- =========================================================================
-- On passe par `C_CVar` quand il est là, par les globales sinon : les deux
-- chemins existent, aucun des deux n'est garanti pour toujours.

---@param name string
---@return string|nil
local function getCVar(name)
    if C_CVar and C_CVar.GetCVar then return C_CVar.GetCVar(name) end
    return GetCVar and GetCVar(name) or nil
end

---@param name string
---@param value any
local function setCVar(name, value)
    if C_CVar and C_CVar.SetCVar then
        C_CVar.SetCVar(name, value)
    elseif SetCVar then
        SetCVar(name, value)
    end
end

--- Valeur relevée avant modification. `nil` signifie « on n'a rien changé », ce
--- qui n'est pas la même chose que « la valeur d'origine était vide ».
local savedErrors

local CVAR_ERRORS = "scriptErrors"

-- =========================================================================
--  Erreurs Lua
-- =========================================================================
-- On coupe l'affichage par la CVar du client plutôt qu'en remplaçant le
-- gestionnaire d'erreurs : les erreurs continuent d'arriver aux gestionnaires
-- installés (BugSack et consorts), seule la fenêtre de Blizzard se tait. C'est
-- exactement ce que promet l'infobulle, et c'est réversible.

---@param mod table
local function applyLuaErrors(mod)
    if mod:Get("hideLuaErrors") then
        if savedErrors == nil then savedErrors = getCVar(CVAR_ERRORS) end
        setCVar(CVAR_ERRORS, "0")
    elseif savedErrors ~= nil then
        setCVar(CVAR_ERRORS, savedErrors)
        savedErrors = nil
    end
end

-- =========================================================================
--  Cinématiques et têtes parlantes
-- =========================================================================
-- Trois choses différentes se cachent derrière le mot « cinématique », et elles
-- ne s'arrêtent pas de la même façon. C'est ce qui faisait qu'un seul appel ne
-- suffisait pas — il traitait la plus rare des trois :
--
--   · le **film** (`PLAY_MOVIE`) : une vidéo, que le client sait terminer ;
--   · la **vraie cinématique** (`CinematicFrame.isRealCinematic`) : une séquence
--     précalculée, que `StopCinematic` arrête depuis n'importe où ;
--   · la **scène en jeu** : la caméra prend la main pendant que le monde
--     continue de tourner. C'est aujourd'hui le cas le plus fréquent — presque
--     toutes les scènes de quête — et c'est celui qu'on ne pouvait pas couper.
--
-- On avait cru `CancelScene` **conditionnée à un geste matériel**, et on
-- n'appelait donc rien à l'ouverture de la scène : on armait une annulation que
-- la première touche devait consommer. Relevé en jeu, `CanCancelScene()` rend
-- déjà `true` depuis le gestionnaire de `CINEMATIC_START` — la scène se coupe
-- donc sur-le-champ, sans rien demander au joueur.
--
-- L'armement reste, **derrière** : si le client refusait l'annulation immédiate
-- sans le dire, la première touche la reprendrait. Il ne coûte qu'un booléen, et
-- c'est la différence entre « ça a marché » et « rien ne s'est passé ».

--- Annulation en attente d'une touche. Remise à zéro à la fin de la scène :
--- une scène passée ne doit pas laisser un piège armé pour la suivante.
local sceneSkipArmed = false

---@param mod table
local function skipCinematic(mod)
    if not mod:Get("skipCinematics") then return end

    if CinematicFrame and CinematicFrame.isRealCinematic and StopCinematic then
        StopCinematic()
        return
    end

    -- Une scène en jeu : on l'annule tout de suite si le client le permet, et on
    -- arme quand même. Les deux gestes ne se contredisent pas — une scène déjà
    -- coupée émet `CINEMATIC_STOP`, qui désarme.
    sceneSkipArmed = true

    if CanCancelScene and CanCancelScene() and CancelScene then
        CancelScene()
    end
end

--- Consomme l'annulation armée. Appelée depuis le traitement d'une touche, donc
--- au seul moment où le client accepte de couper une scène.
---@param mod table
local function consumeSceneSkip(mod)
    if not sceneSkipArmed then return end
    if not mod:Get("skipCinematics") then return end
    if not (CinematicFrame and CinematicFrame:IsShown()) then return end

    sceneSkipArmed = false

    if CinematicFrame.isRealCinematic then
        if StopCinematic then StopCinematic() end
    elseif CanCancelScene and CanCancelScene() and CancelScene then
        CancelScene()
    end
end

--- S'accroche aux touches des deux fenêtres de lecture.
---
--- Deux gestes en un : consommer l'annulation armée, et **répondre à la demande
--- de confirmation** que le client ouvre quand on appuie sur Échap. Sans le
--- second, couper une séquence demande toujours deux touches, et le réglage a
--- l'air de ne rien faire à la première.
---
--- `U.GuardedScript` est le seul motif autorisé pour cela (règle 6) : le hook
--- est posé une fois et devient inerte quand le module s'éteint.
---
--- **Se rappelle**, et c'est le point qui manquait. Les deux fenêtres de lecture
--- vivent dans des modules du client chargés à la demande : au moment où le
--- module s'allume, elles n'existent pas encore, et l'appel unique repartait
--- sans rien accrocher. Le réglage n'avait alors aucun effet — pas un effet
--- partiel, aucun. On rappelle donc cette fonction chaque fois qu'une séquence
--- commence, moment où les cadres existent forcément, et la touche qui suit
--- trouve le hook en place.
---@param mod table
local function hookCinematicKeys(mod)
    local guard = function() return mod:IsEnabled() and mod:Get("skipCinematics") end

    ---@param dialog table|nil
    local function confirm(dialog)
        local button = dialog and (dialog.ConfirmButton or dialog.confirmButton)
        if button and button.Click then button:Click() end
    end

    if CinematicFrame then
        U.GuardedScript(CinematicFrame, "OnKeyDown", function()
            consumeSceneSkip(mod)
        end, guard)

        U.GuardedScript(CinematicFrame, "OnKeyUp", function()
            consumeSceneSkip(mod)
            confirm(CinematicFrame.closeDialog)
        end, guard)
    end

    if MovieFrame then
        U.GuardedScript(MovieFrame, "OnKeyUp", function()
            confirm(MovieFrame.CloseDialog)
        end, guard)
    end
end

---@param mod table
local function skipMovie(mod)
    if not mod:Get("skipCinematics") then return end

    if GameMovieFinished then GameMovieFinished() end

    -- Le film s'arrête, mais sa fenêtre peut rester posée par-dessus le monde :
    -- ce qui suit ne coûte rien quand elle est déjà partie.
    if MovieFrame and MovieFrame.Hide then MovieFrame:Hide() end
end

---@param mod table
local function hideTalkingHead(mod)
    if not mod:Get("hideTalkingHead") then return end

    -- La fenêtre est montée après l'événement, et son addon peut n'être chargé
    -- qu'à cet instant : on la ferme au tour suivant, pas tout de suite.
    C_Timer.After(0, function()
        if TalkingHeadFrame_CloseImmediately then
            TalkingHeadFrame_CloseImmediately()
            return
        end
        local frame = TalkingHeadFrame
        if frame and frame.Hide then frame:Hide() end
    end)
end

-- =========================================================================
--  Pierres d'accès
-- =========================================================================
-- Chaque boss de donjon tué « découvre » une pierre d'accès — le point de
-- contrôle où l'on ressuscite et se téléporte — et le serveur l'annonce par une
-- bannière plein écran, à chaque boss, sans réglage pour la taire.
--
-- L'annonce est un **toast d'événement** : le serveur pousse une entrée dans la
-- file de `EventToastManagerFrame`, qui l'affiche sur `DISPLAY_EVENT_TOASTS`.
-- Son identité stable est son `eventToastID`, relevé en jeu par sonde (voir
-- `dev/docs/API_NOTES.md`) : le libellé change avec la langue, l'identifiant
-- non. Le toast du début de donjon (« Le val Aveuglant », ID 5) et tous les
-- autres passent sans être touchés.

--- L'annonce « Découverte : pierre d'accès », et elle seule.
local WAYSTONE_TOAST_ID = 288

--- Ferme l'annonce de pierre d'accès à l'instant où elle s'ouvre.
---
--- Appelée juste après `DisplayToast` du client, donc quand le toast à juger
--- est en place mais pas encore peint : le fermer ici ne laisse rien à voir.
---
--- Le geste est **celui du clic droit du client**, repris à l'identique
--- (`EventToastManagerFrameMixin:OnMouseDown`) : `CloseActiveToasts` puis
--- `Hide`. C'est un état que le client atteint lui-même à chaque toast
--- congédié — sa file continue proprement — et c'est aussi pourquoi il n'y a
--- rien à restaurer : hook inerte, l'annonce revient.
local function muzzleWaystoneToast()
    local frame = EventToastManagerFrame
    local toast = frame and frame.currentDisplayingToast
    local info  = toast and toast.toastInfo
    local id    = info and info.eventToastID

    -- Garde de secret avant toute comparaison, comme partout : un identifiant
    -- protégé vaut « pas le nôtre », et l'annonce s'affiche plutôt que de lever.
    if U.IsSecret(id) or id ~= WAYSTONE_TOAST_ID then return end

    if frame.CloseActiveToasts then frame:CloseActiveToasts() end
    frame:Hide()
end

--- Pose le hook sur l'affichage des toasts, une fois pour toutes.
---
--- Sur l'affichage et non sur `DISPLAY_EVENT_TOASTS` : l'événement n'accompagne
--- que le **premier** toast d'une salve. Ceux qui attendent en file — la pierre
--- d'accès derrière l'annonce du donjon, par exemple — s'affichent quand le
--- précédent se termine, sans nouvel événement, et un abonnement les aurait
--- laissés passer. `DisplayToast` est le point par où tous sortent.
---
--- `U.GuardedHook` est le seul motif autorisé pour un hook (règle 6) : posé une
--- fois, il devient inerte quand le module ou l'option s'éteint.
---@param mod table
local function hookWaystoneToast(mod)
    if not EventToastManagerFrame then return end

    U.GuardedHook(EventToastManagerFrame, "DisplayToast", muzzleWaystoneToast,
        function() return mod:IsEnabled() and mod:Get("hideWaystoneToast") end)
end

-- =========================================================================
--  Déclaration du module
-- =========================================================================

BUI:RegisterModule(MODULE, {
    title    = L["Annoyances"],
    category = "QoL",
    order    = 90,

    defaults = {
        skipCinematics    = false,
        hideTalkingHead   = false,

        -- **Troisième exception au « aucun défaut ne vaut vrai »** (CLAUDE.md
        -- §4), et la plus discutable des trois : celle-ci ne montre pas
        -- l'addon et ne répare pas le client, elle éteint quelque chose.
        --
        -- L'examen, écrit pour qu'on puisse le contester. Ce que cette case
        -- éteint n'est pas une fonction du jeu, c'est **le rapport d'une
        -- panne** : la fenêtre rouge ne fait rien arriver, elle signale ce qui
        -- est déjà arrivé. Et elle le signale à qui n'en fera rien — un joueur
        -- ne corrige pas l'erreur Lua d'un addon, il la ferme. Le seul geste
        -- qu'elle lui laisse est celui qu'il ferait de toute façon.
        --
        -- Rien n'est perdu pour autant : on coupe la CVar du client, pas les
        -- gestionnaires d'erreurs. BugSack et ses pareils reçoivent tout, et
        -- qui veut la fenêtre de Blizzard décoche la case.
        --
        -- La limite reste nette : la marque va sur ce qui **tait un
        -- symptôme**, jamais sur ce qui change une règle du jeu. Une case qui
        -- sauterait des cinématiques ou parlerait à la place du joueur ne
        -- l'aura pas.
        hideLuaErrors     = true,  -- @default-on

        hideWaystoneToast = false,
    },

    -- Pas d'intitulé de section : la page s'appelle déjà « Nuisances », et le
    -- répéter juste en dessous donne une page qui a l'air cassée.
    options = {
        {
            type    = "toggle",
            key     = "skipCinematics",
            text    = L["Skip cinematics"],
            tooltip = L["Skip cinematics tip"],
        },
        {
            type    = "toggle",
            key     = "hideTalkingHead",
            text    = L["Hide talking heads"],
            tooltip = L["Hide talking heads tip"],
        },
        {
            type    = "toggle",
            key     = "hideLuaErrors",
            text    = L["Hide Lua errors"],
            tooltip = L["Hide Lua errors tip"],
        },
        {
            type    = "toggle",
            key     = "hideWaystoneToast",
            text    = L["Hide waystone discoveries"],
            tooltip = L["Hide waystone discoveries tip"],
        },
    },

    OnEnable = function(self)
        applyLuaErrors(self)
        hookCinematicKeys(self)

        -- Les cadres de lecture arrivent avec leur module du client : on
        -- retente l'accroche à chaque chargement, et de nouveau au début de
        -- chaque séquence — là, ils existent forcément.
        self:RegisterEvent("ADDON_LOADED", function() hookCinematicKeys(self) end)

        self:RegisterEvent("CINEMATIC_START", function()
            hookCinematicKeys(self)
            skipCinematic(self)
        end)
        -- Une scène qui se termine sans avoir été coupée ne doit pas laisser son
        -- annulation armée derrière elle.
        self:RegisterEvent("CINEMATIC_STOP",  function() sceneSkipArmed = false end)
        self:RegisterEvent("PLAY_MOVIE",      function()
            hookCinematicKeys(self)
            skipMovie(self)
        end)
        self:RegisterEvent("TALKINGHEAD_REQUESTED", function() hideTalkingHead(self) end)

        hookWaystoneToast(self)
    end,

    OnDisable = function()
        if savedErrors ~= nil then
            setCVar(CVAR_ERRORS, savedErrors)
            savedErrors = nil
        end
        sceneSkipArmed = false
    end,

    OnSettingChanged = function(self, key)
        if key == nil or key == "hideLuaErrors" then applyLuaErrors(self) end
    end,
})
