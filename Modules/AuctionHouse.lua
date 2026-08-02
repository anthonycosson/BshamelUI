-- =========================================================================
--  Bshamel UI — Modules/AuctionHouse.lua
--  L'hôtel des ventes : ce que le client oublie d'une recherche à l'autre.
--
--  Le filtre existe déjà dans le client (`Enum.AuctionHouseFilter`), il n'est
--  simplement pas mémorisé. On coche **sa** case à chaque ouverture, ce qui
--  laisse le client faire le reste et garde l'état affiché vrai — envelopper
--  l'envoi de la requête filtrerait les résultats en laissant la case décochée,
--  ce qui donnerait une fenêtre qui ment.
--
--  Le réglage vivait dans *Général*, faute de page où le mettre. Un palier de
--  migration (`Core/DB.lua`) suit celui de ceux qui l'avaient changé.
--
--  Réversibilité (règle 6) : le filtre est décoché à l'extinction, **et seulement
--  si c'est nous qui l'avions coché**.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local L    = ns.L

local MODULE = "AuctionHouse"

--- Avons-nous coché le filtre nous-mêmes ? On ne décoche que dans ce cas : si le
--- joueur l'avait mis à la main, le décocher à la désactivation serait défaire
--- son geste et non le nôtre.
local filterSet = false

---@return number|nil
local function currentExpansionFilter()
    return Enum and Enum.AuctionHouseFilter and Enum.AuctionHouseFilter.CurrentExpansionOnly
end

--- Bouton de filtre de la barre de recherche, ou `nil` tant que l'hôtel des
--- ventes n'est pas monté.
---@return table|nil
local function filterButton()
    local frame = AuctionHouseFrame
    local bar   = frame and frame.SearchBar
    local button = bar and bar.FilterButton
    if button and type(button.filters) == "table" then return button end
    return nil
end

--- Coche (ou décoche) le filtre du client.
---
--- `filters` est un **ensemble** indexé par la valeur d'énumération, pas une
--- liste : on écrit à cet index, on n'empile pas.
---@param on boolean
---@return boolean applied
local function setFilter(on)
    local button = filterButton()
    local filter = currentExpansionFilter()
    if not (button and filter) then return false end

    button.filters[filter] = on or nil

    local bar = AuctionHouseFrame.SearchBar
    if bar.UpdateClearFiltersButton then bar:UpdateClearFiltersButton() end
    return true
end

---@param mod table
local function apply(mod)
    if not mod:Get("auctionCurrentXP") then
        if filterSet and setFilter(false) then filterSet = false end
        return
    end

    -- Le bouton n'est construit qu'après l'événement d'ouverture : on laisse
    -- passer une image avant d'aller le chercher.
    C_Timer.After(0, function()
        if not mod:Get("auctionCurrentXP") then return end
        if setFilter(true) then filterSet = true end
    end)
end

-- =========================================================================
--  Déclaration du module
-- =========================================================================

BUI:RegisterModule(MODULE, {
    title    = L["Auction house"],
    category = "QoL",
    order    = 50,

    defaults = {
        auctionCurrentXP = false,
    },

    -- Pas d'intitulé de section : la page s'appelle déjà « Hôtel des ventes ».
    options = {
        {
            type    = "toggle",
            key     = "auctionCurrentXP",
            text    = L["Auction current expansion"],
            tooltip = L["Auction current expansion tip"],
        },
    },

    OnEnable = function(self)
        apply(self)

        -- Le cadre de l'hôtel des ventes se charge à la demande : c'est ici, et
        -- pas à l'activation du module, qu'il devient réglable.
        self:RegisterEvent("AUCTION_HOUSE_SHOW", function() apply(self) end)
    end,

    OnDisable = function()
        if filterSet and setFilter(false) then filterSet = false end
    end,

    OnSettingChanged = function(self)
        apply(self)
    end,
})
