#!/usr/bin/env python3
"""Every key the shell reads must be a field apollo-settings can write back.

~/.config/apollo/config.json has two ends. services/Config.qml declares what
the shell reads, as JsonAdapter properties. apollo-settings/config.go declares
what the settings app loads and saves, as a struct with json tags.

The dangerous direction is QML-without-Go. saveConfig marshals that struct, so
a key with no field on the Go side is *dropped on the next save* — silently,
and not by the control that was touched. That is exactly what happened to
`chessUsername`, which the README tells you to add by hand: set a chess handle,
change any setting in the app, lose the handle.

The other direction is fine and expected: the settings app owns keys the shell
has no business reading (its own keybind table, the dynamic-colour switches,
the rofi accent). Those are listed below.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
QML = ROOT / "config/quickshell/apollo/services/Config.qml"
GO = ROOT / "apollo-settings/config.go"

# Keys apollo-settings owns and the shell deliberately does not read.
SETTINGS_ONLY = {
    "hyprland",      # rendered into generated.lua, not read by the shell
    "keybinds",      # likewise
    "rofiAccent",    # rendered into apollo-colors.rasi
    "powerProfile",  # applied to the CPU governor
    "powerPersist",
    "dynamicColors",  # the wallpaper drives the palette; see dynamic.go
    "dynamicMode",
}


def main() -> int:
    qml = QML.read_text()
    m = re.search(r"adapter: JsonAdapter \{(.*?)\n        \}", qml, re.S)
    if not m:
        print("FAIL  could not find the JsonAdapter block in Config.qml")
        return 1
    props = set(re.findall(r"property\s+\w+\s+(\w+):", m.group(1)))

    go = GO.read_text()
    m = re.search(r"type Config struct \{(.*?)\n\}", go, re.S)
    if not m:
        print("FAIL  could not find the Config struct in config.go")
        return 1
    tags = set(re.findall(r'`json:"(\w+)"', m.group(1)))

    if not props or not tags:
        print("FAIL  parsed no keys from one of the two sides")
        return 1

    fails = 0
    for key in sorted(props - tags):
        print(f"FAIL  Config.qml reads {key!r}, which config.go has no field for — "
              f"apollo-settings will drop it on the next save")
        fails += 1
    for key in sorted(tags - props - SETTINGS_ONLY):
        print(f"FAIL  config.go writes {key!r}, which no Config.qml property reads. "
              f"Add it to the adapter, or to SETTINGS_ONLY in this script if the "
              f"settings app owns it")
        fails += 1

    print(f"\nok    {len(props)} shell keys, {len(tags)} settings keys, "
          f"{len(SETTINGS_ONLY)} settings-only" if not fails
          else f"\n{fails} problem(s)")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
