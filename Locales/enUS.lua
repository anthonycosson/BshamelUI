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
    ["Search..."]               = "Search...",
    ["Reset this page"]         = "Reset this page",
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
    ["Reset page confirm"]      = "Reset every setting on this page to its default value?",
    ["Yes"]                     = "Yes",
    ["Cancel"]                  = "Cancel",
    ["Open Bshamel UI"]         = "Open Bshamel UI",
    ["Cannot open in combat"]   = "The options window cannot be opened during combat.",
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
    ["Cooldown manager"]               = "Cooldown manager",
    ["Dark cooldown manager tip"]      = "The cooldown manager bars and their icons.",
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
        "Movies and cinematics end on their own. An in-game scene ends on your first key press: " ..
        "the game only lets it be cancelled while a key is being handled.",
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
    ["Gem badge"]                      = "Gem",
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
    ["Minimap button tip"] =
        "Left click: addon list\n"
        .. "Right click: options\n"
        .. "Drag: move around the minimap",

    ["Addon buttons empty"]            = "No addon icon to show.",
    ["Group addon buttons"]            = "Group the addon buttons",
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
    ["Teleport menu notice"] =
        "The menu only shows what this character actually owns or knows: the hearthstone chosen "
        .. "above, the stones that have their own cooldown, and every dungeon of the current "
        .. "season you have a teleport for, hero's path or mythic. It does not open during "
        .. "combat: the game refuses to hand a spell to an addon while you are fighting, and "
        .. "nothing in there can be used in combat anyway.",
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
    ["Cast on key down notice"] =
        "The game has its own default here, and other addons write the same setting. That is why "
        .. "there are three choices and not a checkbox: \"Game default\" leaves the setting alone, "
        .. "the other two force it either way. Turning this module off gives the game back the "
        .. "value it had before.",
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
    ["Copy chat hint"]                 = "Everything is selected: press Ctrl+C to copy.",

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
    ["Keystones notice"] =
        "The reply is the keystone link itself whenever it can be found in your bags, so anyone "
        .. "can hover it. Otherwise the dungeon and the level are written out. Only party, raid, "
        .. "instance and guild chat are listened to, never a whisper. Your own !keys is answered "
        .. "too, which is the simplest way to check the setting works.",
    ["No keystone"]                    = "No keystone.",
    ["Dungeon dialogue"]               = "Dungeon dialogue",
    ["Auto dungeon gossip"]            = "Talk to dungeon NPCs for you",
    ["Auto dungeon gossip tip"] =
        "Clicks the single line of dialogue for you inside a dungeon: the prisoners to free in "
        .. "Pit of Saron, the buff handed out at the start of Algeth'ar Academy.",
    ["Dungeon gossip notice"] =
        "Only inside a dungeon, only a dialogue that offers exactly one line and no quest, and "
        .. "each line is clicked once per conversation. A quest is left to the Quest page, a real "
        .. "choice is left to you. Beware that a dialogue which starts an encounter also has a "
        .. "single line: talking to that NPC starts it right away.",

    -- Module GroupFinder
    ["Group finder"]                   = "Group finder",
    ["Signing up"]                     = "Signing up",
    ["Keep signup note"]               = "Keep the sign-up note",
    ["Keep signup note tip"] =
        "Remembers what you type in the application note and fills it in the next time.",
    ["Auto role check"]                = "Confirm role checks",
    ["Auto role check tip"] =
        "Answers the role check automatically with the roles you already signed up with.",
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
    ["Lust notice"] =
        "Every class that can give one leaves its own debuff — shaman, mage, hunter pet, evoker — "
        .. "and the tracker follows them all. The icon is the shaman's, whoever cast it: what it "
        .. "says is that a bloodlust went out, not which one.",

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
    ["Group tools notice"] =
        "The panel does not appear, disappear or resize during combat: the game refuses to show, "
        .. "hide or resize a world marker button while you are fighting. It follows the setting "
        .. "again as soon as the fight ends.",
    ["Need lead"]                      = "You need lead or assist for that.",

    ["Raid manager"]                   = "Raid control panel",
    ["Hide raid manager"]              = "Hide the raid control panel",
    ["Hide raid manager tip"] =
        "Hides the tab the game puts against the left edge of the screen in a raid.",
    ["Raid manager notice"] =
        "The panel is a protected frame: it is not put away or brought back during combat. It "
        .. "follows the setting again as soon as the fight ends.",

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
    ["Combat log already on"] =
        "Combat logging was already running: left alone, and it will not be stopped on the way out.",

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
        "The game's own nameplate settings, gathered here so there is only one "
        .. "place to go. They are not copied: changing one here changes it in the "
        .. "game menu too, and the other way round. Turning this module off leaves "
        .. "them exactly as you left them.",
    ["Bshamel UI options"]             = "Bshamel UI options",
    ["Bshamel UI options notice"] =
        "What the game menu does not offer: settings the addon adds, and the "
        .. "handful of its own it never shows you. Each switch hands back what it "
        .. "took when you turn it off.",
    ["Cannot change in combat"]        = "The game refuses this change during combat.",

    ["Always show nameplates"]         = "Always show nameplates",
    ["Always show nameplates tip"]     = "Keeps nameplates up instead of only showing them in combat.",
    ["Enemy nameplates"]               = "Enemy units",
    ["Enemy nameplates tip"]           = "Nameplates on hostile units.",
    ["Enemy minions"]                  = "Enemy minions",
    ["Enemy minions tip"]              = "Pets, guardians and totems on the enemy side.",
    ["Enemy minor units"]              = "Enemy minor units",
    ["Enemy minor units tip"]          = "Critters and other units with almost no health.",
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
    ["Preview mode"]                   = "Preview mode",
    ["Show cast bar"]                  = "Show what only appears in combat",
    ["Show cast bar tip"] =
        "A cast bar only shows while something is casting, an aura only once a "
        .. "spell puts it there, a raid marker only on a marked unit — none of "
        .. "them can be adjusted by waiting. This keeps the real cast bar up and "
        .. "filling, adds sample auras **to the rows you have taken over** — the "
        .. "ones left to the game get none, they will never appear there — and "
        .. "shows the raid marker with a sample skull. Remember to turn it off.",
    ["Sample cast"]                    = "Casting",
    ["Resize cast text"]               = "Set the cast text size",
    ["Resize cast text tip"] =
        "Applies to whatever the cast bar writes: the spell name, and its target "
        .. "when the game shows it.",
    ["Cast text size"]                 = "Cast text size (pixels)",
    ["Cast text size tip"] =
        "Separate from the text above, because the game itself writes smaller on a "
        .. "cast bar than on a health bar.",
    ["Taken over by the addon"] =
        "Bshamel UI is setting the size in pixels. Turn that off to get this back.",
    ["Auras taken over"] =
        "Bshamel UI is showing this category. Untick \"Take over this row\" in "
        .. "the row that replaces it to get this back — it is switched off, not "
        .. "lost.",

    ["Auras and marker"]               = "Auras and marker",
    ["Auras paused"]                   = "Paused while size and offsets get fixed.",
    ["Auras paused notice"] =
        "Paused: the rows and the marker do not follow their sliders faithfully "
        .. "enough yet. Nothing in this section does anything for now.",
    ["Auras notice"] =
        "The addon shows one row of its own: crowd control. Taking it over "
        .. "switches the game's crowd control off — two rows on one nameplate "
        .. "means the same icons twice — and greys that one box on the left-hand "
        .. "side of this page. Everything else stays the game's, untouched: it "
        .. "now shows buffs and debuffs better than the addon could, and it "
        .. "reads what it will not let an addon read.",
    ["Own auras"]                      = "Adjust the auras",
    ["Own auras tip"] =
        "Opens the section. Nothing changes until you take the row over below. "
        .. "What preview mode shows is that exact row: same code, same place, "
        .. "same size. Every image is the game's own.",
    ["Take over this row"]             = "Take over this row",
    ["Take over crowd control tip"] =
        "Ticked, the addon shows this row and the game stops showing crowd "
        .. "control on enemy nameplates. Unticked, the game keeps its own crowd "
        .. "control icons, wherever it puts them.",
    ["Crowd control auras"]            = "Crowd control — everyone's",
    ["Crowd control auras notice"] =
        "To the right of the health bar. A sheeped mob is sheeped no matter who "
        .. "cast it.",
    ["Aura shaded"]                    = "Addon border on the icons",
    ["Aura shaded tip"] =
        "Ticked, an icon of this row wears the addon's usual border — the game's "
        .. "own bevelled spell frame, tinted to say what the aura is. Unticked, "
        .. "it keeps the one-pixel square outline in the same colour.",
    ["Own aura size"]                  = "Icon size (pixels)",
    ["Own aura size tip"]              = "Side of an aura icon in this row.",
    ["Aura offset X"]                  = "Offset X (pixels)",
    ["Aura offset Y"]                  = "Offset Y (pixels)",
    ["Aura offset tip"]                = "Nudges this row from its anchor on the nameplate.",
    ["Aura max"]                       = "Most icons",
    ["Aura max tip"] =
        "How many icons this row shows at most. The row fills in the order the "
        .. "game answers, and nothing sorts it — what would sort it is hidden "
        .. "on an enemy. A low ceiling is therefore the way to keep the row "
        .. "readable rather than complete.",
    ["Aura gap"]                       = "Spacing (pixels)",
    ["Aura gap tip"]                   = "Gap between two icons of this row.",
    ["Aura timer size"]                = "Timer size",
    ["Aura timer size tip"] =
        "Size of the time left written on this row's icons. Each row has its "
        .. "own: a crowd control is read to the second, a debuff you keep up is "
        .. "read out of the corner of your eye.",
    ["Auras tip"]                      = "Which auras the game shows above these nameplates.",
    ["Buffs"]                          = "Buffs",
    ["Debuffs"]                        = "Debuffs",
    ["Crowd control"]                  = "Crowd control",
    ["Loss of control"]                = "Loss of control",
    ["Nameplate size"]                 = "Nameplate size",
    ["Nameplate size tip"] =
        "The game's own size setting, in five steps. Separate from the width and "
        .. "height in pixels further down, which fine-tune what this sets.",
    ["Debuff spacing"]                 = "Debuff spacing",
    ["Debuff spacing tip"] =
        "Vertical gap only, between the row of debuffs and what sits above it. "
        .. "Applies to all three rows, not just the last one.",

    ["Simplified nameplates"]          = "Simplified nameplates",
    ["Simplified nameplates notice"] =
        "A simplified nameplate is reduced to a name — no bar, no icons. Pick which "
        .. "units get one.",
    ["Simplified nameplates tip"]      = "Shown as a name only.",
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
    ["Cast bar height"]                = "Cast bar height (pixels)",
    ["Cast bar height tip"]            = "Thickness of the cast bar. The game makes it thinner than the health bar.",

    ["Resize nameplates"]              = "Set the size",
    ["Resize nameplates tip"] =
        "Sets the size of every nameplate in pixels while this is on, and hands "
        .. "them back to the game when you turn it off.",
    ["Nameplate width"]                = "Width (pixels)",
    ["Nameplate width tip"] =
        "Width of the plate. The health bar stretches to fill it. 128 is what "
        .. "the game uses.",
    ["Resize nameplate text"]          = "Set the text size",
    ["Resize nameplate text tip"] =
        "One size for every piece of text on a nameplate. Turn it off and each "
        .. "one goes back to the size the game gave it.",
    ["Nameplate text size"]            = "Text size (pixels)",
    ["Nameplate text size tip"] =
        "Name, level, health, health percentage and the spell being cast, all at "
        .. "once. The font and its outline are left alone — only the size changes.",
    ["Nameplate height"]               = "Health bar height (pixels)",
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

    ["Raid marker"]                    = "Raid marker",
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

    ["Visibility"]                     = "Visibility",
    ["Visibility notice"] =
        "Three states, and a nameplate is always in exactly one of them: it is "
        .. "your target, it is another one, or it is behind something. Each "
        .. "state has its own opacity.",
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

    ["Enemy colors"]                   = "Enemy colours",
    ["Enemy colors notice"] =
        "The unit decides, not the zone: NPC enemies take the kind colours below, "
        .. "enemy players take their class colour if you ask for it. Ordinary "
        .. "creatures are left alone — only ranks the game states are recoloured.",
    ["PvP class colors"]               = "Class colours on enemy players",
    ["PvP class colors tip"] =
        "An enemy player's health bar takes the colour of their class, wherever "
        .. "you meet them.",
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


    ["Threat"]                         = "Threat",
    ["Threat notice"] =
        "When aggro is where it belongs, the kind colours above colour the bar — "
        .. "there is no all-is-well colour. Threat has two alerts only, read by "
        .. "your role.",
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
    ["Allies"]                         = "Allies",
    ["Class colored ally names"]       = "Class-coloured names",
    ["Class colored ally names tip"] =
        "Allied players' names take their class colour, including when their nameplate is "
        .. "down to its name alone. Unchecked, the game colours them the way it wants — "
        .. "green, most of the time. An enemy's name always takes their class colour: "
        .. "there, the class is the point.",
    ["Aura scale"]                     = "Aura size",
    ["Aura scale tip"]                 = "Size of the aura icons, as a percentage of the game's own.",

    -- Diagnostic `/bui auras` : les libellés de prose seulement — les noms de
    -- filtres et de champs sont ceux de l'API, ils ne se traduisent pas.
    ["Aura diagnostic"]                = "Nameplate diagnostic — target's plate",
    ["Aura diagnostic needs target"]   = "Target something first: the diagnostic reads the target's nameplate.",
    ["No nameplate for target"]        = "The target has no nameplate on screen.",
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
    ["Class resource notice"] =
        "One square per point of the resource your specialisation counts: combo points, "
        .. "holy power, chi, soul shards, arcane charges, essence, runes, or Maelstrom "
        .. "Weapon stacks. The row picks the right one when you change specialisation, "
        .. "and stays hidden on a character who has none.",
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
})
