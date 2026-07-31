-- =========================================================================
--  Bshamel UI — Modules/Bags.lua
--  Les sacs : ce qu'on en sort chez le marchand, et ce qu'on y détruit.
--
--  Deux comportements, tous deux éteints par défaut, tous deux entièrement
--  réversibles : le premier n'existe que le temps d'une visite chez un marchand,
--  le second est un hook gardé qui devient inerte quand le module s'éteint
--  (CLAUDE.md règle 6).
--
--  Le niveau d'objet sur l'équipement rangé n'est pas ici : il est écrit, et il
--  vit dans **Fiche de personnage**, avec l'autre affichage du même nombre.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local U    = BUI.Util
local L    = ns.L

local MODULE = "Bags"

-- =========================================================================
--  Vente de la camelote
-- =========================================================================
-- Le client sait vendre toute la camelote d'un coup — c'est le bouton du cadre
-- de marchand. On l'appelle donc au lieu de vendre case par case : une seule
-- requête au serveur plutôt qu'une trentaine, et c'est *sa* définition de la
-- camelote qui s'applique, pas la nôtre.
--
-- Mais l'appel part sans accusé de réception, et il ne suffit pas toujours en
-- une fois : le serveur écarte les ventes au-delà de sa limite de débit, et une
-- case dont l'objet n'est pas encore en cache au moment de l'ouverture est
-- ignorée. Une seule passe laisse donc régulièrement des gris dans les sacs.
--
-- D'où la forme : on recompte après chaque passe et on recommence tant que le
-- nombre baisse. On s'arrête sur trois conditions — plus rien à vendre, plus
-- aucun progrès, ou trop de passes —, et jamais sur un simple délai : c'est
-- l'absence de progrès qui prouve qu'il n'y a plus rien à tenter.

--- Qualité « médiocre ». Le nombre est 0 depuis toujours, l'énumération est le
--- chemin qui restera juste.
local POOR = (Enum and Enum.ItemQuality and Enum.ItemQuality.Poor) or 0

--- Premier et dernier sac porté. Le sac à réactifs est arrivé après les autres :
--- son absence sur un client plus ancien ramène simplement la borne à quatre.
local FIRST_BAG = (Enum and Enum.BagIndex and Enum.BagIndex.Backpack) or 0
local LAST_BAG  = (Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag) or 4

local MAX_PASSES = 8
local MAX_STALLS = 2

--- État de la visite en cours. Une seule table, remise à zéro à chaque
--- ouverture de marchand.
local sweep = {}

---@return integer
local function countJunk()
    if not (C_Container and C_Container.GetContainerNumSlots) then return 0 end

    local total = 0
    for bag = FIRST_BAG, LAST_BAG do
        local slots = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, slots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            -- `hasNoValue` : un gris que personne n'achète n'est pas de la
            -- camelote à vendre, c'est de la camelote à détruire.
            if info and info.quality == POOR and not info.hasNoValue then
                total = total + 1
            end
        end
    end
    return total
end

local function stopSweep()
    if sweep.timer then
        sweep.timer:Cancel()
        sweep.timer = nil
    end
end

---@param mod table
local function report(mod)
    stopSweep()
    if not sweep.money then return end

    local earned = GetMoney() - sweep.money
    sweep.money = nil
    if earned > 0 then
        mod:Print(string.format(L["Sold junk"], U.Money(earned)))
    end
end

---@param mod table
local function pass(mod)
    sweep.timer = nil
    if not sweep.open then return report(mod) end

    local junk = countJunk()
    if junk == 0 then return report(mod) end

    -- Aucun progrès depuis la passe précédente. Une fois peut venir de la
    -- limite de débit du serveur, deux fois de suite veut dire que ce qui reste
    -- ne se vend pas.
    if junk >= sweep.last then
        sweep.stalls = sweep.stalls + 1
        if sweep.stalls > MAX_STALLS then return report(mod) end
    else
        sweep.stalls = 0
    end

    sweep.last   = junk
    sweep.passes = sweep.passes + 1
    if sweep.passes > MAX_PASSES then return report(mod) end

    C_MerchantFrame.SellAllJunkItems()
    sweep.timer = C_Timer.NewTimer(T.TIMING.SELL_PASS, function() pass(mod) end)
end

---@param mod table
local function onMerchantShow(mod)
    sweep.open = true
    if not mod:Get("autoSellJunk") then return end
    if not (C_MerchantFrame and C_MerchantFrame.SellAllJunkItems) then return end

    stopSweep()
    sweep.passes = 0
    sweep.stalls = 0
    sweep.last   = math.huge
    sweep.money  = GetMoney()

    -- Première passe tout de suite : le cas courant — un marchand sans le
    -- moindre gris à vendre — coûte alors une lecture des sacs et rien d'autre,
    -- aucun minuteur n'est armé.
    pass(mod)
end

---@param mod table
local function onMerchantClosed(mod)
    sweep.open = false
    report(mod)
end

-- =========================================================================
--  Confirmation de destruction
-- =========================================================================
-- Détruire un objet de valeur demande d'écrire un mot dans une zone de saisie.
-- On l'écrit à la place du joueur — le geste qui engage reste le sien : il
-- reste à cliquer, et c'est ce clic-là qui détruit.
--
-- Le mot est celui du client (`DELETE_ITEM_CONFIRM_STRING`), donc juste dans
-- toutes les langues sans que nous ayons à en connaître aucune.
--
-- On s'accroche à `Show` et non au script `OnShow` : le client vide la zone de
-- saisie *dans* son `OnShow`, et un hook posé là courrait après lui. `Show` se
-- termine après, ce qui fait de ce hook le dernier à écrire.

--- Les deux dialogues à zone de saisie. Les autres détruisent sur un simple
--- « oui » et ne nous concernent pas.
local CONFIRM_POPUPS = {
    DELETE_GOOD_ITEM       = true,
    DELETE_GOOD_QUEST_ITEM = true,
}

-- =========================================================================
--  Confirmation de vente d'un objet encore échangeable
-- =========================================================================
-- Vendre un butin encore échangeable — ou encore remboursable — ouvre une
-- fenêtre qui demande de valider. Elle est là pour une bonne raison : c'est le
-- dernier instant où l'objet peut encore partir à un coéquipier ou revenir en
-- monnaie, et le clic qui suit ferme les deux portes définitivement.
--
-- Le réglage la fait cliquer à la place du joueur. Il est éteint par défaut et
-- le restera : ce qu'on économise est un clic, ce qu'on risque est un objet.
--
-- On clique **le bouton du client**, on ne vend pas nous-mêmes : c'est sa
-- fenêtre, son bouton, sa vente. Rien à défaire à l'extinction, la garde du hook
-- suffit — et le clic est différé d'une image, parce qu'on est à l'intérieur du
-- `Show` de la fenêtre qu'on s'apprête à fermer.

--- Les dialogues de vente que l'on sait valider. Ils portent tous deux sur le
--- même geste — vendre au marchand ce qui est encore récupérable —, et la table
--- vaut test de capacité : un nom que le client ne connaît pas ne s'affichera
--- jamais, donc ne sera jamais cliqué.
local SELL_POPUPS = {
    CONFIRM_MERCHANT_TRADE_TIMER_REMOVAL = true,
    CONFIRM_REFUND_TIMER_REMOVAL         = true,
}

---@param mod table
---@param popup table
local function acceptSale(mod, popup)
    if not mod:Get("skipSellConfirm") then return end
    if not (popup and SELL_POPUPS[popup.which]) then return end

    local button = popup.button1 or (popup.GetButton1 and popup:GetButton1())
    if not (button and button.Click) then return end

    C_Timer.After(0, function()
        -- Le réglage a pu être décoché, ou la fenêtre fermée à la main, dans
        -- l'image qu'on vient de laisser passer.
        if not mod:Get("skipSellConfirm") then return end
        if not (popup:IsShown() and SELL_POPUPS[popup.which]) then return end
        button:Click()
    end)
end

---@param mod table
---@param popup table
local function fillConfirmation(mod, popup)
    if not mod:Get("fillDeleteInput") then return end
    if not (popup and CONFIRM_POPUPS[popup.which]) then return end

    local editBox = popup.editBox or (popup.GetEditBox and popup:GetEditBox())
    if not editBox then return end

    editBox:SetText(DELETE_ITEM_CONFIRM_STRING)
end

---@param mod table
local function hookConfirmations(mod)
    local guard = function() return mod:IsEnabled() end
    local count = STATICPOPUP_NUMDIALOGS or 4

    for i = 1, count do
        local popup = _G["StaticPopup" .. i]
        if popup then
            U.GuardedHook(popup, "Show", function(self)
                fillConfirmation(mod, self)
                acceptSale(mod, self)
            end, guard)
        end
    end
end

-- =========================================================================
--  Déclaration du module
-- =========================================================================

BUI:RegisterModule(MODULE, {
    title    = L["Bags"],
    category = "Interface",
    order    = 40,

    defaults = {
        autoSellJunk    = false,
        fillDeleteInput = false,

        -- Éteint, et c'est le seul défaut possible : la fenêtre qu'on saute est
        -- la dernière chose qui sépare un butin encore échangeable de sa vente.
        skipSellConfirm = false,
    },

    options = {
        { type = "header", text = L["Merchants"] },
        {
            type    = "toggle",
            key     = "autoSellJunk",
            text    = L["Auto-sell junk"],
            tooltip = L["Auto-sell junk tip"],
        },
        {
            type    = "toggle",
            key     = "skipSellConfirm",
            text    = L["Skip sell confirmation"],
            tooltip = L["Skip sell confirmation tip"],
        },
        { type = "warning", text = L["Skip sell confirmation warning"] },

        { type = "header", text = L["Confirmations"] },
        {
            type    = "toggle",
            key     = "fillDeleteInput",
            text    = L["Fill delete confirmation"],
            tooltip = L["Fill delete confirmation tip"],
        },
    },

    OnEnable = function(self)
        hookConfirmations(self)

        -- `MERCHANT_SHOW` et non l'affichage du cadre : c'est l'interaction avec
        -- le marchand qui autorise la vente, et le cadre peut n'être pas encore
        -- monté au moment où l'événement arrive.
        self:RegisterEvent("MERCHANT_SHOW",   function() onMerchantShow(self) end)
        self:RegisterEvent("MERCHANT_CLOSED", function() onMerchantClosed(self) end)
    end,

    OnDisable = function()
        -- Le hook des confirmations n'a rien à défaire : sa garde le rend inerte.
        -- La vente, elle, peut être en cours.
        sweep.open = false
        sweep.money = nil
        stopSweep()
    end,
})
