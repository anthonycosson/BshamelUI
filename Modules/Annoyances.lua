-- =========================================================================
--  Bshamel UI — Modules/Annoyances.lua
--  Ce que le jeu impose et qu'on préfère ne pas voir.
--
--  Trois choses sans rapport technique, et une seule raison de les rassembler :
--  ce sont les réglages qu'on cherche en se disant « comment je fais taire
--  ça ? ». Elles vivaient dans *Général*, qui n'était pas cet endroit-là.
--  Un palier de migration (`Core/DB.lua`) suit les réglages de ceux qui les
--  avaient changés.
--
--  Réversibilité (règle 6) : la CVar des erreurs Lua retrouve sa valeur d'origine,
--  et les deux hooks de touches passent par `U.GuardedScript`, donc deviennent
--  inertes dès que le module s'éteint. Rien n'est laissé derrière.
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
-- `CancelScene` est en effet **conditionnée à un geste matériel** : appelée
-- depuis un gestionnaire d'événement, elle est refusée. Appelée pendant que le
-- client traite une touche, elle passe. On ne l'appelle donc pas à l'ouverture
-- de la scène : on **arme** une annulation, que la première touche consomme.
--
-- Conséquence assumée : une scène en jeu demande une touche, là où un film s'en
-- va tout seul. C'est une touche au lieu de deux — le client en demandait déjà
-- une pour ouvrir sa demande de confirmation, et une autre pour la confirmer.

--- Annulation en attente d'une touche. Remise à zéro à la fin de la scène :
--- une scène passée ne doit pas laisser un piège armé pour la suivante.
local sceneSkipArmed = false

---@param mod table
local function skipCinematic(mod)
    if not mod:Get("skipCinematics") then return end

    -- Une vraie cinématique s'arrête tout de suite. Les scènes attendent la
    -- touche, faute de quoi le client refuse.
    if CinematicFrame and CinematicFrame.isRealCinematic and StopCinematic then
        StopCinematic()
        return
    end

    sceneSkipArmed = true
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
--  Déclaration du module
-- =========================================================================

BUI:RegisterModule(MODULE, {
    title    = L["Annoyances"],
    category = "QoL",
    order    = 90,

    defaults = {
        skipCinematics  = false,
        hideTalkingHead = false,
        hideLuaErrors   = false,
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
    },

    OnEnable = function(self)
        applyLuaErrors(self)
        hookCinematicKeys(self)

        self:RegisterEvent("CINEMATIC_START", function() skipCinematic(self) end)
        -- Une scène qui se termine sans avoir été coupée ne doit pas laisser son
        -- annulation armée derrière elle.
        self:RegisterEvent("CINEMATIC_STOP",  function() sceneSkipArmed = false end)
        self:RegisterEvent("PLAY_MOVIE",      function() skipMovie(self) end)
        self:RegisterEvent("TALKINGHEAD_REQUESTED", function() hideTalkingHead(self) end)
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
