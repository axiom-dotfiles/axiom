# Sway backend

> **Files:** `services/SwayManager.qml`, `services/SwayIpcManager.qml`, `services/SwayConfigWriter.qml`, `services/SwayRuntimeLayer.qml`, `services/SwayTakeover.qml`, `services/SwayBindMerge.qml`, `scripts/sway_config_text.py`, `scripts/claim_sway.sh`, `scripts/merge_sway_binds.py`, `components/surfaces/switcher/SwitcherKeys.qml`, `components/methods/SwayState.qml`, `components/methods/SwayConf.qml`, `tests/tst_SwayState.qml`, `tests/tst_SwayConf.qml`, `services/CompositorManager.qml`, `scripts/dev/nested.sh`
> **Config:** `WindowLook.*`, `Input.*`, `Keybinds.binds`, `Monitors.profiles`, `Compositor.mode`, `WindowBehaviour.*`, `Sway.*`, `Session.*`
> **Related:** [The compositor](README.md), [Backend contract](contract.md), [Recipe: compositor backend](../../recipes/compositor-backend.md)

`SwayManager` is `CompositorManager.backend` under sway: the state, workspaces, windows, outputs, keyboard and special groups, and `SwayConfigWriter` for all three config modes (binds, the window look, input; managed also the shared `WindowBehaviour` options, the `Sway` section and the session).

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
  - `moveToSpecial(name)`: marks the focused window `axiom-special-<name>-<id>` (unmarking any other group's, as a window is on one special workspace at a time) and moves it to the scratchpad. A mark's group is everything up to its last `-` (`SwayState.specialGroup`), so `a` and `a-b` are separate groups.
  - `toggleSpecial(name)`: shows the group's windows on the focused output (`scratchpad show`, floating), or hides them all (`move scratchpad`) when any is shown there (`SwayState.specialToggle`).
- `withOutputDetails`: `get_outputs` (`SwayState.outputDetails`; modes as `WxH@R.RRHz`). `applyOutputs`: one `output … enable mode … pos … scale … transform … adaptive_sync …` command per rule (`SwayConf.outputCommands`), disabled ones last. No mirroring and no color settings.
- `cycleKeyboardLayout`: `input type:keyboard xkb_switch_layout next|prev`. `exitSession`: `exit`. `dpmsCommand`: `swaymsg 'output * power on|off'`. `leaveSwitcher`: `mode default`.
- `toplevelFor`: null. Quickshell can't capture a toplevel on sway (`ScreencopyView` calls it not captureable), so the overview shows icons.
- `withLayerRects`, `withCursorPos`: null; `warpCursorToLayer`, `scrollStrip`: nothing. `surfacesReady` is true at once.

### The config writer (`SwayConfigWriter`)
The [config modes](config-modes.md) on sway; the text comes from the pure `SwayConf` (`tst_SwayConf`), as Hyprland's from `HyprConfigLua`.
- **detached** (`SwayRuntimeLayer`): the binds and the live lines sent through `swaymsg` (`SwayManager.runCommands`), again after every `configReloaded`, which drops them.
  - Sway can't list its binds, so the user's are read from their config files: `scripts/sway_config_text.py` prints the config sway runs (the `-c` of the sway `$SWAYSOCK` names, else where sway looks) with its `include`s put in and axiom's own file left out, and `SwayConf.configBinds` reads its `bindsym`/`bindcode` lines (with `$variables` and `mode` blocks) as BindKeys' entries. A key the user binds is skipped (`skippedKeys`).
  - What it bound is kept as the commands unbinding it (`unbindsym …`, a `PersistentProperties`), sent first on the next apply.
- **included**: `$XDG_STATE_HOME/axiom/sway.conf`, which the user's config includes (`includeLines`: `include <path>`). `checkLoaded`: axiom's file (this or the managed config) defines a mode nothing else does (`SwayConf.loadedMode`, `axiom_layer`; `get_binding_modes`). Monitor profiles aren't written: `MonitorManager` applies the one for what's connected at start and on every hotplug (no `outputProfiles`).
- **managed** (`SwayTakeover`, `scripts/claim_sway.sh`, as Hyprland's): axiom writes `~/.config/sway/config` (`$XDG_CONFIG_HOME/sway/`, `Paths.swayPath`) with the module's lines, the `WindowBehaviour` and `Sway` options (`SwayConf.optionLines`, by `x-sway`) and the session, then `include ~/.config/sway/user/*`.
  - The takeover adopts the previous config as `user/00-previous.conf` (a dated backup beside the original), its lines starting axiom or including the module commented out and its relative `include`s made absolute; sway's example config (`/etc/sway/config`) is only backed up. Release puts it back.
  - The adopted file's binds move into axiom (`SwayBindMerge`, `scripts/merge_sway_binds.py`, the same JSON as Hyprland's merge): an action where one does the same (axiom's own IPC calls read back through `BindActions.ipcActions`), `exec`, else `raw` for sway; the moved lines are commented out (`# (moved into axiom)`, backups in `user/.backups/`, which `user/*` doesn't include). A moved bind repeats only where axiom's action does (`BindActions.actionFlags`) or as a raw command without `--no-repeat`: sway's implicit repeat isn't carried over, since the binds are shared with Hyprland.
  - Sway has no `env`: the session's environment (`CompositorLayer.sessionEnv`) goes to axiom's start line (`exec env … qs …`) and `dbus-update-activation-environment`. Apps sway's own binds start don't get it.
  - `exec` lines run once, at sway's start, not on a reload.
  - Like every managed takeover, it waits for the user's approval when the config is theirs ([config modes](config-modes.md) › Approving a takeover).
- **Reading the user's binds** in managed mode: `sway_config_text.py --skip-header` leaves out the managed config's own lines, so only `user/` counts.
- **Binds** (`SwayConf.bindLine`): `bindsym --no-warn [--whole-window] [--locked] [--release] [--no-repeat] Mod4+Shift+q <command>`. A letter is lower case; `code:N` is a `bindcode`; the wheel is `button4`-`7` and mouse buttons `BTN_*`, over the whole window. Sway repeats a held bind unless told, Hyprland doesn't: every bind without `repeating` gets `--no-repeat`.
  - Actions: `focus`/`move <dir>`, `resize grow|shrink width|height N px`, `kill`, `fullscreen toggle`, `floating toggle`, `sticky toggle` (pin), `move position center`, `layout toggle split`, `exit`; IPC actions and apps as `exec`, quoted when sway would split or unquote them. Raw binds written for sway pass through.
  - **Quoting** (`SwayConf.quote`, `bindCommand`; checked against sway 1.12's parser). Sway takes unescaped quotes out and keeps a backslash before one, so a `"` can't be escaped: `quote` puts each run without a `"` in double quotes and each `"` in single ones. A config file keeps a bind's command as written but unescapes it (backslashes doubled). At runtime sway splits the command list at `;`/`,` before `bindsym` sees it (an unquoted `a, b` runs `b` at once) and strips the quotes, so the runtime layer sends any command holding those quoted whole (`bindLine(…, runtime)`). `merge_sway_binds.py` reads a user's command the way sway does (`stored_command`, `exec_text`).
  - `mouseDrag`/`mouseResize` are sway's `floating_modifier <mod> normal|inverse`.
  - Strips, pseudotiling and groups aren't sway's: those binds are left out.
  - axiom's own: the switcher (`nop axiom switcher step ±1`) and special groups (`nop axiom special toggle|move <name>`), which `SwayManager` reads from `binding` events.
- **The look** (`SwayConf.lookLines`): `client.focused|focused_inactive|unfocused` from the border colors (title text black or white, whichever reads), `default_border pixel <width>` (sway has no rounding: no `windowRounding`), `gaps inner|outer`. Sent live, they also apply to what's open (`[all] border pixel`, `gaps … all set`), and `gapsOut` follows the gaps until the next reload (`SwayManager.setLiveGaps`).
- **The input** (`SwayConf.inputLines`): Input's fields by their `x-sway` command ([schema annotations](../core/schema-annotations.md)); `xkb_numlock` only in the file (`x-swayConfigOnly`). The cursor: `seat * xcursor_theme <theme> <size>`.
- **Key capture** (`keyCapture`): `mode "axiom_record"` with one unreachable bind, defined at runtime, and a sleeping `swaymsg` that leaves it after 30 s should the shell die.
- **The switcher**: sway fires a `--release` bind only when no other key came between, so it can't tell the modifier's release after Tab. Without `switcherRelease`, `SwitcherKeys` (an invisible pixel taking the keyboard while the switcher is open) picks on the release, cancels on Escape. A very quick tap may release before it has the keyboard (fine at 20 ms in nested sway).

### `supports` for sway
`configModes`, `keybinds`, `monitors`, `switcher`, `windowGeometry`, `windowBorders`, `windowShape` (the border width), `windowGaps`, `inputConfig`, `keyCapture`, `bindMerge` (the list and conflicts; merging the user's binds in comes with managed), `scratchpad`, `namedSpecial`, `mouseBinds`. Not: `switcherRelease`, `windowRounding`, `outputProfiles`, `pseudoTile`, `windowGroups`, `monitorColor`, `monitorMirror`, `strips`, `focusGrab`, `layerOrder`, `blur`, `cursorPos`, `cursorWarp`, `workspaceSlide`, `windowBlur`, `windowOpacity`.

### Open questions (check in the nested session)
- **Click outside.** Without `focusGrab`, a grabbing surface takes the keyboard exclusively and each screen's backdrop window catches the click outside it ([README](README.md) › Focus grab). Typing into the launcher opened by IPC works in nested sway; check by hand that bar popouts with text fields, the launcher, the overlay and the power menu close on an outside click.
- **Layer stacking.** With no `layerOrder`, `LayerManager` maps the stacked surfaces in `LayerStack` order ([layer arrangement](layer-arrangement.md)); checked in nested sway for a solid and a floating-pills bar against the border, and an integrated edge menu.
- **Workspace blocks.** `workspace number N` creates N on the focused output, and the facade focuses the output first. Checked on two nested outputs (`swaymsg create_output`); the perMonitor and grid blocks and a live remap still need a look.
- **Focus follows the mouse.** In nested sway the pointer over the nested window refocuses the output under it after a command; read state with that in mind.
- **The greeter** stays a Hyprland session (`issues.md`).
