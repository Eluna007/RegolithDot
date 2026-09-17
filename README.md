# Apollo

A Hyprland rice for Arch: Catppuccin, a Quickshell bar, and Hyprland configured
in **Lua** rather than `hyprland.conf`.

<!-- Screenshots go here. -->

## About this repo

I'm not a developer.

This started because I'm a fan of
[Fi3w0's Moonlit-shell](https://github.com/Fi3w0/Moonlit-shell). It's a
beautiful set of dots and I wanted to daily-drive it — but Moonlit is written
in hyprlang, and I'd moved to Hyprland's Lua configuration and didn't want to
go back. So I set about translating it myself. Apollo is that translation, and
the design, the panels and the look are Moonlit's; the credit for the rice
belongs upstream.

I got the port most of the way there by hand and then hit the limits of what I
could work out on my own, particularly on the Quickshell side.

**Claude (Anthropic's Claude Code) did the work of finishing it** from there:
completing the Lua port, rebuilding and extending the shell, and adding the
tests and checks described below. The commit history is the honest record of
which parts were whose.

So: a personal rice, translated out of admiration for the original and
finished with a lot of help. Published in case it's useful to someone else on
the same path. It isn't a product, it has one user, and it comes with no
promise that it works on your machine.

## What it is

- **Hyprland in Lua.** `config/hypr/hyprland.lua` plus a module per concern —
  appearance, animations, input, gestures, rules, keybinds, autostart. Dispatch
  goes through `hl.dsp.*` rather than the old hyprlang strings.
- **A Quickshell bar**, in four layouts (floating islands or a classic bar,
  horizontal or vertical). Workspaces, a tray, a clock, system stats, and
  panels for audio, bluetooth, wifi, clipboard, calendar, wallpaper, Tailscale
  and power.
- **A launcher** on `SUPER+Space` that also searches open windows, does
  arithmetic, and runs shell actions.
- **A lock screen** with four interchangeable hyprlock layouts, and a **login
  screen** drawn to match — its own SDDM theme rather than a borrowed one.
- **Dynamic colours.** With it switched on, one wallpaper change recolours the
  shell, the terminal, GTK apps, rofi, the lock screen and the login screen.
- **`apollo-settings`**, a small Go/Fyne app for the safe knobs — palette,
  accent, bar layout, a handful of keybinds — which writes the Lua the
  compositor reads.
- **`apollo-doctor`**, which checks every dependency and generated file the
  above quietly relies on.

Some extras that are there because I wanted them: a sudoku widget, a chess
widget with a real engine, and a clock drawn on the wallpaper.

## Install

See [MANUAL-INSTALL.md](MANUAL-INSTALL.md). It's a set of symlinks and a
package list — there is deliberately no installer script.

**Then run `scripts/apollo-doctor`.** It tells you what's missing, and it
writes the palette files the terminal and GTK apps read — those are machine
state, so a fresh clone has only the committed `*.default.*` to seed from until
the doctor runs once. It never overwrites a palette you've already set.

## Docs

| | |
|---|---|
| [docs/hyprland.md](docs/hyprland.md) | The Lua config: what's where, what the translation changed, the keybinds |
| [docs/shell.md](docs/shell.md) | The Quickshell side: launcher, cheatsheet, widgets, motion |
| [docs/theming.md](docs/theming.md) | Where the colours come from, and the lock screen |

## On the tests

There are rather a lot of checks in `scripts/` and `.github/workflows/` for a
personal dotfiles repo. They're there because almost every bug in this thing
has been silent: a widget that says "Disconnected" when the tool it needs isn't
installed, a clipboard panel querying a program that wasn't running, a colour
scheme generator pointed at a template that was never committed, a dozen
entrance animations that played once at login to a hidden window and never
again. None of those announce themselves. Each check exists because something
was actually broken, and each one was verified by putting the bug back and
watching it fail.

## Not included

Deliberately left out of this repo:

- **`install.sh`** — Moonlit's installer. Deploy with the symlinks in
  MANUAL-INSTALL.md instead.
- **Wallpapers** (25 MB) — `~/Pictures/Wallpapers` is expected to exist; the
  picker and `SUPER+SHIFT+B` read from it.
- **`Bibata-Modern-Classic` cursors** (27 MB) — install
  `bibata-cursor-theme` from the AUR.

One upstream inconsistency is preserved as-is: `gtk-3.0/settings.ini` names
`Nero-Cyber-Cyan` as the cursor theme while Moonlit shipped Bibata. Point it at
whichever you actually install.

## Credits

Apollo is a remake. The design, the Quickshell panels, the settings app and the
rice as a whole are [Fi3w0's Moonlit-shell](https://github.com/Fi3w0/Moonlit-shell);
this repo translates them to Hyprland's Lua config and builds on them.
Upstream's LICENSE is kept.

The wallpaper picker pre-caches downscaled thumbnails the way
[iamsurjog/hyprquickpaper](https://github.com/iamsurjog/hyprquickpaper) does.

The motion vocabulary in `services/Motion.qml` is Material 3's expressive
durations and curves as [caelestia-dots/shell](https://github.com/caelestia-dots/shell)
spells them (`Config/tokens.hpp`), found by way of
[Ryoku](https://github.com/Ryoku-dev/ryoku-arch), which ports them too.

Built with [Claude Code](https://claude.ai/code).
