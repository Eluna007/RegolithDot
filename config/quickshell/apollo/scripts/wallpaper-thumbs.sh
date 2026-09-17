#!/usr/bin/env bash
# Thumbnails for the wallpaper picker.
#
# The picker used to hand QML's Image the wallpaper itself and ask it to draw a
# 320px tile. For a JPEG that is merely wasteful — libjpeg can decode at a
# reduced scale — but a 4K PNG or WebP has to be decoded whole first: eight
# million pixels, 32 MB, to produce a thumbnail the size of a postage stamp.
# Do that for five tiles while a momentum spin is running and the picker is
# visibly behind the scroll.
#
# So: downscale every wallpaper once, cache it, and let the picker load the
# small one. Videos need it for a different reason — Image cannot decode one at
# all, so a .mp4 tile drew nothing, which is why videos were left out of the
# picker's filter entirely and wallpaper-switch.sh's whole mpvpaper path had no
# way to be reached from the UI written for it.
#
#   wallpaper-thumbs.sh [wallpaper-dir]
#   wallpaper-thumbs.sh --debug [wallpaper-dir]   what it can see and what it made
#
# The cached file is named after the original plus .png, which is the entire
# contract between this and WallpaperPanel.qml — there is no index file to fall
# out of sync. Prints one line per thumbnail made; prints nothing when they are
# all current, which is the normal case, since this runs every time the picker
# opens.
#
# The approach is lifted from iamsurjog/hyprquickpaper, which pre-caches
# downscaled copies with ImageMagick and batches the work.
set -uo pipefail

DEBUG=0
if [ "${1-}" = "--debug" ]; then DEBUG=1; shift; fi

DIR="${1:-$HOME/Pictures/Wallpapers}"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/apollo/wallpaper-thumbs"

# Wide enough for the 320px tile on a HiDPI screen with room to spare, small
# enough that decoding one is free.
WIDTH=640

# Parallelism, capped. The picker is open and waiting, so using the machine is
# the right call — but spawning one ImageMagick per wallpaper on a folder of a
# hundred would swap. APOLLO_THUMB_JOBS exists for the tests.
JOBS="${APOLLO_THUMB_JOBS:-$(nproc 2>/dev/null || echo 4)}"

[ -d "$DIR" ] || exit 0
mkdir -p "$CACHE" || exit 1

# ImageMagick 7 is `magick`; 6 is `convert`. Arch ships 7, but the two live
# side by side on plenty of machines and `convert` is what an older one has.
IM=""
if command -v magick >/dev/null 2>&1; then IM="magick"
elif command -v convert >/dev/null 2>&1; then IM="convert"
fi

have_ffmpeg=0
command -v ffmpeg >/dev/null 2>&1 && have_ffmpeg=1

if [ -z "$IM" ] && [ "$have_ffmpeg" -eq 0 ]; then
    # Not fatal: the picker falls back to loading the originals, which is what
    # it always did. It is just slower, and videos have no picture.
    echo "wallpaper-thumbs: neither ImageMagick nor ffmpeg installed; the picker will load full-size wallpapers" >&2
    exit 0
fi

# still_frame <video> <out> — one frame, a second in. The first frame of a
# video is very often black, and a black thumbnail is indistinguishable from
# one that failed to render. -frames:v 1 stops after it, so this costs a seek
# and a single decode however long the video is.
still_frame() {
    ffmpeg -y -ss 00:00:01 -i "$1" -frames:v 1 -vf "scale=$WIDTH:-2" "$2" \
           -loglevel error 2>/dev/null && [ -s "$2" ] && return 0
    # Shorter than a second, or a container ffmpeg wants to read from the top.
    rm -f "$2"
    ffmpeg -y -i "$1" -frames:v 1 -vf "scale=$WIDTH:-2" "$2" \
           -loglevel error 2>/dev/null && [ -s "$2" ]
}

# shrink <image> <out> — -auto-orient first, or a photo carrying an EXIF
# rotation is thumbnailed sideways; -strip drops the metadata afterwards, which
# is most of what is left of the file at this size.
#
# `[0]` is the frame to take, and it is not optional. Handed an animated gif
# without it, ImageMagick writes *one file per frame* — out-0.png, out-1.png,
# out-2.png — and never the out.png it was asked for. The size check below then
# fails, the thumbnail is reported as unmakeable, and the numbered frames are
# left behind in the cache under the temp name. Every gif in the folder did
# that. It applies to any multi-frame input, which here also means a .webp.
shrink() {
    "$IM" "$1[0]" -auto-orient -thumbnail "${WIDTH}x" -strip "$2" 2>/dev/null \
        && [ -s "$2" ]
}

# make <src> — writes to a temp name first: the panel reads this directory, and
# a half-written PNG is a broken image rather than a missing one.
make() {
    local src="$1"
    local out tmp ok
    out="$CACHE/$(basename "$src").png"
    tmp="$out.tmp.$$.png"
    ok=1

    case "${src,,}" in
        *.mp4|*.webm|*.mkv|*.mov)
            [ "$have_ffmpeg" -eq 1 ] && still_frame "$src" "$tmp" && ok=0 ;;
        *)
            [ -n "$IM" ] && shrink "$src" "$tmp" && ok=0 ;;
    esac

    if [ "$ok" -eq 0 ]; then
        mv -f "$tmp" "$out"
        echo "$out"
    else
        # "$tmp"-*.png as well: a tool that writes one file per frame leaves
        # numbered siblings rather than the name it was given, and those would
        # otherwise accumulate in the cache forever, invisible to the retry
        # check because they are not the file it looks for.
        #
        # Defensive, and not covered by the tests: with the `[0]` above, no
        # format tried — gif or animated webp — produces them any more. It is
        # here because they were being left behind before that fix, and it
        # costs one glob.
        rm -f "$tmp" "${tmp%.png}"-*.png
        echo "wallpaper-thumbs: could not make a thumbnail for $src" >&2
    fi
}

# --debug answers the question this script's failures actually raise: "my
# videos do not show up" has three different causes — they are not in the
# folder this is looking at, they are in a subfolder (nothing here recurses,
# and neither does the picker), or ffmpeg cannot read them. Guessing between
# those from the outside is impossible; this prints which it is.
if [ "$DEBUG" -eq 1 ]; then
    echo "wallpaper dir : $DIR"
    echo "cache dir     : $CACHE"
    echo "ImageMagick   : ${IM:-(not installed)}"
    echo "ffmpeg        : $([ "$have_ffmpeg" -eq 1 ] && echo yes || echo "(not installed)")"
    echo

    shopt -s nullglob nocaseglob
    stills=("$DIR"/*.jpg "$DIR"/*.jpeg "$DIR"/*.png "$DIR"/*.webp "$DIR"/*.bmp "$DIR"/*.gif)
    videos=("$DIR"/*.mp4 "$DIR"/*.webm "$DIR"/*.mkv "$DIR"/*.mov)
    echo "in this folder: ${#stills[@]} still(s), ${#videos[@]} video(s)"

    # Anything one level down is invisible to both this and the picker, and
    # that is by far the most common reason a wallpaper "is not there".
    nested=0
    for d in "$DIR"/*/; do
        [ -d "$d" ] || continue
        sub=("$d"*.jpg "$d"*.jpeg "$d"*.png "$d"*.webp "$d"*.gif "$d"*.mp4 "$d"*.webm "$d"*.mkv "$d"*.mov)
        nested=$((nested + ${#sub[@]}))
    done
    [ "$nested" -gt 0 ] && echo "in subfolders : $nested file(s) — NOT listed; the picker does not recurse"

    for v in "${videos[@]}"; do
        t="$CACHE/$(basename "$v").png"
        if [ -f "$t" ]; then
            echo "  frame ok    : $(basename "$v")"
        else
            echo "  NO FRAME    : $(basename "$v")"
        fi
    done
    echo
fi

shopt -s nullglob nocaseglob
for src in "$DIR"/*.jpg "$DIR"/*.jpeg "$DIR"/*.png "$DIR"/*.webp "$DIR"/*.bmp \
           "$DIR"/*.gif "$DIR"/*.mp4 "$DIR"/*.webm "$DIR"/*.mkv "$DIR"/*.mov; do
    out="$CACHE/$(basename "$src").png"

    # -nt is false when out does not exist, so this is "missing or stale" in
    # one test.
    [ -f "$out" ] && [ "$out" -nt "$src" ] && continue

    make "$src" &

    if [ "$JOBS" -gt 0 ]; then
        while [ "$(jobs -rp | wc -l)" -ge "$JOBS" ]; do wait -n; done
    fi
done

wait
exit 0
