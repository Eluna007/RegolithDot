-- Springy/bouncy animation curves
-- Tune stiffness (snappier = higher) and damping (bouncier = lower) to taste

hl.curve("bouncy", { type = "spring", mass = 1, stiffness = 170, dampening = 14 })
hl.curve("bouncySoft", { type = "spring", mass = 1, stiffness = 120, dampening = 16 })

hl.animation({ leaf = "windows", enabled = true, speed = 5, spring = "bouncy", style = "popin 80%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 4, spring = "bouncySoft" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, spring = "bouncy", style = "slide" })
hl.animation({ leaf = "fade", enabled = true, speed = 4, spring = "bouncySoft" })
hl.animation({ leaf = "border", enabled = true, speed = 5, spring = "bouncySoft" })
