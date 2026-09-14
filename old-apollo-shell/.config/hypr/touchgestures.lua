-- Touchscreen gestures via the hyprgrass plugin
-- (Hyprland's native hl.gesture() is trackpad-only; this covers actual touch input)

-- 3-finger horizontal swipe: switch workspace (matches touchpad gesture)
hl.plugin.hyprgrass.gesture({
 pattern = { kind = "swipe", fingers = 3, direction = "horizontal" },
 action = "workspace",
})

-- 3-finger swipe down: close focused window
hl.plugin.hyprgrass.gesture({
 pattern = { kind = "swipe", fingers = 3, direction = "down" },
 action = "close",
})
