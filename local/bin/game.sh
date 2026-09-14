#!/bin/bash
powerprofilesctl set performance
gamemoderun mangohud "$@"
powerprofilesctl set balanced
