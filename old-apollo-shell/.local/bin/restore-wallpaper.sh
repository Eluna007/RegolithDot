#!/bin/bash
# Run at Hyprland startup instead of a bare `hyprpaper` — reapplies
# whatever wallpaper (image or video/gif) was last applied, via the same
# wallpaper-switch.sh pipeline. Falls back to a plain hyprpaper launch on
# first-ever run, when nothing's been picked yet.
LAST="$HOME/.config/hypr/last-wallpaper.txt"

if [ -f "$LAST" ]; then
  path=$(cat "$LAST")
  if [ -f "$path" ]; then
    "$HOME/.local/bin/wallpaper-switch.sh" "$path"
    exit 0
  fi
fi

hyprpaper
