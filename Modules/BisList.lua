-- =========================================================================
--  Bshamel UI — Modules/BisList.lua
--  La liste BIS : pour chaque emplacement, les objets qu'on veut finir par
--  porter. Ctrl + clic gauche sur le bouton de l'addon ouvre la fenêtre.
--
--  *Forever* seulement (sa ligne du `.toc` l'écarte de retail).
--
--  Trois fichiers, trois rôles : `Modules/BisIndex.lua` **sait** quels objets
--  existent, `UI/Widgets/Bis*.lua` **dessinent**, et celui-ci **décide** — ce
--  qui s'ouvre, ce qui se range, et où.
--
--  ## Les choix appartiennent au personnage
--
--  Un chasseur et un prêtre ne visent pas le même casque : la liste vit donc
--  dans `CharData`, l'espace par personnage de la base de **compte** (voir
--  `DB:CharData`). Ce n'est pas un réglage — il n'y a pas de défaut à une liste
--  vide, et elle ne passe donc ni par `Get`/`Set` ni par les profils : un
--  profil se partage entre personnages, cette liste jamais.
--
--  L'index, lui, est au compte : la liste des objets du jeu ne dépend pas du
--  personnage.
--
--  ## La case `active` est le consentement à l'index
--
--  Le module charge éteint comme tous les autres — sa case est décochée
--  (CLAUDE.md §4) — et elle commande plus que d'habitude : la cocher déclenche
--  le balayage de la table d'objets du client et quelques milliers de demandes
--  de fiches au serveur. Ça ne change rien au jeu, mais ça travaille, et ça ne
--  doit pas travailler pour qui n'a rien demandé. Elle commande aussi le geste
--  sur le bouton de la minicarte : décochée, ctrl + clic ne fait rien de plus
--  qu'un clic.
--
--  Réversibilité (règle 6) : le module n'ajoute qu'une fenêtre, qui se cache,
--  et un geste sur notre propre bouton, qui se retire. Rien du jeu n'est
--  touché, et l'index reste en base — l'effacer punirait le joueur qui
--  recoche.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local U    = BUI.Util
local W    = BUI.Widgets
local L    = ns.L
local Index = ns.BisIndex

local MODULE = "BisList"

--- Nombre de colonnes de choix. Trois, parce que c'est ce qu'on demande : le
--- premier choix, le repli, et celui qu'on peut avoir en attendant.
local RANKS = 3

--- La fenêtre, bâtie au premier besoin. Les frames ne se détruisent pas
--- (règle 7) : elle se cache, elle ne meurt pas.
local window

-- =========================================================================
--  Ce que le personnage a choisi
-- =========================================================================

---@return table  emplacement -> rang -> itemID
local function picks()
    local mod = BUI.Modules:Get(MODULE)
    local data = mod and mod:CharData()
    if not data then return {} end

    data.picks = data.picks or {}
    return data.picks
end

---@param slotKey string
---@param rank integer
---@return integer|nil
local function getPick(slotKey, rank)
    local slot = picks()[slotKey]
    return slot and slot[rank] or nil
end

---@param slotKey string
---@param rank integer
---@param itemID integer|nil
local function setPick(slotKey, rank, itemID)
    local all = picks()

    if not itemID then
        if all[slotKey] then all[slotKey][rank] = nil end
        -- Un emplacement vidé ne laisse pas de table vide derrière lui : la
        -- sauvegarde est du texte, et une table vide s'y écrit quand même.
        if all[slotKey] and not next(all[slotKey]) then all[slotKey] = nil end
        return
    end

    all[slotKey] = all[slotKey] or {}
    all[slotKey][rank] = itemID
end

-- =========================================================================
--  La fenêtre
-- =========================================================================

--- Les emplacements, intitulés traduits : l'index les publie par clé de
--- locale, parce que deux d'entre eux portent un numéro que le client n'écrit
--- nulle part.
---@return table[]
local function slotList()
    local out = {}
    local slots = Index:Slots()

    for i = 1, #slots do
        out[i] = { key = slots[i].key, label = L[slots[i].label] }
    end

    return out
end

---@return table
local function getWindow()
    if window then return window end

    window = W.BisWindow("BshamelUIBisFrame", {
        slots      = slotList(),
        slotLocs   = function(slotKey) return Index:SlotLocs(slotKey) end,
        ranks      = RANKS,
        stats      = Index:Stats(),
        armorTypes = Index:ArmorTypes(),

        getPick = getPick,
        setPick = setPick,

        search   = function(filters, limit, out)
            return Index:Search(filters, limit, out)
        end,
        progress = function() return Index:Progress() end,
    })

    return window
end

-- =========================================================================
--  Allumer, éteindre
-- =========================================================================

--- Tout rendre : le geste du bouton, le battement de l'index, la fenêtre. Un
--- module éteint doit être indétectable (règle 6), et une case décochée doit
--- l'être autant — c'est la même fonction qui sert aux deux.
local function stopEverything()
    BUI.MinimapDock:SetModifierClick(nil)
    Index:Stop()
    if window then window:Hide() end
end

--- Applique l'état de la case : le geste sur le bouton de la minicarte et
--- l'indexation vont ensemble, parce que l'un sans l'autre ouvrirait une
--- fenêtre qui n'a rien à montrer.
---@param mod table
local function applyActive(mod)
    if not mod:Get("active") then
        stopEverything()
        return
    end

    -- Le geste se déclare au socle de la minicarte, qui possède le bouton : le
    -- module ne dessine pas (règle 2), et c'est aussi ce qui le rend révocable
    -- d'une ligne.
    BUI.MinimapDock:SetModifierClick(function() getWindow():Toggle() end)
    Index:Start()
end

-- =========================================================================
--  Déclaration du module
-- =========================================================================

local defaults = {
    active = false,
}

--- La case est-elle décochée ? Ce qui suit n'a alors rien à proposer : sans
--- index, « ouvrir » montrerait dix-sept lignes vides et « reconstruire » ne
--- reconstruirait rien.
---@return boolean
local function inactive()
    local mod = BUI.Modules:Get(MODULE)
    return not (mod and mod:Get("active"))
end

local options = {
    { type = "header", text = L["General"] },
    {
        type    = "toggle",
        key     = "active",
        text    = L["Enable the BIS list"],
        tooltip = L["Enable the BIS list tip"],
    },
    -- Une ligne rouge, et pas une infobulle : la surprise n'arrive pas au
    -- survol de l'option, elle arrive en jeu, devant une recherche qui ne
    -- trouve pas encore tout. Une phrase, pas un paragraphe.
    {
        type = "alert",
        text = L["BIS index filling"],
    },
    {
        type     = "button",
        text     = L["Open the BIS list"],
        label    = L["Open"],
        tooltip  = L["Open the BIS list tip"],
        disabled = inactive,
        onClick  = function() getWindow():ShowList() end,
    },

    { type = "header", text = L["Item index"] },
    {
        type     = "button",
        text     = L["Rebuild the index"],
        label    = L["Rebuild"],
        tooltip  = L["Rebuild the index tip"],
        disabled = inactive,
        onClick  = function()
            W.Confirm(L["Rebuild the index confirm"], function()
                Index:Rebuild()
                if window then window:Refresh() end
            end)
        end,
    },
}

BUI:RegisterModule(MODULE, {
    title    = L["BIS list"],
    category = "MythicRaid",
    order    = 30,

    -- **Annoncé, pas livré.** Tout le module repose sur un pari qui n'est pas
    -- vérifié : que `C_Item.GetItemInfoInstant` publie la table d'objets du
    -- client pour des objets jamais vus. Si ce pari est faux sur *Forever*,
    -- l'index reste vide et la recherche ne trouve rien — ce qui est
    -- exactement le symptôme constaté en jeu.
    --
    -- `preview` est la bonne réponse à ça, et pas un retrait du `.toc` : la
    -- page reste visible et grisée, le core refuse de l'allumer, et personne
    -- ne tombe sur une fenêtre qui ne trouve rien. Retirer cette ligne est le
    -- seul geste qui la livre, le jour où `/bui bis` dira que le pari tient.
    preview  = true,

    defaults = defaults,
    options  = options,

    OnEnable = function(self)
        -- L'index ne s'abonne à rien lui-même : les abonnements d'un module
        -- sont révoqués à son extinction (règle 6), et c'est ce qui garantit
        -- qu'un module éteint ne demande plus rien au serveur.
        --
        -- Cet événement est émis pour **n'importe quel** objet interrogé dans
        -- l'interface, donc en rafale et le plus souvent sans rapport avec
        -- nous. Il reste abonné même quand la case est décochée, parce que le
        -- mixin ne sait pas se désabonner d'une seule ligne — et le prix est
        -- une lecture de table dans une table vide.
        self:RegisterEvent("GET_ITEM_INFO_RECEIVED", function(_, itemID, success)
            Index:OnItemInfoReceived(itemID, success)
        end)

        -- La fenêtre ouverte pendant que l'index se remplit doit voir arriver
        -- ce qu'il trouve, sans quoi elle dirait « rien » alors qu'elle n'a
        -- pas encore regardé.
        self:RegisterMessage("BIS_INDEX_PROGRESS", function()
            if window and window:IsShown() then window:RefreshProgress() end
        end)

        self:RegisterMessage("BIS_INDEX_READY", function(_, written)
            if window and window:IsShown() then window:Refresh() end

            -- **Une ligne dans le chat, et seulement si la passe a travaillé.**
            -- L'addon ne parle presque jamais, et ce silence est une promesse :
            -- un allumage où rien n'a changé — le cas de tous les jours, le
            -- balayage ne trouvant rien de neuf — n'a rien à annoncer.
            --
            -- Mais la première fois dure quelques minutes, pendant lesquelles
            -- la seule façon de savoir où ça en est serait de garder la fenêtre
            -- ouverte à regarder un nombre monter. On ferme la fenêtre, on va
            -- jouer, et c'est le chat qui dit que c'est prêt.
            --
            -- `BUI:Print` et non `self:Print` : celui du module préfixe le nom
            -- interne (`[BisList]`), qui est une clé de base de données et non
            -- quelque chose qu'un joueur a à lire. Il est fait pour les sorties
            -- de diagnostic, pas pour une phrase adressée à quelqu'un.
            if type(written) == "number" and written > 0 then
                local _, _, total = Index:Progress()
                BUI:Print(L["Index done"]:format(total))
            end
        end)

        applyActive(self)
    end,

    OnDisable = function()
        stopEverything()
    end,

    OnSettingChanged = function(self)
        applyActive(self)
    end,

    --- `/bui bis` : pourquoi l'index est vide.
    ---
    --- Rien de ce que fait l'index ne se voit depuis le jeu, et trois choses
    --- très différentes donnent le même symptôme — une liste vide :
    ---
    --- 1. le client ne publie pas sa table d'objets, et le balayage ne trouve
    ---    rien à retenir (`Probe` le dit : zéro objet connu) ;
    --- 2. il la publie, mais sous des jetons d'emplacement que nous ne
    ---    reconnaissons pas (`known` élevé, `equippable` à zéro) ;
    --- 3. le balayage retient bien des objets, mais les fiches n'arrivent
    ---    jamais du serveur (`stored` à zéro alors que `total` ne l'est pas).
    ---
    --- La dernière lecture est celle qui ne se discute pas : les pièces que le
    --- personnage **porte** existent forcément, et ce que le client en dit est
    --- la vérité contre laquelle tout le reste se compare.
    ---
    --- Les noms de champs sont ceux de l'API : ils ne se traduisent pas.
    DiagnoseIndex = function()
        BUI:Print(L["BIS diagnostic"])

        local phase, done, total = Index:Progress()
        local stored, written = Index:Counts()
        BUI:Print("phase:", phase, "| done:", done, "| total:", total)
        BUI:Print("stored:", stored, "| written this pass:", written,
                  "| bound:", Index:Bound())

        local known, equippable = Index:Probe(1, 5000)
        BUI:Print("ids 1-5000 ->", "known:", known, "| equippable:", equippable)

        -- Les emplacements d'équipement du client, parcourus par leur numéro :
        -- on ne cherche pas à les nommer, on cherche ce que le client répond.
        local shown = 0
        for slot = 1, 19 do
            local link = GetInventoryItemLink("player", slot)
            local itemID = link and C_Item and C_Item.GetItemInfoInstant
                           and C_Item.GetItemInfoInstant(link) or nil

            if itemID and not U.IsSecret(itemID) then
                local equipLoc, indexed = Index:Trace(itemID)
                BUI:Print("slot", slot, "-> id:", itemID,
                          "| equipLoc:", tostring(equipLoc),
                          "| indexed:", indexed and L["Yes"] or L["No"])
                shown = shown + 1
            end
        end

        if shown == 0 then BUI:Print(L["Nothing equipped"]) end
    end,
})
