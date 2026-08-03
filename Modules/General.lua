-- =========================================================================
--  Bshamel UI — Modules/General.lua
--  Les réglages qui n'appartiennent à aucune fenêtre en particulier.
--
--  Trois choses, et rien d'autre : le bouton de l'addon, la caméra, le menu
--  Échap. Ce qui reste après que tout le reste soit parti vers la page où on le
--  cherche vraiment.
--
--  Le module a longtemps servi de fourre-tout, et chaque départ s'est fait pour
--  la même raison : le mode sombre pesait la moitié du fichier
--  (`Modules/DarkMode.lua`) ; le minuteur de file appartient à la recherche de
--  groupe ; la réparation automatique se déclenche chez le marchand, donc dans
--  *Sacs & Réparations* ; l'hôtel des ventes et les nuisances ont leur page. Voir
--  les paliers de migration dans `Core/DB.lua`.
--
--  Le **bouton de l'addon** et le **tiroir de boutons d'addons**, eux, sont
--  revenus. Ils avaient rejoint une page « Minicarte » avec le menu de
--  téléportation ; celui-ci est devenu sa propre page, et il ne restait plus rien
--  autour des deux autres. Ils sont ici et non ailleurs parce qu'ils sont
--  **liés** : le tiroir s'ouvre sur le bouton, et les séparer sur deux pages
--  ferait deux cases dont ni l'une ni l'autre ne s'expliquerait seule (voir les
--  paliers de migration dans `Core/DB.lua`).
--
--  Le module ne dessine ni l'un ni l'autre : `UI/MinimapDock.lua` sait poser le
--  bouton, reconnaître les boutons des autres addons et les emprunter. Ce fichier
--  ne dit que les réglages — même séparation que le mode sombre.
--
--  Réversibilité (CLAUDE.md règle 6) : chaque comportement relève l'état du
--  client **avant** de le changer, et `OnDisable` le repose. Les CVar sont
--  restituées à leur valeur d'origine, l'échelle du menu à la sienne, le bouton
--  se cache et chaque bouton emprunté retrouve son parent. Rien n'est laissé
--  derrière.
--
--  `secure = true` : le module met à l'échelle le menu du jeu, qui porte des
--  boutons sécurisés, et le tiroir **reparente** des cadres — ni l'un ni l'autre
--  ne passe en combat. Le core diffère donc l'activation à la sortie de combat,
--  et ce qui serait quand même refusé en cours de session est rattrapé sur
--  `PLAYER_REGEN_ENABLED`.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local U    = BUI.Util
local L    = ns.L

local MODULE = "General"

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
--  CVar
-- =========================================================================
-- Un seul réglage du client se pilote par CVar ici. On passe par `C_CVar` quand il
-- est là, par les globales sinon : les deux chemins existent, aucun des deux
-- n'est garanti pour toujours.

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

--- Valeurs relevées avant modification. `nil` signifie « on n'a rien changé »,
--- ce qui n'est pas la même chose que « la valeur d'origine était vide ».
local saved = {}

---@param name string
---@param value any   valeur à poser, ou `nil` pour rendre l'originale
local function overrideCVar(name, value)
    if value ~= nil then
        if saved[name] == nil then saved[name] = getCVar(name) end
        setCVar(name, value)
    elseif saved[name] ~= nil then
        setCVar(name, saved[name])
        saved[name] = nil
    end
end

local CVAR_ZOOM   = "cameraDistanceMaxZoomFactor"

-- =========================================================================
--  Caméra
-- =========================================================================

---@param mod table
local function applyCamera(mod)
    if mod:Get("maxCameraDistance") then
        overrideCVar(CVAR_ZOOM, mod:Get("cameraZoomFactor"))
    else
        overrideCVar(CVAR_ZOOM, nil)
    end
end

-- =========================================================================
--  Menu du jeu
-- =========================================================================

local savedMenuScale

---@param mod table
local function applyGameMenu(mod)
    local frame = GameMenuFrame
    if not (frame and frame.SetScale) then return end

    -- Le menu porte des boutons sécurisés : on ne le redimensionne pas en
    -- combat. La sortie de combat rappelle cette fonction (voir `OnEnable`).
    if InCombatLockdown() then return end

    if mod:Get("compactGameMenu") then
        if not savedMenuScale then savedMenuScale = frame:GetScale() end
        frame:SetScale(mod:Get("gameMenuScale") / 100)
    elseif savedMenuScale then
        frame:SetScale(savedMenuScale)
        savedMenuScale = nil
    end
end

-- =========================================================================
--  Bouton de l'addon, et tiroir des boutons d'addons
-- =========================================================================
-- Le socle (`UI/MinimapDock.lua`) possède les deux cadres ; ce module possède
-- les trois réglages qui les décrivent. L'angle ne passe pas par un contrôle :
-- il se change en déplaçant le bouton, et le socle le rend par la fonction qu'on
-- lui donne ici.
--
-- Les deux réglages sont **liés** et se lisent l'un sous l'autre : le tiroir
-- s'ouvre sur le bouton, et n'a aucun sens sans lui. Le socle sait déjà que l'un
-- entraîne l'autre — éteindre le bouton rend les boutons empruntés — mais c'est
-- la page qui doit rendre ce lien évident, en les posant côte à côte.

---@param mod table
local function applyMinimapButton(mod)
    BUI.MinimapDock:SetButton(
        mod:Get("button"),
        function() return mod:Get("angle") end,
        function(angle) mod:Set("angle", angle) end)
end

---@param mod table
local function applyMinimapTray(mod)
    BUI.MinimapDock:SetTray(mod:Get("tray"))
end

-- =========================================================================
--  Application d'ensemble
-- =========================================================================

---@param mod table
local function applyAll(mod)
    applyCamera(mod)
    applyGameMenu(mod)
    applyMinimapButton(mod)
    applyMinimapTray(mod)
end

--- Réglage -> fonction qui le pose. Les réglages absents de cette table ne
--- s'appliquent pas : ils se lisent au moment où l'événement arrive.
local APPLIERS = {
    maxCameraDistance = applyCamera,
    cameraZoomFactor  = applyCamera,
    compactGameMenu   = applyGameMenu,
    gameMenuScale     = applyGameMenu,
    button            = applyMinimapButton,
    tray              = applyMinimapTray,
}

-- =========================================================================
--  Déclaration du module
-- =========================================================================

BUI:RegisterModule(MODULE, {
    title    = L["General"],
    category = "Interface",
    order    = 1,
    secure   = true,

    defaults = {
        button = false,
        -- Angle sur le pourtour de la minicarte, en degrés. Réglage sans
        -- contrôle : il se change en déplaçant le bouton, pas dans cette fenêtre.
        angle  = 200,

        -- Le tiroir n'a pas de bouton : il s'ouvre sur celui de l'addon.
        tray   = false,

        maxCameraDistance = false,
        cameraZoomFactor  = 2.9,

        compactGameMenu = false,
        gameMenuScale   = 75,

        -- Échelle du contenu de la fenêtre d'options, en pourcentage. Réglage
        -- sans contrôle dans cette page, comme l'angle du bouton de minicarte :
        -- il se change depuis la barre de titre de la fenêtre, là où on en voit
        -- l'effet (voir `UI/Config/ConfigFrame.lua`).
        --
        -- Trois quarts par défaut : la page des barres d'infos est devenue la
        -- mesure de l'addon, et à taille pleine elle ne tient pas sous les yeux.
        -- Qui préfère plus grand remonte d'un geste dans la barre de titre.
        configScale = 75,
    },

    options = {
        { type = "header", text = L["Buttons"] },
        {
            type    = "toggle",
            key     = "button",
            text    = L["Minimap button"],
            tooltip = L["Minimap button tip"],
        },
        {
            type     = "toggle",
            key      = "tray",
            text     = L["Group addon buttons"],
            tooltip  = L["Group addon buttons tip"],
            -- Grisé tant que le bouton est éteint : le tiroir s'ouvre dessus, et
            -- une case qu'on peut cocher sans effet se lit comme une panne.
            disabled = requires("button"),
        },

        { type = "header", text = L["Camera"] },
        {
            type    = "toggle",
            key     = "maxCameraDistance",
            text    = L["Max camera distance"],
            tooltip = L["Max camera distance tip"],
        },
        {
            type     = "slider",
            key      = "cameraZoomFactor",
            text     = L["Camera zoom factor"],
            tooltip  = L["Camera zoom factor tip"],
            min      = 1,
            max      = 2.9,
            step     = 0.1,
            decimals = 1,
            disabled = requires("maxCameraDistance"),
        },

        { type = "header", text = L["Game menu"] },
        {
            type    = "toggle",
            key     = "compactGameMenu",
            text    = L["Compact game menu"],
            tooltip = L["Compact game menu tip"],
        },
        {
            type     = "slider",
            key      = "gameMenuScale",
            text     = L["Game menu scale"],
            tooltip  = L["Game menu scale tip"],
            min      = 50,
            max      = 100,
            step     = 5,
            disabled = requires("compactGameMenu"),
        },
    },

    OnEnable = function(self)
        applyAll(self)

        -- Les boutons d'addons apparaissent au chargement de leur addon, et rien
        -- ne les annonce : on repasse une fois la rafale retombée.
        local settle = U.Debounce(T.TIMING.TRAY_SETTLE, function()
            BUI.MinimapDock:Refresh()
        end)
        self:RegisterEvent("ADDON_LOADED",          settle)
        self:RegisterEvent("PLAYER_ENTERING_WORLD", settle)

        -- Ni l'échelle du menu ni un changement de parent ne passent en combat :
        -- ce qui a été refusé pendant le combat est rattrapé ici.
        self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
            applyGameMenu(self)
            BUI.MinimapDock:Refresh()
        end)
    end,

    OnDisable = function()
        -- Le bouton se cache et le tiroir rend chaque bouton emprunté à son
        -- parent, à ses ancrages et à sa strate d'origine.
        BUI.MinimapDock:SetTray(false)
        BUI.MinimapDock:SetButton(false)

        overrideCVar(CVAR_ZOOM, nil)

        local frame = GameMenuFrame
        if savedMenuScale and frame and frame.SetScale then
            frame:SetScale(savedMenuScale)
            savedMenuScale = nil
        end
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
