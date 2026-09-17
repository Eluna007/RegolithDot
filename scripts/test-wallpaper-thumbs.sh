#!/usr/bin/env bash
# wallpaper-thumbs.sh downscales every wallpaper so the picker loads a small
# file instead of decoding a 4K original per tile, and pulls a still frame out
# of each video, which Image cannot draw at all. ffmpeg and ImageMagick are
# both stubbed: what matters here is which files are asked about, what the
# thumbnails end up called, and what happens when one cannot be made — not
# anybody's decoding.
#
# Run: scripts/test-wallpaper-thumbs.sh
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/config/quickshell/apollo/scripts/wallpaper-thumbs.sh"
fails=0

ok()   { echo "  ok   $1"; }
fail() { echo "  FAIL $1${2:+: $2}"; fails=$((fails + 1)); }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
walls="$work/walls"; cache="$work/cache"; bin="$work/bin"
mkdir -p "$walls" "$bin"

# A stub ffmpeg that writes a non-empty file at whatever output path it is
# given, and refuses anything named "broken".
# "broken" fails outright. "truncated" is the nastier one: ffmpeg reports
# success having written nothing, which is what a zero-length or partly
# written frame looks like from the outside.
cat > "$bin/ffmpeg" <<'STUB'
#!/bin/sh
out=""
for a in "$@"; do case "$a" in *.png) out="$a";; esac; done
for a in "$@"; do case "$a" in *broken*) exit 1;; esac; done
for a in "$@"; do case "$a" in *truncated*) : > "$out"; exit 0;; esac; done
printf 'FFMPEG' > "$out"
STUB
chmod +x "$bin/ffmpeg"

# ImageMagick 7's name. The last argument is the output. Each stub writes its
# own name, so a test can tell which tool a thumbnail came from — that is the
# only way to catch a video being dispatched to the image branch, which
# otherwise produces a perfectly good-looking file.
cat > "$bin/magick" <<'STUB'
#!/bin/sh
echo "$@" >> "$MAGICK_ARGV_LOG"
eval out=\$$#
for a in "$@"; do case "$a" in *broken*) exit 1;; esac; done
for a in "$@"; do case "$a" in *truncated*) : > "$out"; exit 0;; esac; done

# Multi-frame input without an explicit frame: ImageMagick writes one file per
# frame - out-0.png, out-1.png - and never the name it was asked for. This is
# real behaviour, verified against ImageMagick, and every gif hit it.
case "$1" in
  *.gif|*.GIF)
    base="${out%.png}"
    printf 'MAGICK' > "$base-0.png"
    printf 'MAGICK' > "$base-1.png"
    exit 0
    ;;
esac
printf 'MAGICK' > "$out"
STUB
chmod +x "$bin/magick"

# Two cut-down PATHs, for "what if the machine has neither tool" and "what if
# it has only one". They cannot simply be empty: the script's shebang is
# `env bash`, and it shells out to basename, mv and friends — an empty PATH
# would test that bash is missing, which is not a case worth handling.
mkdir -p "$work/empty" "$work/ffonly"
for t in bash sh mkdir nproc basename mv rm ls stat wc cat; do
    src="$(command -v "$t" 2>/dev/null)"
    [ -n "$src" ] || continue
    ln -sf "$src" "$work/empty/$t"
    ln -sf "$src" "$work/ffonly/$t"
done
ln -sf "$bin/ffmpeg" "$work/ffonly/ffmpeg"

export MAGICK_ARGV_LOG="$work/magick.argv"
: > "$MAGICK_ARGV_LOG"

run() { PATH="$bin:$PATH" XDG_CACHE_HOME="$cache" "$SCRIPT" "$walls" 2>&1; }

: > "$walls/still.png"
: > "$walls/photo.jpg"
: > "$walls/Sunset.JPG"
: > "$walls/loop.gif"
: > "$walls/clip.mp4"
: > "$walls/loop.webm"
: > "$walls/Scene.MKV"

out="$(run)"
thumbs="$cache/apollo/wallpaper-thumbs"

# The name is the video's own filename plus .png. The panel derives the path
# from that rule alone, so it is the contract between the two - there is no
# index file to disagree with.
for want in clip.mp4.png loop.webm.png; do
    if [ -f "$thumbs/$want" ]; then ok "made $want"; else fail "no frame for $want" "$out"; fi
done

# Case matters on a filesystem, not to a person naming their wallpapers — and
# it decides more than whether the file is seen. A .MKV matched case-sensitively
# falls through to the image branch, where ImageMagick produces a perfectly
# good-looking thumbnail of nothing. Checking which tool made it is the only
# way to see that.
if [ -f "$thumbs/Scene.MKV.png" ]; then
    if grep -q FFMPEG "$thumbs/Scene.MKV.png"; then
        ok "matches video extensions whatever their case"
    else
        fail "an uppercase video was thumbnailed as an image"
    fi
else
    fail "an uppercase extension was skipped" "$(ls "$thumbs")"
fi

# Stills are the whole point of the lag fix: the picker was decoding a 4K
# original per tile to draw a 320px thumbnail.
for want in photo.jpg.png still.png.png Sunset.JPG.png; do
    if [ -f "$thumbs/$want" ]; then ok "downscaled $want"; else fail "no thumbnail for $want" "$(ls "$thumbs")"; fi
done

# A gif is multi-frame, so it has to name the frame it wants. Without `[0]`
# ImageMagick writes out-0.png, out-1.png and never out.png — so the thumbnail
# is reported unmakeable and the numbered frames pile up in the cache, where
# the retry check cannot even see them because they are not the name it looks
# for. Every gif in the folder did this.
if [ -f "$thumbs/loop.gif.png" ]; then
    ok "thumbnails a gif"
else
    fail "a gif got no thumbnail" "$(ls "$thumbs")"
fi
if ls "$thumbs"/*-0.png >/dev/null 2>&1 || ls "$thumbs"/*-1.png >/dev/null 2>&1; then
    fail "left ImageMagick's numbered frames in the cache" "$(ls "$thumbs")"
else
    ok "leaves no numbered frames behind"
fi

# -auto-orient has to come before -thumbnail. ImageMagick applies operators in
# order, so rotating after the resize does nothing — and a photo carrying an
# EXIF rotation is thumbnailed on its side, which looks like a badly cropped
# wallpaper rather than a bug.
if grep -q -- '-auto-orient -thumbnail' "$MAGICK_ARGV_LOG"; then
    ok "orients before resizing"
else
    fail "-auto-orient is missing or applied after -thumbnail" "$(head -1 "$MAGICK_ARGV_LOG")"
fi

# This runs every time the picker opens, so the steady state has to be free.
before="$(stat -c '%Y %n' "$thumbs"/* | sort)"
sleep 1
out="$(run)"
after="$(stat -c '%Y %n' "$thumbs"/* | sort)"
if [ -z "$out" ] && [ "$before" = "$after" ]; then
    ok "a second run does nothing"
else
    fail "re-made frames that were already current" "$out"
fi

# A wallpaper edited or replaced in place must not keep its old frame.
touch "$walls/clip.mp4"
out="$(run)"
if echo "$out" | grep -q "clip.mp4.png"; then
    ok "re-makes a frame when the video is newer"
else
    fail "a stale frame was kept" "$out"
fi

# A video ffmpeg cannot read is one bad wallpaper, not a broken picker.
: > "$walls/broken.mp4"
out="$(run)"; rc=$?
if [ $rc -eq 0 ] && echo "$out" | grep -q "could not make a thumbnail"; then
    ok "reports an unreadable video and carries on"
else
    fail "an unreadable video was not reported" "$out"
fi
if [ -f "$thumbs/broken.mp4.png" ]; then
    fail "left an empty frame behind for an unreadable video"
else
    ok "leaves no half-written frame behind"
fi

# The same from ImageMagick, on the path stills take.
: > "$walls/truncated.jpg"
out="$(run)"
if [ -e "$thumbs/truncated.jpg.png" ]; then
    fail "kept a zero-length image thumbnail" "$(ls -l "$thumbs")"
else
    ok "throws away an image thumbnail ImageMagick did not write"
fi

# ffmpeg exiting 0 having written nothing. An empty .png is worse than no
# file: the panel would show a broken image and the cache would keep serving
# it forever, since it is newer than the video.
: > "$walls/truncated.mp4"
out="$(run)"
if [ -e "$thumbs/truncated.mp4.png" ] || [ -e "$thumbs/truncated.mp4.png.tmp.png" ]; then
    fail "kept a zero-length frame" "$(ls -l "$thumbs")"
else
    ok "throws away a frame ffmpeg claimed to write but did not"
fi

# Neither tool installed: the picker still has to open. It falls back to
# loading the originals, which is what it always did.
out="$(PATH="$work/empty" XDG_CACHE_HOME="$cache" "$SCRIPT" "$walls" 2>&1)"
rc=$?
if [ $rc -eq 0 ] && echo "$out" | grep -q "full-size"; then
    ok "says so and exits cleanly with neither ImageMagick nor ffmpeg"
else
    fail "failed with no thumbnailing tools" "$out"
fi

# Only ffmpeg: videos still get frames, images get nothing, and the run
# succeeds either way. Half the feature is not a reason to refuse the half
# that works.
rm -rf "${cache:?}/apollo"
out="$(PATH="$work/ffonly" XDG_CACHE_HOME="$cache" "$SCRIPT" "$walls" 2>&1)"; rc=$?
if [ $rc -eq 0 ] && [ -f "$thumbs/clip.mp4.png" ] && [ ! -f "$thumbs/photo.jpg.png" ]; then
    ok "with only ffmpeg, videos get frames and the run still succeeds"
else
    fail "the one-tool case was not handled" "$out"
fi

# --debug is the answer to "my videos do not show up", which has three
# different causes that look identical from the outside.
mkdir -p "$walls/nested"
: > "$walls/nested/tucked-away.mp4"
out="$(PATH="$bin:$PATH" XDG_CACHE_HOME="$cache" "$SCRIPT" --debug "$walls" 2>&1)"
if echo "$out" | grep -q "NOT listed; the picker does not recurse"; then
    ok "--debug reports files hidden in a subfolder"
else
    fail "--debug did not mention the subfolder" "$out"
fi
if echo "$out" | grep -qE "in this folder: [0-9]+ still\(s\), [0-9]+ video\(s\)"; then
    ok "--debug counts what it can see"
else
    fail "--debug printed no counts" "$out"
fi
rm -rf "$walls/nested"

# A wallpaper directory that does not exist yet is not an error either.
out="$(PATH="$bin:$PATH" XDG_CACHE_HOME="$cache" "$SCRIPT" "$work/nope" 2>&1)"; rc=$?
if [ $rc -eq 0 ]; then ok "a missing wallpaper directory is not an error"; else fail "failed on a missing directory" "$out"; fi

if [ $fails -gt 0 ]; then echo; echo "$fails failure(s)"; exit 1; fi
echo; echo "ok - wallpaper-thumbs.sh"
