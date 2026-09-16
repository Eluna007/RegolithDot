#!/usr/bin/env bash
# Behavioural test for config/quickshell/apollo/scripts/apps.sh against a
# fixture tree of .desktop files.
#
# Every case here is something that really appears in /usr/share/applications
# and would show up in the launcher as a broken row: NoDisplay entries that are
# meant to be hidden, %U field codes that would land on the command line
# literally, TryExec pointing at an uninstalled binary, and [Desktop Action]
# groups whose Name would otherwise overwrite the application's own.
set -uo pipefail

APPS="${1:-config/quickshell/apollo/scripts/apps.sh}"
APPS="$(cd "$(dirname "$APPS")" && pwd)/$(basename "$APPS")"
ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT

fails=0
ok()   { printf '  ok   %s \n' "$1"; }
bad()  { printf '  FAIL %s \n' "$1"; fails=$((fails + 1)); }
eq()   { if [ "$2" = "$3" ]; then ok "$1"; else printf '  FAIL %s: want %q, got %q \n' "$1" "$2" "$3"; fails=$((fails + 1)); fi; }

mkdir -p "$ROOT/apps" "$ROOT/other" "$ROOT/icons/hicolor/128x128/apps" "$ROOT/icons/hicolor/32x32/apps"
: > "$ROOT/icons/hicolor/128x128/apps/firefox.png"
: > "$ROOT/icons/hicolor/32x32/apps/firefox.png"
: > "$ROOT/icons/hicolor/32x32/apps/small-only.png"

desktop() { printf '%s\n' "$2" > "$ROOT/apps/$1.desktop"; }

desktop firefox '[Desktop Entry]
Type=Application
Name=Firefox
Exec=firefox %u
Icon=firefox
Comment=Browse the web'

desktop hidden '[Desktop Entry]
Type=Application
Name=Hidden Thing
Exec=hidden
NoDisplay=true'

desktop reallyhidden '[Desktop Entry]
Type=Application
Name=Really Hidden
Exec=nope
Hidden=true'

desktop notanapp '[Desktop Entry]
Type=Link
Name=A Link
URL=https://example.com'

desktop missingbin '[Desktop Entry]
Type=Application
Name=Uninstalled
Exec=definitely-not-installed
TryExec=definitely-not-installed-either'

desktop presentbin '[Desktop Entry]
Type=Application
Name=Installed
Exec=sh
TryExec=sh'

desktop withactions '[Desktop Entry]
Type=Application
Name=Real Name
Exec=realbin %F
Icon=small-only

[Desktop Action NewWindow]
Name=Action Name
Exec=realbin --new-window'

desktop noexec '[Desktop Entry]
Type=Application
Name=No Exec'

desktop onlycodes '[Desktop Entry]
Type=Application
Name=Only Codes
Exec=%U'

desktop tabby "$(printf '[Desktop Entry]\nType=Application\nName=Tab\tName\nExec=tabbin')"

# same basename in a lower-priority dir: the first one must win
printf '[Desktop Entry]\nType=Application\nName=Firefox Overridden\nExec=wrong\n' > "$ROOT/other/firefox.desktop"

run() {
  APPLICATION_DIRS="$ROOT/apps:$ROOT/other" APOLLO_ICON_DIRS="$ROOT/icons" "$APPS"
}
out="$(run)"
field() { printf '%s\n' "$out" | awk -F'\t' -v n="$1" '$1 == n { print $'"$2"'; exit }'; }
names="$(printf '%s\n' "$out" | cut -f1)"
has() { printf '%s\n' "$names" | grep -qxF "$1"; }
# if/else rather than `A && ok || bad`: in that form `bad` also runs when `ok`
# itself fails, which makes a passing test able to report a failure.
present() { if has "$1"; then ok "$2"; else bad "$2"; fi; }
absent()  { if has "$1"; then bad "$2"; else ok "$2"; fi; }

echo "what is listed:"
present "Firefox" "a normal entry appears"
present "Installed" "TryExec that exists is kept"
present "Real Name" "the entry Name wins over an action Name"

echo "what is not:"
absent "Hidden Thing" "NoDisplay is skipped"
absent "Really Hidden" "Hidden is skipped"
absent "A Link" "non-Application types are skipped"
absent "Uninstalled" "missing TryExec binary is skipped"
absent "No Exec" "an entry with no Exec is skipped"
absent "Only Codes" "an Exec of only field codes is skipped"
absent "Action Name" "an action Name is not listed as an app"
absent "Firefox Overridden" "a later duplicate does not override"

echo "fields:"
eq "field codes are stripped from Exec" "firefox" "$(field Firefox 2)"
eq "%F is stripped too" "realbin" "$(field 'Real Name' 2)"
eq "comment is carried" "Browse the web" "$(field Firefox 4)"
eq "largest icon wins" "$ROOT/icons/hicolor/128x128/apps/firefox.png" "$(field Firefox 3)"
eq "a smaller-only icon still resolves" "$ROOT/icons/hicolor/32x32/apps/small-only.png" "$(field 'Real Name' 3)"
eq "an unresolvable icon is empty, not broken" "" "$(field Installed 3)"

echo "shape:"
cols="$(printf '%s\n' "$out" | awk -F'\t' 'NF != 4 { print NF; exit }')"
eq "every row has four fields" "" "$cols"
if printf '%s\n' "$names" | grep -q 'Tab\tName'; then bad "tabs inside a name are neutralised"; else ok "tabs inside a name are neutralised"; fi
sorted="$(printf '%s\n' "$names" | sort -f)"
eq "output is sorted" "$sorted" "$names"

echo "empty world:"
eq "no application dirs is silent" "" "$(APPLICATION_DIRS="$ROOT/nothing-here" "$APPS")"
eq "and exits cleanly" "0" "$(APPLICATION_DIRS="$ROOT/nothing-here" "$APPS" >/dev/null 2>&1; echo $?)"

if [ "$fails" -gt 0 ]; then printf '\n%d failure(s)\n' "$fails"; exit 1; fi
printf '\nok - apps.sh lists what should be listed, and nothing else\n'
