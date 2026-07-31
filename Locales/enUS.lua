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

    -- Modules annoncés (Modules/Upcoming.lua)
    ["Coming soon"]             = "Coming soon",
    ["Coming soon notice"]      = "This module is not written yet. The settings below show what it will offer.",
    ["Coming soon tooltip"]     = "Not available yet.",

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
    ["Minimap"]                        = "Minimap",
    ["Minimap button"]                 = "Show the BshamelUI button",
    ["Minimap button tip"] =
        "Adds a button next to the minimap. Left-click opens this window, drag to move it around.",
    ["Enable dark mode"]               = "Enable dark mode",
    ["Dark action bars tip"]           = "Buttons, borders and the artwork behind every action bar.",
    ["Cast bar"]                       = "Cast bar",
    ["Dark cast bar tip"]              = "Your casting bar and the one on your target.",
    ["Dark unit frames tip"] =
        "Player, pet, target, target of target, focus and boss frames. Party and raid frames are not covered yet.",
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
    ["Announcements"]                  = "Announcements",
    ["Announce group deaths"]          = "Announce group deaths",
    ["Announce group deaths tip"]      = "Posts a message in group chat when a member of your party or raid dies.",
    ["Death sound alert"]              = "Play a sound on death",
    ["Death sound alert tip"]          = "Adds an audio alert to the death announcement.",
    ["Annoyances"]                     = "Annoyances",
    ["Skip cinematics"]                = "Skip cinematics",
    ["Skip cinematics tip"]            = "Skips cinematics and in-game movies.",
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

    -- Modules ActionBars et UnitFrames
    ["Action bars"]                    = "Action bars",
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
    ["Confirmations"]                  = "Confirmations",
    ["Fill delete confirmation"]       = "Fill the delete confirmation",
    ["Fill delete confirmation tip"]   = "Types the confirmation word for you when destroying an item asks for it.",

    -- Modules Keystones et RaidTools
    ["Keystones"]                      = "Keystones",
    ["Answer keys request"]            = "Answer !keys in chat",
    ["Answer keys request tip"]        = "Replies with your keystone when someone types !keys in party or raid chat.",
    ["Raid tools"]                     = "Raid tools",
    ["Combat"]                         = "Combat",
    ["Battle res tracker"]             = "Battle res tracker",
    ["Battle res tracker tip"] =
        "Shows how many battle resurrections are left and how long until the next one.",
    ["Ready check buffs"]              = "Check buffs on ready check",
    ["Ready check buffs tip"] =
        "Reports who is missing food, flask or a raid buff when a ready check starts.",
    ["World markers"]                  = "World marker panel",
    ["World markers tip"]              = "Opens a panel to place and clear world markers.",
    ["Logging"]                        = "Logging",
    ["Auto combat logging"]            = "Automatic combat logging",
    ["Auto combat logging tip"] =
        "Starts combat logging when you enter a raid or a mythic+ dungeon, and stops it when you leave.",

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
