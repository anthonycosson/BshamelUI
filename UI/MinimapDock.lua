-- =========================================================================
--  Bshamel UI — UI/MinimapDock.lua
--  Le bouton de l'addon, et le tiroir qui range ceux des autres.
--
--  Deux réglages, **un seul mécanisme**. Le tiroir n'a pas de bouton à lui : il
--  s'ouvre au clic gauche sur le bouton de l'addon et se pose à côté de lui. Il
--  l'exige donc, et pas seulement pour s'ouvrir — sans lui, les boutons rangés
--  seraient invisibles et rien ne permettrait de les ressortir.
--
--  Les deux réglages vivent dans `Modules/General.lua`, l'un sous l'autre, parce
--  que c'est ainsi qu'ils se comprennent. Ce fichier existe pour la raison
--  habituelle : un module déclare, il ne dessine pas. C'est la même séparation
--  que le mode sombre — `UI/Shade.lua` sait teindre, `Modules/DarkMode.lua` sait
--  ce qu'il faut teindre.
--
--  Les deux vœux restent malgré tout séparés ici (`SetButton`, `SetTray`) : c'est
--  ce fichier, et non l'ordre dans lequel les cases sont cochées, qui sait que le
--  bouton entraîne le tiroir.
--
--  Réversibilité : `ReleaseAll` rend chaque bouton emprunté à son parent, à ses
--  ancrages et à sa strate d'origine ; le bouton de l'addon se cache.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local W    = BUI.Widgets
local L    = ns.L

local Dock = {}
BUI.MinimapDock = Dock

-- =========================================================================
--  Boutons d'addons : qui a le droit d'être rangé
-- =========================================================================
-- On ne range que ce qui appartient à un autre addon. Les boutons du client
-- restent où ils sont : ils font partie de la minicarte, pas de son encombrement.
--
-- Deux filtres se complètent. Le premier est la liste des cadres du client, qui
-- sont nommés et connus ; le second est un préfixe, parce que Blizzard nomme ses
-- pièces de minicarte d'après elle et qu'une nouvelle apparaît à chaque
-- extension — un cadre inconnu qui s'appelle « Minimap quelque chose » est
-- presque sûrement le sien.
--
-- Un troisième écarte ce qui n'appartient à personne : les **épingles** que les
-- addons de carte posent sur la minicarte (voir plus bas).

local CLIENT_FRAMES = {
    MinimapZoomIn = true, MinimapZoomOut = true,
    MinimapBackdrop = true, MinimapCluster = true, MinimapNorthTag = true,
    MinimapZoneTextButton = true, MinimapCompassTexture = true,
    GameTimeFrame = true, TimeManagerClockButton = true,
    QueueStatusMinimapButton = true, QueueStatusButton = true,
    GarrisonLandingPageMinimapButton = true,
    ExpansionLandingPageMinimapButton = true,
    AddonCompartmentFrame = true,
}

local CLIENT_PREFIXES = { "Minimap", "MiniMap", "GameTime", "QueueStatus", "AddonCompartment" }

--- Bouton posé par une bibliothèque d'icônes. Il porte toujours ce préfixe, et
--- c'est le cas le plus fréquent — la moitié des addons passent par là.
local LIB_PREFIX = "LibDBIcon10_"

---@param name string
---@return boolean
local function isClientFrame(name)
    if CLIENT_FRAMES[name] then return true end
    if name:find(LIB_PREFIX, 1, true) == 1 then return false end

    for i = 1, #CLIENT_PREFIXES do
        if name:find(CLIENT_PREFIXES[i], 1, true) == 1 then return true end
    end
    return false
end

-- =========================================================================
--  Épingles de carte : ce qui ressemble à un bouton sans en être un
-- =========================================================================
-- Un addon de récolte pose ses gisements **sur la minicarte**, et il les pose
-- exactement comme un bouton : des cadres `Button` nommés, enfants de la carte,
-- affichés. Rien ne les distingue d'un bouton d'addon pour qui regarde leur
-- type — et il y en a trente à l'écran. Le tiroir se remplissait donc de
-- « GatherMatePin1 », « GatherMatePin2 »… jusqu'à ce qu'on n'y trouve plus rien.
--
-- Pire que l'encombrement : une épingle rangée est une épingle **volée** à son
-- addon, qui la recycle à chaque pas du joueur. Elle ressortirait dans le tiroir
-- sous un autre gisement, et son propriétaire ne pourrait plus la replacer.
--
-- Trois signes, et il en faut trois : chacun rattrape ce que le précédent laisse
-- passer. Le pool ne se voit pas quand une seule épingle est affichée à
-- l'instant du parcours ; le vocabulaire ne voit que les mots auxquels on a
-- pensé — « GatherMateIcon12 » n'en contient aucun ; la taille, elle, ne demande
-- rien au nom.

--- Racine d'un nom, sans son numéro de série. Un pool nomme ses cadres
--- « <racine>1 », « <racine>2 »… : la racine est ce qui les rassemble.
---@param name string
---@return string
local function nameStem(name)
    return (name:gsub("%d+$", ""))
end

--- Mots par lesquels se terminent les noms d'épingles. Ils disent ce que le
--- cadre **est**, là où un bouton d'addon dit à qui il appartient — et un addon
--- a un bouton, pas une collection.
local PIN_WORDS = { "Pin", "Pins", "Node", "Nodes", "Waypoint", "POI" }

---@param name string
---@return boolean
local function looksLikePin(name)
    local stem = nameStem(name)
    for i = 1, #PIN_WORDS do
        local word = PIN_WORDS[i]
        if stem:sub(-#word) == word then return true end
    end
    return false
end

--- Le cadre a-t-il la taille d'un bouton ? C'est le signe qui ne demande rien au
--- nom, donc le seul qui vaille pour un addon dont on ignore les habitudes : une
--- épingle fait la moitié d'un bouton de minicarte — c'est ce qui la rend lisible
--- au milieu de la carte —, un panneau en fait le double.
---
--- Les bornes sont larges à dessein. Elles ne trient pas les boutons entre eux :
--- elles séparent ce qui est un bouton de ce qui n'en est pas un.
---@param frame table
---@return boolean
local function buttonSized(frame)
    if not (frame.GetWidth and frame.GetHeight) then return false end

    local width, height = frame:GetWidth(), frame:GetHeight()
    local min,   max    = T.SIZE.MINIMAP_BUTTON_MIN, T.SIZE.MINIMAP_BUTTON_MAX

    return width  >= min and width  <= max
       and height >= min and height <= max
end

---@param frame table
---@return boolean
local function isAddonButton(frame)
    -- Nos propres boutons ne se rangent évidemment pas dans notre tiroir. La
    -- fabrique les connaît tous, y compris celui de la téléportation, qui est
    -- créé par un autre module et que ce fichier n'a jamais vu.
    if not frame or W.IsMinimapButtonOurs(frame) then return false end

    -- Un cadre interdit lève à la moindre question posée : on n'en pose aucune.
    if frame.IsForbidden and frame:IsForbidden() then return false end

    -- Un cadre **protégé** ne se range pas. Le déplacer, le reparenter ou changer
    -- sa strate est réservé à l'interface de Blizzard : le client refuse et
    -- affiche « BshamelUI a été bloqué à cause d'une action qui n'est utilisable
    -- que par l'IU de Blizzard ».
    --
    -- La liste de noms ne suffit pas à les écarter tous : le client en ajoute à
    -- chaque extension, et un addon peut très bien bâtir son bouton sur un
    -- template sécurisé — un bouton qui lance un sort en est un. La question se
    -- pose donc au cadre lui-même, qui répond juste dans tous les cas.
    if frame.IsProtected and frame:IsProtected() then return false end

    if not (frame.GetName and frame.IsShown and frame.IsObjectType) then return false end

    local name = frame:GetName()
    if not name then return false end

    -- Le préfixe d'une bibliothèque d'icônes **est** une réponse : rien d'autre
    -- ne s'appelle ainsi, et ce qui s'appelle ainsi est le bouton d'un addon.
    local fromLibrary = name:find(LIB_PREFIX, 1, true) == 1

    -- Un bouton, ou un cadre de bibliothèque qui n'en est pas tout à fait un :
    -- certaines versions posent une frame et lui greffent les clics.
    if not (frame:IsObjectType("Button") or fromLibrary) then
        return false
    end

    -- Un bouton caché l'est parce que son addon l'a voulu. Le ranger le ferait
    -- réapparaître dans le tiroir, ce qui défait le geste de quelqu'un d'autre.
    if not frame:IsShown() then return false end

    -- Les signes qui écartent les épingles ne valent que pour le reste : une
    -- bibliothèque nomme d'après l'addon et jamais d'après une collection, et un
    -- addon a le droit de vouloir son bouton plus petit que ceux du client.
    if not fromLibrary and (looksLikePin(name) or not buttonSized(frame)) then
        return false
    end

    return not isClientFrame(name)
end

--- Cadres qui portent les boutons du pourtour. Trois, parce que le client a
--- déplacé les siens d'une extension à l'autre et que les addons suivent.
---@return table[]
local function scanRoots()
    return { Minimap, MinimapBackdrop, MinimapCluster }
end

--- Tables de travail. Réutilisées : la recherche tourne à chaque addon chargé
--- (règle 7).
local candidates = {}
local families   = {}

---@return table[]
local function findAddonButtons()
    wipe(candidates)
    wipe(families)

    local roots = scanRoots()
    for i = 1, #roots do
        local root = roots[i]
        if root and root.GetChildren then
            for _, child in ipairs({ root:GetChildren() }) do
                if isAddonButton(child) then
                    local stem = nameStem(child:GetName())
                    families[stem] = (families[stem] or 0) + 1
                    candidates[#candidates + 1] = child
                end
            end
        end
    end

    -- Une racine portée par plusieurs cadres est un **pool**, donc des épingles :
    -- un addon pose un bouton, pas une famille numérotée. On écarte la famille
    -- entière, y compris son premier membre — c'est tout ou rien, sans quoi le
    -- tiroir volerait une épingle sur trente.
    local kept = 0
    for i = 1, #candidates do
        local frame = candidates[i]
        if families[nameStem(frame:GetName())] == 1 then
            kept = kept + 1
            candidates[kept] = frame
        end
    end
    for i = #candidates, kept + 1, -1 do
        candidates[i] = nil
    end

    return candidates
end

-- =========================================================================
--  État
-- =========================================================================
-- Deux vœux, posés chacun par son module et retenus ici. Le tiroir n'est tendu
-- que quand les deux sont vrais : c'est cette table, et non l'ordre dans lequel
-- les modules s'allument, qui décide de ce qui est à l'écran.

local button, tray
local buttonWanted, trayWanted = false, false

---@return boolean
local function trayLive()
    return trayWanted and buttonWanted
end

local function applyTray()
    if not trayLive() then
        if tray then tray:ReleaseAll() end
        return
    end

    if not Minimap then return end
    tray = tray or W.Tray(UIParent, L["Addon buttons empty"])
    Dock:Refresh()
end

--- Angle du bouton, lu et écrit par le module qui possède le réglage. Posés par
--- `SetButton`, ils survivent au bouton lui-même : le module peut l'éteindre et
--- le rallumer sans que la fabrique ait à être rappelée.
local getAngle, setAngle

local function applyButton()
    if not buttonWanted then
        if button then button:Hide() end
        return
    end

    if not button then
        button = W.MinimapButton({
            tooltipTitle = L["Bshamel UI"],
            tooltipText  = L["Minimap button tip"],

            -- Deux gestes sur un seul bouton, et le tiroir n'en demande plus un
            -- à lui : un bouton d'addon qui en ajoute un second pour ranger ceux
            -- des autres se moque du monde.
            --
            -- Le clic gauche ouvre le tiroir, **ou** la fenêtre d'options quand
            -- il n'y a pas de tiroir : un clic qui ne fait rien se lit comme un
            -- bouton cassé. La question porte sur le vœu et non sur l'existence
            -- du tiroir — une fois construit, il ne se détruit pas, et un tiroir
            -- éteint doit rendre son clic à la fenêtre d'options.
            onClick = function(mouseButton)
                -- Le tiroir s'ouvre même vide : il dit alors qu'il n'y a rien à
                -- ranger, ce qui est une réponse. Refuser de s'ouvrir ne se
                -- distinguerait pas d'un bouton cassé.
                if mouseButton ~= "RightButton" and tray and trayLive() then
                    tray:PlaceNear(button)
                    tray:Toggle()
                    return
                end
                if BUI.Config and BUI.Config.Toggle then BUI.Config:Toggle() end
            end,

            getAngle = function() return getAngle and getAngle() end,
            setAngle = function(angle) if setAngle then setAngle(angle) end end,
        })
        if not button then return end
    end

    button:Refresh()
    button:Show()
end

-- =========================================================================
--  Ce que les modules déclarent
-- =========================================================================

--- Le bouton de l'addon est-il voulu, et où lit-on son angle ?
---@param shown boolean
---@param readAngle? fun(): number
---@param writeAngle? fun(angle: number)
function Dock:SetButton(shown, readAngle, writeAngle)
    if readAngle then getAngle = readAngle end
    if writeAngle then setAngle = writeAngle end

    buttonWanted = shown and true or false
    applyButton()

    -- Le bouton entraîne le tiroir : c'est lui qui l'ouvre, donc l'éteindre doit
    -- rendre les boutons empruntés plutôt que de les laisser rangés dans un
    -- tiroir que plus rien ne déplie.
    applyTray()
end

--- Les boutons des autres addons sont-ils rangés ?
---@param enabled boolean
function Dock:SetTray(enabled)
    trayWanted = enabled and true or false
    applyTray()
end

--- Reprend le pourtour de la minicarte. À rappeler quand un addon s'est chargé :
--- son bouton apparaît sans que rien ne l'annonce.
function Dock:Refresh()
    if not (tray and trayLive()) then return end

    -- Reparenter un cadre en combat est refusé par le client, même quand le
    -- cadre ne lui appartient pas. Ce qui est repoussé ici est rattrapé à la
    -- sortie de combat, où cette même fonction est rappelée.
    if InCombatLockdown() then return end

    tray:Hold(findAddonButtons())
end

--- Rend tout d'un geste. `SetButton(false)` et `SetTray(false)` font déjà le
--- travail ; celle-ci est là pour l'extinction franche, sans avoir à se rappeler
--- lequel des deux entraîne l'autre.
function Dock:ReleaseAll()
    if tray then tray:ReleaseAll() end
    if button then button:Hide() end
end
