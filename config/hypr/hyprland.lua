-- ╭──────────────────────────────────────────────────────────────────────╮
-- │  Apollo — a Hyprland rice                                            │
-- │                                                                      │
-- │  A remake of Apollo-shell (github.com/Fi3w0/Apollo-shell),         │
-- │  translated from hyprlang (.conf) to Hyprland's Lua configuration.   │
-- ╰──────────────────────────────────────────────────────────────────────╯
--
-- Each require() is its own Lua scope: an error in one module does not stop
-- the others from loading. Order matters — env must run before anything
-- spawns, and keybinds/rules want the palette from `lua.config`.

require("lua.env")
require("lua.monitors")
require("lua.appearance")
require("lua.animations")
require("lua.input")
require("lua.rules")
require("lua.keybinds")
require("lua.autostart")

-- Overrides written by apollo-settings. Must stay last so its values shadow
-- everything above.
--
-- dofile, not require: require caches by module name, so after the settings
-- app rewrites this file and calls `hyprctl reload`, a cached copy could be
-- served instead of the new one. dofile always re-reads. pcall keeps a fresh
-- install, where the file doesn't exist yet, from erroring out.
local cfg_dir = (os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config")) .. "/hypr"
pcall(dofile, cfg_dir .. "/lua/generated.lua")
