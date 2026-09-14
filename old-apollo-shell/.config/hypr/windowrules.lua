-- Float common utility dialogs
hl.window_rule({
 name = "float-pavucontrol",
 match = { class = "^(pavucontrol)$" },
 float = true,
})
hl.window_rule({
 name = "float-blueman",
 match = { class = "^(blueman-manager)$" },
 float = true,
})
hl.window_rule({
 name = "float-file-dialogs",
 match = { class = "^(xdg-desktop-portal-gtk)$" },
 float = true,
})
-- Picture-in-picture: float, pin above other windows, keep it small
hl.window_rule({
 name = "pip-float",
 match = { title = "^(Picture-in-Picture)$" },
 float = true,
 pin = true,
})

-- Thunar: semi-transparent so Hyprland's existing blur shows through it,
-- matching the frosted-glass look used across the bar/panels/hyprlock.
-- Testing at an obvious 30% first to confirm the effect works at all.
hl.window_rule({
 name = "thunar-glass",
 match = { class = "^([Tt]hunar)$" },
 opacity = "0.60 override 0.60 override",
})
