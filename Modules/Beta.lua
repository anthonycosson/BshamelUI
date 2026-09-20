-- =========================================================================
--  Bshamel UI — Modules/Beta.lua
--  Les bugs de la bêta de *Forever* que l'addon rattrape en attendant que
--  Blizzard les corrige.
--
--  *Forever* seulement (sa ligne du `.toc` l'écarte de retail, voir
--  `CLAUDE.md` §1). Ce module n'ajoute **aucune** fonctionnalité : il ne
--  répare que ce que le client casse, et chaque correctif est destiné à
--  disparaître d'ici la sortie. C'est pour cela qu'ils vivent ensemble ici
--  plutôt que dispersés dans les modules qu'ils concernent : le jour où
--  Blizzard corrige, on retire une entrée, pas une couture.
--
--  **Ses cases sont cochées à la livraison** (`@default-on`), et c'est la
--  seconde exception de l'addon après le bouton de minicarte. Le motif est
--  écrit au-dessus de chacune : un correctif de plantage n'est pas un réglage
--  de confort. La promesse « installer l'addon ne change rien au jeu » vaut
--  pour ce que le jeu fait ; elle ne peut pas s'étendre à ce qu'il **rate** —
--  une fiche de personnage qui lève une erreur Lua à chaque survol n'est pas
--  un état qu'on protège. La case reste là pour qu'on puisse revenir en
--  arrière et constater le bug d'origine.
--
--  Réversibilité (règle 6) : chaque correctif défait exactement ce qu'il a
--  posé, et l'extinction rend le bug tel qu'il était.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local U    = BUI.Util
local T    = BUI.Theme
local L    = ns.L

local MODULE = "Beta"

-- =========================================================================
--  Infobulles des caractéristiques de la fiche de personnage
-- =========================================================================
-- **Le bug** (bêta 1.60.1, `Blizzard_UIPanels_Game/Camelot/PaperDollFrameStats.lua`) :
--
--     local classStatText = _G[strupper(classFileName).."_"..strupper(statName).."_".."TOOLTIP"]
--
-- `statName` est le nom **traduit** de la caractéristique (`SPELL_STAT1_NAME`,
-- « Force » en français). La clé cherchée devient donc `SHAMAN_FORCE_TOOLTIP`,
-- qui n'existe que sous sa forme anglaise, `SHAMAN_STRENGTH_TOOLTIP`. Le repli
-- `DEFAULT_FORCE_TOOLTIP` est absent pour la même raison, et le `string.format`
-- qui suit reçoit `nil` : erreur Lua à chaque ouverture de la fiche.
--
-- Le client anglais ne le voit pas ; tous les autres l'ont à chaque survol.
--
-- **Ce qu'on fait** : on pose les clés traduites qui manquent, en les faisant
-- pointer sur les textes anglais déjà chargés — dont la **valeur** est, elle,
-- bien traduite. Blizzard trouve alors sa chaîne, et l'infobulle s'affiche dans
-- la langue du joueur.
--
-- On n'écrit que des clés **absentes** : si le client se corrige, ou si une
-- autre langue a déjà la sienne, on ne touche à rien.
--
-- **Le prix, connu et accepté : une erreur Lua à l'ouverture de la fiche.**
-- Une globale écrite par un addon est teintée pour la session, définitivement.
-- Le client relit celle-ci à l'ouverture de la fiche — `SetStatTooltip2` est
-- appelée pendant `RefreshRightPane`, pas au survol — et la suite de son
-- `OnShow` hérite de la teinte. Quatre lignes plus loin, il affiche les points
-- de vie du joueur en chiffres, qui sont des valeurs secrètes, et lève
-- « attempt to compare a secret number value ».
--
-- **Il n'existe aucune version propre de ce correctif** : un addon ne peut pas
-- écrire une globale sans la teindre, et la clé manquante ne se fournit que
-- par une globale. Le choix est donc entre deux bugs, et il a été fait le
-- 20 septembre 2026 : garder les infobulles lisibles, masquer l'erreur. Ne pas
-- « réparer » ce compromis sans le rouvrir — le retirer ramène simplement
-- l'autre erreur.

--- Les cinq caractéristiques, par l'indice que le client leur donne, avec le
--- nom anglais que portent ses chaînes.
local STATS = {
    [1] = "STRENGTH",
    [2] = "AGILITY",
    [3] = "STAMINA",
    [4] = "INTELLECT",
    [5] = "SPIRIT",
}

--- Clés qu'on a posées, pour pouvoir les retirer : clé -> vrai.
local posted = {}

--- Les deux préfixes que le client essaie, dans l'ordre : la classe du
--- personnage, puis le repli commun.
---@return string[]
local function prefixes()
    local list = { "DEFAULT" }

    local _, class = UnitClass("player")
    if type(class) == "string" and not U.IsSecret(class) then
        list[#list + 1] = strupper(class)
    end
    return list
end

local function applyStatTooltips()
    for index, english in pairs(STATS) do
        -- Le nom traduit vient du client : c'est exactement celui que son code
        -- réutilisera pour composer la clé.
        local localized = _G["SPELL_STAT" .. index .. "_NAME"]

        if type(localized) == "string" and not U.IsSecret(localized) then
            for _, prefix in ipairs(prefixes()) do
                local key    = prefix .. "_" .. strupper(localized) .. "_TOOLTIP"
                local source = _G[prefix .. "_" .. english .. "_TOOLTIP"]

                if _G[key] == nil and type(source) == "string" then
                    _G[key] = source
                    posted[key] = true
                end
            end
        end
    end
end

--- Retire ce qu'on a posé : le bug redevient exactement ce qu'il était.
local function restoreStatTooltips()
    for key in pairs(posted) do
        _G[key] = nil
    end
    wipe(posted)
end

-- =========================================================================
--  La configuration, rangée dans des macros
-- =========================================================================
-- **Les macros, le client les rend.** C'est tout l'intérêt : le SavedVariables
-- d'un addon n'est jamais relu au lancement sur cette bêta (voir
-- `Core/Forever.lua`), alors que les macros sont des données du client, rangées
-- dans son propre fichier et restituées comme les raccourcis ou les barres
-- d'action. Un code d'export qui dort dans une macro survit donc à ce que le
-- fichier de réglages ne survit pas.
--
-- **Le corps d'une macro tient 255 caractères** (`MacroFrameText`, `letters`),
-- ce qui est plus court qu'un code d'export. Il est donc coupé en tranches, une
-- par macro, numérotées dans l'ordre de relecture. Chaque tranche commence par
-- un `#` : le client y voit un commentaire, la macro ne fait rien si on la
-- joue, et la relecture n'a qu'un caractère à retirer.
--
-- Une dernière macro, celle-là jouable, ne contient que l'appel qui restaure.
-- C'est elle qu'on pose sur une barre ou sur un raccourci.

--- Nom de la macro jouable, et racine des macros de données. Seize caractères
--- au plus par nom : `BUIconfig12` en fait onze.
local MACRO_NAME  = "BUIconfig"

--- Ce que la macro jouable exécute. Le module se retrouve par son nom, qui est
--- une clé de base de données donc stable (règle 4).
local MACRO_BODY  = '/run BshamelUI.Modules:Get("Beta"):RestoreConfig()'

--- Taille d'une tranche. Sous les 255 du client, avec de quoi loger le `#` et
--- de la marge pour un client qui compterait autrement.
local CHUNK       = 240

--- Au-delà, on refuse plutôt que de remplir le carnet de macros du joueur.
--- Un profil n'a aucune raison d'y arriver : l'export ne transporte que ce qui
--- diffère des défauts.
local MAX_CHUNKS  = 12

---@param index integer
---@return string
local function chunkName(index)
    return MACRO_NAME .. index
end

---@param name string
---@return integer|nil
local function macroIndex(name)
    if type(GetMacroIndexByName) ~= "function" then return nil end
    local index = GetMacroIndexByName(name)
    if type(index) ~= "number" or index == 0 then return nil end
    return index
end

--- Retire les macros qu'on avait posées. Par **nom** et non par indice : effacer
--- une macro décale toutes celles qui la suivent, et un indice retenu d'avance
--- désignerait alors la macro d'à côté — celle du joueur.
local function wipeMacros()
    if type(DeleteMacro) ~= "function" then return end

    for i = 1, MAX_CHUNKS do
        while macroIndex(chunkName(i)) do
            DeleteMacro(chunkName(i))
        end
    end
end

--- Écrit le profil actif dans des macros de compte.
---@return boolean ok
---@return string|nil reason  `"combat"`, `"api"`, `"export"`, `"long"` ou `"full"`
---@return integer|nil count
local function saveToMacros()
    if InCombatLockdown() then return false, "combat" end
    if type(CreateMacro) ~= "function" then return false, "api" end

    local text = BUI.DB:ExportString()
    if not text then return false, "export" end

    local chunks = {}
    for i = 1, #text, CHUNK do
        chunks[#chunks + 1] = text:sub(i, i + CHUNK - 1)
    end
    if #chunks > MAX_CHUNKS then return false, "long" end

    wipeMacros()

    for i = 1, #chunks do
        local created = CreateMacro(chunkName(i), T.TEXTURE.CONFIG_MACRO,
                                    "#" .. chunks[i], false)
        if not created then
            -- Carnet plein : on ne laisse pas derrière nous une sauvegarde à
            -- moitié écrite, qui se relirait en code tronqué.
            wipeMacros()
            return false, "full"
        end
    end

    -- La macro jouable est réécrite quand elle existe déjà, au lieu d'être
    -- laissée telle quelle : son icône et son corps sont les nôtres, et une
    -- macro d'une version précédente porterait les anciens. Elle n'est pas
    -- effacée pour autant — la refaire lui ferait perdre sa place sur la barre
    -- d'action où le joueur l'a posée.
    local runner = macroIndex(MACRO_NAME)
    if runner and type(EditMacro) == "function" then
        EditMacro(runner, MACRO_NAME, T.TEXTURE.CONFIG_MACRO, MACRO_BODY)
    elseif not runner then
        CreateMacro(MACRO_NAME, T.TEXTURE.CONFIG_MACRO, MACRO_BODY, false)
    end

    return true, nil, #chunks
end

--- Le joueur a-t-il déjà rangé sa configuration ? Lu depuis
--- `Core/Forever.lua`, qui se tait quand la réponse est oui : lui dire comment
--- sauvegarder ce qu'il a déjà sauvegardé ne l'aiderait pas.
---@return boolean
local function hasMacros()
    return macroIndex(chunkName(1)) ~= nil
end

--- Recompose le code rangé dans les macros.
---@return string|nil
local function readMacros()
    if type(GetMacroBody) ~= "function" then return nil end

    local parts = {}
    for i = 1, MAX_CHUNKS do
        local body = GetMacroBody(chunkName(i))
        if type(body) ~= "string" or body == "" then break end
        parts[#parts + 1] = (body:gsub("^#", ""))
    end

    if #parts == 0 then return nil end
    return table.concat(parts)
end

-- =========================================================================
--  Application d'ensemble
-- =========================================================================

---@param mod table
local function applyAll(mod)
    if mod:IsEnabled() and mod:Get("fixStatTooltips") then
        applyStatTooltips()
    else
        restoreStatTooltips()
    end
end

--- Le bouton « enregistrer », et ce qu'il répond.
local function onSave()
    local ok, reason, count = saveToMacros()

    if ok then
        BUI:Print(BUI:Lf("Config macros saved", count))
        BUI:Print(BUI:Lf("Config macros hint", MACRO_NAME))
    elseif reason == "combat" then
        BUI:Print(L["Config macros combat"])
    elseif reason == "long" then
        BUI:Print(L["Config macros too long"])
    elseif reason == "full" then
        BUI:Print(L["Config macros full"])
    else
        BUI:Print(L["Export failed"])
    end
end

-- =========================================================================
--  Déclaration du module
-- =========================================================================

BUI:RegisterModule(MODULE, {
    title    = L["Beta fixes"],
    category = "Beta",
    order    = 90,

    defaults = {
        -- Sans ce correctif, ouvrir la fiche de personnage lève une erreur Lua
        -- sur tout client qui n'est pas anglais, et l'infobulle de la
        -- caractéristique ne s'affiche pas. Réparer un plantage du client n'est
        -- pas « changer le jeu » : c'est lui rendre ce qu'il annonce. Décocher
        -- la case redonne le bug, pour qui veut le constater.
        fixStatTooltips = true,  -- @default-on
    },

    options = {
        { type = "header", text = L["Client bugs"] },
        {
            type    = "toggle",
            key     = "fixStatTooltips",
            text    = L["Fix stat tooltips"],
            tooltip = L["Fix stat tooltips tip"],
        },

        { type = "header", text = L["Settings lost at launch"] },
        { type = "alert",  text = L["Settings lost at launch warning"] },
        {
            type    = "button",
            text    = L["Save config to macros"],
            label   = L["Save"],
            tooltip = L["Save config to macros tip"],
            onClick = onSave,
        },
        {
            type    = "button",
            text    = L["Restore config from macros"],
            label   = L["Restore"],
            tooltip = L["Restore config from macros tip"],
            onClick = function()
                BUI.Modules:Get(MODULE):RestoreConfig()
            end,
        },
    },

    --- Y a-t-il une configuration rangée dans des macros ? Lu par
    --- `Core/Forever.lua` pour savoir s'il a quelque chose à conseiller.
    ---@return boolean
    HasConfigMacros = function()
        return hasMacros()
    end,

    --- Relit les macros et remet la configuration qu'elles portent.
    ---
    --- Publique parce que la macro jouable l'appelle par son nom — c'est le
    --- seul point d'entrée que le joueur déclenche depuis une barre d'action.
    ---@param silent? boolean  ne rien dire quand il n'y a simplement rien à lire
    RestoreConfig = function(self, silent)
        local text = readMacros()
        if not text then
            if not silent then BUI:Print(L["Config macros missing"]) end
            return
        end

        local data = BUI.DB:ParseImport(text)
        local ok = BUI.DB:ValidateImport(data)
        if not ok or not BUI.DB:ImportProfile(data) then
            BUI:Print(L["Config macros invalid"])
            return
        end

        BUI:Print(L["Config macros restored"])
    end,

    OnEnable = function(self)
        applyAll(self)

        -- Les chaînes du client sont là dès le chargement ; cet abonnement ne
        -- sert qu'au cas où la fiche s'ouvre avant nous (module différé hors
        -- combat, rechargement à chaud).
        self:RegisterEvent("PLAYER_ENTERING_WORLD", function() applyAll(self) end)

        -- **Restauration automatique, sans case à cocher.** Une case ne peut pas
        -- commander ça : elle vivrait dans la base, c'est-à-dire dans ce que le
        -- client vient précisément de ne pas rendre — elle serait donc toujours
        -- décochée au moment où elle aurait à décider. Ce qui autorise la
        -- restauration, c'est **l'existence des macros**, et elle ne tient pas
        -- du défaut : personne ne les a sinon le joueur, en cliquant.
        --
        -- Deux conditions, et la seconde compte autant que la première : la base
        -- doit être revenue **vide**. Restaurer par-dessus des réglages qui sont
        -- bien là écraserait le travail de la session avec un code d'hier.
        if BUI.DB:LoadedEmpty() then
            C_Timer.After(1, function() self:RestoreConfig(true) end)
        end
    end,

    OnDisable = restoreStatTooltips,

    OnSettingChanged = function(self)
        applyAll(self)
    end,
})
