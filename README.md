# Apollo widgets

Two [Quickshell](https://quickshell.org) widgets — a sudoku and a chess board
— that run on any Wayland compositor. No bar, no compositor bindings: they are
opened over IPC, so the keybind lives in your compositor's own config.

This repo used to be a whole Hyprland rice. It isn't any more; see
[History](#history).

## The widgets

**Apolloku** — sudoku. Four difficulties, generated on the fly and rated by
the techniques a solve actually needs rather than by how many clues are left.
Notes mode, hints, undo, a mistake counter. Generation runs incrementally
across frames, so making a hard puzzle never freezes the panel.

**Chess** — play a local opponent or the built-in engine. Legal-move
generation is a 0x88 board with full rules (en passant, castling rights,
promotion, the draw conditions); the engine is alpha-beta with quiescence,
sliced one root move per frame so the search never blocks the UI. Set a
chess.com handle and it shows your ratings alongside.

## Install

Symlink the shell into your Quickshell config directory:

```sh
ln -s "$PWD/config/quickshell/apollo" ~/.config/quickshell/apollo
```

Then run it — as a service, or from your compositor's startup:

```sh
qs -c apollo
```

Needs `quickshell`, a Nerd Font (the panels draw glyphs from
`JetBrainsMono Nerd Font Mono`), and `curl` if you want chess.com ratings.

## Opening them

Both panels are toggled over Quickshell's IPC:

```sh
qs -c apollo ipc call panel toggle apolloku
qs -c apollo ipc call panel toggle chess
qs -c apollo ipc call panel close
```

Bind those in your compositor. In niri's `config.kdl`:

```kdl
binds {
    Mod+Shift+S { spawn "qs" "-c" "apollo" "ipc" "call" "panel" "toggle" "apolloku"; }
    Mod+Shift+C { spawn "qs" "-c" "apollo" "ipc" "call" "panel" "toggle" "chess"; }
}
```

Toggling the panel that is already open closes it; opening the other replaces
it, so the two never overlap. `Esc` closes whichever is up.

## Configuration

Optional, and read live from `~/.config/apollo/config.json` — edit it and the
panels restyle without a restart. With no file at all you get Catppuccin Mocha
anchored to the top edge.

| Key | Default | |
|---|---|---|
| `flavor` | `"mocha"` | `mocha`, `macchiato`, `frappe` or `latte` |
| `accent` | `"#cba6f7"` | Drives active and hover states |
| `panelEdge` | `"top"` | `top` (centred), `left` or `right` |
| `panelMargin` | `10` | Gap from that edge, in pixels |
| `chessUsername` | `""` | chess.com handle; empty hides the ratings section |

## Multi-monitor

The panels are single instances and land on your first screen. Nothing here
imports a compositor module, which is what makes it portable — the cost is
that the shell can't ask which output has focus. Making them follow focus
means querying the compositor (`niri msg --json focused-output`) and passing
the name down to `screen` in `shell.qml`.

## History

This started as a Hyprland rice: a Quickshell bar, Hyprland configured in Lua,
hyprlock, an SDDM theme, a settings app, dynamic colours. All of that was
removed when I moved to niri — the two widgets are what I actually wanted to
keep. The rest is in the git history if you want it.

The shell scaffolding these widgets grew inside was a translation of
[Fi3w0's Moonlit-shell](https://github.com/Fi3w0/Moonlit-shell), whose LICENSE
is kept. The sudoku and chess widgets themselves are not Moonlit's.

The motion vocabulary in `services/Motion.qml` is Material 3's expressive
durations and curves as [caelestia-dots/shell](https://github.com/caelestia-dots/shell)
spells them (`Config/tokens.hpp`).

Built with [Claude Code](https://claude.ai/code).
