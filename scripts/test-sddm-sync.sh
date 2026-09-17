#!/usr/bin/env bash
# apollo-sddm-sync copies the desktop's wallpaper and palette into the login
# screen's theme. Everything it does is a file operation as root against two
# directories, so it can be driven end to end against temporary ones.
#
# Run: scripts/test-sddm-sync.sh
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SYNC="$ROOT/local/bin/apollo-sddm-sync"
fails=0

ok()   { echo "  ok   $1"; }
fail() { echo "  FAIL $1${2:+: $2}"; fails=$((fails + 1)); }

# want <label> <0|1 expected> <command…> — `ok` when the command's exit status
# matches. Written as a function rather than `cmd && ok || fail` because that
# chain runs `fail` when `ok` itself fails, which is a trap worth not laying.
want() {
    local label="$1" expect="$2"; shift 2
    if "$@" >/dev/null 2>&1; then [ "$expect" -eq 0 ] && ok "$label" && return
    else [ "$expect" -ne 0 ] && ok "$label" && return
    fi
    fail "$label"
}

if [ "$(id -u)" -ne 0 ]; then
    echo "skipped - apollo-sddm-sync only runs as root, and this shell is not"
    exit 0
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

home="$work/home"
theme="$work/theme"
stage="$home/.cache/apollo/theme"
mkdir -p "$stage" "$theme" "$work/pics"

# getent is how the script finds the invoking user's home. Stub it rather than
# creating a real account.
mkdir -p "$work/bin"
cat > "$work/bin/getent" <<STUB
#!/bin/sh
echo "tester:x:1000:1000::$home:/bin/bash"
STUB
chmod +x "$work/bin/getent"

run() { PATH="$work/bin:$PATH" SUDO_USER=tester APOLLO_SDDM_THEME_DIR="$theme" "$SYNC" 2>&1; }

# ── No staged palette ────────────────────────────────────────────────────
out="$(run)"; rc=$?
if [ $rc -ne 0 ] && echo "$out" | grep -q "no staged palette"; then
    ok "refuses to write a theme with no palette staged"
else
    fail "a missing palette was not refused" "$out"
fi

printf '# a comment\nbase=#1e1e2e\naccent=#cba6f7\ntext=#cdd6f4\n' > "$stage/sddm-colors.conf"

# ── Palette only, no wallpaper ───────────────────────────────────────────
out="$(run)"; rc=$?
if [ $rc -eq 0 ]; then ok "syncs with a palette and no wallpaper"; else fail "palette-only sync failed" "$out"; fi

conf="$theme/theme.conf"
want "writes a [General] header"            0 grep -q '^\[General\]$'  "$conf"
want "carries the staged colours over"      0 grep -q '^accent=#cba6f7$' "$conf"
want "strips the staged file's comments"    1 grep -q '^# a comment$'    "$conf"

# ── With a wallpaper ─────────────────────────────────────────────────────
: > "$work/pics/moon.png"
echo "$work/pics/moon.png" > "$stage/still.txt"
out="$(run)"; rc=$?
if [ $rc -eq 0 ] && [ -f "$theme/backgrounds/current.png" ]; then
    ok "copies the wallpaper into the theme"
else
    fail "the wallpaper was not copied" "$out"
fi
want "points theme.conf at the copy" 0 \
    grep -q '^background=backgrounds/current.png$' "$conf"

perms="$(stat -c '%a' "$theme/backgrounds/current.png")"
if [ "$perms" = "644" ]; then
    ok "the copy is world-readable (the greeter is another user)"
else
    fail "background is mode $perms; the sddm user cannot read it"
fi

# ── Switching format ─────────────────────────────────────────────────────
# The old background has to go. If it survives, the theme directory
# accumulates every wallpaper ever set, and a stale current.png sits beside
# the current.jpg that theme.conf actually names.
: > "$work/pics/dunes.jpg"
echo "$work/pics/dunes.jpg" > "$stage/still.txt"
run >/dev/null
if [ -f "$theme/backgrounds/current.jpg" ] && [ ! -f "$theme/backgrounds/current.png" ]; then
    ok "replaces the previous background instead of piling up"
else
    fail "changing format left the old background behind" "$(ls "$theme/backgrounds")"
fi

# ── A wallpaper that has been deleted since ──────────────────────────────
echo "$work/pics/gone.png" > "$stage/still.txt"
out="$(run)"; rc=$?
if [ $rc -eq 0 ] && echo "$out" | grep -q "is gone"; then
    ok "a deleted wallpaper is a warning, not a broken login screen"
else
    fail "a missing wallpaper was not handled" "$out"
fi

# ── Nothing staged: fall back to the session's recorded wallpaper ────────
# still.txt is only written by a wallpaper *change*. Without this fallback a
# freshly installed login screen has the right colours and no wallpaper until
# you happen to switch one, which is not a connection anyone would guess at.
rm -f "$stage/still.txt"
mkdir -p "$home/.config/hypr"
: > "$work/pics/recorded.jpg"
echo "$work/pics/recorded.jpg" > "$home/.config/hypr/last-wallpaper.txt"
run >/dev/null
if [ -f "$theme/backgrounds/current.jpg" ]; then
    want "falls back to the recorded wallpaper" 0 \
        grep -q '^background=backgrounds/current.jpg$' "$conf"
else
    fail "did not fall back to last-wallpaper.txt" "$(ls "$theme/backgrounds")"
fi

# A video is why still.txt exists at all: the greeter cannot play one, and a
# copied .mp4 renders as nothing. It must be refused, not installed.
: > "$work/pics/clip.mp4"
echo "$work/pics/clip.mp4" > "$home/.config/hypr/last-wallpaper.txt"
out="$(run)"; rc=$?
if [ $rc -eq 0 ] && echo "$out" | grep -q "is a video" && [ ! -f "$theme/backgrounds/current.mp4" ]; then
    ok "refuses to install a video as the login wallpaper"
else
    fail "a video wallpaper was not refused" "$out"
fi
rm -f "$home/.config/hypr/last-wallpaper.txt"

# ── Run as root with no invoking user ────────────────────────────────────
out="$(PATH="$work/bin:$PATH" APOLLO_SDDM_THEME_DIR="$theme" SUDO_USER='' "$SYNC" 2>&1)"; rc=$?
if [ $rc -ne 0 ]; then
    ok "refuses to follow root's own (empty) config"
else
    fail "ran as root with no invoking user" "$out"
fi

# ── Theme not installed ──────────────────────────────────────────────────
out="$(PATH="$work/bin:$PATH" SUDO_USER=tester APOLLO_SDDM_THEME_DIR="$work/nope" "$SYNC" 2>&1)"; rc=$?
if [ $rc -ne 0 ] && echo "$out" | grep -q "does not exist"; then
    ok "says the theme is not installed rather than creating half of one"
else
    fail "a missing theme directory was not reported" "$out"
fi

if [ $fails -gt 0 ]; then
    echo; echo "$fails failure(s)"; exit 1
fi
echo; echo "ok - apollo-sddm-sync"
