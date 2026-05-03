#!/bin/bash
USED=$(memory_pressure | grep "System-wide memory free percentage:" | awk '{print 100 - $5}' | tr -d '%')
sketchybar --set "$NAME" label="${USED}%"
