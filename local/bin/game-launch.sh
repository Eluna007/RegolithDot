#!/bin/bash
powerprofilesctl set performance
"$@"
powerprofilesctl set balanced
