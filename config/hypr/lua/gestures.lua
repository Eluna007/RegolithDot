-- Touchscreen gestures via the hyprgrass plugin.
--
-- Hyprland's native hl.gesture() is trackpad-only (see input.lua); this
-- covers actual touch input. It needs the plugin installed and loaded:
--
--   hyprpm add https://github.com/horriblename/hyprgrass
--   hyprpm enable hyprgrass
--
-- This file used to call hl.plugin.hyprgrass.gesture() unguarded, with a
-- comment claiming that errored out "harmlessly" when the plugin was missing.
-- It does not. Hyprland reports "Your config has errors", stops loading, and
-- falls back to a handful of emergency binds — so a missing *touchscreen*
-- plugin took the touchpad, the keybinds and the window rules down with it.
-- That is what a reboot after a Hyprland or kernel update looks like: hyprpm
-- needs the plugin rebuilt against the new headers, and until it is, the
-- plugin does not load.
--
-- autostart.lua runs `hyprpm reload -n` on session start, but that is an
-- event handler: it fires *after* the config is parsed, so on a cold boot the
-- plugin is not loaded yet when this file runs. The guard is not belt and
-- braces, it is the normal path.
local grass = hl.plugin and hl.plugin.hyprgrass

if not grass then
    -- Not a warning worth printing on every start: a machine with no
    -- touchscreen never wants this plugin, and the rest of the desktop is
    -- unaffected. `hyprpm list` says whether it is loaded.
    return
end

-- 3-finger horizontal swipe: switch workspace (matches the touchpad gesture)
grass.gesture({
    pattern = { kind = "swipe", fingers = 3, direction = "horizontal" },
    action  = "workspace",
})

-- 3-finger swipe down: close focused window
grass.gesture({
    pattern = { kind = "swipe", fingers = 3, direction = "down" },
    action  = "close",
})
