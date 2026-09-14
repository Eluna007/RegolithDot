-- Luna's keybinds, carried over from the pre-Apollo config.
--
-- Kept verbatim except where a bind talked to the old shell. Apollo's
-- Quickshell config is a *named* one (~/.config/quickshell/apollo), so its
-- IPC is addressed as `qs -c apollo ipc call …`; a bare `qs ipc call` will
-- not find it. The panel names also differ: the old shell had one handler
-- per panel, Apollo has a single `panel toggle <name>`.
--
-- The keys themselves are unchanged.

local env = require("lua.config")
local mainMod = "SUPER"

-- Core app binds
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(env.terminal), { description = "Terminal" })
hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd(env.launcher), { description = "App launcher" })
hl.bind(mainMod .. " + Q", hl.dsp.window.close(), { description = "Close window" })
hl.bind(mainMod .. " + M", hl.dsp.exit(), { description = "Exit Hyprland" })
hl.bind(mainMod .. " + V", hl.dsp.window.float(), { description = "Toggle floating" })
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }), { description = "Fullscreen" })

-- Move focus (vim style)
hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "left" }),  { description = "Focus left" })
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "right" }), { description = "Focus right" })
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "up" }),    { description = "Focus up" })
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "down" }),  { description = "Focus down" })

-- Switch Workspaces (1-9, 0)
for i = 1, 10 do
    local key = tostring(i % 10)
    local ws = tostring(i)
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = ws }),
        { description = "Workspace " .. ws })
end

-- Resize submap
hl.bind(mainMod .. " + S", hl.dsp.submap("resize"), { description = "Resize mode" })
hl.define_submap("resize", function()
    hl.bind("H", hl.dsp.window.resize({ x = -20, y = 0, relative = true }), { description = "Shrink width" })
    hl.bind("L", hl.dsp.window.resize({ x = 20, y = 0, relative = true }),  { description = "Grow width" })
    hl.bind("K", hl.dsp.window.resize({ x = 0, y = -20, relative = true }), { description = "Shrink height" })
    hl.bind("J", hl.dsp.window.resize({ x = 0, y = 20, relative = true }),  { description = "Grow height" })
    hl.bind("Escape", hl.dsp.submap("reset"), { description = "Leave resize mode" })
end)

-- Window overview (Alt+Tab style switcher)
hl.bind(mainMod .. " + Tab", hl.dsp.exec_cmd("qs -c apollo ipc call panel toggle overview"),
    { description = "Window overview" })

-- Wallpaper carousel
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("qs -c apollo ipc call panel toggle wallpaper"),
    { description = "Wallpaper carousel" })

-- Screenshot
hl.bind("XF86SelectiveScreenshot", hl.dsp.exec_cmd(
    "grim -g \"$(slurp)\" - | satty --filename - " ..
    "--output-filename ~/Pictures/screenshot-$(date +%s).png --copy-command \"wl-copy\""),
    { description = "Screenshot region" })

-- Toggle between dwindle and master layouts
hl.bind(mainMod .. " + SHIFT + SPACE", function()
    local current = hl.get_config("general.layout")
    if current == "dwindle" then
        hl.config({ general = { layout = "master" } })
    else
        hl.config({ general = { layout = "dwindle" } })
    end
end, { description = "Toggle dwindle/master layout" })

-- Rofi extras. The launcher stays wofi (see lua/config.lua); rofi is here
-- only for these two modes. The cheatsheet reads `hyprctl binds -j`, so it
-- lists what is actually registered — including the ten workspace binds this
-- file generates in a loop, which no config-file parser would ever see.
-- Needs `rofi` and `jq`.
hl.bind("ALT + period", hl.dsp.exec_cmd(
    [[rofi -show emoji -modes "emoji:$HOME/.config/rofi/scripts/emoji.sh" ]] ..
    [[-theme $HOME/.config/rofi/themes/emoji.rasi]]
), { description = "Emoji picker" })

hl.bind("ALT + slash", hl.dsp.exec_cmd(
    [[rofi -show keybinds -modes "keybinds:$HOME/.config/rofi/scripts/keybinds.sh" ]] ..
    [[-theme $HOME/.config/rofi/themes/keybinds.rasi]]
), { description = "Keybind cheatsheet" })

-- Media keys (volume/mute) — routed through osd-report.sh so the shell's
-- OSD pops up for any trigger, not just clicking the bar icon.
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("~/.local/bin/osd-report.sh volume raise"), { description = "Volume up" })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("~/.local/bin/osd-report.sh volume lower"), { description = "Volume down" })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("~/.local/bin/osd-report.sh volume mute"),  { description = "Mute" })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("~/.local/bin/osd-report.sh mic mute"),     { description = "Mute microphone" })

-- Brightness keys
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("~/.local/bin/osd-report.sh brightness raise"), { description = "Brightness up" })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("~/.local/bin/osd-report.sh brightness lower"), { description = "Brightness down" })
