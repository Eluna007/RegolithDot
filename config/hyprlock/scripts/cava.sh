#!/usr/bin/env bash
#
# Decorative audio visualiser for the lock screen.
#
# HONEST DESCRIPTION: despite the name, this does not read audio. Upstream
# drives it from the system clock - a folded triangle wave over the bar index -
# so it animates while something is playing without ever touching cava or
# PipeWire. Kept as-is because sampling real audio from a locked session means
# keeping a cava instance and a FIFO alive across the lock, which is a lot of
# moving parts for a decoration.
#
# Changed from upstream: it preferred Spotify by name before falling back, and
# its two colours were hardcoded gold. Colours now come from matugen, via the
# shell-sourceable half of the palette.
set -uo pipefail

VIS_BARS=48        # columns
MAX_HEIGHT=9       # rows
SPACE_CHAR=" "

# matugen writes this; the fallbacks keep the visualiser visible if a wallpaper
# change has not run yet.
COLOR_ACTIVE="#FFD97A"
COLOR_DIM="#c3b389"
# shellcheck source=/dev/null
[ -r "$HOME/.config/hyprlock/colors.sh" ] && . "$HOME/.config/hyprlock/colors.sh"
COLOR_ACTIVE="${APOLLO_ACCENT:-$COLOR_ACTIVE}"
COLOR_DIM="${APOLLO_FG_DIM:-$COLOR_DIM}"

command -v playerctl >/dev/null 2>&1 || exit 0

# Whichever player is actually playing. Upstream tried "spotify" first and only
# then fell back to the first name in the list, which on a machine without
# Spotify meant picking a paused browser tab over the thing making noise.
playing=""
while read -r p; do
    [ -n "$p" ] || continue
    if [ "$(playerctl -p "$p" status 2>/dev/null)" = "Playing" ]; then
        playing="$p"; break
    fi
done < <(playerctl -l 2>/dev/null)

# Nothing playing: print nothing. The label collapses rather than freezing on
# the last frame.
[ -n "$playing" ] || exit 0

now_ms=$(date +%s%3N)
phase=$(( now_ms / 90 ))

heights=()
for ((i = 0; i < VIS_BARS; i++)); do
    # 31 is coprime with the bar count, which stops the wave repeating visibly
    # across the row.
    h=$(( (i * 31 + phase) % (MAX_HEIGHT * 2) ))
    (( h > MAX_HEIGHT )) && h=$(( MAX_HEIGHT * 2 - h ))
    (( h < 1 )) && h=1
    heights[i]=$h
done

for ((row = MAX_HEIGHT; row > 0; row--)); do
    line=""
    for ((i = 0; i < VIS_BARS; i++)); do
        if (( heights[i] >= row )); then
            line+="<span foreground=\"$COLOR_ACTIVE\">█</span>"
        else
            line+="<span foreground=\"$COLOR_DIM\">█</span>"
        fi
        line+="$SPACE_CHAR"
    done
    echo "$line"
done
