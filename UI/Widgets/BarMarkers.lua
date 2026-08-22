-- =========================================================================
--  Bshamel UI — UI/Widgets/BarMarkers.lua
--  Des repères posés sur une barre du client.
--
--  Un trait vertical blanc, à un pourcentage choisi de la barre. Rien de plus :
--  ce qu'on veut savoir, c'est « suis-je passé sous la barre que je me suis
--  fixée ? », et un trait répond à ça mieux qu'un nombre — on le franchit, on ne
--  le lit pas.
--
--  **Le widget parle en pourcentage de largeur** — une géométrie, la seule
--  chose qu'un trait connaisse. Un repère voulu « à 30 points » se convertit
--  chez l'appelant, contre le maximum de la barre : `UnitPowerMax` se lit en
--  clair là où la valeur **courante** reste secrète (voir
--  `dev/docs/API_NOTES.md`), et c'est cette lecture-là, une valeur de jeu et
--  non une géométrie, qui n'a pas sa place ici.
--
--  Les traits vivent sur un cadre à nous, posé sur la barre. On ne touche donc
--  ni à ses textures, ni à ses ancrages, ni à rien de ce qui lui appartient : à
--  l'extinction, le cadre se cache et il ne reste aucune trace (règle 6).
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local U    = BUI.Util
local W    = BUI.Widgets

--- Repères posés sur une barre, masqués au départ.
---
--- La barre peut être un cadre du client : on ne lui écrit rien, on se contente
--- de lui accrocher un enfant.
---@param bar table
---@return table|nil  `{ Set = fun(values: number[]), Hide = fun() }`
function W.BarMarkers(bar)
    if type(bar) ~= "table" or type(bar.CreateTexture) ~= "function" then return nil end

    local ok, overlay = pcall(CreateFrame, "Frame", nil, bar)
    if not (ok and overlay) then return nil end

    pcall(overlay.SetAllPoints, overlay, bar)
    pcall(overlay.EnableMouse, overlay, false)

    -- La marque que le mode sombre respecte : ce cadre vit en enfant d'une
    -- barre du client que le moteur assombrit, et sans elle le parcours
    -- teintait nos traits comme de l'habillage — un blanc du thème ressortait
    -- gris (voir `collectFrom` dans `UI/Shade.lua`).
    overlay.buiOwn = true

    -- Au-dessus de l'habillage que le client pose sur ses propres enfants de
    -- barre — au niveau de la barre, le trait passerait dessous — et sous nos
    -- textes (`BAR_TEXT_LEVEL`), qui doivent rester lisibles en le croisant.
    local okLevel, level = pcall(bar.GetFrameLevel, bar)
    if okLevel and type(level) == "number" then
        pcall(overlay.SetFrameLevel, overlay, level + T.SIZE.BAR_MARKER_LEVEL)
    end

    local markers = {}
    --- Les pourcentages voulus, tels que l'appelant les a donnés. Zéro éteint le
    --- repère — c'est ainsi que la glissière s'annule, sans case à cocher de plus
    --- (même motif que le seuil de brillance de la rangée de ressource).
    local wanted = {}

    local lines = {}
    for i = 1, T.SIZE.BAR_MARKER_MAX do
        local line = overlay:CreateTexture(nil, "OVERLAY")
        line:SetTexture(T.TEXTURE.SOLID)
        line:SetVertexColor(T.COLOR.BAR_MARKER:GetRGB())
        line:Hide()
        lines[i] = line
    end

    --- Repose les traits.
    ---
    --- **Seule la largeur se lit**, et elle se garde : une barre du client peut
    --- rendre une mesure secrète, sur laquelle la moindre multiplication lève.
    --- Illisible, on ne pose rien plutôt que de poser au hasard — un repère faux
    --- est pire qu'un repère absent, puisqu'on s'y fie.
    ---
    --- La hauteur, elle, ne se lit **jamais** : le trait s'ancre en haut et en
    --- bas du cadre, ce qui le fait couvrir toute la barre sans qu'on ait à
    --- savoir combien elle mesure.
    local function place()
        local width = overlay:GetWidth()
        if U.IsSecret(width) or type(width) ~= "number" or width <= 0 then
            for i = 1, #lines do lines[i]:Hide() end
            return
        end

        local thickness = T.SIZE.BAR_MARKER_W

        for i = 1, #lines do
            local line = lines[i]
            local pct  = wanted[i]

            if pct and pct > 0 then
                -- Centré sur sa position : un trait posé par son bord gauche
                -- marque un demi-trait plus loin que le nombre annoncé.
                local x = width * (pct / 100) - thickness / 2

                line:ClearAllPoints()
                line:SetPoint("TOP",    overlay, "TOPLEFT",    x, 0)
                line:SetPoint("BOTTOM", overlay, "BOTTOMLEFT", x, 0)
                line:SetWidth(thickness)
                line:Show()
            else
                line:Hide()
            end
        end
    end

    -- La barre change de taille sans rien annoncer — le client la retaille avec
    -- l'affichage de la ressource personnelle. Notre cadre la suit par
    -- `SetAllPoints`, et c'est **son** changement de taille qu'on écoute : rien
    -- à accrocher sur un cadre qui ne nous appartient pas.
    overlay:SetScript("OnSizeChanged", place)

    --- Pose les pourcentages voulus, dans l'ordre. Une entrée nulle ou à zéro
    --- éteint le repère correspondant.
    ---@param values number[]
    function markers.Set(values)
        for i = 1, T.SIZE.BAR_MARKER_MAX do
            wanted[i] = tonumber(values and values[i]) or 0
        end

        overlay:Show()
        place()
    end

    --- Range les repères. Appelable à l'aveugle : c'est ce qui permet à un module
    --- de rendre l'écran tel qu'il l'a trouvé sans savoir ce qu'il avait posé.
    function markers.Hide()
        for i = 1, #lines do lines[i]:Hide() end
        overlay:Hide()
    end

    markers.Hide()
    return markers
end
