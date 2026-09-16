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
