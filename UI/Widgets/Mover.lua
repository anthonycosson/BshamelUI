-- =========================================================================
--  Bshamel UI — UI/Widgets/Mover.lua
--  Les trois frames dont le déplacement des fenêtres du client a besoin.
--
--  Elles vivent ici et non dans `UI/Move.lua` pour une raison mécanique :
--  `CreateFrame` n'est autorisé que sous `UI/Widgets/` (CLAUDE.md règle 2). Le
--  moteur décide *quoi* déplacer, ce fichier fournit *avec quoi*.
--
--  Chacune répond à un piège de l'API, et aucune n'est un choix de confort :
--
--  1. `SecureMover` — une fenêtre **protégée** du client (le cadre de recherche
--     de groupe, par exemple) ne supporte ni `SetMovable`, ni `StartMoving`, ni
--     `SetPoint` venus d'un addon : l'appel n'échoue pas, il *taint* l'arbre du
--     cadre, et l'erreur tombe plus tard, ailleurs, sur une comparaison de
--     valeur secrète que rien ne relie à nous. On passe donc par un snippet
--     exécuté dans l'environnement restreint, qui s'exécute de façon sûre par
--     construction.
--
--  2. `WheelCatcher` — même raison, poussée d'un cran : `EnableMouseWheel` est
--     une écriture d'**état d'entrée**, exactement la classe d'appel qui taint.
--     On ne l'appelle donc sur aucun cadre du client. À la place, une frame à
--     nous se pose par-dessus celui qu'on survole et prend la molette. Ses clics
--     la traversent (`EnableMouse(false)`), donc elle n'intercepte rien d'autre.
--
--  3. `Ticker` — une boucle `OnUpdate` cadencée, pour suivre le curseur pendant
--     un glisser et pour repérer la fenêtre survolée. Un `OnUpdate` nu est
--     interdit (règle 7) ; celui-ci passe par `U.Throttle`.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local U    = BUI.Util
local W    = BUI.Widgets

-- =========================================================================
--  Repositionneur sécurisé
-- =========================================================================

--- Corps exécuté dans l'environnement restreint.
---
--- Il ne peut lire que ce qu'on lui a explicitement passé : des références de
--- cadre (`SetFrameRef`) et des attributs (`SetAttribute`). C'est cette
--- limitation qui fait sa sûreté — le snippet n'a aucun moyen de voir du code
--- d'addon, donc rien à tainter.
local PLACE_SNIPPET = [[
    local target = self:GetFrameRef("target")
    if not target then return end

    local relative = self:GetFrameRef("relative") or self:GetParent()
    target:ClearAllPoints()
    target:SetPoint(
        self:GetAttribute("point"), relative, self:GetAttribute("relPoint"),
        self:GetAttribute("x"), self:GetAttribute("y"))
]]

local SCALE_SNIPPET = [[
    local target = self:GetFrameRef("target")
    if target then target:SetScale(self:GetAttribute("scale")) end
]]

--- Un seul repositionneur pour tout l'addon : il ne porte aucun état entre deux
--- appels, en avoir plusieurs ne servirait à rien.
local mover

--- Repositionneur sécurisé, créé au premier appel.
---
--- Renvoie `nil` si le client n'expose pas le template : l'appelant doit alors
--- renoncer à déplacer les cadres protégés plutôt que d'échouer — les autres
--- continuent de fonctionner.
---@return table|nil
function W.SecureMover()
    if mover then return mover end

    local template = T.Template("SECURE_HANDLER")
    if not template then return nil end

    -- Parenté à `UIParent`, et c'est un contrat avec le snippet : `self:GetParent()`
    -- y désigne donc bien `UIParent`, qui est le repère de toutes nos positions.
    local frame = CreateFrame("Frame", nil, UIParent, template)

    --- Ancre `target`. Renvoie `false` en combat, où l'environnement restreint
    --- refuse de repositionner un cadre protégé.
    ---@param target table
    ---@param point string
    ---@param relative? table   par défaut `UIParent`
    ---@param relPoint string
    ---@param x number
    ---@param y number
    ---@return boolean applied
    function frame:Place(target, point, relative, relPoint, x, y)
        if InCombatLockdown() then return false end

        self:SetFrameRef("target", target)
        self:SetFrameRef("relative", relative or UIParent)
        self:SetAttribute("point", point)
        self:SetAttribute("relPoint", relPoint)
        self:SetAttribute("x", x)
        self:SetAttribute("y", y)
        self:Execute(PLACE_SNIPPET)
        return true
    end

    ---@param target table
    ---@param scale number
    ---@return boolean applied
    function frame:Rescale(target, scale)
        if InCombatLockdown() then return false end

        self:SetFrameRef("target", target)
        self:SetAttribute("scale", scale)
        self:Execute(SCALE_SNIPPET)
        return true
    end

    mover = frame
    return frame
end

-- =========================================================================
--  Capteur de molette
-- =========================================================================

--- Frame invisible qui se pose sur un cadre du client pour lui prendre la
--- molette, sans jamais toucher à son état d'entrée.
---
--- `EnableMouse(false)` est le détail qui rend la chose acceptable : les clics
--- traversent le capteur, donc le cadre couvert continue de se comporter
--- normalement. Seule la molette est détournée, et seulement tant que le capteur
--- est posé.
---@param onWheel fun(target: table, delta: number)
---@return table
function W.WheelCatcher(onWheel)
    local catcher = CreateFrame("Frame", nil, UIParent)
    catcher:Hide()
    catcher:EnableMouse(false)
    catcher:EnableMouseWheel(false)

    -- Au-dessus de tout : le capteur doit couvrir la fenêtre survolée quelle que
    -- soit la strate de celle-ci.
    catcher:SetFrameStrata("TOOLTIP")

    catcher:SetScript("OnMouseWheel", function(self, delta)
        if self.target then onWheel(self.target, delta) end
    end)

    --- Pose le capteur sur un cadre.
    ---@param frame table
    function catcher:Cover(frame)
        if self.target == frame and self:IsShown() then return end
        self.target = frame
        self:ClearAllPoints()
        self:SetAllPoints(frame)
        self:EnableMouseWheel(true)
        self:Show()
    end

    --- Retire le capteur. La molette revient au jeu à l'instant même.
    function catcher:Park()
        if not self.target and not self:IsShown() then return end
        self.target = nil
        self:EnableMouseWheel(false)
        self:Hide()
    end

    return catcher
end

-- =========================================================================
--  Boucle cadencée
-- =========================================================================

--- Frame sans apparence dont le seul rôle est de faire tourner `fn` tant qu'elle
--- est affichée. `Show()` démarre la boucle, `Hide()` l'arrête — une frame
--- cachée ne reçoit pas d'`OnUpdate`, il n'y a donc rien à débrancher.
---@param interval number
---@param fn fun()
---@return table
function W.Ticker(interval, fn)
    local ticker = CreateFrame("Frame", nil, UIParent)
    ticker:Hide()
    ticker:SetScript("OnUpdate", U.Throttle(interval, fn))
    return ticker
end
