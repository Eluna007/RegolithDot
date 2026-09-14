#!/bin/bash
# Adjusts volume/mic/brightness and reports the new value to the shell's
# OSD via IPC — used by keybinds instead of calling wpctl/brightnessctl
# directly, so the popup shows for ANY trigger (keys), not just bar clicks.
kind="$1"   # volume | mic | brightness
action="$2" # raise | lower | mute

case "$kind" in
  volume)
    case "$action" in
      raise) wpctl set-volume -l 1.0 @DEFAULT_SINK@ 5%+ ;;
      lower) wpctl set-volume @DEFAULT_SINK@ 5%- ;;
      mute)  wpctl set-mute @DEFAULT_SINK@ toggle ;;
    esac
    info=$(wpctl get-volume @DEFAULT_SINK@)
    if echo "$info" | grep -q MUTED; then
      value=0
    else
      value=$(echo "$info" | grep -oP '[0-9.]+' | awk '{printf "%d", $1*100}')
    fi
    ;;
  mic)
    case "$action" in
      mute) wpctl set-mute @DEFAULT_SOURCE@ toggle ;;
    esac
    info=$(wpctl get-volume @DEFAULT_SOURCE@)
    if echo "$info" | grep -q MUTED; then
      value=0
    else
      value=$(echo "$info" | grep -oP '[0-9.]+' | awk '{printf "%d", $1*100}')
    fi
    ;;
  brightness)
    case "$action" in
      raise) brightnessctl set 5%+ >/dev/null ;;
      lower) brightnessctl set 5%- >/dev/null ;;
    esac
    cur=$(brightnessctl g)
    max=$(brightnessctl m)
    value=$(( cur * 100 / max ))
    ;;
esac

qs ipc call osd set "$kind" "$value"
