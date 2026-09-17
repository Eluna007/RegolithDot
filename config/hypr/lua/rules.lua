-- Window and layer rules.
--
-- Apollo's rules merged with those from the pre-Apollo config. Hyprland
-- evaluates these top to bottom and the *last* match wins, so the broad
-- rules come first and the specific ones after.
--
-- `opacity` takes a single string, not two numbers: "<active> <inactive>",
-- optionally "<active> <inactive> <fullscreen>". Values multiply with
-- decoration.active_opacity / inactive_opacity unless you append " override".

-- ── Layers ───────────────────────────────────────────────────────────────
-- Blur the shell's layer surfaces (bar, panels, OSD) so they read as frosted
-- glass over the wallpaper. The namespace is "quickshell" — that's what
-- Quickshell registers with the compositor by default, regardless of what the
-- config directory is called. Check with `hyprctl layers` if it ever misses.
hl.layer_rule({
    name         = "blur-shell",
    match        = { namespace = "^(quickshell)$" },
    blur         = true,
    ignore_alpha = 0.2,
})

-- ── Floating utility dialogs ─────────────────────────────────────────────
hl.window_rule({
    name  = "float-pavucontrol",
    match = { class = "^(pavucontrol)$" },
    float = true,
})

hl.window_rule({
    name  = "float-blueman",
    match = { class = "^(blueman-manager)$" },
    float = true,
})

-- Picture-in-picture: float, pin above other windows, keep it out of the way.
hl.window_rule({
    name  = "pip-float",
    match = { title = "^(Picture-in-Picture)$" },
    float = true,
    pin   = true,
})

-- Portal file chooser: float it, center it, and give it the same rounding as
-- everything else so it doesn't land as a square grey box mid-screen.
hl.window_rule({
    name        = "portal-filechooser",
    match       = { class = "^([Xx]dg-desktop-portal-gtk)$" },
    float       = true,
    center      = true,
    border_size = 2,
    rounding    = 10,
    opacity     = "0.95 0.92",
})

-- ── Frosted windows ──────────────────────────────────────────────────────
-- Terminal frost is handled by kitty itself (background_opacity in
-- kitty.conf), so the global blur shows through without a rule here.

-- Thunar. The class is capital-T "Thunar" on Arch, so Moonlit's lowercase-only
-- `^(thunar)$` never matched — the case-insensitive first letter comes from
-- the pre-Apollo config and is what actually makes this rule fire.
hl.window_rule({
    name    = "thunar-frost",
    match   = { class = "^([Tt]hunar)$" },
    opacity = "0.88 0.85",
})

hl.window_rule({
    name    = "prism-frost",
    match   = { class = "^(PrismLauncher|prismlauncher|org\\.prismlauncher\\.PrismLauncher)$" },
    opacity = "0.78 0.74",
})

-- Apollo Settings. Matched by title, not class: it's a Fyne app, and under
-- Xwayland it leaves the class empty.
hl.window_rule({
    name     = "apollo-settings",
    match    = { title = "^(Apollo Settings)$" },
    float    = true,
    center   = true,
    rounding = 12,
    opacity  = "0.94 0.90",
})
