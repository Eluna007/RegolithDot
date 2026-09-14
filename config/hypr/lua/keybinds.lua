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
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(env.terminal))
hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd(env.launcher))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + M", hl.dsp.exit())
hl.bind(mainMod .. " + V", hl.dsp.window.float())
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))

-- Move focus (vim style)
hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "down" }))

-- Switch Workspaces (1-9, 0)
for i = 1, 10 do
    local key = tostring(i % 10)
    local ws = tostring(i)
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = ws }))
end

-- Resize submap
hl.bind(mainMod .. " + S", hl.dsp.submap("resize"))
hl.define_submap("resize", function()
    hl.bind("H", hl.dsp.window.resize({ x = -20, y = 0, relative = true }))
    hl.bind("L", hl.dsp.window.resize({ x = 20, y = 0, relative = true }))
    hl.bind("K", hl.dsp.window.resize({ x = 0, y = -20, relative = true }))
    hl.bind("J", hl.dsp.window.resize({ x = 0, y = 20, relative = true }))
    hl.bind("Escape", hl.dsp.submap("reset"))
end)

-- Window overview (Alt+Tab style switcher)
hl.bind(mainMod .. " + Tab", hl.dsp.exec_cmd("qs -c apollo ipc call panel toggle overview"))

-- Wallpaper carousel
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("qs -c apollo ipc call panel toggle wallpaper"))

-- Screenshot
hl.bind("XF86SelectiveScreenshot", hl.dsp.exec_cmd(
    "grim -g \"$(slurp)\" - | satty --filename - " ..
    "--output-filename ~/Pictures/screenshot-$(date +%s).png --copy-command \"wl-copy\""))

-- Toggle between dwindle and master layouts
hl.bind(mainMod .. " + SHIFT + SPACE", function()
    local current = hl.get_config("general.layout")
    if current == "dwindle" then
        hl.config({ general = { layout = "master" } })
    else
        hl.config({ general = { layout = "dwindle" } })
    end
end)

-- Media keys (volume/mute) — routed through osd-report.sh so the shell's
-- OSD pops up for any trigger, not just clicking the bar icon.
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("~/.local/bin/osd-report.sh volume raise"))
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("~/.local/bin/osd-report.sh volume lower"))
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("~/.local/bin/osd-report.sh volume mute"))
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("~/.local/bin/osd-report.sh mic mute"))

-- Brightness keys
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("~/.local/bin/osd-report.sh brightness raise"))
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("~/.local/bin/osd-report.sh brightness lower"))
