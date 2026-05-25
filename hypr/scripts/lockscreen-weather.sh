#!/bin/bash
CITY="Los Angeles"
WEATHER=$(curl -s "wttr.in/${CITY// /+}?format=%t+%C" 2>/dev/null)
[ -n "$WEATHER" ] && echo "$WEATHER" > /tmp/hyprlock-weather
