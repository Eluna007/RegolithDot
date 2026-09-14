-- Animations: snappy windows, horizontal workspace slide, rotating border.
--
-- Translated from Apollo's animations.conf. Two shape changes from hyprlang:
--
--   bezier = NAME, X0, Y0, X1, Y1
--     becomes hl.curve(NAME, { type = "bezier", points = { {X0,Y0}, {X1,Y1} } })
--
--   animation = LEAF, ENABLED, SPEED, CURVE, STYLE
--     becomes hl.animation({ leaf = LEAF, enabled = ..., speed = ..., bezier = ..., style = ... })
--
-- `speed` is unchanged: deciseconds, so speed = 3 is a 300ms animation.

hl.curve("easeOutExpo", { type = "bezier", points = { {0.16, 1},    {0.3,  1}   } })
hl.curve("easeInOut",   { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}   } })
hl.curve("overshot",    { type = "bezier", points = { {0.05, 0.9},  {0.1,  1.1} } })
hl.curve("liner",       { type = "bezier", points = { {1,    1},    {1,    1}   } })

hl.config({ animations = { enabled = true } })

-- Windows pop in past their final size (overshot) and slide out.
hl.animation({ leaf = "windows",     enabled = true, speed = 3,  bezier = "overshot",  style = "slide" })
hl.animation({ leaf = "windowsIn",   enabled = true, speed = 3,  bezier = "overshot",  style = "slide" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 3,  bezier = "easeInOut", style = "slide" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4,  bezier = "easeInOut" })

hl.animation({ leaf = "border",      enabled = true, speed = 10, bezier = "default" })

-- The rotating gradient border. Note: the `loop` style makes Hyprland render
-- a new frame every refresh whether or not a border is on screen, which costs
-- battery on a laptop. Drop the style (or the whole line) to stop the spin.
hl.animation({ leaf = "borderangle", enabled = true, speed = 30, bezier = "liner",     style = "loop" })

hl.animation({ leaf = "fade",        enabled = true, speed = 4,  bezier = "easeInOut" })
hl.animation({ leaf = "fadeDim",     enabled = true, speed = 4,  bezier = "easeInOut" })

-- Workspaces slide left/right instead of cross-fading.
hl.animation({ leaf = "workspaces",  enabled = true, speed = 4,  bezier = "easeOutExpo", style = "slide" })
