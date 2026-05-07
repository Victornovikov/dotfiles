---
name: aerospace
description: Configure and troubleshoot AeroSpace tiling window manager and SketchyBar status bar on macOS. Use when user asks about window management, workspaces, keybindings, bar items, or layout changes.
allowed-tools: Read Edit Write Bash(sketchybar *) Bash(aerospace *) Bash(borders *) Bash(/opt/homebrew/bin/sketchybar *) Bash(/opt/homebrew/bin/aerospace *) Bash(/opt/homebrew/bin/borders *) Bash(brew services *) Bash(brew install *) Bash(pkill borders*) Bash(chmod *) Bash(jq *) Bash(defaults read*)
---

# AeroSpace + SketchyBar Skill

You are helping the user configure their macOS tiling window manager setup.

## Config locations

- AeroSpace config: `~/.aerospace.toml`
- SketchyBar config: `~/.config/sketchybar/sketchybarrc`
- SketchyBar plugins: `~/.config/sketchybar/plugins/`
- Ghostty terminal: `~/.config/ghostty/config`
- JankyBorders: configured inline via `borders` args in `~/.aerospace.toml` `after-startup-command` (no separate config file)

## Critical: PATH issue

`/opt/homebrew/bin` is NOT in PATH when AeroSpace or SketchyBar spawn shell commands via `/bin/bash -c`, nor when SketchyBar runs under launchd (via `brew services`). Always use full paths in:
- `aerospace.toml` exec commands: `/opt/homebrew/bin/sketchybar`
- `aerospace.toml` after-startup-command: `/opt/homebrew/bin/sketchybar`
- `sketchybarrc` itself — e.g. `for sid in $(/opt/homebrew/bin/aerospace list-workspaces --all)`. Without the full path, `aerospace` is silently not found and the loop produces nothing, so no workspace items get created in the bar.
- SketchyBar plugin scripts that shell out to brew-installed tools.

Symptoms: missing bar items (loops silently skipped), triggers that don't fire, scripts that work interactively but fail under launchd.

## AeroSpace config rules

- `after-startup-command` and `exec-on-workspace-change` take arrays of AeroSpace commands
- `exec-and-forget` is a single AeroSpace command that takes the rest of the string as a shell command — it is ONE array element: `'exec-and-forget /bin/bash -c "..."'`
- Do NOT split `/bin/bash` and `-c` into separate array elements for `after-startup-command` — that treats them as separate AeroSpace subcommands
- `exec-on-workspace-change` is different — it accepts `['/bin/bash', '-c', '...']` format (shell command array, not AeroSpace command array)
- Available env var in exec-on-workspace-change: `$AEROSPACE_FOCUSED_WORKSPACE`

## SketchyBar + AeroSpace integration

The workspace change flow:
1. User switches workspace (e.g. alt+2)
2. AeroSpace runs exec-on-workspace-change which triggers: `sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE=$AEROSPACE_FOCUSED_WORKSPACE`
3. SketchyBar fires the event on all subscribed items
4. Each workspace item runs its script with `FOCUSED_WORKSPACE` in env
5. Script compares `$1` (workspace id) to `$FOCUSED_WORKSPACE` to highlight/dim

Key setup in sketchybarrc:
```bash
sketchybar --add event aerospace_workspace_change

# Iterate an explicit workspace range (not `list-workspaces --all`).
# Rationale: AeroSpace creates workspaces lazily and never destroys them,
# so `--all` returns stragglers (10/11/...) from accidental keypresses.
# The explicit range matches the keybind scheme and force-assignment.
for sid in 1 2 3 4 5 6 7 8 9; do
  /opt/homebrew/bin/sketchybar --add item space.$sid left \
    --subscribe space.$sid aerospace_workspace_change \
    --set space.$sid \
      script="$HOME/.config/sketchybar/plugins/aerospace.sh $sid"
done
```

Plugin script pattern:
```bash
#!/usr/bin/env bash
if [ "$1" = "$FOCUSED_WORKSPACE" ]; then
  sketchybar --set "$NAME" background.drawing=on
else
  sketchybar --set "$NAME" background.drawing=off
fi
```

## macOS Spaces prerequisite

AeroSpace replaces macOS Spaces. Correct setup:
- System Settings → Desktop & Dock → Mission Control → uncheck **"Displays have separate Spaces"** (logout/login to apply).
- Remove all extra Mission Control desktops (enter Mission Control, X out extras — leave one "Desktop" total).
- Verify with `defaults read com.apple.spaces spans-displays` → expect `1` (semantics inverted from UI: `1` = separate Spaces OFF = Spaces span all displays).
- In Mission Control's top strip you should see only "Desktop" (no numbered Desktop 1/2/3). Per-monitor thumbnail differences below are expected — one Space, windows distributed across monitors.

## macOS menu bar prerequisite (for SketchyBar at top)

The macOS menu bar and SketchyBar both want to live at the top of the screen. Without hiding the system menu bar, SketchyBar sits under it and you see both — ugly, and the system bar steals the top edge for click targets.

Fix: auto-hide the system menu bar so SketchyBar owns the top.
- System Settings → Control Center → Menu Bar → **"Automatically hide and show the menu bar"** → **Always**.
- Verify: `defaults read NSGlobalDomain _HIHideMenuBar` → expect `1`.
- Effect: system menu bar hides until you flick the cursor to the top edge; SketchyBar stays visible at the top at all times because it's a separate overlay window.

Note this also changes `outer.top` reasoning: with the menu bar always hidden, external monitors and the built-in display behave the same — no need for the per-monitor split documented in "Multi-monitor gap handling" below if you only run AeroSpace on machines with the bar always hidden.

## Workspace-to-monitor assignment

AeroSpace workspaces each "live" on exactly one monitor — wherever they were last shown. `alt-N` only changes the monitor that owns workspace N; other monitors stay put. Without pinning, workspaces drift to whichever monitor was focused, making switching unpredictable.

Pin with `workspace-to-monitor-force-assignment`:

```toml
[workspace-to-monitor-force-assignment]
1 = 3       # built-in laptop (rightmost by x)
4 = 2       # middle monitor
7 = 1       # leftmost monitor
```

Each slot accepts:
- **Sequence number** (1-indexed left-to-right by x-coordinate) — **preferred**. Matches `aerospace list-monitors` output order. Stable across sessions on the same physical layout.
- Exact monitor name (from `aerospace list-monitors`) — **unreliable**: EDID can report wrong names (e.g. a portrait external showing as "Built-in Retina Display"). Avoid unless verified.
- Regex substring of monitor name.
- Keywords `main` / `secondary`.
- List: evaluated left-to-right, first match wins — use for disconnect resilience (different displays at different locations). Example: `4 = [2, 'secondary']`.

Gotchas:
- AeroSpace's sequence numbers in force-assignment ARE left-to-right by x. AeroSpace's `list-monitors` output uses the same ordering. So `1 = 2` in force-assignment means "the 2nd monitor left-to-right" which matches `aerospace list-monitors`' id 2.
- **Do not trust monitor names** — always verify with `aerospace list-monitors` and compare physical screen positions. When names contradict physical reality, use sequence numbers.
- Behavior when the assigned monitor isn't connected and no fallback matches: workspace lands on the currently focused monitor. For disconnect resilience, use fallback lists.
- Existing windows don't auto-migrate on config reload. Move them manually with `alt-shift-N` or via `aerospace move-node-to-workspace`.
- Stray workspaces (10, 11, ...) accumulate from accidental keypresses and persist forever. Filter the SketchyBar item loop to the configured range (1-9).

## Per-monitor bar display (show only owning monitor's workspaces)

Goal: each monitor's SketchyBar shows only workspaces pinned to that monitor. Requires assigning each `space.N` item the right `display=` value.

**The core problem** (SketchyBar issue #607): AeroSpace's `monitor-id` is ordered left-to-right by x-coordinate, but SketchyBar's `display=N` uses AppKit's `arrangement-id` which depends on main-display + connection history — **these two orderings don't match**. Neither does `monitor-appkit-nsscreen-screens-id` reliably: `NSScreen.screens` array order differs from `arrangement-id` order on some setups.

**Robust solution** — sort SketchyBar's displays by x-coordinate so position N in the sorted list corresponds to AeroSpace monitor-id N:

`~/.config/sketchybar/plugins/update_space_displays.sh`:
```bash
#!/usr/bin/env bash
AEROSPACE=/opt/homebrew/bin/aerospace
SKETCHYBAR=/opt/homebrew/bin/sketchybar

mapfile -t arrangement_ids < <(
  "$SKETCHYBAR" --query displays | jq -r 'sort_by(.frame.x) | .[]["arrangement-id"]'
)

"$AEROSPACE" list-monitors --format '%{monitor-id}' | while read -r mid; do
  display_id="${arrangement_ids[$((mid - 1))]}"
  for sid in $("$AEROSPACE" list-workspaces --monitor "$mid"); do
    [[ "$sid" =~ ^[1-9]$ ]] || continue
    "$SKETCHYBAR" --set space."$sid" display="$display_id"
  done
done
```

Wire it into `sketchybarrc` after all `space.N` items are created, and subscribe to `display_change` so the mapping recomputes when monitors connect/disconnect:

```bash
sketchybar --add item space_displays_updater left \
  --set space_displays_updater \
    drawing=off \
    script="$HOME/.config/sketchybar/plugins/update_space_displays.sh" \
  --subscribe space_displays_updater display_change

"$HOME/.config/sketchybar/plugins/update_space_displays.sh"
```

**Verifying correctness:** `associated_display_mask` in `sketchybar --query space.N` is `1 << display`, so `display=1 → mask=2`, `display=2 → mask=4`, `display=3 → mask=8`. Check physical monitor with `sketchybar --query displays` and compare `frame` dimensions to what's on-screen.

**Alternatives explored:**
- FelixKratz's recommended approach `display=${nsscreen-screens-id}` — works only when `NSScreen.screens` order matches `arrangement-id` order, not universally.
- kahl-dev's `match_displays.sh` — most robust, uses Swift to cross-reference `NSScreen.localizedName + DirectDisplayID` against `sketchybar --query displays` and aerospace names. Overkill when the x-sort approach works.

## Current keybind scheme (Alt as modifier, vim-style)

- Focus: alt + h/j/k/l
- Move window: alt+shift + h/j/k/l
- Move to monitor: alt+ctrl + h/j/k/l (follows focus)
- Focus monitor: alt+tab / alt+shift+tab
- Workspaces: alt + 1-9
- Move to workspace: alt+shift + 1-9
- Move to workspace + follow: alt+ctrl + 1-9
- Cycle windows: alt+n / alt+shift+n
- Layouts: alt+/ (tile toggle), alt+, (accordion), alt+e (horizontal), alt+s (vertical)
- Fullscreen: alt+f
- Float toggle: alt+shift+f
- Resize: alt+shift + -/=
- Service mode: alt+shift+; (then esc to reload)

## SketchyBar plugin guidelines

- Avoid Unicode symbols (arrows, icons, etc.) in labels — they have different glyph heights than JetBrains Mono and cause vertical misalignment. Use plain ASCII instead (e.g. `d`/`u` not `↓`/`↑`).
- For items with variable-length labels (like network speeds), set `label.width` to a fixed value and `label.align=left` to prevent the bar from jumping/reflowing.
- Use `top -l 1 -n 0` for CPU (use `awk '{printf "%d", $3}'` to truncate decimals).
- Use `memory_pressure` for RAM.
- Use `netstat -ibn` for network throughput (store previous reading in `/tmp/` to calculate delta).

## SketchyBar current items (right side, left to right)

CPU, RAM, NET, VOL, BAT, clock

## SketchyBar current theme: Solarized Dark

- Bar background: `0xff002b36`
- Active text: `0xff93a1a1`
- Dimmed text: `0xff586e75`
- Highlight: `0xff073642`
- Accent: `0xff268bd2`
- Font: JetBrains Mono

## Reloading

- AeroSpace: `alt+shift+;` then `esc`, or `aerospace reload-config`
- SketchyBar: `sketchybar --reload` or `brew services restart sketchybar`

## Multi-monitor gap handling

SketchyBar draws at the top of each screen but doesn't reserve screen space like the macOS menu bar. On the built-in Retina display, the system menu bar reserves ~25px so `outer.top = 10` is enough to clear the 32px bar. On external monitors (which may lack their own menu bar), windows overlap the bar.

Fix: use AeroSpace's per-monitor gap syntax to give external monitors a larger `outer.top`:

```toml
outer.top = [{monitor.'Built-in Retina Display' = 10}, 42]
```

This keeps 10px on built-in (menu bar handles the rest) and sets 42px (32 bar + 10 gap) as the default for all other monitors.

Syntax: `[{monitor.'Monitor Name' = value}, ..., default_value]` — monitor names come from `aerospace list-monitors`.

## Window borders (JankyBorders)

AeroSpace doesn't draw borders around windows — there's no native way to see which window is focused. Solved with [JankyBorders](https://github.com/FelixKratz/JankyBorders) (FelixKratz, same author as SketchyBar).

Install: `brew install borders`.

Launched from `after-startup-command` in `~/.aerospace.toml` so its lifecycle ties to AeroSpace. **Use full path** (PATH issue, see top of this file):

```toml
after-startup-command = [
  'exec-and-forget /opt/homebrew/bin/sketchybar',
  'exec-and-forget /opt/homebrew/bin/borders active_color=0xffcb4b16 inactive_color=0xff586e75 width=4.0',
]
```

Current Solarized Dark colors:
- `active_color=0xffcb4b16` — Solarized orange (focused window). Differentiates from SketchyBar's blue accent so window-focus and workspace-focus cues don't compete.
- `inactive_color=0xff586e75` — Solarized base01 (dim grey). Use `0x00000000` to hide inactive borders entirely.
- `width=4.0` — visible without being intrusive.

Other useful args: `style=round` for rounded corners, `hidpi=on` for retina sharpness.

Live tweaking (no AeroSpace reload needed):

```bash
pkill borders
/opt/homebrew/bin/borders active_color=0xffXXXXXX inactive_color=0xffYYYYYY width=N.0 &
```

After settling on values, update the `after-startup-command` line in `~/.aerospace.toml` so they persist across restarts.

## When making changes

1. Always read the current config before editing
2. After editing aerospace.toml, remind user to reload: `alt+shift+; then esc`
3. After editing sketchybar configs, run `sketchybar --reload`
4. Test triggers manually when debugging: `sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE=1`
