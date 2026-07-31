-- =========================================================================
--  Bshamel UI — Locales/enUS.lua
--  Locale de base. Toute clé utilisée dans le code doit exister ici.
-- =========================================================================

local _, ns = ...
local BUI = ns.BUI

BUI:RegisterLocale("enUS", {
    -- Fenêtre d'options
    ["Bshamel UI"]              = "Bshamel UI",
    ["Game"]                    = "Game",
    ["Interface"]               = "Interface",
    ["QoL"]                     = "QoL",
    ["Mythic+ / Raid"]          = "Mythic+ / Raid",
    ["Search..."]               = "Search...",
    ["Reset this page"]         = "Reset this page",
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
    ["Enable dark mode"]               = "Enable dark mode",
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
    ["Camera"]                         = "Camera",
    ["Max camera distance"]            = "Raise the maximum camera distance",
    ["Max camera distance tip"] =
        "Lets the camera zoom out further than the client allows by default.",
    ["Camera zoom factor"]             = "Zoom factor",
    ["Camera zoom factor tip"] =
        "Multiplies the client's zoom-out limit. 2.9 is the highest the client accepts.",
    ["Game menu"]                      = "Game menu",
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
    ["Auction current expansion"]      = "Auction house: current expansion only",
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
    ["Show item level"]                = "Show item level",
    ["Show item level on slots tip"] =
        "Shows the item level of every equipped piece on its own slot, scaling included.",
    ["Show upgrade level"]             = "Show upgrade level",
    ["Show upgrade level tip"]         = "Shows the upgrade rank of each equipped piece.",
    ["Warn partial upgrade"]           = "Warn on partial upgrades",
    ["Warn partial upgrade tip"] =
        "Turns the rank orange until the piece reaches its maximum. Off, every rank stays green.",
    ["Show enchants"]                  = "Show enchants",
    ["Show enchants tip"] =
        "Green on every slot that can take an enchant and has one, red on those that are missing it.",
    ["Show gems"]                      = "Show gems",
    ["Show gems tip"]                  = "Green when every socket is filled, red as soon as one is empty.",
    ["Show void core"]                 = "Show void core",
    ["Show void core tip"]             = "Flags weapons and trinkets that have not been voidforged yet.",
    ["Bags and bank"]                  = "Bags and bank",
    ["Show item level in bags"]        = "Show item level on stored gear",
    ["Show item level in bags tip"] =
        "Prints the item level on every piece of gear in your bags, your bank and the warband bank.",

    -- Pastilles posées à côté d'un emplacement, une par ligne. C'est leur
    -- couleur qui informe, le mot ne fait que nommer la question — il gagne donc
    -- à être lisible plutôt que court, quitte à empiéter sur le modèle du
    -- personnage, qu'aucune information ne recouvre.
    ["Enchant badge"]                  = "Enchant",
    ["Gem badge"]                      = "Gem",
    ["Void core badge"]                = "Void core",

    -- Intitulé cherché dans l'infobulle d'une pièce pour savoir si elle porte un
    -- noyau du vide. Aucun identifiant stable n'étant exposé côté objet, c'est la
    -- seule chose du module qui dépende de la langue du client : une locale dont
    -- l'intitulé est faux montre les armes et bijoux en rouge à tort.
    --
    -- La forme française est relevée en jeu. **La forme anglaise est une
    -- supposition** et reste à vérifier sur un client anglais.
    ["Void core marker"]               = "Ascendant Voidforge",

    -- Module Minimap
    ["Minimap"]                        = "Minimap",
    ["Buttons"]                        = "Buttons",
    ["Minimap button"]                 = "Show the BshamelUI button",
    -- Infobulle du bouton lui-même, en jeu : trois gestes, une ligne chacun.
    -- Ce n'est pas une phrase, c'est une antisèche — elle se lit d'un coup d'œil
    -- ou elle ne sert à rien.
    ["Minimap button tip"] =
        "Left click: addon list\n"
        .. "Right click: options\n"
        .. "Drag: move around the minimap",
    ["Addon buttons empty"]            = "No addon icon to show.",
    ["Group addon buttons"]            = "Group the addon buttons",
    ["Group addon buttons tip"] =
        "Tidies every other addon's minimap button into a drawer that opens beside the BshamelUI "
        .. "button, on left-click. The game's own buttons are left alone, and turning this off "
        .. "puts each button back exactly where it was. Needs the BshamelUI button: it is what "
        .. "opens the drawer.",
    ["Teleports"]                      = "Teleports",
    ["Teleport menu"]                  = "Show a teleport button",
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
    ["Dark mode moved"] =
        "Dark mode now lives on the General page, with one switch per interface element.",
    ["Class-colored health"]           = "Class-colored health bars",
    ["Class-colored health tip"]       = "Colors each health bar with the class color of the unit.",
    ["Hide reputation color"]          = "Hide the reputation color",
    ["Hide reputation color tip"] =
        "Removes the faction-colored plate behind the name on the target and focus frames.",
    ["Specialization"]                 = "Specialization",
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
    ["Bags"]                           = "Bags",
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
    ["Answer keys request tip"]        = "Replies with your keystone when someone types !keys in party or raid chat.",
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

    -- Module GroupFinder
    ["Group finder"]                   = "Group finder",
    ["Signing up"]                     = "Signing up",
    ["Keep signup note"]               = "Keep the sign-up note",
    ["Keep signup note tip"] =
        "Remembers what you type in the application note and fills it in the next time.",
    ["Auto role check"]                = "Confirm role checks",
    ["Auto role check tip"] =
        "Answers the role check automatically with the roles you already signed up with.",
    -- Module RaidTools
    ["Raid tools"]                     = "Raid tools",
    ["Combat"]                         = "Combat",
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

    ["Group tools"]                    = "Group tools",
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
    ["Hide raid manager"]              = "Hide the raid control panel",
    ["Hide raid manager tip"] =
        "Hides the tab the game puts against the left edge of the screen in a raid.",
    ["Group tools notice"] =
        "The panel does not appear, disappear or resize during combat: the game refuses to show, "
        .. "hide or resize a world marker button while you are fighting. It follows the setting "
        .. "again as soon as the fight ends.",
    ["Need lead"]                      = "You need lead or assist for that.",

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
    ["Show mythic timer"]              = "Show the timer",
    ["Show mythic timer tip"] =
        "A panel with the time left, the +2 and +3 thresholds, and your season best on that dungeon.",
    ["Timer preview"]                  = "Preview mode",
    ["Timer preview tip"] =
        "Shows the panel outside a dungeon, filled with sample numbers, so you can place it.",
    ["Mythic timer notice"] =
        "The thresholds are what the game grants: finishing under 80% of the timer is +2, under "
        .. "60% is +3. The comparison is the season best the game itself records — nothing is "
        .. "written down here.",
    ["Preview dungeon"]                = "Sample dungeon",
    ["Season best"]                    = "Best",

    -- Module Windows
    ["Windows"]                        = "Windows",
    ["Moving"]                         = "Moving",
    ["Move windows"]                   = "Move windows",
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
})
