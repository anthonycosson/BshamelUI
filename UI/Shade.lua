-- =========================================================================
--  Bshamel UI — UI/Shade.lua
--  Moteur du mode sombre : assombrit l'habillage du client, et sait le rendre.
--
--  Principe : on **multiplie** la couleur de sommet des textures existantes, on
--  ne pose aucun voile par-dessus. Un voile dépend de l'ordre des calques d'un
--  cadre qui ne nous appartient pas — si le client dessine son habillage
--  au-dessus, le voile ne se voit jamais. La multiplication agit sur la texture
--  elle-même, quel que soit le calque (même raison que `T.SetPanelFill`).
--
--  Assombrir ne suffit pas : l'habillage du client est doré, et une multiplication
--  seule donne un doré foncé, pas du sombre. Les textures d'habillage sont donc
--  **désaturées** avant d'être assombries. Les icônes, elles, gardent leurs
--  couleurs : une icône de sort désaturée n'est plus reconnaissable.
--
--  **Les icônes ne sont jamais teintées**, et presque jamais dessinées :
--    · un bouton d'action, une infobulle, un cadre d'unité ont déjà un contour
--      — une texture d'habillage distincte de l'icône, avec ses coins arrondis.
--      La teinter fonce le contour et rien d'autre. Y ajouter un trait poserait
--      un carré derrière une forme ronde (voir `dev/docs/API_NOTES.md`) ;
--    · une icône d'aura, comme un emplacement du gestionnaire de temps de
--      recharge, est un carré nu : le client ne lui dessine aucun contour, il
--      n'y a donc rien à teinter et le trait doit être tracé. Ces cas-là sont
--      déclarés dans `ICON_BORDERS`, et ils y sont tous.
--
--  Réversibilité : couleur et désaturation d'origine sont relevées avant la
--  première teinte et conservées. `Restore` les repose telles quelles — c'est ce
--  qui permet à `OnDisable` de rendre le module indétectable (CLAUDE.md règle 6).
--  Repeindre est idempotent : on rend d'abord, on recollecte, on reteinte.
--
--  Ce qu'on ne touche jamais :
--    · la texture de remplissage d'une barre de statut — c'est la donnée (vie,
--      ressource, temps restant), pas l'habillage ;
--    · les portraits et icônes de classe : les assombrir barbouille le visage du
--      personnage, ce que personne ne demande en cochant « mode sombre » ;
--    · les objets `Cooldown`, dont le balayage est peint par le moteur ;
--    · tout cadre `IsForbidden` : y toucher lève une erreur.
--
--  Les cadres du client sont résolus par leur nom global **à chaque passage**, et
--  une absence est ignorée. C'est la forme que prend ici la règle « test de
--  capacité, jamais de numéro de patch » : une fenêtre qui n'existe pas encore
--  (chargée à la demande, créée en entrant en groupe) ou plus (retirée à une
--  extension) ne casse rien.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local U    = BUI.Util

local S = {}
BUI.Shade = S

--- Voir `U.IsSecret`, où le prédicat vit depuis qu'un deuxième fichier s'en
--- sert. Il n'écarte qu'une **valeur** dont on s'apprête à faire un calcul,
--- jamais le cadre qui la porte : écarter un cadre sur ce soupçon reviendrait à
--- décider qu'il est intouchable sans avoir essayé, et c'est précisément ce qui
--- a fait disparaître les cadres d'unités d'un mode sombre qui les traitait
--- très bien la veille.
local secret = U.IsSecret

--- Appelle une méthode du client et rend sa valeur, ou `nil` si l'appel lève.
---
--- **Tout** ce que ce fichier demande à un cadre passe par ici. On ne devine
--- jamais ce qui est touchable : on essaie, et un échec ne coûte que l'appel qui
--- a échoué. C'est la seule stratégie qui reste juste quand le client ajoute des
--- protections d'une extension à l'autre — une liste de gardes écrite à la main
--- est fausse le jour où elle est écrite, et fausse autrement six mois plus tard.
---@param frame table
---@param method string
---@return any
local function ask(frame, method)
    local getter = frame[method]
    if type(getter) ~= "function" then return nil end
    local ok, value = pcall(getter, frame)
    if ok then return value end
    return nil
end

--- Même chose pour les méthodes qui rendent une liste variadique.
---@param frame table
---@param method string
---@return table
local function askAll(frame, method)
    local getter = frame[method]
    if type(getter) ~= "function" then return {} end
    local ok, list = pcall(function() return { getter(frame) } end)
    if ok then return list end
    return {}
end

-- =========================================================================
--  Ce que porte chaque élément
-- =========================================================================

--- élément -> noms globaux des cadres du client.
local FRAMES = {
    actionBars = {
        "MainMenuBar", "MainMenuBarArtFrame", "OverrideActionBar",
        "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft",
        "MultiBar5", "MultiBar6", "MultiBar7",
        "StanceBar", "PetActionBar", "PossessActionBar",
        "MainMenuBarVehicleLeaveButton",
    },

    castBar = {
        "PlayerCastingBarFrame", "PetCastingBarFrame",
        "TargetFrameSpellBar", "FocusFrameSpellBar",
    },

    -- Cadres d'unités « classiques ». Les cadres de **groupe et de raid** n'y
    -- sont pas, et c'est délibéré : les atteindre par leur conteneur comme par
    -- leurs noms globaux n'a rien donné, et rien n'indique pour l'instant que
    -- le client laisse teinter leur habillage. Y revenir demandera de
    -- comprendre d'abord *comment* ils sont peints, pas d'ajouter des noms.
    --
    -- Les cadres de **boss** n'y sont plus non plus, et pour une autre raison :
    -- ce sont des cadres de combat. Ce qu'on y lit — qui est ciblé, qui incante,
    -- combien il reste de vie — se lit vite ou ne se lit pas, et un habillage
    -- assombri les rapproche du fond au moment précis où ils comptent le plus.
    -- Le mode sombre range l'interface ; il n'a rien à faire sur ce qui sert à
    -- réagir.
    unitFrames = {
        "PlayerFrame", "PetFrame",
        "TargetFrame", "TargetFrameToT",
        "FocusFrame", "FocusFrameToT",
    },

    auras = { "BuffFrame", "DebuffFrame" },

    tooltip = { "GameTooltip", "ItemRefTooltip" },

    -- Gestionnaire de temps de recharge. Quatre visionneuses, dont certaines
    -- n'existent que si le joueur les a activées : on cite les quatre et on
    -- prend celles qui répondent présent.
    cooldownManager = {
        "EssentialCooldownViewer", "UtilityCooldownViewer",
        "BuffIconCooldownViewer", "BuffBarCooldownViewer",
    },
}

---@param element string
---@param name string
local function alsoWatch(element, name)
    local names = FRAMES[element]
    names[#names + 1] = name
end

-- La barre d'action principale n'est pas atteignable par sa seule barre : ses
-- boutons sont nommés globalement et ne descendent pas forcément d'elle. On les
-- cite donc un par un, ce qui reste vrai quel que soit leur parent.
for i = 1, 12 do
    alsoWatch("actionBars", "ActionButton" .. i)
end

--- Éléments dont les icônes n'ont **pas** de contour et à qui il faut donc en
--- poser un.
---
--- La liste est courte, et le vérifier avant d'y ajouter une entrée évite un
--- défaut qu'on ne reconnaît pas au premier coup d'œil : un élément qui a déjà
--- son habillage reçoit alors deux contours — le sien, teinté par le moteur, et
--- le nôtre par-dessus. Le rendu n'est pas franchement cassé, il est seulement
--- *différent* du reste, ce qui est plus long à diagnostiquer.
---
--- Un emplacement du gestionnaire de temps de recharge est nu de cette
--- façon-là : relevé sur le client, il ne porte que son icône, un masque, la
--- texture d'état `OutOfRange` et l'atlas `UI-HUD-CoolDownManager-IconOverlay`.
--- Aucune texture de contour à emprunter, d'où son entrée ici. Une icône d'aura
--- est nue pour la même raison.
local ICON_BORDERS = {
    auras           = true,
    cooldownManager = true,
}

--- Clés sous lesquelles un cadre publie son contour. Sur les éléments qui
--- reçoivent un contour commun, ces textures-là sont **laissées au widget**, qui
--- les rhabille : les teinter en plus reviendrait à les traiter deux fois.
local BORDER_KEYS = { "Border", "IconBorder" }

--- Clés sous lesquelles un cadre publie son **fond**, par opposition à son
--- contour. La pièce centrale d'un nine-slice en fait partie : c'est elle qui
--- peint la surface, les huit autres dessinent le cadre.
local BACKGROUND_KEYS = { "Center", "Bg", "Background" }

--- Éléments dont on assombrit le contour **sans toucher au fond**.
---
--- Une infobulle est le cas d'école : son fond fait partie de sa lisibilité, le
--- jeu l'a réglé pour que le texte s'y détache, et l'assombrir change autre
--- chose que l'habillage. Ailleurs — un cadre d'unité, une barre d'action — le
--- fond *est* de l'habillage et suit le reste.
local KEEP_BACKGROUND = {
    tooltip = true,
}

--- Cadres qui ne portent pas de nom global et qu'il faut aller chercher sur leur
--- porteur.
local NESTED = {
    -- Les auras de la cible et du focus sortent d'un **pool** porté par leur
    -- cadre d'unité : elles n'ont ni nom global, ni place fixe. On énumère donc
    -- celles qui sont actives à l'instant du passage, et `UNIT_AURA` nous
    -- ramène ici quand elles changent.
    --
    -- Elles sont aussi croisées par le parcours des cadres d'unités, qui
    -- descend jusqu'à elles. Sans conséquence : ce parcours-là ne touche pas
    -- aux icônes, et une texture d'habillage teintée deux fois de la même
    -- façon reste teintée une fois.
    auras = function(collect)
        local frames = { TargetFrame, FocusFrame }
        for i = 1, #frames do
            local pools = frames[i] and frames[i].auraPools
            if pools and pools.EnumerateActive then
                for aura in pools:EnumerateActive() do
                    collect(aura)
                end
            end
        end

        -- Les auras affichées sous le personnage, avec la ressource
        -- personnelle. Ce sont des buffs et des debuffs comme les autres : leur
        -- place est ici, sous la même option, et non avec la barre qui les
        -- porte. Elles vivent sur la barre de nom du joueur, qui n'existe que
        -- lorsque cet affichage est allumé.
        collect(PersonalFriendlyBuffFrame)

        if C_NamePlate and C_NamePlate.GetNamePlateForUnit then
            local plate = C_NamePlate.GetNamePlateForUnit("player")
            local unitFrame = plate and plate.UnitFrame
            if unitFrame then collect(unitFrame.BuffFrame) end
        end
    end,
}

-- =========================================================================
--  Classement des textures
-- =========================================================================

--- Clés sous lesquelles un cadre du client publie un portrait. Intouchables.
local PORTRAIT_KEYS = { "portrait", "Portrait", "PortraitTexture", "PlayerPortrait" }

--- Clés sous lesquelles il publie une icône. Assombries, mais progressivement.
local ICON_KEYS = { "icon", "Icon" }

--- Textures qu'un bouton ne publie pas dans ses régions : elles se demandent.
--- C'est par là que passe l'habillage d'un bouton d'action — sans cette liste,
--- une barre d'action entière échappe au parcours sans que rien ne le signale.
---
--- La normale et elle seule. Les autres — enfoncé, coché, désactivé, survolé —
--- ne sont pas de l'habillage mais du **retour visuel** : elles disent au joueur
--- ce qui se passe. Les assombrir revient à éteindre le signal, et c'est ainsi
--- qu'une lueur de survol dorée devient une auréole noire.
local BUTTON_TEXTURES = { "GetNormalTexture" }

--- Textures d'état, à ne jamais teindre, pour la même raison. Elles se
--- demandent au cadre plutôt que de se reconnaître à leur nom : c'est le cadre
--- qui sait laquelle est laquelle.
local STATE_TEXTURES = {
    "GetHighlightTexture", "GetPushedTexture", "GetCheckedTexture", "GetDisabledTexture",
}

--- Textures d'état que le cadre ne rend par aucune méthode et qu'il faut donc
--- reconnaître autrement.
---
--- Un emplacement du gestionnaire de temps de recharge publie `OutOfRange` :
--- c'est le voile qui dit au joueur que la cible est hors de portée. Aucun
--- `Get…Texture` ne le rend, il échappe donc à `STATE_TEXTURES` et se retrouvait
--- classé comme habillage — donc assombri, donc éteint au moment précis où il a
--- quelque chose à dire. Le défaut ne se voit qu'à distance, ce qui explique
--- qu'il ait tenu.
local STATE_KEYS = { "OutOfRange" }

---@param owner table
---@param region table
---@param keys string[]
---@return boolean
local function publishedAs(owner, region, keys)
    for i = 1, #keys do
        if owner[keys[i]] == region then return true end
    end
    return false
end

--- Nom de débogage d'une région, quand le client sait le donner. Les cadres du
--- client nomment leurs textures : « …Portrait », « …Icon » s'y lisent, ce qui
--- rattrape les textures qu'aucune clé ne publie.
---
--- **Le dernier segment, et lui seul.** `GetDebugName` rend le chemin complet —
--- `BuffIconCooldownViewer.…12ab.…34cd` — et chercher un mot dans tout ce chemin
--- fait porter à une texture le nom de ses ancêtres. Une visionneuse qui
--- s'appelle `BuffIconCooldownViewer` rendait ainsi *toutes* ses textures
--- « icônes », habillage compris : le suivi des améliorations n'a jamais pris la
--- teinte, alors que les trois autres visionneuses, aux noms sans « icon », la
--- prenaient très bien. Le nom d'un cadre parle du cadre, pas de ce qu'il porte.
---
--- **`type(name) == "string"` ne suffit pas.** Le client rend ce nom en valeur
--- *secrète* dès que l'exécution est teintée par un addon — et une chaîne
--- secrète est bel et bien une chaîne, donc le test de type la laisse passer.
--- L'indexer pour appeler `match` lève alors, et l'erreur remonte hors du seul
--- appel fautif : elle interrompt tout le parcours de l'élément. C'est ainsi
--- qu'un module qui se contentait de poser une couleur de classe sur une barre
--- de vie a éteint le mode sombre des cadres d'unités entiers — le module
--- teintait l'exécution, le nom devenait secret, et le parcours mourait à la
--- première texture. Rien dans le symptôme ne désignait le coupable.
---
--- Sans nom, on ne perd que le rattrapage : le classement retombe sur les clés
--- que le cadre publie, et le nom n'a jamais servi qu'à **écarter**, jamais à
--- décider qu'une texture est touchable.
---@param region table
---@return string|nil
local function debugName(region)
    local name = ask(region, "GetDebugName")
    if type(name) ~= "string" or secret(name) then return nil end
    return name:match("[^.]+$") or name
end

--- Cette texture dit-elle un état au joueur, plutôt que de décorer ?
---
--- La clé d'abord, le nom ensuite : le cadre qui publie sa texture sous une clé
--- d'état est le cas sûr, et le nom rattrape celle qu'aucune clé ne publie.
--- C'est le même partage que pour les portraits et les icônes, et le nom y a le
--- même rôle — il ne sert qu'à **écarter**, jamais à décider qu'on peut toucher.
---@param owner table
---@param region table
---@return boolean
local function signalsState(owner, region)
    if publishedAs(owner, region, STATE_KEYS) then return true end

    local name = debugName(region)
    if not name then return false end

    for i = 1, #STATE_KEYS do
        if name:find(STATE_KEYS[i], 1, true) then return true end
    end
    return false
end

--- « portrait » (jamais touché), « icon » (jamais teintée, éventuellement
--- bordée) ou « art » (teintée).
---
--- Seule une texture que son porteur publie **sous une clé d'icône** est traitée
--- comme une icône bordable. Se fier au nom pour cela reviendrait à border tout
--- ce qui s'appelle « …Icon », y compris des fonds de la taille d'un conteneur
--- entier — on l'a vu donner une icône géante sur le suivi des auras. Le nom ne
--- sert donc qu'à écarter.
---@param owner table
---@param region table
---@return string
local function classify(owner, region)
    if publishedAs(owner, region, PORTRAIT_KEYS) then return "portrait" end
    if publishedAs(owner, region, ICON_KEYS) then return "icon" end

    local name = debugName(region)
    if name and (name:find("[Pp]ortrait") or name:find("[Ii]con")) then return "portrait" end

    return "art"
end

-- =========================================================================
--  État
-- =========================================================================

--- texture -> apparence relevée avant la première teinte
local originals = {}
--- élément -> { art = { textures }, icons = { textures } }
local painted = {}
--- élément -> { factor = , icon = }
local active = {}

-- =========================================================================
--  Collecte
-- =========================================================================

---@param frame table|nil
---@param out table
---@param seen table
---@param rules table  { reskins = boolean, keepBackground = boolean }
local function collectFrom(frame, out, seen, rules)
    if type(frame) ~= "table" or type(frame.GetObjectType) ~= "function" then return end
    if seen[frame] then return end
    seen[frame] = true

    if ask(frame, "IsForbidden") == true then return end
    if ask(frame, "GetObjectType") == "Cooldown" then return end

    -- Ce que ce cadre affiche pour informer, et non pour décorer : le
    -- remplissage de sa barre (vie, ressource, temps restant) et ses textures
    -- d'état. Rien de tout cela ne s'assombrit.
    local spare = { ask(frame, "GetStatusBarTexture") }
    for i = 1, #STATE_TEXTURES do
        spare[#spare + 1] = ask(frame, STATE_TEXTURES[i])
    end

    ---@param region any
    ---@return boolean
    local function informs(region)
        for i = 1, #spare do
            if spare[i] == region then return true end
        end
        return false
    end

    local function take(region)
        if type(region) ~= "table" or informs(region) then return end
        if type(region.SetVertexColor) ~= "function" then return end

        -- Protégé comme le classement plus bas, et pour la même raison : un
        -- échec ici ne doit coûter que cette texture. Sans cela, une seule
        -- région récalcitrante emporte le parcours entier et l'élément reste
        -- clair — le défaut se lit alors comme « le mode sombre ne marche plus »,
        -- ce qui n'oriente vers rien. Un doute se tranche en ne touchant pas.
        local known, signals = pcall(signalsState, frame, region)
        if not known or signals then return end

        if rules.reskins and publishedAs(frame, region, BORDER_KEYS) then return end
        if rules.keepBackground and publishedAs(frame, region, BACKGROUND_KEYS) then return end

        local ok, kind = pcall(classify, frame, region)
        if not ok or kind == "portrait" then return end

        local bucket = out[kind]
        bucket[#bucket + 1] = region
    end

    for _, region in ipairs(askAll(frame, "GetRegions")) do
        if type(region) == "table" and ask(region, "GetObjectType") == "Texture" then
            take(region)
        end
    end

    -- L'habillage d'un bouton ne figure pas dans ses régions : il se demande.
    for i = 1, #BUTTON_TEXTURES do
        take(ask(frame, BUTTON_TEXTURES[i]))
    end

    for _, child in ipairs(askAll(frame, "GetChildren")) do
        collectFrom(child, out, seen, rules)
    end
end

--- Ce que le parcours doit faire ou ne pas faire pour cet élément.
---@param element string
---@return table
local function rulesFor(element)
    return {
        reskins        = ICON_BORDERS[element] == true,
        keepBackground = KEEP_BACKGROUND[element] == true,
    }
end

---@param element string
---@return table  { art = {}, icon = {} }
local function collect(element)
    local out   = { art = {}, icon = {} }
    local seen  = {}
    local rules = rulesFor(element)

    local names = FRAMES[element]
    if names then
        for i = 1, #names do
            collectFrom(_G[names[i]], out, seen, rules)
        end
    end

    local nested = NESTED[element]
    if nested then
        pcall(nested, function(frame) collectFrom(frame, out, seen, rules) end)
    end

    return out
end

-- =========================================================================
--  Teinte et restitution
-- =========================================================================

--- Apparence d'origine d'une texture, relevée une fois pour toutes.
--- Renvoie `nil` quand elle n'est pas lisible : le client peut rendre des
--- valeurs **secrètes**, sur lesquelles la moindre multiplication lève.
---@param texture table
---@return table|nil
local function remember(texture)
    local origin = originals[texture]
    if origin ~= nil then return origin or nil end

    local ok, r, g, b, a = pcall(texture.GetVertexColor, texture)
    if not ok or secret(r) or type(r) ~= "number" then
        originals[texture] = false   -- relevé impossible, ne pas y revenir
        return nil
    end

    origin = {
        r = r, g = g or 1, b = b or 1, a = a or 1,
        desaturated = texture.IsDesaturated and texture:IsDesaturated() or false,
        alpha = ask(texture, "GetAlpha") or 1,
    }
    originals[texture] = origin
    return origin
end

---@param texture table
---@param origin table
---@param factor number
---@param desaturate boolean
local function shade(texture, origin, factor, desaturate)
    if desaturate and texture.SetDesaturated then
        texture:SetDesaturated(true)
    end
    texture:SetVertexColor(origin.r * factor, origin.g * factor, origin.b * factor, origin.a)
end

--- Teinte une liste de textures.
---
--- Chaque texture est isolée. C'est la même leçon qu'au niveau des éléments, un
--- cran plus bas : une seule texture qui lève emporterait sinon toutes celles
--- qui la suivent, et un cadre d'unité entier resterait clair à cause d'une de
--- ses vingt régions. On échoue donc texture par texture, jamais en bloc.
---@param textures table
---@param factor number
---@param desaturate boolean
local function paint(textures, factor, desaturate)
    for i = 1, #textures do
        local texture = textures[i]
        local origin  = remember(texture)
        if origin then pcall(shade, texture, origin, factor, desaturate) end
    end
end

---@param texture table
---@param origin table
local function unshade(texture, origin)
    if texture.SetDesaturated then texture:SetDesaturated(origin.desaturated) end
    texture:SetVertexColor(origin.r, origin.g, origin.b, origin.a)
end

---@param textures table
local function unpaint(textures)
    for i = 1, #textures do
        local texture = textures[i]
        local origin  = originals[texture]
        if origin then pcall(unshade, texture, origin) end
    end
end


-- =========================================================================
--  Bords tracés
-- =========================================================================

--- icône -> son bord, ou `false` si le client n'a pas su le poser. La valeur
--- `false` compte : elle évite de retenter la création à chaque passage.
local borders = {}

--- icône -> ses coordonnées de texture d'origine, avant rognage.
local crops = {}

--- Rogne le liseré que l'icône porte **dans son image**. Sans ce rognage, notre
--- tracé s'ajoute à ce liseré au lieu de le remplacer, et le bord paraît deux
--- fois trop épais quelle que soit l'épaisseur qu'on lui donne.
---@param icon table
local function cropIcon(icon)
    if crops[icon] or type(icon.SetTexCoord) ~= "function" then return end

    local ok, ulx, uly, llx, lly, urx, ury, lrx, lry = pcall(icon.GetTexCoord, icon)
    if not ok or type(ulx) ~= "number" then return end

    crops[icon] = { ulx, uly, llx, lly, urx, ury, lrx, lry }

    local from, to = T.SIZE.SHADE_ICON_CROP, 1 - T.SIZE.SHADE_ICON_CROP
    icon:SetTexCoord(from, to, from, to)
end

---@param icon table
local function uncropIcon(icon)
    local origin = crops[icon]
    if not origin then return end
    crops[icon] = nil
    pcall(icon.SetTexCoord, icon, unpack(origin))
end

---@param icon table
---@param factor number
local function drawBorder(icon, factor)
    local border = borders[icon]
    if border == nil then
        border = BUI.Widgets.ShadeBorder(icon) or false
        borders[icon] = border
    end
    if not border then return end

    cropIcon(icon)
    border:Draw(factor)
end

---@param icons table
---@param factor number
local function drawBorders(icons, factor)
    for i = 1, #icons do
        pcall(drawBorder, icons[i], factor)
    end
end

---@param icons table
local function hideBorders(icons)
    for i = 1, #icons do
        local icon   = icons[i]
        local border = borders[icon]
        if border then border:Hide() end
        uncropIcon(icon)
    end
end

---@param element string
local function restore(element)
    local lists = painted[element]
    if not lists then return end

    unpaint(lists.art)
    hideBorders(lists.icon)
    painted[element] = nil
end

--- Rend les seules textures qui étaient teintes et ne le sont plus — celles
--- qu'un nouveau parcours n'a pas retrouvées : une aura tombée, un cadre que le
--- client a rangé.
---@param previous table|nil
---@param current table
local function releaseMissing(previous, current)
    if not previous then return end

    local keep = {}
    for i = 1, #current.art do keep[current.art[i]] = true end
    for i = 1, #current.icon do keep[current.icon[i]] = true end

    local goneArt, goneIcon = {}, {}
    for i = 1, #previous.art do
        local texture = previous.art[i]
        if not keep[texture] then goneArt[#goneArt + 1] = texture end
    end
    for i = 1, #previous.icon do
        local icon = previous.icon[i]
        if not keep[icon] then goneIcon[#goneIcon + 1] = icon end
    end

    unpaint(goneArt)
    hideBorders(goneIcon)
end

--- Assombrit un élément. Rappeler après l'apparition de nouveaux cadres les
--- rattrape.
---
--- **On ne rend jamais avant de repeindre.** Rendre tout l'élément puis le
--- reteinter donnerait le même résultat — la teinte se recalcule toujours depuis
--- la couleur d'origine, donc repeindre une texture déjà teintée ne change rien
--- — mais chaque passage repasserait par un état clair. Sur un changement de
--- cible, où plusieurs passages s'enchaînent, cela se voit : l'interface a l'air
--- de « se rafraîchir » au lieu d'être simplement sombre. On ne rend donc que ce
--- qui **sort** du périmètre.
---@param element string
---@param factor number  voir `T.SHADE_FACTOR`
function S:Apply(element, factor)
    active[element] = factor

    local lists = collect(element)
    releaseMissing(painted[element], lists)
    painted[element] = lists

    paint(lists.art, factor, true)

    -- À intensité nulle il n'y a rien à assombrir : rhabiller un contour à
    -- pleine clarté le remplacerait par un ornement que personne n'a demandé.
    if ICON_BORDERS[element] and factor < 1 then
        drawBorders(lists.icon, factor)
    end
end

--- Assombrit **un seul cadre**, au titre d'un élément déjà allumé.
---
--- Sert quand le client vient de reconstruire quelque chose et nous le dit :
--- inutile de reparcourir tout l'élément, et surtout inutile d'attendre le
--- prochain regroupement. Un cadre isolé se traite pour un coût si faible qu'on
--- peut le faire sur-le-champ, ce qu'un parcours complet interdirait.
---
--- Sans effet si l'élément est éteint : on ne rallume pas par la bande.
---@param element string
---@param frame table
function S:ApplyTo(element, frame)
    local factor = active[element]
    if not factor then return end

    local out = { art = {}, icon = {} }
    collectFrom(frame, out, {}, rulesFor(element))

    paint(out.art, factor, true)
    if ICON_BORDERS[element] and factor < 1 then
        drawBorders(out.icon, factor)
    end

    -- Ces textures doivent pouvoir être rendues comme les autres : on les
    -- ajoute à ce que l'élément a déjà teinté. Un doublon dans la liste ne
    -- coûte rien, la restitution repose la même couleur d'origine deux fois.
    local lists = painted[element]
    if not lists then return end

    for i = 1, #out.art do lists.art[#lists.art + 1] = out.art[i] end
    for i = 1, #out.icon do lists.icon[#lists.icon + 1] = out.icon[i] end
end

---@param element string
function S:Restore(element)
    restore(element)
    active[element] = nil
end

--- Rend tous les éléments à leur état d'origine. Appelé par `OnDisable`.
function S:RestoreAll()
    for element in pairs(active) do
        restore(element)
    end
    wipe(active)
end

--- Repasse la teinte sur les cadres apparus depuis le dernier passage : auras
--- recréées, cadres de groupe montés en entrant en groupe, fenêtre chargée à la
--- demande. Sans argument, sur tous les éléments allumés.
---@param element? string
function S:Refresh(element)
    if element then
        local factor = active[element]
        if factor then self:Apply(element, factor) end
        return
    end

    for name, factor in pairs(active) do
        self:Apply(name, factor)
    end
end
