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
            disable_while_typing   = false,
        },
    },
})

hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})
hl.gesture({ fingers = 3, direction = "up", action = function() hl.exec_cmd("caelestia shell drawers toggle launcher") end })
hl.gesture({ fingers = 3, direction = "down", action = function() hl.exec_cmd("caelestia shell drawers toggle dashboard") end })
hl.gesture({ fingers = 4, direction = "up", action = function() hl.exec_cmd("caelestia shell drawers toggle session") end })
hl.gesture({ fingers = 4, direction = "down", action = function() hl.exec_cmd("caelestia shell drawers toggle sidebar") end })
hl.gesture({ fingers = 4, direction = "horizontal", action = "move" })
hl.gesture({ fingers = 3, direction = "left", mods = "SUPER", action = "float", mode = "float" })
hl.gesture({ fingers = 3, direction = "right", mods = "SUPER", action = "float", mode = "tile" })
