-- ╭──────────────────────────────────────────────────────────────────────╮
-- │  Apollo — a Hyprland rice                                            │
-- │                                                                      │
-- │  A remake of Moonlit-shell (github.com/Fi3w0/Moonlit-shell),         │
-- │  translated from hyprlang (.conf) to Hyprland's Lua configuration.   │
-- ╰──────────────────────────────────────────────────────────────────────╯
--
-- Order matters — env must run before anything spawns, and keybinds/rules want
-- the palette from `lua.config`.
--
-- An error in any module stops every one after it. This comment used to claim
-- the opposite ("each require() is its own scope"), which is true of *scope*
-- and false of *control flow*: require does not pcall, so when gestures.lua
-- errored on a missing plugin, rules, keybinds and autostart never ran, and a
-- missing touchscreen plugin cost the touchpad and every keybind. The modules
-- are each written to load on a machine that has none of the optional pieces,
-- and scripts/test-hypr-lua.lua runs them to prove it.

require("lua.env")
require("lua.monitors")
require("lua.appearance")
require("lua.animations")
require("lua.input")
require("lua.rules")
require("lua.keybinds")
require("lua.autostart")

-- Last, deliberately. It is the only module that depends on a third-party
-- plugin, so if it ever does fail it takes nothing with it.
require("lua.gestures")

-- Overrides written by apollo-settings. Must stay last so its values shadow
-- everything above.
--
-- dofile, not require: require caches by module name, so after the settings
-- app rewrites this file and calls `hyprctl reload`, a cached copy could be
-- served instead of the new one. dofile always re-reads. pcall keeps a fresh
-- install, where the file doesn't exist yet, from erroring out.
local cfg_dir = (os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config")) .. "/hypr"
pcall(dofile, cfg_dir .. "/lua/generated.lua")
