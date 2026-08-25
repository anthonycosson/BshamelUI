-- =========================================================================
--  Bshamel UI — Modules/GroupFinder.lua
--  Ce qui entoure une inscription : la note, la confirmation, le compte à
--  rebours — et le tri des annonces elles-mêmes.
--
--  Quatre agacements de la recherche de groupe, qui n'ont en commun que le
--  moment où on les rencontre :
--
--   · la **note d'inscription** se retape à chaque candidature, alors que c'est
--     la même depuis six mois ;
--   · la **vérification des rôles** demande de cliquer sur un bouton pour dire
--     ce qu'on a déjà dit en s'inscrivant ;
--   · la fenêtre qui annonce l'instance **ne dit pas combien de temps il reste**
--     pour la prendre, alors qu'elle se referme toute seule ;
--   · la recherche personnalisée **montre tout**, sans filtre de difficulté ni
--     de composition — le **panneau de filtres** (deuxième moitié du fichier)
--     s'ancre contre elle et cache ce qu'on n'a pas demandé.
--
--  Le minuteur vivait dans *Général*, faute de page où le mettre. Il est ici
--  depuis que celle-ci existe, et un palier de migration (`Core/DB.lua`) déplace
--  le réglage de ceux qui l'avaient changé.
--
--  La note et les valeurs des filtres sont des **données**, pas des réglages :
--  elles vivent dans le SavedVariables du personnage (`DB:CharData`), hors du
--  mécanisme de défauts — c'est le même chemin que l'historique de chat, et
--  pour la même raison.
--
--  ## D'où viennent les points d'accroche du panneau
--
--  De la lecture de Premade Groups Filter (règle 8 : lire pour identifier les
--  API, jamais copier — il est sous GPL, incompatible avec notre licence).
--  L'essentiel tient en deux hooks et trois lectures, consignés dans
--  `dev/docs/API_NOTES.md`. Sa table de sept cents activités maintenue à la
--  main n'est **pas** reprise : tout ce que le filtre sait d'un résultat, il
--  le demande au client au moment où il le regarde. L'état **neutre** ne cache
--  rien — cases toutes cochées, bornes vides : allumer le panneau ne change
--  rien aux résultats tant qu'on n'a rien réglé.
--
--  Réversibilité : les deux scripts posés sur la fenêtre d'inscription et les
--  deux hooks de la recherche passent par `U.GuardedScript`/`U.GuardedHook`,
--  donc deviennent inertes quand le module s'éteint (règle 6) ; les décomptes
--  s'arrêtent, le panneau se cache, et la liste intacte des résultats est
--  reposée à l'écran.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local U    = BUI.Util
local W    = BUI.Widgets
local L    = ns.L

local MODULE = "GroupFinder"

-- =========================================================================
--  Note d'inscription
-- =========================================================================

--- Zone de saisie de la note, ou `nil` tant que la recherche de groupe n'est pas
--- montée : sa fenêtre est chargée à la demande.
---
--- Trois chemins, du plus explicite au plus général. Le client a déjà déplacé
--- cette zone d'un cran de profondeur en changeant de conteneur défilant, et un
--- chemin devenu faux ne lève pas : il rend `nil`, le réglage ne fait plus rien,
--- et rien ne le dit. On cherche donc la zone plutôt que de nommer le conteneur
--- du jour.
---@return table|nil
local function noteBox()
    local dialog = LFGListApplicationDialog
    local body   = dialog and dialog.Description
    if not body then return nil end

    if body.EditBox and body.EditBox.GetText then return body.EditBox end
    if body.GetText then return body end

    if not body.GetChildren then return nil end
    for _, child in ipairs({ body:GetChildren() }) do
        if child.GetObjectType and child:GetObjectType() == "EditBox" then
            return child
        end
    end
    return nil
end

---@param mod table
local function hookSignupNote(mod)
    local dialog = LFGListApplicationDialog
    if not (dialog and noteBox()) then return end

    local guard = function()
        return mod:IsEnabled() and mod:Get("keepSignupNote") == true
    end

    -- À l'ouverture, on ne remplit qu'une zone **vide** : le client y met parfois
    -- lui-même quelque chose, et écraser ce qu'il a écrit serait le contredire.
    U.GuardedScript(dialog, "OnShow", function()
        local box = noteBox()
        if not box then return end
        if box:GetText() ~= "" then return end

        local note = mod:CharData().signupNote
        if note and note ~= "" then box:SetText(note) end
    end, guard)

    -- À la fermeture, on relève ce qui est écrit, que la candidature soit partie
    -- ou non : une note abandonnée est justement celle qu'on veut retrouver.
    U.GuardedScript(dialog, "OnHide", function()
        local box = noteBox()
        if not box then return end
        mod:CharData().signupNote = box:GetText()
    end, guard)
end

-- =========================================================================
--  Confirmations
-- =========================================================================

--- Fenêtres candidates du client pour la demande de rôles, de la plus récente à
--- la plus ancienne. Test de capacité et non de version (règle 1) : sur le client
--- courant, seule `LFDRoleCheckPopup` existe.
---@return table|nil
local function rolePopup()
    if LFGRoleCheckPopup and LFGRoleCheckPopup.HookScript then return LFGRoleCheckPopup end
    if LFDRoleCheckPopup and LFDRoleCheckPopup.HookScript then return LFDRoleCheckPopup end
    return nil
end

--- Vrai tant que la demande de rôles en cours a déjà reçu notre réponse.
---
--- Deux chemins y mènent — l'événement et l'ouverture de la fenêtre — et rien ne
--- dit lequel arrive le premier : le client montre sa fenêtre depuis son propre
--- abonnement au même événement, et l'ordre entre deux abonnés n'est pas défini.
--- Ce drapeau est ce qui rend les deux chemins interchangeables : le premier
--- servi répond, le second n'a plus rien à faire.
local roleCheckAnswered = false

--- Répond à la demande de rôles si le réglage le veut.
---@param mod table
---@return boolean answered  vrai si la demande est réglée, par cet appel ou l'autre
local function answerRoleCheck(mod)
    if not mod:Get("autoRoleCheck") then return false end
    if roleCheckAnswered then return true end
    if not CompleteLFGRoleCheck then return false end

    roleCheckAnswered = true
    CompleteLFGRoleCheck(true)

    -- Et si elle est déjà là, on la referme. Le crochet posé sur son ouverture
    -- l'empêche d'être dessinée quand il a pu être posé à temps ; ceci rattrape
    -- le cas où elle nous a précédés, et raccourcit alors ce qu'on ne peut plus
    -- supprimer.
    local popup = rolePopup()
    if popup and popup:IsShown() then popup:Hide() end

    return true
end

--- Empêche la fenêtre de demande de rôles de s'afficher quand on y répond seul.
---
--- **Répondre à l'événement ne suffit pas.** Le client ouvre sa fenêtre depuis
--- son propre abonnement au même événement : répondre avant lui ne l'empêche pas
--- d'ouvrir, cela avance seulement le moment où elle se referme. Elle apparaît
--- donc quand même, le temps d'un battement de cils, et c'est ce battement qu'on
--- vient supprimer.
---
--- Une frame montrée puis cachée **dans le même passage** n'est jamais dessinée :
--- se poser sur son `OnShow` est ce qui fait disparaître le clignotement au lieu
--- de le raccourcir.
---
--- La réponse est envoyée d'ici aussi, et pas seulement cachée : c'est ce qui
--- garantit qu'on ne masque jamais une fenêtre à laquelle personne n'a répondu.
---@param mod table
local function hookRoleCheck(mod)
    local popup = rolePopup()
    if not popup then return end

    U.GuardedScript(popup, "OnShow", function(self)
        if answerRoleCheck(mod) then self:Hide() end
    end, function()
        return mod:IsEnabled() and mod:Get("autoRoleCheck") == true
    end)
end

-- =========================================================================
--  Minuteur des fenêtres de file d'attente
-- =========================================================================

--- Durée d'une proposition de groupe, en secondes.
---
--- Le client publie l'échéance des invitations de champ de bataille
--- (`GetBattlefieldPortExpiration`) mais **rien** pour une proposition de
--- donjon : ni fonction, ni constante. Ce nombre est donc le délai que le client
--- applique, mesuré et non déduit — voir `dev/docs/API_NOTES.md`. S'il change un
--- jour, c'est ici et nulle part ailleurs.
local PROPOSAL_SECONDS = 40

--- fenêtre du client -> décompte qu'on lui a posé
local countdowns = {}

--- Cadre sur lequel poser le décompte : l'**icône du rôle** quand la fenêtre en
--- porte une, la fenêtre elle-même sinon.
---
--- C'est le seul repère qui tienne dans les deux cas. Le centre de la fenêtre
--- tombe entre le nom de l'instance et l'icône, donc sur rien ; l'icône, elle,
--- est un disque vide au milieu, exactement de la taille d'un nombre.
---
--- Deux chemins, du plus général au plus ancien, et aucun n'est un pari : un
--- champ absent ou un nom inconnu rend `nil`, et on retombe sur la fenêtre.
---@param dialog table
---@return table
local function countdownAnchor(dialog)
    local icon = dialog.roleIcon

    if not icon then
        local name = dialog.GetName and dialog:GetName()
        icon = name and _G[name .. "RoleIcon"] or nil
    end

    if icon and icon.GetCenter and icon:GetCenter() then return icon end
    return dialog
end

---@param parent table
---@param source fun(): number|nil
---@param total number  durée pleine, qui donne sa couleur au décompte
local function watch(parent, source, total)
    local countdown = countdowns[parent]
    if not countdown then
        countdown = W.Countdown(parent)
        if not countdown then return end
        countdown:SetPoint("CENTER", countdownAnchor(parent), "CENTER",
            0, T.SIZE.COUNTDOWN_Y)
        countdowns[parent] = countdown
    end
    countdown:Watch(source, total)
end

local function stopCountdowns()
    for _, countdown in pairs(countdowns) do
        countdown:Stop()
    end
end

---@param mod table
local function watchProposal(mod)
    if not mod:Get("queueTimer") then return end

    -- Le cadre qui s'affiche est le **dialogue**, pas le popup qui le porte :
    -- coiffer le second poserait le décompte sur un conteneur invisible.
    local dialog = LFGDungeonReadyDialog or LFGDungeonReadyPopup
    if not dialog then return end

    local total    = PROPOSAL_SECONDS
    local deadline = GetTime() + total

    watch(dialog, function()
        local remaining = deadline - GetTime()
        if remaining <= 0 then return nil end
        return remaining
    end, total)
end

--- Secondes restantes pour accepter une entrée en champ de bataille ou en
--- arène, prises sur le client lui-même.
---@return number|nil
local function portExpiration()
    if not (GetMaxBattlefieldID and GetBattlefieldStatus and GetBattlefieldPortExpiration) then
        return nil
    end
    for i = 1, GetMaxBattlefieldID() do
        if GetBattlefieldStatus(i) == "confirm" then
            local remaining = GetBattlefieldPortExpiration(i)
            if remaining and remaining > 0 then return remaining end
        end
    end
    return nil
end

---@param mod table
local function watchBattlefield(mod)
    if not mod:Get("queueTimer") then return end

    local dialog = PVPReadyDialog
    if not (dialog and dialog:IsShown()) then return end

    -- La durée pleine est ce qui reste au moment où la fenêtre s'ouvre : le
    -- client ne publie que le temps restant, jamais le délai qu'il a accordé.
    local remaining = portExpiration()
    if not remaining then return end

    watch(dialog, portExpiration, remaining)
end

---@return table|nil
local function module()
    return BUI.Modules:Get(MODULE)
end

--- Le module est-il allumé ? Garde des deux hooks.
local function live()
    local mod = module()
    return mod ~= nil and mod:IsEnabled()
end

-- =========================================================================
--  Les trois visages de la recherche
-- =========================================================================
-- Le client range chaque onglet de la recherche personnalisée sous un numéro
-- de catégorie. Ces trois-là sont les seuls que le panneau connaisse : les
-- autres (quêtes, gouffres, champs de bataille cotés…) ne montrent pas de
-- panneau du tout.
--
-- Les numéros sont ceux du moteur, stables d'une extension à l'autre —
-- identifiés en lisant Premade Groups Filter, vérifiés en jeu. Une catégorie
-- inconnue ne casse rien : elle n'a pas de contexte, donc pas de panneau.
local CATEGORY = {
    DUNGEON = 2,
    RAID    = 3,
    ARENA   = 4,
}

---@param categoryID number|nil
---@return string|nil
local function contextOf(categoryID)
    if categoryID == CATEGORY.DUNGEON then return "dungeon" end
    if categoryID == CATEGORY.RAID    then return "raid"   end
    if categoryID == CATEGORY.ARENA   then return "arena"  end
end

--- La catégorie ouverte en ce moment, posée par le hook de catégorie.
local currentCategory

-- =========================================================================
--  Ce qu'on sait lire d'un résultat
-- =========================================================================

--- Un nombre lisible, ou rien. Les valeurs de la recherche de groupe peuvent
--- devenir secrètes au gré des patchs : ce qu'on ne sait pas lire ne se
--- filtre pas — on montre, on ne cache jamais sur un doute.
---@param value any
---@return number|nil
local function num(value)
    if type(value) ~= "number" then return nil end
    if U.IsSecret(value) then return nil end
    return value
end

--- L'activité d'un résultat, demandée au client.
---@param resultID number
---@return table|nil searchInfo, table|nil activityInfo
local function resultInfo(resultID)
    if not (C_LFGList and C_LFGList.GetSearchResultInfo) then return nil end

    local ok, info = pcall(C_LFGList.GetSearchResultInfo, resultID)
    if not (ok and type(info) == "table") then return nil end

    -- Le champ a changé de forme : `activityID` hier, `activityIDs` (liste)
    -- aujourd'hui. On prend ce que ce client-ci donne.
    local activityID = info.activityID
    if not activityID and type(info.activityIDs) == "table" then
        activityID = info.activityIDs[1]
    end

    local act
    if activityID and C_LFGList.GetActivityInfoTable then
        local okAct, value = pcall(C_LFGList.GetActivityInfoTable, activityID)
        if okAct and type(value) == "table" then act = value end
    end

    return info, act
end

--- Les identifiants de difficulté du moteur, pour les activités qui en
--- portent un. Ils sont stables depuis des extensions — ce sont ceux de
--- `GetDifficultyInfo` — et couvrent donjons, raids d'aujourd'hui et raids
--- d'hier. Ce n'est pas une table d'activités à entretenir : une dizaine de
--- constantes du moteur, pas sept cents lignes de saison.
local DIFF_BY_ID = {
    [1]  = "normal", [2]  = "heroic",   -- donjons
    [23] = "mythic", [8]  = "mplus",
    [14] = "normal", [15] = "heroic", [16] = "mythic",  -- raids
    [17] = "normal",                                    -- outils de raid
    [3]  = "normal", [4]  = "normal",                   -- anciens raids 10/25
    [5]  = "heroic", [6]  = "heroic",
    [9]  = "normal",                                    -- raids 40
}

--- Ce nom contient-il ce mot, sans regarder la casse ? Les noms d'activités
--- français écrivent « héroïque » en minuscules là où `PLAYER_DIFFICULTY2`
--- dit « Héroïque » : la comparaison directe ratait tout.
---@param name any
---@param word any
---@return boolean
local function nameHas(name, word)
    if type(name) ~= "string" or type(word) ~= "string" or word == "" then
        return false
    end
    return name:lower():find(word:lower(), 1, true) ~= nil
end

--- La difficulté d'une activité, du plus sûr au moins sûr :
---
---  1. les **drapeaux** de l'activité — mythique + et mythique, quand le
---     client les pose (les donjons les portent, les raids pas toujours) ;
---  2. son **identifiant de difficulté**, quand ce client-ci l'expose ;
---  3. les **mots du client** (`PLAYER_DIFFICULTY*`, localisés comme les noms
---     d'activités) cherchés dans le nom complet puis le court, sans la casse.
---
--- Tout le reste est normal — un groupe qu'on ne sait pas classer se range
--- avec les normaux plutôt que de disparaître dans une case que rien ne coche.
---@param act table
---@return string  "normal" | "heroic" | "mythic" | "mplus"
local function difficultyOf(act)
    if act.isMythicPlusActivity then return "mplus" end
    if act.isMythicActivity     then return "mythic" end

    local diffID = num(act.difficultyID)
    if diffID and DIFF_BY_ID[diffID] then
        return DIFF_BY_ID[diffID]
    end

    -- Mythique + se cherche avant mythique : son nom contient l'autre.
    local full, short = act.fullName, act.shortName
    if nameHas(full, PLAYER_DIFFICULTY_MYTHIC_PLUS)
       or nameHas(short, PLAYER_DIFFICULTY_MYTHIC_PLUS) then return "mplus" end
    if nameHas(full, PLAYER_DIFFICULTY6)
       or nameHas(short, PLAYER_DIFFICULTY6) then return "mythic" end
    if nameHas(full, PLAYER_DIFFICULTY2)
       or nameHas(short, PLAYER_DIFFICULTY2) then return "heroic" end

    return "normal"
end

--- La tranche d'arène d'une activité : la taille du groupe la dit — deux
--- joueurs pour le 2v2, trois pour le 3v3. Une autre taille n'est aucune des
--- deux, et passe tous les filtres.
---@param act table
---@return string|nil  "b2" | "b3"
local function bracketOf(act)
    local size = num(act.maxNumPlayers)
    if size == 2 then return "b2" end
    if size == 3 then return "b3" end
end

-- =========================================================================
--  Les filtres du personnage
-- =========================================================================
-- Des données, pas des réglages : ils vivent dans le SavedVariables du
-- personnage (`CharData`), comme la note d'inscription du module voisin. Une
-- table par contexte, et l'absence de champ est l'état neutre — une case
-- absente est cochée, une borne absente ne borne pas. Réinitialiser, c'est
-- vider la table.

---@param mod table
---@param ctx string
---@return table
local function ctxStore(mod, ctx)
    local data = mod:CharData()
    data.filters = data.filters or {}
    local store = data.filters[ctx]
    if not store then
        store = {}
        data.filters[ctx] = store
    end
    return store
end

---@param value number|nil
---@param minV number|nil
---@param maxV number|nil
---@return boolean
local function within(value, minV, maxV)
    if value == nil then return true end
    if minV and value < minV then return false end
    if maxV and value > maxV then return false end
    return true
end

--- Les statuts de candidature qui veulent dire « pas avec eux » : le refus du
--- chef, et le refus parce que le groupe s'est rempli avant de répondre. Le
--- délai expiré n'y est pas — personne n'a dit non.
local DECLINED = {
    declined          = true,
    declined_full     = true,
    declined_delisted = true,
}

--- Ce groupe a-t-il déjà refusé notre candidature ? Le client s'en souvient
--- tant que la candidature vit ; quand il l'oublie, le groupe réapparaît, et
--- c'est très bien : on cache un refus, pas une rancune.
---@param resultID number
---@return boolean
local function isDeclined(resultID)
    if not (C_LFGList and C_LFGList.GetApplicationInfo) then return false end

    local ok, _, appStatus = pcall(C_LFGList.GetApplicationInfo, resultID)
    if not (ok and type(appStatus) == "string") then return false end
    return DECLINED[appStatus] == true
end

--- Ce résultat passe-t-il les filtres ? `store` peut manquer : hors des trois
--- onglets connus, seul le masquage des refus s'applique.
---@param store table|nil
---@param ctx string|nil
---@param resultID number
---@param hideDeclined boolean
---@return boolean
local function passes(store, ctx, resultID, hideDeclined)
    if hideDeclined and isDeclined(resultID) then return false end
    if not store then return true end

    local info, act = resultInfo(resultID)
    if not info then return true end

    if act then
        if ctx == "arena" then
            local bracket = bracketOf(act)
            if bracket and store.show and store.show[bracket] == false then
                return false
            end
        else
            local diff = difficultyOf(act)
            if store.show and store.show[diff] == false then return false end

            local gid = act.groupFinderActivityGroupID
            if gid and store.groups and store.groups[gid] == false then
                return false
            end
        end
    end

    if C_LFGList.GetSearchResultMemberCounts then
        local ok, counts = pcall(C_LFGList.GetSearchResultMemberCounts, resultID)
        if ok and type(counts) == "table" then
            local dps = num(counts.DAMAGER)
            -- Les inscrits sans rôle comptent avec les DPS : c'est ce que le
            -- client affiche, et un filtre qui compte autrement que l'écran
            -- ment.
            local noRole = num(counts.NOROLE)
            if dps and noRole then dps = dps + noRole end

            if not within(num(counts.TANK),   store.tanksMin, store.tanksMax) then return false end
            if not within(num(counts.HEALER), store.healsMin, store.healsMax) then return false end
            if not within(dps,                store.dpsMin,   store.dpsMax)   then return false end
        end
    end

    if ctx ~= "arena" then
        if not within(num(info.numMembers), store.sizeMin, store.sizeMax) then
            return false
        end
    end

    return true
end

-- =========================================================================
--  La liste intacte, et sa réécriture
-- =========================================================================

--- Les résultats tels que le client les a relevés, avant nous. C'est elle
--- qu'on refiltre quand une case change, et elle qu'on repose en éteignant.
--- Une table de travail au niveau du fichier, jamais recréée (règle 7).
local pristine = {}

--- Sommes-nous en train de demander le réaffichage ? Le hook guette la mise à
--- jour de la liste : sans ce drapeau, notre propre demande le relancerait.
local applying = false

---@return table|nil
local function searchPanel()
    return LFGListFrame and LFGListFrame.SearchPanel
end

--- Réécrit la liste du client d'après la liste intacte et les filtres, puis
--- lui demande de réafficher.
---@param mod table
local function applyFilters(mod)
    local sp = searchPanel()
    if not (sp and type(sp.results) == "table") then return end

    -- Le panneau ne connaît que trois onglets, mais le masquage des refus
    -- vaut partout : hors contexte, il est le seul filtre qui s'applique.
    local ctx          = contextOf(currentCategory)
    local hideDeclined = mod:Get("hideDeclined") and true or false
    if not ctx and not hideDeclined then return end

    local store   = ctx and mod:Get("filterPanel") and ctxStore(mod, ctx) or nil
    local results = sp.results

    local n = 0
    for i = 1, #pristine do
        local id = pristine[i]
        if passes(store, ctx, id, hideDeclined) then
            n = n + 1
            results[n] = id
        end
    end
    for i = #results, n + 1, -1 do
        results[i] = nil
    end

    -- Le compteur du client dit combien de lignes il montre : on vient d'en
    -- changer le nombre, on le lui dit.
    sp.totalResults = n

    if type(LFGListSearchPanel_UpdateResults) == "function" then
        applying = true
        pcall(LFGListSearchPanel_UpdateResults, sp)
        applying = false
    end
end

--- Repose la liste intacte à l'écran — le geste d'extinction.
local function restoreResults()
    local sp = searchPanel()
    if not (sp and type(sp.results) == "table") then return end
    if #pristine == 0 then return end

    local results = sp.results
    for i = 1, #pristine do
        results[i] = pristine[i]
    end
    for i = #results, #pristine + 1, -1 do
        results[i] = nil
    end
    sp.totalResults = #pristine

    if type(LFGListSearchPanel_UpdateResults) == "function" then
        applying = true
        pcall(LFGListSearchPanel_UpdateResults, sp)
        applying = false
    end

    wipe(pristine)
end

--- Refiltre depuis la liste intacte — quand une case du panneau change.
---@param mod table
local function refilter(mod)
    if #pristine == 0 then return end
    applyFilters(mod)
end

-- =========================================================================
--  Le panneau
-- =========================================================================

local panel, stowButton

--- Cases « montré / caché » d'un contexte. L'absence vaut coché : l'état
--- neutre ne s'écrit pas sur le disque.
---@param ctx string
---@param key string
local function showGetter(ctx, key)
    return function()
        local mod = module()
        if not mod then return true end
        local store = ctxStore(mod, ctx)
        return not (store.show and store.show[key] == false)
    end
end

---@param ctx string
---@param key string
local function showSetter(ctx, key)
    return function(value)
        local mod = module()
        if not mod then return end
        local store = ctxStore(mod, ctx)
        store.show = store.show or {}
        -- Deux écritures, pas un `value and nil or false` : cette expression
        -- vaut toujours `false` en Lua — `nil` n'arrête pas le `or` —, et
        -- c'est le bug qui rendait une case impossible à recocher.
        if value then
            store.show[key] = nil
        else
            store.show[key] = false
        end
        refilter(mod)
    end
end

--- Bornes d'un contexte : `nil` est « sans limite ».
---@param ctx string
---@param field string
local function boundGetter(ctx, field)
    return function()
        local mod = module()
        return mod and ctxStore(mod, ctx)[field]
    end
end

---@param ctx string
---@param field string
local function boundSetter(ctx, field)
    return function(value)
        local mod = module()
        if not mod then return end
        ctxStore(mod, ctx)[field] = value
        refilter(mod)
    end
end

---@param ctx string
---@param text string
---@param prefix string
---@return table
local function rangeDesc(ctx, text, prefix)
    return {
        type    = "range",
        text    = text,
        tooltip = L["Min max tip"],
        getMin  = boundGetter(ctx, prefix .. "Min"),
        setMin  = boundSetter(ctx, prefix .. "Min"),
        getMax  = boundGetter(ctx, prefix .. "Max"),
        setMax  = boundSetter(ctx, prefix .. "Max"),
    }
end

---@param ctx string
---@param key string
---@param text string
---@return table
local function showDesc(ctx, key, text)
    return {
        type    = "toggle",
        text    = text,
        tooltip = L["Show filter tip"],
        get     = showGetter(ctx, key),
        set     = showSetter(ctx, key),
    }
end

--- Les lignes d'un contexte. Les intitulés de difficulté sont ceux du client
--- (`PLAYER_DIFFICULTY*`) : ils suivent sa langue et ses renommages tout
--- seuls ; les nôtres ne servent que s'il ne les a plus.
---@param ctx string
---@return table[]
local function buildDescriptors(ctx)
    local rows = {}
    local function add(row) rows[#rows + 1] = row end

    if ctx == "arena" then
        add({ type = "header", text = L["Arena bracket"] })
        add(showDesc(ctx, "b2", L["2v2"]))
        add(showDesc(ctx, "b3", L["3v3"]))

        add({ type = "header", text = L["Roles"] })
        add(rangeDesc(ctx, L["Healers"], "heals"))
        add(rangeDesc(ctx, L["DPS"],     "dps"))
        return rows
    end

    add({ type = "header", text = L["Difficulty"] })
    add(showDesc(ctx, "normal", PLAYER_DIFFICULTY1 or L["Normal"]))
    add(showDesc(ctx, "heroic", PLAYER_DIFFICULTY2 or L["Heroic"]))
    add(showDesc(ctx, "mythic", PLAYER_DIFFICULTY6 or L["Mythic"]))
    if ctx == "dungeon" then
        add(showDesc(ctx, "mplus", PLAYER_DIFFICULTY_MYTHIC_PLUS or L["Mythic+"]))
    end

    add({ type = "header", text = L["Roles"] })
    add(rangeDesc(ctx, L["Tanks"],      "tanks"))
    add(rangeDesc(ctx, L["Healers"],    "heals"))
    add(rangeDesc(ctx, L["DPS"],        "dps"))
    add(rangeDesc(ctx, L["Group size"], "size"))

    -- L'en-tête de la liste voyage avec elle : le widget la range dans sa
    -- colonne de droite, pas dans le fil des sections.
    add({ type = "list",
          text = (ctx == "raid") and (RAIDS or L["Raids"])
                                  or (DUNGEONS or L["Dungeons"]) })
    return rows
end

-- =========================================================================
--  La liste des instances : déduite des résultats, pas d'une table
-- =========================================================================
-- On liste les groupes d'activités **vus dans la recherche courante** : c'est
-- toujours la saison en cours, dans la langue du client, sans une ligne de
-- données à maintenir. Tables de travail au niveau du fichier (règle 7).

local seenGroups  = {}
local groupOrder  = {}
local listEntries = {}

---@param ctx string
local function rebuildListEntries(ctx)
    if not panel then return end

    wipe(seenGroups)
    wipe(groupOrder)

    for i = 1, #pristine do
        local _, act = resultInfo(pristine[i])
        local gid = act and act.groupFinderActivityGroupID
        if gid and not seenGroups[gid] and C_LFGList.GetActivityGroupInfo then
            local ok, name = pcall(C_LFGList.GetActivityGroupInfo, gid)
            if ok and type(name) == "string" and name ~= "" then
                seenGroups[gid] = name
                groupOrder[#groupOrder + 1] = gid
            end
        end
    end

    table.sort(groupOrder, function(a, b)
        return seenGroups[a] < seenGroups[b]
    end)

    for i = 1, #groupOrder do
        local gid   = groupOrder[i]
        local entry = listEntries[i]
        if not entry then
            entry = {}
            listEntries[i] = entry
        end
        entry.text    = seenGroups[gid]
        entry.tooltip = L["Show filter tip"]
        entry.get = function()
            local m = module()
            if not m then return true end
            local store = ctxStore(m, ctx)
            return not (store.groups and store.groups[gid] == false)
        end
        entry.set = function(value)
            local m = module()
            if not m then return end
            local store = ctxStore(m, ctx)
            store.groups = store.groups or {}
            -- Même piège que `showSetter` : deux écritures, pas d'expression.
            if value then
                store.groups[gid] = nil
            else
                store.groups[gid] = false
            end
            refilter(m)
        end
    end
    for i = #listEntries, #groupOrder + 1, -1 do
        listEntries[i] = nil
    end

    panel:SetListEntries(listEntries)
end

--- Relance la recherche en cours — les annonces vieillissent en quelques
--- minutes, et le client n'actualise rien de lui-même.
---
--- Son bouton d'abord : il connaît son propre délai de grâce entre deux
--- recherches et refuse le clic pendant qu'il court. À défaut, sa fonction.
local function doSearch()
    local sp = searchPanel()
    if not sp then return end

    local button = sp.RefreshButton
    if button and button.Click then
        button:Click()
        return
    end
    if type(LFGListSearchPanel_DoSearch) == "function" then
        pcall(LFGListSearchPanel_DoSearch, sp)
    end
end

--- Montre le panneau si le contexte en veut un, le cache sinon. Le bouton de
--- rangement suit le même contexte, mais reste visible panneau rangé : c'est
--- lui qui permet de le ressortir.
---@param mod table
local function updatePanel(mod)
    local ctx = contextOf(currentCategory)

    if not (ctx and mod:Get("filterPanel")) then
        if panel then panel:Hide() end
        if stowButton then stowButton:Hide() end
        return
    end

    local sp = searchPanel()
    if not (sp and PVEFrame) then return end

    if not stowButton then
        stowButton = W.GroupFilterStowButton({
            parent    = sp,
            -- Contre le bouton d'actualisation du client quand il existe :
            -- les petits outils de la recherche se rangent sur la même ligne.
            -- Absent, le widget retombe sur le coin haut-droit du parent.
            anchor    = sp.RefreshButton,
            isStowed  = function()
                local m = module()
                return (m and m:Get("filterStowed")) and true or false
            end,
            onToggle  = function()
                local m = module()
                if m then m:Set("filterStowed", not m:Get("filterStowed")) end
            end,
            stowTitle = L["Stow filter panel"],
            showTitle = L["Show filter panel"],
            tooltip   = L["Stow filter panel tip"],
        })
    end
    stowButton:Refresh()
    stowButton:Show()

    -- Rangé : les filtres continuent d'agir, seul le panneau se tait.
    if mod:Get("filterStowed") then
        if panel then panel:Hide() end
        return
    end

    if not panel then
        panel = W.GroupFilterPanel({
            parent        = sp,
            anchor        = PVEFrame,

            -- L'écart du panneau à sa place par défaut. Réglages sans
            -- contrôle : ils s'écrivent en le faisant glisser, comme l'angle
            -- des boutons de minicarte.
            getOffset     = function()
                local m = module()
                if not m then return 0, 0 end
                return m:Get("filterPanelX") or 0, m:Get("filterPanelY") or 0
            end,
            setOffset     = function(x, y)
                local m = module()
                if not m then return end
                m:Set("filterPanelX", U.Round(x, 0))
                m:Set("filterPanelY", U.Round(y, 0))
            end,

            title         = L["Filters"],
            resetLabel    = L["Reset"],
            resetTooltip  = L["Reset filters tip"],
            onReset       = function()
                local m = module()
                if not m then return end
                local context = contextOf(currentCategory)
                if not context then return end
                wipe(ctxStore(m, context))
                refilter(m)
            end,

            searchLabel   = L["Search"],
            searchTooltip = L["Search tip"],
            onSearch      = doSearch,

            -- Le masquage des refus vit dans le panneau — c'est en triant des
            -- annonces qu'on pense à lui — mais c'est un réglage du module :
            -- une fois coché, il agit dans tous les onglets.
            footerToggle  = {
                text    = L["Hide declined groups"],
                tooltip = L["Hide declined groups tip"],
                get     = function()
                    local m = module()
                    return (m and m:Get("hideDeclined")) and true or false
                end,
                set     = function(value)
                    local m = module()
                    if m then m:Set("hideDeclined", value and true or false) end
                end,
            },
        })
    end

    panel:ShowPage(ctx, function() return buildDescriptors(ctx) end)
    panel:Show()
    rebuildListEntries(ctx)
end

-- =========================================================================
--  Les deux hooks
-- =========================================================================

--- Le client vient de reconstruire sa liste de résultats : on la relève, on
--- filtre, on réaffiche. C'est le seul endroit où la liste intacte se remplit.
---@param sp table
local function onResultList(sp)
    if applying then return end

    local mod = module()
    if not (mod and (mod:Get("filterPanel") or mod:Get("hideDeclined"))) then
        return
    end
    if not (sp and type(sp.results) == "table") then return end

    wipe(pristine)
    for i = 1, #sp.results do
        pristine[i] = sp.results[i]
    end

    applyFilters(mod)

    local ctx = contextOf(currentCategory)
    if ctx and panel and panel:IsShown() then
        rebuildListEntries(ctx)
    end
end

--- Le joueur vient de changer d'onglet : le panneau change de visage, et la
--- liste intacte ne vaut plus rien — c'était celle d'une autre catégorie.
---@param categoryID number
local function onSetCategory(_, categoryID)
    currentCategory = categoryID
    wipe(pristine)

    local mod = module()
    if mod then updatePanel(mod) end
end

--- Pose les deux hooks — une fois, et sous garde. Rappelée sans risque : le
--- garde-fou de `U.GuardedHook` ne pose jamais deux fois le même.
local function hookSearch()
    if type(LFGListSearchPanel_UpdateResultList) == "function" then
        U.GuardedHook("LFGListSearchPanel_UpdateResultList", onResultList, live)
    end
    if type(LFGListSearchPanel_SetCategory) == "function" then
        U.GuardedHook("LFGListSearchPanel_SetCategory", onSetCategory, live)
    end
end

-- =========================================================================
--  Déclaration du module
-- =========================================================================

BUI:RegisterModule(MODULE, {
    title    = L["Group finder"],
    category = "QoL",
    order    = 60,

    defaults = {
        keepSignupNote = false,
        autoRoleCheck  = false,
        queueTimer     = false,
        filterPanel    = false,

        -- Écart du panneau de filtres à sa place par défaut, en pixels.
        -- Réglages sans contrôle : ils s'écrivent en faisant glisser le
        -- panneau — même statut que l'angle du bouton de téléportation.
        filterPanelX   = 0,
        filterPanelY   = 0,

        -- Panneau replié derrière son bouton de rangement. Sans contrôle lui
        -- aussi : c'est le petit bouton posé sur la recherche qui l'écrit.
        filterStowed   = false,

        -- Sans ligne dans la page : sa case vit au pied du panneau de filtres,
        -- où l'on est quand on pense à lui. Un réglage quand même — coché, il
        -- agit dans tous les onglets, panneau visible ou non.
        hideDeclined   = false,
    },

    options = {
        { type = "header", text = L["Signing up"] },
        {
            type    = "toggle",
            key     = "keepSignupNote",
            text    = L["Keep signup note"],
            tooltip = L["Keep signup note tip"],
        },
        {
            type    = "toggle",
            key     = "autoRoleCheck",
            text    = L["Auto role check"],
            tooltip = L["Auto role check tip"],
        },

        { type = "header", text = L["Queues"] },
        {
            type    = "toggle",
            key     = "queueTimer",
            text    = L["Queue popup timer"],
            tooltip = L["Queue popup timer tip"],
        },

        -- Le même intitulé que la page : la section parle de la recherche
        -- elle-même, quand les deux premières parlent de ce qui l'entoure.
        { type = "header", text = L["Group finder"] },
        {
            type    = "toggle",
            key     = "filterPanel",
            text    = L["Premade filter panel"],
            tooltip = L["Premade filter panel tip"],
        },
    },

    OnEnable = function(self)
        -- Le drapeau est remis à plat ici : éteindre le module révoque ses
        -- abonnements, donc peut-être le `LFG_ROLE_CHECK_HIDE` qui l'aurait
        -- rendu. Rallumer sur un drapeau resté levé ferait cacher la fenêtre
        -- suivante sans y avoir répondu, ce qui est exactement ce qu'il faut
        -- éviter.
        roleCheckAnswered = false

        hookSignupNote(self)
        hookRoleCheck(self)
        hookSearch()

        -- La fenêtre d'inscription est chargée à la demande : elle peut
        -- n'exister qu'une fois la recherche de groupe ouverte. On retente une
        -- fois la rafale retombée ; `U.GuardedScript` ne pose jamais deux fois
        -- le même script.
        local settle = U.Debounce(T.TIMING.CHAT_SETTLE, function() hookSignupNote(self) end)

        -- La fenêtre de rôles, elle, se raccroche **sans temporisation**. Elle
        -- vit dans un module du client chargé à la demande, et rien n'interdit
        -- qu'une demande de rôles arrive dans la foulée de ce chargement : le
        -- cinquième de seconde qui suffit largement à la fenêtre d'inscription
        -- serait ici le seul moment où l'on ne peut pas la retenir. Le crochet ne
        -- coûte que deux lectures de globale, et `U.GuardedScript` ne le pose
        -- jamais deux fois.
        self:RegisterEvent("ADDON_LOADED", function()
            hookRoleCheck(self)
            hookSearch()
            settle()
        end)
        self:RegisterEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED", settle)
        self:RegisterEvent("LFG_LIST_AVAILABILITY_UPDATE",     settle)

        self:RegisterEvent("LFG_ROLE_CHECK_SHOW", function() answerRoleCheck(self) end)

        -- La demande suivante est une autre demande : le drapeau ne vaut que pour
        -- celle en cours.
        self:RegisterEvent("LFG_ROLE_CHECK_HIDE", function() roleCheckAnswered = false end)

        self:RegisterEvent("LFG_PROPOSAL_SHOW",         function() watchProposal(self) end)
        self:RegisterEvent("UPDATE_BATTLEFIELD_STATUS", function() watchBattlefield(self) end)

        -- Un refus arrive **après** l'affichage de la liste : c'est son propre
        -- événement, et c'est lui qui doit faire disparaître le groupe — pas
        -- la prochaine recherche.
        self:RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED", function()
            if self:Get("hideDeclined") then refilter(self) end
        end)

        -- Le module s'allume peut-être devant une recherche déjà ouverte : on
        -- relève ce qui est à l'écran plutôt que d'attendre la prochaine.
        local sp = searchPanel()
        if sp then
            currentCategory = sp.categoryID
            updatePanel(self)
            if sp:IsShown() then onResultList(sp) end
        end
    end,

    -- Les deux scripts d'inscription passent par `U.GuardedScript` et deviennent
    -- inertes d'eux-mêmes ; les abonnements sont révoqués par le core (règle 6).
    -- Restent ce qui est posé à l'écran : les décomptes s'arrêtent, le panneau
    -- se cache, et la liste de résultats redevient celle du client.
    OnDisable = function()
        stopCountdowns()
        if panel then panel:Hide() end
        if stowButton then stowButton:Hide() end
        restoreResults()
    end,

    OnSettingChanged = function(self, key)
        -- Décocher le minuteur pendant qu'une fenêtre de file est ouverte doit
        -- le faire disparaître tout de suite, pas à la fenêtre suivante.
        if key == nil or key == "queueTimer" then
            if not self:Get("queueTimer") then stopCountdowns() end
        end

        -- Ranger ou ressortir n'éteint rien : les filtres continuent d'agir,
        -- seul le panneau apparaît ou disparaît.
        if key == "filterStowed" then
            updatePanel(self)
            return
        end

        if key == nil or key == "filterPanel" or key == "hideDeclined" then
            local wantsAny = self:Get("filterPanel") or self:Get("hideDeclined")

            -- `updatePanel` sait aussi cacher : panneau et bouton de rangement
            -- s'éteignent par le même chemin qui les allume.
            updatePanel(self)

            if wantsAny then
                -- Une liste est peut-être déjà à l'écran : elle se relève et
                -- se filtre tout de suite, pas à la prochaine recherche. Si
                -- elle était déjà relevée, on refiltre — un réglage vient de
                -- changer ce qui doit se voir.
                local sp = searchPanel()
                if sp and sp:IsShown() and #pristine == 0 then
                    onResultList(sp)
                else
                    refilter(self)
                end
            else
                restoreResults()
            end
        end
    end,
})
