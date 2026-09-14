#!/bin/bash
# Reads matugen's current "primary" color from colors.json and writes it
# as a hyprlock-readable variable, so the lock screen's accent color
# stays in sync with whatever wallpaper is active. Run both whenever the
# wallpaper changes and right before hyprlock launches (cheap, local).
COLORS="$HOME/.config/quickshell/colors.json"
OUT="$HOME/.config/hypr/hyprlock-colors.conf"
FALLBACK="\$accent = rgb(138, 180, 248)"

if [ -f "$COLORS" ]; then
  rgb=$(python3 -c "
import json, sys
try:
    with open('$COLORS') as f:
        data = json.load(f)
    hexcolor = data.get('primary', '').lstrip('#')
    if len(hexcolor) == 6:
        r = int(hexcolor[0:2], 16)
        g = int(hexcolor[2:4], 16)
        b = int(hexcolor[4:6], 16)
        print(f'{r}, {g}, {b}')
except Exception:
    pass
")
  if [ -n "$rgb" ]; then
    echo "\$accent = rgb($rgb)" > "$OUT"
    exit 0
  fi
fi

echo "$FALLBACK" > "$OUT"
