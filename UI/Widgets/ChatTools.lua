-- =========================================================================
--  Bshamel UI — UI/Widgets/ChatTools.lua
--  Pièces posées sur les cadres de chat du client.
--
--  La règle : **on ajoute, on ne remplace pas**. Le cadre de chat reste celui de
--  Blizzard, avec ses onglets, son arrimage et ses réglages ; ce qu'on lui pose
--  dessus se retire sans laisser de trace (CLAUDE.md règle 6). Rien ici ne cache
--  quoi que ce soit du client.
--
--  Le redimensionnement à l'onglet, lui, ne crée aucune frame : il s'accroche
--  aux scripts de l'onglet du client et vit donc dans `Modules/Chat.lua`.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local T    = BUI.Theme
local W    = BUI.Widgets

-- =========================================================================
--  Bouton de copie
-- =========================================================================

--- Petit bouton posé dans le coin haut-droit d'un cadre de chat.
---
--- Discret au repos, franc au survol : il vit par-dessus le texte que le joueur
--- lit, et ce texte prime sur lui. Il n'est pas invisible pour autant — un
--- bouton qu'on ne découvre qu'en passant la souris au bon endroit n'existe pas.
---
--- Options : `tooltipTitle`, `tooltipText`, `onClick`.
---@param chatFrame table
---@param options table
---@return table button
function W.ChatCopyButton(chatFrame, options)
    local button = CreateFrame("Button", nil, chatFrame)
    button:SetSize(T.SIZE.CHAT_BUTTON, T.SIZE.CHAT_BUTTON)
    button:SetPoint("TOPRIGHT", chatFrame, "TOPRIGHT",
                    -T.SIZE.CHAT_BUTTON_PAD, -T.SIZE.CHAT_BUTTON_PAD)

    -- Au-dessus de la poignée de hauteur, qui court sur la même bande : les deux
    -- se chevauchent, et c'est le bouton qui doit prendre le clic.
    button:SetFrameLevel(chatFrame:GetFrameLevel() + 6)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(T.TEXTURE.CHAT_COPY)
    icon:SetAlpha(T.ALPHA.CHAT_TOOL)

    button:SetScript("OnEnter", function() icon:SetAlpha(T.ALPHA.CHAT_TOOL_HOVER) end)
    button:SetScript("OnLeave", function() icon:SetAlpha(T.ALPHA.CHAT_TOOL) end)

    -- `W.Tooltip` s'accroche aux deux mêmes scripts : les deux corps tournent.
    W.Tooltip(button, options.tooltipTitle, options.tooltipText)

    if options.onClick then
        button:SetScript("OnClick", function() options.onClick(chatFrame) end)
    end

    return button
end
