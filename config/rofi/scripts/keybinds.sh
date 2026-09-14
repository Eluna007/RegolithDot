#!/usr/bin/env bash
# Keybinds cheatsheet rofi mode.
#
# The Moonlit version of this script parsed ~/.config/hypr/keybinds.conf by
# hand, matching `bind = mods, key, dispatcher, args` lines and expanding
# `$variables`. None of that survives the move to Lua: binds are now function
# calls, the arguments are tables, and a `for i = 1, 4` loop registers four
# binds that appear nowhere in the file as text.
#
# So instead of parsing the config, ask the compositor. `hyprctl binds -j`
# reports what is actually registered — loops, helper functions, apollo-settings
# overrides and all — which is what "never drifts from what's bound" always
# meant. Binds carrying a `description` flag show it; the rest fall back to
# their dispatcher.
#
# Selecting a row copies the shortcut to the clipboard.

retv="${ROFI_RETV:-0}"
input="${1:-}"

if [[ "$retv" -ge 1 ]]; then
    combo="${input%%  →*}"
    # Trim trailing whitespace left by the separator.
    combo="${combo%"${combo##*[![:space:]]}"}"
    printf '%s' "$combo" | wl-copy
    qs -c apollo ipc call notify send Apollo "Copied" "$combo copied to clipboard" &>/dev/null &
    exit 0
fi

printf '\x00prompt\x1fkeybinds\n'

if ! command -v hyprctl >/dev/null || ! command -v jq >/dev/null; then
    printf 'hyprctl and jq are required for the keybind cheatsheet\n'
    exit 0
fi

# modmask is a bitfield: SHIFT 1, CAPS 2, CTRL 4, ALT 8, MOD2 16, MOD3 32,
# SUPER 64, MOD5 128. Order them the way people say them out loud.
hyprctl binds -j | jq -r '
    def mods($m):
        [ if ($m /  64 | floor) % 2 == 1 then "Super" else empty end,
          if ($m /   4 | floor) % 2 == 1 then "Ctrl"  else empty end,
          if ($m /   8 | floor) % 2 == 1 then "Alt"   else empty end,
          if ($m /   1 | floor) % 2 == 1 then "Shift" else empty end ];

    def keylabel($k):
        { "comma": ",", "period": ".", "slash": "/", "minus": "-",
          "mouse:272": "Mouse Left", "mouse:273": "Mouse Right",
          "mouse_up": "Scroll Up", "mouse_down": "Scroll Down",
          "XF86MonBrightnessUp": "Brightness Up",
          "XF86MonBrightnessDown": "Brightness Down",
          "XF86AudioRaiseVolume": "Volume Up",
          "XF86AudioLowerVolume": "Volume Down",
          "XF86AudioMute": "Mute",
          "XF86AudioMicMute": "Mic Mute",
          "XF86SelectiveScreenshot": "Screenshot Key",
          "XF86AudioPlay": "Play/Pause",
          "XF86AudioNext": "Next Track",
          "XF86AudioPrev": "Previous Track"
        }[$k] // $k;

    .[]
    | select((.key // "") != "" or (.keycode // 0) != 0)
    | (mods(.modmask) + [ keylabel(.key // ("code:" + (.keycode|tostring))) ] | join(" + ")) as $combo
    | (if (.description // "") == "" then (.dispatcher // "?") else .description end) as $what
    | "\($combo)  →  \($what)"
' | {
    q="${input,,}"
    while IFS= read -r row; do
        if [[ -z "$q" || "${row,,}" == *"$q"* ]]; then
            printf '%s\n' "$row"
        fi
    done
}
