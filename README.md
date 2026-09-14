# Apollo

A Hyprland rice for Arch, built on Hyprland's **Lua** configuration.

Apollo is a remake of [Moonlit-shell](https://github.com/Fi3w0/Moonlit-shell) by
Fi3w0. Moonlit is written in hyprlang (`.conf`); Apollo is the same desktop
translated to `hyprland.lua`, with everything that talked to Hyprland through
the old dispatch syntax updated to match.

Catppuccin Mocha, a rotating gradient border, frosted-glass blur, and a
Quickshell bar with panels for audio, bluetooth, wifi, clipboard, calendar,
system stats, wallpaper and power.

---

## What's here

```
config/hypr/            Hyprland — Lua
  hyprland.lua            entry point; requires the modules below
  lua/config.lua          palette + shared knobs (retheme starts here)
  lua/env.lua             environment variables
  lua/monitors.lua        monitor rules
  lua/appearance.lua      general + decoration + blur + shadow
  lua/animations.lua      curves and the animation tree
  lua/input.lua           touchpad
  lua/rules.lua           window + layer rules
  lua/keybinds.lua        keybinds  ← the file you're meant to replace
  lua/autostart.lua       hyprland.start handler
  hypridle.conf           hypridle — still hyprlang, it's a separate binary
  hyprlock.conf           hyprlock  — likewise
  scripts/lock.sh

config/quickshell/apollo/   the shell: bar/, panels/, services/, shell.qml
config/rofi/                themes + launcher/emoji/keybind modes
config/{kitty,fish,nvim,gtk-3.0,gtk-4.0,ranger,Thunar,fastfetch,keyd,dgop}
config/xdg-desktop-portal/

apollo-settings/        Go/Fyne GUI for the safe knobs; generates Lua
scripts/apollo-doctor   health check
local/share/            icon theme, .desktop entry, PrismLauncher theme
sddm/                   SDDM theme drop-in
```

See [MANUAL-INSTALL.md](MANUAL-INSTALL.md) to deploy it.

---

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

---

## Keybinds

`config/hypr/lua/keybinds.lua` is a faithful port of Moonlit's bindings, kept
only so Apollo boots usable. Nothing else in `lua/` imports it — overwrite the
whole file with your own and the rest of the config doesn't notice.

The header of that file has the hyprlang → Lua cheatsheet for porting your own.

---

## Not included

Deliberately left out of this repo:

- **`install.sh`** — Moonlit's installer. Deploy with the symlinks in
  MANUAL-INSTALL.md instead.
- **Wallpapers** (25 MB) — `~/Pictures/Wallpapers` is expected to exist; the
  picker and `SUPER+SHIFT+B` read from it.
- **`Bibata-Modern-Classic` cursors** (27 MB) — install
  `bibata-cursor-theme` from the AUR.
- **Screenshots** — Moonlit's own, not Apollo's.

One upstream inconsistency is preserved as-is: `gtk-3.0/settings.ini` names
`Nero-Cyber-Cyan` as the cursor theme while Moonlit shipped Bibata. Point it at
whichever you actually install.

---

## Credits

Apollo is a remake. The design, the Quickshell panels, the settings app and the
rice as a whole are [Fi3w0's Moonlit-shell](https://github.com/Fi3w0/Moonlit-shell);
this repo translates them to Hyprland's Lua config. Upstream's LICENSE is kept.
