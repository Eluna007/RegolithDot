# The shell

The Quickshell side: the bar, its panels, and the widgets that live in them. Everything here is in `config/quickshell/apollo/`.

[← back to the README](../README.md)

## The launcher

A full-screen page of large icons, the way Launchpad is: `SUPER+Space`, or the
Arch logo in the bar. Type to filter, arrows to move, Enter to launch. There is
no card — the whole screen is the surface, translucent over the blur `rules.lua`
already applies to the `quickshell` layer namespace, so the compositor does the
glass rather than QML faking it.

It is a card at 75% of the screen, centred, with a fixed **5×5** page. Fixed
rather than derived from the space available: "however many fit" gave a
different page size per monitor, so the same app was on page 1 on the laptop
and page 2 plugged in.

75% of a 16:9 screen divided into 5×5 gives cells about 2:1 — wide, short boxes
that read as a table rather than an icon grid. The row height is the honest
constraint, so the column width is capped at 1.3× it and the grid centres in
whatever width is left. The icon scales with the cell (59px at 1080p, 83px at
1440p, 38px on a small laptop) rather than being 56px everywhere.

Pages carry dots at the bottom; the scroll wheel, PageUp/PageDown and the dots
themselves turn them. The selection is an index into the whole result list
rather than into the page, so an arrow off the end of a page steps onto the
next one instead of stopping. `pageCount`, `pageSlice`, `pageOf` and
`moveByRow` are in `Commands.js` with tests, because the off-by-ones there hide:
a last page one short, and an empty trailing page when the count divides
exactly, both look plausible until you count.

If the grid is empty it says which of three things happened — the scan has not
finished, `apps.sh` found nothing at all, or the query matched nothing. Those
are different problems and a single "no results" makes a broken scanner look
exactly like a bad search. `apps.sh --debug` prints the directories it searched,
how many `.desktop` files are in each, and how many entries survive filtering.

One field searches four things, ranked together:

| Type | Finds | Enter |
|---|---|---|
| an app name | installed applications | launches it |
| a window title | what is open right now | focuses it, switching workspace |
| a sum (`2+2`, `sqrt(16)`, `=5`) | the answer, pinned on top | copies it |
| anything else | shell actions — lock, Wi-Fi, wallpaper, chess… | runs or opens it |

`>` on its own lists the actions, the way a command palette does. With the
field empty it is simply the app grid — that is what opening a launcher is for.
Windows and actions join in as soon as you type, where ranking decides the
order instead of concatenation.

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
`rofi -show combi`, which merged a custom script mode with drun. With the
keybind cheatsheet moved into the shell too, rofi is left with the emoji
picker — genuinely a different tool.

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

## The keybind cheatsheet

`ALT+/`, or "Keybinds" in the launcher. Search, then click a shortcut (or press
Enter) to copy it.

It asks `hyprctl binds -j` rather than reading `keybinds.lua`, and that is the
part worth keeping from the rofi mode it replaces: binds are Lua function calls
now, their arguments are tables, and a `for i = 1, 4` loop registers four binds
that appear nowhere in the file as text. What the compositor reports is what is
actually bound — `apollo-settings`' rebinds included.

Rows are grouped by their modifier half (`Super`, `Super + Shift`, …), which is
a fact about the bind rather than a guessed category, and is how people look a
shortcut up. Inside a group the keys sort naturally: 1, 2, 10, not 1, 10, 2.

`scripts/test-keys.js` covers the parts you cannot check by opening the panel
once — you look a shortcut up precisely when you do not know it, so a wrong
sheet reads exactly like a right one. It pins the modmask bitfield (CAPS is bit
2 and NumLock bit 16; neither may be mistaken for Shift), the deduplication
(hyprctl reports a bind per submap), the natural sort, and that `hyprctl`
missing leaves an empty sheet that says so rather than a panel that fails to
open.

## The desktop layer

A clock and the date, drawn on the wallpaper beneath every window
(`panels/Desktop.qml`). On a tiling compositor that means you see it on an
empty workspace and nowhere else, which is when a screen has nothing else to
say. Apollo Settings › Bar › Desktop turns it off.

It sits on `WlrLayer.Bottom` — above the wallpaper, below windows — and its
input region is empty (`mask: Region {}`), so every click goes through to
whatever is behind it. Its layer namespace is deliberately **not**
`quickshell`: `rules.lua` blurs `^(quickshell)$`, and blurring a surface that
sits directly on the wallpaper would blur the wallpaper through it.

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

## Motion

Every panel used to open the same way — `opacity` 0→1, 200ms, `OutCubic`.
A fade says nothing about where a thing came from. `services/Motion.qml` holds
one vocabulary instead: Material 3 expressive durations and curves as
[Caelestia's shell](https://github.com/caelestia-dots/shell) spells them, so a
popout grows out of the bar edge you clicked, with that edge staying put.

The spatial curves overshoot. Sampling each cubic at 4001 points:

| curve | peak | at |
|---|---|---|
| `curveStandard` | 1.0000 | — |
| `curveDefaultEffects` | 1.0000 | — |
| `curveDefaultSpatial` | 1.0139 | 56% through |
| `curveFastSpatial` | 1.0921 | 39% through |

That is what decides whether a springy card can be clipped by its own surface,
and the answer is no: the overshoot applies to the animated **range**, not the
final value. A scale running 0.90 → 1.00 on `curveDefaultSpatial` peaks at
0.90 + 0.10 × 1.0139 = **1.0014** — half a pixel on a 360px card. Swapping in
`curveFastSpatial` would make that 1.009, about 3px, and would want checking
against each panel's spare room first.

Bar-attached popouts scale from `Motion.originFor(Config.barPosition)`; the
full-screen sheets (launcher, cheatsheet, wallpaper picker) grow from their own
centre, since no bar edge is theirs. Scrims still just fade.

`check-qml.py` fails the build on a `Motion.` name the singleton does not
define. An undefined `easing.bezierCurve` is not an error in QML — the
animation quietly runs on the default easing, which is exactly the vocabulary
being lost without a symptom.
