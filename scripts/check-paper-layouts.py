#!/usr/bin/env python3
"""Three lists name the wallpaper picker's layouts. They have to agree.

  panels/WallpaperPanel.qml    the Loader's switch — what the shell will load
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
NOT_LAYOUTS = {"WallpaperPanel.qml", "WallpaperSource.qml", "WallpaperTile.qml",
               "WallpaperTransition.qml"}

fails = []


def fail(msg):
    fails.append(msg)
    print(f"FAIL  {msg}")


def main() -> int:
    panel = PANEL.read_text()
    m = re.search(r"switch \(Config\.paperLayout\) \{(.*?)\n            \}", panel, re.S)
    if not m:
        fail("WallpaperPanel.qml: no switch on Config.paperLayout")
        return 1
    body = m.group(1)

    cases = dict(re.findall(r'case "(\w+)":\s*return "([\w.]+)"', body))
    m = re.search(r'default:\s*return "([\w.]+)"', body)
    if not m:
        fail("WallpaperPanel.qml: the Loader has no default layout — an "
             "unknown name would load nothing")
        return 1
    default_file = m.group(1)

    cli = CLI.read_text()
    m = re.search(r"describe\(\) \{\n  case \"\$1\" in(.*?)\n  esac", cli, re.S)
    if not m:
        fail("apollo-paper-layout: no describe() case block")
        return 1
    described = {n for n in re.findall(r"^\s+(\w+)\)", m.group(1), re.M)}

    m = re.search(r"available\(\) \{ printf '%s\\n' (.*?); \}", cli)
    offered = set(m.group(1).split()) if m else set()
    if not m:
        fail("apollo-paper-layout: no available() list")

    # The default layout is reached by name too, or it could never be
    # switched *back* to once you had left it.
    files = {f.name for f in PANELS_DIR.glob("Wallpaper*.qml")} - NOT_LAYOUTS
    named_files = set(cases.values()) | {default_file}

    for name, f in sorted(cases.items()):
        if f not in files:
            fail(f"WallpaperPanel.qml maps '{name}' to {f}, which does not exist")
    if default_file not in files:
        fail(f"WallpaperPanel.qml's default is {default_file}, which does not exist")

    for f in sorted(files - named_files):
        fail(f"{f} is a layout the Loader never selects")

    # Every name the CLI offers must be one the Loader knows, or switching to
    # it silently lands on the default.
    for name in sorted(described - set(cases)):
        fail(f"apollo-paper-layout offers '{name}', which the Loader's switch "
             f"does not name (it would fall through to the default)")
    if described != offered:
        fail(f"apollo-paper-layout: describe() has {sorted(described)} but "
             f"available() lists {sorted(offered)}")

    if fails:
        print(f"\n{len(fails)} problem(s)")
        return 1
    print(f"ok - {len(files)} picker layout(s): "
          f"{', '.join(sorted(described))} — named the same in all three places")
    return 0


if __name__ == "__main__":
    sys.exit(main())
