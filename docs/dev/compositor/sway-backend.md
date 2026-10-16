# Sway backend

> **Files:** `services/SwayManager.qml`, `services/SwayIpcManager.qml`, `components/methods/SwayState.qml`, `components/methods/SwayConf.qml`, `tests/tst_SwayState.qml`, `tests/tst_SwayConf.qml`, `services/CompositorManager.qml`, `scripts/dev/nested.sh`
> **Config:** `WindowLook.*`, `Monitors.profiles`
> **Related:** [The compositor](README.md), [Backend contract](contract.md), [Recipe: compositor backend](../../recipes/compositor-backend.md)

`SwayManager` is `CompositorManager.backend` under sway: the state, workspaces, windows, outputs, keyboard and special groups work. Its config writer (binds, the window look, input, the three modes) isn't written yet: the plan for it is under [The config writer](#the-config-writer-swayconfigwriter-planned), and until it lands `supports.configModes` and `keybinds` stay off.

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

### State
Outputs and workspaces come live from Quickshell's `I3` module (as Hyprland's do from `Quickshell.Hyprland`); everything else from sway's replies, read through `swaymsg` (`SwayIpcManager`: `I3.dispatch` runs a command with no reply, and `I3` has no window tree, inputs or outputs in full). The replies become the [shapes](contract.md#shapes) in `SwayState` (`tst_SwayState`, on replies captured in nested sway under `tests/fixtures/sway/`).
- **Events**: an `I3IpcListener` on `window`, `workspace`, `output`, `input` and `binding`; any of them re-reads the tree (`get_tree`, debounced 50 ms).
  - `configReloaded`: a `workspace` event with change `reload`.
  - `outputsHotplugged`: an `output` event that changed the set of output names (sway sends `output` for any output change).
  - `keyboardLayoutChanged`: `input` with `xkb_layout` / `xkb_keymap`.
  - `windowFocused`: `window` with `focus`. `layersChanged`: never (sway reports no layer surfaces).
  - `binding`: axiom's own binds run `nop axiom <what> <verb> [argument]` (`switcher step|commit|cancel` → `switcherKey`; `special toggle|move <name>`), so a key costs no process.
- **windows** (`SwayState.tree`): the tree's leaves with a pid, under `nodes` and `floating_nodes`; the scratchpad's aren't listed until shown.
  - `id` = `String(con_id)`; `appId` = `app_id`, else the X11 `class`; `initialAppId` the same.
  - `workspaceId` = the workspace's `num` (-1 on a named one); `fullscreen`: `fullscreen_mode` > 0; `maximized`: never.
  - `hidden`: behind the front tab of a tabbed or stacked container.
  - geometry = `rect` (global, logical, with the title bar). Sway reports no change to the space layer surfaces reserve, so the tree is read again 1.5 s after start, and the overview and dock `refresh()` on opening.
  - `focusRank`: the windows focused since axiom started (a JSON list in `PersistentProperties`), then the order sway's per-container focus stacks give (`SwayState.ranked`).
- **outputs** (`SwayState.output`): `I3.monitors`; `description` = `make model serial` (the parts that aren't `Unknown`), sway's own identifier for an output; `reserved` = the output's rect minus its active workspace's (from the tree); `specialWorkspaceId` always 0.
- **workspaces** (`SwayState.workspace`): `I3.workspaces` with a number; `windowCount` from the tree.
- **gapsOut**: sway's IPC has no gaps. Read from its config (`get_config`, `SwayState.configInfo`): outer plus inner per edge, as sway leaves both at the screen edge; read again on every reload.
- **Keyboard**: `get_inputs`, the first keyboard named like one. Sway names layouts in full ("English (US)"): their short names come from `Input.kbLayout` when axiom sets the keyboard, else the config's `xkb_layout`, else from the name (`SwayState.keyboard`).

### Primitives
- `activateWindow` / `closeWindow`: `[con_id=N] focus` / `kill`.
- `travel`: no slide (`workspaceSlide` off), so only the last leg: `focus output <name>` when given, then `workspace number N`, `move container to workspace number N; workspace number N`, or `[con_id=focusId] focus`. `travelingTo` stays -1.
- `sendWindowToWorkspace`: `move container to workspace number N`.
- `applyRemap`: Hyprland's detour through named workspaces (`axiom-remap-…`). Sway creates a workspace on the focused output, so each output is focused before its windows move.
- `placeWindow` (the overview's drop): next to a target, it marks the target (`axiom-drop`), splits it on the side's axis and moves the window to the mark, which puts it after the target; left and top then swap the two. With no target, onto the workspace; a floating window then moves to `floatAt` (`move absolute position`). Sway can't put the cursor back (`restore` unused).
- `resizeWindow`: `resize grow|shrink width|height N px`; a floating window also moves by (dx, dy).
- Special workspaces are groups of scratchpad windows (`namedSpecial`, once binds can reach them):
  - `moveToSpecial(name)`: marks the focused window `axiom-special-<name>-<id>` and moves it to the scratchpad.
  - `toggleSpecial(name)`: shows the group's windows on the focused output (`scratchpad show`, floating), or hides them all (`move scratchpad`) when any is shown there (`SwayState.specialToggle`).
- `withOutputDetails`: `get_outputs` (`SwayState.outputDetails`; modes as `WxH@R.RRHz`). `applyOutputs`: one `output … enable mode … pos … scale … transform … adaptive_sync …` command per rule (`SwayConf.outputCommands`), disabled ones last. No mirroring and no color settings.
- `cycleKeyboardLayout`: `input type:keyboard xkb_switch_layout next|prev`. `exitSession`: `exit`. `dpmsCommand`: `swaymsg 'output * power on|off'`. `leaveSwitcher`: `mode default`.
- `toplevelFor`: null. Quickshell can't capture a toplevel on sway (`ScreencopyView` calls it not captureable), so the overview shows icons.
- `withLayerRects`, `withCursorPos`: null; `warpCursorToLayer`, `scrollStrip`: nothing. `surfacesReady` is true at once.

### The config writer (`SwayConfigWriter`, planned)
Sway gets all three modes ([config modes](config-modes.md)), the text from a pure `SwayConf` helper (`tst_SwayConf`), as Hyprland's comes from `HyprConfigLua`:
- **detached**: `swaymsg` commands at runtime (`runtimeApply`), again after every `configReloaded`, which drops them. `bindsym` on a key the user's config binds would replace that bind: read the user's binds first (`swaymsg -t get_config`, `bindsym` lines) and skip those keys (`skippedKeys`), as Hyprland's runtime layer does.
- **included**: an `include` line (`includeLines`) pointing at a generated file under `$XDG_STATE_HOME/axiom/`. `checkLoaded`: a marker the file sets (e.g. a `set $axiom_included 1`, read back through `get_config`).
- **managed**: axiom writes `~/.config/sway/config`, ending in `include ~/.config/sway/user/*` (`userFiles`); the takeover needs its own `claim_sway.sh` (and guard rules, AGENTS.md › Never).
- **What the layer is in sway's terms:**
  - binds: `bindsym` (`KeyNames` → `Mod4+Shift+1`; mouse buttons with `--whole-window BTN_LEFT`), each action's command from a `SwayBinds` helper sharing `tst_BindActions`' table; IPC actions as `exec qs … ipc call …`
  - the look (`CompositorLayer.look()`): gaps `gaps inner all set <gaps.inner>` / `gaps outer all set <gaps.outer>` (and `gapsOut` to match); borders `client.focused <c> <c> <text> <c> <c>`, `client.unfocused …` from `borders.active`/`.inactive`, plus `default_border pixel <shape.width>`; SwayFX's `corner_radius <shape.radius>` (vanilla sway has none: no `windowShape` unless `swaymsg -t get_version` says SwayFX); SwayFX `blur` for the blur part
  - the input (`CompositorLayer.input()`): `input type:keyboard xkb_layout …`, `repeat_rate`, `repeat_delay`; `input type:pointer accel_profile …`, `pointer_accel`, `left_handed`; `input type:touchpad natural_scroll`, `tap`, `dwt`, `scroll_factor`; `seat seat0 xcursor_theme <theme> <size>`
  - monitors: `output <name or "make model serial"> mode … pos … scale … transform …` (`transform` 0-7 → `normal`/`90`/`180`/`270`/`flipped-*`; `vrr` → `adaptive_sync on`; `bitdepth` → `render_bit_depth`). No `outputProfiles`: `MonitorManager` applies the matching profile on hotplug; in the file modes the profile for what's connected is also written.
- **Turning a live part off**: a runtime command can't be taken back cleanly either; reload (`swaymsg reload`), as Hyprland does.

### `supports` for sway
Now: `monitors`, `windowGeometry`. With the writer: `configModes`, `keybinds`, `inputConfig`, `windowBorders`, `windowGaps`, `scratchpad`, `namedSpecial`, `switcher`, `mouseBinds`; to check, `keyCapture` (a `ShortcutInhibitor` on the recorder) and `bindMerge` (binds parsed from the config). False: `outputProfiles`, `pseudoTile`, `windowGroups`, `monitorColor`, `monitorMirror`, `strips`, `focusGrab`, `layerOrder`, `blur`, `cursorPos`, `cursorWarp`, `workspaceSlide`, `windowShape`, `windowBlur`, `windowOpacity`.

### Open questions (check in the nested session)
- **Click outside.** Without `focusGrab`, a grabbing surface takes the keyboard exclusively and each screen's backdrop window catches the click outside it ([README](README.md) › Focus grab). Typing into the launcher opened by IPC works in nested sway; check by hand that bar popouts with text fields, the launcher, the overlay and the power menu close on an outside click.
- **Layer stacking.** With no `layerOrder`, `LayerManager` maps the stacked surfaces in `LayerStack` order ([layer arrangement](layer-arrangement.md)); checked in nested sway for a solid and a floating-pills bar against the border, and an integrated edge menu.
- **Workspace blocks.** `workspace number N` creates N on the focused output, and the facade focuses the output first. Checked on two nested outputs (`swaymsg create_output`); the perMonitor and grid blocks and a live remap still need a look.
- **Runtime modes.** Sway likely defines `mode` blocks only while reading its config: the switcher's mode would then exist in the file modes only, and detached would step with plain `nop` binds.
- **Focus follows the mouse.** In nested sway the pointer over the nested window refocuses the output under it after a command; read state with that in mind.
- **The greeter** stays a Hyprland session (`issues.md`).
