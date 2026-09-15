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
and unlike the rest of `config/hypr/` it is *not* Moonlit's — see below.

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

## Keybinds, input and gestures

`lua/keybinds.lua`, `lua/input.lua` and `lua/gestures.lua` are Luna's, not
Moonlit's — carried over when Apollo was deployed. Notable differences from
upstream: `natural_scroll = false`, `disable_while_typing = false`, a vim-style
focus/resize layout with a resize submap, and touchscreen gestures via the
[hyprgrass](https://github.com/horriblename/hyprgrass) plugin, which Moonlit
had no equivalent for.

Nothing else in `lua/` imports these three, so they stay easy to swap.

## The lock screen

Four layouts vendored from
[mahaveergurjar/Hyprlock-Dots](https://github.com/mahaveergurjar/Hyprlock-Dots)
(upstream ships no LICENSE; kept with attribution):

| | |
|---|---|
| **12** | minimal, left-aligned: welcome, clock, username + password pills |
| **15** | centred clock; right column of music, weather, battery, avatar |
| **18** | music-first: album art, transport, progress, cava visualiser |
| **20** | widget dashboard: login card, clock + uptime, music, wifi/bt, battery |

Switch from a terminal, or from apollo-settings' **Lock** tab:

```sh
apollo-lock-layout        # what is set now, and what else there is
apollo-lock-layout 18     # switch
```

hyprlock re-reads its config on every lock, so there is nothing to reload —
the next lock uses the new layout. To see it right away, run `hyprlock`.

Both writers touch one file, `~/.config/hyprlock/layout.conf`: a single
`source` line that `config/hypr/hyprlock.conf` pulls in. It is gitignored
machine state, like `colors.conf` below, so switching layouts never shows up
as a change to this repo. That indirection is also why the Lock tab keeps
nothing in `config.json` — it reads and writes the same file the CLI does, so
the two cannot disagree about which layout is active.

`scripts/check-lock-layouts.py` (a CI step) keeps the three lists of layouts
— the files, the CLI's `describe()`, and `lock.go`'s `lockLayouts` — from
drifting apart, and `apollo-doctor` reports which layout is live.

Upstream hardcodes every colour. Here they are `$variables` resolved from three
files, split by who writes them:

| file | written by | holds |
|---|---|---|
| `colors.conf` | matugen | the 17 colour variables |
| `wallpaper.conf` | `hyprlock-wallpaper.sh` | `$wall` |
| `assets.conf` | you, tracked in git | `$avatar`, `$cover` |

The first two are gitignored machine state, regenerated together on every
wallpaper change, so the lock screen recolours with the wallpaper like the rest
of the rice. `scripts/check-hyprlock-vars.py` (also a CI step) verifies every
variable a layout references is actually defined — hyprlock renders an unknown
one as nothing, which on a lock screen reads as black on black.

Needs `playerctl` for the music widgets, `cava` for layout18's visualiser,
`imagemagick` for album art, `curl` for layout15's weather, and `iw` +
`bluez-utils` for layout20's wifi/bluetooth widgets. Those last two redirect
stderr and fall back to "Disconnected", so a missing tool looks exactly like
being offline — `apollo-doctor` tells them apart.

`scripts/check-layout-commands.py` (a CI step) requires every command a layout
shells out to be declared. The layouts are vendored from someone else's
machine and assume its binaries: `hostname` was one (it lives in `inetutils`,
not a base Arch install), and the only symptom was an error in hyprlock's log
— on a locked screen, where nobody is reading logs.

`battery.sh` (layout15 and layout20) finds the battery instead of assuming
`/sys/class/power_supply/BAT0`. That name is not universal — plenty of
laptops expose `BAT1` — and on a machine where it is wrong the widget
rendered blank while every update tick wrote a `cat: No such file` pair into
hyprlock's log. `scripts/test-battery.sh` (a CI step) covers discovery, every
decile including 100%, and the no-battery case; a second CI step rejects a
hardcoded `BAT<n>` path anywhere outside a comment.

`playerctlock.sh` (metadata) and `hlock_mpris.sh` (album art) were rewritten:
upstream hardcoded `playerctl -p spotify` and bailed with "Not playing on
Spotify" otherwise, so every music widget printed that string on a machine
without it. They now take whichever MPRIS player is playing, and the art
script handles `file://` and `data:` art as well as `http(s)://`.

Album art reaches hyprlock through `reload_cmd`, which is expected to *print
a path* — upstream left it empty, so the art never refreshed. When nothing is
playing the script prints `assets/no-art.png`, a 1×1 transparent PNG: a path
that does not exist makes hyprlock log `cannot get file time` and render a
broken widget.

Apollo does not use Moonlit's `awww` wallpaper daemon or its `lock.sh`.
`hypridle.conf` calls `hyprlock` directly.

Clipboard history is `copyq`, not Moonlit's `cliphist` watchers.

The pipeline spans three places, which is worth knowing before you move any
piece of it:

1. `local/bin/wallpaper-switch.sh` applies a wallpaper. The `SUPER+W`
   carousel calls it too, so the picker and the boot restore can't disagree
   about what's set. It uses `hyprpaper` for
   stills, `mpvpaper` for gifs and video (hyprpaper can only show one frame of
   a gif) — then runs `matugen` over it.
2. matugen writes `~/.config/quickshell/colors.json`. That is the *parent* of
   `~/.config/quickshell/apollo`, not inside it, so clearing out a previous
   shell can delete it by accident.
3. matugen's second template writes `~/.config/hyprlock/colors.conf`, and
   `hyprlock-wallpaper.sh` writes `wallpaper.conf` beside it, in the same
   `wallpaper-switch.sh` run so the two can never disagree.

Break any link and the lock screen loses its palette. `apollo-doctor` checks
for all of it.

Requires `hyprpaper`, `matugen`, and (for animated wallpapers) `mpvpaper` and
`ffmpeg`.

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
