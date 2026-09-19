-- =========================================================================
--  Bshamel UI — Modules/BuffTrackerData.lua
--  Ce que le suivi des buffs sait suivre, et d'où chaque buff vient.
--
--  La moitié qui **décrit** du module (CLAUDE.md, « un module qui ne tient plus
--  dans un fichier ») : aucune logique, que des faits de jeu. `BuffTracker.lua`
--  les lit, en fait des cases à cocher et un panneau.
--
--  **Tout a été relevé dans les tables de la bêta de Forever** (1.60.1.69913,
--  19 septembre 2026, via wago.tools), pas de mémoire de vanilla :
--    · les rangs des sorts de classe sont ceux que `SkillLineAbility` fait
--      apprendre — Bénédiction du sanctuaire n'y est pas, elle n'est pas ici ;
--    · les bonus de campement sont ceux que décrit l'aura « Camp Benefits »
--      (1229741), et l'objet de chacun est rattaché à son métier par la même
--      table ;
--    · élixirs et flacons sont les sorts d'utilisation des objets de ces
--      sous-classes de consommables — les utilitaires (détection, respiration
--      aquatique) sont écartés.
--
--  **Trois catégories, une règle chacune, et rien n'est rangé deux fois :**
--    · **Buffs** — ce qu'on reçoit d'une classe ou d'un objet de campement.
--      Une ligne par effet : le buff de classe, puis l'objet de camp qui donne
--      le même bonus. Les deux ne se cumulent pas (relevé en jeu) — c'est l'un
--      ou l'autre, et la ligne passe au vert par l'un ou l'autre ;
--    · **Consommables** — ce qu'on prend soi-même, et qui s'ajoute aux buffs :
--      nourriture, élixir, flacon ;
--    · **Arme** — ce qui se pose sur l'arme.
--
--  Les parchemins ont été des alternatives, et en sont sortis : personne ne
--  s'en sert, et une ligne qui les cite n'aide personne à ne rien rater. Ils
--  restent dans « Mis de côté ».
--
--  Les noms affichés ne sont **pas** écrits ici : sorts et objets de camp sont
--  demandés au client (`C_Spell.GetSpellName`), dans sa langue ; le reste est
--  une clé de locale.
--
--  Un buff se suit par **identifiant de sort**, jamais par nom : deux auras
--  différentes portent souvent le même nom (« Force »), et un suivi par nom les
--  confondrait.
-- =========================================================================

local _, ns = ...

---@class BUI.BuffSource
---@field ids? integer[]    auras qui comptent comme « on l'a »
---@field camp? integer     objet de camp : le sort qui le fabrique
---@field label? string     sinon : clé de locale de son nom
---@field skills? integer[] lignes de métier qui le produisent

---@class BUI.BuffEntry
---@field key string        clé du réglage, sans préfixe
---@field benefit? string  buff : ce qu'il donne, en clé de locale — le nom de la ligne
---@field class? string     jeton anglais de la classe qui donne le buff
---@field name? integer     buff de classe : le sort dont le nom s'affiche
---@field ids? integer[]    ses rangs, ou les auras de la famille
---@field camp? integer     ligne sans classe : l'objet de camp qui la nomme
---@field label? string     sinon : clé de locale du nom de la ligne
---@field sources? BUI.BuffSource[] l'objet de camp équivalent
---@field skills? integer[] le métier qui le fabrique
---@field kinds? string[]   consommable : ce qu'il peut donner, en clés de locale
---@field weapon? string    « temp » ou « scope » : se lit sur l'arme, pas en aura
---@field note? string      clé de locale d'une précision
---@field reason? string    ligne mise de côté : pourquoi, en clé de locale

local D = {}
ns.BuffTrackerData = D

-- Lignes de métier, par identifiant de jeu.
local ALCHEMY, BLACKSMITHING, ENCHANTING, TAILORING, ENGINEERING =
      171, 164, 333, 197, 202
local MINING, HERBALISM, SKINNING, FISHING, FIRST_AID, COOKING =
      186, 182, 393, 356, 129, 185

-- Objets de camp. Chacun pose sa propre aura quand on s'assied au feu.
local CANDLE    = { ids = { 1229513 }, camp = 1229705, skills = { HERBALISM } }
local FIRST_AID_KIT = { ids = { 1230124 }, camp = 1230117, skills = { FIRST_AID } }
local BANNER    = { ids = { 1229718 }, camp = 1229504, skills = { TAILORING } }
local LUTE      = { ids = { 1230653 }, camp = 1230643, skills = { ENCHANTING } }
local FISH_BOWL = { ids = { 1230098 }, camp = 1229745, skills = { FISHING } }
local LODESTONE = { ids = { 1230164 }, camp = 1230161, skills = { MINING } }
local MANA_WELL = { ids = { 1230587 }, camp = 1230564, skills = { ALCHEMY } }

-- =========================================================================
--  Buffs
-- =========================================================================

--- Le buff de classe, puis l'objet de camp qui donne **le même** bonus. Une
--- ligne couvre la version de groupe : « Robustesse » est là, que ce soit par
--- le sort ou par la prière. Les paires sont celles des descriptions du
--- client : la bougie donne de l'Intelligence, la trousse de l'Endurance…
---
--- La magnétite est sur deux lignes, et c'est vérifié : bénédiction de
--- puissance, cri de guerre et magnétite posent tous trois la même aura de
--- puissance d'attaque en mêlée (133, 139 et 90 au rang le plus haut).
---
--- **Une ligne se nomme par ce qu'elle donne** (`benefit`) : « Intelligence »,
--- pas « Intelligence des Arcanes ». Le nom d'un buff ne dit pas ce qu'on
--- gagne, et c'est ce qu'on cherche en parcourant la liste ; les noms des
--- sources sont dans l'infobulle. Les bénéfices sont relevés sur l'aura de
--- chaque sort (`SpellEffect`) : la marque et le luth donnent armure,
--- caractéristiques et résistances, les rois et le bocal un pourcentage de
--- toutes les caractéristiques, le salut −30 % de menace, l'aura de
--- précision de la puissance d'attaque **à distance**.
---
--- Les deux dernières lignes n'ont pas de classe : l'objet de camp est leur
--- seule source.
D.BUFFS = {
    { key = "arcaneIntellect", benefit = "Stat intellect", class = "MAGE", name = 1459,
      ids = { 1459, 1460, 1461, 10156, 10157, 23028 },
      sources = { CANDLE } },
    { key = "fortitude", benefit = "Stat stamina", class = "PRIEST", name = 1243,
      ids = { 1243, 1244, 1245, 2791, 10937, 10938, 21562, 21564 },
      sources = { FIRST_AID_KIT } },
    { key = "divineSpirit", benefit = "Stat spirit", class = "PRIEST", name = 14752,
      ids = { 14752, 14818, 14819, 27841, 27681 },
      sources = { BANNER } },
    { key = "markOfTheWild", benefit = "Benefit mark", class = "DRUID", name = 1126,
      ids = { 1126, 5232, 5234, 6756, 8907, 9884, 9885, 21849, 21850 },
      sources = { LUTE } },
    { key = "blessingOfKings", benefit = "Benefit kings", class = "PALADIN", name = 20217,
      ids = { 20217, 25898 },
      sources = { FISH_BOWL } },
    { key = "blessingOfMight", benefit = "Benefit melee AP", class = "PALADIN", name = 19740,
      ids = { 19740, 19834, 19835, 19836, 19837, 19838, 25291, 25782, 25916 },
      sources = { LODESTONE } },
    { key = "battleShout", benefit = "Benefit melee AP shout", class = "WARRIOR", name = 6673,
      ids = { 5242, 6192, 6673, 11549, 11550, 11551, 25289 },
      sources = { LODESTONE } },
    { key = "blessingOfWisdom", benefit = "Stat mana regen", class = "PALADIN", name = 19742,
      ids = { 19742, 19850, 19852, 19853, 19854, 25290, 25894, 25918 },
      sources = { MANA_WELL } },

    { key = "shadowProtection", benefit = "Benefit shadow resistance", class = "PRIEST", name = 976,
      ids = { 976, 10957, 10958, 27683 } },
    { key = "blessingOfSalvation", benefit = "Benefit threat", class = "PALADIN", name = 1038,
      ids = { 1038, 25895 } },
    { key = "blessingOfLight", benefit = "Benefit healing received", class = "PALADIN", name = 19977,
      ids = { 19977, 19978, 19979, 25890 } },
    { key = "trueshotAura", benefit = "Benefit ranged AP", class = "HUNTER", name = 19506,
      ids = { 19506, 20905, 20906, 1299346, 1299348 } },

    { key = "campWheel", benefit = "Stat strength", camp = 1230171, ids = { 1230172 }, skills = { BLACKSMITHING } },
    { key = "campChair", benefit = "Stat critical", camp = 1229517, ids = { 1229519 }, skills = { SKINNING } },
}

-- =========================================================================
--  Consommables
-- =========================================================================

--- Par famille : ce qui compte est « ai-je mon élixir », pas lequel.
--- L'infobulle dit ce que la famille peut donner (`kinds`), rangé par effet
--- d'après l'aura de chaque objet — c'est là, et nulle part ailleurs, que les
--- élixirs se détaillent.
D.CONSUMABLES = {
    -- « Bien nourri » sous tous ses identifiants, ceux de Forever compris.
    { key = "wellFed", label = "Well fed", skills = { COOKING },
      ids = { 19705, 19706, 19708, 19709, 19710, 19711, 24799, 24870, 25694,
              25941, 1225778, 1225779, 1225780, 1225782, 1243969, 1248406,
              1248420, 1248421, 1248422, 1248688, 1249519, 1249520, 1249521,
              1249523, 1249907, 1249926, 1249927, 1283082, 1294007, 1302064,
              1319310 } },

    { key = "elixir", label = "Elixir", skills = { ALCHEMY },
      kinds = { "Stat strength", "Stat agility", "Stat stamina", "Stat intellect",
                "Stat spirit", "Stat critical", "Stat health", "Stat armor",
                "Stat attack power", "Stat spell power", "Stat healing",
                "Stat mana regen", "Stat resistance" },
      ids = { 673, 2367, 2374, 2378, 3160, 3164, 3166, 3220, 3593, 7844,
              8212, 11328, 11334, 11348, 11349, 11371, 11390, 11396, 11405,
              11474, 17038, 17535, 17537, 17538, 17539, 21920, 439959,
              1245244, 1250918, 1250920, 1250922, 1250924, 1250925, 1250926,
              1250928, 1250931, 1250932, 1250940, 1250941, 1250942, 1250944,
              1250948, 1250971, 1250972, 1250974, 1250976, 1250978, 1250979,
              1250981, 1250984, 1250985, 1250986, 1250988, 1250989, 1310077 } },

    { key = "flask", label = "Flask", skills = { ALCHEMY },
      kinds = { "Stat stamina", "Stat critical", "Stat health", "Stat spell power",
                "Stat mana regen", "Stat resistance" },
      ids = { 17626, 17627, 17628, 17629, 1293740, 1293741, 1293742, 1293743 } },
}

-- =========================================================================
--  Arme
-- =========================================================================

--- Elles ne sont pas des auras : c'est l'arme qui les porte.
---
--- L'amélioration temporaire compte **quelle qu'elle soit** : une arme de
--- chaman (croque-roc, Furie-des-vents) ou un poison de voleur occupe la même
--- place qu'une pierre ou une huile et ne se cumule pas avec elles — la ligne
--- est donc au vert, il n'y a rien à ajouter.
D.WEAPON = {
    { key = "weaponTemp", label = "Weapon enhancement", weapon = "temp",
      note = "Weapon temp note",
      sources = {
          { label = "Sharpening stone", skills = { BLACKSMITHING } },
          { label = "Weightstone",      skills = { BLACKSMITHING } },
          { label = "Weapon oil",       skills = { ENCHANTING } },
      } },
    -- La lunette de visée est un enchantement **permanent** de l'arme à
    -- distance : l'ingénieur la fabrique, elle reste tant qu'on ne la
    -- remplace pas.
    { key = "scope", label = "Scope", weapon = "scope", skills = { ENGINEERING } },
}

-- =========================================================================
--  Mis de côté, et pour plus tard
-- =========================================================================

--- Retirés du suivi ou encore à trancher. La page les affiche grisés, pour que
--- rien ne se perde — une ligne qui disparaît sans trace est une décision
--- qu'on ne retrouve plus. `reason` est une clé de locale.
D.PENDING = {
    { key = "unendingBreath",     name = 5697,    reason = "Buff pending no stat" },
    { key = "soulstone",          name = 20707,   reason = "Buff pending no stat" },
    { key = "detectInvisibility", name = 132,     reason = "Buff pending no stat" },
    { key = "thorns",             name = 467,     reason = "Buff pending no stat" },
    { key = "fearWard",           name = 6346,    reason = "Buff pending no stat" },
    { key = "campTent",           camp = 1229432, reason = "Buff pending tent" },
    { key = "scrolls",            label = "Scrolls", reason = "Buff pending scrolls" },
    { key = "amplifyMagic",       name = 1008,    reason = "Buff pending undecided" },
    { key = "dampenMagic",        name = 604,     reason = "Buff pending undecided" },
}

--- Buffs mondiaux : affichés, grisés, pour une version future. Pas d'`ids` :
--- rien ne les suit encore.
D.WORLD = {
    { key = "worldOnyxia",     name = 22888 },
    { key = "worldRend",       name = 16609 },
    { key = "worldSongflower", name = 15366 },
    { key = "worldZandalar",   name = 24425 },
    { key = "worldDarkmoon",   name = 23768 },
    { key = "worldFengus",     name = 22817 },
    { key = "worldMoldar",     name = 22818 },
    { key = "worldSlipkik",    name = 22820 },
}
