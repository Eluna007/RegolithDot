#!/usr/bin/env python3
"""The palette is declared in three places; they have to agree.

  services/Config.qml   _flavors        what the shell draws with
  apollo-settings/palette.go flavorRamps  the neutral ramp wallust re-tints
  apollo-settings/apps.go    flavorAccents the accent family fanned out to apps

Drift here is silent and ugly: the bar renders one Mocha and the terminal
another, or a flavor the shell knows about has no accents in Go and every
colour in kitty's generated file comes out empty.

Also checks that every @define-color the GTK stylesheets *use* is one the
committed apollo-colors.default.css defines. GTK does not report an undefined
colour name — the widget just draws wrong.

The `.default.*` files are what a fresh clone is seeded from by apollo-doctor;
the files the apps actually read are gitignored machine state, because
apollo-settings rewrites them and ~/.config is symlinked into this repo.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
QML = ROOT / "config/quickshell/apollo/services/Config.qml"
PALETTE_GO = ROOT / "apollo-settings/palette.go"
APPS_GO = ROOT / "apollo-settings/apps.go"

NEUTRALS = ["base", "mantle", "crust", "surface0", "surface1", "surface2",
            "overlay0", "overlay1", "overlay2", "subtext0", "subtext1", "text"]
ACCENTS = ["rosewater", "flamingo", "pink", "mauve", "red", "maroon", "peach",
           "yellow", "green", "teal", "sky", "sapphire", "blue", "lavender"]

fails = []


def fail(msg):
    fails.append(msg)
    print(f"FAIL  {msg}")


def qml_flavors():
    src = QML.read_text()
    m = re.search(r"readonly property var _flavors: \(\{(.*?)\}\)\n", src, re.S)
    if not m:
        fail("could not find the _flavors table in Config.qml")
        return {}
    out = {}
    for name, body in re.findall(r'"(\w+)":\s*\{([^}]*)\}', m.group(1)):
        out[name] = dict(re.findall(r'(\w+):\s*"(#[0-9a-fA-F]{6})"', body))
    return out


def go_table(path, var):
    src = path.read_text()
    m = re.search(r"var %s = map\[string\]map\[string\]string\{(.*?)\n\}\n" % var, src, re.S)
    if not m:
        fail(f"could not find {var} in {path.relative_to(ROOT)}")
        return {}
    out = {}
    for name, body in re.findall(r'"(\w+)":\s*\{(.*?)\n\t\},', m.group(1), re.S):
        out[name] = dict(re.findall(r'"(\w+)":\s*"(#[0-9a-fA-F]{6})"', body))
    return out


def compare(label, qml, go, slots):
    if set(qml) != set(go):
        fail(f"{label}: flavors differ — QML has {sorted(qml)}, Go has {sorted(go)}")
        return
    for flavor in sorted(qml):
        for slot in slots:
            q, g = qml[flavor].get(slot), go[flavor].get(slot)
            if q is None:
                fail(f"{label}: Config.qml {flavor} is missing {slot}")
            elif g is None:
                fail(f"{label}: Go {flavor} is missing {slot}")
            elif q.lower() != g.lower():
                fail(f"{label}: {flavor}.{slot} is {g} in Go but {q} in Config.qml")
    print(f"ok    {label}: {len(qml)} flavors x {len(slots)} slots agree")


def check_gtk():
    for major in (3, 4):
        css = ROOT / f"config/gtk-{major}.0/gtk.css"
        gen = ROOT / f"config/gtk-{major}.0/apollo-colors.default.css"
        if not gen.is_file():
            fail(f"gtk-{major}.0/apollo-colors.default.css is missing — a fresh clone has nothing to seed from")
            continue
        defined = set(re.findall(r"@define-color\s+(\w+)", gen.read_text()))
        body = css.read_text()
        if '@import url("apollo-colors.css");' not in body:
            fail(f"gtk-{major}.0/gtk.css does not import apollo-colors.css")
        used = set(re.findall(r"@(\w+)", body)) - {"import", "define", "media", "keyframes"}
        missing = sorted(used - defined)
        if missing:
            fail(f"gtk-{major}.0/gtk.css uses undefined colours: {missing}")
        else:
            print(f"ok    gtk-{major}.0: {len(used)} colour names, all defined")


def check_kitty():
    conf = ROOT / "config/kitty/kitty.conf"
    gen = ROOT / "config/kitty/apollo-colors.default.conf"
    if not gen.is_file():
        fail("kitty/apollo-colors.default.conf is missing — a fresh clone has nothing to seed from")
        return
    if "include apollo-colors.conf" not in conf.read_text():
        fail("kitty.conf does not include apollo-colors.conf")
        return
    keys = {line.split()[0] for line in gen.read_text().splitlines()
            if line.strip() and not line.startswith("#")}
    missing = [f"color{i}" for i in range(16) if f"color{i}" not in keys]
    if missing:
        fail(f"kitty/apollo-colors.default.conf is missing {missing}")
    else:
        print(f"ok    kitty: {len(keys)} colour keys, all 16 ANSI slots present")


def main():
    qml = qml_flavors()
    compare("neutral ramp", qml, go_table(PALETTE_GO, "flavorRamps"), NEUTRALS)
    compare("accent family", qml, go_table(APPS_GO, "flavorAccents"), ACCENTS)
    check_kitty()
    check_gtk()
    print(f"\n{len(fails)} problem(s)")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
