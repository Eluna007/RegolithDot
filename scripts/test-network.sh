#!/usr/bin/env bash
# Behavioural test for config/hyprlock/scripts/network.sh, driven by stub
# nmcli/iw/bluetoothctl on PATH.
#
# The bug this exists for: `iw` is not installed on a base Arch system, and
# because the widget redirected stderr and fell back to "Disconnected", a
# connected machine reported itself offline with nothing in the log. A test
# that only ran on a machine with iw would never have caught it.
#
# The stub bodies below are single-quoted on purpose: `$1` inside one is the
# stub's own argument when it runs, not this script's. SC2016 warns about
# exactly the thing that makes them work.
# shellcheck disable=SC2016
set -uo pipefail

NET="${1:-config/hyprlock/scripts/network.sh}"
NET="$(cd "$(dirname "$NET")" && pwd)/$(basename "$NET")"
BIN="$(mktemp -d)"
trap 'rm -rf "$BIN"' EXIT

fails=0

# stub NAME BODY - put a fake tool on PATH; omit to make it "not installed".
stub() { printf '#!/bin/sh\n%s\n' "$2" > "$BIN/$1"; chmod +x "$BIN/$1"; }
clear_stubs() { rm -f "$BIN"/*; }
run() { PATH="$BIN:/usr/bin:/bin" "$NET" "$@"; }

eq() {
  if [ "$2" = "$3" ]; then printf '  ok   %s\n' "$1"
  else printf '  FAIL %s: want %q, got %q\n' "$1" "$2" "$3"; fails=$((fails + 1)); fi
}

echo "wifi:"
# Luna's actual machine: no iw at all, nmcli connected. This reported
# "Disconnected" before the fix.
clear_stubs
stub nmcli 'echo "yes:Sylmar_Guest"; echo "no:SomeNeighbour"'
eq "nmcli connected (no iw installed)" "Sylmar_Guest" "$(run --wifi)"

clear_stubs
stub nmcli 'echo "no:SomeNeighbour"'
eq "nmcli, nothing active"            "Disconnected" "$(run --wifi)"

clear_stubs
stub nmcli 'echo "yes:Cafe\:Wifi"'
eq "SSID containing a colon"          "Cafe:Wifi"    "$(run --wifi)"

clear_stubs
stub iw 'printf "phy#0\n\tInterface wlan0\n\t\tssid Legacy Net\n\t\ttype managed\n"'
eq "no nmcli, iw connected"           "Legacy Net"   "$(run --wifi)"

clear_stubs
stub iw 'printf "phy#0\n\tInterface wlan0\n\t\ttype managed\n"'
eq "no nmcli, iw not associated"      "Disconnected" "$(run --wifi)"

clear_stubs
eq "no tool at all is not a lie"      "Unavailable"  "$(run --wifi)"

clear_stubs
stub nmcli 'echo "yes:AVeryLongNetworkNameIndeed"'
eq "truncation to 14"                 "AVeryLongNetwo" "$(run --wifi 14)"

echo "bluetooth:"
# Luna's bluez: `bluetoothctl info` with no argument errors out. Upstream's
# command form could therefore never report a connected device.
clear_stubs
stub bluetoothctl 'case "$1" in
  devices) [ "$2" = Connected ] && echo "Device AA:BB:CC:DD:EE:FF WH-1000XM4" ;;
  info) echo "Missing device address argument" >&2; exit 1 ;;
esac'
eq "connected, modern bluez"          "WH-1000XM4"   "$(run --bluetooth)"

clear_stubs
stub bluetoothctl 'case "$1" in
  devices) ;;
  info) echo "Missing device address argument" >&2; exit 1 ;;
esac'
eq "nothing connected (Luna today)"   "Disconnected" "$(run --bluetooth)"

clear_stubs
stub bluetoothctl 'case "$1" in
  devices) echo "Invalid argument" >&2; exit 1 ;;
  info) printf "Device AA:BB:CC:DD:EE:FF\n\tName: Old Headset\n\tConnected: yes\n" ;;
esac'
eq "older bluez, info fallback"       "Old Headset"  "$(run --bluetooth)"

clear_stubs
eq "bluetoothctl missing"             "Unavailable"  "$(run --bluetooth)"

clear_stubs
stub bluetoothctl 'case "$1" in devices) echo "Device AA:BB:CC:DD:EE:FF A Very Long Device Name" ;; esac'
eq "truncation to 14"                 "A Very Long De" "$(run --bluetooth 14)"

echo "misc:"
clear_stubs
eq "no mode is an error" "1" "$(run --nonsense >/dev/null 2>&1; echo $?)"
eq "usage goes to stderr, not the widget" "" "$(run --nonsense 2>/dev/null)"

if [ "$fails" -gt 0 ]; then printf '\n%d failure(s)\n' "$fails"; exit 1; fi
printf '\nok - network.sh distinguishes connected, disconnected and tool-missing\n'
