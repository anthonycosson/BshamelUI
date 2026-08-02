-- =========================================================================
--  Bshamel UI — Modules/InfoBar.lua
--  Barre d'infos — annoncée, pas encore écrite.
--
--  `preview = true` : le core refuse de l'allumer, quoi qu'en dise la base d'un
--  joueur, et la colonne de navigation l'affiche grisée, sans clic et suivie de
--  « (Prochainement) ». Elle occupe sa place pour dire ce qui vient, et rien de
--  plus.
--
--  Le forçage est dans `Core/Module.lua`, à l'écriture des défauts, et pas
--  seulement dans l'interface : un réglage qui n'existe pas ne doit pas pouvoir
--  s'allumer par un autre chemin que celui qu'on a prévu.
--
--  Ce fichier n'a ni `options` ni `OnEnable` : il n'y a rien à régler tant qu'il
--  n'y a rien à afficher, et son entrée ne s'ouvre pas. Le jour où la barre
--  existe, c'est ici que tout s'écrit — la ligne du `.toc` est déjà posée et le
--  nom du module, qui est une clé de base de données, ne changera pas.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI
local L    = ns.L

BUI:RegisterModule("InfoBar", {
    title    = L["Info bar"],
    category = "Interface",
    order    = 15,
    preview  = true,
})
