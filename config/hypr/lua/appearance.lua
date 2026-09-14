-- Look and feel: gradient borders, tight gaps, frosted-glass blur.
--
-- Translated from Apollo's general.conf + decoration.conf. The hyprlang
-- `general { ... }` / `decoration { blur { ... } }` blocks map directly onto
-- nested Lua tables passed to hl.config().

local cfg = require("lua.config")
local p = cfg.palette

hl.config({
    general = {
        gaps_in     = cfg.gaps_in,
        gaps_out    = cfg.gaps_out,
        border_size = cfg.border_size,

        col = {
            active_border   = cfg.border_active,
            inactive_border = cfg.border_inactive,
        },

        layout           = "dwindle",
        resize_on_border = true,
        allow_tearing    = false,
    },

    decoration = {
        rounding = cfg.rounding,

        active_opacity   = 1.0,
        inactive_opacity = 0.92,

        blur = {
            enabled           = true,
            size              = 4,
            passes            = 2,
            new_optimizations = true,
            ignore_opacity    = true,
            xray              = false,

            -- Frosted glass, kept subtle: enough saturation to keep colors
            -- alive behind the panels without the smeared-neon look.
            vibrancy          = 0.1,
            vibrancy_darkness = 0.05,
            noise             = 0.008,
            contrast          = 1.0,
            brightness        = 1.0,
        },

        shadow = {
            enabled        = true,
            range          = 16,
            render_power   = 3,
            color          = "rgba(" .. p.crust .. "aa)",
            color_inactive = "rgba(" .. p.crust .. "55)",
        },
    },

    dwindle = {
        preserve_split = true,
        smart_split    = false,
    },

    master = {
        new_status = "master",
    },
})
