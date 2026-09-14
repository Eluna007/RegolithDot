-- Monitors.
--
-- An empty `output` is the fallback rule: any monitor without an explicit
-- rule gets its preferred mode, auto position, and 1x scale. This is the
-- Lua spelling of Apollo's `monitor = ,preferred,auto,1`.
--
-- To pin a specific display, add a rule above this one, e.g.:
--   hl.monitor({ output = "eDP-1", mode = "1920x1080@60", position = "0x0", scale = 1 })

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
