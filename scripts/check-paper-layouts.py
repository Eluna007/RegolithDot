#!/usr/bin/env python3
"""Three lists name the wallpaper picker's layouts. They have to agree.

  panels/WallpaperPanel.qml    the layouts table — what the shell will load
  local/bin/apollo-paper-layout  describe() — what you can ask for
  panels/Wallpaper*.qml        the files that actually exist

Each disagreement fails differently and none of them says so. A name the CLI
offers but the Loader does not know falls through to the default, so the switch
appears to do nothing. A Loader case naming a file that is not there loads
nothing at all — an empty picker over a dimmed screen, with the reason in a log
nobody is reading. And a layout file no case names is dead weight that looks
wired up from the file tree alone.

This is check-lock-layouts.py's job for the other set of layouts, and it exists
for the same reason: the hyprlock layouts drifted exactly this way.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PANEL = ROOT / "config/quickshell/apollo/panels/WallpaperPanel.qml"
CLI = ROOT / "local/bin/apollo-paper-layout"
PANELS_DIR = ROOT / "config/quickshell/apollo/panels"

# Not layouts: the panel itself and the pieces every layout shares.
# The panel itself, and the pieces every layout shares rather than is.
NOT_LAYOUTS = {"WallpaperPanel.qml", "WallpaperSource.qml", "WallpaperTile.qml",
               "WallpaperTransition.qml", "WallpaperBackdrop.qml"}

fails = []


def fail(msg):
    fails.append(msg)
    print(f"FAIL  {msg}")


def main() -> int:
    panel = PANEL.read_text()

    m = re.search(r"readonly property var layouts: \(\{(.*?)\n    \}\)", panel, re.S)
    if not m:
        fail("WallpaperPanel.qml: no layouts table")
        return 1
    table = dict(re.findall(r'"([\w-]+)":\s*\{\s*file:\s*"([\w.]+)"', m.group(1)))
    if not table:
        fail("WallpaperPanel.qml: the layouts table parsed empty")
        return 1

    m = re.search(r'readonly property string defaultLayout: "([\w-]+)"', panel)
    if not m:
        fail("WallpaperPanel.qml: no defaultLayout")
        return 1
    default = m.group(1)
    if default not in table:
        fail(f"WallpaperPanel.qml: defaultLayout is {default!r}, which the table "
             f"does not name — an unknown layout would fall back to nothing")

    cli = CLI.read_text()
    m = re.search(r"describe\(\) \{\n  case \"\$1\" in(.*?)\n  esac", cli, re.S)
    if not m:
        fail("apollo-paper-layout: no describe() case block")
        return 1
    described = {n for n in re.findall(r"^\s+([\w-]+)\)", m.group(1), re.M)}

    m = re.search(r"available\(\) \{\n  printf '%s\\n' (.*?)\n\}", cli, re.S)
    offered = set(m.group(1).replace("\\", " ").split()) if m else set()
    if not m:
        fail("apollo-paper-layout: no available() list")

    files = {f.name for f in PANELS_DIR.glob("Wallpaper*.qml")} - NOT_LAYOUTS

    for name, f in sorted(table.items()):
        if f not in files:
            fail(f"WallpaperPanel.qml maps '{name}' to {f}, which does not exist")

    for f in sorted(files - set(table.values())):
        fail(f"{f} is a layout the panel never selects")

    for name in sorted(described - set(table)):
        fail(f"apollo-paper-layout offers '{name}', which the panel's table "
             f"does not name (it would fall back to the default)")
    for name in sorted(set(table) - described):
        fail(f"the panel has a layout '{name}' that apollo-paper-layout does "
             f"not offer, so there is no way to ask for it")
    if described != offered:
        fail(f"apollo-paper-layout: describe() has {sorted(described)} but "
             f"available() lists {sorted(offered)}")

    if fails:
        print(f"\n{len(fails)} problem(s)")
        return 1
    print(f"ok - {len(table)} picker layout(s) across {len(files)} file(s): "
          f"{', '.join(sorted(table))} — named the same in all three places")
    return 0


if __name__ == "__main__":
    sys.exit(main())
