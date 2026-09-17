#!/usr/bin/env python3
"""The login screen's theme.conf and the code that generates it must agree.

Three files spell out the same set of colour keys:

  sddm/themes/apollo/Main.qml   root.conf("<key>", …) — what the greeter reads
  sddm/themes/apollo/theme.conf the committed starting point
  apollo-settings/login.go      renderLoginColors — what a wallpaper change writes

A key that is read but never written comes back as an empty string, and an
empty string is not a colour: QML logs a warning nobody will ever see and
paints black. On a login screen that is a black rectangle with no password
field and no way in — you would be looking at a machine that appears not to
boot. The fallbacks in Main.qml mean today's answer is Mocha rather than
black, which is the right behaviour and also exactly why this has to be
checked rather than noticed.

Also checks the metadata SDDM itself reads, since a theme that fails to load
does not report anything — SDDM quietly falls back to its built-in one, which
looks like the theme "not applying".
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
THEME = ROOT / "sddm/themes/apollo"
MAIN = THEME / "Main.qml"
CONF = THEME / "theme.conf"
META = THEME / "metadata.desktop"
LOGIN_GO = ROOT / "apollo-settings/login.go"

fails = []


def fail(msg):
    fails.append(msg)
    print(f"FAIL  {msg}")


def main() -> int:
    for p in (MAIN, CONF, META, LOGIN_GO):
        if not p.exists():
            fail(f"{p.relative_to(ROOT)} is missing")
    if fails:
        return 1

    main_src = MAIN.read_text()
    read_keys = set(re.findall(r'conf\("(\w+)"', main_src))
    # `background` is added by apollo-sddm-sync, not by login.go, because only
    # the sync knows what the image ends up being called inside the theme.
    read_keys.discard("background")

    conf_keys = set(re.findall(r"^(\w+)=", CONF.read_text(), re.M))
    written_keys = set(re.findall(r'\{"(\w+)",', LOGIN_GO.read_text()))

    for key in sorted(read_keys - conf_keys):
        fail(f'Main.qml reads "{key}", which theme.conf does not define')
    for key in sorted(read_keys - written_keys):
        fail(f'Main.qml reads "{key}", which renderLoginColors does not write')
    for key in sorted(written_keys - read_keys):
        fail(f'renderLoginColors writes "{key}", which Main.qml never reads')

    for key, value in re.findall(r"^(\w+)=(.*)$", CONF.read_text(), re.M):
        if key != "background" and not re.fullmatch(r"#[0-9a-fA-F]{6}", value):
            fail(f"theme.conf {key}={value!r} is not a #rrggbb colour")

    meta = META.read_text()
    for key, want in (("MainScript", "Main.qml"), ("ConfigFile", "theme.conf")):
        m = re.search(rf"^{key}=(.*)$", meta, re.M)
        if not m:
            fail(f"metadata.desktop has no {key}")
        elif m.group(1).strip() != want:
            fail(f"metadata.desktop {key}={m.group(1).strip()!r}, want {want!r}")
        elif not (THEME / want).exists():
            fail(f"metadata.desktop {key} names {want}, which does not exist")

    # Without QtVersion=6 SDDM runs the Qt 5 greeter, and Qt 5 is not on a
    # current Arch install at all — the theme never loads.
    if not re.search(r"^QtVersion=6$", meta, re.M):
        fail("metadata.desktop does not set QtVersion=6")

    # The same rule the shell is held to (scripts/check-qml.py): a
    # NumberAnimation-on-property is a property value source that starts at
    # component completion and permanently replaces the binding.
    for m in re.finditer(r"NumberAnimation\s+on\s+(\w+)", main_src):
        fail(f"Main.qml uses `NumberAnimation on {m.group(1)}` — use a Behavior")

    if fails:
        print(f"\n{len(fails)} problem(s)")
        return 1
    print(f"ok - the login screen's {len(read_keys)} colour keys are defined, "
          "generated and read by the same names")
    return 0


if __name__ == "__main__":
    sys.exit(main())
