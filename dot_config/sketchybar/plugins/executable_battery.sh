#!/bin/bash
PERCENTAGE=$(pmset -g batt | grep -Eo "\d+%" | head -1)
sketchybar --set "$NAME" label="$PERCENTAGE"
