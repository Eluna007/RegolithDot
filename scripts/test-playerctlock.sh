#!/usr/bin/env bash
# Behavioural test for config/hyprlock/scripts/playerctlock.sh, driven by a
# stub playerctl on PATH.
#
# Upstream gated everything behind an is_spotify() check, so on a machine
# without Spotify every music widget in every layout printed "Not playing on
# Spotify" instead of the track. That is the class of bug here: the widget
# looks populated, it is just populated with the wrong thing.
#
# The stub bodies are single-quoted on purpose - "$1" inside one is the stub's
# own argument at run time, not this script's.
# shellcheck disable=SC2016
set -uo pipefail

PC="${1:-config/hyprlock/scripts/playerctlock.sh}"
PC="$(cd "$(dirname "$PC")" && pwd)/$(basename "$PC")"
BIN="$(mktemp -d)"
trap 'rm -rf "$BIN"' EXIT

fails=0
clear_stubs() { rm -f "${BIN:?}"/*; }
run() { PATH="$BIN:/usr/bin:/bin" "$PC" "$@"; }

eq() {
  if [ "$2" = "$3" ]; then printf '  ok   %s\n' "$1"
  else printf '  FAIL %s: want %q, got %q\n' "$1" "$2" "$3"; fails=$((fails + 1)); fi
}

# player NAME STATUS TITLE ARTIST
player() {
  cat > "$BIN/playerctl" <<STUB
#!/bin/sh
if [ "\$1" = "-l" ]; then echo "$1"; exit 0; fi
if [ "\$1" = "-p" ]; then
  case "\$3" in
    status)   echo "$2" ;;
    metadata)
      case "\$5" in
        *title*)  echo "$3" ;;
        *artist*) echo "$4" ;;
        *)        echo "" ;;
      esac ;;
  esac
fi
STUB
  chmod +x "$BIN/playerctl"
}

echo "the bug this file exists for:"
clear_stubs
player firefox Playing "A YouTube Video" "Some Channel"
eq "a non-Spotify player reports its title" "A YouTube Video" "$(run --title 24)"
eq "...and its artist"                      "Some Channel"    "$(run --artist 30)"
case "$(run --title 24)" in
  *Spotify*) printf '  FAIL title mentions Spotify\n'; fails=$((fails + 1)) ;;
  *) printf '  ok   nothing mentions Spotify\n' ;;
esac

echo "player selection:"
clear_stubs
# Browsers register one MPRIS client per tab; status picks the real one.
cat > "$BIN/playerctl" <<'STUB'
#!/bin/sh
if [ "$1" = "-l" ]; then printf 'firefox.instance1\nfirefox.instance2\n'; exit 0; fi
if [ "$1" = "-p" ]; then
  case "$2" in
    firefox.instance1) [ "$3" = status ] && echo "Stopped" ;;
    firefox.instance2)
      case "$3" in
        status) echo "Playing" ;;
        metadata) case "$5" in *title*) echo "Right Tab" ;; *) echo "" ;; esac ;;
      esac ;;
  esac
fi
STUB
chmod +x "$BIN/playerctl"
eq "skips a stopped client for a playing one" "Right Tab" "$(run --title 24)"

echo "widths:"
clear_stubs
player spotify Playing "An Extremely Long Track Title Indeed" "An Extremely Long Artist Name Here"
eq "default title width is unchanged" "An Extremely Lo..." "$(run --title)"
eq "explicit title width"             "An Extremely Long Track ..." "$(run --title 24)"
eq "default artist width"             "An Extremely Long Ar" "$(run --artist)"
eq "explicit artist width"            "An Extremely Long Artist Name " "$(run --artist 30)"

clear_stubs
player spotify Playing "Short" "Also Short"
eq "a title under the width is untouched" "Short" "$(run --title 24)"

echo "icons:"
clear_stubs; player spotify Playing "x" "y"
eq "spotify"        "$(printf '')"     "$(run --icon)"
clear_stubs; player mpv Playing "x" "y"
eq "anything else"  "$(printf '')"     "$(run --icon)"
clear_stubs
eq "no playerctl installed still draws a glyph" "󰎆" "$(run --icon)"
cat > "$BIN/playerctl" <<'STUB'
#!/bin/sh
[ "$1" = "-l" ] && exit 0
STUB
chmod +x "$BIN/playerctl"
eq "nothing playing still draws a glyph" "󰎆" "$(run --icon)"
eq "...but the title is blank, not an error" "" "$(run --title 24)"

echo "source labels all carry a glyph:"
for p in spotify firefox chromium mpv vlc someplayer; do
  clear_stubs; player "$p" Playing "x" "y"
  out="$(run --source)"
  # The glyphs went missing from three of these once; a trailing space is
  # exactly what that looked like.
  if printf '%s' "$out" | LC_ALL=C grep -q '[^ -~]'; then
    printf '  ok   %s -> %s\n' "$p" "$out"
  else
    printf '  FAIL %s has no glyph: %q\n' "$p" "$out"; fails=$((fails + 1))
  fi
done

echo "misc:"
clear_stubs; player spotify Playing "x" "y"
eq "an unknown mode fails loudly" "1" "$(run --nonsense >/dev/null 2>&1; echo $?)"
eq "no arguments prints usage"    "1" "$(run >/dev/null 2>&1; echo $?)"

if [ "$fails" -gt 0 ]; then printf '\n%d failure(s)\n' "$fails"; exit 1; fi
printf '\nok - playerctlock.sh works for any MPRIS player, at any width\n'
