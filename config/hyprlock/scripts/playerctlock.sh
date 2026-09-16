#!/usr/bin/env bash
# Track metadata for the hyprlock layouts: $music --title, --artist, etc.
#
# Rewritten from upstream, which called an is_spotify() gate on every
# invocation and exited 1 with "Not playing on Spotify" when Spotify was not
# running - so on a machine without Spotify every music widget in every layout
# printed that string instead of the track. It now uses whichever MPRIS player
# is actually playing.
#
# Album art is NOT fetched here. Upstream re-ran a download and an ImageMagick
# pass in the background on every call, and the layouts call this several times
# a second. Art is hlock_mpris.sh's job, driven by hyprlock's reload_cmd.
set -uo pipefail

if [ $# -eq 0 ]; then
    echo "Usage: $0 --title [W] | --artist [W] | --icon | --album | --position | --length | --status | --source"
    exit 1
fi

# Nothing to report. --icon still answers, because layout20 draws a pill that
# needs a glyph whether or not anything is playing; every other mode renders as
# an empty label, which is what the layouts want.
idle() {
    case "${1-}" in
        --icon) echo "󰎆" ;;
        *)      echo "" ;;
    esac
    exit 0
}

command -v playerctl >/dev/null 2>&1 || idle "$1"

# First player that is playing or paused. `playerctl -l` lists every MPRIS
# client - browsers register one per tab - so status is what picks the real one.
player=""
while read -r p; do
    [ -n "$p" ] || continue
    case "$(playerctl -p "$p" status 2>/dev/null)" in
        Playing|Paused) player="$p"; break ;;
    esac
done < <(playerctl -l 2>/dev/null)

# Nothing playing: every field is blank, so the widgets simply render empty
# rather than showing an error string.
[ -n "$player" ] || idle "$1"

meta() { playerctl -p "$player" metadata --format "{{ $1 }}" 2>/dev/null; }

# microseconds -> M:SS
fmt_len() { local s=$(( ${1:-0} / 1000000 )); printf "%d:%02d min" $((s/60)) $((s%60)); }
# seconds (possibly fractional) -> M:SS
fmt_pos() { local s=${1%.*}; printf "%d:%02d" $((s/60)) $((s%60)); }

case "$1" in
--title)
    # Optional width. Defaults to the value the other layouts were built
    # around, so adding the argument changes nothing for them.
    w="${2:-15}"
    t="$(meta "xesam:title")"
    if [ -z "$t" ]; then
        echo ""
    elif [ "${#t}" -gt "$w" ]; then
        echo "${t:0:$w}..."
    else
        echo "$t"
    fi
    ;;
--artist)
    w="${2:-20}"
    a="$(meta "xesam:artist")"; echo "${a:0:$w}"
    ;;
--icon)
    # Just the player's glyph, for a pill with no room for a name.
    case "${player%%.*}" in
        spotify) echo "" ;;
        firefox) echo "󰈹" ;;
        vlc)     echo "󰕼" ;;
        *)       echo "" ;;
    esac
    ;;
--album)
    meta "xesam:album"
    ;;
--position)
    pos="$(playerctl -p "$player" position 2>/dev/null)"
    len="$(meta "mpris:length")"
    if [ -n "$pos" ] && [ -n "$len" ]; then
        echo "$(fmt_pos "$pos")/$(fmt_len "$len")"
    else
        echo ""
    fi
    ;;
--length)
    len="$(meta "mpris:length")"; [ -n "$len" ] && fmt_len "$len" || echo ""
    ;;
--status)
    # The glyph is the action the button would take, not the current state.
    case "$(playerctl -p "$player" status 2>/dev/null)" in
        Playing) echo "⏸" ;;
        Paused)  echo "▶" ;;
        *)       echo "" ;;
    esac
    ;;
--source)
    # Upstream only recognised Spotify and printed nothing for anything else.
    # playerctl's player name is the bus name: "spotify", "firefox",
    # "mpv.instance123", "chromium.instance456".
    case "${player%%.*}" in
        spotify)            echo "Spotify " ;;
        firefox)            echo "Firefox 󰈹" ;;
        chromium|chrome|brave) echo "Browser " ;;
        mpv)                echo "mpv " ;;
        vlc)                echo "VLC 󰕼" ;;
        *)                  echo "${player%%.*} " ;;
    esac
    ;;
*)
    echo "Invalid option: $1" >&2
    exit 1
    ;;
esac
