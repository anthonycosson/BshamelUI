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
--  Bande de saisie
-- =========================================================================

--- Bande invisible posée le long de la barre de titre d'une fenêtre du client,
--- pour qu'on puisse toujours la prendre par là.
---
--- **Le motif.** Une fenêtre se prend par son `OnMouseDown`, et beaucoup de
--- fenêtres ne le reçoivent jamais : leur contenu prend la souris et couvre
--- tout le corps. La sonde le chiffre — le canevas des talents couvre
--- quatre-vingt-douze pour cent de la fenêtre des sorts, le navigateur d'aide
--- la totalité de la sienne. Il reste une bordure de quelques pixels, et le
--- joueur en conclut que le déplacement ne marche pas.
---
--- **Pourquoi une frame à nous, et pas un point d'accroche sur le leur.**
--- Brancher le glisser sur le cadre fautif marche quand ce cadre ne fait rien
--- d'autre ; le canevas des talents, lui, **se déplace déjà au glisser** — c'est
--- ainsi qu'on panoramique l'arbre. On y ferait les deux gestes à la fois. Et
--- rendre la barre de titre preneuse de souris demanderait `EnableMouse` sur un
--- cadre du client, exactement l'écriture d'état d'entrée que ce fichier refuse
--- de faire (voir `WheelCatcher`).
---
--- **Où elle se pose.** Sur `TitleContainer` quand la fenêtre en a un : c'est
--- l'endroit que Blizzard réserve à son titre, déjà dégagé du portrait à gauche
--- et du bouton de fermeture à droite. Sans lui, une bande de mêmes retraits le
--- long du bord haut. Dans les deux cas elle s'arrête **avant** la croix de
--- fermeture — une bande qui l'avalerait rendrait la fenêtre impossible à
--- fermer, ce qui serait pire que le défaut qu'elle corrige.
---
--- **Enfant de la fenêtre**, et c'est ce qui la rend sans entretien : elle suit
--- ses déplacements, son échelle et sa strate, et disparaît avec elle. La marque
--- `buiOwn` la fait passer sans être teintée par le mode sombre.
---
--- Rien n'est écrit sur la fenêtre elle-même : la bande se pose par-dessus,
--- comme le capteur de molette. L'éteindre suffit à la rendre indétectable.

--- Clés sous lesquelles une fenêtre publie le **bouton de réduction** de sa
--- barre de titre — celui que le retrait de Blizzard ne dégage pas, parce qu'il
--- se pose à gauche de la croix de fermeture et non à sa place.
---
--- Quatre graphies pour le même bouton, relevées dans la source du client : le
--- modèle le publie sous `MaxMinButtonFrame`, et chaque fenêtre le renomme —
--- `MaximizeMinimizeFrame` pour les communautés, la fenêtre d'essayage et la
--- carte, `MaximizeMinimizeButton` pour les sorts, `MaximizeMinimize` pour les
--- métiers. Une clé absente ne coûte rien ; une clé oubliée coûte un bouton.
---
--- La croix elle-même n'y est pas : le retrait la couvre déjà, et l'ajouter
--- ferait reculer la bande deux fois.
local TITLE_BUTTONS = {
    "MaxMinButtonFrame", "MaximizeMinimizeFrame", "MaximizeMinimizeButton",
    "MaximizeMinimize",
}

---@param window table
---@param onGrab fun()
---@param onRelease fun()
---@return table|nil
function W.TitleGrip(window, onGrab, onRelease)
    if type(window) ~= "table" or type(window.GetFrameLevel) ~= "function" then
        return nil
    end

    local grip = CreateFrame("Frame", nil, window)
    grip.buiOwn = true
    grip:EnableMouse(true)
    grip:Hide()

    -- Au-dessus de ce que la fenêtre porte, sinon la bande ne reçoit rien —
    -- c'est tout son objet. Le niveau est relatif à la fenêtre, donc la bande
    -- reste sous les fenêtres d'une strate supérieure (menus, infobulles).
    local ok, level = pcall(window.GetFrameLevel, window)
    if ok and type(level) == "number" then
        pcall(grip.SetFrameLevel, grip, level + T.SIZE.GRIP_LEVEL)
    end

    -- **Les deux coins hauts prennent le même repère, et c'est la règle.** Un
    -- `TOPLEFT` sur un cadre et un `TOPRIGHT` sur un autre imposent deux bords
    -- hauts au même rectangle : il n'en a qu'un, le client tranche comme il
    -- veut, et la bande sort de travers ou de hauteur nulle — donc muette, ce
    -- qui ne se voit pas. Le premier jet de cette fonction ancrait le coin droit
    -- sur le bouton de réduction, et c'est exactement ce qui s'est produit.
    --
    -- On écarte donc le bouton en **retrait**, pas en ancrage : sa largeur se
    -- lit sur lui (`GetWidth` rend la taille du modèle, même sur un cadre jamais
    -- affiché — c'est le *rectangle* qui manque à ce moment-là, pas la taille),
    -- et le repli vaut ce que Blizzard donne au sien.
    local extra = 0
    for i = 1, #TITLE_BUTTONS do
        local button = window[TITLE_BUTTONS[i]]
        if type(button) == "table" and type(button.GetObjectType) == "function" then
            local readable, width = pcall(button.GetWidth, button)
            if readable and type(width) == "number" and width > 0 then
                extra = width
            else
                extra = T.SIZE.GRIP_BUTTON_W
            end
            break
        end
    end

    local title = window.TitleContainer
    if type(title) == "table" and type(title.GetObjectType) == "function" then
        -- Le titre de la fenêtre : déjà dégagé du portrait à gauche et de la
        -- croix de fermeture à droite. Il ne reste que le bouton de réduction à
        -- écarter, quand il y en a un.
        grip:SetPoint("TOPLEFT",  title, "TOPLEFT",  0, 0)
        grip:SetPoint("TOPRIGHT", title, "TOPRIGHT", -extra, 0)

        -- Sa hauteur, quand elle est lisible. `or` ne suffit pas : un cadre
        -- jamais affiché peut rendre **zéro**, pas `nil`, et une bande de
        -- hauteur nulle ne reçoit rien — le défaut serait silencieux et parfait.
        local readable, height = pcall(title.GetHeight, title)
        if not (readable and type(height) == "number" and height > 0) then
            height = T.SIZE.GRIP_H
        end
        grip:SetHeight(height)
    else
        -- Sans titre publié, la bande se pose sur le bord haut, aux mesures que
        -- Blizzard donne au sien. Le retrait de droite dégage la croix ; le
        -- bouton de réduction s'ajoute par-dessus.
        grip:SetPoint("TOPLEFT",  window, "TOPLEFT",
                      T.SIZE.GRIP_INSET_L, -T.SIZE.GRIP_INSET_T)
        grip:SetPoint("TOPRIGHT", window, "TOPRIGHT",
                      -(T.SIZE.GRIP_INSET_R + extra), -T.SIZE.GRIP_INSET_T)
        grip:SetHeight(T.SIZE.GRIP_H)
    end

    grip:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then onGrab() end
    end)

    grip:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" then onRelease() end
    end)

    return grip
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
