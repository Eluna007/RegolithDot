#!/usr/bin/env bash
# wallpaper-switch.sh must start the incoming wallpaper daemon before it stops
# the outgoing one, and must start it detached.
#
# Every flash of the bare Hyprland background came from the other order: kill
# the old daemon, then spend a few hundred milliseconds starting the new one
# with nothing on screen in between. And a daemon left in the script's own
# process group dies when whoever ran the script is reaped — an animated
# wallpaper that played for a second and vanished.
#
# Neither shows up in the script's output, so both are checked by recording the
# order of the calls. Every external tool is stubbed: what matters is the
# sequence, not hyprpaper's rendering.
#
# Run: scripts/test-wallpaper-switch.sh
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/local/bin/wallpaper-switch.sh"
fails=0

ok()   { echo "  ok   $1"; }
fail() { echo "  FAIL $1${2:+: $2}"; fails=$((fails + 1)); }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
export HOME="$work/home"
bin="$work/bin"
mkdir -p "$HOME/.config/hypr" "$HOME/.local/bin" "$bin" "$work/walls"

LOG="$work/calls.log"
export LOG

# Every tool the script reaches for, recording what it was asked to do. PIDs
# are faked through a file so pgrep/pkill can be driven from the test.
export RUNNING="$work/running"
: > "$RUNNING"

for t in mpvpaper hyprpaper ffmpeg matugen apollo-settings hyprlock-wallpaper.sh; do
    cat > "$bin/$t" <<STUB
#!/bin/sh
echo "$t \$*" >> "\$LOG"
exit 0
STUB
    chmod +x "$bin/$t"
done

cat > "$bin/setsid" <<'STUB'
#!/bin/sh
# Record that the daemon was started detached, then "start" it by adding it to
# the fake process table.
shift            # -f
echo "setsid $*" >> "$LOG"
echo "$1" >> "$RUNNING"
exit 0
STUB
chmod +x "$bin/setsid"

cat > "$bin/pgrep" <<'STUB'
#!/bin/sh
# pgrep -x NAME
name="$2"
if grep -qx "$name" "$RUNNING" 2>/dev/null; then echo 4242; exit 0; fi
exit 1
STUB
chmod +x "$bin/pgrep"

cat > "$bin/pkill" <<'STUB'
#!/bin/sh
echo "pkill $*" >> "$LOG"
exit 0
STUB
chmod +x "$bin/pkill"

# `kill` is a bash builtin, so a stub on PATH is never reached — the test
# would see no kills at all and pass whatever the script did. An exported
# function is looked up before the builtin, so this one is.
kill() { echo "kill $*" >> "$LOG"; }
export -f kill

cat > "$bin/hyprctl" <<'STUB'
#!/bin/sh
echo "hyprctl $*" >> "$LOG"
exit 0
STUB
chmod +x "$bin/hyprctl"

cat > "$bin/sudo" <<'STUB'
#!/bin/sh
exit 1
STUB
chmod +x "$bin/sudo"

ln -sf "$bin/hyprlock-wallpaper.sh" "$HOME/.local/bin/hyprlock-wallpaper.sh"

run() { : > "$LOG"; PATH="$bin:$PATH" bash "$SCRIPT" "$1" >/dev/null 2>&1; }

# line_of PATTERN — the 1-based line number of the first matching call.
line_of() { grep -n -- "$1" "$LOG" | head -1 | cut -d: -f1; }

: > "$work/walls/still.png"
: > "$work/walls/clip.mp4"

# ── A video, with a still already up ─────────────────────────────────────
echo hyprpaper > "$RUNNING"
run "$work/walls/clip.mp4"

start="$(line_of 'setsid mpvpaper')"
stop="$(line_of 'kill ')"
if [ -n "$start" ]; then
    ok "starts mpvpaper detached"
else
    fail "mpvpaper was not started through setsid" "$(cat "$LOG")"
fi
if [ -n "$start" ] && [ -n "$stop" ] && [ "$start" -lt "$stop" ]; then
    ok "starts the video before retiring what was on screen"
else
    fail "killed the old wallpaper before the new one was up" "$(cat "$LOG")"
fi

# ── A still, with a video already up ─────────────────────────────────────
echo mpvpaper > "$RUNNING"
run "$work/walls/still.png"

setw="$(line_of 'hyprctl hyprpaper wallpaper')"
stop="$(line_of 'kill ')"
if [ -n "$setw" ] && [ -n "$stop" ] && [ "$setw" -lt "$stop" ]; then
    ok "sets the still before retiring the video under it"
else
    fail "killed the video before the still was up — this is the flash" "$(cat "$LOG")"
fi

# hyprpaper was not running, so it has to be started, and detached like
# everything else.
if grep -q 'setsid hyprpaper' "$LOG"; then
    ok "starts hyprpaper detached when it is not already up"
else
    fail "hyprpaper was not started through setsid" "$(cat "$LOG")"
fi

# ── A still, with hyprpaper already up ───────────────────────────────────
# The whole point of the IPC swap: never restart a daemon that is working.
echo hyprpaper > "$RUNNING"
run "$work/walls/still.png"
if grep -q 'setsid hyprpaper' "$LOG"; then
    fail "restarted hyprpaper when it was already running" "$(cat "$LOG")"
else
    ok "reuses a running hyprpaper over its IPC"
fi

# ── The colour chain still runs ──────────────────────────────────────────
# Applying a wallpaper is also what drives matugen, the lock screen and the
# palette. A reordering that dropped one of those would be invisible here
# otherwise.
for want in matugen hyprlock-wallpaper.sh; do
    if grep -q "^$want" "$LOG"; then
        ok "$want still runs on a wallpaper change"
    else
        fail "$want no longer runs" "$(cat "$LOG")"
    fi
done

if [ "$(cat "$HOME/.config/hypr/last-wallpaper.txt")" = "$work/walls/still.png" ]; then
    ok "records the wallpaper for the boot restore"
else
    fail "last-wallpaper.txt was not written"
fi

if [ $fails -gt 0 ]; then echo; echo "$fails failure(s)"; exit 1; fi
echo; echo "ok - wallpaper-switch.sh"
