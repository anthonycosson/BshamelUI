-- =========================================================================
--  Bshamel UI — Modules/Chat.lua
--  Quatre conforts autour des fenêtres de chat du client.
--
--  Le fil commun : **on ne remplace pas le chat de Blizzard**. Ses onglets, son
--  arrimage, ses filtres et ses couleurs restent les siens ; ce module ajoute
--  quatre choses par-dessus, et chacune se retire (CLAUDE.md règle 6) :
--
--    - l'historique est **relu** dans les fenêtres du client, jamais stocké
--      ailleurs qu'au format qu'elles ont affiché ;
--    - la poignée de hauteur pilote le redimensionnement du client et lui fait
--      ranger la nouvelle taille, de sorte qu'elle survive sans nous ;
--    - les couleurs passent par `ChangeChatColor`, avec les originales relevées
--      avant d'y toucher ;
--    - la copie lit ce que la fenêtre affiche et n'y écrit rien.
--
--  Le module n'est **pas** `secure` : une fenêtre de chat n'est pas une frame
--  protégée, et rien ici ne touche à un bouton de sort.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local U    = BUI.Util
local W    = BUI.Widgets
local L    = ns.L

local MODULE = "Chat"

-- =========================================================================
--  Les fenêtres qu'on gère
-- =========================================================================

--- Applique `fn(frame, index)` à chaque fenêtre de chat permanente.
---
--- Les fenêtres **temporaires** — chuchotements détachés, dialogues de PNJ —
--- sont écartées : elles naissent et meurent en cours de session, si bien que
--- rien de ce qu'on poserait dessus ne durerait, et leur numéro est réattribué
--- à la suivante, ce qui mélangerait les historiques.
---@param fn fun(frame: table, index: integer)
local function eachChatFrame(fn)
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local frame = _G["ChatFrame" .. i]
        if frame and not frame.isTemporary then fn(frame, i) end
    end
end

-- =========================================================================
--  Historique
-- =========================================================================
-- On relève ce que la fenêtre **affiche**, au moment où elle l'affiche, et non
-- les événements de discussion. C'est le seul relevé qui soit juste : le texte
-- d'une ligne de chat est le produit des réglages du joueur (horodatage, noms
-- de classe colorés, numéros de canal) et des filtres posés par les autres
-- addons. Le refabriquer à partir de `CHAT_MSG_*` donnerait une histoire qui ne
-- ressemble pas à celle qu'on a lue.

--- Lignes conservées par fenêtre. Assez pour retrouver une conversation perdue
--- dans un rechargement, pas assez pour peser dans le SavedVariables.
local HISTORY_LINES = 128

--- Vrai pendant qu'on rejoue l'historique : le relevé doit alors se taire,
--- sans quoi chaque session recopierait la précédente dans la suivante.
local restoring = false

--- Une seule restitution par session, quoi qu'il arrive ensuite au réglage.
local restored = false

---@param mod table
---@param index integer
---@return table
local function historyFor(mod, index)
    local data = mod:CharData()
    data.history = data.history or {}

    local list = data.history[index]
    if not list then
        list = {}
        data.history[index] = list
    end
    return list
end

--- Range une ligne affichée.
---
--- Une table par ligne, et c'est assumé : le chat n'est pas un chemin chaud au
--- sens de la règle 7 — quelques messages par seconde au pire, contre plusieurs
--- centaines d'événements pour le journal de combat.
---@param mod table
---@param index integer
---@param text string
---@param r? number
---@param g? number
---@param b? number
local function capture(mod, index, text, r, g, b)
    if restoring then return end

    -- L'ordre des deux tests n'est pas indifférent : une chaîne **secrète** a
    -- bien le type `string`, et c'est la comparaison suivante qui lèverait. Le
    -- client rend le texte d'une ligne en valeur secrète dès que notre hook a
    -- teinté l'exécution ; cette ligne-là n'entre pas dans l'historique, et rien
    -- de secret ne part dans le SavedVariables.
    if type(text) ~= "string" or U.IsSecret(text) or text == "" then return end

    local list = historyFor(mod, index)
    list[#list + 1] = {
        text = text,
        r = type(r) == "number" and r or nil,
        g = type(g) == "number" and g or nil,
        b = type(b) == "number" and b or nil,
    }

    while #list > HISTORY_LINES do
        table.remove(list, 1)
    end
end

--- Pose le relevé sur chaque fenêtre.
---
--- `U.GuardedHook` est le seul motif de hook autorisé (règle 6) : posé une fois,
--- rendu inerte par sa garde quand le module s'éteint ou que le réglage retombe.
---@param mod table
local function hookCapture(mod)
    local guard = function()
        return mod:IsEnabled() and mod:Get("keepHistory") == true
    end

    eachChatFrame(function(frame, index)
        if type(frame.AddMessage) ~= "function" then return end

        U.GuardedHook(frame, "AddMessage", function(_, text, r, g, b)
            capture(mod, index, text, r, g, b)
        end, guard)
    end)
end

---@param mod table
local function replayHistory(mod)
    local history = mod:CharData().history
    if not history then return end

    eachChatFrame(function(frame, index)
        local list = history[index]
        if not (list and #list > 0 and frame.AddMessage) then return end

        frame:AddMessage(L["Chat history separator"], T.COLOR.DISABLED:GetRGB())
        for i = 1, #list do
            local line = list[i]
            frame:AddMessage(line.text, line.r, line.g, line.b)
        end
    end)
end

--- Rejoue l'historique dans les fenêtres, une seule fois par session.
---
--- Au moment de l'activation, donc avant que la session n'ait rien à dire :
--- l'ancien se lit ainsi au-dessus du nouveau, dans l'ordre où il a été écrit.
---@param mod table
local function restoreHistory(mod)
    if restored then return end
    restored = true

    restoring = true
    -- Appel protégé, et le drapeau retombe **après** lui : une erreur au milieu
    -- du rejeu laisserait sinon le relevé muet pour le reste de la session.
    BUI.safecall(replayHistory, mod)
    restoring = false
end

--- Oublie ce qui a été relevé. Appelé quand le joueur éteint le réglage : il
--- vient de dire qu'il ne veut pas qu'on garde ses conversations.
---@param mod table
local function forgetHistory(mod)
    local data = mod:CharData()
    if data.history then wipe(data.history) end
end

-- =========================================================================
--  Couleurs de groupe
-- =========================================================================
-- Une conversation de groupe change de couleur selon l'endroit où elle a lieu :
-- groupe dehors, discussion d'instance en donjon, raid en raid. Ce sont trois
-- couleurs pour un seul fil de discussion, avec les mêmes gens.

--- Ce qui forme « le groupe » : tout ce qui s'adresse aux gens avec qui on joue
--- à cet instant. L'**avertissement de raid** n'y est pas, volontairement : il
--- est fait pour interrompre la lecture, l'aligner sur le reste le ferait taire.
local GROUP_TYPES = {
    "PARTY", "PARTY_LEADER", "PARTY_GUIDE",
    "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER",
    "RAID", "RAID_LEADER",
}

--- Celui dont la couleur gagne. Le groupe et non le raid : c'est la forme la
--- plus courante, donc celle que le joueur a déjà réglée à son goût.
local REFERENCE_TYPE = "PARTY"

--- type -> couleur relevée avant qu'on y touche
local savedColors = {}

--- Vrai pendant qu'on repeint : `ChangeChatColor` émet `UPDATE_CHAT_COLOR`, et
--- on ne se répond pas à soi-même.
local applying = false

---@param chatType string
---@return number|nil r, number|nil g, number|nil b
local function chatColor(chatType)
    local info = ChatTypeInfo and ChatTypeInfo[chatType]
    if not info then return nil end
    return info.r, info.g, info.b
end

---@param chatType string
---@param r? number
---@param g? number
---@param b? number
local function paint(chatType, r, g, b)
    local cr, cg, cb = chatColor(chatType)
    if cr == nil then return end

    if savedColors[chatType] == nil then
        savedColors[chatType] = { r = cr, g = cg, b = cb }
    end

    -- Ne rien faire quand la couleur est déjà la bonne. Ce n'est pas une
    -- optimisation : c'est ce qui fait converger le va-et-vient avec le client.
    -- `ChangeChatColor` annonce son changement, l'annonce nous rappelle, et un
    -- rappel qui repeint à l'identique annoncerait encore.
    if cr == r and cg == g and cb == b then return end

    if ChangeChatColor then ChangeChatColor(chatType, r, g, b) end
end

local function restoreColors()
    for chatType, color in pairs(savedColors) do
        if ChangeChatColor then ChangeChatColor(chatType, color.r, color.g, color.b) end
    end
    wipe(savedColors)
end

---@param mod table
local function applyColors(mod)
    if applying then return end
    applying = true

    if mod:Get("unifyGroupColors") then
        local r, g, b = chatColor(REFERENCE_TYPE)
        if r then
            for i = 1, #GROUP_TYPES do
                local chatType = GROUP_TYPES[i]
                if chatType ~= REFERENCE_TYPE then paint(chatType, r, g, b) end
            end
        end
    else
        restoreColors()
    end

    applying = false
end

--- Repasse sur les couleurs quand le joueur en change une lui-même : changer la
--- couleur du groupe doit emmener toute la famille avec elle. Groupé, le client
--- annonçant un type à la fois.
local repaintColors = U.Debounce(T.TIMING.CHAT_SETTLE, function()
    local mod = BUI.Modules:Get(MODULE)
    if mod and mod:IsEnabled() then applyColors(mod) end
end)

-- =========================================================================
--  Pièces posées sur les fenêtres
-- =========================================================================

--- cadre de chat -> { copy }
local tools = {}

---@param frame table
---@return table
local function toolsFor(frame)
    local entry = tools[frame]
    if not entry then
        entry = {}
        tools[frame] = entry
    end
    return entry
end

--- Cadre à redimensionner réellement quand on saisit `frame`.
---
--- Les fenêtres arrimées partagent la taille du meneur de leur dock : c'est lui
--- qu'il faut redimensionner, sinon le client repose aussitôt l'ancienne taille.
--- Résolu à chaque prise, une fenêtre pouvant être arrimée ou détachée entre
--- deux.
---@param frame table
---@return table
local function sizingTarget(frame)
    if frame.isDocked and GENERAL_CHAT_DOCK and GENERAL_CHAT_DOCK.primary then
        return GENERAL_CHAT_DOCK.primary
    end
    return frame
end

-- =========================================================================
--  Hauteur : on saisit l'onglet
-- =========================================================================
-- L'onglet est la poignée que le joueur a déjà sous la souris, et la seule
-- surface du chat qui ne serve pas à lire. Aucune texture n'est donc ajoutée
-- nulle part : ce qui devient saisissable existait déjà.
--
-- Le clic court garde tout son sens, et c'est ce qui rend le geste sans risque :
-- sans mouvement, il n'y a pas de redimensionnement, et `HookScript` laisse
-- l'onglet changer de fenêtre comme avant.

--- Onglet d'une fenêtre de chat, ou `nil`.
---@param frame table
---@return table|nil
local function chatTab(frame)
    if frame.tab then return frame.tab end

    local name = frame.GetName and frame:GetName()
    return name and _G[name .. "Tab"] or nil
end

--- Cadre en cours de redimensionnement, `nil` le reste du temps.
local sizing

local function stopSizing()
    if not sizing then return end

    if sizing.StopMovingOrSizing then sizing:StopMovingOrSizing() end

    -- La nouvelle taille est rangée dans la disposition du client lui-même :
    -- elle survit alors au rechargement sans que nous ayons à la mémoriser, et
    -- le joueur retrouve son chat comme il l'a laissé même sans l'addon.
    if FCF_SavePositionAndDimensions then FCF_SavePositionAndDimensions(sizing) end

    sizing = nil
end

---@param frame table
---@param button? string
local function startSizing(frame, button)
    if button and button ~= "LeftButton" then return end

    local target = sizingTarget(frame)
    if not (target and target.StartSizing) then return end

    -- Les cadres de chat du client sont redimensionnables ; s'il s'en trouvait un
    -- qui ne l'est pas, on le rend tel. Le rendre comme on l'a trouvé n'aurait
    -- pas de sens ici : on ne retire jamais une capacité que le client a pu
    -- donner entre-temps.
    if target.IsResizable and not target:IsResizable() and target.SetResizable then
        target:SetResizable(true)
    end

    target:StartSizing("TOP")
    sizing = target
end

--- Rend les onglets saisissables. Les hooks sont posés une fois et leur garde
--- les rend inertes quand le module s'éteint ou que le réglage retombe.
---@param mod table
local function hookTabs(mod)
    local guard = function()
        return mod:IsEnabled() and mod:Get("dragToResize") == true
    end

    eachChatFrame(function(frame)
        local tab = chatTab(frame)
        if not tab then return end

        U.GuardedScript(tab, "OnMouseDown", function(_, button)
            startSizing(frame, button)
        end, guard)

        -- Le relâchement arrive toujours à l'onglet qui a reçu l'appui, même si
        -- le curseur l'a quitté entre-temps : c'est le moteur qui le garantit.
        U.GuardedScript(tab, "OnMouseUp", stopSizing, guard)

        -- Filet : un onglet qui disparaît sous nos pieds — arrimage, fenêtre
        -- refermée — laisserait sinon un redimensionnement en cours.
        U.GuardedScript(tab, "OnHide", stopSizing, guard)
    end)
end

-- =========================================================================
--  Copie
-- =========================================================================

--- Échappements du client à retirer avant de rendre le texte copiable, dans
--- l'ordre où ils s'annulent. Un lien garde ce qu'il **affichait** : c'est le
--- nom de l'objet ou du joueur qu'on veut recoller ailleurs, pas son
--- identifiant. Les textures en ligne, elles, n'ont pas d'équivalent en texte.
local ESCAPES = {
    { "|c%x%x%x%x%x%x%x%x", "" },   -- ouverture de couleur
    { "|r",                 "" },   -- fermeture de couleur
    { "|H.-|h(.-)|h",     "%1" },   -- lien
    { "|T.-|t",             "" },   -- texture
    { "|A.-|a",             "" },   -- atlas
    { "|K.-|k",             "" },   -- identifiant Battle.net opaque
}

---@param text string
---@return string
local function plain(text)
    for i = 1, #ESCAPES do
        text = text:gsub(ESCAPES[i][1], ESCAPES[i][2])
    end
    return text
end

--- Table de travail du ramassage, réutilisée d'une copie à l'autre (règle 7) :
--- une fenêtre de chat porte plusieurs centaines de lignes.
local lines = {}

--- Contenu affiché d'une fenêtre de chat, en texte nu, et **où le lecteur en
--- est** dans ce contenu.
---
--- La fenêtre de copie rend tout l'historique, plusieurs centaines de lignes, et
--- l'ouvrir à son début revient à présenter ce qui s'est dit il y a une heure à
--- quelqu'un qui vient de lire la dernière ligne. La fraction rendue en second
--- dit à quelle hauteur se placer : le bas quand le chat n'est pas remonté, ce
--- qui est le cas courant.
---
--- **Approximative, et du bon côté.** `GetScrollOffset` compte des lignes
--- affichées et `GetNumMessages` des messages : un message replié sur deux
--- lignes fait donc reculer le repère un peu trop loin. On arrive alors un cran
--- au-dessus de son point de lecture, avec du contexte devant soi — l'erreur
--- inverse le ferait chercher plus bas.
---@param frame table
---@return string text
---@return number|nil at  fraction du texte où placer la vue
local function chatText(frame)
    if not (frame.GetNumMessages and frame.GetMessageInfo) then return "" end

    local count  = frame:GetNumMessages()
    local offset = frame.GetScrollOffset and frame:GetScrollOffset() or 0
    local last   = math.max(1, count - offset)
    local anchor = 0

    wipe(lines)
    for i = 1, count do
        local text = frame:GetMessageInfo(i)

        -- **`type(text) == "string"` ne suffit pas.** Le client rend certaines
        -- lignes en valeur *secrète* — celles où il protège l'identité de
        -- quelqu'un —, et une chaîne secrète est bel et bien une chaîne : le test
        -- de type la laisse passer. C'est l'indexer pour appeler `gsub` qui lève,
        -- et l'erreur remonte alors hors de la seule ligne fautive : elle
        -- interrompt la copie entière, qui ne rend plus rien.
        --
        -- Une ligne qu'on n'a pas le droit de lire est **sautée**. On perd cette
        -- ligne-là dans le presse-papier ; on perdait tout jusqu'ici.
        if type(text) == "string" and not U.IsSecret(text) then
            lines[#lines + 1] = plain(text)
        end

        -- Après l'ajout : le repère désigne une ligne du texte rendu, pas un
        -- numéro de message. Les lignes sautées ne comptent nulle part.
        if i == last then anchor = #lines end
    end

    if #lines == 0 then return "" end
    return table.concat(lines, "\n"), anchor / #lines
end

--- Fenêtre de copie, construite au premier clic et jamais détruite.
local copyWindow

---@param frame table
local function openCopy(frame)
    if not copyWindow then
        copyWindow = W.CopyWindow("BshamelUICopyFrame", L["Copy chat"], L["Copy chat hint"])
        if not copyWindow then return end
    end
    copyWindow:Open(chatText(frame))
end

---@param mod table
local function applyCopyButton(mod)
    local on = mod:Get("copyButton")

    eachChatFrame(function(frame)
        local entry = toolsFor(frame)

        if not on then
            if entry.copy then entry.copy:Hide() end
            return
        end

        if not entry.copy then
            entry.copy = W.ChatCopyButton(frame, {
                tooltipTitle = L["Copy chat"],
                tooltipText  = L["Copy button tip"],
                onClick      = openCopy,
            })
        end
        entry.copy:Show()
    end)
end

-- =========================================================================
--  Application d'ensemble
-- =========================================================================

---@param mod table
local function applyAll(mod)
    hookCapture(mod)
    hookTabs(mod)
    applyCopyButton(mod)
    applyColors(mod)
end

--- Repose nos pièces sur les fenêtres du client après qu'il les a remaniées :
--- une fenêtre ouverte, arrimée ou détachée en cours de session n'a pas encore
--- reçu ce qu'on pose. Groupé, ces événements arrivant par paquets.
local refreshTools = U.Debounce(T.TIMING.CHAT_SETTLE, function()
    local mod = BUI.Modules:Get(MODULE)
    if not (mod and mod:IsEnabled()) then return end

    hookCapture(mod)
    hookTabs(mod)
    applyCopyButton(mod)
end)

--- Réglage -> fonction qui le pose.
local APPLIERS = {
    copyButton       = applyCopyButton,
    unifyGroupColors = applyColors,

    dragToResize = function(mod)
        if mod:Get("dragToResize") then
            -- Les hooks peuvent n'avoir jamais été posés : allumer le réglage en
            -- cours de session doit rendre les onglets saisissables tout de suite.
            hookTabs(mod)
        else
            stopSizing()
        end
    end,

    keepHistory = function(mod)
        if mod:Get("keepHistory") then
            -- Le hook peut n'avoir jamais été posé : allumer le réglage en cours
            -- de session doit relever à partir de maintenant.
            hookCapture(mod)
        else
            forgetHistory(mod)
        end
    end,
}

-- =========================================================================
--  Déclaration du module
-- =========================================================================

BUI:RegisterModule(MODULE, {
    title    = L["Chat"],
    category = "QoL",
    order    = 40,

    defaults = {
        keepHistory      = false,
        dragToResize     = false,
        unifyGroupColors = false,
        copyButton       = false,
    },

    options = {
        { type = "header", text = L["History"] },
        {
            type    = "toggle",
            key     = "keepHistory",
            text    = L["Keep history"],
            tooltip = L["Keep history tip"],
        },

        { type = "header", text = L["Appearance"] },
        {
            type    = "toggle",
            key     = "dragToResize",
            text    = L["Drag to resize"],
            tooltip = L["Drag to resize tip"],
        },
        {
            type    = "toggle",
            key     = "unifyGroupColors",
            text    = L["Unify group colors"],
            tooltip = L["Unify group colors tip"],
        },

        { type = "header", text = L["Copy"] },
        {
            type    = "toggle",
            key     = "copyButton",
            text    = L["Copy button"],
            tooltip = L["Copy button tip"],
        },
    },

    OnEnable = function(self)
        applyAll(self)

        -- La restitution vient après le relevé : les lignes rejouées passent
        -- alors devant un hook déjà posé, que `restoring` fait taire. L'ordre
        -- inverse marcherait aussi, il serait juste plus fragile à relire.
        if self:Get("keepHistory") then restoreHistory(self) end

        self:RegisterEvent("UPDATE_CHAT_COLOR", repaintColors)

        self:RegisterEvent("UPDATE_CHAT_WINDOWS", refreshTools)
        self:RegisterEvent("UPDATE_FLOATING_CHAT_WINDOWS", refreshTools)
    end,

    OnDisable = function()
        stopSizing()

        for _, entry in pairs(tools) do
            if entry.copy then entry.copy:Hide() end
        end

        restoreColors()

        if copyWindow then copyWindow:Hide() end
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
