#!/usr/bin/env bash
# Behavioural test for config/quickshell/apollo/scripts/battery.sh.
#
# The bar and the system-monitor panel both parse this one line, so its shape
# matters: four tab-separated fields, always, with empty meaning "not known".
# Empty is not zero - a battery at 0% and a machine with no battery must not
# look the same to the parser.
set -uo pipefail

BAT="${1:-config/quickshell/apollo/scripts/battery.sh}"
BAT="$(cd "$(dirname "$BAT")" && pwd)/$(basename "$BAT")"
TREE="$(mktemp -d)"
trap 'rm -rf "$TREE"' EXIT

fails=0
mk() { rm -rf "${TREE:?}"/*; }
run() { APOLLO_POWER_SUPPLY_DIR="$TREE" "$BAT"; }
field() { run | cut -f"$1"; }

# bat DIR PCT STATUS  - the minimum a driver must expose
bat() {
  mkdir -p "$TREE/$1"
  printf 'Battery\n' > "$TREE/$1/type"
  printf '%s\n' "$2" > "$TREE/$1/capacity"
  printf '%s\n' "$3" > "$TREE/$1/status"
}
ac() { mkdir -p "$TREE/AC"; printf 'Mains\n' > "$TREE/AC/type"; printf '1\n' > "$TREE/AC/online"; }

eq() {
  if [ "$2" = "$3" ]; then printf '  ok   %s\n' "$1"
  else printf '  FAIL %s: want %q, got %q\n' "$1" "$2" "$3"; fails=$((fails + 1)); fi
}

echo "shape:"
mk; bat BAT1 55 Discharging
eq "always 4 fields" "4" "$(run | awk -F'\t' '{print NF}')"
mk
eq "4 fields with no battery too" "4" "$(run | awk -F'\t' '{print NF}')"
eq "no battery -> empty percent"  ""  "$(field 1)"

echo "discovery:"
mk; bat BAT0 55 Discharging;    eq "BAT0"          "55" "$(field 1)"
mk; bat BAT1 55 Discharging;    eq "BAT1"          "55" "$(field 1)"
mk; bat macsmc-battery 7 Full;  eq "odd name"      "7"  "$(field 1)"
mk; ac; bat BAT1 55 Full;       eq "AC not a battery" "55" "$(field 1)"
mk; bat BAT1 0 Discharging;     eq "0% is a reading, not absence" "0" "$(field 1)"

echo "status:"
mk; bat BAT1 55 Charging;       eq "charging" "Charging" "$(field 2)"
mk; bat BAT1 55 Discharging;    eq "discharging" "Discharging" "$(field 2)"
mk; mkdir -p "$TREE/BAT1"; printf 'Battery\n' > "$TREE/BAT1/type"; printf '55\n' > "$TREE/BAT1/capacity"
eq "missing status file -> Unknown" "Unknown" "$(field 2)"

echo "time remaining:"
# energy driver: 30 Wh left, drawing 10 W -> 3 hours
mk; bat BAT1 55 Discharging
printf '30000000\n' > "$TREE/BAT1/energy_now"; printf '10000000\n' > "$TREE/BAT1/power_now"
eq "energy: 3h to empty" "10800" "$(field 3)"

# charge driver (no energy_* at all): same arithmetic via charge/current
mk; bat BAT1 55 Discharging
printf '30000000\n' > "$TREE/BAT1/charge_now"; printf '10000000\n' > "$TREE/BAT1/current_now"
eq "charge: 3h to empty" "10800" "$(field 3)"

# charging counts up to full, not down from now
mk; bat BAT1 50 Charging
printf '20000000\n' > "$TREE/BAT1/energy_now"; printf '10000000\n' > "$TREE/BAT1/power_now"
printf '50000000\n' > "$TREE/BAT1/energy_full"
eq "charging: 3h to full" "10800" "$(field 3)"

mk; bat BAT1 55 Discharging
printf '30000000\n' > "$TREE/BAT1/energy_now"; printf '0\n' > "$TREE/BAT1/power_now"
eq "zero draw -> no estimate, not infinity" "" "$(field 3)"

mk; bat BAT1 100 Full
printf '50000000\n' > "$TREE/BAT1/energy_now"; printf '0\n' > "$TREE/BAT1/power_now"
eq "full -> no estimate" "" "$(field 3)"

mk; bat BAT1 55 Discharging
eq "no energy files -> no estimate" "" "$(field 3)"

echo "health:"
mk; bat BAT1 55 Discharging
printf '45000000\n' > "$TREE/BAT1/energy_full"; printf '50000000\n' > "$TREE/BAT1/energy_full_design"
eq "90% health" "90" "$(field 4)"
mk; bat BAT1 55 Discharging
printf '45000000\n' > "$TREE/BAT1/charge_full"; printf '50000000\n' > "$TREE/BAT1/charge_full_design"
eq "90% health via charge_*" "90" "$(field 4)"
mk; bat BAT1 55 Discharging
eq "no design capacity -> unknown" "" "$(field 4)"
mk; bat BAT1 55 Discharging
printf '45000000\n' > "$TREE/BAT1/energy_full"; printf '0\n' > "$TREE/BAT1/energy_full_design"
eq "zero design capacity is not a divide" "" "$(field 4)"

echo "robustness:"
mk; bat BAT1 55 Discharging
eq "no stderr on a plain battery" "" "$(run 2>&1 1>/dev/null)"
mk
eq "no stderr with no battery"    "" "$(run 2>&1 1>/dev/null)"
mk; bat BAT1 55 Discharging; printf 'garbage\n' > "$TREE/BAT1/power_now"; printf '30000000\n' > "$TREE/BAT1/energy_now"
eq "non-numeric rate -> no estimate" "" "$(field 3)"
eq "non-numeric rate -> no stderr"   "" "$(run 2>&1 1>/dev/null)"

if [ "$fails" -gt 0 ]; then printf '\n%d failure(s)\n' "$fails"; exit 1; fi
printf '\nok - battery.sh emits 4 fields for every battery shape, empty where unknown\n'
