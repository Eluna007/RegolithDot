-- Shared knobs for the Apollo Hyprland config.
--
-- Every other module in lua/ pulls its values from here, so retheming is a
-- one-file job. In hyprlang this was a scatter of `$variables`; Lua gives us
-- a real table we can nest and reuse.

local M = {}

-- ── Catppuccin Mocha ─────────────────────────────────────────────────────
-- Apollo's palette, kept as-is. Hex only (no rgba() wrapper) so callers can
-- pick their own alpha per use.
M.palette = {
    rosewater = "f5e0dc",
    flamingo  = "f2cdcd",
    pink      = "f5c2e7",
    mauve     = "cba6f7",
    red       = "f38ba8",
    maroon    = "eba0ac",
    peach     = "fab387",
    yellow    = "f9e2af",
    green     = "a6e3a1",
    teal      = "94e2d5",
    sky       = "89dceb",
    sapphire  = "74c7ec",
    blue      = "89b4fa",
    lavender  = "b4befe",
    text      = "cdd6f4",
    subtext0  = "a6adc8",
    surface0  = "313244",
    base      = "1e1e2e",
    crust     = "11111b",
}

local p = M.palette

-- ── Core apps ────────────────────────────────────────────────────────────
M.terminal    = "kitty"
M.filemanager = "thunar"
M.launcher    = "rofi -show combi"
M.settings    = "apollo-settings"

-- ── Layout ───────────────────────────────────────────────────────────────
M.gaps_in     = 3
M.gaps_out    = 8
M.border_size = 2
M.rounding    = 10

-- ── Borders ──────────────────────────────────────────────────────────────
-- pink → mauve → blue, rotated continuously by the `borderangle` animation.
M.border_active = {
    colors = {
        "rgba(" .. p.red .. "ee)",
        "rgba(" .. p.mauve .. "ee)",
        "rgba(" .. p.blue .. "ee)",
    },
    angle = 45,
}
M.border_inactive = "rgba(" .. p.surface0 .. "aa)"

-- ── Paths ────────────────────────────────────────────────────────────────
M.home        = os.getenv("HOME") or ""
M.wallpapers  = M.home .. "/Pictures/Wallpapers"
M.screenshots = M.home .. "/Pictures/Screenshots"

return M
