"""Structural checks for the Quickshell config.

A QML error is not a contained failure: an unresolved import or a stray brace
stops the whole shell loading, so the bar, every panel and the notification
daemon all disappear at once. There is no QML runtime in CI, but the mistakes
that actually cause that are structural and can be caught without one.

Checked here:
  - balanced braces/parens/brackets, ignoring strings and comments
  - every relative `import "..."` resolves to a real directory or file
  - every panel the bar can open is actually instantiated by the shell
  - no `x = x` self-assignment, which in QML notifies nothing

Stripping strings and comments needs a real scanner rather than regexes. A
regex pass that removes quoted text first will start a "string" at the
apostrophe in a comment like "doesn't" and swallow every brace up to the next
quote; one that removes comments first will start a "comment" at the // in a
URL. Both produce confident, wrong answers about files that load perfectly.
"""
import pathlib, re, sys

ROOT = pathlib.Path("config/quickshell/apollo")
bad = []

def strip(text):
    """Blank out strings, template literals and comments, keeping length so
    nothing else shifts. One left-to-right pass with explicit state - the only
    way to get quotes-in-comments and comments-in-quotes both right."""
    out = []
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        nxt = text[i + 1] if i + 1 < n else ""
        if c == "/" and nxt == "/":
            while i < n and text[i] != "\n":
                out.append(" "); i += 1
            continue
        if c == "/" and nxt == "*":
            while i < n and not (text[i] == "*" and i + 1 < n and text[i + 1] == "/"):
                out.append("\n" if text[i] == "\n" else " "); i += 1
            out.append("  "); i += 2
            continue
        if c in "\"'`":
            quote = c
            out.append(" "); i += 1
            while i < n:
                if text[i] == "\\":
                    out.append("  "); i += 2; continue
                if text[i] == quote:
                    out.append(" "); i += 1; break
                out.append("\n" if text[i] == "\n" else " "); i += 1
            continue
        out.append(c); i += 1
    return "".join(out)

qml_files = sorted(ROOT.rglob("*.qml"))
if not qml_files:
    print("no QML files found - wrong working directory?"); sys.exit(1)

for f in qml_files:
    text = f.read_text()
    body = strip(text)
    for open_c, close_c, name in [("{", "}", "braces"), ("(", ")", "parens"), ("[", "]", "brackets")]:
        if body.count(open_c) != body.count(close_c):
            bad.append(f"{f}: unbalanced {name} ({body.count(open_c)} open, {body.count(close_c)} close)")

    # `foo = foo` looks like "re-notify this property" and does nothing at
    # all: QML emits no change signal when a property is assigned the value it
    # already holds. Written after a mutated-in-place object was "refreshed"
    # this way, leaving the chess board frozen while the game moved on.
    for m in re.finditer(r'^\s*(?:root\.)?(\w+)\s*=\s*(?:root\.)?(\w+)\s*$', strip(text), re.M):
        if m.group(1) == m.group(2):
            line = strip(text)[:m.start()].count("\n") + 1
            bad.append(f"{f}:{line}: `{m.group(1)} = {m.group(1)}` notifies nothing; "
                       f"assign a new value")

    # relative imports must resolve
    for m in re.finditer(r'^\s*import\s+"([^"]+)"(?:\s+as\s+(\w+))?', text, re.M):
        target = (f.parent / m.group(1)).resolve()
        if not target.exists():
            bad.append(f"{f}: import \"{m.group(1)}\" does not exist")


# An import alias shadows anything of the same name, attached properties
# included. `import "keys/Keys.js" as Keys` next to `Keys.onPressed` resolves
# to the file, not to QtQuick, and the element silently stops handling keys -
# no error, no warning, it just never fires.
RESERVED = {
    "Keys", "Layout", "Component", "ListView", "GridView", "Drag", "Screen",
    "Window", "KeyNavigation", "LayoutMirroring", "Accessible", "Positioner",
    "Qt", "Behavior", "Binding", "Transition", "StackView", "SplitView",
}
for f in qml_files:
    for m in re.finditer(r'^\s*import\s+"[^"]+"\s+as\s+(\w+)', f.read_text(), re.M):
        if m.group(1) in RESERVED:
            bad.append(f"{f}: import alias \"{m.group(1)}\" shadows a QtQuick "
                       f"attached property of the same name")

# Every panel the shell switches to must actually be instantiated, or clicking
# its button opens nothing and says nothing.
shell = (ROOT / "shell.qml").read_text()
bar = (ROOT / "bar" / "Bar.qml").read_text()
opened = set(re.findall(r'openPanel\("(\w+)"\)', bar))
wired = set(re.findall(r'visible:\s*scope\.activePanel === "(\w+)"', shell))
# these are opened through their own paths rather than a plain visible binding
wired |= {"launcher", "overview"}
for name in sorted(opened - wired):
    bad.append(f"Bar.qml opens panel \"{name}\" but shell.qml never instantiates it")

# services/ holds singletons (Config, Hypr, Motion). A file that names one
# without importing the directory gets undefined, and QML reports that once at
# startup into a log nobody reads - which is how Config.showDesktop and then
# Config.shellScript both shipped broken from shell.qml.
SINGLETONS = {f.stem for f in (ROOT / "services").glob("*.qml")}
for f in qml_files:
    if f.parent.name == "services":
        continue
    raw = f.read_text()
    body = strip(raw)
    # The import is matched on the RAW source: strip() blanks string literals,
    # and an import path *is* a string literal - so against the stripped text
    # every file looks like it imports nothing. (Second time that has caught
    # me; the Quickshell.env rule below hit the same wall.) A commented-out
    # import still will not match, because `//` is not whitespace.
    imports_services = re.search(r'^\s*import\s+"[^"]*services"', raw, re.M)
    for name in sorted(SINGLETONS):
        if re.search(r'\b%s\.' % name, body) and not imports_services:
            bad.append(f"{f}: uses {name}.* but never imports the services "
                       f"directory - the singleton resolves to undefined")
            break

# Quickshell.env() returns null for an unset variable, not "". A `!== ""` test
# therefore passes when the variable is unset, the ternary takes the wrong
# branch, and the caller concatenates the string "null" into a path. That is
# how both the launcher and the clipboard panel ended up running
# "null/quickshell/apollo/scripts/apps.sh" and showing an empty list.
# Config.shellScript() is the one correct implementation.
for f in qml_files:
    body = strip(f.read_text())
    # Matched against the stripped source, where string literals are already
    # blanked - so the test is "env() compared with !==" rather than
    # "env() !== \"\"". That is the right shape to catch anyway: env() returns
    # null when unset, and null !== anything-non-null is true.
    if re.search(r'Quickshell\.env\([^)]*\)\s*!==', body):
        bad.append(f"{f}: Quickshell.env() compared with !== is true when the "
                   f"variable is unset - env() returns null, not \"\". Use "
                   f"truthiness, or Config.shellScript()")

# A colour the bar names but never declares binds to undefined. Qt logs
# "Unable to assign [undefined] to QColor" once and carries on drawing it
# wrong, which is how root.teal went unnoticed on the Tailscale icon.
PALETTE = {
    "rosewater", "flamingo", "pink", "mauve", "red", "maroon", "peach",
    "yellow", "green", "teal", "sky", "sapphire", "blue", "lavender",
    "base", "mantle", "crust", "surface0", "surface1", "surface2",
    "overlay0", "overlay1", "overlay2", "subtext0", "subtext1", "text",
}
bar_files = [f for f in qml_files if f.parent.name == "bar"]
bar_src = strip((ROOT / "bar" / "Bar.qml").read_text())
declared = set(re.findall(r'property\s+color\s+(\w+)\s*:', bar_src))
for f in bar_files:
    for name in sorted(set(re.findall(r'\broot\.(\w+)', strip(f.read_text())))):
        if name in PALETTE and name not in declared:
            bad.append(f"{f}: root.{name} is a palette colour Bar.qml never "
                       f"declares - it binds to undefined")

# `NumberAnimation on <property> { running: true }` is a property value source:
# it starts when the component is completed, and it replaces any binding on
# that property for good. shell.qml creates every panel eagerly and toggles it
# with `visible`, so every one of these fired once at login, to a hidden
# surface, and was never seen again - the shell had a dozen entrance
# animations that had never played. Drive it from `visible` instead:
#
#     property real reveal: 1
#     NumberAnimation { target: root; property: "reveal"; from: 0; to: 1
#                       running: root.visible }
#
# There are no legitimate uses left in this shell, so the rule is absolute
# rather than a list of properties to watch.
for f in qml_files:
    for m in re.finditer(r'NumberAnimation on (\w+)', strip(f.read_text())):
        bad.append(f"{f}: `NumberAnimation on {m.group(1)}` starts at component "
                   f"completion, not when the panel is shown - drive it from "
                   f"`visible` (see services/Motion.qml)")

# `Loader { onLoaded: item.<prop> = ... }` for a property the loaded component
# declares `required`.
#
# A required property has to be supplied when the object is created, so this is
# too late by definition - and it fails in the one way that hides itself. The
# component is never built, `item` stays null, and `onLoaded` therefore never
# runs either, so the assignment meant to satisfy the property cannot even be
# reached. The panel opens empty. QML writes "Required property <name> was not
# initialized" into a log nobody is reading while looking at the empty panel.
#
# The wallpaper picker shipped exactly this: SUPER+W gave a dimmed screen with
# no wallpapers on it. Pass them at creation instead:
#
#     loader.setSource("Thing.qml", { "wallpapers": wallpapers })
#
# Loader keeps the source and its properties across `active` toggling, so that
# form works for a panel that is built once and shown repeatedly. Both are
# pinned by scripts/qml-tests/tst_loader_required.qml.
#
# FileView also has an onLoaded, and it is not this: the discriminator is
# assigning *through* `item`, which only a Loader has.
for f in qml_files:
    src = strip(f.read_text())
    for m in re.finditer(r'onLoaded:\s*\{?[^}]*?\bitem\.(\w+)\s*=(?!=)', src):
        bad.append(f"{f}: `onLoaded: item.{m.group(1)} = ...` is too late for a "
                   f"required property - pass it with "
                   f"loader.setSource(url, {{ \"{m.group(1)}\": ... }})")

# A view's cache buffer, computed from geometry, without a floor under it.
#
# Every size derived from a panel's width is evaluated once before that panel
# has any geometry — at width 0, with margins subtracted, it goes negative.
# QML rejects a negative cacheBuffer outright ("Cannot set a negative cache
# buffer") and lays the view out with negative cells for a frame before the
# real numbers arrive. WallpaperGrid shipped that, and the only sign of it was
# a warning in a log.
#
# Narrow on purpose: a literal is fine, and so is anything already clamped.
for f in qml_files:
    for m in re.finditer(r"cacheBuffer:\s*(.+)", strip(f.read_text())):
        expr = m.group(1).strip()
        if re.fullmatch(r"\d+", expr):
            continue
        if "Math.max" in expr:
            continue
        bad.append(f"{f}: `cacheBuffer: {expr}` is computed without a floor - "
                   f"before the panel has geometry this is negative, which QML "
                   f"rejects. Wrap it in Math.max().")

# A curve or duration that Motion does not define comes back undefined, and an
# undefined bezierCurve is not an error - the animation just runs on the
# default easing, so the whole point of the shared vocabulary is silently lost.
motion = strip((ROOT / "services" / "Motion.qml").read_text())
defined = set(re.findall(r'property\s+\w+\s+(\w+)\s*:', motion))
defined |= set(re.findall(r'function\s+(\w+)\s*\(', motion))
for f in qml_files:
    if f.name == "Motion.qml":
        continue
    # Stripped, or every comment mentioning services/Motion.qml reads as a
    # reference to a property called "qml".
    for name in sorted(set(re.findall(r'\bMotion\.(\w+)', strip(f.read_text())))):
        if name not in defined:
            bad.append(f"{f}: Motion.{name} is not defined in services/Motion.qml")

# The launcher's actions name panels as data rather than as openPanel() calls,
# so the check above cannot see them. A typo there is silent: the row is
# offered, you pick it, and nothing happens.
commands = (ROOT / "panels" / "launcher" / "Commands.js").read_text()
named = set(re.findall(r'panel:\s*"(\w+)"', commands))
for name in sorted(named - wired):
    bad.append(f"Commands.js offers panel \"{name}\" but shell.qml never instantiates it")

if bad:
    print("\n".join(bad)); sys.exit(1)
print(f"ok - {len(qml_files)} QML files: balanced, imports resolve, "
      f"{len(opened)} bar panels and {len(named)} launcher actions all wired")
