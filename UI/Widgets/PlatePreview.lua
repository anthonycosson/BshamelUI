-- =========================================================================
--  Bshamel UI — UI/Widgets/PlatePreview.lua
--  La rangée d'auras des barres d'infos.
--
--  ## La maquette du client a vécu ici, et elle est partie
--
--  Ce fichier a porté un aperçu : une instance à nous de
--  `NamePlatePreviewTemplate`, la maquette que le panneau d'options du jeu
--  montre. Elle s'affichait correctement, suivait les CVars, et le raisonnement
--  qui l'autorisait paraissait solide — « la maquette n'a pas d'unité, elle n'a
--  donc aucune valeur secrète à comparer ».
--
--  **Le raisonnement était faux, et le jeu l'a dit :**
--
--      attempted to iterate a table that cannot be accessed while tainted
--      (execution tainted by 'BshamelUI')
--        CastingBarFrame.lua: StopFinishAnims <- StopAnims <- SetUnit
--        CompactUnitFrame_SetUnit <- ApplyFrameOptions <- OnNamePlateAdded
--        Blizzard_SettingsDefinitions_Frame/Nameplates.lua
--        <- pcall <- UI/Widgets/PlatePreview.lua
--
--  Monter ce template réveille le gestionnaire de barres d'infos du panneau de
--  réglages, qui repasse `ApplyFrameOptions` **sur les vraies plaques** — donc
--  sur de vraies unités, avec de vraies valeurs secrètes, et teinté par nous.
--  C'était aussi ce qui rendait les plaques à leur taille Blizzard à chaque
--  ouverture de la fenêtre d'options : le symptôme et l'erreur avaient la même
--  cause.
--
--  C'est la règle du module, rencontrée par une porte qu'on croyait dérobée :
--  **on n'entre pas dans le code de mise en page du client** (voir
--  `Modules/Nameplates.lua`, « On n'appelle pas le pilote de barres d'infos »).
--  Il n'y a pas de version prudente de cet appel, et `pcall` n'en protège pas —
--  ce n'est pas nous qui levons, c'est lui, parce que nous l'avons réveillé.
--
--  Ce qu'il reste : la rangée d'auras ci-dessous, qui ne monte que des cadres à
--  nous et n'appelle rien de lui.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local U    = BUI.Util
local W    = BUI.Widgets

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
            -- Le décompte chiffré est **montré**, et son corps se règle rangée
            -- par rangée. Il avait été masqué en le croyant réservé au
            -- gestionnaire de temps de recharge : c'est le balayage seul qui dit
            -- « bientôt fini », le chiffre dit *quand*, et sur une entrave de
            -- huit secondes les deux ne répondent pas à la même question.
            if cooldown.SetHideCountdownNumbers then
                cooldown:SetHideCountdownNumbers(false)
            end
            icon.cooldown = cooldown
        end
    end

    icon.count = icon:CreateFontString(nil, "OVERLAY", T.FONT.PLATE_STACK)
    icon.count:SetPoint("BOTTOMRIGHT", 0, 0)

    -- Le contour commun de l'addon, posé sur la vignette et laissé caché : c'est
    -- le réglage qui décide (voir `setEdge`). `nil` si le client ne connaît pas
    -- l'atlas — la vignette garde alors son liseré, et rien n'est cassé.
    icon.border = W.ShadeBorder(icon.face)

    row._icons[i] = icon
    return icon
end

--- Deux façons de border une vignette, et une seule à la fois.
---
---   · **le liseré**, un carré d'un pixel de la couleur de la nature de l'aura.
---     C'est ce que la rangée a toujours porté ;
---   · **le contour de l'addon**, la bordure de sort du jeu — coins en biseau —,
---     teintée de la même couleur pour ne rien perdre de ce que disait le
---     liseré.
---
--- Le second demande de **rogner l'image du sort** : une icône de sort porte son
--- propre liseré noir dans son dessin, et poser un contour par-dessus en fait
--- deux (même raison que `cropIcon` dans `UI/Shade.lua`). Le premier ne le
--- demande pas — il *est* un second bord, mais collé au dessin, ce qui se lit
--- comme un seul.
---
--- **Le mode sombre décide de l'intensité, pas de la présence.** Le contour se
--- dessine à pleine couleur d'ordinaire, et fonce avec le reste de l'interface
--- quand la teinte des auras est allumée — ce qu'on demande au moteur, qui seul
--- sait ce qui est réellement appliqué (`Shade:FactorFor`). Sans mode sombre
--- chargé, pleine couleur : un moteur absent n'est pas un moteur éteint, et la
--- rangée doit se border dans les deux cas.
---
--- Les deux se rendent l'un l'autre : c'est une case qui bascule, pas un état
--- qu'on pose une fois.
---@param icon table
---@param kind string
---@param shaded boolean
---@param side number  côté de la vignette, celui que le curseur vient de poser
local function setEdge(icon, kind, shaded, side)
    if shaded and icon.border then
        local from, to = T.SIZE.SHADE_ICON_CROP, 1 - T.SIZE.SHADE_ICON_CROP
        icon.face:SetTexCoord(from, to, from, to)
        icon.edge:Hide()

        -- Le côté est **donné**, jamais mesuré : une vignette descend d'une
        -- barre de nom, et le client rend ses mesures en valeurs secrètes, sur
        -- lesquelles le moindre calcul lève (voir `smallestSide` dans
        -- `UI/Widgets/ShadeBorder.lua`). Celui du contour est celui de l'image,
        -- donc la vignette moins son retrait des deux côtés.
        local face   = side - 2 * T.SIZE.PLATE_AURA_EDGE
        local factor = BUI.Shade and BUI.Shade:FactorFor("auras") or 1
        icon.border:Draw(factor, edgeColor(kind), face)
        return
    end

    icon.face:SetTexCoord(0, 1, 0, 1)
    icon.edge:SetColorTexture(edgeColor(kind):GetRGB())
    icon.edge:Show()
    if icon.border then icon.border.Hide() end
end

--- Affiche une liste d'auras : `{ icon =, kind =, count =, duration =,
--- expirationTime = }`, bornée par `list.n` — la liste est une table de travail
--- réutilisée, sa longueur ne se lit pas à `#`.
---
--- La rangée se dimensionne sur ce qu'elle montre et se cache quand il n'y a
--- rien : une rangée vide n'est pas une rangée discrète, c'est un cadre invisible
--- qui intercepte on ne sait quoi.
--- Le corps du décompte se repose **à chaque passage**, et pas une fois à la
--- construction : le client refait sa police en posant une durée, et une taille
--- écrite avant lui est perdue au premier balayage. Le poser ici coûte un appel
--- par vignette affichée, sur un chemin qui ne passe que quand une aura change.
---@param cooldown table
---@param timer number
local function setTimerSize(cooldown, timer)
    if type(cooldown.GetCountdownFontString) ~= "function" then return end

    local ok, text = pcall(cooldown.GetCountdownFontString, cooldown)
    if not ok or type(text) ~= "table" then return end

    T.SetTextSize(text, timer)
end

---@param list table
---@param side number
---@param gap number
---@param timer number  corps du décompte
---@param shaded boolean  contour de l'addon plutôt que liseré, voir `setEdge`
function W.AuraRowSet(row, list, side, gap, timer, shaded)
    -- La rangée vit **hors de l'échelle de la plaque** (voir `W.AuraRow`) : le
    -- nombre du curseur est donc un nombre de pixels d'écran, et il le reste
    -- quand la plaque de la cible grossit.

    -- `list.max` est le plafond que le joueur a réglé pour **cette** rangée ;
    -- celui du thème reste le plafond dur. La coupe se fait ici, à la peinture,
    -- et non au remplissage : un plafond abaissé se voit alors sans attendre
    -- qu'une aura change, et l'aperçu montre exactement ce que montrera la
    -- plaque.
    local shown = math.min(list.n or #list, list.max or T.SIZE.PLATE_AURA_MAX)

    for i = 1, shown do
        local entry = list[i]
        local icon  = iconOf(row, i)

        icon:SetSize(side, side)
        icon:ClearAllPoints()
        icon:SetPoint("LEFT", row, "LEFT", (i - 1) * (side + gap), 0)

        icon.face:SetTexture(entry.icon)

        -- Le bord se repose **après** la taille et l'image : le débordement du
        -- contour se mesure sur l'icône, et le rognage se pose sur la texture
        -- qu'on vient de lui donner.
        setEdge(icon, entry.kind, shaded, side)

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

            setTimerSize(icon.cooldown, timer)
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
---
--- **Le parent est la plaque, pas le cadre d'unité**, et les deux lignes qui
--- suivent en découlent. La plaque est le cadre que `C_NamePlate` nous rend :
--- il est à nous d'accès, le client n'en refait pas la mise en page, et son
--- niveau se lit. Le cadre d'unité et sa barre de vie, eux, sont des régions
--- restreintes que le client repose à chaque passage — une rangée posée là est
--- reprise dans la seconde (technique lue chez MiniCC, règle 8).
---
--- `SetIgnoreParentScale` est la seconde moitié de la même idée. La plaque de la
--- cible n'a pas l'échelle des autres, et elle change au clic : une rangée qui
--- en hérite respire à chaque changement de cible, et le nombre du curseur ne
--- veut plus rien dire. Hors de cette échelle, trente pixels sont trente pixels.
---@param parent table  la plaque, qui porte la rangée
---@return table|nil
function W.AuraRow(parent)
    local ok, row = pcall(CreateFrame, "Frame", nil, parent)
    if not (ok and row) then return nil end

    pcall(row.SetIgnoreParentScale, row, true)

    -- La rangée ne prend pas la souris : elle est posée par-dessus la plaque, et
    -- une plaque se clique pour cibler.
    pcall(row.EnableMouse, row, false)

    -- Le niveau du parent se lit **avant** de s'en servir : le client peut le
    -- rendre secret, et une arithmétique sur un secret lève — hors du `pcall` si
    -- elle se fait dans ses arguments. Illisible, on laisse le niveau que la
    -- création a donné.
    local okL, level = pcall(parent.GetFrameLevel, parent)
    if okL and type(level) == "number" and not U.IsSecret(level) then
        pcall(row.SetFrameLevel, row, level + 10)
    end

    row._icons = {}
    row:Hide()
    return row
end
