#!/usr/bin/env bash
# wallpaper-thumbs.sh pulls a still frame out of each video wallpaper so the
# picker has something to draw. ffmpeg is stubbed: what matters here is which
# files it is asked about, what the frames end up called, and what happens when
# a video cannot be read — not ffmpeg's decoding.
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
printf 'PNG' > "$out"
STUB
chmod +x "$bin/ffmpeg"

run() { PATH="$bin:$PATH" XDG_CACHE_HOME="$cache" "$SCRIPT" "$walls" 2>&1; }

: > "$walls/still.png"
: > "$walls/photo.jpg"
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

# Case matters on a filesystem, not to a person naming their wallpapers.
if [ -f "$thumbs/Scene.MKV.png" ]; then
    ok "matches video extensions whatever their case"
else
    fail "an uppercase extension was skipped" "$(ls "$thumbs")"
fi

# Stills are the picker's own job; a frame of a JPEG is wasted work and a
# second copy of the same picture in the cache.
if [ -f "$thumbs/photo.jpg.png" ] || [ -f "$thumbs/still.png.png" ]; then
    fail "made a thumbnail for a still image" "$(ls "$thumbs")"
else
    ok "leaves still images alone"
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
if [ $rc -eq 0 ] && echo "$out" | grep -q "could not read a frame"; then
    ok "reports an unreadable video and carries on"
else
    fail "an unreadable video was not reported" "$out"
fi
if [ -f "$thumbs/broken.mp4.png" ]; then
    fail "left an empty frame behind for an unreadable video"
else
    ok "leaves no half-written frame behind"
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

# No ffmpeg at all: the picker still has to open.
out="$(PATH="$work/empty:/usr/bin:/bin" XDG_CACHE_HOME="$cache" "$SCRIPT" "$walls" 2>&1)"
rc=$?
if [ $rc -eq 0 ]; then ok "exits cleanly with no ffmpeg installed"; else fail "failed without ffmpeg" "$out"; fi

# A wallpaper directory that does not exist yet is not an error either.
out="$(PATH="$bin:$PATH" XDG_CACHE_HOME="$cache" "$SCRIPT" "$work/nope" 2>&1)"; rc=$?
if [ $rc -eq 0 ]; then ok "a missing wallpaper directory is not an error"; else fail "failed on a missing directory" "$out"; fi

if [ $fails -gt 0 ]; then echo; echo "$fails failure(s)"; exit 1; fi
echo; echo "ok - wallpaper-thumbs.sh"
