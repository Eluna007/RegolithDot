#!/usr/bin/env bash
# Wifi SSID and connected-bluetooth-device readouts for layout20.
#
# Upstream used `iw dev` for wifi and `bluetoothctl info` for bluetooth, both
# with stderr redirected and a "Disconnected" fallback. That combination turns
# every failure into a plausible-looking lie: `iw` is not installed on a base
# Arch system at all, so the widget read "Disconnected" while the machine was
# online, and there was nothing in the log to say otherwise.
#
# So: prefer the tool this rice already requires (NetworkManager), fall back to
# the one upstream used, and say "Unavailable" rather than "Disconnected" when
# no tool is present - a wrong answer is worse than an honest blank.
#
#   network.sh --wifi [WIDTH]        SSID, "Disconnected", or "Unavailable"
#   network.sh --bluetooth [WIDTH]   device name, "Disconnected", or "Unavailable"
#
# WIDTH truncates the result, since these render into fixed-size pills.
set -uo pipefail

have() { command -v "$1" >/dev/null 2>&1; }

# nmcli -t escapes a literal colon inside a field as '\:'; unescape it so an
# SSID containing one survives.
unescape() { sed 's/\\:/:/g'; }

wifi() {
  local ssid=""

  # NetworkManager is a hard dependency of Apollo, so this is the common path.
  if have nmcli; then
    ssid="$(nmcli -t -f active,ssid dev wifi 2>/dev/null \
            | sed -n 's/^yes://p' | head -n1 | unescape)"
    [ -n "$ssid" ] && { printf '%s\n' "$ssid"; return; }
    printf 'Disconnected\n'
    return
  fi

  # Upstream's path, kept for a machine running something other than NM.
  if have iw; then
    ssid="$(iw dev 2>/dev/null | awk '$1=="ssid"{ $1=""; sub(/^ /,""); print; exit }')"
    [ -n "$ssid" ] && { printf '%s\n' "$ssid"; return; }
    printf 'Disconnected\n'
    return
  fi

  printf 'Unavailable\n'
}

bluetooth() {
  have bluetoothctl || { printf 'Unavailable\n'; return; }

  # `devices Connected` is the direct question and needs no default device
  # selected. `bluetoothctl info` with no argument only works when one is, and
  # otherwise exits with "Missing device address argument" - which is why the
  # original always fell through to "Disconnected".
  local name
  name="$(bluetoothctl devices Connected 2>/dev/null \
          | head -n1 | cut -d' ' -f3-)"
  [ -n "$name" ] && { printf '%s\n' "$name"; return; }

  # Older bluez without the Connected filter.
  name="$(bluetoothctl info 2>/dev/null | sed -n 's/^[[:space:]]*Name:[[:space:]]*//p' | head -n1)"
  [ -n "$name" ] && { printf '%s\n' "$name"; return; }

  printf 'Disconnected\n'
}

case "${1-}" in
  --wifi)      out="$(wifi)" ;;
  --bluetooth) out="$(bluetooth)" ;;
  *)
    echo "usage: network.sh --wifi|--bluetooth [WIDTH]" >&2
    exit 1
    ;;
esac

width="${2-}"
if [ -n "$width" ]; then
  printf '%s\n' "$out" | cut -c "1-$width"
else
  printf '%s\n' "$out"
fi
