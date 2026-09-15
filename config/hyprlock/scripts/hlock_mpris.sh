#!/usr/bin/env bash
# Prints the path of the current track's album art, for hyprlock's reload_cmd.
#
# hyprlock's `reload_cmd` is expected to PRINT A PATH; hyprlock then loads it.
# So this always prints something - a transparent placeholder when there is no
# art - because printing nothing, or a path that does not exist, makes hyprlock
# log "cannot get file time" and render a broken widget.
#
# Rewritten from upstream, which was hardcoded to `playerctl -p spotify`, only
# understood http(s) art URLs, and signalled hyprlock with SIGUSR2 instead of
# printing a path. It now takes whichever MPRIS player is actually playing.
set -uo pipefail

ART="/tmp/apollo-mpris-art.png"
BLUR="/tmp/apollo-mpris-blurred.png"
SEEN="/tmp/apollo-mpris.url"
NONE="${HOME}/.config/hyprlock/assets/no-art.png"

no_art() { printf '%s\n' "$NONE"; exit 0; }

command -v playerctl >/dev/null 2>&1 || no_art

# First player that is playing or paused. `playerctl -l` lists every MPRIS
# client - browsers register one per tab - so status is what picks the real one.
player=""
while read -r p; do
    [ -n "$p" ] || continue
    case "$(playerctl -p "$p" status 2>/dev/null)" in
        Playing|Paused) player="$p"; break ;;
    esac
done < <(playerctl -l 2>/dev/null)
[ -n "$player" ] || no_art

url="$(playerctl -p "$player" metadata --format '{{mpris:artUrl}}' 2>/dev/null)"
[ -n "$url" ] || no_art

# Same track as last time and the file is still there: skip the work. reload_cmd
# runs every reload_time seconds, so without this a network fetch would repeat
# every couple of seconds for as long as the screen is locked.
if [ -f "$SEEN" ] && [ -f "$ART" ] && [ "$(cat "$SEEN")" = "$url" ]; then
    printf '%s\n' "$ART"; exit 0
fi

tmp="$(mktemp /tmp/apollo-mpris-dl.XXXXXX)" || no_art
trap 'rm -f "$tmp"' EXIT

case "$url" in
    file://*)
        # Local players (mpv, Rhythmbox, a browser with a local file) hand back
        # a percent-encoded file:// URL.
        src="${url#file://}"
        src="$(printf '%b' "${src//%/\\x}")"
        [ -f "$src" ] || no_art
        cp -- "$src" "$tmp" || no_art
        ;;
    http://*|https://*)
        command -v curl >/dev/null 2>&1 || no_art
        curl -sSfL --max-time 5 -o "$tmp" "$url" || no_art
        ;;
    data:image/*)
        # Some players inline the cover as base64.
        printf '%s' "${url#*,}" | base64 -d > "$tmp" 2>/dev/null || no_art
        ;;
    *)
        no_art
        ;;
esac

[ -s "$tmp" ] || no_art

if command -v magick >/dev/null 2>&1; then
    magick "$tmp" -quality 50 "$ART" 2>/dev/null || no_art
    # Blurred full-screen version, for layouts that use it as a backdrop.
    magick "$ART" -blur 200x7 -resize 1920x^ -gravity center \
        -extent 1920x1080 "$BLUR" 2>/dev/null
else
    # No ImageMagick: use the download as-is. Most cover art is already a
    # reasonable PNG or JPEG, and hyprlock reads both.
    cp -- "$tmp" "$ART" || no_art
fi

printf '%s\n' "$url" > "$SEEN"
printf '%s\n' "$ART"
