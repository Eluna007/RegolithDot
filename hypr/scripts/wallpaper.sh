#!/bin/bash

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
THEME_FILE="$HOME/.config/quickshell/myshell/services/Colors.qml"

# Get wallpaper path — use argument or pick with rofi
if [ -n "$1" ]; then
    WALLPAPER="$1"
else
    WALLPAPER=$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.mp4" -o -iname "*.webm" \) | \
        while read -r file; do
            echo -en "$file\x00icon\x1f$file\n"
        done | rofi -dmenu -p "Wallpaper" -i -show-icons \
            -kb-custom-1 "" \
            -format 'p')
fi

[ -z "$WALLPAPER" ] && exit 0

EXT="${WALLPAPER##*.}"
EXT="${EXT,,}"

# Set wallpaper based on file type
if [[ "$EXT" == "mp4" || "$EXT" == "webm" || "$EXT" == "mkv" ]]; then
    pkill mpvpaper 2>/dev/null
    mpvpaper -o "no-audio loop" '*' "$WALLPAPER" &
else
    pgrep awww-daemon > /dev/null || (awww-daemon &)
    sleep 0.5
    awww img "$WALLPAPER" --transition-type wave --transition-duration 1.5
fi

# Extract dominant color with ImageMagick
DOMINANT=$(magick "$WALLPAPER" -resize 50x50\! -format "%[fx:int(255*r+.5)],%[fx:int(255*g+.5)],%[fx:int(255*b+.5)]" info: 2>/dev/null | tr -d '%')

if [ -z "$DOMINANT" ]; then
    echo "Failed to extract color"
    exit 1
fi

R=$(echo $DOMINANT | cut -d',' -f1)
G=$(echo $DOMINANT | cut -d',' -f2)
B=$(echo $DOMINANT | cut -d',' -f3)
HEX=$(printf "#%02x%02x%02x" $R $G $B)

echo "Dominant color: $HEX"

# Generate color scheme with matugen
COLORS=$(matugen color hex "$HEX" -j hex 2>/dev/null)

# Extract key colors
extract() {
    echo "$COLORS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
colors = data.get('colors', {})
key = '$1'
if key in colors:
    print(colors[key]['dark']['color'])
else:
    print('$2')
"
}

PRIMARY=$(extract "primary" "#a2c9fe")
SURFACE=$(extract "surface" "#111418")
SURFACE_VAR=$(extract "surface_variant" "#43474e")
PRIMARY_CONT=$(extract "primary_container" "#1c4875")
ON_SURFACE=$(extract "on_surface" "#e1e2e8")
TERTIARY=$(extract "tertiary" "#d4bae4")

# Write Colors.qml for Quickshell
cat > "$THEME_FILE" << QMLEOF
pragma Singleton

import QtQuick
import Quickshell

Singleton {
    property color primary:          "$PRIMARY"
    property color surface:          "$SURFACE"
    property color surfaceVariant:   "$SURFACE_VAR"
    property color primaryContainer: "$PRIMARY_CONT"
    property color foreground:        "$ON_SURFACE"
    property color tertiary:         "$TERTIARY"
    property color dominant:         "$HEX"
}
QMLEOF

echo "Colors written to $THEME_FILE"
cat > "$HOME/.config/rofi/luna.rasi" << ROFIEOF
* {
    bg:          ${SURFACE}ee;
    bg-alt:      ${SURFACE_VAR}cc;
    bg-active:   ${PRIMARY_CONT}ee;
    fg:          ${ON_SURFACE};
    fg-muted:    ${ON_SURFACE}99;
    accent:      ${PRIMARY};
    tertiary:    ${TERTIARY};
    border-col:  ${PRIMARY}aa;

    background-color: transparent;
    text-color: @fg;
    font: "JetBrainsMono Nerd Font 12";
}

window {
    background-color: @bg;
    border: 2px;
    border-color: @border-col;
    border-radius: 16px;
    width: 480px;
    padding: 16px;
}

mainbox {
    background-color: transparent;
    spacing: 10px;
}

inputbar {
    background-color: @bg-alt;
    border-radius: 10px;
    padding: 10px 14px;
    spacing: 8px;
    children: [prompt, entry];
}

prompt {
    text-color: @accent;
    font: "JetBrainsMono Nerd Font Bold 12";
}

entry {
    text-color: @fg;
    placeholder: "Search...";
    placeholder-color: @fg-muted;
}

listview {
    background-color: transparent;
    lines: 8;
    columns: 1;
    spacing: 4px;
    margin: 8px 0 0 0;
}

element {
    background-color: transparent;
    border-radius: 8px;
    padding: 8px 12px;
    spacing: 10px;
    orientation: horizontal;
}

element normal.normal {
    background-color: transparent;
    text-color: @fg;
}

element selected.normal {
    background-color: @bg-active;
    text-color: @fg;
}

element-icon {
    size: 20px;
}

element-text {
    text-color: inherit;
    vertical-align: 0.5;
}

scrollbar {
    background-color: @bg-alt;
    handle-color: @accent;
    handle-width: 4px;
    border-radius: 4px;
    width: 4px;
}
ROFIEOF
echo "Rofi theme updated"

# Update Hyprland border colors
hyprctl eval "hl.config({ general = { col = { active_border = { colors = {'rgb(${PRIMARY//#/})', 'rgb(${TERTIARY//#/})'}, angle = 45 }, inactive_border = 'rgb(${SURFACE_VAR//#/})' } } })" 2>/dev/null

echo "Done! Wallpaper and theme updated."
