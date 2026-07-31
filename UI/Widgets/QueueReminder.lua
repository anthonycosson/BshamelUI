-- =========================================================================
--  Bshamel UI — UI/Widgets/QueueReminder.lua
--  Bannière : ce qu'on vient de rejoindre, et comment s'y rendre.
--
--  On accepte une invitation, on retourne à ce qu'on faisait, et deux minutes
--  plus tard on ne sait plus dans quel donjon le groupe est parti. La bannière
--  garde le nom sous les yeux et, quand le personnage connaît la téléportation
--  qui va avec, propose de s'y rendre d'un clic.
--
--  Le bouton de téléportation est un bouton **sécurisé** : lancer un sort depuis
--  du code Lua est refusé par le client, seul un clic sur un bouton d'action
--  décrit par attributs le fait partir (même contrainte que le menu de
--  téléportation). Il en hérite deux limites, et elles décident de la forme du
--  fichier :
--
--  1. les attributs ne s'écrivent pas en combat — la bannière ne s'affiche donc
--     pas pendant un combat, ce qui tombe bien : elle doit justement disparaître
--     quand le combat commence ;
--  2. un bouton sécurisé ne se cache pas en combat. `Dismiss` rend alors la
--     bannière invisible et note qu'elle est à fermer ; `Settle`, appelé à la
--     sortie de combat, termine le geste. C'est le seul moyen d'obtenir « reste
--     affichée jusqu'au combat » sans demander au client une chose qu'il refuse.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local W    = BUI.Widgets

--- Bouton qui lance réellement un sort. Renvoie `nil` si le client n'expose pas
--- de template d'action sécurisée : la bannière se passe alors de bouton plutôt
--- que d'en montrer un qui ne ferait rien.
---@param panel table
---@param label string
---@return table|nil
local function newTeleportButton(panel, label)
    local secure = T.Template("SECURE_ACTION")
    local plain  = T.Template("BUTTON")
    if not (secure and plain) then return nil end

    -- Les deux templates ensemble : le premier donne l'action, le second
    -- l'apparence d'un bouton du client. Aucun nom n'est écrit ici — ce sont
    -- ceux que `T.Template` a retenus.
    local button = CreateFrame("Button", nil, panel, secure .. ", " .. plain)
    button:SetSize(T.SIZE.CONTROL_W, T.SIZE.ROW_H - 2)
    button:SetText(label or "")

    button:RegisterForClicks("AnyUp")
    button:SetAttribute("useOnKeyDown", false)
    button:SetAttribute("type", "spell")

    return button
end

--- Bannière de rappel, masquée au départ.
---@param opts table  { getPos, setPos, teleportLabel }
---@return table
function W.QueueReminder(opts)
    local panel = W.Panel({
        width  = T.SIZE.REMINDER_W,
        height = T.SIZE.TOOL_PAD * 2 + T.SIZE.KEY_ROW_H + T.SIZE.TOOL_GAP + T.SIZE.ROW_H,
        strata = "HIGH",
        getPos = opts.getPos,
        setPos = opts.setPos,
    })

    local icon = panel:CreateTexture(nil, "ARTWORK")
    icon:SetSize(T.SIZE.REMINDER_ICON, T.SIZE.REMINDER_ICON)
    icon:SetPoint("TOPLEFT", panel, "TOPLEFT", T.SIZE.TOOL_PAD, -T.SIZE.TOOL_PAD)

    local label = panel:CreateFontString(nil, "ARTWORK", T.FONT.LABEL)
    label:SetPoint("LEFT", icon, "RIGHT", T.SIZE.TOOL_GAP, 0)
    label:SetPoint("RIGHT", panel, "RIGHT", -T.SIZE.TOOL_PAD, 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)

    local teleport = newTeleportButton(panel, opts.teleportLabel)
    if teleport then
        teleport:SetPoint("BOTTOM", panel, "BOTTOM", 0, T.SIZE.TOOL_PAD)
        -- Fermer la bannière est le geste qui suit la téléportation : `PostClick`
        -- et non `OnClick`, qui remplacerait le lancement du sort lui-même.
        teleport:SetScript("PostClick", function() panel:Dismiss() end)
    end

    --- Affiche la bannière. `spellID` est facultatif : sans lui, la bannière ne
    --- porte que le nom. Rend `false` si le combat l'interdit — les attributs du
    --- bouton ne s'écrivent pas alors, et la bannière n'a de toute façon rien à
    --- faire à l'écran pendant un combat.
    ---@param name string
    ---@param texture? number|string
    ---@param spellID? number
    ---@return boolean shown
    function panel:Announce(name, texture, spellID)
        if InCombatLockdown() then return false end

        label:SetText(name or "")
        icon:SetTexture(texture)
        icon:SetShown(texture ~= nil)

        if teleport then
            teleport:SetAttribute("spell", spellID)
            teleport:SetShown(spellID ~= nil)
        end

        self._pending = false
        self:SetAlpha(1)
        self:ApplyPosition()
        self:Show()
        return true
    end

    --- Ferme la bannière. En combat, elle est **rendue inatteignable** et sa
    --- fermeture est notée : `Settle` la terminera.
    ---
    --- Inatteignable et pas seulement invisible : une opacité nulle laisserait un
    --- bouton cliquable sous le curseur, c'est-à-dire une téléportation qui part
    --- toute seule au milieu d'un combat. On la sort donc de l'écran, ce qui
    --- passe — le panneau est à nous —, là où cacher son bouton sécurisé serait
    --- refusé.
    function panel:Dismiss()
        if InCombatLockdown() then
            self._pending = true
            self:SetAlpha(0)
            self:SetClampedToScreen(false)
            self:ClearAllPoints()
            self:SetPoint("CENTER", UIParent, "CENTER", 0, -GetScreenHeight() * 2)
            return
        end

        self._pending = false
        self:SetAlpha(1)
        self:SetClampedToScreen(true)
        self:Hide()
        self:ApplyPosition()
    end

    --- Termine une fermeture que le combat avait refusée. Sans effet si aucune
    --- n'est en attente.
    function panel:Settle()
        if not self._pending then return end
        self:Dismiss()
    end

    return panel
end
