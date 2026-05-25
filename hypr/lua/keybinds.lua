local cfg = require("lua.config")
local mod = cfg.mod

-- Helpers
local function bind(key, action, opts)
    hl.bind(mod .. " + " .. key, action, opts or {})
end

local function bind_shift(key, action, opts)
    hl.bind(mod .. " + SHIFT + " .. key, action, opts or {})
end

local function bind_ctrl_alt(key, action)
    hl.bind("CTRL + ALT + " .. key, action, {})
end

local function bind_locked(key, action)
    hl.bind(key, action, { locked = true })
end

local function bind_locked_repeat(key, action)
    hl.bind(key, action, { locked = true, repeating = true })
end

-- ── Terminal & Apps ──────────────────────────────────────────
bind("Return",    hl.dsp.exec_cmd(cfg.terminal))
bind("E",         hl.dsp.exec_cmd(cfg.filemanager))
bind("D",         hl.dsp.exec_cmd(cfg.menu))
bind("W",         hl.dsp.exec_cmd("qs -p ~/.config/quickshell/wallpaper-picker/Main.qml"))
bind("V",         hl.dsp.exec_cmd("bash -c 'cliphist list | rofi -dmenu -p \"Clipboard\" | cliphist decode | wl-copy'"))

-- ── Window Management ────────────────────────────────────────
bind("Q",         hl.dsp.window.close())
bind("SPACE",     hl.dsp.window.float({ action = "toggle" }))
bind("P",         hl.dsp.window.pseudo())
bind("J",         hl.dsp.layout("togglesplit"))
bind_shift("F",   hl.dsp.window.fullscreen({ mode = 1 }))
bind_shift("I",   hl.dsp.layout("togglesplit"))

-- ── Focus (Arrow keys + HJKL) ────────────────────────────────
bind("left",      hl.dsp.focus({ direction = "left" }))
bind("right",     hl.dsp.focus({ direction = "right" }))
bind("up",        hl.dsp.focus({ direction = "up" }))
bind("down",      hl.dsp.focus({ direction = "down" }))
bind("h",         hl.dsp.focus({ direction = "left" }))
bind("l",         hl.dsp.focus({ direction = "right" }))
bind("k",         hl.dsp.focus({ direction = "up" }))
bind("j",         hl.dsp.focus({ direction = "down" }))

-- ── Move Windows ─────────────────────────────────────────────
bind_shift("left",  hl.dsp.window.move({ direction = "left" }))
bind_shift("right", hl.dsp.window.move({ direction = "right" }))
bind_shift("up",    hl.dsp.window.move({ direction = "up" }))
bind_shift("down",  hl.dsp.window.move({ direction = "down" }))

-- ── Workspaces ───────────────────────────────────────────────
for i = 1, 10 do
    local key = i % 10
    hl.bind(mod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- ── Scratchpad ───────────────────────────────────────────────
bind("minus",       hl.dsp.workspace.toggle_special("magic"))
bind_shift("minus", hl.dsp.window.move({ workspace = "special:magic" }))

-- ── Screenshots ──────────────────────────────────────────────
bind("Print",             hl.dsp.exec_cmd("grim ~/Pictures/Screenshots/$(date +%Y%m%d_%H%M%S).png"))
bind_shift("Print",       hl.dsp.exec_cmd("grim -g \"$(slurp)\" ~/Pictures/Screenshots/$(date +%Y%m%d_%H%M%S).png"))
bind_shift("S",           hl.dsp.exec_cmd("grim -g \"$(slurp)\" - | swappy -f -"))
hl.bind("CTRL + Print",   hl.dsp.exec_cmd("bash -c 'sleep 5 && grim ~/Pictures/Screenshots/$(date +%Y%m%d_%H%M%S).png'"), {})
hl.bind("ALT + Print",    hl.dsp.exec_cmd("bash -c 'grim -g \"$(hyprctl activewindow -j | jq -r \".at,.size\" | awk \\'NR==1{x=$1;y=$2} NR==2{print x\",\"y\" \"$1\"x\"$2}\\')\" ~/Pictures/Screenshots/$(date +%Y%m%d_%H%M%S).png'"), {})

-- ── System ───────────────────────────────────────────────────
bind_ctrl_alt("L",   hl.dsp.exec_cmd("bash -c 'bash ~/.config/hypr/scripts/lockscreen-weather.sh & hyprlock'"))
bind_ctrl_alt("Delete", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch exit"))
bind_shift("N",      hl.dsp.exec_cmd("swaync-client --toggle-panel"))

-- ── Mouse ────────────────────────────────────────────────────
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mod .. " + mouse:272",  hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273",  hl.dsp.window.resize(), { mouse = true })

-- ── Media & Brightness ───────────────────────────────────────
bind_locked_repeat("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"))
bind_locked_repeat("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"))
bind_locked_repeat("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
bind_locked_repeat("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"))
bind_locked_repeat("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"))
bind_locked_repeat("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"))
bind_locked("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"))
bind_locked("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"))
bind_locked("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"))
bind_locked("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"))
