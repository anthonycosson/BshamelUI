-- =========================================================================
--  Bshamel UI — UI/Widgets/KeyThresholds.lua
--  Ce qui manque au chrono mythique+ du client, ajouté à son bloc.
--
--  Le client affiche le temps restant, le niveau de la clé, une barre qui se vide
--  et un compteur de morts. Ce qu'il ne dit pas est ce qui décide d'une clé : où
--  tombent **+2** et **+3**, ce que les morts ont coûté, et à quelle minute chaque
--  boss est tombé. Ces choses-là se calculaient de tête en courant.
--
--  Un panneau à nous a vécu ici. Il redisait le temps restant à côté de celui du
--  client — deux chronos pour une clé, dont un seul est le vrai — et il fallait le
--  placer. Tout ce qui suit est donc **ajouté au bloc du client**, jamais redit :
--
--  - **Trois temps en rangée**, sur la ligne du chrono : ce qu'il reste avant
--    l'échéance, avant de perdre +3, avant de perdre +2. Le premier est celui du
--    client, on ne fait que le teinter. Un palier perdu retire son nombre, et le
--    suivant se recale contre le chrono.
--  - **Deux repères sur la barre**, aux deux paliers, rentrés dans le remplissage.
--  - **Le temps perdu par les morts**, sur l'en-tête du suivi : la ligne du chrono
--    est prise par les trois temps, et le compteur de morts du client ne bouge pas.
--  - **Le temps de chaque boss** sur les lignes du suivi, et l'écart avec une clé
--    de même niveau déjà réussie dans le chrono : vert si on est devant, rouge
--    sinon.
--
--  **Le code couleur est celui des trois paliers d'une clé**, et il vaut pour les
--  trois nombres : bleu pour le +1 qu'on obtient en finissant dans le chrono, or
--  pour le +3, gris pour le +2. Il ne se déduit de rien — c'est un vocabulaire, et
--  il vit dans `UI/Theme.lua` comme tous les autres.
--
--  Le temps restant, lui, reste écrit par **`UpdateTime`, la fonction du client**.
--  Un chrono qu'on démarre soi-même est faux dès qu'on recharge l'interface au
--  milieu d'une clé (voir `dev/docs/API_NOTES.md`), et un aperçu ne peut pas
--  ressembler à autre chose que le vrai puisque c'est le vrai qui dessine.
--
--  Réversibilité : chaque pièce se cache, et les deux textes du client qu'on
--  retouche — la couleur du chrono, le texte d'une ligne de boss — sont réécrits
--  par le client à sa passe suivante.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local U    = BUI.Util
local W    = BUI.Widgets

---@class BUI.KeyBoss
---@field name string     intitulé de la ligne
---@field at number       secondes écoulées quand il est tombé
---@field delta? number   écart avec la clé de référence

---@class BUI.KeySample
---@field name string             nom du donjon montré par l'aperçu
---@field level number            niveau de la clé
---@field limit number            chrono du donjon, en secondes
---@field elapsed number          secondes écoulées au départ de l'aperçu
---@field bosses? BUI.KeyBoss[]   lignes de boss d'exemple
---@field forces? table           `{ name, percent }`, le décompte de troupes d'exemple
---@field deaths? table           `{ count, lost }`, les morts d'exemple

---@class BUI.KeyThresholdOpts
---@field deaths? fun(): number|nil                          secondes perdues par les morts
---@field split? fun(index: any): number|nil, number|nil     temps du boss, écart

--- Fractions du chrono qui accordent des niveaux supplémentaires, **de la plus dure
--- à la plus facile** — c'est l'ordre dans lequel on les perd, donc l'ordre dans
--- lequel ils se lisent de gauche à droite.
---
--- Ce ne sont pas des réglages : ce sont les fractions que le jeu applique, et
--- elles ne sont publiées par aucune fonction de l'API. Elles vivent donc ici comme
--- une donnée de jeu, à un seul endroit. La couleur, elle, n'est pas une donnée de
--- jeu : c'est une entrée du thème, citée ici et choisie là-bas.
local TIERS = {
    { bonus = 3, fraction = 0.6, color = "TIER_THREE" },
    { bonus = 2, fraction = 0.8, color = "TIER_TWO" },
}

--- Intitulé du niveau de clé, celui du client. Le repli n'est pas une phrase à
--- traduire : un niveau se lit « +12 » dans toutes les langues.
local LEVEL_FORMAT = CHALLENGE_MODE_POWER_LEVEL or "+%d"

--- Le bloc de chrono du suivi d'objectifs, et le module qui le porte.
---
--- Test de capacité et non de version (règle 1) : on ne demande pas quel patch
--- tourne, on demande si le bloc est là et s'il porte les pièces qu'on va toucher.
--- Rend `nil` sinon, et le module se passe alors de tout cela plutôt que de lever
--- une erreur.
---@return table|nil block, table|nil tracker
local function findBlock()
    local tracker = ScenarioObjectiveTracker
    if type(tracker) ~= "table" or not tracker.LayoutBlock then return nil end

    local block = tracker.ChallengeModeBlock
    if type(block) ~= "table" then return nil end
    if not (block.StatusBar and block.TimeLeft and block.Level
            and block.UpdateTime and block.IsActive) then
        return nil
    end

    return block, tracker
end

--- Les ajouts au chrono mythique+ du client.
--- Rend `nil` si le client ne publie pas ce bloc.
---@param opts BUI.KeyThresholdOpts
---@return table|nil
function W.KeyThresholds(opts)
    -- Les deux sont testés, alors que `findBlock` ne rend jamais l'un sans
    -- l'autre : c'est ce test-là qui apprend à l'analyse statique que la suite
    -- n'a plus à s'en soucier.
    local block, tracker = findBlock()
    if not (block and tracker) then return nil end

    local notches   = {}
    local countdown = {}
    local tiersOn   = false   -- repères, teinte du chrono et compte-à-rebours
    local deathsOn  = false   -- temps perdu par les morts
    local splitsOn  = false   -- temps de boss sur les lignes du suivi
    local sample    = nil     ---@type BUI.KeySample|nil
    local elapsed   = 0       -- avancement de l'aperçu, en secondes
    local ticker    = nil

    -- ---------------------------------------------------------------------
    --  Les repères sur la barre
    -- ---------------------------------------------------------------------
    -- Posés sur le **bloc** et non sur sa barre, à un sous-calque plus haut que
    -- l'habillage du client : celui-ci est dessiné par-dessus la barre pour lui
    -- faire un cadre, et une texture posée sur la barre passerait dessous.
    -- L'ancrage, lui, reste sur la barre — c'est elle qui porte l'échelle du temps.
    --
    -- Teintés de l'or de l'habillage et non du doré des libellés : un repère
    -- appartient au cadre, il ne s'y pose pas (voir `T.COLOR.FRAME_GOLD`).
    --
    -- **Deux textures par repère, et non une.** Ce qui se lit n'est pas un trait
    -- plein : c'est une lueur, opaque sur le palier et éteinte sur ses deux bords.
    -- Un dégradé ne va que dans un sens, donc il en faut deux, dos à dos — la moitié
    -- gauche s'allume vers la droite, la droite s'éteint vers la droite.
    --
    -- Sans dégradé disponible chez le client, chaque moitié se rabat sur un aplat :
    -- le repère est alors plus dur, jamais absent.

    ---@param opaqueAtMax boolean  l'extrémité pleine est-elle à droite ?
    ---@return table
    local function newNotchHalf(opaqueAtMax)
        local half = block:CreateTexture(nil, "OVERLAY", nil, T.SIZE.KEY_TIER_LEVEL)
        half:SetSize(T.SIZE.KEY_TIER_W / 2, T.SIZE.KEY_TIER_H)

        if not T.ApplyGradient(half, T.COLOR.FRAME_GOLD, T.ALPHA.KEY_TIER,
                               "HORIZONTAL", opaqueAtMax) then
            half:SetColorTexture(T.COLOR.FRAME_GOLD:GetRGB())
        end

        half:Hide()
        return half
    end

    for i = 1, #TIERS do
        notches[i] = { newNotchHalf(true), newNotchHalf(false) }
    end

    -- ---------------------------------------------------------------------
    --  Les deux compte-à-rebours
    -- ---------------------------------------------------------------------
    -- En **rangée** à droite du chrono, et non empilés : trois temps sur une ligne
    -- se lisent d'une saccade de l'œil, deux colonnes en demandent deux. La rangée
    -- du chrono est de toute façon la seule place libre du bloc — les affixes
    -- tiennent celle du niveau, le compteur de morts tient la droite, la barre
    -- tient le bas.
    --
    -- Chacun s'ancre par le **bas** au bas de son voisin de gauche : des nombres de
    -- corps différents se lisent sur une ligne quand leurs pieds sont alignés, pas
    -- leurs centres. Et le premier s'ancre au bord droit du chrono, qui suit son
    -- texte — le chrono n'a pas de largeur déclarée, donc la rangée se recale
    -- d'elle-même quand « 4:59 » devient « 24:59 ».

    for i = 1, #TIERS do
        local row = block:CreateFontString(nil, "OVERLAY", T.FONT.KEY_NEXT)
        row:SetJustifyH("LEFT")
        row:SetTextColor(T.COLOR[TIERS[i].color]:GetRGB())
        row:SetPoint("BOTTOMLEFT", (i == 1) and block.TimeLeft or countdown[i - 1],
                     "BOTTOMRIGHT", T.SIZE.KEY_NEXT_PAD, 0)
        row:Hide()

        countdown[i] = row
    end

    -- ---------------------------------------------------------------------
    --  Le temps perdu par les morts
    -- ---------------------------------------------------------------------
    -- Sur l'**en-tête du suivi**, à droite, et non contre le compteur de morts : la
    -- ligne du chrono est prise par les trois temps, et le compteur du client reste
    -- où le client l'a mis. L'en-tête ne porte que le nom du donjon, cadré à
    -- gauche — sa droite est la dernière place libre de tout le bloc.
    --
    -- Sur la **rangée du niveau**, entre le niveau de clé et les affixes. La rangée
    -- du chrono a été essayée d'abord, contre le compteur de morts : les trois temps
    -- n'y laissent qu'une trentaine de pixels, soit la largeur du nombre à un cheveu
    -- près, et un chrono qui passe à cinq chiffres mangeait le reste.
    --
    -- Plus petit que les paliers, aussi : la rangée du niveau est basse, et c'est un
    -- nombre qui se consulte plutôt qu'il ne se lit en courant. Le compteur de morts
    -- du client, lui, ne bouge pas — c'est sa place, on ne fait que se ranger
    -- ailleurs. Son ancrage est reposé par `anchorDeaths`, les affixes n'existant
    -- pas encore.

    local deaths = block:CreateFontString(nil, "OVERLAY", T.FONT.KEY_DEATHS)
    deaths:SetJustifyH("RIGHT")
    deaths:SetWordWrap(false)
    deaths:SetTextColor(T.COLOR.RED:GetRGB())
    deaths:Hide()

    -- =====================================================================
    --  Affichage
    -- =====================================================================

    --- Repose les repères sur la barre.
    ---
    --- **La barre porte le temps restant, pas le temps écoulé** : le client la borne
    --- de zéro au chrono du donjon et lui donne le temps qui reste. Un palier
    --- accordé « sous 60 % du chrono » se lit donc à 40 % de la barre, et le
    --- remplissage le franchit en descendant.
    ---
    --- Le repère est **cadré en haut** de la barre et haut de dix pixels sur les
    --- treize du cadre : la marge transparente de l'atlas du remplissage n'est pas
    --- symétrique, et les trois pixels qu'on laisse sont ceux du bas (voir
    --- `T.SIZE.KEY_TIER_H`). Ses deux moitiés se rejoignent **sur** le palier, si
    --- bien que la lueur est centrée dessus et non posée à côté.
    local function layout()
        local bar   = block.StatusBar
        local width = bar:GetWidth() or 0

        for i = 1, #TIERS do
            local x = width * (1 - TIERS[i].fraction)

            notches[i][1]:ClearAllPoints()
            notches[i][1]:SetPoint("TOPRIGHT", bar, "TOPLEFT", x, 0)

            notches[i][2]:ClearAllPoints()
            notches[i][2]:SetPoint("TOPLEFT",  bar, "TOPLEFT", x, 0)
        end
    end

    --- Écrit les deux compte-à-rebours.
    ---
    --- **Le chrono du client n'est pas touché.** Il reste blanc, comme le client
    --- l'écrit, et rouge à l'échéance comme le client le colore : c'est le nombre
    --- principal, le blanc est ce qu'il y a de plus lisible, et le teindre comme un
    --- palier le rangerait au même niveau que les deux autres alors qu'il les
    --- commande.
    ---
    --- Un palier perdu **vide et efface** son nombre. Le vider et pas seulement le
    --- cacher : le nombre suivant est ancré à son bord droit, donc un nombre caché
    --- mais large laisserait un blanc là où il était.
    ---@param timeLeft number
    ---@param limit number
    local function paint(timeLeft, limit)
        for i = 1, #TIERS do
            local margin = (limit > 0) and (timeLeft - limit * (1 - TIERS[i].fraction)) or 0

            if margin > 0 then
                countdown[i]:SetText(U.Clock(margin))
                countdown[i]:Show()
            else
                countdown[i]:SetText("")
                countdown[i]:Hide()
            end
        end
    end

    --- Repose le temps des morts entre le niveau de clé et les affixes.
    ---
    --- Il grandit **vers la gauche**, depuis l'affixe le plus à gauche, et c'est le
    --- seul sens qui tienne dans tous les cas : le client pose ses affixes depuis le
    --- bord droit du bloc, donc trois affixes commencent plus à gauche que deux et
    --- quatre plus à gauche encore. Un nombre cadré à droite contre eux recule
    --- d'autant, là où un nombre posé à la suite du niveau leur monterait dessus dès
    --- qu'il y en a quatre.
    ---
    --- Sans affixe — l'aperçu n'en pose pas —, il se range à la suite du niveau.
    local function anchorDeaths()
        local edge, edgeLeft

        local pool = block.affixPool
        if pool and pool.EnumerateActive then
            for frame in pool:EnumerateActive() do
                local left = frame:GetLeft()
                if left and (not edgeLeft or left < edgeLeft) then
                    edge, edgeLeft = frame, left
                end
            end
        end

        deaths:ClearAllPoints()
        if edge then
            deaths:SetPoint("RIGHT", edge, "LEFT", -T.SIZE.KEY_DEATHS_PAD, 0)
        else
            deaths:SetPoint("LEFT", block.Level, "RIGHT", T.SIZE.KEY_DEATHS_PAD, 0)
        end
    end

    --- Écrit le temps perdu par les morts, ou retire le nombre s'il n'y a pas encore
    --- eu de mort — un « +00:00 » rouge alarmerait sans rien dire.
    ---
    --- En aperçu, le nombre vient du relevé : hors donjon, le client ne compte aucune
    --- mort, et l'aperçu montrerait alors la seule chose qu'on ne veut pas y voir —
    --- rien.
    local function paintDeaths()
        local lost
        if sample then
            lost = sample.deaths and sample.deaths.lost
        elseif opts.deaths then
            lost = opts.deaths()
        end

        if not (deathsOn and lost) or lost <= 0 then
            deaths:Hide()
            return
        end

        anchorDeaths()
        deaths:SetText(U.Delta(lost))
        deaths:Show()
    end

    ---@param visible boolean
    local function setTiersShown(visible)
        for i = 1, #notches do
            notches[i][1]:SetShown(visible)
            notches[i][2]:SetShown(visible)
        end
        if not visible then
            for i = 1, #countdown do
                countdown[i]:SetText("")
                countdown[i]:Hide()
            end
        end
    end

    --- Le suffixe d'une ligne de boss : son temps, et l'écart s'il y a une référence.
    ---
    --- Une ligne du suivi est un **seul texte**, donc une seule couleur, et il en
    --- faut trois — le nom au ton du client, le temps à l'or de l'habillage, l'écart
    --- en vert ou en rouge. Les couleurs passent donc par des codes en ligne.
    ---
    --- **L'écart passe à la ligne, toujours.** Bout à bout, la ligne tenait sur un
    --- rang pour « Ranjit » et sur deux pour « Grand sage Viryx » : le retour à la
    --- ligne tombait alors selon la longueur du nom, donc à un endroit différent pour
    --- chaque boss, et la colonne des écarts n'existait pas. Un retour forcé le rend
    --- prévisible — le temps reste contre le nom, l'écart est toujours dessous.
    ---@param at number
    ---@param delta? number
    ---@return string
    local function splitSuffix(at, delta)
        local suffix = "  " .. T.Colorize(T.COLOR.FRAME_GOLD, U.Clock(at))
        if not delta then return suffix end

        local color = (delta <= 0) and T.COLOR.GREEN or T.COLOR.RED
        return suffix .. "\n" .. T.Colorize(color, U.Delta(delta))
    end

    -- ---------------------------------------------------------------------
    --  Ce que le client nous dit
    -- ---------------------------------------------------------------------
    -- Trois accroches, et aucune ne compte quoi que ce soit : le client repose son
    -- chrono par `UpdateTime`, borne sa barre dans `Activate`, et recompte ses morts
    -- dans `UpdateDeathCount`. On écrit juste après lui, à chaque fois.

    U.GuardedHook(block, "UpdateTime", function(self, elapsedTime)
        local limit = self.timeLimit or 0
        paint(math.max(0, limit - (elapsedTime or 0)), limit)
    end, function() return tiersOn end)

    U.GuardedHook(block, "Activate", function()
        layout()
        setTiersShown(true)
    end, function() return tiersOn end)

    U.GuardedHook(block, "UpdateDeathCount", paintDeaths, function() return deathsOn end)

    -- Les affixes sont posés au départ de la clé, et c'est **contre eux** que le
    -- temps des morts se cale : il faut donc attendre qu'ils existent. `Activate`
    -- appelle cette fonction, donc ce hook suffit à couvrir le départ d'une clé.
    U.GuardedHook(block, "SetUpAffixes", anchorDeaths, function() return deathsOn end)

    -- ---------------------------------------------------------------------
    --  Les temps de boss
    -- ---------------------------------------------------------------------
    -- Le suivi construit ses lignes par `AddObjective`, qui pose le texte **et en
    -- déduit la hauteur de la ligne**. On ne peut donc pas rallonger un texte sans
    -- refaire ce calcul : un nom de boss long passerait à la ligne, et la ligne
    -- suivante lui monterait dessus.
    --
    -- On refait donc le calcul avec la fonction du client, `SetStringText`, qui rend
    -- la hauteur du texte, et on reporte l'écart sur la hauteur du bloc. Le reste
    -- suit tout seul : les lignes s'ancrent l'une sous l'autre.
    --
    -- On lui passe `useFullHeight` **vrai** là où le client passe faux, ce qui lève
    -- son plafond de deux rangs. L'écart occupant désormais un rang à lui seul, un
    -- nom de boss qui passe à la ligne en demanderait trois, et le troisième serait
    -- coupé — c'est-à-dire l'écart, la seule chose qu'on a ajoutée.

    local objectives = tracker.ObjectivesBlock

    if objectives and objectives.AddObjective and objectives.SetStringText then
        U.GuardedHook(objectives, "AddObjective",
            function(self, objectiveKey, text, _, _, _, colorStyle)
                if type(text) ~= "string" or not opts.split then return end

                local at, delta = opts.split(objectiveKey)
                if not at then return end

                local line = self.GetExistingLine and self:GetExistingLine(objectiveKey)
                if not (line and line.Text) then return end

                local before = line:GetHeight()
                local after  = self:SetStringText(line.Text, text .. splitSuffix(at, delta),
                                                 true, colorStyle, self.isHighlighted)
                line:SetHeight(after)
                self.height = (self.height or 0) + (after - before)
            end,
            function() return splitsOn end)
    end

    -- ---------------------------------------------------------------------
    --  Aperçu
    -- ---------------------------------------------------------------------
    -- Le suivi d'objectifs ne pose son bloc de chrono qu'en donjon mythique+ : hors
    -- donjon, sa mise en page sort avant d'y arriver. On la lui demande donc
    -- **après** son passage — un hook ne défait pas ce qu'une fonction du client a
    -- décidé, il ajoute ce qu'elle n'a pas fait.
    --
    -- Et seulement si elle n'a rien posé du tout : un scénario en cours a son propre
    -- contenu dans ce module, et un bloc de chrono collé dessous serait un aperçu
    -- posé sur du vrai.

    --- Pose les lignes d'exemple sous le bloc de chrono : les boss, puis le décompte
    --- des troupes.
    ---
    --- Elles passent par `AddObjective`, la fonction du client, avec ses pastilles et
    --- ses teintes : un aperçu bâti autrement montrerait autre chose que ce qu'on
    --- verra. Leur suffixe est composé ici plutôt que laissé au hook des vrais temps
    --- de boss — celui-là interroge l'état d'une clé en cours, et il n'y en a pas.
    ---@param module table
    local function layoutSampleLines(module)
        if not (sample and sample.bosses and objectives and objectives.Reset) then return end

        objectives:Reset()

        for i = 1, #sample.bosses do
            local boss = sample.bosses[i]
            local text = string.format("%d/%d %s", 1, 1, boss.name or "")
            if splitsOn and boss.at then
                text = text .. splitSuffix(boss.at, boss.delta)
            end

            -- `useFullHeight` vrai pour la même raison que sur les vraies lignes :
            -- l'écart occupe un rang à lui, et le plafond de deux le couperait dès
            -- qu'un nom passe à la ligne.
            local line = objectives:AddObjective(i, text, nil, true,
                                                 OBJECTIVE_DASH_STYLE_HIDE,
                                                 OBJECTIVE_TRACKER_COLOR["Complete"])
            if line and line.Icon then
                line.Icon:Show()
                T.TrySetAtlas(line.Icon, T.ATLAS.OBJECTIVE_DONE)
            end
        end

        if sample.forces then
            local line = objectives:AddObjective("forces",
                string.format("%s  %.2f%%", sample.forces.name or "",
                              sample.forces.percent or 0),
                nil, nil, OBJECTIVE_DASH_STYLE_HIDE)
            if line and line.Icon then
                line.Icon:Show()
                T.TrySetAtlas(line.Icon, T.ATLAS.OBJECTIVE_TODO)
            end
        end

        module:LayoutBlock(objectives)
    end

    U.GuardedHook(tracker, "LayoutContents", function(self)
        if not sample or self.hasContents or block:IsActive() then return end

        self:LayoutBlock(block)
        layoutSampleLines(self)

        if self.Header and self.Header.Text then
            self.Header.Text:SetText(sample.name or "")
        end
    end, function() return sample ~= nil end)

    --- Remplit le bloc du client avec le relevé d'aperçu, puis le laisse dessiner.
    local function drawSample()
        if not sample then return end

        block.timeLimit   = sample.limit
        block.wasDepleted = false
        block.Level:SetText(LEVEL_FORMAT:format(sample.level or 0))

        -- Les deux pièces que le client n'affiche que sur événement : sans clé en
        -- cours, rien ne les a remplies.
        if block.StartedDepleted    then block.StartedDepleted:Hide()    end
        if block.TimesUpLootStatus  then block.TimesUpLootStatus:Hide()  end

        -- Le compteur de morts, lui, se **remplit** au lieu de se cacher : c'est une
        -- pièce du bloc, et un aperçu qui l'escamote ne montre pas le bloc. Il reste
        -- à sa place, et ses deux champs sont remplis avec — son infobulle les lit,
        -- et une infobulle qui contredit le nombre qu'elle explique est pire que pas
        -- d'infobulle.
        local count = sample.deaths and sample.deaths.count or 0
        if block.DeathCount then
            block.deathCount = count
            block.timeLost   = sample.deaths and sample.deaths.lost or 0
            if block.DeathCount.Count then block.DeathCount.Count:SetText(count) end
            block.DeathCount:SetShown(count > 0)
        end

        block.StatusBar:SetMinMaxValues(0, sample.limit)
        block:UpdateTime(elapsed)

        layout()
        setTiersShown(tiersOn)
        paintDeaths()
    end

    --- Fait courir le chrono d'aperçu, à la vitesse à laquelle il court en donjon.
    ---
    --- **À vitesse réelle, et pas accélérée.** L'aperçu sert à juger ce que ça donne
    --- à l'écran, pas à dérouler une clé en trente secondes : un chrono qui défile
    --- dix fois trop vite ne ressemble plus à ce qu'on verra. Il n'a pas à défiler
    --- pour montrer les paliers — l'exemple démarre au-dessus des deux repères, donc
    --- les trois temps sont là dès le premier passage.
    ---
    --- Il repart de son départ à l'échéance, plutôt que de rester figé sur zéro.
    local function tick()
        if not sample or block:IsActive() then return end

        elapsed = elapsed + T.TIMING.KEY_PREVIEW
        if elapsed > sample.limit then elapsed = sample.elapsed end
        drawSample()
    end

    --- Rend au bloc l'état où le client l'a laissé : aucun chrono, aucun niveau.
    --- Un `timeLimit` qui traîne serait une clé de plus dans un bloc éteint.
    ---
    --- **Sauf si une vraie clé a démarré entre-temps** — et c'est le cas le plus
    --- fréquent, puisque le départ d'une clé est justement ce qui éteint l'aperçu. Le
    --- client vient alors de remplir le bloc, et l'effacer lui retirerait son propre
    --- chrono : son prochain passage lèverait sur un `timeLimit` absent.
    local function clearSample()
        if block:IsActive() then return end

        block.timeLimit = nil
        block.Level:SetText("")
        block.TimeLeft:SetText("")

        -- Le compteur de morts avait été rempli pour l'aperçu : on le rend au client
        -- vide et caché, l'état d'un bloc que rien n'a encore activé.
        block.deathCount = nil
        block.timeLost   = nil
        if block.DeathCount then
            if block.DeathCount.Count then block.DeathCount.Count:SetText("") end
            block.DeathCount:Hide()
        end
        deaths:Hide()
    end

    -- =====================================================================
    --  Commandes
    -- =====================================================================

    local marker = {}

    --- Redemande une passe au suivi d'objectifs. C'est le seul moyen de faire
    --- réécrire ses lignes, et c'est celui que le client s'applique à lui-même
    --- quand son chrono s'arrête.
    function marker:Refresh()
        tracker:MarkDirty()
    end

    --- Affiche ou retire les repères et les compte-à-rebours.
    ---@param visible boolean
    function marker:SetThresholds(visible)
        tiersOn = visible and true or false
        if tiersOn then layout() end
        setTiersShown(tiersOn)
    end

    --- Affiche ou retire le temps perdu par les morts.
    ---@param visible boolean
    function marker:SetDeaths(visible)
        deathsOn = visible and true or false
        paintDeaths()
    end

    --- Affiche ou retire les temps de boss. Les lignes déjà écrites ne se retouchent
    --- pas : on redemande une passe, et le client les réécrit — avec notre suffixe
    --- si le réglage est allumé, sans lui sinon. C'est aussi ce qui rend le module
    --- indétectable une fois éteint.
    ---@param visible boolean
    function marker:SetSplits(visible)
        local was = splitsOn
        splitsOn  = visible and true or false
        if was ~= splitsOn then self:Refresh() end
    end

    --- Allume l'aperçu sur le relevé donné, ou l'éteint avec `nil`.
    ---@param data BUI.KeySample|nil
    function marker:SetPreview(data)
        if not data then
            if not sample then return end

            sample = nil
            if ticker then
                ticker:Cancel()
                ticker = nil
            end
            clearSample()
            self:Refresh()
            return
        end

        sample  = data
        elapsed = data.elapsed or 0
        drawSample()

        if not ticker then
            ticker = C_Timer.NewTicker(T.TIMING.KEY_PREVIEW, tick)
        end
        self:Refresh()
    end

    --- Rend le module indétectable : tout se cache, l'aperçu s'éteint, et le suivi
    --- réécrit ses lignes sans nous.
    function marker:Stop()
        self:SetPreview(nil)
        self:SetThresholds(false)
        self:SetDeaths(false)
        self:SetSplits(false)
    end

    return marker
end
