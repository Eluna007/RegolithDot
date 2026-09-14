-- Input: keyboard, touchpad, trackpad gestures.
--
-- Luna's settings, kept over Apollo's. The differences are deliberate
-- personal preferences, not defaults worth overwriting:
--
--   natural_scroll       = false  (Moonlit used true — reversed scrolling)
--   disable_while_typing = false  (Moonlit used true)
--   clickfinger_behavior = true   (2/3-finger clicks as right/middle)

hl.config({
    input = {
        kb_layout    = "us",
        follow_mouse = 1,
        sensitivity  = 0,

        touchpad = {
            natural_scroll       = false, -- traditional scroll direction
            tap_to_click         = true,
            disable_while_typing = false,
            clickfinger_behavior = true,
        },
    },
})

-- 3-finger horizontal swipe to switch workspaces.
-- This is Hyprland's native (trackpad-only) gesture support; touchscreen
-- swipes are handled separately in gestures.lua via hyprgrass.
hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})
