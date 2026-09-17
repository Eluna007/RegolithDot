#!/usr/bin/env python3
"""Five files decide what counts as a wallpaper. They have to agree.

A wallpaper's format decides which of two paths it takes, and both answers are
spelled out separately in code that cannot see each other:

  local/bin/wallpaper-switch.sh          animated -> mpvpaper, still -> hyprpaper
  local/bin/apollo-sddm-sync             animated -> refuse, the greeter cannot play one
  apollo-settings/dynamic.go             animated -> matugen needs a frame first
  panels/WallpaperPanel.qml nameFilters  what the picker lists at all
  panels/WallpaperPanel.qml isVideo      what QML's Image cannot draw
  scripts/wallpaper-thumbs.sh            what gets a cached thumbnail

Every disagreement here is silent and shaped like a missing feature. Videos
were absent from nameFilters for as long as the picker existed, so
wallpaper-switch.sh's whole mpvpaper branch was unreachable from the UI — the
code was there, tested, and could not be run. Adding .mov to the picker without
adding it to wallpaper-switch.sh would be the same bug pointing the other way:
selectable, then handed to hyprpaper, which cannot play it.

Two sets, and the difference between them is the point:

  ANIMATED  gif mp4 webm mkv mov   mpvpaper plays these; matugen cannot read one
  NO_DECODE     mp4 webm mkv mov   QML's Image cannot draw these at all

gif is in the first and not the second: mpvpaper is what loops one on the
desktop, but the picker draws it perfectly well with AnimatedImage, so it needs
no cached *frame* — it still gets a thumbnail like everything else, because
every format the picker lists has to have one. A format shown with no
thumbnail rule is one that decodes its 4K original on every pass, forever, and
nothing about the picker would say why that one is slow.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

ANIMATED = {"gif", "mp4", "webm", "mkv", "mov"}
NO_DECODE = {"mp4", "webm", "mkv", "mov"}

fails = []


def fail(msg):
    fails.append(msg)
    print(f"FAIL  {msg}")


def shell_case(rel, label):
    """Extensions in a `*.gif|*.mp4|...)` case branch."""
    src = (ROOT / rel).read_text()
    m = re.search(r"^\s*(\*\.\w+(?:\|\*\.\w+)+)\)", src, re.M)
    if not m:
        fail(f"{rel}: no `*.ext|*.ext)` branch found — {label}")
        return set()
    return set(re.findall(r"\*\.(\w+)", m.group(1)))


def main() -> int:
    qml = (ROOT / "config/quickshell/apollo/panels/WallpaperPanel.qml").read_text()

    m = re.search(r"nameFilters:\s*\[(.*?)\]", qml, re.S)
    if not m:
        fail("WallpaperPanel.qml: no nameFilters")
        return 1
    listed = {e.lower() for e in re.findall(r'"\*\.(\w+)"', m.group(1))}

    m = re.search(r"isVideo:\s*/\\\.\(([^)]*)\)", qml)
    if not m:
        fail("WallpaperPanel.qml: no isVideo pattern")
        return 1
    no_decode_qml = set(m.group(1).split("|"))

    thumbs = (ROOT / "config/quickshell/apollo/scripts/wallpaper-thumbs.sh").read_text()
    thumbed = set(re.findall(r'"\$DIR"/\*\.(\w+)', thumbs))

    go = (ROOT / "apollo-settings/dynamic.go").read_text()
    m = re.search(r'case (\"\.\w+\"(?:, \"\.\w+\")*):', go)
    go_animated = set(re.findall(r'"\.(\w+)"', m.group(1))) if m else set()
    if not m:
        fail("dynamic.go: no extension switch found in currentStill")

    checks = [
        ("local/bin/wallpaper-switch.sh (mpvpaper branch)",
         shell_case("local/bin/wallpaper-switch.sh", "mpvpaper branch"), ANIMATED),
        ("local/bin/apollo-sddm-sync (refuse branch)",
         shell_case("local/bin/apollo-sddm-sync", "video refusal"), ANIMATED),
        ("apollo-settings/dynamic.go (currentStill)", go_animated, ANIMATED),
        ("WallpaperPanel.qml isVideo", no_decode_qml, NO_DECODE),
        # Everything the picker lists, not just the videos: the thumbnails are
        # what stop a 4K original being decoded per tile.
        ("wallpaper-thumbs.sh globs", thumbed, listed),
    ]
    for label, have, want in checks:
        if have != want:
            missing = ", ".join(sorted(want - have)) or "—"
            extra = ", ".join(sorted(have - want)) or "—"
            fail(f"{label}: missing [{missing}], unexpected [{extra}]")

    # The picker has to list everything the pipeline can apply, or the feature
    # exists and cannot be reached.
    for ext in sorted(ANIMATED - listed):
        fail(f"WallpaperPanel.qml nameFilters does not list *.{ext}, "
             f"which wallpaper-switch.sh can apply")

    if fails:
        print(f"\n{len(fails)} problem(s)")
        return 1
    print(f"ok - {len(listed)} wallpaper formats listed and all thumbnailed; "
          f"{len(ANIMATED)} animated and {len(NO_DECODE)} undecodable "
          f"spelled the same in all five places")
    return 0


if __name__ == "__main__":
    sys.exit(main())
