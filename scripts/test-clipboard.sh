#!/usr/bin/env bash
# Behavioural test for config/quickshell/apollo/scripts/clipboard.sh, driven by
# a stub copyq on PATH.
#
# The bug this replaces: the panel ran `cliphist list` while autostart ran
# copyq, so it showed an empty history next to a working clipboard manager.
# An empty list is indistinguishable from "you have not copied anything", which
# is why it went unnoticed.
#
# The stub bodies are single-quoted on purpose - $1 inside one is the stub's
# own argument at run time.
# shellcheck disable=SC2016
set -uo pipefail

CB="${1:-config/quickshell/apollo/scripts/clipboard.sh}"
CB="$(cd "$(dirname "$CB")" && pwd)/$(basename "$CB")"
BIN="$(mktemp -d)"
OUT="$(mktemp -d)"
trap 'rm -rf "$BIN" "$OUT"' EXIT

fails=0
eq() {
  if [ "$2" = "$3" ]; then printf '  ok   %s \n' "$1"
  else printf '  FAIL %s: want %q, got %q \n' "$1" "$2" "$3"; fails=$((fails + 1)); fi
}
run() { PATH="$BIN:/usr/bin:/bin" APOLLO_COPYQ=copyq "$CB" "$@"; }

# A copyq stub that records what it was asked and answers plausibly.
cat > "$BIN/copyq" <<STUB
#!/bin/sh
printf '%s\n' "\$*" >> "$OUT/calls"
case "\$1" in
  eval) echo "EVAL_OUTPUT" ;;
  read) echo "row-\$2-contents" ;;
esac
STUB
chmod +x "$BIN/copyq"
cat > "$BIN/wl-copy" <<STUB
#!/bin/sh
cat > "$OUT/clipboard"
STUB
chmod +x "$BIN/wl-copy"

echo "listing:"
eq "--list asks copyq, not cliphist" "EVAL_OUTPUT" "$(run --list)"
if grep -q "^eval" "$OUT/calls"; then printf '  ok   uses copyq eval \n'
else printf '  FAIL never called copyq eval \n'; fails=$((fails + 1)); fi

echo "selecting:"
: > "$OUT/calls"
run --use 3
eq "--use reads that row" "row-3-contents" "$(cat "$OUT/clipboard")"
if grep -q "^read 3" "$OUT/calls"; then printf '  ok   passes the row through \n'
else printf '  FAIL wrong copyq call: %s \n' "$(cat "$OUT/calls")"; fails=$((fails + 1)); fi

echo "a row number is the only thing that reaches copyq:"
for bad in "0; rm -rf /" "size()" "../x" "" "-1" "1 2"; do
  : > "$OUT/calls"
  if run --use "$bad" >/dev/null 2>&1; then
    printf '  FAIL accepted %q \n' "$bad"; fails=$((fails + 1))
  else
    printf '  ok   rejected %q \n' "$bad"
  fi
done

echo "clearing:"
: > "$OUT/calls"
run --clear
if grep -q "^eval" "$OUT/calls"; then printf '  ok   --clear goes through eval \n'
else printf '  FAIL --clear did nothing \n'; fails=$((fails + 1)); fi

echo "no copyq installed:"
rm -f "$BIN/copyq"
eq "--list is silent, not an error" "" "$(run --list 2>&1)"
eq "and exits cleanly" "0" "$(run --list >/dev/null 2>&1; echo $?)"

echo "misc:"
eq "an unknown mode fails" "1" "$(run --nonsense >/dev/null 2>&1; echo $?)"
eq "no arguments fails"    "1" "$(run >/dev/null 2>&1; echo $?)"

if [ "$fails" -gt 0 ]; then printf '\n%d failure(s)\n' "$fails"; exit 1; fi
printf '\nok - clipboard.sh talks to copyq, and only ever passes it a row number\n'
