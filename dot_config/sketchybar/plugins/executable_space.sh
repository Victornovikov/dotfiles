#!/bin/bash
if [ "$SELECTED" = "true" ]; then
  sketchybar --set "$NAME" background.drawing=on icon.color=0xff268bd2
else
  sketchybar --set "$NAME" background.drawing=off icon.color=0xff93a1a1
fi
