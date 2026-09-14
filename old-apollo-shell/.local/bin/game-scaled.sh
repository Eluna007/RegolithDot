#!/bin/bash
powerprofilesctl set performance
gamescope -W 1920 -H 1080 -w 1280 -h 720 -F fsr -- gamemoderun mangohud "$@"
powerprofilesctl set balanced
