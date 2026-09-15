#!/usr/bin/env bash
# Battery readout for the lock screen.
#
# Upstream hardcoded /sys/class/power_supply/BAT0. That name is not universal -
# plenty of laptops expose BAT1, and on a machine where it is wrong every
# update tick printed a `cat: No such file` pair into hyprlock's log while the
# widget rendered blank. So find the battery rather than assume it.
#
# Two other upstream bugs fixed here:
#   - at 100% the icon index was 10, one past the end of a ten-element array,
#     so the icon disappeared exactly when the battery was full
#   - with no battery at all (a desktop) it printed errors instead of nothing
#
# Modes, so the layouts do not have to reach into sysfs themselves:
#   (none)      "85% 󰁾"        - what layout15 shows
#   --percent   "85"        (empty when there is no battery)
#   --status    "Discharging"
#   --charging  "yes" | "no" | "unknown"
set -uo pipefail

# Overridable so the test harness can point at a fake sysfs tree.
PSDIR="${APOLLO_POWER_SUPPLY_DIR:-/sys/class/power_supply}"

# First readable battery. `type` is the reliable discriminator (it rules out
# the AC adapter and any USB-PD device), but a few drivers omit it, so a
# readable `capacity` is what actually qualifies.
bat_dir() {
  local d
  for d in "$PSDIR"/*; do
    [ -r "$d/capacity" ] || continue
    if [ -r "$d/type" ] && [ "$(cat "$d/type" 2>/dev/null)" != "Battery" ]; then
      continue
    fi
    printf '%s\n' "$d"
    return 0
  done
  return 1
}

bat="$(bat_dir)" || bat=""

percentage=""
status=""
if [ -n "$bat" ]; then
  percentage="$(cat "$bat/capacity" 2>/dev/null)"
  status="$(cat "$bat/status" 2>/dev/null)"
fi

case "${1-}" in
  --percent)
    printf '%s\n' "$percentage"
    exit 0
    ;;
  --status)
    printf '%s\n' "$status"
    exit 0
    ;;
  --charging)
    # "Discharging" is the only state that means running off the battery;
    # Charging, Full and "Not charging" all mean the adapter is in. With no
    # battery at all the answer is genuinely unknown, and the layouts treat
    # anything that is not "no" as plugged in - correct for a desktop.
    if [ -z "$bat" ]; then printf 'unknown\n'
    elif [ "$status" = "Discharging" ]; then printf 'no\n'
    else printf 'yes\n'
    fi
    exit 0
    ;;
esac

# Default: percentage plus an icon. Nothing at all if there is no battery,
# which renders as an empty label rather than a broken one.
[ -n "$percentage" ] || exit 0

# Literal glyphs rather than \U escapes: bash expands those only under a
# UTF-8 locale, and hyprlock runs this from an environment where that is not
# guaranteed - the failure shows up as the escape printed verbatim on the lock
# screen. Bytes in the file cannot fail that way.
icons=("󰂃" "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰁹")
charging_icon="󰂄"

idx=$((percentage / 10))
(( idx > 9 )) && idx=9      # 100% would otherwise index past the end
(( idx < 0 )) && idx=0

icon="${icons[idx]}"
[ "$status" = "Charging" ] && icon="$charging_icon"

printf '%s%% %s\n' "$percentage" "$icon"
