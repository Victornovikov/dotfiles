#!/bin/bash
CPU=$(top -l 1 -n 0 | grep "CPU usage" | awk '{printf "%d", $3}')
sketchybar --set "$NAME" label="${CPU}%"
