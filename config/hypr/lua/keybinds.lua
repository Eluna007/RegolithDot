-- ╭──────────────────────────────────────────────────────────────────────╮
-- │  THIS IS THE FILE YOU REPLACE.                                       │
-- │                                                                      │
-- │  It's a faithful port of Apollo's keybinds.conf, kept so Apollo      │
-- │  boots usable out of the box. Nothing else in lua/ requires anything  │
-- │  from here, so you can overwrite the whole file with your own binds   │
-- │  and the rest of the config is unaffected.                           │
-- ╰──────────────────────────────────────────────────────────────────────╯
--
-- hyprlang -> Lua, for reference while you port your own:
--
--   bind  = SUPER, Q, exec, kitty   ->  hl.bind("SUPER + Q", hl.dsp.exec_cmd("kitty"))
--   bindm = SUPER, mouse:272, ...   ->  hl.bind(..., ..., { mouse = true })
--   bindel = , XF86...              ->  hl.bind(..., ..., { locked = true, repeating = true })
--                                       (e = repeating, l = locked)
--
-- exec_cmd runs through `sh -c`, so $(...), pipes, and $HOME all still work.

local cfg = require("lua.config")
local mod = "SUPER"

local function bind(keys, action, flags)
    hl.bind(mod .. " + " .. keys, action, flags or {})
end

-- ── Apps ─────────────────────────────────────────────────────────────────
bind("Q",     hl.dsp.exec_cmd(cfg.terminal), { description = "Terminal" })
bind("Space", hl.dsp.exec_cmd(cfg.launcher), { description = "App launcher" })
bind("comma", hl.dsp.exec_cmd(cfg.settings), { description = "Apollo Settings" })

-- ── Windows ──────────────────────────────────────────────────────────────
bind("W",   hl.dsp.window.close(),      { description = "Close window" })
bind("Tab", hl.dsp.window.cycle_next(), { description = "Next window" })
bind("F",   hl.dsp.window.fullscreen(), { description = "Fullscreen" })
bind("P",   hl.dsp.window.float(),      { description = "Toggle floating" })

hl.bind("ALT + Tab", hl.dsp.exec_cmd("qs -c apollo ipc call panel toggle overview"),
    { description = "Window overview" })

-- ── Workspaces ───────────────────────────────────────────────────────────
-- Apollo ships four. Widen the range if you want more.
for i = 1, 4 do
    bind(tostring(i), hl.dsp.focus({ workspace = i }),
        { description = "Workspace " .. i })
    hl.bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }),
        { description = "Move to workspace " .. i })
end

-- ── Wallpaper ────────────────────────────────────────────────────────────
bind("B", hl.dsp.exec_cmd("qs -c apollo ipc call panel toggle wallpaper"),
    { description = "Wallpaper picker" })

-- Random wallpaper. flock keeps a held-down key from starting a pile of
-- concurrent transitions; the trailing sleep holds the lock until the
-- crossfade finishes.
bind("SHIFT + B", hl.dsp.exec_cmd(
    [[flock -n /tmp/wallrand.lock -c 'W=$(find ]] .. cfg.wallpapers ..
    [[ -type f | shuf -n1); awww img "$W" -t grow --transition-fps 60 ]] ..
    [[--transition-duration 1.1 --resize crop && printf "%s" "$W" > ]] ..
    [[~/.cache/wallpaper-current; sleep 1.3']]
), { description = "Random wallpaper" })

-- ── Rofi extras ──────────────────────────────────────────────────────────
hl.bind("ALT + period", hl.dsp.exec_cmd(
    [[rofi -show emoji -modi "emoji:$HOME/.config/rofi/scripts/emoji.sh" ]] ..
    [[-theme $HOME/.config/rofi/themes/emoji.rasi]]
), { description = "Emoji picker" })

hl.bind("ALT + slash", hl.dsp.exec_cmd(
    [[rofi -show keybinds -modi "keybinds:$HOME/.config/rofi/scripts/keybinds.sh" ]] ..
    [[-theme $HOME/.config/rofi/themes/keybinds.rasi]]
), { description = "Keybind cheatsheet" })

-- ── Screenshots ──────────────────────────────────────────────────────────
-- Saved to disk and copied to the clipboard in one pass; the cliphist watcher
-- picks the image up from there automatically.
local shot_dir = cfg.screenshots

hl.bind("ALT + S", hl.dsp.exec_cmd(
    "mkdir -p " .. shot_dir .. [[ && grim -g "$(slurp)" - | tee ]] ..
    shot_dir .. [[/$(date +%Y-%m-%d_%H-%M-%S).png | wl-copy --type image/png]]
), { description = "Screenshot region" })

hl.bind("ALT + D", hl.dsp.exec_cmd(
    "mkdir -p " .. shot_dir .. [[ && grim - | tee ]] ..
    shot_dir .. [[/$(date +%Y-%m-%d_%H-%M-%S).png | wl-copy --type image/png]]
), { description = "Screenshot screen" })

-- ── Brightness ───────────────────────────────────────────────────────────
-- locked so they work on the lock screen, repeating so holding the key ramps.
local brightness_flags = { locked = true, repeating = true }

hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(
    [[brightnessctl s 5%- && qs -c apollo ipc call osd set brightness ]] ..
    [[$(brightnessctl -m | cut -d, -f4 | tr -d %)]]
), brightness_flags)

hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(
    [[brightnessctl s 5%+ && qs -c apollo ipc call osd set brightness ]] ..
    [[$(brightnessctl -m | cut -d, -f4 | tr -d %)]]
), brightness_flags)

-- ── Mouse ────────────────────────────────────────────────────────────────
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
