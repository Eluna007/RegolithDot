#!/usr/bin/env bash
# One line of battery state for the shell, tab separated:
#
#   percent <TAB> status <TAB> seconds-remaining <TAB> health-percent
#
# Any field may be empty, which means "not known" and is never the same as
# zero. The bar hides itself on an empty percent rather than inventing one:
# a plausible number nobody measured is worse than a blank, and a hardcoded
# 100 is exactly how a stale shell instance drawing a dead battery poller
# went unnoticed for a day.
#
# Called by both shell.qml (the bar pill) and SysMonPanel (the detail card) by
# absolute path under the shell's own config directory, so the two can never
# drift and nothing depends on PATH or an install step.
#
# Upstream read /sys/class/power_supply/BAT0 directly. That name is not
# universal - this machine has BAT1 - so the battery is discovered, never named.
set -uo pipefail

PSDIR="${APOLLO_POWER_SUPPLY_DIR:-/sys/class/power_supply}"

# Print a sysfs file's contents, or nothing if it is absent or unreadable.
# Never fails, so a missing optional field does not abort the script.
read_first() {
  if [ -r "$1" ]; then
    cat "$1" 2>/dev/null
  fi
}

bat=""
for d in "$PSDIR"/*; do
  [ -r "$d/capacity" ] || continue
  t="$(read_first "$d/type")"
  [ -z "$t" ] || [ "$t" = "Battery" ] || continue
  bat="$d"
  break
done

if [ -z "$bat" ]; then
  printf '\t\t\t\n'
  exit 0
fi

pct="$(read_first "$bat/capacity")"
status="$(read_first "$bat/status")"
[ -n "$status" ] || status="Unknown"

# Time remaining. Drivers expose either energy (µWh / µW) or charge
# (µAh / µA); both give hours as now/rate. A rate of 0 means idle or full,
# where there is no meaningful estimate rather than an infinite one.
secs=""
now="$(read_first "$bat/energy_now")"
rate="$(read_first "$bat/power_now")"
if [ -z "$now" ] || [ -z "$rate" ]; then
  now="$(read_first "$bat/charge_now")"
  rate="$(read_first "$bat/current_now")"
fi
full="$(read_first "$bat/energy_full")"
[ -n "$full" ] || full="$(read_first "$bat/charge_full")"

if [ -n "$now" ] && [ -n "$rate" ] && [ "$rate" -gt 0 ] 2>/dev/null; then
  case "$status" in
    Discharging)
      secs=$(( now * 3600 / rate ))
      ;;
    Charging)
      if [ -n "$full" ] && [ "$full" -gt "$now" ] 2>/dev/null; then
        secs=$(( (full - now) * 3600 / rate ))
      fi
      ;;
  esac
fi

# Health: how much of the design capacity the pack still holds.
health=""
design="$(read_first "$bat/energy_full_design")"
[ -n "$design" ] || design="$(read_first "$bat/charge_full_design")"
if [ -n "$full" ] && [ -n "$design" ] && [ "$design" -gt 0 ] 2>/dev/null; then
  health=$(( full * 100 / design ))
fi

printf '%s\t%s\t%s\t%s\n' "$pct" "$status" "$secs" "$health"
