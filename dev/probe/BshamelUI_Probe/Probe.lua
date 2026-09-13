-- =========================================================================
--  Bshamel UI — sonde de compatibilité
--
--  Cet addon ne fait rien pour un joueur. Il pose au client, une par une, les
--  questions que Bshamel UI lui posera : cette fonction existe-t-elle, cet
--  événement se laisse-t-il écouter, ce CVar est-il connu, ce template se
--  monte-t-il, cet atlas répond-il.
--
--  La liste vient de `Data.lua`, engendré depuis le dépôt : rien n'est deviné,
--  rien n'est oublié. Le résultat est écrit dans `BshamelUIProbeDB`, donc
--  lisible dans WTF après un `/reload`, et résumé en jeu par `/buiprobe`.
--
--  Le verdict utile est par fichier : « Modules/Quest.lua — 100 % » veut dire
--  que ce module est portable tel quel sur ce client-là.
--
--  Rien de ce fichier ne part chez un joueur : il vit sous `dev/`, que
--  `.pkgmeta` exclut du zip, `.luacheckrc` du lint et `check-design.sh` de ses
--  garde-fous. Les règles de CLAUDE.md sur le dessin ne s'y appliquent pas.
-- =========================================================================

local ADDON, P = ...

local RESULT = {}   -- [demande] = true / false
local KIND   = {}   -- [demande] = ce que le client a répondu
local FILES  = {}   -- [fichier du dépôt] = { total, present, missing, score }

local probeFrame = CreateFrame("Frame")
local scratch                        -- cadre à tout faire, monté à la demande

-- -------------------------------------------------------------------------
--  Les cinq façons de poser la question
-- -------------------------------------------------------------------------

--- Résout `Truc` ou `C_Machin.Truc` dans l'espace global.
local function resolve(name)
    local dot = string.find(name, ".", 1, true)
    if not dot then return _G[name] end
    local ns = _G[string.sub(name, 1, dot - 1)]
    if type(ns) ~= "table" then return nil end
    return ns[string.sub(name, dot + 1)]
end

local function testSymbol(name)
    local value = resolve(name)
    if value == nil then return false end
    return true, type(value)
end

-- Un nom d'événement inconnu fait lever `RegisterEvent`. C'est le seul test
-- possible, et il est exact : le client répond sur ce qu'il connaît vraiment.
local function testEvent(name)
    local ok = pcall(probeFrame.RegisterEvent, probeFrame, name)
    if ok then pcall(probeFrame.UnregisterEvent, probeFrame, name) end
    return ok, ok and "event" or nil
end

local function testCVar(name)
    local info
    if C_CVar and C_CVar.GetCVarInfo then
        info = C_CVar.GetCVarInfo(name)
    elseif _G.GetCVarInfo then
        info = _G.GetCVarInfo(name)
    end
    if info ~= nil then return true, "cvar" end

    -- Client sans introspection : la lecture suffit, elle rend `nil` sur un nom
    -- que le client ne connaît pas.
    local get = (C_CVar and C_CVar.GetCVar) or _G.GetCVar
    if get then
        local ok, value = pcall(get, name)
        if ok and value ~= nil then return true, "cvar=" .. tostring(value) end
    end
    return false
end

-- Les types de cadre à essayer quand il faut monter le template pour savoir.
-- Un template de bouton refuse de se monter en `Frame` : sans cette liste, la
-- moitié de `T.TEMPLATES` serait déclarée absente à tort.
local FRAME_TYPES = { "Frame", "Button", "CheckButton", "Slider", "EditBox",
                      "ScrollFrame", "StatusBar", "Cooldown" }

local function testTemplate(name)
    -- Même chemin que `T.HasTemplate` : on interroge d'abord, on ne monte que
    -- s'il n'y a pas d'autre moyen. Monter un template réveille le code de
    -- Blizzard qui va avec, et ce réveil a déjà coûté un bug à l'addon.
    if C_XMLUtil and C_XMLUtil.GetTemplateInfo then
        local info = C_XMLUtil.GetTemplateInfo(name)
        if info then return true, info.type or "template" end
        return false
    end
    for i = 1, #FRAME_TYPES do
        if pcall(CreateFrame, FRAME_TYPES[i], nil, nil, name) then
            return true, FRAME_TYPES[i]
        end
    end
    return false
end

local function testAtlas(name)
    if C_Texture and C_Texture.GetAtlasInfo then
        return C_Texture.GetAtlasInfo(name) ~= nil, "atlas"
    end
    scratch = scratch or CreateFrame("Frame")
    if not scratch.tex then scratch.tex = scratch:CreateTexture(nil, "BACKGROUND") end
    local tex = scratch.tex
    if not pcall(tex.SetAtlas, tex, name) then return false end
    if tex.GetAtlas and tex:GetAtlas() ~= name then return false end
    return true, "atlas"
end

--- Aiguillage : le préfixe d'une demande dit comment la poser.
local function evaluate(check)
    local colon = string.find(check, ":", 1, true)
    if not colon then return testSymbol(check) end

    local kind = string.sub(check, 1, colon - 1)
    local name = string.sub(check, colon + 1)
    if kind == "event" then return testEvent(name)    end
    if kind == "cvar"  then return testCVar(name)     end
    if kind == "tmpl"  then return testTemplate(name) end
    if kind == "atlas" then return testAtlas(name)    end
    return false
end

-- -------------------------------------------------------------------------
--  La passe
-- -------------------------------------------------------------------------

--- L'identité du client. Interdite dans l'addon (CLAUDE.md §1), légitime ici :
--- c'est exactement ce qu'on est venu mesurer.
local function clientInfo()
    local version, build, buildDate, tocversion = GetBuildInfo()
    return {
        version    = version,
        build      = build,
        date       = buildDate,
        tocversion = tocversion,
        project    = _G.WOW_PROJECT_ID,
        locale     = GetLocale and GetLocale() or nil,
    }
end

local function run()
    for i = 1, #P.CHECKS do
        local check = P.CHECKS[i]
        local ok, what = evaluate(check)
        RESULT[check] = ok and true or false
        KIND[check]   = what
    end

    for file, list in pairs(P.USERS) do
        local missing = {}
        for i = 1, #list do
            if not RESULT[list[i]] then missing[#missing + 1] = list[i] end
        end
        table.sort(missing)
        local total = #list
        FILES[file] = {
            total   = total,
            present = total - #missing,
            missing = missing,
            score   = total > 0 and math.floor(((total - #missing) / total) * 100 + 0.5) or 100,
        }
    end

    BshamelUIProbeDB = {
        generated = P.GENERATED,
        source    = P.SOURCE,
        probed    = date and date("%Y-%m-%d %H:%M") or nil,
        client    = clientInfo(),
        results   = RESULT,
        kind      = KIND,
        files     = FILES,
    }
end

-- -------------------------------------------------------------------------
--  Le résumé en jeu
-- -------------------------------------------------------------------------
-- Le fichier de WTF est la sortie de référence ; ce résumé existe pour que le
-- triage se fasse sans quitter le jeu.

local function tint(score)
    if score >= 100 then return "|cff40d060" end
    if score >= 80  then return "|cffe0c040" end
    if score >= 40  then return "|cffe08040" end
    return "|cffe05050"
end

local function say(msg) print("|cff00aeef[sonde]|r " .. msg) end

local function sortedFiles(prefix)
    local out = {}
    for file in pairs(FILES) do
        if not prefix or string.sub(file, 1, #prefix) == prefix then
            out[#out + 1] = file
        end
    end
    -- Le pire d'abord : c'est là que se trouve la décision.
    table.sort(out, function(a, b)
        if FILES[a].score ~= FILES[b].score then return FILES[a].score < FILES[b].score end
        return a < b
    end)
    return out
end

local function reportGroup(prefix)
    local files = sortedFiles(prefix)
    for i = 1, #files do
        local file, r = files[i], FILES[files[i]]
        say(string.format("%s %3d %%|r  %s  |cff808080(%d/%d)|r",
            tint(r.score), r.score, file, r.present, r.total))
    end
    return #files
end

--- Les demandes manquantes d'un fichier, en lignes courtes : le chat coupe.
local function reportMissing(pattern)
    local files, shown = sortedFiles(nil), 0
    local needle = string.lower(pattern)
    for i = 1, #files do
        local file, r = files[i], FILES[files[i]]
        if string.find(string.lower(file), needle, 1, true) and #r.missing > 0 then
            shown = shown + 1
            say(string.format("%s%s|r — %d manquant(s) :", tint(r.score), file, #r.missing))
            local line = ""
            for j = 1, #r.missing do
                local piece = r.missing[j]
                if #line + #piece > 100 then print("    " .. line); line = "" end
                line = (line == "") and piece or (line .. ", " .. piece)
            end
            if line ~= "" then print("    " .. line) end
        end
    end
    if shown == 0 then say("rien ne manque a l'endroit demande.") end
end

local function report(arg)
    local c = BshamelUIProbeDB and BshamelUIProbeDB.client
    local absent = 0
    for _, ok in pairs(RESULT) do if not ok then absent = absent + 1 end end

    say(string.format("client %s (build %s, toc %s, projet %s)",
        tostring(c and c.version), tostring(c and c.build),
        tostring(c and c.tocversion), tostring(c and c.project)))
    say(string.format("%d demandes testées, |cffe05050%d absentes|r — liste engendrée le %s (%s).",
        #P.CHECKS, absent, tostring(P.GENERATED), tostring(P.SOURCE)))

    -- Tant que la liste n'a pas été confrontée à retail, elle contient des noms
    -- que le générateur a pris pour des cadres à tort. Ils comptent comme des
    -- absences, donc les scores sont trop sévères — et un score trop sévère sur
    -- un module portable, c'est exactement la décision qu'on ne veut pas prendre.
    if not P.CALIBRATED then
        say("|cffe0c040liste non étalonnée|r — sonder retail d'abord, puis "
            .. "`make-probe.sh --calibrer`. D'ici là, les scores sont trop bas.")
    end

    if arg == "all" or arg == "tout" then
        reportGroup(nil)
    elseif arg and arg ~= "" then
        reportMissing(arg)
    else
        reportGroup("Modules/")
        say("|cff808080socle :|r")
        reportGroup("Core/")
        reportGroup("UI/Theme.lua")
    end

    say("détail complet : /buiprobe tout · manquants d'un fichier : /buiprobe quest")
    say("puis |cffffffff/reload|r, et lire BshamelUIProbeDB dans WTF.")
end

-- -------------------------------------------------------------------------
--  Amorçage
-- -------------------------------------------------------------------------
-- `PLAYER_LOGIN` et pas `ADDON_LOADED` : les CVars et les templates du client ne
-- répondent juste que sur un monde monté.

probeFrame:RegisterEvent("PLAYER_LOGIN")
probeFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    run()
    report(nil)
end)

_G.SLASH_BSHAMELUIPROBE1 = "/buiprobe"
SlashCmdList["BSHAMELUIPROBE"] = function(msg)
    if not BshamelUIProbeDB then run() end
    report(string.lower((string.gsub(msg or "", "^%s*(.-)%s*$", "%1"))))
end
