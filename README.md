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

## The launcher

A Spotlight-style launcher: `SUPER+Space`, or the Arch logo in the bar. Type
to filter, arrows to move, Enter to act. The card is translucent and
`rules.lua` already blurs the `quickshell` layer namespace, so the compositor
does the glass rather than QML faking it.

One field searches four things, ranked together:

| Type | Finds | Enter |
|---|---|---|
| an app name | installed applications | launches it |
| a window title | what is open right now | focuses it, switching workspace |
| a sum (`2+2`, `sqrt(16)`, `=5`) | the answer, pinned on top | copies it |
| anything else | shell actions — lock, Wi-Fi, wallpaper, chess… | runs or opens it |

`>` on its own lists the actions, the way a command palette does. With the
field empty the open windows come first, so at rest it is a task switcher and
the app list is one keystroke away.

Windows come from `Hyprland.toplevels`, the same live list the overview uses,
so a keystroke costs no process. Actions that open one of the shell's own
panels hand the name back to `shell.qml` rather than shelling out to the IPC.
Those names are data, not `openPanel()` calls, so `check-qml.py` cross-checks
them against the panels `shell.qml` instantiates — a typo there would be
silent: the row appears, you pick it, nothing happens.

The calculator is a tokenizer and a recursive-descent parser, not `eval`.
`scripts/test-launcher.js` pins the parts that look right and are wrong:
`2 + 2 * 3` is 8, `2^3^2` is 512 and not 64, `0.1 + 0.2` reads `0.3` while
`1/3` is not rounded to `0.33`, and division by zero is refused rather than
answered `Infinity`. A bare `5` is not treated as a sum — `=5` asks for it —
so numbers in app names still reach the apps.

It replaces two launchers. `SUPER+Space` ran wofi and the Arch logo ran
`rofi -show combi`, which merged a custom script mode with drun; rofi stays
only for the emoji and keybind pickers, which are genuinely different tools.

`scripts/apps.sh` reads the `.desktop` files. It honours the things that make
a launcher list wrong: `NoDisplay` and `Hidden` entries stay hidden, `%U` and
friends are stripped from `Exec` so they do not land on the command line, a
`TryExec` naming an uninstalled binary drops the entry, `[Desktop Action]`
groups do not overwrite the application's own `Name`, and the first directory
in the XDG search order wins a duplicate. Icons are resolved by one indexed
pass rather than a stat storm, and an app whose icon is missing gets a
lettered tile instead of a broken-image box.

Two hundred apps scan in about 30ms. It was 356ms before the icon lookup
stopped spawning a process per app, and 175ms per *nine* apps before the
parser stopped spawning a `sed` per field.

Ranking lives in `launcher/Match.js`: exact name, then prefix, then word
boundary, then initials (`vsc` finds Visual Studio Code), then substring, then
a packed subsequence (`gimp` finds GNU Image Manipulation Program). Comments
are scored at a quarter weight, so a long description never outranks an app
whose name you typed. `scripts/test-launcher.js` asserts those orderings and
that ties stay in alphabetical order — a list that reshuffles under the
cursor is how you launch the wrong thing.

## Tailscale

The mesh mark in the tray opens it. Connect and disconnect with the switch,
see every device on the tailnet with online state and last-seen age, pick or
clear an exit node, and click any peer to copy its address.

Status is polled in `shell.qml`, not in the panel, so the bar icon shows the
connection state while the panel is closed and the two cannot disagree about
it. The icon hides entirely when `tailscale` is not installed.

`tailscale up`, `down` and `set` normally need root. Rather than prompting for
a password, the panel runs them as you and shows what the CLI actually said
when it refuses — along with the one-time fix, which is
`sudo tailscale set --operator=$USER`. A switch that silently does nothing is
the worst of the options.

Parsing is in `tailscale/Tailscale.js` and covered by
`scripts/test-tailscale.js`. That binary updates independently of this shell,
so the tests feed it every shape a broken or newer tailscale might emit —
`Peer` as an array, `Online` as a string, a `BackendState` nobody has seen
before — and require that each blanks a widget rather than throwing. An
unrecognised state is never assumed to be running: showing "connected" for a
tailnet that is down is worse than showing nothing.

## Chess

Play the built-in engine or a second person at the same keyboard, with your
chess.com ratings alongside when you set one. The checkerboard mark in the
tray opens it; `U` undoes, `F` flips the board, `N` starts a new game.

`chess/Chess.js` is a 0x88 move generator with make/unmake, SAN, FEN and the
draw rules. Correctness here is not a matter of taste, so it is measured:
`scripts/test-chess.js` runs **perft** against the published node counts for
the six standard test positions — 11.7 million nodes, matching exactly. A
generator that mishandles en passant, castling through an attacked square,
promotion or a pinned piece cannot reproduce those by accident.

`chess/Engine.js` is alpha-beta with quiescence, iterative deepening and
MVV-LVA ordering, over material plus piece-square tables. Club strength at
best, deliberately: Stockfish plays far better but is a separate process to
find, launch and speak UCI to, where this is a few hundred lines node can test
directly. Five levels; the lower ones pick among near-best moves so they are beatable
rather than erratic. The search runs in slices, like Apolloku's generator and
for the same reason — it shares the thread that draws the bar — but the unit
of work is one **root move**, not one depth. Slicing per depth meant that
whenever a slice ran out of budget the whole search was abandoned, so on this
machine levels 3, 4 and 5 all returned the same depth-2 move: the deeper
levels silently did not exist. A root subtree is roughly a thirty-fifth of an
iteration, and alpha carries across slices, so nothing is re-searched.

Depth is capped at 4 because the numbers say so. Measured in this shell's QML
engine, it runs at ~94k nodes/sec — about fifty times slower than the same
code under node — which puts depth 4 at roughly a second of thinking and
depth 5 at fourteen. A level nobody will wait for is not a level.

Ratings are optional. Set `chessUsername` in `~/.config/apollo/config.json`
and the panel fetches `api.chess.com/pub/player/<name>/stats` every five
minutes with curl — public data, no login. That response is treated as
untrusted: every field is range-checked, strings are stripped of control
characters and clamped, and it is all rendered as `Text.PlainText`. The
username is validated against `^[A-Za-z0-9_-]{3,25}$` before it goes near
curl, and is passed as an argv entry rather than pasted into the URL.

## Apolloku

Sudoku in the bar, remade from the version on the `pre-apollo-shell` branch.
The board glyph in the tray opens it; digits, arrows, `N` (pencil marks), `H`
(hint), `U` (undo), `F` (fill marks) and `Space` (pause) all work from the
keyboard.

The puzzle logic is in `panels/apolloku/Sudoku.js` and `Model.js` — plain
ECMAScript, no QML — so `scripts/test-apolloku.js` exercises it for real under
node in CI. That matters because the two properties that make a sudoku a
sudoku are invisible in the UI: a puzzle with two solutions and a puzzle with
one look identical until you have spent ten minutes on the wrong branch.

The bar mark is drawn (`bar/ApollokuIcon.qml`), not a font glyph: a 3x3 board
with two rules each way and four lit cells. The Nerd Font grid glyph it
replaced read as a generic tile grid rather than a sudoku.

Solving a puzzle sets off the celebration from the original — ~320 confetti
pieces launched from the cells in a shuffled cascade, then a card with the
time, the rating and whether it beat your best. One `NumberAnimation` drives
every piece through arithmetic on a single progress value, so it costs one
animation rather than 320.

Two things changed from the original, both flagged by its own comments:

**Difficulty is measured, not assumed.** The original carved to a clue count
and named the result after it, noting that "clue count correlates with
difficulty but does not determine it". It does not: a sparse board solvable by
naked singles alone is an easy puzzle, and calling it Expert is just wrong.
`rate()` now solves each candidate the way a person would — naked singles,
hidden singles, locked candidates, naked pairs — and the hardest technique it
needed is the rating. Carving repeats until the rating matches what was asked
for. Measured over 48 puzzles, the old clue-count labelling produced
`{Easy: 35, Medium: 9, Hard: 1, Expert: 3}` regardless of what was requested.

**Generation no longer freezes the bar.** It runs on the thread that draws
everything, and a full run reaches ~300ms. `createGenerator`/`step` do one
carve per call so the panel can drive it from a `Timer`, spreading the work
across frames with a progress readout instead of stalling the shell.

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

---

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
one is **checked in** — so a fresh clone is fully themed before `apollo-settings`
has ever run, and your palette shows up as a tracked change, which is the point.

The lock screen is the exception: it sits *on* the wallpaper, so it takes its
colors straight from it via matugen (see [The lock screen](#the-lock-screen)),
regardless of the flavor.

`scripts/check-palettes.py` fails the build if the three tables that spell the
palette out — `Config.qml`'s `_flavors`, `palette.go`'s `flavorRamps` and
`apps.go`'s `flavorAccents` — ever disagree, or if a GTK stylesheet uses a color
name nothing defines. GTK does not report an undefined color; the widget just
draws wrong.

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
