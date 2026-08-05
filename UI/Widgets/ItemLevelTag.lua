-- =========================================================================
--  Bshamel UI — UI/Widgets/ItemLevelTag.lua
--  Niveau d'objet posé sur un bouton d'objet du client.
--
--  Sacs, banque, banque de bataillon : les trois interfaces sont différentes,
--  leurs boutons ne le sont pas. Le widget prend un bouton, quel qu'il soit, et
--  y pose un nombre.
--
--  Les étiquettes vivent dans une table **à clés faibles** plutôt que dans un
--  champ posé sur le bouton. Deux raisons, et la seconde est la vraie :
--
--    * les boutons de conteneur sortent d'un pool ; celles de boutons recyclés
--      disparaissent avec eux au lieu de retenir la frame indéfiniment ;
--    * on n'écrit rien sur un cadre du client. Les boutons d'objet portent une
--      chaîne d'exécution sécurisée — c'est par eux qu'on utilise un objet —, et
--      la règle est de ne rien y ajouter qu'on puisse éviter d'y ajouter.
--
--  La table sert aussi d'inventaire : c'est elle qui permet de tout effacer à la
--  désactivation du module sans avoir à retrouver les boutons (CLAUDE.md
--  règle 6).
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local W    = BUI.Widgets

--- bouton -> étiquette. Clés faibles : un bouton oublié par le client l'est
--- aussi par nous.
local tags = setmetatable({}, { __mode = "k" })

--- cadre d'ancrage -> niveau d'objet du personnage. Mêmes clés faibles, et pour
--- la même raison.
local headlines = setmetatable({}, { __mode = "k" })

--- Le niveau d'objet **du personnage**, posé au-dessus d'un emplacement.
---
--- Un seul nombre pour toute la fiche, là où le reste du module en pose seize.
--- Il répond à une autre question : les seize disent laquelle des pièces traîne,
--- celui-ci dit où en est le personnage — c'est le nombre qu'une inscription en
--- donjon regarde, et le client ne l'écrit nulle part sur cette fiche.
---
--- Posé **en tête de fiche**, sous la barre de titre. Il vivait au-dessus des
--- armes, au bas du modèle : la place était libre, mais c'était l'endroit où l'on
--- regarde les deux pièces les plus détaillées de la fiche, et un nombre qui
--- parle du personnage entier s'y lisait comme un troisième nombre d'arme. En
--- tête, il n'est en concurrence avec rien et se trouve là où l'œil arrive.
---@param frame table  la fiche elle-même
---@return table|nil
function W.SheetItemLevel(frame)
    if not (frame and frame.CreateFontString) then return nil end

    local headline = headlines[frame]
    if not headline then
        headline = frame:CreateFontString(nil, "OVERLAY", T.FONT.SLOT_HEADLINE)
        headline:SetJustifyH("CENTER")
        headlines[frame] = headline
    end

    headline:ClearAllPoints()
    headline:SetPoint("TOP", frame, "TOP", 0, -T.SIZE.SHEET_HEADLINE_TOP)

    return headline
end

--- Efface tous les niveaux d'objet de personnage posés.
function W.ClearSheetItemLevels()
    for _, headline in pairs(headlines) do headline:Hide() end
end

--- Étiquette d'un bouton, créée au premier appel.
---@param button table
---@return table|nil
function W.ItemLevelTag(button)
    if not (button and button.CreateFontString) then return nil end

    local tag = tags[button]
    if not tag then
        tag = button:CreateFontString(nil, "OVERLAY", T.FONT.SLOT_BADGE)

        -- Au-dessus de ce que le bouton peint lui-même. Le calque `OVERLAY` ne
        -- suffit pas : le bouton y pose déjà son contour de qualité et sa
        -- surcouche d'icône, et à sous-niveau égal l'ordre de dessin est celui
        -- de la création — donc le leur, puisqu'ils existent avant nous.
        tag:SetDrawLayer("OVERLAY", 7)

        -- En bas à droite. C'est là que le client écrit le nombre
        -- d'exemplaires, et ce n'est pas un conflit : seul l'équipement reçoit
        -- une étiquette, et l'équipement ne s'empile pas — le nombre n'est donc
        -- jamais dessiné sur une case que l'on touche. Le coin haut-gauche, lui,
        -- reste libre pour ce que le client y met déjà.
        tag:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT",
                     -T.SIZE.BAG_TAG_INSET, T.SIZE.BAG_TAG_INSET)
        tags[button] = tag
    end

    return tag
end

--- Efface toutes les étiquettes posées jusqu'ici.
---
--- On les **cache** sans les détruire : une frame ne se détruit pas dans ce jeu,
--- et un `FontString` vide coûte moins qu'un nouveau à la réactivation.
function W.ClearItemLevelTags()
    for _, tag in pairs(tags) do
        tag:Hide()
    end
end
