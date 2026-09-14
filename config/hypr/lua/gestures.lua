-- Touchscreen gestures via the hyprgrass plugin.
--
-- Hyprland's native hl.gesture() is trackpad-only (see input.lua); this
-- covers actual touch input. It needs the plugin installed and loaded:
--
--   hyprpm add https://github.com/horriblename/hyprgrass
--   hyprpm enable hyprgrass
--
-- autostart.lua runs `hyprpm reload -n` on session start. Without the
-- plugin, hl.plugin.hyprgrass is nil and this file errors out — harmlessly,
-- since each require() is its own scope, but the gestures won't work.

-- 3-finger horizontal swipe: switch workspace (matches the touchpad gesture)
hl.plugin.hyprgrass.gesture({
    pattern = { kind = "swipe", fingers = 3, direction = "horizontal" },
    action  = "workspace",
})

-- 3-finger swipe down: close focused window
hl.plugin.hyprgrass.gesture({
    pattern = { kind = "swipe", fingers = 3, direction = "down" },
    action  = "close",
})
