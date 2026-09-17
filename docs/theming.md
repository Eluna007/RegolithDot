# Theming

Where the colours come from, and the lock screen that has its own set.

[← back to the README](../README.md)

## Colors follow the palette

One palette, fanned out. `apollo-settings` › Theme is where it is decided:

- **Flavor** picks a whole Catppuccin palette — the neutral ramp (`base`…`text`)
  *and* the accent family (`red`, `green`, `blue`, …).
- **Accent** is your own highlight on top of it, independent of the flavor.
- **Dynamic colors** (needs `wallust`) derives both from the current wallpaper.
  *Accent only* touches the highlight; *Full palette* also re-tints the neutral
  surfaces, keeping each slot's lightness so text stays readable. It never
  touches the accent family: a terminal whose red, green and yellow are all one
  wallpaper hue cannot show a diff.

Every write of `config.json` fans that palette out (`apollo-settings/apps.go`):

| Surface | File | Picks it up |
|---|---|---|
| The shell | `~/.config/apollo/config.json` | live, `Config.qml` watches it |
| kitty | `kitty/apollo-colors.conf` | `ctrl+shift+f5`, or the next window |
| Thunar / GTK | `gtk-{3,4}.0/apollo-colors.css` | next app start |
| rofi | `rofi/themes/apollo-colors.rasi` | next launch |

Each generated file is `include`d or `@import`ed by the real config, and each
one is **gitignored**. That is deliberate: `~/.config/kitty`, `gtk-3.0`,
`gtk-4.0` and `rofi` are symlinks *into* this repo, so a tracked generated file
would mean a customised palette is an uncommitted change sitting in the way of
every `git pull`.

What is committed is the `*.default.*` beside each one — the Mocha starting
point. `apollo-doctor` copies it into place when the generated file is missing,
which is what makes a fresh clone themed, and it never overwrites one that
already exists.

`config/rofi/config.rasi` points its `@theme` at the generated file with a
static `~` path. `apollo-settings` used to rewrite that line too, with an
absolute `/home/<user>/` path — a tracked modification and a personal path in a
committed file, both for no gain.

The lock screen is the exception: it sits *on* the wallpaper, so it takes its
colors straight from it via matugen (see [The lock screen](#the-lock-screen)),
regardless of the flavor.

`scripts/check-palettes.py` fails the build if the three tables that spell the
palette out — `Config.qml`'s `_flavors`, `palette.go`'s `flavorRamps` and
`apps.go`'s `flavorAccents` — ever disagree, or if a GTK stylesheet uses a color
name nothing defines. GTK does not report an undefined color; the widget just
draws wrong.

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
of the rice. The bar's battery icon steps through the Nerd Font ramp per decile rather
than switching between two glyphs at 20%, and the system-monitor panel draws
a charge ring beside the time remaining and pack health. Both read
`Config.batteryIcon()`, so the pill and the panel cannot disagree.

`scripts/check-hyprlock-vars.py` (also a CI step) verifies every
variable a layout references is actually defined — hyprlock renders an unknown
one as nothing, which on a lock screen reads as black on black.

Needs `playerctl` for the music widgets, `cava` for layout18's visualiser,
`imagemagick` for album art, `curl` for layout15's weather, and `bluez-utils`
for layout20's bluetooth widget.

Its wifi widget reads `nmcli` rather than upstream's `iw`, which is not on a
base Arch install at all; `iw` stays as a fallback for a machine not running
NetworkManager. Both widgets say "Unavailable" when no tool is present rather
than "Disconnected" — upstream reported a connected machine as offline, and
because it redirected stderr there was nothing in the log to contradict it.
Its bluetooth widget was wrong the same way: `bluetoothctl info` with no
argument needs a default device selected and otherwise just errors, so it
could never report a connected device. `scripts/test-network.sh` (a CI step)
covers both against stubbed tools.

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
2. matugen renders `~/.config/hyprlock/colors.conf` (hyprlang `$variables` the
   layouts reference) and `colors.sh` (the same palette in a form the scripts
   that emit pango markup themselves can source).
3. `hyprlock-wallpaper.sh` writes `wallpaper.conf` beside them, in the same
   `wallpaper-switch.sh` run, so the palette and the image can never disagree.

Break any link and the lock screen loses its palette. `apollo-doctor` checks
for all of it, and `scripts/check-matugen-templates.py` checks the inputs:
`config/matugen` is symlinked whole into `~/.config`, so a `[templates.*]`
block naming a file that is not in this repo makes matugen fail on every
wallpaper change.

The lock screen is matugen's only consumer. **The shell does not read this
palette** — it takes its colors from `~/.config/apollo/config.json`, which
`apollo-settings` writes (see "Colors follow the palette" below).

Requires `hyprpaper`, `matugen`, and (for animated wallpapers) `mpvpaper` and
`ffmpeg`.

## Where the panels sit

A bar popout anchors to `Config.barEdge`, not to a hardcoded margin. The bar's
*window* is 42px tall or 46px wide, but in islands mode the pill it paints is
only 34 across and centred in that window — so the pill ends at 38 (top) or 40
(left/right). Panels used to sit at 52, which left a 12px gap and made every
popout look detached from the rail it came out of. Classic mode paints the
whole window, so there the two numbers are the same.

Panel margins are measured from the screen edge rather than from the bar's
exclusive zone. The evidence is the old top-bar margin: it was exactly the
bar's own height, which only lines up if it is screen-relative.
