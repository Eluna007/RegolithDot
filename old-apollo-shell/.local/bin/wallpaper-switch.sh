#!/bin/bash
# Wofi flow retired — the Quickshell carousel (SUPER+W) is the only picker.
# This script just applies whatever path it's given.
selected="$1"
[ -z "$selected" ] && exit 0

# Remember this pick so it can be restored on the next boot.
echo "$selected" > "$HOME/.config/hypr/last-wallpaper.txt"

case "$selected" in
  *.gif|*.mp4|*.webm|*.mkv)
    # Video AND gif both need mpvpaper — hyprpaper only ever shows a
    # static single frame, it can't animate a gif at all. mpv can loop
    # a gif exactly like a video.
    pkill hyprpaper 2>/dev/null
    pkill mpvpaper 2>/dev/null
    sleep 0.2
    mpvpaper -o "no-audio loop" '*' "$selected" &

    FRAME="/tmp/wallpaper-frame.png"
    ffmpeg -y -ss 00:00:01 -i "$selected" -frames:v 1 "$FRAME" -loglevel error
    matugen image "$FRAME" --source-color-index 0
    ~/.local/bin/generate-hyprlock-colors.sh
    ;;
  *)
    # Image-to-image: never restart hyprpaper. It supports live preload +
    # swap over its own IPC — that's the whole point of the daemon design,
    # and it's what avoids the flash of the bare compositor background.
    pkill mpvpaper 2>/dev/null
    if ! pgrep -x hyprpaper >/dev/null; then
      hyprpaper &
      sleep 0.5
    fi
    hyprctl hyprpaper preload "$selected"
    hyprctl hyprpaper wallpaper ",$selected,fill"

    matugen image "$selected" --source-color-index 0
    ~/.local/bin/generate-hyprlock-colors.sh
    ;;
esac
