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
    # Image-to-image: never restart hyprpaper. It swaps over its own IPC,
    # which is what avoids the flash of the bare compositor background.
    pkill mpvpaper 2>/dev/null
    if ! pgrep -x hyprpaper >/dev/null; then
      hyprpaper &
      # Wait for hyprpaper's IPC to actually answer instead of guessing at a
      # sleep. A flat 0.5s was enough when hyprpaper was already warm, but not
      # at a cold start, where the compositor is bringing up the shell, two
      # portals and several daemons at the same time: the wallpaper request
      # landed before the socket was listening, was dropped, and the session
      # came up on the default Hyprland background.
      for _ in $(seq 1 60); do
        hyprctl hyprpaper listactive >/dev/null 2>&1 && break
        sleep 0.25
      done
    fi

    # hyprpaper's IPC no longer has `preload` (nor `unload`/`listloaded`) —
    # `wallpaper` loads the image on demand. Calling preload just returns
    # "invalid hyprpaper request". The surviving requests are:
    #   hyprctl hyprpaper wallpaper '[mon], [path], [fit_mode]'
    #   hyprctl hyprpaper listactive
    # Empty monitor = fallback, i.e. every output.
    if ! hyprctl hyprpaper wallpaper ",$selected,fill"; then
      echo "wallpaper-switch: hyprpaper rejected the wallpaper request" >&2
      exit 1
    fi

    matugen image "$selected" --source-color-index 0
    ~/.local/bin/generate-hyprlock-colors.sh
    ;;
esac
