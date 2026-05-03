#!/bin/bash

INTERFACE=$(route -n get default 2>/dev/null | grep interface | awk '{print $2}')
if [ -z "$INTERFACE" ]; then
  sketchybar --set "$NAME" label="--"
  exit 0
fi

BYTES_IN=$(/usr/sbin/netstat -ibn | grep -m1 "$INTERFACE" | awk '{print $7}')
BYTES_OUT=$(/usr/sbin/netstat -ibn | grep -m1 "$INTERFACE" | awk '{print $10}')

PREV_FILE="/tmp/sketchybar_net_${INTERFACE}"

if [ -f "$PREV_FILE" ]; then
  PREV_IN=$(awk 'NR==1' "$PREV_FILE")
  PREV_OUT=$(awk 'NR==2' "$PREV_FILE")
  INTERVAL=$(awk 'NR==3' "$PREV_FILE")
  PREV_TIME=$INTERVAL

  NOW=$(date +%s)
  echo "$BYTES_IN" > "$PREV_FILE"
  echo "$BYTES_OUT" >> "$PREV_FILE"
  echo "$NOW" >> "$PREV_FILE"

  ELAPSED=$((NOW - PREV_TIME))
  if [ "$ELAPSED" -le 0 ]; then ELAPSED=1; fi

  DOWN=$(( (BYTES_IN - PREV_IN) / ELAPSED ))
  UP=$(( (BYTES_OUT - PREV_OUT) / ELAPSED ))

  # Convert to human readable
  if [ "$DOWN" -gt 1048576 ]; then
    DOWN_FMT="$(( DOWN / 1048576 ))M"
  elif [ "$DOWN" -gt 1024 ]; then
    DOWN_FMT="$(( DOWN / 1024 ))K"
  else
    DOWN_FMT="${DOWN}B"
  fi

  if [ "$UP" -gt 1048576 ]; then
    UP_FMT="$(( UP / 1048576 ))M"
  elif [ "$UP" -gt 1024 ]; then
    UP_FMT="$(( UP / 1024 ))K"
  else
    UP_FMT="${UP}B"
  fi

  sketchybar --set "$NAME" label="${DOWN_FMT}/${UP_FMT}"
else
  echo "$BYTES_IN" > "$PREV_FILE"
  echo "$BYTES_OUT" >> "$PREV_FILE"
  echo "$(date +%s)" >> "$PREV_FILE"
  sketchybar --set "$NAME" label="--"
fi
