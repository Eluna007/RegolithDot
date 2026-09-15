"""The lock screen's layout list lives in three places; they must agree.

  config/hyprlock/layouts/layout*.conf   the layouts themselves
  apollo-settings/lock.go                lockLayouts, the Lock tab's radio
  local/bin/apollo-lock-layout           describe(), the CLI

Drift here is quiet and only shows up on a locked screen: a layout the files
have but the lists do not is simply unreachable, and one the lists have but
the files do not writes a `source` at nothing, which locks to a bare
background with no widgets and no diagnostic.

Also checks the indirection itself - hyprlock.conf must source the generated
layout.conf and must not source a layout directly, or switching layouts would
edit a tracked file (and two layouts would draw over each other).
"""
import pathlib, re, sys

bad = []

# ── the three lists ─────────────────────────────────────────────────────
on_disk = {p.name[len("layout"):-len(".conf")]
           for p in pathlib.Path("config/hyprlock/layouts").glob("layout*.conf")}

go = pathlib.Path("apollo-settings/lock.go").read_text()
block = re.search(r"var lockLayouts = \[\]lockLayout\{.*?\n\}", go, re.S)
if not block:
    print("apollo-settings/lock.go: could not find the lockLayouts list"); sys.exit(1)
in_go = set(re.findall(r'\{"(\d+)",', block.group(0)))

sh = pathlib.Path("local/bin/apollo-lock-layout").read_text()
desc = re.search(r"^describe\(\) \{.*?^\}", sh, re.S | re.M)
if not desc:
    print("local/bin/apollo-lock-layout: could not find describe()"); sys.exit(1)
in_sh = set(re.findall(r"^\s*(\d+)\)", desc.group(0), re.M))

if not on_disk:
    bad.append("config/hyprlock/layouts/ has no layout*.conf files")
if in_go != on_disk:
    bad.append(f"apollo-settings/lock.go lists {sorted(in_go)} but "
               f"config/hyprlock/layouts/ has {sorted(on_disk)}")
if in_sh != on_disk:
    bad.append(f"local/bin/apollo-lock-layout describes {sorted(in_sh)} but "
               f"config/hyprlock/layouts/ has {sorted(on_disk)}")

# ── the default the Reset button writes must exist ──────────────────────
m = re.search(r'const defaultLockLayout = "(\d+)"', go)
if not m:
    bad.append("apollo-settings/lock.go: no defaultLockLayout constant")
elif m.group(1) not in on_disk:
    bad.append(f"apollo-settings/lock.go: defaultLockLayout is {m.group(1)}, "
               f"which is not in config/hyprlock/layouts/")

# ── the indirection ─────────────────────────────────────────────────────
entry = pathlib.Path("config/hypr/hyprlock.conf").read_text()
sources = [l.split("=", 1)[1].strip()
           for l in entry.split("\n")
           if not l.lstrip().startswith("#") and re.match(r"\s*source\s*=", l)]

if "$hyprlockDir/layout.conf" not in sources:
    bad.append("config/hypr/hyprlock.conf does not source $hyprlockDir/layout.conf")
direct = [s for s in sources if "/layouts/" in s]
if direct:
    bad.append(f"config/hypr/hyprlock.conf sources a layout directly ({', '.join(direct)}); "
               "it must go through layout.conf so switching does not edit a tracked file")

# ── layout.conf is machine state, so it must never be committed ─────────
if "config/hyprlock/layout.conf" not in pathlib.Path(".gitignore").read_text().split("\n"):
    bad.append(".gitignore does not ignore config/hyprlock/layout.conf")
if pathlib.Path("config/hyprlock/layout.conf").exists():
    bad.append("config/hyprlock/layout.conf is checked in; it is machine state")

if bad:
    print("\n".join(bad)); sys.exit(1)
print(f"ok - layouts {sorted(on_disk)} agree across lock.go, apollo-lock-layout "
      f"and config/hyprlock/layouts; hyprlock.conf sources them via layout.conf")
