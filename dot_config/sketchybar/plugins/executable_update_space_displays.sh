#!/usr/bin/env bash

# Assigns each space.N SketchyBar item to the correct physical display
# based on which AeroSpace monitor currently owns workspace N.
#
# Why this is non-trivial: AeroSpace's monitor-id is ordered left-to-right
# by x-coordinate, but SketchyBar's `display` flag uses AppKit's
# arrangement-id which has a different (macOS-internal) ordering.
# Neither monitor-id nor nsscreen-screens-id maps 1:1 to arrangement-id.
#
# Translation: sort SketchyBar's displays by frame.x; the nth entry
# corresponds to AeroSpace monitor-id n.

AEROSPACE=/opt/homebrew/bin/aerospace
SKETCHYBAR=/opt/homebrew/bin/sketchybar
JQ=/usr/bin/jq

# Build positional array: arrangement_ids[i] = arrangement-id of the i-th
# monitor from the left (matches AeroSpace's monitor-id ordering).
mapfile -t arrangement_ids < <(
  "$SKETCHYBAR" --query displays | "$JQ" -r 'sort_by(.frame.x) | .[]["arrangement-id"]'
)

"$AEROSPACE" list-monitors --format '%{monitor-id}' | while read -r mid; do
  # aerospace monitor-id is 1-based; array is 0-based
  display_id="${arrangement_ids[$((mid - 1))]}"
  for sid in $("$AEROSPACE" list-workspaces --monitor "$mid"); do
    # Only configured workspaces (1-9) have bar items
    [[ "$sid" =~ ^[1-9]$ ]] || continue
    "$SKETCHYBAR" --set space."$sid" display="$display_id"
  done
done
