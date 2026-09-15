#!/usr/bin/env bash
# Behavioural test for config/hyprlock/scripts/battery.sh.
#
# Every bug this covers was live at some point: BAT0 assumed to exist, the
# icon vanishing at exactly 100% (index 10 of a ten-element array), errors
# printed on a machine with no battery, and glyphs rendered as \U escapes
# under a non-UTF-8 locale. None of it is visible until the screen is locked,
# which is the worst place to debug.
set -uo pipefail

BAT="${1:-config/hyprlock/scripts/battery.sh}"
TREE="$(mktemp -d)"
trap 'rm -rf "$TREE"' EXIT

fails=0
mk()  { rm -rf "${TREE:?}"/*; }
bat() { mkdir -p "$TREE/$1"; printf 'Battery\n' > "$TREE/$1/type"
        printf '%s\n' "$2" > "$TREE/$1/capacity"; printf '%s\n' "$3" > "$TREE/$1/status"; }
ac()  { mkdir -p "$TREE/AC"; printf 'Mains\n' > "$TREE/AC/type"; printf '1\n' > "$TREE/AC/online"; }
run() { APOLLO_POWER_SUPPLY_DIR="$TREE" "$BAT" "$@"; }

eq() { # label, expected, actual
  if [ "$2" = "$3" ]; then
    printf '  ok   %s\n' "$1"
  else
    printf '  FAIL %s: want %q, got %q\n' "$1" "$2" "$3"
    fails=$((fails + 1))
  fi
}

# Discovery: the battery is found whatever it is called, and the AC adapter
# is never mistaken for one even though it sorts first in the glob.
mk; bat BAT0 85 Discharging;      eq "BAT0 found"            "85" "$(run --percent)"
mk; bat BAT1 85 Discharging;      eq "BAT1 found"            "85" "$(run --percent)"
mk; bat macsmc-battery 42 Full;   eq "odd driver name found" "42" "$(run --percent)"
mk; ac; bat BAT1 55 Full;         eq "AC not mistaken"       "55" "$(run --percent)"

# The icon must be non-empty at every decile, 100 included.
for p in 0 5 10 25 50 75 99 100; do
  mk; bat BAT1 "$p" Discharging
  out="$(run)"
  icon="${out#* }"
  if [ -n "$icon" ] && [ "$icon" != "$out" ]; then
    printf '  ok   %s%% renders an icon (%s)\n' "$p" "$out"
  else
    printf '  FAIL %s%%: no icon in %q\n' "$p" "$out"
    fails=$((fails + 1))
  fi
done

# Charging state drives which glyph layout20 shows.
mk; bat BAT1 50 Discharging;  eq "discharging"    "no"      "$(run --charging)"
mk; bat BAT1 50 Charging;     eq "charging"       "yes"     "$(run --charging)"
mk; bat BAT1 100 Full;        eq "full is not discharging" "yes" "$(run --charging)"
mk; bat BAT1 90 "Not charging"; eq "not charging" "yes"     "$(run --charging)"

# No battery: empty output, no errors, and "unknown" rather than a wrong guess.
mk;                eq "no battery: silent"  ""        "$(run 2>/dev/null)"
mk;                eq "no battery: stderr"  ""        "$(run 2>&1 1>/dev/null)"
mk;                eq "no battery: percent" ""        "$(run --percent)"
mk;                eq "no battery: charging" "unknown" "$(run --charging)"
mk; ac;            eq "AC only: silent"     ""        "$(run 2>&1)"

# Glyphs must be bytes in the file, not \U escapes that need a UTF-8 locale.
mk; bat BAT1 55 Charging
for loc in C C.UTF-8; do
  out="$(LC_ALL=$loc run 2>/dev/null)"
  case "$out" in
    *'\U'*|*'\u'*) printf '  FAIL locale %s: unexpanded escape in %q\n' "$loc" "$out"; fails=$((fails + 1)) ;;
    *) printf '  ok   locale %s renders glyphs (%s)\n' "$loc" "$out" ;;
  esac
done

if [ "$fails" -gt 0 ]; then
  printf '\n%d failure(s)\n' "$fails"
  exit 1
fi
printf '\nok - battery.sh handles any battery name, 0-100%%, and no battery at all\n'
