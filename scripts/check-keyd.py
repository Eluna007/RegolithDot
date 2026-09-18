#!/usr/bin/env python3
"""keyd must not be pointed at the pointing devices.

keyd captures a device with EVIOCGRAB and re-emits its events through a virtual
one. For a keyboard that is the point. For a touchpad it is a grab-and-re-emit
path with no reason to exist, and an intermittently dead touchpad is what it
looks like from the outside.

A bare `*` in [ids] does exactly that, and neither half of it is obvious:

  device.c:192    keyd manages a device if it has *any* capability, so mice and
                  touchpads are enumerated alongside keyboards
  config.c:1071   config_check_match() ends with
                  `return config->wildcard ? 1 : 0` — the wildcard does no
                  capability filtering at all

`k:*` is not the fix either. The `k:` branch stores what follows as a literal
id and matching is a prefix compare against ids like "04f3:0007", so `k:*`
matches nothing, never sets the wildcard, and keyd captures nothing — the
remaps stop working silently. Exclusions are the mechanism keyd provides.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONF = ROOT / "config/keyd/default.conf"

fails = []


def fail(msg):
    fails.append(msg)
    print(f"FAIL  {msg}")


def main() -> int:
    if not CONF.is_file():
        fail(f"{CONF.relative_to(ROOT)} is missing")
        return 1

    lines = [ln.split("#")[0].strip() for ln in CONF.read_text().splitlines()]

    try:
        start = next(i for i, ln in enumerate(lines) if ln == "[ids]")
    except StopIteration:
        fail("no [ids] section — keyd requires one and refuses the file without it")
        return 1

    ids = []
    for ln in lines[start + 1:]:
        if ln.startswith("["):
            break
        if ln:
            ids.append(ln)

    if not ids:
        fail("[ids] is empty")
        return 1

    if any(i.startswith("k:") or i.startswith("m:") for i in ids):
        for i in ids:
            if i in ("k:*", "m:*"):
                fail(f"{i!r} matches no device: the prefix takes a literal id, "
                     f"so this never matches and the wildcard is never set — "
                     f"keyd would capture nothing and the remaps would stop "
                     f"working with no error")

    if "*" in ids:
        excluded = [i[1:] for i in ids if i.startswith("-")]
        if not excluded:
            fail("[ids] is a bare `*` with nothing excluded — that hands keyd "
                 "every pointing device on the machine, touchpad included")
        else:
            print(f"ok    wildcard with {len(excluded)} device(s) excluded: "
                  f"{', '.join(excluded)}")
    else:
        print(f"ok    {len(ids)} explicit device id(s), no wildcard")

    if fails:
        print(f"\n{len(fails)} problem(s)")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
