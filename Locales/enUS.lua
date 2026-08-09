-- =========================================================================
--  Bshamel UI — Locales/enUS.lua
--  Locale de base. Toute clé utilisée dans le code doit exister ici.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI

BUI:RegisterLocale("enUS", {
    -- Fenêtre d'options
    ["Bshamel UI"]              = "Bshamel UI",
    ["Interface"]               = "Interface",
    ["Quality of life"]         = "Quality of life",
    ["Tools"]                   = "Tools",
    ["Content scale"]           = "Compact view",
    ["Content scale tip"] =
        "Shrinks everything inside the window without changing the window itself, "
        .. "so more settings fit. Click to pick a size.",
    ["Scale percent"]           = "%d%%",
    -- Infobulle de la case de valeur d'une glissière (UI/Widgets/Slider.lua).
    -- Vaut pour toutes les glissières de l'addon : elle décrit un geste de
    -- l'interface, pas un réglage.
    ["Slider value tip"] =
        "Right-click to type an exact value. Enter confirms, Escape cancels.",
    -- Recherche d'options (UI/Config/Search.lua)
    ["Search settings"]         = "Search settings…",
    ["No results"]              = "No setting matches this search.",
    ["More results hint"]       = "More settings match: refine the search to see them.",
    ["Yes"]                     = "Yes",
    ["Cancel"]                  = "Cancel",
    ["Open Bshamel UI"]         = "Open Bshamel UI",
    -- Écrit une fois à la connexion. La commande y est en clair : c'est la seule
    -- chose que le joueur ait besoin de retenir, et l'addon ne se manifeste
    -- nulle part ailleurs tant qu'il n'a rien coché.
    ["Login hint"]              = "Type /bui to open the options.",
    ["Module disabled tooltip"] = "This module is disabled.",
    ["Version"]                 = "Version",
    ["Blocked action watch"]    = "Blocked action watch:",
    ["Blocked action needs errors"] =
        "Lua error display has been turned on: the game reports blocked actions only then. " ..
        "It goes back to how it was when you turn the watch off.",
    ["On"]                      = "on",
    ["Off"]                     = "off",

    -- Modules annoncés (Modules/Upcoming.lua)
    ["Coming soon"]             = "Coming soon",
    ["Coming soon notice"]      = "This module is not written yet. The settings below show what it will offer.",
    ["Coming soon tooltip"]     = "Not available yet.",
    -- Accolé à l'intitulé d'une catégorie dont **tous** les modules sont
    -- annoncés : l'espace fait partie de la chaîne, la langue décide de la
    -- ponctuation.
    ["Coming soon suffix"]      = " (Coming soon)",

    -- Module Quest
    ["Quest"]                   = "Quest",
    ["Automation"]              = "Automation",
    ["Auto-accept quests"]      = "Auto-accept quests",
    ["Auto-accept quests tip"]  = "Automatically accepts quests offered by NPCs and quest items.",
    ["Auto-turn-in quests"]     = "Auto-turn-in quests",
    ["Auto-turn-in quests tip"] = "Automatically completes quests and takes the reward when there is only one.",
    ["Filters"]                 = "Filters",
    ["Skip trivial quests"]     = "Skip low-level quests",
    ["Skip trivial quests tip"] = "Leave grey (trivial) quests alone.",
    ["Bypass modifier"]         = "Hold to bypass",
    ["Bypass modifier tip"]     = "Hold this key to temporarily suspend the automation.",
    ["None"]                    = "None",
    ["Shift"]                   = "Shift",
    ["Ctrl"]                    = "Ctrl",
    ["Alt"]                     = "Alt",

    -- Module General
    ["General"]                        = "General",

    -- Catégorie « Import / export » et sa page Profiles
    ["Import / export"]         = "Import / export",
    ["Backup and sharing"]      = "Backup and sharing",
    ["Export settings"]         = "Export settings",
    ["Export"]                  = "Export",
    ["Export settings tip"] =
        "Opens a window holding a text code of every setting of the current profile. "
        .. "Copy it to keep a backup, move it to another account, or share it.",
    ["Export copy hint"]        = "The code is selected: Ctrl+C copies it. Escape closes.",
    ["Export failed"]           = "Export failed: a setting could not be written out.",
    ["Import settings"]         = "Import settings",
    ["Import"]                  = "Import",
    ["Import settings tip"] =
        "Paste a code exported from Bshamel UI, then apply it: you choose whether it "
        .. "replaces the current profile or goes into a brand-new one.",
    ["Import paste hint"]       = "Ctrl+V pastes. Escape closes.",
    ["Apply"]                   = "Apply",
    ["Import invalid"]          = "This code is not a valid Bshamel UI export.",
    ["Import newer"] =
        "This code comes from a newer version of Bshamel UI: update the addon, then import again.",
    ["Import destination"] =
        "Where should the imported settings go? The current profile would be replaced; "
        .. "a new profile leaves everything else untouched.",
    ["Current profile"]         = "Current profile",
    ["New profile"]             = "New profile",
    ["Import applied"]          = "Settings imported.",
    ["Import applied to new"]   = "Settings imported into the new profile '%s'.",

    -- Module Profiles
    ["Profiles"]                = "Profiles",
    ["Active profile"]          = "Active profile",
    ["Active profile tip"] =
        "The settings profile this character uses. Each character picks its own profile; "
        .. "several characters can share one.",
    -- Le libellé du bouton de création réutilise la clé `Create` existante.
    ["Create blank profile"]    = "Create a blank profile",
    ["Create blank profile tip"] =
        "Creates a profile where every setting is back to its default, and switches "
        .. "this character to it.",
    ["Duplicate profile"]       = "Duplicate the active profile",
    ["Duplicate"]               = "Duplicate",
    ["Duplicate profile tip"] =
        "Saves a copy of the active profile under a new name. This character keeps "
        .. "using the current one.",
    ["Other profiles"]          = "Other profiles",
    ["Other profile"]           = "Other profile",
    ["Other profile tip"] =
        "Pick the profile the action below acts on.",
    ["Copy into active"]        = "Replace the active profile",
    -- Pas la clé `Copy` : elle existe déjà avec un autre sens (« Copie »).
    ["Copy profile"]            = "Copy",
    ["Copy into active tip"] =
        "Replaces every setting of the active profile with a copy of the profile "
        .. "picked above, after a confirmation.",
    ["Delete profile"]          = "Delete the active profile",
    ["Delete"]                  = "Delete",
    ["Delete profile tip"] =
        "Permanently deletes the active profile, after a confirmation. This character "
        .. "then goes back to the default profile; another character that was using the "
        .. "deleted profile will start over on a blank profile with the same name.",
    ["Delete profile confirm"] =
        "Permanently delete profile '%s'? This character will go back to the default profile.",
    ["Profile deleted"]         = "Profile '%s' deleted.",
    ["No other profile"]        = "There is no other profile yet.",
    ["Pick a profile first"]    = "Pick a profile above first.",
    ["No profile picked"]       = "(pick a profile)",
    ["New profile name"]        = "Name of the new profile:",
    ["Profile exists"]          = "A profile with that name already exists.",
    ["Profile created"]         = "Profile '%s' created; this character now uses it.",
    ["Profile duplicated"]      = "Active profile duplicated as '%s'.",
    ["Profile copied"]          = "Settings copied from profile '%s'.",
    ["Copy profile confirm"] =
        "Replace every setting of the active profile ('%s') with a copy of '%s'?",
    -- Module DarkMode
    ["Enable dark mode"]               = "Enable dark mode",
    ["What it darkens"]                = "What it darkens",
    ["Dark action bars tip"]           = "Buttons, borders and the artwork behind every action bar.",
    ["Cast bar"]                       = "Cast bar",
    ["Dark cast bar tip"]              = "Your casting bar and the one on your target.",
    ["Dark unit frames tip"] =
        "Player, pet, target, target of target and focus frames. Boss, party and raid frames are left alone.",
    ["Buffs and debuffs"]              = "Buffs and debuffs",
    ["Dark auras tip"]                 = "Aura icons, their borders and their timers.",
    ["Tooltip"]                        = "Tooltip",
    ["Dark tooltip tip"]               = "The tooltip border. Its background is left as the game set it.",
    ["Spellbook"]                      = "Spellbook",
    ["Dark spellbook tip"] =
        "The spells and talents window: its artwork, its tabs and its frames. "
        .. "Spell icons keep their border, which says what kind of spell it is.",
    ["Cooldown manager"]               = "Cooldown manager",
    ["Dark cooldown manager tip"]      = "The cooldown manager bars and their icons.",
    ["Dark personal resources tip"] =
        "The health and resource bars shown under your character.",
    ["Dark nameplates tip"] =
        "The frame around every nameplate: health bar and cast bar borders. "
        .. "The bars themselves, the target highlight and the icons keep their colors.",
    -- Module PersonalResource
    ["Personal resources"]             = "Personal resources",
    ["Show personal resources"]        = "Show personal resources",
    ["Show personal resources tip"] =
        "The game's own setting: shows your health and resource bars under "
        .. "your character. Changing it is refused during combat.",
    ["Health bar"]                     = "Health bar",
    ["Resource bar"]                   = "Resource bar",
    ["Personal no text"]               = "No text at all",
    ["Personal no text tip"] =
        "Hides the game's own text on this bar, without writing anything in its place.",
    ["No text active"]                 = "Uncheck \"No text at all\" first.",
    ["Personal value text"]            = "Value text",
    ["Personal value text tip"] =
        "Writes the current amount on this bar, in place of the game's own text.",
    ["Personal percent text"]          = "Percentage text",
    ["Personal percent text tip"] =
        "Writes the percentage on this bar, in place of the game's own text.",
    ["Personal value anchor"]          = "Value position",
    ["Personal percent anchor"]        = "Percentage position",
    ["Personal anchor tip"]            = "Side of the bar where this text sits.",
    ["Anchor left"]                    = "Left",
    ["Anchor center"]                  = "Center",
    ["Anchor right"]                   = "Right",
    ["Personal text size"]             = "Text size",
    ["Personal text size tip"]         = "Font size of the value and the percentage.",
    ["Needs value text"]               = "Turn on the value text first.",
    ["Needs percent text"]             = "Turn on the percentage text first.",
    ["Personal text needs one"]        = "Turn on the value or the percentage first.",
    -- Module General (suite)
    ["Camera"]                         = "Camera",
    ["Max camera distance"]            = "Raise the maximum camera distance",
    ["Max camera distance tip"] =
        "Lets the camera zoom out further than the client allows by default.",
    ["Camera zoom factor"]             = "Zoom factor",
    ["Camera zoom factor tip"] =
        "Multiplies the client's zoom-out limit. 2.9 is the highest the client accepts.",
    -- La touche est dans l'intitulé de la section : « menu du jeu » ne désigne
    -- rien pour qui ne l'a jamais lu écrit, alors que tout le monde connaît le
    -- menu qui s'ouvre sur Échap.
    ["Game menu"]                      = "Game menu (Esc)",
    ["Compact game menu"]              = "Shrink the game menu",
    ["Compact game menu tip"]          = "Scales down the menu opened with Escape, which the client draws very large.",
    ["Game menu scale"]                = "Menu size",
    ["Game menu scale tip"]            = "Size of the Escape menu, as a percentage of the client's own.",
    ["Queues"]                         = "Queues",
    ["Queue popup timer"]              = "Show a timer on queue popups",
    ["Queue popup timer tip"] =
        "Counts down the time left to accept a dungeon, raid, arena or battleground invitation.",
    ["Auto-repair"]                    = "Auto-repair",
    ["Auto-repair tip"] =
        "Repairs at every merchant, from guild funds first and from your own money second.",
    ["Repaired from guild"]            = "Repaired for %s from guild funds.",
    ["Repaired from purse"]            = "Repaired for %s.",
    ["Repair too expensive"]           = "Not enough money to repair: %s needed.",
    ["Auction house"]                  = "Auction house",
    ["Auction current expansion"]      = "Current expansion only",
    ["Auction current expansion tip"]  = "Restricts auction house browsing to items from the current expansion.",
    ["Annoyances"]                     = "Annoyances",
    ["Skip cinematics"]                = "Skip cinematics",
    ["Skip cinematics tip"] =
        "Movies, cinematics and in-game scenes all end on their own, without asking anything of you.",
    ["Hide talking heads"]             = "Hide talking heads",
    ["Hide talking heads tip"]         = "Hides the talking head frame that pops up during quests and dungeons.",
    ["Hide Lua errors"]                = "Hide Lua errors",
    ["Hide Lua errors tip"]            = "Suppresses the error popup. Errors are still reported to error handlers.",


    -- Module Character
    ["Character sheet"]                = "Character sheet",
    ["Item details"]                   = "Item details",
    ["Show average item level"]        = "Show the character's item level",
    ["Show average item level tip"] =
        "Writes the average item level above the weapons. The one you wear, not the one "
        .. "your bags promise.",
    -- L'intitulé du niveau d'objet du personnage. Abrégé, parce qu'il tient sous
    -- le modèle entre deux armes : le mot entier y prendrait plus de place que le
    -- nombre qu'il annonce, et « Ilvl » est ce que les joueurs écrivent déjà.
    ["Item level headline"]            = "Ilvl: %s",
    ["Item level decimals"]            = "Decimal places",
    ["Item level decimals tip"] =
        "How precise the character's item level should be. Zero rounds it to a whole "
        .. "number.",
    ["Show item level"]                = "Show item level on each piece",
    ["Show item level on slots tip"] =
        "Shows the item level of every equipped piece beside its slot, scaling included.",
    ["Show upgrade level"]             = "Show upgrade level",
    ["Show upgrade level tip"] =
        "Shows the upgrade rank beside the item level, in brackets. Both take the colour of "
        .. "the upgrade track: orange for Myth, purple for Hero, blue for Champion, green for "
        .. "Veteran, white below that.",
    ["Show enchants"]                  = "Show enchants",
    ["Show enchants tip"] =
        "Green on every slot that can take an enchant and has one, red on those that are missing it.",
    ["Show gems"]                      = "Show gems",
    ["Show gems tip"]                  = "Green when every socket is filled, red as soon as one is empty.",
    ["Bags and bank"]                  = "Bags and bank",
    ["Show item level in bags"]        = "Show item level on stored gear",
    ["Show item level in bags tip"] =
        "Prints the item level on every piece of gear in your bags, your bank and the warband bank.",

    -- Titres et indications des icônes posées à côté d'un emplacement. Ce sont
    -- des **infobulles**, pas des pastilles : l'icône dit déjà de quoi il s'agit,
    -- le texte n'est là que pour qui s'arrête dessus.
    ["Enchant badge"]                  = "Enchant",
    ["No enchant hint"]                = "This slot can take an enchant and has none.",
    ["Empty socket"]                   = "Empty socket",

    -- Bouton de l'addon (module General)
    -- `Buttons` coiffe aussi les pages Addons et Téléportations : c'est le même
    -- intitulé pour la même chose, un bouton posé sur le pourtour de la carte.
    ["Buttons"]                        = "Buttons",
    ["Minimap button"]                 = "Show the BshamelUI button on the minimap",
    -- Infobulle du bouton lui-même, en jeu : trois gestes, une ligne chacun.
    -- Ce n'est pas une phrase, c'est une antisèche — elle se lit d'un coup d'œil
    -- ou elle ne sert à rien.
    -- Le clic gauche dit deux choses parce qu'il en fait deux, selon que les
    -- boutons d'addons soient regroupés ou non. L'annoncer d'un seul des deux
    -- côtés mentirait à la moitié des joueurs — et, le tiroir étant éteint à
    -- l'installation, à tous ceux qui viennent d'installer l'addon.
    ["Minimap button tip"] =
        "Left click: options — the addon list, once they are grouped\n"
        .. "Right click: options\n"
        .. "Drag: move around the minimap",

    ["Addon buttons empty"]            = "No addon icon to show.",
    ["Group addon buttons"]            = "Group the addon buttons",
    -- Avertissement rouge sous la case, pas une infobulle : voir `General.lua`.
    ["Group addon buttons warning"] =
        "Left-clicking the minimap button then opens the addon list: Bshamel UI's "
        .. "options move to the right click.",
    -- Trois phrases au plus, et la première dit le geste : c'est la seule chose
    -- qu'il faut savoir pour retrouver ses boutons une fois qu'ils ont disparu
    -- du pourtour de la carte.
    ["Group addon buttons tip"] =
        "Tidies the other addons' minimap buttons into a drawer. Left-click the BshamelUI "
        .. "button to open it. Turning this off puts each button back exactly where it was.",

    -- Module Teleports
    ["Teleports"]                      = "Teleports",
    ["Menu"]                           = "Menu",
    ["Teleport menu"]                  = "Show a teleport button on the minimap",
    ["Teleport menu tip"] =
        "Adds a button next to the minimap: your hearthstones, and the dungeons of the current "
        .. "season under a submenu. Click a line to use it.",
    ["Teleport in combat"]             = "The teleport menu does not open during combat.",
    ["Hearthstones"]                   = "Hearthstones",
    ["Hearthstone choice"]             = "Hearthstone",
    ["Hearthstone choice tip"] =
        "Which hearthstone the menu offers. They all share one cooldown and all go to the same "
        .. "place, so the menu lists one: the one you like looking at.",
    ["Other expansions"]               = "Other expansions",
    ["Teleport macro"]                 = "Action bar macro",
    ["Teleport macro tip"] =
        "Creates a macro that opens this menu. Drag it from the macro window onto an action bar: "
        .. "an action slot only takes what the game puts there, and a macro is one of those things.",
    ["Create"]                         = "Create",

    -- Nom de la macro. Seize caractères au maximum : c'est la limite du client,
    -- et un nom plus long est refusé sans un mot d'explication.
    ["Teleport macro name"]            = "Teleports",
    ["Teleport macro created"] =
        "Macro \"%s\" created. Open the macro window and drag it onto an action bar.",
    ["Teleport macro updated"]         = "Macro \"%s\" is already there, and up to date.",
    ["Teleport macro failed"]          = "No macro slot left: free one and try again.",

    -- Débuts de nom qui désignent une téléportation de donjon, séparés par des
    -- virgules. Ce sont des chaînes du **client**, pas des textes affichés : une
    -- locale dont les préfixes sont faux montre une section vide, jamais une
    -- entrée fausse.
    --
    -- Le français réunit toutes les familles sous « Voie » ; l'anglais nomme
    -- chacune autrement, d'où deux entrées ici.
    ["Teleport spell prefixes"]        = "Path,Timeway",

    -- Module Bags
    ["Sold junk"]                      = "Sold junk for %s.",

    -- Modules ActionBars et UnitFrames
    ["Action bars"]                    = "Action bars",
    ["Input"]                          = "Input",
    ["Cast on key down"]               = "Fire actions on",
    ["Cast on key down tip"] =
        "Whether an action goes off the moment the key goes down, or when it comes back up. "
        .. "Applies to every action bar, and to clicks as well as keys.",
    ["Game default"]                   = "Game default",
    ["Key down"]                       = "Key down",
    ["Key up"]                         = "Key up",
    ["Unit frames"]                    = "Unit frames",
    ["Appearance"]                     = "Appearance",
    ["Dark mode"]                      = "Dark mode",
    ["Dark mode tip"]                  = "Darkens the artwork so it sits back into the screen.",
    ["Class-colored health"]           = "Class-colored health bars",
    ["Class-colored health tip"]       = "Colors each health bar with the class color of the unit.",
    ["Hide reputation color"]          = "Hide the reputation color",
    ["Hide reputation color tip"] =
        "Removes the faction-colored plate behind the name on the target and focus frames.",
    ["Show spec icon"]                 = "Show the specialization icon",
    ["Show spec icon tip"] =
        "Replaces the portrait with the specialization icon on the player, target, focus and " ..
        "target-of-target frames. Another player's specialization is only known once the game can " ..
        "inspect them, which needs them to be nearby; until then the portrait is left alone.",
    ["Decorations"]                    = "Decorations",
    ["Hide rested effect"]             = "Hide the rested effect",
    ["Hide rested effect tip"] =
        "Removes the animation that plays over your portrait while you are rested.",
    ["Hide corner icon"]               = "Hide the corner icon",
    ["Hide corner icon tip"] =
        "Removes the small badge the game draws in the corner of your portrait.",
    ["Hide combat glow"]               = "Hide the combat glow",
    ["Hide combat glow tip"] =
        "Removes the flashing glow around every engaged frame: yours, your pet's, your target's, "
        .. "your focus and the boss frames.",
    ["Hide PvP icon"]                  = "Hide the PvP icon",
    ["Hide PvP icon tip"] =
        "Removes the PvP and prestige badge from the player, target and focus frames.",
    ["Party frames"]                   = "Party frames",
    ["Enlarge party frames"]           = "Enlarge the party frames",
    ["Enlarge party frames tip"] =
        "Scales the party frames past the maximum the Edit Mode slider allows.",
    ["Party frame scale"]              = "Party frame scale",
    ["Party frame scale tip"] =
        "Percentage of the original size. 100% is the size the frames already have.",
    ["Arena frames"]                   = "Arena frames",
    ["Enlarge arena frames"]           = "Enlarge the arena frames",
    ["Enlarge arena frames tip"] =
        "Scales the enemy arena frames past the maximum the Edit Mode slider allows. The size "
        .. "is set during the preparation phase: the game refuses to resize these frames while "
        .. "you are fighting.",
    ["Arena frame scale"]              = "Arena frame scale",
    ["Arena frame scale tip"] =
        "Percentage of the original size. 100% is the size the frames already have.",

    -- Module CooldownManager
    ["Tracked buffs"]                  = "Tracked buffs",
    ["Center tracked buffs"]           = "Keep tracked buffs grouped in the middle",
    ["Center tracked buffs tip"] =
        "The game keeps one slot per tracked buff, and leaves it empty when the buff falls off, so "
        .. "the ones still up stay spread apart. This packs them together in the middle of the row.",


    -- Module Chat
    ["Chat"]                           = "Chat",
    ["History"]                        = "History",
    ["Keep history"]                   = "Keep history across reloads",
    ["Keep history tip"]               = "Restores the last messages after a /reload or a relog.",
    ["Chat history separator"]         = "----- previous session -----",
    ["Drag to resize"]                 = "Drag the tab to resize the height",
    ["Drag to resize tip"] =
        "Drag a chat tab up or down to change the chat height. A plain click still switches "
        .. "tabs, and the new size is kept by the game itself.",
    ["Unify group colors"]             = "One color for group chat",
    ["Unify group colors tip"] =
        "Party, instance and raid chat all take the party color, so a conversation with the same "
        .. "people keeps the same color everywhere. Raid warnings keep their own.",
    ["Copy"]                           = "Copy",
    ["Copy button"]                    = "Show a copy button on the chat",
    ["Copy button tip"] =
        "Adds a discreet button to the top-right corner of every chat window.",
    ["Copy chat"]                      = "Copy chat",
    ["Copy chat hint"] =
        "Select what you want, then Ctrl+C to copy. Ctrl+A selects everything.",

    -- Module Bags
    ["Bags and repairs"]               = "Bags and repairs",
    ["Merchants"]                      = "Merchants",
    ["Auto-sell junk"]                 = "Auto-sell junk",
    ["Auto-sell junk tip"]             = "Sells grey items at every merchant.",
    ["Skip sell confirmation"]         = "Skip the sell confirmation",
    ["Skip sell confirmation tip"] =
        "Answers the window that appears when you sell loot that is still tradeable or refundable.",
    ["Skip sell confirmation warning"] =
        "That window is the last step before the item stops being tradeable and refundable. " ..
        "With this on, one misplaced click sells it for good.",
    ["Confirmations"]                  = "Confirmations",
    ["Fill delete confirmation"]       = "Fill the delete confirmation",
    ["Fill delete confirmation tip"]   = "Types the confirmation word for you when destroying an item asks for it.",

    -- Module Keystones
    ["Keystones"]                      = "Keystones",
    ["Answer keys request"]            = "Answer !keys in chat",
    ["Answer keys request tip"] =
        "Replies with your keystone when someone types !keys in party, raid, instance or guild "
        .. "chat. Never to a whisper, never in a public channel.",
    ["Auto slot keystone"]             = "Slot your keystone automatically",
    ["Auto slot keystone tip"] =
        "Puts your keystone into the font of power as soon as it opens. A keystone already "
        .. "slotted by someone else is left alone.",
    ["No keystone"]                    = "No keystone.",
    ["Dungeon dialogue"]               = "Dungeon dialogue",
    ["Auto dungeon gossip"]            = "Talk to dungeon NPCs for you",
    ["Auto dungeon gossip tip"] =
        "Clicks through dialogues for you so you keep moving: Algeth'ar, Pit of Saron, the "
        .. "cauldron in Maisara, and so on.",

    -- Module GroupFinder
    ["Group finder"]                   = "Group finder",
    ["Signing up"]                     = "Signing up",
    ["Keep signup note"]               = "Keep the sign-up note",
    ["Keep signup note tip"] =
        "Remembers what you type in the application note and fills it in the next time.",
    ["Auto role check"]                = "Confirm role checks",
    ["Auto role check tip"] =
        "Answers the role check automatically with the roles you already signed up with. "
        .. "The game's popup never appears.",

    -- Panneau de filtres de la recherche personnalisée
    ["Premade filter panel"]           = "Filter panel on the group browser",
    ["Premade filter panel tip"] =
        "Docks a filter panel to the right of the premade group browser: difficulty, "
        .. "role counts, group size, specific instance. With nothing set, it hides nothing.",
    ["Hide declined groups"]           = "Hide groups that declined you",
    ["Hide declined groups tip"] =
        "Hides listings that turned down your application, including those that filled up "
        .. "before answering. They come back once the game forgets the application. Works "
        .. "in every tab, even where this panel does not show.",
    ["Search"]                         = "Search",
    ["Search tip"]                     = "Runs the current search again, for a fresh list of groups.",
    ["Reset filters tip"]              = "Clears every filter of the current tab. All groups show again.",
    ["Difficulty"]                     = "Difficulty",
    ["Normal"]                         = "Normal",
    ["Heroic"]                         = "Heroic",
    ["Mythic"]                         = "Mythic",
    ["Mythic+"]                        = "Mythic+",
    ["Roles"]                          = "Roles",
    ["Tanks"]                          = "Tanks",
    ["Healers"]                        = "Healers",
    ["DPS"]                            = "DPS",
    ["Group size"]                     = "Group size",
    ["Min max tip"] =
        "At least the left number, at most the right one. Leave a box empty for no limit.",
    ["Min"]                            = "Min",
    ["Max"]                            = "Max",
    ["Show filter tip"]                = "Untick to hide these groups from the results.",
    ["Arena bracket"]                  = "Arena bracket",
    ["2v2"]                            = "2v2",
    ["3v3"]                            = "3v3",
    ["Dungeons"]                       = "Dungeons",
    ["Raids"]                          = "Raids",
    -- Module RaidCooldowns
    ["Bloodlust and battle res"]       = "Bloodlust and battle res",
    ["Battle resurrections"]           = "Battle resurrections",
    ["Battle res tracker"]             = "Battle res tracker",
    ["Battle res tracker tip"] =
        "Shows how many battle resurrections are left and how long until the next one.",
    ["Battle res size"]                = "Icon size",
    ["Battle res size tip"]            = "Side of the icon, in pixels. Drag the icon to move it.",
    ["Battle res shaded"]              = "Dark border on the icon",
    ["Battle res shaded tip"] =
        "Draws the addon's dark border around the icon, like dark mode does on aura icons. This "
        .. "one is its own setting: dark mode elsewhere does not decide it.",
    ["Lock battle res"]                = "Lock the icon in place",
    ["Lock battle res tip"]            = "Freezes the icon where it is. It keeps counting.",
    ["Battle res preview"]             = "Preview mode",
    ["Battle res preview tip"] =
        "Shows the icon outside an instance, filled with sample values, so you can place it.",

    ["Bloodlust"]                      = "Bloodlust",
    ["Lust tracker"]                   = "Bloodlust lockout tracker",
    ["Lust tracker tip"] =
        "Counts down the lockout debuff every bloodlust leaves behind. That debuff, and not the "
        .. "haste itself, is what decides when the next pull can have one.",
    ["Lust size"]                      = "Icon size",
    ["Lust size tip"]                  = "Side of the icon, in pixels. Drag the icon to move it.",
    ["Lust shaded"]                    = "Dark border on the icon",
    ["Lust shaded tip"] =
        "Draws the addon's dark border around the icon, like dark mode does on aura icons. This "
        .. "one is its own setting: dark mode elsewhere does not decide it.",
    ["Lock lust"]                      = "Lock the icon in place",
    ["Lock lust tip"]                  = "Freezes the icon where it is. It keeps counting.",
    ["Lust preview"]                   = "Preview mode",
    ["Lust preview tip"] =
        "Shows the icon with a sample countdown, so you can place it without waiting for a pull.",
    ["Hide lust debuff"]               = "Hide the debuff from your debuff row",
    ["Hide lust debuff tip"] =
        "Takes the lockout debuff out of your debuff row, since the icon above already counts it "
        .. "down. Turning this off puts it back.",

    -- Module RaidPanel
    ["Group tools"]                    = "Group tools",
    ["Blizzard panel"]                 = "The game's panel",
    ["World markers"]                  = "Group tool panel",
    ["World markers tip"] =
        "A panel with the eight world markers, a red no-entry sign that clears them, a ready check and a "
        .. "pull timer. Drag it to move it, drag its bottom right corner to scale it.",
    ["Lock group tools"]               = "Lock the panel in place",
    ["Lock group tools tip"] =
        "Freezes the panel where it is and puts its resize handle away. The buttons keep working.",
    ["Group tools on hover"]           = "Show only under the cursor",
    ["Group tools on hover tip"] =
        "Keeps the panel invisible until you move the mouse over it. It still takes the mouse "
        .. "where it stands, so remember where you put it.",
    ["World marker number"]            = "World marker %d",
    ["World marker tip"]               = "Places this world marker where you are aiming.",
    ["Clear markers"]                  = "Clear markers",
    ["Clear markers tip"]              = "Removes every world marker.",
    -- Le bouton porte « Ready » et non « Ready check » : c'est le mot que les
    -- groupes emploient, et les deux boutons de la rangée se partagent une
    -- largeur — un intitulé court y tient à toutes les tailles du panneau.
    ["Ready"]                          = "Ready",
    ["Ready check tip"]                = "Starts a ready check. Needs lead or assist.",
    ["Pull"]                           = "Pull",
    ["Pull tip"]                       = "Starts the countdown and announces it in group chat. Needs lead or assist.",
    ["Pull seconds"]                   = "Pull (%d)",
    ["Pull announce"]                  = "Pulling in %d seconds.",
    ["Pull timer"]                     = "Pull countdown",
    ["Pull timer tip"]                 = "How many seconds the pull button counts down.",
    ["Need lead"]                      = "You need lead or assist for that.",

    ["Raid manager"]                   = "Raid control panel",
    ["Hide raid manager"]              = "Hide the raid control panel",
    ["Hide raid manager tip"] =
        "Hides the tab the game puts against the left edge of the screen in a raid.",

    -- Module CombatLog
    ["Logging"]                        = "Logging",
    ["Auto combat logging"]            = "Automatic combat logging",
    ["Auto combat logging tip"] =
        "Starts combat logging the moment you enter a dungeon or a raid, and stops it when you "
        .. "leave. Advanced logging is turned on with it, and put back as it was.",
    ["Combat log armed"] =
        "Automatic combat logging is on. It starts by itself the moment you set foot in a dungeon "
        .. "or a raid, and says so here.",
    ["Combat log off"]                 = "Automatic combat logging is off.",
    ["Combat log started"] =
        "Combat logging started, advanced logging on. The file is Logs\\WoWCombatLog.txt.",
    ["Combat log stopped"]             = "Combat logging stopped.",

    -- Module MythicTimer
    ["Mythic+ timer"]                  = "Mythic+ timer",
    ["Display"]                        = "Display",
    ["Show key thresholds"]            = "Show the +2 / +3 timers",
    ["Show key thresholds tip"] =
        "Two times added right of the game's own clock: what is left before losing +3, in gold, "
        .. "then before losing +2, in grey. Plus a mark on the bar at each threshold. A threshold "
        .. "gone takes its number with it.",
    ["Show death time"]                = "Show what deaths cost",
    ["Show death time tip"] =
        "The seconds your deaths added, small and in red, between the key level and the affixes. "
        .. "The game counts them and only shows that number in a tooltip.",
    ["Show boss times"]                = "Show boss times",
    ["Show boss times tip"] =
        "The time each boss went down, against its name in the tracker, and on the line below the "
        .. "gap with your fastest timed run of the same dungeon at the same level: green when you "
        .. "are ahead, red when behind.",
    ["Timer preview"]                  = "Preview mode",
    ["Timer preview tip"] =
        "Shows the game's timer outside a dungeon, on a sample key with sample bosses and enemy "
        .. "forces, so you can see how it reads. Turn the options off one by one to see the "
        .. "tracker as the game draws it.",
    ["Preview dungeon"]                = "Sample dungeon",
    ["Preview boss"]                   = "Sample boss %d",
    ["Preview forces"]                 = "Enemy Forces",

    -- Module Windows
    ["Windows"]                        = "Windows",
    ["Moving"]                         = "Moving",
    ["Move windows"]                   = "Allow moving the game's windows",
    ["Move windows tip"] =
        "Drag a Blizzard window and it stays where you dropped it, session after session. "
        .. "Only windows that already take mouse input can be picked up.",
    ["Move modifier"]                  = "Move with",
    ["Move modifier tip"] =
        "Which key must be held to drag a window. With no key, dragging anywhere "
        .. "inside a window body moves it.",
    ["No modifier"]                    = "No key",
    ["Size"]                           = "Size",
    ["Scale windows"]                  = "Resize with Ctrl + wheel",
    ["Scale windows tip"] =
        "Hold Ctrl and scroll over a window to make it bigger or smaller. "
        .. "The size is remembered like the position.",
    ["Reset"]                          = "Reset",
    ["Reset window layout"]            = "Reset every window",
    ["Reset window layout tip"] =
        "Sends every window back where Blizzard puts it. %d moved right now.",
    ["Reset windows confirm"] =
        "Send every window back to its default position and size?",
    ["Window layout reset"]            = "Every window is back in its default place.",

    -- Module Nameplates
    ["Nameplates"]                     = "Nameplates",

    ["Blizzard settings"]              = "Blizzard settings",
    ["Blizzard settings notice"] =
        "An exact copy of the Blizzard settings, so you never have to go back and "
        .. "forth between menus.",
    ["Bshamel UI options"]             = "Bshamel UI options",
    -- Les deux notes rouges sont un **couple** : même corps, même couleur, et
    -- une longueur voisine. L'une plus longue que l'autre se lit comme plus
    -- grosse, alors que rien ne les distingue.
    ["Bshamel UI options notice"] =
        "Extra settings the game does not offer, greying out on their own the "
        .. "Blizzard settings they take over.",
    ["Cannot change in combat"]        = "The game refuses this change during combat.",

    ["Always show nameplates"]         = "Always show nameplates",
    ["Always show nameplates tip"]     = "Keeps nameplates up instead of only showing them in combat.",
    ["Enemy nameplates"]               = "Enemy units",
    ["Enemy nameplates tip"]           = "Nameplates on hostile units.",
    ["Enemy minions"]                  = "Enemy minions",
    ["Enemy minions tip"]              = "Pets, guardians and totems on the enemy side.",
    ["Enemy minor units"]              = "Enemy minor units",
    ["Enemy minor units tip"]          = "Critters and other units with almost no health.",
    -- Section « Unités adverses » (moitié Bshamel UI). Chaque infobulle donne un
    -- **exemple** : « minion », « guardian » et « minus » sont le vocabulaire du
    -- moteur, pas celui du joueur.
    ["Enemy units section"]            = "Enemy units",
    ["Tune enemy units"]               = "Set which enemies show",
    ["Tune enemy units tip"] =
        "Decides which enemy units get a nameplate, separately in the open "
        .. "world, in PvE instances and in PvP instances. The game has one set "
        .. "of settings for all three; that is all this section adds.\n\n"
        .. "Turning it on copies the state the game is in right now into the "
        .. "boxes below: nothing changes on screen until you touch them. The "
        .. "three matching lines in the Blizzard half grey out, since this is "
        .. "where they are set from now on.",
    ["Open world"]                     = "Open world",
    ["PvE instances"]                   = "PvE instances",
    ["PvP instances"]                   = "PvP instances",
    ["Enemy minor units example"] =
        "Creatures the game gives almost no health. For example: the rats and "
        .. "chickens of a city, the insects of a zone, and the small adds some "
        .. "bosses drop in numbers.",
    ["Enemy pets"]                     = "Enemy pets",
    ["Enemy pets example"] =
        "Players' pets only, as opposed to temporary summons. For example: a "
        .. "hunter's dog, a warlock's permanent demon, a mage's elemental.",
    ["Enemy guardians"]                = "Enemy guardians",
    ["Enemy guardians example"] =
        "Summons that are not pets: they act on their own and expire. For "
        .. "example: a death knight's gargoyle, a druid's treants, a shaman's "
        .. "fire elemental.",
    ["Enemy totems"]                   = "Enemy totems",
    ["Enemy totems example"] =
        "Totems planted on the ground, to kill or to walk around. For example: "
        .. "a shaman's earthquake totem, a war totem, a hunter's turret.",
    ["Enemy units taken over"] =
        "Bshamel UI decides this line, separately for each of the three "
        .. "contexts. The first two are set once and for all — the enemy side "
        .. "shows, and what it summons no longer goes through \"Minions\" — and "
        .. "the families are ticked on the right. Untick \"Set which enemies "
        .. "show\" to get everything back as it was.",

    ["Friendly player nameplates"]     = "Friendly players",
    ["Friendly player nameplates tip"] = "Nameplates on players on your side.",
    ["Friendly NPC nameplates"]        = "Friendly NPCs",
    ["Friendly NPC nameplates tip"]    = "Nameplates on quest givers, vendors and other friendly NPCs.",
    ["Nameplate distance"]             = "Distance",
    ["Nameplate distance tip"]         = "How far away a nameplate is still drawn, in yards.",
    ["Vertical overlap"]               = "Vertical spacing",
    ["Horizontal overlap"]             = "Horizontal spacing",
    ["Overlap tip"] =
        "How much room each nameplate keeps around itself before the game pushes "
        .. "the next one aside. Higher spreads them out, lower packs them tighter.",
    ["Spacing and distance"]           = "Spacing and distance",

    ["Nameplate style"]                = "Style",
    ["Nameplate style tip"] =
        "The overall look the game gives its nameplates. Same list as the game "
        .. "menu, and the same setting.",
    ["Style modern"]                   = "Modern",
    ["Style thin"]                     = "Thin bars",
    ["Style block"]                    = "Block bars",
    ["Style health focus"]             = "Wide health bar",
    ["Style cast focus"]               = "Block casts",
    ["Style legacy"]                   = "Traditional red",

    ["Stacking"]                       = "Stacking",
    ["Stacking tip"] =
        "Stacked nameplates never cover each other; unstacked ones stay over the "
        .. "unit they belong to.",
    ["Stack enemy nameplates"]         = "Enemy units",
    ["Stack friendly nameplates"]      = "Friendly units",
    ["Health bar info"]                = "Health bar info",
    ["Health bar info tip"]            = "What the game writes on a nameplate's health bar.",
    ["Health percentage"]              = "Health percentage",
    ["Health value"]                   = "Health points",
    ["Rarity icon"]                    = "Rarity icon",
    ["Cast bar info"]                  = "Cast bar info",
    ["Cast bar info tip"]              = "What the game writes on a nameplate's cast bar.",
    ["Spell name"]                     = "Spell name",
    ["Spell icon"]                     = "Spell icon",
    ["Spell target"]                   = "Spell target",
    ["Highlight important casts"]      = "Highlight important casts",
    ["Highlight casts on you"]         = "Highlight casts aimed at you",

    ["Threat display"]                 = "Threat display",
    ["Threat display tip"]             = "How the game itself shows threat. Separate from the addon's threat colours.",
    ["Threat progressive"]             = "Progressive",
    ["Threat flash"]                   = "Flash",
    ["Threat health bar color"]        = "Health bar colour",

    ["Enemy NPC auras"]                = "Enemy NPC auras",
    ["Enemy player auras"]             = "Enemy player auras",
    ["Friendly player auras"]          = "Friendly player auras",
    ["Health bar size"]                = "Health bar",
    ["Cast bar size"]                  = "Cast bar",
    ["Preview cast bar"]               = "Preview the cast bar",
    ["Preview cast bar tip"] =
        "A cast bar only shows while something is casting, so it cannot be "
        .. "adjusted by waiting. This preview keeps the real bar up and filling "
        .. "on every nameplate — the one you will get, in its place and at its "
        .. "size, nothing is imitated. Remember to turn it off.",
    ["Preview marker"]                 = "Preview the marker",
    ["Preview marker tip"] =
        "Puts a sample skull on every nameplate, so the size and offset can be "
        .. "set without waiting for a lead to mark a target. Remember to turn "
        .. "it off.",
    ["Sample cast"]                    = "Casting",
    ["Cast text size"]                 = "Cast text size",
    ["Cast text size tip"] =
        "Separate from the text above, because the game itself writes smaller on a "
        .. "cast bar than on a health bar.",
    ["Taken over by the addon"] =
        "Bshamel UI is setting the size in pixels. Turn that off to get this back.",

    ["Threat taken over"] =
        "Bshamel UI already colours the bar by threat. Untick \"Colour by "
        .. "threat\" on the right to hand this back to the game.",
    ["Name diagnostic"]                = "Name diagnostic:",
    ["Sheet diagnostic"]               = "Character sheet diagnostic:",
    ["Sheet diagnostic unavailable"]   = "The Character sheet module is not running.",
    ["No enchantable slot"]            = "No enchantable slot carries an item.",

    ["Auras paused"]                   = "Paused while size and offsets get fixed.",
    ["Auras tip"]                      = "Which auras the game shows above these nameplates.",
    ["Buffs"]                          = "Buffs",
    ["Debuffs"]                        = "Debuffs",
    ["Crowd control"]                  = "Crowd control",
    ["Loss of control"]                = "Loss of control",
    ["Nameplate size"]                 = "Nameplate size",
    ["Nameplate size tip"] =
        "The game's own size setting, in five steps. \"Set the size\" on the "
        .. "right pushes it to 5 and locks it there: the width and height in "
        .. "pixels need the largest box the game makes to have their full range. "
        .. "Turning that off gives this back as it was.",
    ["Tune overlap"]                   = "Set the overlap",
    ["Tune overlap tip"] =
        "How much room each nameplate keeps before the game pushes its "
        .. "neighbour aside. The game rewrites these two values by itself "
        .. "whenever it redoes its nameplates, which is why they sit behind a "
        .. "switch: while it is on, the addon puts your values back each time.",
    ["Needs allied names only"] =
        "Only means something in names-only mode, where the name is all there is "
        .. "left to read. Tick the box above.",
    ["Simplified taken by names only"] =
        "\"Allied players — names only\" already does this. It was unticked when "
        .. "you turned that on; untick that one to get this back.",
    ["Debuff spacing"]                 = "Debuff spacing",
    ["Debuff spacing tip"] =
        "Vertical gap only, between the row of debuffs and what sits above it. "
        .. "Applies to all three rows, not just the last one.",

    ["Simplified nameplates"]          = "Simplified nameplates",
    ["Simplified nameplates tip"] =
        "Reduces these units' nameplate to a plain bar: no name, no numbers, no "
        .. "icons. Not to be confused with allied players' names-only mode, "
        .. "which keeps the name and removes the bar.",
    ["Minions"]                        = "Minions",
    ["Minor units"]                    = "Minor units",
    ["Friendly players"]               = "Friendly players",
    ["Friendly NPCs"]                  = "Friendly NPCs",
    ["Show off-screen nameplates"]     = "Off-screen units",
    ["Show off-screen nameplates tip"] =
        "Whether nameplates are drawn for units that are off screen.",
    ["Friendly minions"]               = "Friendly minions",
    ["Friendly minions tip"]           = "Pets, guardians and totems belonging to players on your side.",

    ["Resize cast bar"]                = "Set the cast bar size",
    ["Resize cast bar tip"] =
        "Same treatment as the health bar, on its own switch: turning it off gives "
        .. "the cast bar back without touching the rest.",
    ["Cast bar height"]                = "Cast bar height",
    ["Cast bar height tip"]            = "Thickness of the cast bar. The game makes it thinner than the health bar.",

    ["Flat target size"]               = "Do not enlarge the target",
    ["Flat target size tip"] =
        "The game enlarges your target's nameplate to tell it apart. Ticked, "
        .. "it keeps the size of its neighbours — which is what makes yours "
        .. "exact: that enlargement goes over everything else, including a "
        .. "size set to the pixel. The game's setting is given back as it was "
        .. "when you untick.",
    ["Resize nameplates"]              = "Set the size",
    ["Resize nameplates tip"] =
        "Sets the size of every nameplate in pixels while this is on, and hands "
        .. "them back to the game when you turn it off.",
    ["Nameplate width"]                = "Width",
    ["Nameplate width tip"] =
        "Width of the plate. The health bar stretches to fill it. 128 is what "
        .. "the game uses.",
    ["Nameplate text size"]            = "Text size",
    ["Nameplate text size tip"] =
        "Name, level, health, health percentage and the spell being cast, all at "
        .. "once. The font and its outline are left alone — only the size changes.",
    ["Nameplate height"]               = "Health bar height",
    ["Nameplate height tip"] =
        "Thickness of the health bar. 11 is what the game uses. The name and the "
        .. "icons keep their size — they are not part of the bar.",

    ["Set the bar texture"]            = "Set the bar texture",
    ["Set the bar texture tip"] =
        "Replaces the fill of enemy health bars. Your target and the others each "
        .. "have their own choice below. Turning this off gives every bar its "
        .. "image back.",
    ["Others bar texture"]             = "Others — texture",
    ["Others bar texture tip"]         = "Fill of every nameplate you are not targeting.",
    ["Target bar texture"]             = "Target — texture",
    ["Target bar texture tip"]         = "Fill of your current target's nameplate.",
    ["Texture vivid"]                  = "Vivid colour",
    ["Texture standard"]               = "Standard colour",

    ["Raid marker"]                    = "Target marker",
    ["Place raid marker"]              = "Place the marker yourself",
    ["Place raid marker tip"] =
        "Puts the target icon on the top-right corner of the health bar, at the "
        .. "size and offset you choose.",
    ["Marker size"]                    = "Marker size",
    ["Marker size tip"]                = "Side of the icon, in pixels.",
    ["Marker offset X"]                = "Marker offset, sideways",
    ["Marker offset Y"]                = "Marker offset, up and down",
    ["Marker offset tip"] =
        "Distance from the top-right corner of the health bar. At zero the icon "
        .. "sits centred on that corner.",

    ["Tune visibility"]                = "Set the opacity",
    ["Tune visibility tip"] =
        "Sets how visible each nameplate is while this is on, and hands the "
        .. "plates back to the game when you turn it off.",
    ["Target opacity"]                 = "Target — opacity",
    ["Target opacity tip"]             = "How visible the plate of your current target is.",
    ["Others opacity"]                 = "Others — opacity",
    ["Others opacity tip"]             = "How visible the plates of everything you are not targeting are.",
    ["Occluded opacity"]               = "Behind cover — opacity",
    ["Occluded opacity tip"] =
        "How visible a plate is when its owner is behind a wall or a pillar.",

    ["Nameplate colors"]               = "Nameplate colours",
    ["PvP class colors"]               = "Class colours on enemy players",
    ["PvP class colors tip"] =
        "An enemy player's health bar takes the colour of their class, wherever "
        .. "you meet them — arena and battleground included. The game does the "
        .. "painting: this is its own setting, surfaced here. Allied players "
        .. "have their own tickbox just below.",
    ["Ally class colors"]              = "Class colours on allied players",
    ["Ally class colors tip"] =
        "An allied player's health bar takes the colour of their class. The "
        .. "game does the painting: this is its own setting, surfaced here. In "
        .. "dungeons and raids it reduces allied nameplates to the name alone — "
        .. "the names tickbox speaks there.",
    ["Ally name class colors"]         = "Class colours on allied names",
    ["Ally name class colors tip"] =
        "An allied player's name takes the colour of their class instead of "
        .. "white — everywhere, dungeons and raids included, and including in "
        .. "\"names only\" mode, where the name is all that is left. The game "
        .. "does the painting: this is its own setting, surfaced here.",
    ["Color enemies by kind"]          = "Colour enemies by kind",
    ["Color enemies by kind tip"] =
        "Rarity first, then what the creature does: a rare that casts stays "
        .. "coloured as a rare.",
    ["NPC colors scope"]               = "Where it applies",
    ["NPC colors scope tip"] =
        "Everywhere, or only inside dungeons and raids — outside them the "
        .. "game's own colours come back without unticking anything.",
    ["Everywhere"]                     = "Everywhere",
    ["Instances only"]                 = "In instances only",
    ["Boss color"]                     = "Boss",
    ["Boss color tip"] =
        "World bosses, and any elite two levels or more above you.",
    ["Miniboss color"]                 = "Miniboss",
    ["Miniboss color tip"]             = "An elite exactly one level above you.",
    ["Caster color"]                   = "Elite caster",
    ["Caster color tip"] =
        "Dungeon and raid trash that casts. Only elites are sorted this way: "
        .. "outside, a creature's class means nothing.",
    ["Melee color"]                    = "Elite melee",
    ["Melee color tip"]                = "Dungeon and raid trash that does not cast.",
    ["Rare color"]                     = "Rare",
    ["Rare color tip"]                 = "Silver dragon, no elite border.",
    ["Rare elite color"]               = "Rare elite",
    ["Rare elite color tip"]           = "Silver dragon with the elite border.",


    ["Color by threat"]                = "Colour by threat",
    ["Color by threat tip"] =
        "Turns the bar to the alert colour the moment aggro moves toward the "
        .. "wrong person — lost if you are the tank, taken if you are not.",
    ["Threat shifting"]                = "Aggro shifting (by role)",
    ["Threat shifting tip"] =
        "Tank: it is slipping away, or you are taking it back without holding it "
        .. "firmly. Damage or healer: you are climbing and about to take it.",
    ["Threat wrong"]                   = "Aggro taken or lost (by role)",
    ["Threat wrong tip"]               = "Tank: you lost it. Damage or healer: you took it.",

    ["Allied names only"]              = "Show only the name for allies",
    ["Allied names only tip"] =
        "Friendly players get a name and no health bar. Theirs is already on the "
        .. "party frames.",
    ["Resize ally names"]              = "Enlarge allied names",
    ["Resize ally names tip"] =
        "Friendly players' names take the size below. Outside instances only: "
        .. "the game locks friendly nameplates in dungeons and raids.",
    ["Ally name size"]                 = "Allied name size (12 by default)",
    ["Aura scale"]                     = "Aura size",
    ["Aura scale tip"]                 = "Size of the aura icons, as a percentage of the game's own.",

    -- Diagnostic `/bui auras` : les libellés de prose seulement — les noms de
    -- filtres et de champs sont ceux de l'API, ils ne se traduisent pas.
    ["Aura diagnostic"]                = "Nameplate diagnostic — target's plate",
    ["Aura diagnostic needs target"]   = "Target something first: the diagnostic reads the target's nameplate.",
    ["No nameplate for target"]        = "The target has no nameplate on screen.",
    ["Nameplate forbidden"] =
        "The game marks this nameplate as forbidden: it is protecting the "
        .. "unit's identity, and nothing the addon puts on that plate would "
        .. "take. Colours, sizes and markers are the game's here.",
    ["Refused"]                        = "refused",
    ["Secret"]                         = "secret",
    ["Control"]                        = "control",
    ["Tokens"]                         = "tokens",
    ["Aura diagnostic unavailable"]    = "The Nameplates module is not running.",

    -- Diagnostic `/bui glow` : la prose seulement — les noms de textures sont
    -- ceux du client, ils ne se traduisent pas.
    ["Glow diagnostic"] =
        "Dark mode diagnostic: hover the button now. Its textures are listed in three "
        .. "seconds, and the ones the addon darkened are marked.",
    ["Glow diagnostic nothing"]        = "Nothing was under the cursor.",
    ["Glow diagnostic darkened"]       = "darkened by the addon",

    -- Ressource de classe (Modules/ClassResource.lua)
    ["Class resource"]                 = "Class resource",
    ["Show resource bar"]              = "Show the class resource",
    ["Show resource bar tip"] =
        "Adds a row of squares that you place yourself. It replaces nothing: the game "
        .. "keeps showing its own resource under your character.",
    ["Resource preview"]               = "Preview",
    ["Resource preview tip"] =
        "Fills the row on its own, one square at a time, so you can place it and watch "
        .. "the threshold colour switch without waiting for a fight.",
    ["Lock resource bar"]              = "Lock in place",
    ["Lock resource bar tip"]          = "Stops the row from being dragged with the mouse.",

    ["Resource shape"]                 = "Shape",
    ["Resource cell width"]            = "Square width",
    ["Resource cell width tip"]        = "Width of a single square.",
    ["Resource cell height"]           = "Square height",
    ["Resource cell height tip"]       = "Height of a single square.",
    ["Resource cell gap"]              = "Gap between squares",
    ["Resource cell gap tip"] =
        "Space between two squares. At zero they touch, separated only by their outline.",
    ["Resource cell count"]            = "Number of squares",
    ["Resource cell count tip"] =
        "Caps the row at X squares before it starts over. Zero means no cap.\n\n"
        .. "Rogue: at 6 combo points with a cap of 10, the row does not show ten squares — "
        .. "the cap limits, it never adds.\n\n"
        .. "Enhancement Shaman: at 10 Maelstrom Weapon stacks with a cap of 5, the row "
        .. "starts over on the 6th stack.\n\n"
        .. "The point is to avoid a row of ten small squares when two passes of five large "
        .. "ones read better.",
    ["Resource count"]                 = "Show the number",
    ["Resource count tip"]             = "Writes the current count in the middle of the row.",
    ["Hide empty resource"]            = "Hide when empty",
    ["Hide empty resource tip"] =
        "The row disappears while you have nothing and comes back at the first point. "
        .. "The preview keeps it visible either way.",

    ["Resource colours"]               = "Colours",
    ["Resource colour source"]         = "Filled colour",
    ["Resource colour source tip"]     = "Where the colour of a filled square comes from.",
    ["Game resource colour"]           = "The game's",
    ["Class colour"]                   = "Your class",
    ["Custom colour"]                  = "Pick one",
    ["Resource fill colour"]           = "Chosen colour",
    ["Resource fill colour tip"]       = "Colour of a filled square.",
    ["Resource fill colour needs custom"] =
        "Only used when the filled colour is set to \"Pick one\".",
    ["Resource threshold"]             = "Colour change from",
    ["Resource threshold tip"] =
        "From this many points on, the whole row takes the colour below. Zero turns it off.",
    ["Resource threshold colour"]      = "Colour past that point",
    ["Resource threshold colour tip"] =
        "Colour the row takes once the matching count is reached.",
    ["Resource threshold 2"]           = "Second step from",
    ["Resource threshold 2 tip"] =
        "A second colour change, higher than the first. The highest step reached always "
        .. "wins: it overrides the one above it.",
    ["Resource threshold colour 2"]    = "Second step colour",
    ["Resource threshold 3"]           = "Third step from",
    ["Resource threshold 3 tip"] =
        "The last colour change. Like the others, it overrides the steps below it.",
    ["Resource threshold colour 3"]    = "Third step colour",
    ["Resource threshold needs previous"] =
        "Set the step above first.",
    ["Resource threshold glow"]        = "Show a shine effect",
    ["Resource threshold glow tip"] =
        "Puts the same glow the game shows on an action button when a spell procs onto "
        .. "the filled squares. It has its own trigger and follows no colour step.",
    ["Resource glow threshold"]        = "Shine from",
    ["Resource glow threshold tip"] =
        "How many points before the squares start to shine.",
    ["Resource threshold colour needs threshold"] =
        "Set a colour change point first.",

    -- =====================================================================
    --  Inutile mais indispensable — Emotes
    -- =====================================================================
    ["Useless but essential"]          = "Useless but essential",
    ["Emotes"]                         = "Emotes",
    ["Answer by yourself"]             = "Answer on your own",
    ["Say no to kiss"]                 = "Answer /no to a kiss",
    ["Say no to kiss tip"] =
        "Someone blows you a kiss, you decline — and the answer goes back to "
        .. "them. Every time, whatever language they play in.",
    ["Say no to hug"]                  = "Answer /no to a hug",
    ["Say no to hug tip"] =
        "Someone hugs you, you decline — and the answer goes back to them. "
        .. "Every time, whatever language they play in.",

    -- **Ce ne sont pas des libellés, ce sont les formules qu'on reconnaît.**
    -- Le client rédige lui-même la phrase d'un emote, dans sa langue, et aucune
    -- API ne la publie : elle se traduit donc ici, comme tout ce qui dépend de
    -- la langue. Le fragment est cherché tel quel, sans casse, au milieu de la
    -- phrase entière.
    --
    -- **Plusieurs formules par emote, séparées par `;`.** Le français a coûté un
    -- aller-retour en jeu pour une phrase qu'on croyait connaître ; ces deux
    -- lignes-ci n'ont pas été relevées sur un client anglais, et portent donc
    -- les deux tournures possibles plutôt qu'un pari. Une formule de trop ne
    -- coûte rien, une formule manquante rend le module muet.
    --
    -- Une locale qui ne les traduit pas retombe sur ces deux-ci. Si aucune ne
    -- correspond, le module se tait — c'est voulu : un emote parti de travers se
    -- voit par tout le monde.
    ["Kiss received"]                  = "blows you a kiss;kisses you",
    ["Hug received"]                   = "hugs you;in their arms",

    ["Emote watch"]                    = "Emote watch:",
    ["Emote seen"]                     = "emote:",
    ["Emote module unavailable"]       = "The Emotes module is not running.",
})