local cfg = require("lua.config")

hl.config({
    input = {
        kb_layout    = "us",
        follow_mouse = 1,
        sensitivity  = 0,
        touchpad = {
            natural_scroll         = true,
            tap_to_click           = true,
            tap_and_drag           = true,
            drag_lock              = true,
            scroll_factor          = 1.0,
            disable_while_typing   = true,
        },
    },
})

hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})
