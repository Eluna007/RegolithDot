-- Input: touchpad behaviour.
--
-- Translated from Apollo's input.conf. Two option names needed real changes,
-- not just reindentation:
--
--   tap-to-click  ->  tap_to_click
--     Lua identifiers can't contain hyphens, and the option's current name
--     uses an underscore anyway.
--
--   drag_lock = true  ->  drag_lock = 1
--     drag_lock is no longer a bool. It's 0 = off, 1 = on with timeout,
--     2 = on and sticky. 1 is the behaviour the old `true` gave you.

hl.config({
    input = {
        -- 2-finger scrolling, the touchpad norm.
        scroll_method = "2fg",

        touchpad = {
            natural_scroll       = true,
            tap_to_click         = true,
            disable_while_typing = true,
            drag_lock            = 1,

            -- Apollo dials scrolling down to 70%; the stock 1.0 overshoots
            -- badly on a high-resolution touchpad.
            scroll_factor        = 0.7,
        },
    },
})
