# Hyprland in Lua

Apollo configures Hyprland through `hyprland.lua` rather than `hyprland.conf`. This is what that means in practice, and what is where.

[← back to the README](../README.md)

## What's here

```
config/hypr/            Hyprland — Lua
  hyprland.lua            entry point; requires the modules below
  lua/config.lua          palette + shared knobs (retheme starts here)
  lua/env.lua             environment variables
  lua/monitors.lua        monitor rules
  lua/appearance.lua      general + decoration + blur + shadow
  lua/animations.lua      curves and the animation tree
  lua/input.lua           touchpad + native trackpad gestures
  lua/gestures.lua        touchscreen gestures (needs the hyprgrass plugin)
  lua/rules.lua           window + layer rules
  lua/keybinds.lua        keybinds
  lua/autostart.lua       hyprland.start handler
  hypridle.conf           hypridle — still hyprlang, it's a separate binary

config/quickshell/apollo/   the shell: bar/, panels/, services/, shell.qml
config/hyprlock/            lock screen: 4 layouts + their scripts
config/matugen/             colour generation, incl. the hyprlock template
config/rofi/                themes + launcher/emoji/keybind modes
config/{kitty,fish,nvim,gtk-3.0,gtk-4.0,ranger,Thunar,fastfetch,keyd,dgop}
config/xdg-desktop-portal/

apollo-settings/        Go/Fyne GUI for the safe knobs; generates Lua
scripts/apollo-doctor   health check
local/bin/              wallpaper pipeline, OSD bridge, game wrappers
local/share/            icon theme, .desktop entry, PrismLauncher theme
sddm/                   SDDM theme drop-in
```

`config/hypr/hyprlock.conf` stays hyprlang too (hyprlock is its own binary),
and unlike the rest of `config/hypr/` it is *not* Moonlit's — see
[Theming](theming.md).

See [MANUAL-INSTALL.md](../MANUAL-INSTALL.md) to deploy it.

## What the translation changed

Most of the port is mechanical — `general { }` becomes a Lua table, `bind =`
becomes `hl.bind()`. These are the places where it wasn't:

| Moonlit (hyprlang) | Apollo (Lua) | Why |
|---|---|---|
| `exec-once = foo` | `hl.on("hyprland.start", ...)` | Fires once per session, so `hyprctl reload` no longer duplicates every daemon |
| `bindel = , XF86…` | `{ locked = true, repeating = true }` | The `e`/`l` suffix letters became named flags |
| `bindm = …` | `{ mouse = true }` | Same |
| `tap-to-click = true` | `tap_to_click = true` | Lua identifiers can't contain hyphens |
| `drag_lock = true` | `drag_lock = 1` | No longer a bool: 0 off, 1 on with timeout, 2 sticky |
| `scroll_method = 2fg` | `scroll_method = "2fg"` | Now a string |
| `bezier = name, …` | `hl.curve(name, { type = "bezier", points = … })` | |
| `opacity = 0.88 0.85` | `opacity = "0.88 0.85"` | One string, not two numbers |
| `~/.config/hypr/moonlit.conf` | `~/.config/hypr/lua/generated.lua` | What apollo-settings writes |

Two things beyond the config files had to follow:

- **The shell's Hyprland calls.** `Hyprland.dispatch("workspace 3")` is dead —
  the IPC takes Lua expressions now. All of them go through
  `config/quickshell/apollo/services/Hypr.qml`, which sends
  `hl.dsp.focus({ workspace = 3 })` as an argv array so Lua's braces and quotes
  never meet a shell.
- **The keybind cheatsheet.** Moonlit's `rofi` mode parsed `keybinds.conf` line
  by line. That can't work against Lua, where a `for i = 1, 4` loop registers
  four binds that appear nowhere in the file as text. It reads `hyprctl binds -j`
  instead, which is what "never drifts from what's bound" always meant. Needs `jq`.

## Keybinds, input and gestures

`lua/keybinds.lua`, `lua/input.lua` and `lua/gestures.lua` are from the
pre-Apollo config, not
Moonlit's — carried over when Apollo was deployed. Notable differences from
upstream: `natural_scroll = false`, `disable_while_typing = false`, a vim-style
focus/resize layout with a resize submap, and touchscreen gestures via the
[hyprgrass](https://github.com/horriblename/hyprgrass) plugin, which Moonlit
had no equivalent for.

Nothing else in `lua/` imports these three, so they stay easy to swap.
