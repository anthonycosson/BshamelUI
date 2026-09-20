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
local W    = BUI.Widgets
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
--- Repose l'état d'origine d'**une** barre, et l'oublie.
---
--- C'est la moitié qui manquait, et son absence se voyait sur les boss. Un cadre
--- d'unité est **réemployé** : la même barre montre un chaman, puis le boss
--- qu'on cible ensuite. Or le client ne repeint pas une barre de vie à chaque
--- mise à jour — il pose son vert une fois et n'y revient que pour dire quelque
--- chose (unité pillée par un autre, joueur déconnecté). Une barre teinte en
--- bleu chaman le restait donc jusqu'à ce qu'un de ces cas se présente, et le
--- boss suivant héritait de la couleur du chaman précédent.
---
--- La couleur rendue est celle relevée **avant** notre première teinte, c'est-
--- à-dire le vert du client. L'oubli compte autant que la restitution : la
--- prochaine teinte relèvera la couleur d'alors, et non une valeur figée depuis
--- le début de la session.
---@param bar table
local function restoreBar(bar)
    local state = barColors[bar]
    if not state then return end
    barColors[bar] = nil

    if type(bar.SetStatusBarDesaturated) == "function" then
        pcall(bar.SetStatusBarDesaturated, bar, state.desaturated)
    end
    pcall(bar.SetStatusBarColor, bar, state[1], state[2], state[3], state[4])
end

--- La classe d'un adversaire d'arène, par le seul chemin qui reste quand
--- `UnitClass` se tait.
---
--- **En arène, le client cache la classe** — relevé par `/bui cadres` : une
--- cible dont `UnitIsPlayer` répond franchement `true` rend une classe secrète.
--- Il publie en revanche la **spécialisation** de chaque adversaire, et c'est
--- par là que ses propres cadres d'arène se colorent :
---
---     local specID, gender = GetArenaOpponentSpec(index)
---     local _, _, _, _, _, class = GetSpecializationInfoByID(specID, gender)
---
--- Reste à savoir de quel adversaire il s'agit. Les cadres de Blizzard n'ont pas
--- ce problème — chacun **est** `arena1`, `arena2`… — alors qu'une cible peut
--- être n'importe lequel : on l'apparie donc par `UnitIsUnit`, jeton par jeton.
---
--- Chaque lecture est gardée : le jour où l'un de ces trois maillons devient
--- secret à son tour, on rend `nil` et la barre reste au client.
---@param unit string
---@return string|nil  le jeton de classe, « MAGE » et compagnie
local function arenaClass(unit)
    if not (GetNumArenaOpponentSpecs and GetArenaOpponentSpec
            and GetSpecializationInfoByID) then
        return nil
    end

    local count = GetNumArenaOpponentSpecs()
    if U.IsSecret(count) or type(count) ~= "number" then return nil end

    for i = 1, count do
        if U.IsTrue(UnitIsUnit(unit, "arena" .. i)) then
            local specID, gender = GetArenaOpponentSpec(i)
            if U.IsSecret(specID) or type(specID) ~= "number" or specID <= 0 then
                return nil
            end

            local ok, _, _, _, _, _, class = pcall(GetSpecializationInfoByID, specID, gender)
            if not ok or U.IsSecret(class) or type(class) ~= "string" then return nil end

            return class
        end
    end

    return nil
end

--- Les unités qui ne sont pas des joueurs gardent la couleur du client : un
--- sanglier n'a pas de classe, et le vert dit déjà tout ce qu'il y a à dire.
---
--- `U.IsTrue` et non le booléen brut : un booléen secret ne se teste pas, et un
--- secret vaut donc « ce n'est pas un joueur ». Certains PNJ ont une classe dans
--- les données du jeu, chaman compris : sans ce garde-fou, ce sont eux qui
--- décideraient de la couleur.
---@param bar table|nil
---@param unit string|nil
local function colorBar(bar, unit)
    if not (bar and unit) then return end

    if not (U.IsTrue(UnitExists(unit)) and U.IsTrue(UnitIsPlayer(unit))) then
        restoreBar(bar)
        return
    end

    local _, class = UnitClass(unit)

    -- La classe cachée n'est pas la fin du chemin en arène : la spécialisation
    -- de l'adversaire, elle, est publiée.
    if U.IsSecret(class) then
        class = arenaClass(unit)
    end

    if class == nil or U.IsSecret(class) then
        restoreBar(bar)
        return
    end

    local color = T.ClassColor(class)
    if not color then
        restoreBar(bar)
        return
    end
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

    -- **On repeint à l'image suivante, pas dans l'appel du client.**
    --
    -- Un hook s'exécute *à l'intérieur* de l'appel qu'il coiffe : tout ce que
    -- notre code touche pendant ce temps **teinte l'exécution en cours**, et
    -- c'est la suite du code de Blizzard qui paie l'addition. Sur *Forever*,
    -- ouvrir la fiche de personnage lançait ainsi une lecture de la barre de
    -- vie du joueur, et le client comparait ses propres valeurs devenues
    -- secrètes : « attempt to compare a secret number value (execution tainted
    -- by BshamelUI) », sur une ligne où nous n'avions rien à faire.
    --
    -- Un report d'une image suffit : le client termine son passage sans nous,
    -- et la couleur se pose ensuite, dans une exécution qui n'appartient qu'à
    -- nous. L'œil ne voit pas la différence — c'est la même image.
    U.GuardedHook("UnitFrameHealthBar_Update", function(bar, unit)
        C_Timer.After(0, function()
            colorBar(bar, unit)
            colorTargetOfTarget()
        end)
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
-- On ne dessine donc rien : le client peint cette case, et on repasse derrière
-- lui à l'instant où il écrit.
--
-- **La spécialisation d'un autre joueur se lit dans son infobulle, elle ne se
-- demande pas au serveur.** C'est le point qui décide de tout le ressenti. Une
-- inspection (`NotifyInspect` / `INSPECT_READY`) est le chemin déclaré, et il
-- coûte un aller-retour serveur, une portée de quelques dizaines de mètres, et
-- une demande à la fois — l'icône arrivait donc toujours après coup, et parfois
-- pas du tout. Or le client **connaît déjà** la réponse : il l'écrit dans
-- l'infobulle de l'unité, et `C_TooltipInfo.GetUnit` rend ces lignes comme des
-- données, sans créer de frame et sans rien demander à personne. La réponse
-- tombe dans la même image que la question.

--- GUID -> identifiant de spécialisation, ou `false` quand l'infobulle n'en
--- portait pas. Une spécialisation ne change qu'au gré du joueur qui la porte :
--- ce cache tient toute la session sans mentir plus d'une poignée de secondes.
---
--- Le `false` compte autant que le nombre : sans lui, une unité sans ligne de
--- spécialisation ferait relire son infobulle à chaque passage.
local specByGUID = {}

--- classID -> { nom de spécialisation -> identifiant }
---
--- **Par classe, et c'est ce qui rend la lecture sûre.** Deux classes peuvent
--- porter le même nom de spécialisation — un druide et un chaman ont tous deux
--- une « Restauration ». Comme on connaît déjà la classe de l'unité, on ne
--- cherche que parmi les siennes : l'ambiguïté disparaît, et on n'a jamais
--- besoin du nom traduit de la classe, qui se décline en genre selon les langues
--- et demanderait une table d'exceptions par locale.
local specsByClass = {}

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

--- Spécialisations d'une classe, par leur nom traduit.
---@param classID number
---@return table<string, number>
local function specsForClass(classID)
    local cached = specsByClass[classID]
    if cached then return cached end

    local names = {}
    if GetNumSpecializationsForClassID and GetSpecializationInfoForClassID then
        for i = 1, GetNumSpecializationsForClassID(classID) do
            local id, name = GetSpecializationInfoForClassID(classID, i)
            if id and type(name) == "string" then names[name] = id end
        end
    end

    specsByClass[classID] = names
    return names
end

--- Spécialisation lue dans l'infobulle d'une unité.
---
--- `C_TooltipInfo` rend des **données**, donc sans créer la moindre frame — même
--- chemin que la fiche de personnage pour lire un objet équipé. Les champs d'une
--- ligne ne sont peuplés qu'après `SurfaceArgs` : sans ce passage, `leftText`
--- est absent et la boucle ne trouve jamais rien.
---
--- Une lecture d'infobulle alloue une table : cette fonction n'est donc appelée
--- que depuis un passage de rafraîchissement, jamais depuis un hook de texture
--- (règle 7). Le cache par GUID fait le reste.
---@param unit string
---@return number|nil
local function tooltipSpec(unit)
    if not (C_TooltipInfo and C_TooltipInfo.GetUnit) then return nil end

    local _, _, classID = UnitClass(unit)
    if U.IsSecret(classID) or type(classID) ~= "number" then return nil end

    local names = specsForClass(classID)
    if not next(names) then return nil end

    local data = C_TooltipInfo.GetUnit(unit)
    if not data then return nil end
    if TooltipUtil and TooltipUtil.SurfaceArgs then TooltipUtil.SurfaceArgs(data) end

    for _, line in ipairs(data.lines or {}) do
        local text = line.leftText
        if type(text) == "string" and not U.IsSecret(text) then
            for name, id in pairs(names) do
                if strfind(text, name, 1, true) then return id end
            end
        end
    end

    return nil
end

--- Spécialisation **déjà connue** d'une unité : le cache, et rien d'autre.
---
--- C'est la fonction que suivent les hooks de texture. Elle ne lit aucune
--- infobulle et n'alloue rien : à cet endroit-là, on peint ce qu'on sait ou on
--- ne peint pas.
---@param unit string
---@return number|nil
local function knownSpec(unit)
    if not (UnitExists(unit) and UnitIsPlayer(unit)) then return nil end
    -- `UnitIsUnit` rend un booléen **secret** dès que l'identité d'une des deux
    -- unités est protégée : le tester en direct lève (voir `U.IsTrue`).
    if U.IsTrue(UnitIsUnit(unit, "player")) then return playerSpec() end

    local guid = guidOf(unit)
    if not guid then return nil end
    return specByGUID[guid] or nil
end

--- Spécialisation d'une unité, en la cherchant si on ne l'a pas encore.
---
--- Appelée par les passages de rafraîchissement, elle est ce qui **remplit** le
--- cache que les hooks consultent ensuite.
---@param unit string
---@return number|nil
local function resolveSpec(unit)
    if not (UnitExists(unit) and UnitIsPlayer(unit)) then return nil end
    if U.IsTrue(UnitIsUnit(unit, "player")) then return playerSpec() end

    local guid = guidOf(unit)
    if not guid then return nil end

    local cached = specByGUID[guid]
    if cached ~= nil then return cached or nil end

    local specID = tooltipSpec(unit)
    specByGUID[guid] = specID or false
    return specID
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

--- Sommes-nous en train de poser l'icône ? Le hook posé sur la texture rappelle
--- notre propre pose ; ce drapeau coupe la boucle.
local painting = false

--- cadre -> unité qu'il montrait quand on a peint dessus.
---
--- **On ne rend que ce qu'on a pris.** Sans cette trace, la restitution repassait
--- sur les cinq cadres à chaque rafraîchissement, y compris quand l'option n'a
--- jamais été allumée — c'est-à-dire par défaut, et pour tout le monde.
local painted = {}

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

    painting = true
    pcall(portrait.SetTexture, portrait, file)
    if type(portrait.SetTexCoord) == "function" then
        pcall(portrait.SetTexCoord, portrait, 0, 1, 0, 1)
    end
    painting = false

    painted[frame] = unit
    return true
end

--- Atlas de classe que le client poserait à la place du visage, ou `nil` s'il
--- montrerait un visage.
---
--- C'est la reprise de `UnitFrame_ShouldReplacePortrait`, avec des gardes de
--- secret là où le client teste en direct. `U.IsTrue` fait qu'un secret vaut
--- « non » : on retombe alors sur le visage, qui est le défaut du client et le
--- seul repli honnête quand il refuse de nous dire à qui on parle.
---@param unit string
---@return string|nil
local function replacementAtlas(unit)
    if type(UnitIsHumanPlayer) ~= "function" then return nil end
    if not U.IsTrue(UnitIsHumanPlayer(unit)) then return nil end
    if type(GetClassAtlas) ~= "function" then return nil end

    local cvar = U.IsTrue(UnitIsUnit(unit, "player"))
                 and "ReplaceMyPlayerPortrait"
                 or  "ReplaceOtherPlayerPortraits"
    if U.GetCVar(cvar) ~= "1" then return nil end

    local _, class = UnitClass(unit)
    if U.IsSecret(class) or type(class) ~= "string" then return nil end
    return GetClassAtlas(class)
end

--- Rend son portrait au client, sans entrer dans son code.
---
--- **On ne rappelle pas `UnitFramePortrait_Update`, et c'est le point à ne pas
--- perdre.** Cette fonction demande à `UnitFrame_ShouldReplacePortrait` s'il faut
--- une icône de classe, qui lit `UnitIsUnit` et **teste le booléen rendu**. Ce
--- booléen est secret dès que l'identité de l'unité est protégée — une arène, un
--- champ de bataille — et un secret ne se teste pas depuis une exécution teintée
--- par un addon : c'est le code du client qui lève, une fois par cadre et par
--- passage. C'est la règle déjà écrite pour le pilote des barres d'infos : on
--- n'entre pas dans le code de mise en page du client, et il n'existe pas de
--- version prudente de cet appel.
---
--- On refait donc son choix nous-mêmes, et de la même façon : l'icône de classe
--- s'il l'aurait posée, le visage sinon. `SetPortraitTexture` est la fonction
--- qu'il appelle lui-même dans ce dernier cas ; elle ne lit rien de secret.
---@param frame table
---@param unit string
local function repaintPortrait(frame, unit)
    local portrait = portraitOf(frame)
    if not portrait then return end

    painting = true

    if type(portrait.SetTexCoord) == "function" then
        pcall(portrait.SetTexCoord, portrait, 0, 1, 0, 1)
    end

    local atlas = replacementAtlas(unit)
    if atlas and type(portrait.SetAtlas) == "function" then
        pcall(portrait.SetAtlas, portrait, atlas)
    elseif type(SetPortraitTexture) == "function" then
        pcall(SetPortraitTexture, portrait, unit, frame.disablePortraitMask)
    end

    painting = false
end

--- Rend leur portrait aux seuls cadres sur lesquels on a peint.
local function restorePortraits()
    for frame, unit in pairs(painted) do
        repaintPortrait(frame, unit)
    end
    wipe(painted)
end

---@param mod table
local function applySpecIcons(mod)
    if not mod:Get("specIcon") then
        restorePortraits()
        return
    end

    eachUnitFrame(function(frame, unit)
        -- La résolution d'abord : elle remplit le cache que les hooks de texture
        -- consultent. Sans elle, une cible jamais vue n'aurait son icône qu'à la
        -- prochaine écriture du client — et c'est exactement le délai qu'on
        -- cherche à supprimer.
        resolveSpec(unit)
        paintPortrait(frame, unit)
    end)
end

--- S'accroche au moment où le client peint un portrait.
---
--- **Deux hooks, et il en faut deux.** `UnitFramePortrait_Update` est le chemin
--- déclaré, mais s'y arrimer seul laisse voir le visage un instant avant
--- l'icône : le client ne peint pas toujours par là, et surtout il repasse sur
--- la case après avoir annoncé le changement de cible. Le second hook est posé
--- sur **la texture elle-même** — quoi qu'il pose, et quand qu'il le pose, on
--- repose l'icône dans le même souffle. Il n'y a plus de course à courir : c'est
--- l'écriture du client qui déclenche la nôtre.
---
--- Une minuterie ne pouvait pas y arriver. Elle parie sur le moment où le client
--- s'y met, et ce pari se perd des deux côtés : trop tôt on peint l'ancienne
--- cible, trop tard le joueur a vu le portrait par défaut.
---@param mod table
local function hookPortraits(mod)
    local guard = function()
        return mod:IsEnabled() and mod:Get("specIcon") == true
    end

    if type(UnitFramePortrait_Update) == "function" then
        U.GuardedHook("UnitFramePortrait_Update", function(frame)
            if type(frame) ~= "table" or not frame.unit then return end
            paintPortrait(frame, frame.unit)
        end, guard)
    end

    eachUnitFrame(function(frame, unit)
        local portrait = portraitOf(frame)
        if not portrait then return end

        U.GuardedHook(portrait, "SetTexture", function()
            if painting then return end
            paintPortrait(frame, unit)
        end, guard)
    end)
end

-- =========================================================================
--  Couleur de réputation derrière la cible
-- =========================================================================
-- La plaque colorée posée derrière le nom de la cible dit sa faction. Elle est
-- repeinte par le client à chaque changement de cible, et la teindre une fois ne
-- suffit donc pas : on se branche sur le moment où il la repeint.
--
-- **On la masque, une fois, et elle reste masquée.** C'est la conclusion de deux
-- tentatives ratées, et elle tient en une phrase : le client ne réaffiche jamais
-- cette plaque, parce qu'il ne la cache jamais.
--
--   · `CheckFaction` recalcule sa *couleur*, et rien d'autre. Lui demander de
--     recalculer ne rend donc pas une plaque masquée — d'où un réglage qui ne
--     revenait pas quand on le décochait. La restitution, c'est `Show`, pas un
--     recalcul ;
--   · une opacité nulle marchait, mais elle demandait de courir après chaque
--     écriture d'opacité du client, avec le battement visible que cela suppose.
--
-- `Hide` est persistant, donc gratuit : il n'y a rien à repasser à chaque
-- changement de cible, et rien qui puisse arriver en retard. Le hook sur `Show`
-- n'est qu'un garde — si une écriture du client rendait un jour la plaque, elle
-- serait défaite dans le même souffle.

local REPUTATION_FRAMES = { "TargetFrame", "FocusFrame" }

--- plaque -> était-elle affichée avant qu'on la masque
local repShown = {}

---@param frame table|nil
---@return table|nil
local function reputationColorOf(frame)
    local content = frame and frame.TargetFrameContent
    local main    = content and content.TargetFrameContentMain
    local region  = main and main.ReputationColor

    if type(region) == "table" and type(region.Hide) == "function" then return region end
    return nil
end

--- Masque une plaque, en retenant si elle était affichée.
---@param region table
local function hideReputationColor(region)
    if repShown[region] == nil then
        local ok, shown = pcall(region.IsShown, region)
        repShown[region] = (ok and shown) and true or false
    end
    pcall(region.Hide, region)
end

--- Rend leur état aux plaques qu'on avait masquées.
local function restoreReputationColor()
    for region, shown in pairs(repShown) do
        if shown then pcall(region.Show, region) else pcall(region.Hide, region) end
    end
    wipe(repShown)
end

---@param mod table
local function applyReputationColor(mod)
    if not mod:Get("hideReputationColor") then
        restoreReputationColor()
        return
    end

    for i = 1, #REPUTATION_FRAMES do
        local region = reputationColorOf(_G[REPUTATION_FRAMES[i]])
        if region then hideReputationColor(region) end
    end
end

--- Garde posé sur la plaque : si quelque chose la rend visible, elle repart.
---
--- Le hook est sur **la texture**, pas sur la fonction censée la peindre : il
--- n'a donc aucun moment à deviner, et il ne peut pas arriver en retard. Il ne
--- sert normalement jamais — `Hide` est persistant — mais il coûte un test et
--- il rend le réglage insensible à ce que le client changerait un jour.
---
--- Pas de récursion possible : masquer ne déclenche pas `Show`.
---@param mod table
local function hookReputationColor(mod)
    local guard = function()
        return mod:IsEnabled() and mod:Get("hideReputationColor") == true
    end

    for i = 1, #REPUTATION_FRAMES do
        local region = reputationColorOf(_G[REPUTATION_FRAMES[i]])
        if region then
            U.GuardedHook(region, "Show", function(self)
                hideReputationColor(self)
            end, guard)
        end
    end
end

-- =========================================================================
--  Décorations que l'on peut éteindre
-- =========================================================================
-- Le client pose sur ses cadres des éléments qui ne disent rien qu'on ne sache
-- déjà : la lueur qui clignote quand on est en combat, l'effet de repos, la
-- pastille de coin, l'icône de prestige. Chacun s'éteint séparément.
--
-- **On les range sous un parent masqué, on ne les cache pas.** Ce sont des
-- éléments *contextuels* : le client les montre et les cache lui-même selon la
-- situation, et deux d'entre eux portent une animation qui pilote leur opacité.
-- Un `Hide` comme un `SetAlpha(0)` seraient donc défaits au passage suivant —
-- avec le battement visible que cela suppose. Sous un parent masqué, il n'y a
-- plus rien à repasser ni aucun moment à deviner (voir `W.Hidden`).

--- Réglage -> chemins des éléments qu'il éteint.
---
--- Un chemin est une suite de clés à partir d'une globale. On descend clé à
--- clé, et une clé absente arrête la descente sans rien casser : c'est la forme
--- que prend ici le test de capacité, pour des chemins que Blizzard réorganise
--- d'une extension à l'autre.
local DECORATIONS = {
    hideRestedEffect = {
        { "PlayerFrame", "PlayerFrameContent", "PlayerFrameContentContextual", "PlayerRestLoop" },
    },

    hideCornerIcon = {
        { "PlayerFrame", "PlayerFrameContent", "PlayerFrameContentContextual",
          "PlayerPortraitCornerIcon" },
    },

    -- **Tous les cadres qui clignotent, pas seulement le vôtre.** La lueur de
    -- combat n'est pas une décoration du cadre du joueur : c'est un même signal
    -- posé sur chaque cadre engagé — le joueur, son familier, la cible, le focus
    -- et les boss. N'en éteindre qu'une partie ne se lit pas comme un réglage
    -- partiel mais comme un réglage qui ne marche pas, et c'est exactement ce
    -- qui s'est produit : le cadre du joueur se taisait, celui de la cible
    -- continuait de battre.
    --
    -- Le nom de la texture n'est d'ailleurs pas le même partout — `FrameFlash`
    -- chez le joueur, `Flash` chez la cible — ce qui est une raison de plus de
    -- les citer une par une plutôt que de croire à une convention.
    hideCombatGlow = {
        { "PlayerFrame", "PlayerFrameContainer", "FrameFlash" },
        { "TargetFrame", "TargetFrameContainer", "Flash" },
        { "FocusFrame",  "TargetFrameContainer", "Flash" },
        { "PetFrameFlash" },
        { "PetAttackModeTexture" },
    },

    -- Le badge et le portrait de prestige vont ensemble, et l'icône PvP avec
    -- eux : c'est une seule décoration pour le joueur, qui la voit comme telle.
    -- Elle est éteinte sur les trois cadres qui la portent — la couper sur la
    -- cible et la garder sur le focus serait un réglage à moitié appliqué.
    hidePvpIcon = {
        { "PlayerFrame", "PlayerFrameContent", "PlayerFrameContentContextual", "PrestigeBadge" },
        { "PlayerFrame", "PlayerFrameContent", "PlayerFrameContentContextual", "PrestigePortrait" },
        { "PlayerFrame", "PlayerFrameContent", "PlayerFrameContentContextual", "PvpIcon" },
        { "TargetFrame", "TargetFrameContent", "TargetFrameContentContextual", "PrestigeBadge" },
        { "TargetFrame", "TargetFrameContent", "TargetFrameContentContextual", "PrestigePortrait" },
        { "TargetFrame", "TargetFrameContent", "TargetFrameContentContextual", "PvpIcon" },
        { "FocusFrame", "TargetFrameContent", "TargetFrameContentContextual", "PrestigeBadge" },
        { "FocusFrame", "TargetFrameContent", "TargetFrameContentContextual", "PrestigePortrait" },
        { "FocusFrame", "TargetFrameContent", "TargetFrameContentContextual", "PvpIcon" },
    },
}

-- Les cadres de boss portent la même lueur, sous le même chemin. Cinq lignes
-- identiques à une lettre près se recopient mal : on les engendre.
for i = 1, 5 do
    local glows = DECORATIONS.hideCombatGlow
    glows[#glows + 1] = { "Boss" .. i .. "TargetFrame", "TargetFrameContainer", "Flash" }
end

--- élément rangé -> son parent d'origine
local stowed = {}

--- Élément désigné par un chemin, ou `nil` si le client ne l'a plus.
---@param path string[]
---@return table|nil
local function resolve(path)
    local node = _G[path[1]]
    for i = 2, #path do
        if type(node) ~= "table" then return nil end
        node = node[path[i]]
    end

    if type(node) == "table" and type(node.SetParent) == "function" then return node end
    return nil
end

---@param region table
local function stow(region)
    if stowed[region] then return end

    local ok, parent = pcall(region.GetParent, region)
    if not ok or type(parent) ~= "table" then return end

    stowed[region] = parent
    pcall(region.SetParent, region, W.Hidden())
end

---@param region table
local function release(region)
    local parent = stowed[region]
    if not parent then return end

    stowed[region] = nil
    pcall(region.SetParent, region, parent)
end

--- Rend tous les éléments rangés, sans relire les réglages.
local function releaseAll()
    for region, parent in pairs(stowed) do
        pcall(region.SetParent, region, parent)
    end
    wipe(stowed)
end

-- -------------------------------------------------------------------------
--  La bande du nom du joueur : deux réglages, une seule texture
-- -------------------------------------------------------------------------
-- `StatusTexture` est la bande qui s'allume sur le nom et le portrait. Elle ne
-- se range pas sous le parent masqué comme les autres décorations, parce
-- qu'elle sert **deux fois** : dorée au repos, rouge en combat. La ranger
-- éteindrait les deux d'un coup, alors que ce sont deux réglages distincts et
-- que le joueur peut n'en vouloir qu'un.
--
-- On la cache donc à la main, et on lui demande d'abord ce qu'elle **dit à cet
-- instant**. L'ordre du test est celui du client (`PlayerFrame_UpdateStatus`) :
-- le repos d'abord, le combat ensuite. Chaque état a sa case, et la bande suit
-- celle de l'état en cours.
--
-- C'est ce qui rattache la bande dorée à « masquer l'effet de repos » : le ZZZ
-- et elle sont une seule chose pour qui la regarde, et n'en éteindre qu'une se
-- lit comme un réglage qui ne marche qu'à moitié.

---@return table|nil
local function statusTexture()
    local content = PlayerFrame and PlayerFrame.PlayerFrameContent
    local main    = content and content.PlayerFrameContentMain
    local region  = main and main.StatusTexture

    if type(region) == "table" and type(region.Hide) == "function" then return region end
    return nil
end

--- Ce que la bande dit à cet instant : `"rest"`, `"combat"`, ou `nil` quand
--- elle ne dit rien — le client la cache alors lui-même, et il n'y a pas de
--- décision à prendre.
---
--- `inCombat` vaut `1` et non `true` : le client l'écrit en nombre. Un test
--- d'égalité à `true` ne passait jamais, et la bande restait. Il ne vaut
--- d'ailleurs pas « en combat » mais « en **attaque automatique** »
--- (`PLAYER_ENTER_COMBAT`) — d'où un défaut qui semblait aléatoire : la bande
--- ne s'allume qu'au corps à corps, pas quand on se bat aux sorts.
---@return string|nil
local function statusMeans()
    if U.IsTrue(IsResting()) then return "rest" end
    if PlayerFrame ~= nil and PlayerFrame.inCombat ~= nil then return "combat" end
    return nil
end

--- Ce que dit la bande -> le réglage qui décide de la montrer.
local STATUS_KEY = {
    rest   = "hideRestedEffect",
    combat = "hideCombatGlow",
}

--- La bande doit-elle être cachée, dans l'état où elle est ?
---@param mod table
---@return boolean
local function statusHidden(mod)
    local means = statusMeans()
    if not means then return false end
    return mod:IsEnabled() and mod:Get(STATUS_KEY[means]) == true
end

---@param mod table
local function applyStatusBand(mod)
    local region = statusTexture()
    if not (region and statusMeans()) then return end

    if statusHidden(mod) then
        pcall(region.Hide, region)
    else
        pcall(region.Show, region)
    end
end

--- Le client la remontre à chaque changement d'état : on repasse derrière, au
--- moment même où il l'écrit. Même motif que la plaque de réputation.
---
--- La garde ne retient que l'activation du module : c'est le corps qui sait
--- quelle case commande la bande à cet instant, et cette question se repose à
--- chaque passage.
---@param mod table
local function hookStatusBand(mod)
    local region = statusTexture()
    if not region then return end

    U.GuardedHook(region, "Show", function(self)
        if statusHidden(mod) then pcall(self.Hide, self) end
    end, function()
        return mod:IsEnabled()
    end)
end

---@param mod table
local function applyDecorations(mod)
    applyStatusBand(mod)

    -- Ces éléments pendent de cadres protégés : les reparenter en combat lève
    -- une erreur d'action bloquée. Ce qui est refusé ici est rattrapé à la
    -- sortie de combat (voir `OnEnable`).
    if InCombatLockdown() then return end

    for key, paths in pairs(DECORATIONS) do
        local on = mod:Get(key)
        for i = 1, #paths do
            local region = resolve(paths[i])
            if region then
                if on then stow(region) else release(region) end
            end
        end
    end
end

-- =========================================================================
--  Taille des cadres de groupe et d'arène
-- =========================================================================
-- Le mode Édition règle la taille de ces cadres par une échelle, et borne son
-- curseur. On pose la même échelle qu'il poserait, sans la borne.
--
-- C'est une **échelle absolue** et non un multiplicateur de la sienne : le
-- réglage remplace le sien tant qu'il est allumé, et le lui rend quand il
-- s'éteint. Deux valeurs qui se multiplieraient donneraient un résultat que ni
-- l'une ni l'autre des deux fenêtres n'annonce.
--
-- Deux systèmes, un seul mécanisme. Ils ne partagent pas leur réglage — un
-- cadre de groupe se lit en donjon, un cadre d'arène se lit à trois contre trois,
-- et rien ne dit que la même taille convienne aux deux — mais tout le reste leur
-- est commun.

--- Systèmes réglables, avec les réglages qui les commandent et les cadres qui
--- les portent.
---
--- Les cadres sont désignés par leur nom global et résolus à chaque passage : un
--- nom qui ne répond pas est simplement sauté. C'est ce qui rend la liste d'arène
--- sûre à écrire — l'interface d'arène est **chargée à la demande**, et ses cadres
--- n'existent pas tant qu'on n'est pas entré en arène.
---
--- Citer plusieurs noms par système n'est pas de la prudence : le client a **deux
--- styles** pour ces cadres, celui du jeu et celui « façon raid », et le joueur
--- bascule de l'un à l'autre sans nous prévenir. Le mode Édition sait lequel est
--- à l'écran ; nous, non — et mettre à l'échelle un cadre caché ne coûte rien.
local SCALED_SYSTEMS = {
    {
        toggle = "enlargeParty",
        slider = "partyScale",
        frames = { "CompactPartyFrame", "PartyFrame" },
    },
    {
        toggle = "enlargeArena",
        slider = "arenaScale",
        -- `CompactArenaFrame` est le style façon raid, celui qui porte des
        -- `CompactArenaFrameMemberN` ; les deux autres sont le style du jeu — le
        -- conteneur de la rencontre, et celui de la phase de préparation. Ce
        -- dernier compte : une taille qui change au moment où les portes
        -- s'ouvrent se lit comme un défaut.
        frames = { "CompactArenaFrame",
                   "ArenaEnemyFramesContainer", "ArenaEnemyPrepFramesContainer" },
    },
}

--- cadre -> échelle qu'il portait avant qu'on y touche.
---
--- Un seul registre pour les deux systèmes : c'est le cadre qui porte son
--- échelle d'origine, pas le réglage qui l'a changée.
local frameScales = {}

--- Repose l'échelle d'un cadre et l'oublie.
---
--- Le mode Édition est ensuite invité à recalculer la sienne s'il sait le faire :
--- il a le dernier mot, parce que le joueur a pu déplacer son curseur pendant que
--- le nôtre tenait la barre.
---@param frame table
local function restoreFrameScale(frame)
    local scale = frameScales[frame]
    if not scale then return end
    frameScales[frame] = nil

    BUI.safecall(frame.SetScale, frame, scale)
    if type(frame.UpdateSystemSettingFrameSize) == "function" then
        BUI.safecall(frame.UpdateSystemSettingFrameSize, frame)
    end
end

--- Rend leur échelle aux cadres d'un système.
---@param system table
local function restoreSystemScale(system)
    if InCombatLockdown() then return end

    for i = 1, #system.frames do
        local frame = _G[system.frames[i]]
        if type(frame) == "table" then restoreFrameScale(frame) end
    end
end

--- Rend son échelle à tout ce qu'on a agrandi, sans relire un seul réglage.
--- Appelé par `OnDisable` : le module s'éteint, ce qu'il a posé doit disparaître
--- même si les interrupteurs restent cochés.
local function restoreAllScales()
    if InCombatLockdown() then return end

    for frame in pairs(frameScales) do
        restoreFrameScale(frame)
    end
    wipe(frameScales)
end

--- Ce cadre descend-il d'un autre cadre du même système ?
---
--- Deux échelles emboîtées se **multiplient** : citer par mégarde un cadre et son
--- parent poserait 150 % deux fois, soit 225 %, et le curseur mentirait sans que
--- rien ne le signale — un réglage qui « va trop loin » ne ressemble pas à une
--- liste mal écrite. Les listes ci-dessus sont écrites en frères, mais elles sont
--- écrites à la main, à partir de noms relevés sur un client : on vérifie plutôt
--- que de parier, et la vérification coûte une remontée de parents sur un chemin
--- qui n'est pas chaud.
---@param frame table
---@param others table  cadre -> vrai, les cadres du même système
---@return boolean
local function nestedIn(frame, others)
    local parent = frame
    while true do
        if type(parent.GetParent) ~= "function" then return false end
        parent = parent:GetParent()
        if type(parent) ~= "table" then return false end
        if others[parent] then return true end
    end
end

---@param mod table
---@param system table
local function applySystemScale(mod, system)
    -- Cadres protégés : les redimensionner en combat lève une erreur d'action
    -- bloquée. Ce qui est refusé ici est rattrapé à la sortie de combat, où
    -- `OnEnable` rappelle cette fonction.
    --
    -- L'arène en paie le prix le plus visible : on y est en combat du début à la
    -- fin d'une manche. C'est la phase de préparation qui sauve le réglage — les
    -- portes fermées, on est hors combat, et l'échelle posée là tient pour toute
    -- la manche puisque rien ne la repose entre-temps.
    if InCombatLockdown() then return end

    if not mod:Get(system.toggle) then
        restoreSystemScale(system)
        return
    end

    local scale = mod:Get(system.slider) / 100

    -- Les cadres présents à cet instant sont relevés **avant** d'être touchés :
    -- écarter celui qui descend d'un autre suppose de connaître déjà les autres.
    local present, order = {}, {}
    for i = 1, #system.frames do
        local frame = _G[system.frames[i]]
        if type(frame) == "table" and type(frame.SetScale) == "function" then
            present[frame]    = true
            order[#order + 1] = frame
        end
    end

    for i = 1, #order do
        local frame = order[i]
        if not nestedIn(frame, present) then
            if frameScales[frame] == nil then
                frameScales[frame] = frame:GetScale() or 1
            end
            BUI.safecall(frame.SetScale, frame, scale)
        end
    end
end

---@param mod table
local function applyScales(mod)
    for i = 1, #SCALED_SYSTEMS do
        applySystemScale(mod, SCALED_SYSTEMS[i])
    end
end

--- Garde d'un système, construite une fois. Elle retrouve le module au lieu de
--- le capturer : `hookScaledFrames` est rappelée à chaque changement de groupe,
--- et une fermeture par appel serait une fermeture jetée à chaque appel (règle 7).
---@param toggle string
---@return fun(): boolean
local function scaleGuard(toggle)
    return function()
        local mod = BUI.Modules:Get(MODULE)
        return (mod and mod:IsEnabled() and mod:Get(toggle) == true) or false
    end
end

for i = 1, #SCALED_SYSTEMS do
    SCALED_SYSTEMS[i].guard = scaleGuard(SCALED_SYSTEMS[i].toggle)
end

--- S'accroche au moment où le mode Édition repose sa taille.
---
--- Sans ce hook, ouvrir puis fermer le mode Édition — ou simplement changer de
--- disposition — ramènerait les cadres à la taille bornée, et le réglage aurait
--- l'air de « ne pas tenir ». Le hook ne rappelle pas la fonction qu'il coiffe :
--- il repose l'échelle directement, il n'y a donc pas de boucle.
---@param mod table
local function hookScaledFrames(mod)
    for i = 1, #SCALED_SYSTEMS do
        local system = SCALED_SYSTEMS[i]

        for j = 1, #system.frames do
            local frame = _G[system.frames[j]]
            if type(frame) == "table"
               and type(frame.UpdateSystemSettingFrameSize) == "function" then
                U.GuardedHook(frame, "UpdateSystemSettingFrameSize", function()
                    applySystemScale(mod, system)
                end, system.guard)
            end
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
    applyDecorations(mod)
    applyScales(mod)
end

--- Réglage -> fonction qui le pose.
local APPLIERS = {
    classColorHealth    = applyClassColors,
    specIcon            = applySpecIcons,
    hideReputationColor = applyReputationColor,
    enlargeParty        = applyScales,
    partyScale          = applyScales,
    enlargeArena        = applyScales,
    arenaScale          = applyScales,
}

for key in pairs(DECORATIONS) do
    APPLIERS[key] = applyDecorations
end

-- =========================================================================
--  Déclaration du module
-- =========================================================================

BUI:RegisterModule(MODULE, {
    title    = L["Unit frames"],
    category = "Interface",
    order    = 10,
    secure   = true,

    defaults = {
        classColorHealth    = false,
        hideReputationColor = false,

        specIcon     = false,

        hideRestedEffect = false,
        hideCornerIcon   = false,
        hideCombatGlow   = false,
        hidePvpIcon      = false,

        enlargeParty = false,
        -- 100 % : l'échelle que le cadre porte déjà. Allumer l'interrupteur sans
        -- toucher au curseur ne change donc rien à l'écran, ce qui est la seule
        -- valeur de départ honnête — le joueur monte ensuite jusqu'où il veut.
        partyScale   = 100,

        enlargeArena = false,
        arenaScale   = 100,
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
            key     = "specIcon",
            text    = L["Show spec icon"],
            tooltip = L["Show spec icon tip"],
        },

        { type = "header", text = L["Decorations"] },
        {
            type    = "toggle",
            key     = "hideRestedEffect",
            text    = L["Hide rested effect"],
            tooltip = L["Hide rested effect tip"],
        },
        {
            type    = "toggle",
            key     = "hideCornerIcon",
            text    = L["Hide corner icon"],
            tooltip = L["Hide corner icon tip"],
        },
        {
            type    = "toggle",
            key     = "hideCombatGlow",
            text    = L["Hide combat glow"],
            tooltip = L["Hide combat glow tip"],
        },
        {
            type    = "toggle",
            key     = "hidePvpIcon",
            text    = L["Hide PvP icon"],
            tooltip = L["Hide PvP icon tip"],
        },
        {
            type    = "toggle",
            key     = "hideReputationColor",
            text    = L["Hide reputation color"],
            tooltip = L["Hide reputation color tip"],
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

        { type = "header", text = L["Arena frames"] },
        {
            type    = "toggle",
            key     = "enlargeArena",
            text    = L["Enlarge arena frames"],
            tooltip = L["Enlarge arena frames tip"],
        },
        {
            type     = "slider",
            key      = "arenaScale",
            text     = L["Arena frame scale"],
            tooltip  = L["Arena frame scale tip"],
            min      = 100,
            max      = 250,
            step     = 5,
            disabled = requires("enlargeArena"),
        },
    },

    OnEnable = function(self)
        applyAll(self)

        hookHealthBars(self)
        hookPortraits(self)
        hookReputationColor(self)
        hookStatusBand(self)
        hookScaledFrames(self)

        -- **Ce qui se voit ne passe pas par ici.** Barre de vie, portrait et
        -- plaque de faction sont reposés par les hooks ci-dessus, au moment même
        -- où le client écrit dessus : il n'y a aucun délai à rattraper, et aucun
        -- réglage n'attend un passage pour s'appliquer.
        --
        -- Les deux passages qui suivent ne servent qu'à ce qu'aucune écriture du
        -- client n'annonce :
        --
        --   · le premier, immédiat, **lance les demandes d'inspection**. C'est
        --     la seule chose qui doive partir tôt, parce que la réponse vient du
        --     serveur : tout retard pris ici s'ajoute au sien ;
        --   · le second, groupé, est le filet. La cible de la cible n'est pas
        --     résolue au moment où la cible l'est, et un cadre peut naître en
        --     cours de route — d'où le repostage des hooks, que `GuardedHook`
        --     rend gratuit quand il n'y a rien de neuf.
        local function pass()
            hookPortraits(self)
            hookReputationColor(self)

            applyClassColors(self)
            applySpecIcons(self)
            applyReputationColor(self)
        end

        local settle = U.Debounce(T.TIMING.UNIT_SETTLE, pass)

        local function refresh()
            pass()
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

        -- Un cadre de groupe peut n'exister qu'une fois le groupe formé, et un
        -- hook ne se pose que sur un cadre qui existe : on repasse. `GuardedHook`
        -- ne pose jamais deux fois le même, rappeler ne coûte donc rien.
        local rescale = function()
            hookScaledFrames(self)
            applyScales(self)

            -- Les décorations pendent de cadres protégés, comme les cadres de
            -- groupe : elles se reposent aux mêmes moments, et pour la même
            -- raison — ce que le combat a refusé se rattrape à sa sortie.
            applyDecorations(self)
        end

        self:RegisterEvent("GROUP_ROSTER_UPDATE",       rescale)
        self:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED", rescale)
        self:RegisterEvent("PLAYER_ENTERING_WORLD",     rescale)

        -- Ce que le combat a refusé est rattrapé ici.
        self:RegisterEvent("PLAYER_REGEN_ENABLED", rescale)

        -- L'interface d'arène est **chargée à la demande** : aucun des événements
        -- ci-dessus ne tombe après la naissance de ses cadres, et poser un hook
        -- sur un cadre qui n'existe pas encore ne fait rien. On repasse donc au
        -- chargement de son addon, puis à chaque annonce d'adversaire — le client
        -- monte et cache ces cadres au fil de la manche.
        --
        -- Les décorations n'ont pas bougé : on ne repasse que sur les échelles.
        local rescaleArena = function()
            hookScaledFrames(self)
            applyScales(self)
        end

        self:RegisterEvent("ADDON_LOADED", function(_, name)
            if name == "Blizzard_ArenaUI" then rescaleArena() end
        end)
        self:RegisterEvent("ARENA_OPPONENT_UPDATE", rescaleArena)
    end,

    --- `/bui cadres` : pourquoi la barre de la cible n'a pas la couleur de sa
    --- classe.
    ---
    --- Trois réponses possibles, et elles se ressemblent toutes de l'écran — la
    --- barre est verte :
    ---
    ---   · l'unité n'est pas un joueur, et c'est juste ;
    ---   · le client **cache** si c'en est un (`UnitIsPlayer` secret), ce qu'il
    ---     fait en arène, et le garde-fou renonce avant même de lire la classe ;
    ---   · il laisse dire que c'en est un mais **cache la classe**.
    ---
    --- Seul le troisième cas est sans issue. Le deuxième ne l'est peut-être pas,
    --- et c'est cette ligne-là qui le dira. Même motif que `/bui noms` : la prose
    --- est traduite, les noms d'API sont bruts.
    DiagnoseFrames = function(self)
        self:Print(L["Frame diagnostic"])

        --- Ce que le client répond, ou « secret » quand il refuse de conclure.
        ---@param value any
        ---@return string
        local function tell(value)
            if U.IsSecret(value) then return L["Frame diagnostic secret"] end
            return tostring(value)
        end

        for _, unit in ipairs({ "target", "focus" }) do
            if not U.IsTrue(UnitExists(unit)) then
                self:Print(unit, L["Frame diagnostic absent"])
            else
                local _, class = UnitClass(unit)

                self:Print(unit,
                    "UnitIsPlayer:", tell(UnitIsPlayer(unit)),
                    "— UnitClass:", tell(class),
                    "— " .. L["Frame diagnostic arena"], tostring(arenaClass(unit)))
            end
        end

        -- Le réglage du client pour les couleurs de classe sur les cadres PvP.
        -- Il ne commande pas les nôtres, mais s'il est éteint, la question ne se
        -- pose peut-être pas là où on la croit.
        self:Print("pvpFramesDisplayClassColor:",
            tostring(U.GetCVar("pvpFramesDisplayClassColor")))
    end,

    OnDisable = function()
        -- On rend sans relire les réglages : le module s'éteint, ce qu'il a
        -- posé doit disparaître même si les interrupteurs restent cochés.
        restoreBars()
        restorePortraits()
        restoreReputationColor()
        releaseAll()
        restoreAllScales()

        -- La bande du nom : rendue si l'état du joueur la réclame encore, qu'il
        -- s'agisse du repos ou du combat.
        local region = statusTexture()
        if region and statusMeans() then pcall(region.Show, region) end
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
