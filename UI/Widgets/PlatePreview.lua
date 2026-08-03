-- =========================================================================
--  Bshamel UI — UI/Widgets/PlatePreview.lua
--  L'aperçu de barre d'infos du client, posé dans notre page.
--
--  **On ne dessine rien.** Ce fichier a remplacé un widget qui fabriquait de
--  fausses auras et une fausse barre d'incantation, et qui a duré le temps qu'on
--  s'aperçoive qu'il mentait : ses vignettes n'avaient ni la taille, ni l'écart,
--  ni la place des vraies. Un aperçu qui approxime fait prendre des décisions de
--  réglage fausses — il est pire que pas d'aperçu.
--
--  Le client, lui, possède la maquette qu'il montre dans son propre panneau
--  d'options : `NamePlatePreviewTemplate`. On en fabrique **une instance à
--  nous** — on ne lui prend pas la sienne, ce qui la retirerait de son panneau.
--  Ce qu'elle affiche est ce qu'il affiche, et elle suivra ses changements de
--  style sans qu'on touche à une ligne.
--
--  ## Pourquoi c'est permis, alors que le reste ne l'était pas
--
--  Appeler le pilote de barres d'infos teinte tout ce qu'il touche, parce que son
--  chemin lit les points de vie d'une **vraie unité** — une valeur secrète, qui
--  ne se compare pas depuis du code d'addon (voir `dev/docs/API_NOTES.md`).
--
--  La maquette n'a pas d'unité. Ses méthodes s'appellent `SetExplicitValues`,
--  `UpdatePreviewText` : on lui *donne* ses valeurs, elle n'en lit aucune. Il n'y
--  a donc rien de secret à comparer, et le mur qui fermait cette porte n'est pas
--  devant celle-ci.
--
--  Cela reste un raisonnement, pas une preuve : tout passe par `pcall`, et un
--  refus rend `nil` plutôt qu'une erreur. Une page sans aperçu vaut mieux qu'une
--  page qui lève.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local U    = BUI.Util
local W    = BUI.Widgets

--- Construit un aperçu, ou `nil` si le client ne sait pas le monter.
---
--- Le `nil` n'est pas un cas d'erreur à rattraper : c'est ce qui fait
--- **disparaître** la ligne de la page, comme un contrôle branché sur un CVar
--- absent. Une maquette vide serait un cadre creux au milieu des réglages.
---@param parent table
---@return table|nil
function W.PlatePreview(parent)
    local template = T.Template("PLATE_PREVIEW")
    if not template then return nil end

    local ok, preview = pcall(CreateFrame, "Frame", nil, parent, template)
    if not (ok and preview) then return nil end

    -- **On lui impose sa hauteur, on ne la lui demande pas.** La première version
    -- lisait la sienne, en se disant que la maquette savait mieux que nous ce
    -- qu'elle occupait. Elle le sait, mais elle le dit parfois avec une valeur
    -- *secrète* — elle descend d'un template de barre d'infos, et le secret
    -- voyage avec elle. Cette hauteur devenait celle de la page, puis la course
    -- de l'ascenseur, qui ne se compare plus : mille cinq cents erreurs par
    -- seconde dans la fenêtre d'options.
    --
    -- Un nombre à nous coupe la contamination à la source. Il est moins juste, et
    -- c'est un prix qu'on paie volontiers.
    preview:SetHeight(T.SIZE.PLATE_PREVIEW_H)

    -- La maquette se remplit elle-même à l'affichage — c'est ce que font ses
    -- `OnShow` et ses `OnNamePlate*Changed`. On ne l'appelle donc pas : on la
    -- montre. C'est la même règle que partout ailleurs dans cet addon, où l'on
    -- laisse le client faire son travail plutôt que de le refaire à sa place.
    preview:Show()

    return preview
end

-- =========================================================================
--  La rangée d'auras de l'addon
-- =========================================================================
-- Une rangée qui affiche **ce qu'on lui donne** : les vraies auras d'une unité,
-- ou trois auras d'exemple. C'est le même code dans les deux cas, et c'est
-- toute la valeur de cette pièce — l'aperçu ne peut pas mentir sur ce qu'il
-- montre, puisqu'il *est* l'affichage qu'il prévisualise. La technique est
-- celle de MiniCC, lue pour la méthode (règle 8) : son mode test nourrit ses
-- propres conteneurs avec de faux sorts, et il est fidèle par construction.
--
-- Ce fichier a porté deux versions malhonnêtes avant celle-ci : des vignettes
-- inventées aux mauvaises mesures, puis les mêmes aux mesures du client mais
-- posées dans un conteneur dont l'intérieur ne se lit pas. Le détail de ces
-- impasses est dans `dev/docs/API_NOTES.md`.
--
-- La rangée s'ancre **au-dessus du nom** de la plaque : c'est là que le client
-- pose les siennes, et le nom est le seul repère publié. Un seul point règle
-- les deux axes — le nom est centré sur la plaque, caler le milieu-bas de la
-- rangée sur son milieu-haut la centre du même geste.

--- Couleur du liseré d'une vignette, par nature d'aura. La couleur d'entrave
--- est celle des casters : déjà, dans ce module, la teinte de « ce sur quoi on
--- agit tout de suite ».
---@param kind string  "HELP" | "HARM" | "CC"
---@return ColorMixin
local function edgeColor(kind)
    if kind == "HELP" then return T.COLOR.GREEN end
    if kind == "CC"   then return T.COLOR.PLATE.CASTER end
    return T.COLOR.RED
end

--- La i-ème vignette d'une rangée, construite au premier besoin puis réutilisée
--- (règle 7). Chaque vignette porte un liseré coloré, l'icône du sort, son
--- balayage de temps de recharge et son compteur de cumuls — les quatre choses
--- qu'une aura du client montre.
---@param row table
---@param i number
---@return table
local function iconOf(row, i)
    local icon = row._icons[i]
    if icon then return icon end

    icon = CreateFrame("Frame", nil, row)

    icon.edge = icon:CreateTexture(nil, "BACKGROUND")
    icon.edge:SetAllPoints()

    icon.face = icon:CreateTexture(nil, "ARTWORK")
    icon.face:SetPoint("TOPLEFT", T.SIZE.PLATE_AURA_EDGE, -T.SIZE.PLATE_AURA_EDGE)
    icon.face:SetPoint("BOTTOMRIGHT", -T.SIZE.PLATE_AURA_EDGE, T.SIZE.PLATE_AURA_EDGE)

    -- Le balayage du client, quand il le publie : une aura sans horloge se lit
    -- mal, mais elle se lit — on dégrade, on ne casse pas.
    local template = T.Template("COOLDOWN")
    if template then
        local ok, cooldown = pcall(CreateFrame, "Cooldown", nil, icon, template)
        if ok and cooldown then
            cooldown:SetAllPoints(icon.face)
            -- Le compte à rebours chiffré appartient au gestionnaire de temps de
            -- recharge ; sur une vignette de cette taille il recouvrirait tout.
            if cooldown.SetHideCountdownNumbers then
                cooldown:SetHideCountdownNumbers(true)
            end
            icon.cooldown = cooldown
        end
    end

    icon.count = icon:CreateFontString(nil, "OVERLAY", T.FONT.PLATE_STACK)
    icon.count:SetPoint("BOTTOMRIGHT", 0, 0)

    row._icons[i] = icon
    return icon
end

--- Affiche une liste d'auras : `{ icon =, kind =, count =, duration =,
--- expirationTime = }`, bornée par `list.n` — la liste est une table de travail
--- réutilisée, sa longueur ne se lit pas à `#`.
---
--- La rangée se dimensionne sur ce qu'elle montre et se cache quand il n'y a
--- rien : une rangée vide n'est pas une rangée discrète, c'est un cadre invisible
--- qui intercepte on ne sait quoi.
---@param list table
---@param side number
---@param gap number
function W.AuraRowSet(row, list, side, gap)
    -- La rangée retrouve l'échelle de l'interface, et **seulement** elle. Une
    -- plaque porte deux échelles empilées : celle de l'interface, que tous nos
    -- curseurs parlent, et un zoom à elle — la ciblée est grossie, les
    -- lointaines réduites. Suivre les deux rendait la taille du curseur fausse
    -- partout ; ignorer les deux (l'essai précédent) faussait en plus les
    -- décalages, qui se mesurent dans l'échelle du cadre. On annule donc le seul
    -- zoom de plaque : le rapport entre l'échelle effective du parent et celle
    -- de l'interface. Trente veut alors dire trente, comme sur tout autre
    -- curseur de l'addon, et la rangée cesse de respirer au changement de cible.
    local parent = row:GetParent()
    if parent then
        local okP, plateScale = pcall(parent.GetEffectiveScale, parent)
        local okU, uiScale    = pcall(UIParent.GetEffectiveScale, UIParent)
        -- Le secret avant la comparaison : une échelle protégée passerait le
        -- test de type et lèverait au `> 0`.
        if okP and okU
           and not U.IsSecret(plateScale) and not U.IsSecret(uiScale)
           and type(plateScale) == "number" and plateScale > 0
           and type(uiScale) == "number" and uiScale > 0 then
            pcall(row.SetScale, row, uiScale / plateScale)
        end
    end

    local shown = math.min(list.n or #list, T.SIZE.PLATE_AURA_MAX)

    for i = 1, shown do
        local entry = list[i]
        local icon  = iconOf(row, i)

        icon:SetSize(side, side)
        icon:ClearAllPoints()
        icon:SetPoint("LEFT", row, "LEFT", (i - 1) * (side + gap), 0)

        icon.edge:SetColorTexture(edgeColor(entry.kind):GetRGB())
        icon.face:SetTexture(entry.icon)

        if icon.cooldown then
            -- L'horloge d'une aura est un **objet de durée**, pas deux nombres :
            -- sur ce client, départ et échéance ne se lisent plus, et le
            -- balayage consomme l'objet tel quel — c'est ce qui le fait tourner
            -- sans jamais toucher une valeur protégée. Les nombres restent le
            -- repli des auras d'exemple, dont les durées sont à nous.
            if entry.durationObject
               and icon.cooldown.SetCooldownFromDurationObject then
                pcall(icon.cooldown.SetCooldownFromDurationObject,
                      icon.cooldown, entry.durationObject)
            elseif entry.duration and entry.duration > 0 and entry.expirationTime then
                icon.cooldown:SetCooldown(entry.expirationTime - entry.duration,
                                          entry.duration)
            else
                icon.cooldown:Clear()
            end
        end

        icon.count:SetText((entry.count and entry.count > 1)
                           and tostring(entry.count) or "")
        icon:Show()
    end

    for i = shown + 1, #row._icons do
        row._icons[i]:Hide()
    end

    if shown == 0 then
        row:Hide()
        return
    end

    row:SetSize(shown * side + (shown - 1) * gap, side)
    row:Show()
end

--- Construit une rangée d'auras. Vide, cachée et **sans ancrage** : c'est
--- l'appelant qui la pose — la place d'une rangée est une décision de module,
--- pas de widget — et `AuraRowSet` qui la peuple.
---@param parent table  le cadre d'unité, qui porte la rangée
---@return table|nil
function W.AuraRow(parent)
    local ok, row = pcall(CreateFrame, "Frame", nil, parent)
    if not (ok and row) then return nil end

    pcall(row.SetFrameLevel, row, (parent:GetFrameLevel() or 0) + 5)

    row._icons = {}
    row:Hide()
    return row
end
