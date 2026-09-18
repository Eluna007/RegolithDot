# Theming

Where the colours come from — the wallpaper, the lock screen and the login
screen included.

[← back to the README](../README.md)

## Colors follow the palette

One palette, fanned out. `apollo-settings` › Theme is where it is decided:

- **Flavor** picks a whole Catppuccin palette — the neutral ramp (`base`…`text`)
  *and* the accent family (`red`, `green`, `blue`, …).
- **Accent** is your own highlight on top of it, independent of the flavor.
- **Dynamic colors** derives both from the current wallpaper. *Accent only*
  touches the highlight; *Full palette* also re-tints the neutral surfaces,
  keeping each slot's lightness so text stays readable. It never touches the
  accent family: a terminal whose red, green and yellow are all one wallpaper
  hue cannot show a diff.

Every write of `config.json` fans that palette out (`apollo-settings/apps.go`):

| Surface | File | Picks it up |
|---|---|---|
| The shell | `~/.config/apollo/config.json` | live, `Config.qml` watches it |
| kitty | `kitty/apollo-colors.conf` | `ctrl+shift+f5`, or the next window |
| Thunar / GTK | `gtk-{3,4}.0/apollo-colors.css` | next app start |
| rofi | `rofi/themes/apollo-colors.rasi` | next launch |
| The login screen | staged, then `sudo ~/.local/bin/apollo-sddm-sync` | next login |

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

The lock screen is the exception: it sits *on* the wallpaper, so it takes
matugen's own Material You scheme rather than a re-tinted Catppuccin ramp (see
[The lock screen](#the-lock-screen)), regardless of the flavor.

`scripts/check-palettes.py` fails the build if the three tables that spell the
palette out — `Config.qml`'s `_flavors`, `palette.go`'s `flavorRamps` and
`apps.go`'s `flavorAccents` — ever disagree, or if a GTK stylesheet uses a color
name nothing defines. GTK does not report an undefined color; the widget just
draws wrong.

## The wallpaper drives all of it

With **Dynamic colors** on, one wallpaper change recolours the whole rice.
The chain, all inside a single `wallpaper-switch.sh` run:

| | |
|---|---|
| `wallpaper-switch.sh` | puts the image on screen |
| `matugen` | extracts a source colour, renders the lock screen's palette, and **stages** that colour in `~/.cache/apollo/theme/source.sh` |
| `apollo-settings theme` | re-tints the flavor's ramp toward it and writes `config.json`, kitty, GTK, rofi and the staged login palette |
| `apollo-sddm-sync` | copies that palette and the wallpaper into the login screen — the only step that needs root |

Only the *hue* comes from the wallpaper. Each slot keeps the flavor's own
lightness, which is what guarantees the result is readable rather than
low-contrast mud for one unlucky wallpaper, and the accent family is left alone
entirely.

Staging is what makes the toggle possible: matugen renders its templates
unconditionally on every wallpaper change, but the fan-out only happens when
you have asked for it. Turning Dynamic colors off leaves the staged file where
it is and puts the flavor's own ramp back.

The switches are `dynamicColors` and `dynamicMode` in `config.json`. They used
to be `wallustEnabled` and `wallustMode`, after the tool that read them —
`loadConfig` carries the old keys over once, so an existing config keeps its
setting. wallust is no longer used or needed: its integration read the current
wallpaper from `~/.cache/wallpaper-current`, a file nothing in Apollo has ever
written, so it returned early every time and the toggle had never done anything
at all. matugen was already a hard dependency and already ran on every wallpaper
change, so it does the extraction now — which also means the lock screen and the
shell cannot disagree about what colour the wallpaper is, because they are
handed the same number.

## The login screen

`sddm/themes/apollo` is a Qt 6 QML greeter drawn like the rest of the rice: a
translucent card on the wallpaper, an accent pill, the same Material 3 easing.

It is the one part of this repo that is **copied rather than symlinked**, and
that is not a style choice. SDDM's greeter runs as the unprivileged `sddm` user
before any session exists, so it cannot read anything under your home directory
— not the wallpaper, not `~/.config`, not `~/.face`, and not a symlink pointing
into this repo. Everything it draws has to be copied into
`/usr/share/sddm/themes/apollo` by root:

```sh
sudo ~/.local/bin/apollo-sddm-sync
```

The full path matters: `sudo` swaps `PATH` for its own `secure_path`, which
does not include `~/.local/bin`, so the bare name is always "command not
found". `wallpaper-switch.sh` names the path for the same reason.

That is also why editing `sddm/themes/apollo/theme.conf` here does nothing on
its own. What is committed is the Mocha starting point; the installed copy is
rewritten from your current palette on every sync.

Dynamic colors is **not** required for this. That switch decides where the
palette comes from, not who receives it — the login screen's copy is staged on
every write of `config.json`, so a flavour you picked by hand reaches it just
the same. `apollo-settings theme` stages it too, which is the one command to
run on a machine where the settings app may never be opened again.

`wallpaper-switch.sh` runs `sudo -n ~/.local/bin/apollo-sddm-sync` on every wallpaper change,
which does nothing unless you have added the sudoers drop-in in
[MANUAL-INSTALL.md](../MANUAL-INSTALL.md) — a keybind has nowhere to show a
password prompt, and a prompt with nowhere to go would hang the wallpaper change
rather than fail it.

Two things about the theme are deliberate and worth not undoing:

- **No `QtQuick.Controls`.** A Controls style is a separate package from a
  separate tree, and a theme that fails to load does not degrade gracefully —
  SDDM silently falls back to its built-in theme, which looks exactly like the
  theme "not applying", with the diagnostic in a log only a working session
  could show you. `TextInput` and `MouseArea` cost a few more lines and cannot
  fail that way.
- **Every colour read has a fallback.** A key `theme.conf` does not define comes
  back as an empty string, and an empty string is not a colour: QML warns and
  paints black. On a login screen that is a black rectangle with no password
  field. `scripts/check-sddm-theme.py` (a CI step) keeps the three lists of keys
  — what `Main.qml` reads, what `theme.conf` defines, and what
  `renderLoginColors` writes — from ever drifting apart, and
  `scripts/test-sddm-sync.sh` drives the sync script against temporary
  directories, including the wallpaper that was deleted since and the format
  change that used to leave the old background behind.

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

0. **The new daemon starts before the old one stops, always.** Every flash of
   the bare Hyprland background between wallpapers came from the other order —
   kill the outgoing daemon, then spend a few hundred milliseconds starting the
   incoming one with nothing on screen in between. Video to still was the worst
   of it: the video branch had already killed hyprpaper, so the still had to
   cold-start it. The script holds the old PIDs and retires them only once the
   replacement is drawing.

   The daemons are also started with `setsid`, and the shell applies wallpapers
   with `execDetached` rather than a tracked `Process`. A `Process` is a child
   of the shell and so is everything it spawns, so reaping the finished script
   took `mpvpaper` down with it — an animated wallpaper that played for about a
   second, which is how long the rest of the script took, and then vanished.

   `scripts/test-wallpaper-switch.sh` (a CI step) pins the ordering by
   recording the sequence of calls, because none of this shows up in the
   script's output.

   What ordering cannot fix is the gap between a daemon *accepting* a
   wallpaper and drawing it: hyprpaper's IPC answers when the request is
   queued, and mpvpaper has nothing to ask at all. `panels/WallpaperTransition.qml`
   covers that — a Bottom-layer surface holding the outgoing wallpaper while
   the daemons swap underneath, handing over with one of three shapes, a
   different one each time: a circle out of the middle, a hard diagonal wipe,
   or the new wallpaper pushing the old one off the screen. Not a fade,
   deliberately: a fade through a half-drawn background is the thing being
   hidden. A transition you see twenty times a day stops being a transition and
   starts being a delay, so it never repeats itself twice running. It takes no input, unmaps itself when it is done, and gives up after
   six seconds if the art never loads, because an overlay that stays up forever
   is a desktop you cannot use.

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

The lock screen is the only consumer of matugen's *rendered* scheme. The shell
does not read these files: it takes its colors from
`~/.config/apollo/config.json`, and reaches the wallpaper by way of the staged
source colour instead (see "The wallpaper drives all of it" above). Two
consumers, one extraction.

Requires `hyprpaper`, `matugen`, and (for animated wallpapers) `mpvpaper` and
`ffmpeg`.

## The wallpaper picker

`SUPER+W`. Everything in `~/Pictures/Wallpapers`, applied through
`wallpaper-switch.sh` so the picker and the boot restore cannot disagree about
what is set.

### Layouts

```sh
apollo-paper-layout              # what is set now, and what else there is
apollo-paper-layout coverflow    # switch
```

| | |
|---|---|
| **filmstrip** | a centred card holding a strip of thumbnails — Apollo's own, and the default |
| **classic** | a plain list with a big preview; lightest on the GPU |
| **coverflow**, **-clear**, **-minimal** | full-screen sheared cards; without the blur, without the caption |
| **dock**, **dock-clear** | a sheared deck along the bottom edge, wallpaper above it |
| **grid**, **grid-clear** | a wall of thumbnails with a large preview beside it |
| **floating**, **-center**, **-clean**, **-clear**, **-clear-clean**, **-minimal** | tiered cards suspended around the focused one, with reflections under all, one, or none |

Everything but the filmstrip is ported from
[ujjalsigdel/hyprquickpaper](https://github.com/ujjalsigdel/hyprquickpaper).

Fifteen names, six files. Upstream ships every variant as its own complete
`shell.qml` — its six floating layouts are 364 to 559 lines apiece and differ
in three yes/no answers — but a variant is not a different layout, it is the
same one with the blur off or the reflections gone. Here it is the same file
and a couple of properties, handed over by `Loader.setSource`, which is the
only place a required property can be supplied anyway. That is what keeps a
long list of names from meaning a long list of copies of the same delegate.

`apollo-paper-layout` lists them all with a line on each.

The split is the lock screen's. `WallpaperPanel.qml` is the surface — the
scrim, the reveal, the keyboard — and everything underneath lives once in
`WallpaperSource.qml`: the folder, the thumbnails, what is currently applied,
and `apply()`. A layout file is only its look, and `WallpaperTile.qml` draws
one wallpaper for all of them.

That split is the whole reason for porting rather than vendoring. Upstream
ships each of its fourteen layouts as a complete standalone `shell.qml`, which
is right for a drop-in config and would mean fourteen copies of that plumbing
here — plus a second Quickshell process, its own `config.json`, and a border
colour that does not follow your accent.

The one piece that must never be re-implemented per layout is `apply()`. Every
upstream layout runs its own `commands.sh`, which sets the wallpaper itself.
Going through `wallpaper-switch.sh` instead is what keeps the rest of the rice
following it — the boot restore's record, matugen, the lock screen's colours
and wallpaper, the shell/kitty/GTK/rofi palette, and the login screen. Apply a
wallpaper any other way and all of that silently stops tracking. (Upstream's
own `hyprpaper` backend also calls `hyprctl hyprpaper preload`, which current
hyprpaper removed from its IPC — it just answers "invalid hyprpaper request".)

`scripts/check-paper-layouts.py` (a CI step) keeps the three lists of layouts —
the Loader's switch, `apollo-paper-layout`'s `describe()`, and the files
themselves — from drifting. A name the CLI offers that the Loader does not know
falls through to the default, so switching to it appears to do nothing.

A wallpaper's format decides which pipeline it takes — animated ones go to
mpvpaper, stills to hyprpaper — and that answer used to be spelled out
separately in files that could not see each other. Videos were missing from the
picker's `nameFilters` for as long as the picker existed, so the whole mpvpaper
branch was unreachable from the UI it was written for.
`scripts/check-wallpaper-formats.py` (a CI step) now keeps all five lists in
step, in both directions: a format the pipeline can apply must be offered, and
a format offered must be one the pipeline can apply.

Three things the tiles do that are not obvious:

- **Every wallpaper is thumbnailed once, and the picker loads that.** Handing
  `Image` a 4K original and asking for a 320px tile is merely wasteful for a
  JPEG, which can decode at a reduced scale — but a 4K PNG or WebP is decoded
  whole first, eight million pixels, to produce a postage stamp. Five of those
  during a momentum spin is the lag.
  `config/quickshell/apollo/scripts/wallpaper-thumbs.sh` downscales each one to
  640px with ImageMagick, in parallel up to `nproc`, and the tile loads that
  instead. A thumbnail that has not been made yet falls back to the original,
  so the picker is never worse than it was — just slower until the cache
  catches up.
  A multi-frame input has to name the frame it wants — `magick "file[0]"`.
  Without it ImageMagick writes *one file per frame*, `out-0.png`, `out-1.png`,
  and never the `out.png` it was asked for, so every gif was reported as
  unthumbnailable and the numbered frames piled up in the cache under the temp
  name, invisible to the retry check because they are not the name it looks for.
- **Videos are drawn from a cached frame,** by the same script, because
  `Image` cannot decode one at all. ffmpeg pulls a single frame a second in
  (the first frame of a video is very often black, and a black thumbnail is
  indistinguishable from one that failed). The cached file is named after the
  original plus `.png` — the entire contract between the script and the panel,
  so there is no index file to fall out of sync.
- **Gifs animate, and only the centred one does.** `Image` renders exactly one
  frame of a gif, which is why they looked like stills that would not play;
  `AnimatedImage` is the type that plays them. Decoding five at once is real
  work for four tiles nobody is looking at.
- **Decoded tiles are kept, and so are the delegates.** A `PathView` destroys
  and recreates its delegates as they leave and re-enter the path, so with
  `cache: false` every thumbnail was re-decoded from disk on every pass, and a
  momentum spin outruns the decoder. `cacheItemCount` keeps them alive off the
  path as well.

The pre-cached-thumbnail approach is
[iamsurjog/hyprquickpaper](https://github.com/iamsurjog/hyprquickpaper)'s, which
caches downscaled copies with ImageMagick and batches the work.

A tile that is loading and a tile that cannot be drawn used to look identical:
an empty frame. They now differ, because "still working" and "this file is
broken" want different reactions from you.

When a wallpaper is missing from the picker entirely, ask the script:

```sh
~/.config/quickshell/apollo/scripts/wallpaper-thumbs.sh --debug
```

It prints the folder it is reading, whether ImageMagick and ffmpeg are there,
how many stills and videos it can see, which videos have no frame — and how
many files are sitting in **subfolders**, which neither it nor the picker
looks into. That last one is by far the most common reason a wallpaper "is not
there", and nothing else about the picker would tell you.

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
