--[[
    ================================================================
    CONFIGURATION FILE
    ================================================================

    This is a Lua file (.lua). Lua is a lightweight scripting
    language used to configure this mod's settings.

    HOW TO EDIT THIS FILE:
    1. Only change the values AFTER the equals sign (=).
    2. Numbers (like 1.0 or 2375) can be changed to your liking.
    3. Booleans (true or false) must stay lowercase.

    ABOUT COMMENTS:
    - Text starting with "--" is a single-line comment.
    - Text between "--[ [" and "] ]" is a multi-line comment.
    (Note: Spaces were added above to prevent syntax errors,
    in reality there are no spaces between the brackets).

    - Comments are IGNORED by the game. They are only here to
      provide instructions or remind you of the "Game defaults."
    - You can use comments to take notes for yourself!

    TIPS:
    - You can "comment out" specific lines to make the mod ignore
      them. If a line is commented out, the mod will use the
      game's original value instead.

      Example:
      LimitedMovementEncumbrance = {
        -- MaxSpeedMultiplier = 1.0,  <-- This line will be ignored
        bSprintingSuppressed = false, <-- This line will be applied
      }
    ================================================================


    ================================================================
    COMMANDS CONFIGURATION:
    ================================================================

    This mod uses a "Root" command followed by a "Sub-command".
    Syntax in the game console (press F10 once or twice to open it): [root] [sub-command]

    Examples:
    - > extractors reload
    - > extractors reloadTP
    - > extractors pickUpFromWorld

    RENAME & CUSTOMIZE:
    You can rename any command by changing the text between the quotes.

    Example:
    If you change 'root_command_name' to "ex" and 'pickUpFromWorld'
    to "pu", you will then type: "ex pu" instead of "extractors pickUpFromWorld".

    CASE SENSITIVITY:
    Root-command are case-sensitive.
    Sub-commands are NOT case-sensitive.
    You can type 'RELOAD', 'Reload', or 'reload', they will all work.


    ================================================================
    HOW TO CONFIGURE KEY BINDS:
    ================================================================

    A `key_bind` option allows you to trigger a command with a keyboard shortcut.

    1. The `key` must be from the `Key` table (e.g., Key.A, Key.F1, Key.NUM_ONE).
    2. The `modifierKey` is a LIST of keys that must be held down.
       It must be inside curly braces `{ }`.
       Valid modifiers: ModifierKey.CONTROL, ModifierKey.SHIFT, ModifierKey.ALT.

    EXAMPLES:
    - Control + R:
        key_bind = { key = Key.R, modifierKey = { ModifierKey.CONTROL } }

    - Single key (F5) with no modifiers:
        key_bind = { key = Key.F5, modifierKey = { } }

    - Disabled (Empty):
        key_bind = { }

    RESOURCES:
    List of all available Keys:
    https://docs.ue4ss.com/dev/lua-api/table-definitions/key.html

    List of all available ModifierKeys:
    https://docs.ue4ss.com/dev/lua-api/table-definitions/modifierkey.html
    ================================================================
]]

LOG_LEVEL = "INFO" ---@type _LogLevel
MIN_LEVEL_OF_FATAL_ERROR = "ERROR" ---@type _LogLevel

---@class MOD_OPTIONS
local options = {
  commands = {
    root_command_name = "extractors",
    sub_commands = {
      help = {
        command_name = "help",
        help_message = "Display the help.",
        key_bind = {}
      },
      pickUpFromWorld = {
        command_name = "pickUp",
        help_message =
        "Pick up all extractors. Note: This leaves them in a stopped state, which is useful for testing the mod's reload features.",
        key_bind = {}
      },
      reloadExtractors = {
        command_name = "reload",
        help_message =
        "Reload stopped (bugged) extractors. IMPORTANT: Only extractors near the player will be processed.",
        key_bind = {
          key = Key.E,
          modifierKey = { ModifierKey.CONTROL, ModifierKey.SHIFT }
        }
      },

      reloadExtractorsWithPlayerTeleportation = {
        command_name = "reloadTP",
        help_message = "Reload ALL stopped (bugged) extractors using player teleportation.\n" ..
            "IMPORTANT:\n" ..
            "* This command teleports\n" ..
            "the player to every stopped extractor to reload them one by one.\n" ..
            "Once finished, the player is teleported back to their starting point.\n" ..
            "* If you are teleported into a storm,\n" ..
            "you will die because the `storm` timer does not stop.",
        key_bind = {
          key = Key.E,
          modifierKey = { ModifierKey.ALT, ModifierKey.CONTROL, ModifierKey.SHIFT }
        }
      },
      teleportToExtractor = {
        command_name = "tp",
        help_message =
        "Teleport to a specific extractor. (ex: 'tp 2'). If the number is omitted, it defaults to the first one ('tp' = 'tp 1').",
        key_bind = {}
      },
      teleportToStoppedExtractor = {
        command_name = "tpStopped",
        help_message =
        "Teleport to a specific stopped extractor. (ex: 'tp 2'). If the number is omitted, it defaults to the first one ('tp' = 'tp 1').",
        key_bind = {}
      },
      teleportBack = {
        command_name = "tpBack",
        help_message =
        "Teleport back to the previous saved location. (Note: You must use 'tp' or 'tpStopped' first to save your current position).",
        key_bind = {}
      },
      getNumberOfExtractors = {
        command_name = "getNum",
        help_message = "Display (in the game console) the total count of extractors.",
        key_bind = {}
      },
      stopBackgroundAutoReload = {
        command_name = "stopBgAutoReload",
        help_message = "Stop the automatic background reload loop.",
        key_bind = {}
      },
      destroyExtractor = {
        command_name = "destroy",
        help_message = "Destroy a specific extractor by its number (ex: 'destroy 2').",
      }
    }
  },
  delays = {
    -- Delay (in milliseconds) after PickUp before attempting to reload.
    -- This applies specifically to the 'reloadExtractorsWithPlayerTeleportation' command.
    -- If extractors fail to restart during teleportation, try increasing this value.
    delayBeforeReload = 2500,

    -- Delay (in frames) between teleporting to each extractor.
    -- This applies specifically to the 'reloadExtractorsWithPlayerTeleportation' command.
    -- If extractors fail to restart during teleportation, try increasing this value.
    loopInterval = 120,

    -- Teleport the player back to their original location after N frames.
    -- Used with `reloadExtractorsWithPlayerTeleportation`.
    teleportBack = 120,

    -- Delay (in milliseconds) for the background check loop.
    -- The `reloadExtractors` command will be executed every N seconds for reload stopped extractors.
    -- IMPORTANT: THe command (reloadExtractors) works only for extractors that are near the player.
    backgroundAutoReloadDelay = 10000,
    enableBackgroundAutoReload = true
  },
  -- Vertical offset to avoid teleporting exactly inside the extractor's collision.
  offsetUp = 1100,
}

return options
