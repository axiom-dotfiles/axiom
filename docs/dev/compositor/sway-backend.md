# Sway backend (plan)

> **Files:** `services/CompositorManager.qml`, `services/HyprlandManager.qml`, `scripts/dev/nested.sh`
> **Config:** `WindowLook.*`
> **Related:** [The compositor](README.md), [Backend contract](contract.md), [Recipe: compositor backend](../../recipes/compositor-backend.md)

Not written yet: what a sway backend needs, mapped onto the [contract](contract.md), and how to run it while writing it. The rest of the shell already goes through `CompositorManager`, so the backend is one new service plus a line in `CompositorManager.backend`. Remove this doc's "plan" status (and its `issues.md` entry) once it lands.

### Running it
- `scripts/dev/nested.sh sway` (needs `sway`; `foot` for a terminal inside) opens sway in a window, with a second axiom in it:
  - on scratch folders
  - on its own D-Bus session
  - with idle and polkit off.
- `--copy-config` starts from your own config.
- `scripts/dev/nested.sh niri` does the same for niri. With no niri backend, axiom runs there on no backend at all (the bar, the launcher and notifications; empty workspaces). That's the "unknown compositor" case to keep working.
- Logs: the newest `/run/user/$UID/quickshell/by-pid/<pid>/log.log` (`pgrep -af "qs -p"`: the one without `-d`).
- IPC: `qs ipc --pid <pid> call …`.
- Closing the window, or killing that `sway`, ends both.

### State: `Quickshell.I3`
Quickshell's `I3` module speaks sway's IPC (`$SWAYSOCK`). It gives `monitors`, `workspaces`, `focusedMonitor`, `focusedWorkspace`, `dispatch(command)` (a `run_command`; no reply), `rawEvent` and `I3IpcListener` (subscribe to chosen events).
- **outputs**: from `I3.monitors` (`name`, `x`, `y`, `width`, `height`, `scale`, `focused`, `activeWorkspace`, `lastIpcObject` for `make model serial` as the `description`).
  - `reserved`: the output's rect minus its active workspace's rect (`get_workspaces`).
  - `specialWorkspaceId` is always 0 (the scratchpad isn't a workspace).
- **workspaces**: `I3.workspaces`, `id` = `num`. `windowCount` comes from the tree.
- **windows**: the I3 module has no window list. Run `swaymsg -t get_tree -r` (a `Process`), again on a debounced `I3IpcListener { subscriptions: "window workspace" }` event, and walk the tree's `nodes` and `floating_nodes` for leaves with a `pid`:
  - `id` = `String(con_id)`
  - `appId` = `app_id` ?? `window_properties.class`
  - `title` = `name`
  - `workspaceId`/`output` from the enclosing nodes
  - `floating`: under `floating_nodes`
  - `fullscreen`: `fullscreen_mode > 0`
  - `hidden`: not `visible`, when on the active workspace
  - geometry = `rect` (global, logical)
  - `focusRank`: sway keeps no history; track an MRU list from `window` focus events (0 = `focused`).
- **activeWindowId**: the focused leaf's `con_id`.
- **gapsOut**: sway's `gaps outer` (from `WindowLook` when axiom sets it, else 0). `get_tree` has no per-side gaps.
- Put the tree walking in a pure helper (`SwayState`, with `tst_SwayState` on a `get_tree` fixture), as `HyprState` is for Hyprland.

### Primitives
- `activateWindow(id)`: `[con_id=<id>] focus`
- `closeWindow(id)`: `[con_id=<id>] kill`
- `travel(output, legs, mode, focusId)`: no slide (`workspaceSlide` false), so only the last leg.
  - `focus output <name>` when `output` is set.
  - `go`: `workspace number <id>`.
  - `move`: `move container to workspace number <id>; workspace number <id>`.
  - `focusId`: activate the window.
  - Keep `travelingTo` at -1.
- `sendWindowToWorkspace(id)`: `move container to workspace number <id>`
- `applyRemap(plan, outputs)`: `[con_id=…] move container to workspace number …`, then `focus output …; workspace number …`. Sway also creates a workspace on the output it's first used from, so keep the named-workspace detour `HyprlandManager.applyRemap` uses.
- `placeWindow`/`resizeWindow`: `move container to workspace number <id>` only (no dwindle aim). `resize grow|shrink width|height <px>` for resizes.
- `withKeyboard`: `swaymsg -t get_inputs -r`, the first `type: keyboard` with `xkb_layout_names` and `xkb_active_layout_index`. Refresh on `input` events (`keyboardLayoutChanged`).
- `cycleKeyboardLayout`: `input type:keyboard xkb_switch_layout next|prev`
- `exitSession`: `exit`. `dpmsCommand(on)`: `swaymsg 'output * power on|off'`.
- `toplevelFor(id)`: match `ToplevelManager.toplevels` by appId and title (the protocol has no id).
- `withLayerRects`: null (sway has no layer listing; `LayerManager` places axiom's layers without it). `withCursorPos`: null.
- `configReloaded`: from the `shutdown`/`reload` events (`I3IpcListener` "shutdown" isn't it: use the `config` subscription when Quickshell passes it, else `binding`/`tick`).

### The window look (`applyLook`)
- gaps: `gaps inner all set <gapsIn>`, `gaps outer all set <gapsOut>`, and set `gapsOut` to match
- borders: `client.focused <c> <c> <text> <c> <c>`, `client.unfocused …` from `activeColor`/`inactiveColor`, plus `default_border pixel <borderWidth>`
- shape: SwayFX's `corner_radius <radius>`. Vanilla sway has none: leave `windowShape` out of `supports` unless `swaymsg -t get_version` says SwayFX.
- Each part turned off: put sway's defaults back (`gaps inner all set 0`, …). A config reload drops them anyway, and `CompositorManager` applies the look again after `configReloaded`.

### `supports` for sway
`windowGeometry`, `windowBorders`, `windowGaps` (plus `windowShape` on SwayFX). Everything else is false: `configModes`, `keybinds`, `monitors`, `switcher`, `strips`, `focusGrab`, `layerOrder`, `blur`, `cursorPos`, `cursorWarp`, `workspaceSlide`, `windowBlur`, `windowOpacity`.

### Open questions (check in the nested session)
- **Click outside.** Without `focusGrab`, a grabbing surface takes the keyboard exclusively and each screen's backdrop window catches the click outside it ([README](README.md) › Focus grab). Typing into the launcher opened by IPC works in nested sway; check by hand that bar popouts with text fields, the launcher, the overlay and the power menu close on an outside click.
- **Layer stacking.** With no `layerOrder`, `LayerManager` maps the stacked surfaces in `LayerStack` order ([layer arrangement](layer-arrangement.md)); checked in nested sway for a solid and a floating-pills bar against the border, and an integrated edge menu.
- **`surfacesReady`.** Return true at once.
- **Workspace numbers.** `workspace number N` creates N on the focused output. Check the perMonitor and grid layouts' blocks. Ids are `num` (a named workspace with no number has `num` -1; skip those).
- **The greeter** stays a Hyprland session (`issues.md`).
