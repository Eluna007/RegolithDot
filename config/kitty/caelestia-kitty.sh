#!/usr/bin/env bash
# Mirror caelestia's wallpaper-derived scheme into kitty, then live-reload kitty.
set -u
SCHEME="${1:-$HOME/.local/state/caelestia/scheme.json}"
OUT="${2:-$HOME/.config/kitty/caelestia-colors.conf}"
[ -f "$SCHEME" ] || exit 0

python3 - "$SCHEME" "$OUT" <<'PY'
import json, sys
scheme_path, out_path = sys.argv[1], sys.argv[2]
c = json.load(open(scheme_path))["colours"]
def h(k, default="ffffff"): return "#" + c.get(k, default)
lines = [f"color{i} {h('term'+str(i))}" for i in range(16)]
lines += [
    f"background {h('background')}",
    f"foreground {h('onBackground')}",
    f"cursor {h('primary')}",
    f"cursor_text_color {h('background')}",
]
with open(out_path, "w") as f:
    f.write("# Generated from caelestia scheme.json. Do not edit by hand.\n")
    f.write("\n".join(lines) + "\n")
PY

pkill -USR1 -x kitty 2>/dev/null || true
