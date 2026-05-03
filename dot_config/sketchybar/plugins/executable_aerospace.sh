#!/usr/bin/env bash

if [ "$1" = "$FOCUSED_WORKSPACE" ]; then
  sketchybar --set "$NAME" background.drawing=on label.color=0xff93a1a1
else
  sketchybar --set "$NAME" background.drawing=off label.color=0xff586e75
fi
