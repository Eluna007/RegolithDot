#!/usr/bin/env bash
# Still frames for the video wallpapers in the picker.
#
# The carousel draws its thumbnails with QML's Image, which cannot decode a
# video at all — a .mp4 renders as nothing, with no error anywhere. Videos were
# simply left out of the picker's file filter because of it, which meant
# wallpaper-switch.sh's whole mpvpaper path (gifs and video, the thing
# hyprpaper cannot do) had no way to be reached from the UI.
#
# So: pull one frame out of each video, once, and cache it. The name is the
# video's own filename plus .png, so the panel can work out the path without
# this script telling it anything — no index file, nothing to get out of sync.
#
#   wallpaper-thumbs.sh [wallpaper-dir]
#
# Prints one line per frame it made. Prints nothing when everything is current,
# which is the normal case: this runs every time the picker opens.
set -uo pipefail

DIR="${1:-$HOME/Pictures/Wallpapers}"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/apollo/wallpaper-thumbs"

[ -d "$DIR" ] || exit 0

if ! command -v ffmpeg >/dev/null 2>&1; then
    # Not fatal, and not silent either: the panel falls back to a placeholder
    # tile, so the wallpaper is still selectable — it just has no picture.
    echo "wallpaper-thumbs: ffmpeg not installed; video wallpapers will have no thumbnail" >&2
    exit 0
fi

mkdir -p "$CACHE" || exit 1

made=0
shopt -s nullglob nocaseglob
for src in "$DIR"/*.mp4 "$DIR"/*.webm "$DIR"/*.mkv "$DIR"/*.mov; do
    out="$CACHE/$(basename "$src").png"

    # -nt is false when out does not exist, which is the first-run case, so
    # this covers "missing" and "stale" in one test.
    [ -f "$out" ] && [ "$out" -nt "$src" ] && continue

    # One second in: the first frame of a video is very often black, and a
    # black thumbnail is indistinguishable from one that failed to render.
    # -frames:v 1 stops after it, so this costs a seek and a single decode
    # however long the video is.
    #
    # Written to a temp name first: the panel watches this directory, and a
    # half-written PNG is a broken image rather than a missing one.
    tmp="$out.tmp.png"
    if ffmpeg -y -ss 00:00:01 -i "$src" -frames:v 1 \
              -vf "scale=560:-2" "$tmp" -loglevel error 2>/dev/null \
       && [ -s "$tmp" ]; then
        mv -f "$tmp" "$out"
        echo "$out"
        made=$((made + 1))
    else
        rm -f "$tmp"
        # A video shorter than a second, or one ffmpeg cannot read. Try frame
        # zero before giving up on it.
        if ffmpeg -y -i "$src" -frames:v 1 -vf "scale=560:-2" "$tmp" \
                  -loglevel error 2>/dev/null && [ -s "$tmp" ]; then
            mv -f "$tmp" "$out"
            echo "$out"
            made=$((made + 1))
        else
            rm -f "$tmp"
            echo "wallpaper-thumbs: could not read a frame out of $src" >&2
        fi
    fi
done

exit 0
