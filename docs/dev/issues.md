# Known issues

> **Files:** this file only
> **Config:** none
> **Related:** [Developer docs](README.md), [testing](testing.md)

Problems found while working on something else: not fixed yet, but recorded so they aren't lost. **Add an entry whenever you find a problem outside the task at hand** rather than fixing it unasked or only mentioning it. Remove the entry in the change that fixes it. Before starting work in an area, check here for what's already known about it.

Each entry is a `###` heading plus these four bullets, in this order (`scripts/check_docs.py` checks the shape and that cited paths and members exist):

```
### <Short title>
- **Where:** `path/File.qml` (symbol, or several paths)
- **What:** what's wrong and the evidence (log line, grep count, failing case); quote a log warning's message in backticks so verify.sh marks it known (one from Qt or Quickshell that names no file: quote its category too, `quickshell.I3.ipc`)
- **Size:** trivial | small | needs a plan
- **Found:** YYYY-MM-DD, while <task>
```

## Open

### No niri backend
- **Where:** `services/CompositorManager.qml` (`backend`), `docs/dev/compositor/README.md`
- **What:** Under niri axiom runs with no backend: the bar, launcher and notifications work, but workspaces, windows, the dock's running apps and the keyboard layout are empty. Sway's backend (`docs/dev/compositor/sway-backend.md`) is the one to copy.
- **Size:** needs a plan
- **Found:** 2026-10-16, while decoupling the shell from Hyprland

### Changing a setting under sway can flash the screen
- **Where:** `services/LayerManager.qml` (`_sequence`), `components/hosts/popout/LayerSlot.qml`, `services/MonitorManager.qml`
- **What:** Reported on sway: changing a setting flashes the whole settings page. Two causes fixed: the border's shadow window wasn't held, so turning the shadow on remapped every surface ordered under it (`LayerManager: mapping … again, in its place` for the backdrop, bars, border and dock, the backdrop dimming the overlay flashing with them), and a sway reload (any save rewriting axiom's file) reset the outputs to the config's, dropping the monitor profile. Not reproduced with an ordinary setting since (a save then logs no remap and no overlay resize). Without `layerOrder`, a bar remade by a change of kind still remaps everything after it, by design. If it still happens, note which setting and look for those log lines.
- **Size:** small
- **Found:** 2026-10-16, while auditing the sway branch

### Sway's special workspaces are floating scratchpad windows
- **Where:** `services/SwayManager.qml` (`toggleSpecial`, `moveToSpecial`), `components/methods/SwayState.qml` (`specialToggle`)
- **What:** Hyprland's special workspace is a tiled workspace drawn over the current one; sway has none, so a special group is marked scratchpad windows, and sway's scratchpad makes every window floating, centred and stacked on the others (a group of three shows as three overlapping windows). Options: keep the scratchpad and lay the group's windows out in a grid on show (`move position` / `resize set` per window, over the workspace like Hyprland's), or a hidden named workspace per group (tiles, but replaces the view instead of overlaying it). A group name holding `,` or `;` also breaks its `nop axiom special` bind (sway splits the command there).
- **Size:** needs a plan
- **Found:** 2026-10-16, while auditing the sway branch

### Smart gaps make sway's gaps and reserved space wrong
- **Where:** `components/methods/SwayState.qml` (`output`, `configInfo`), `services/SwayManager.qml` (`gapsOut`)
- **What:** With `Sway.smartGaps` on (`smart_gaps on`), a workspace with one window has no gaps, but `gapsOut` still reports the configured ones, and `output().reserved` (the workspace rect less those gaps) comes out short by them. Bars and edge menus placed from `gapsOut` and the dock's `reserved` are then off by the gap on such a workspace. Needs per-workspace gaps (whether the active workspace has one tiled window).
- **Size:** small
- **Found:** 2026-10-16, while auditing the sway branch

### Overview drops on sway nest split containers
- **Where:** `services/SwayManager.qml` (`placeWindow`)
- **What:** A drop next to a window runs `split h|v` on the target every time, which wraps it in a new container even when its parent already splits that way, so repeated drops nest containers sway then draws as such (tabbed/stacked parents behave oddly). Split only when the parent's layout differs (the tree has it).
- **Size:** small
- **Found:** 2026-10-16, while auditing the sway branch

### Detached sway keeps the floating modifier after the mouse binds go
- **Where:** `services/SwayRuntimeLayer.qml`, `components/methods/SwayConf.qml` (`unbindLines`, `floatingModifier`)
- **What:** The runtime layer sends `floating_modifier` for the drag/resize binds but its unbind commands don't take it back, so removing them in detached mode leaves sway's floating modifier set until sway reloads. It also overrides a `floating_modifier` of the user's own config, which `BindKeys.runtimeBinds` doesn't see as a taken key.
- **Size:** small
- **Found:** 2026-10-16, while auditing the sway branch

### `noWarps` off maps to sway's `mouse_warping output`
- **Where:** `config/json/config.schema.json` (`WindowBehaviour.noWarps`, `x-swayMap`)
- **What:** Hyprland with `cursor.no_warps` off moves the cursor to a window focused by keybind; sway's `mouse_warping output` only moves it when focus changes output (`container` would match Hyprland). Decide which sway value matches what the setting promises.
- **Size:** trivial
- **Found:** 2026-10-16, while auditing the sway branch

### Quickshell's I3 socket warns on every reload
- **Where:** `services/SwayManager.qml` (Quickshell.I3)
- **What:** Under sway every reload of the shell logs `I3 event socket disconnected` twice (category `quickshell.I3.ipc`), from the old generation's sockets closing. Events still arrive afterwards (checked in nested sway). Quickshell's, not axiom's; nothing to fix here unless it starts dropping events.
- **Size:** trivial
- **Found:** 2026-10-16, while writing the sway backend

### Qt text-input warnings under sway
- **Where:** `components/reusable/StyledTextEntry.qml` (the text fields; Qt's own wayland text-input)
- **What:** Under sway the log fills with `Trying to disable` / `Trying to enable` warnings from `qt.qpa.wayland.textinput` (`QWaylandTextInputv3::disableSurface`) as keyboard focus moves between axiom's surfaces. Seen live on sway, never under Hyprland; typing still works. Likely Qt's text-input-v3 handling with several layer surfaces taking focus.
- **Size:** small
- **Found:** 2026-10-16, while consolidating compositor settings

### Floating bars sit flush on the border without a backend
- **Where:** `config/Bar.qml` (`enrichBarConfig`: `floatGap`), `services/CompositorManager.qml` (`gapsOut`)
- **What:** A floating bar's automatic gap (`floatGap` -1) is the compositor's outer gaps (`CompositorManager.gapsOut`). With no backend (niri today) `gapsOut` is all 0, so a floating bar sits flush against the border. Sway's backend reads its gaps from the config (`SwayState.configInfo`); decide what the gap is with no backend at all (a fixed default, or `Appearance.screenMargin`).
- **Size:** small
- **Found:** 2026-10-16, while testing layer order in nested sway

### Blur behind axiom on niri
- **Where:** `services/CompositorManager.qml` (`supports`), `components/methods/LayerStack.qml` (`blurSurfaces`)
- **What:** Axiom's surfaces blur where the compositor blurs its layers (`supports.blur`: Hyprland's layer rules, SwayFX's `layer_effects`); elsewhere they're solid (`Appearance.compositorBlurs`) and the translucency setting is greyed out. niri can blur layers by namespace too (layer rules); a niri backend would need the same per-namespace rules from `LayerStack`'s lists. Unchecked on SwayFX: whether its `blur_ignore_transparent` really blurs halos (axiom then drops the chrome's shadows, no `blurThreshold`), and how unblurred layer popups (tooltips) look.
- **Size:** needs a plan
- **Found:** 2026-10-16, while placing layers without Hyprland
### The greeter runs its own Hyprland session
- **Where:** `scripts/greeter/greeter-session.sh`, `services/GreetdManager.qml` (`_applyHyprland`)
- **What:** The greeter runs its own Hyprland session (`start-hyprland`, `hyprctl dispatch exit`), whatever compositor the user's session uses. Decide whether it keeps Hyprland or moves to cage/sway. (The onboarding's binds table and Welcome copy no longer assume Hyprland.)
- **Size:** small
- **Found:** 2026-10-16, while decoupling the shell from Hyprland

### Two exclusive-focus surfaces at once without a native grab
- **Where:** `services/FocusGrab.qml` (`exclusive`), `components/hosts/overlay/OverlayPanel.qml`, `components/hosts/popout/BarPopouts.qml`, `components/hosts/popout/EdgePopout.qml`
- **What:** Without `supports.focusGrab`, every active grab's surface asks for `WlrKeyboardFocus.Exclusive`. With the overlay open (exclusive the whole time) and a popout with a text field opened over it, two surfaces on the Overlay layer ask for exclusive focus. Which one gets the keyboard is up to the compositor and wasn't checked in nested sway or niri: typing into a popout over the overlay may go to the overlay. Not seen yet; check it in `scripts/dev/nested.sh sway`.
- **Size:** small
- **Found:** 2026-10-16, while auditing the layer-placement branch

### Missing app icons warn in the log
- **Where:** `services/LauncherManager.qml` (`Quickshell.iconPath`), `services/DockManager.qml`
- **What:** An app whose `.desktop` icon isn't in the icon theme (here `xdg-desktop-portal-gtk`'s `applications-system-symbolic`) logs `Could not load icon` at each size it's drawn, though the fallback icon shows. Noise in `scripts/log.sh`; either skip hidden/`NoDisplay` entries or resolve the name before handing it to an Image.
- **Size:** trivial
- **Found:** 2026-10-16, while auditing the layer-placement branch

### The python venv and bytecode are written into the repo
- **Where:** `scripts/setup_venv.sh`, `scripts/venv_python.sh`
- **What:** The venv for `generate_theme.py`/`calendar_sync.py` is made at `<repo>/.venv`, and python leaves `__pycache__/` in `scripts/`. A packaged (read-only) install can't do either. Put the venv in `$XDG_DATA_HOME/axiom/venv` (or use the system python when the requirements already import), and set `PYTHONDONTWRITEBYTECODE=1`. Blocks packaging, not the XDG move.
- **Size:** small
- **Found:** 2026-10-15, while moving config and state to the XDG folders

### Hyprland starts axiom by its repo path, and self-update assumes git
- **Where:** `services/HyprlandConfigWriter.qml` (`shellCommand`), `services/SelfUpdateManager.qml`, `scripts/greeter/greeter_install.sh`
- **What:** `shellCommand` is `qs -p '<repo>'`, which a package would want as `qs -c axiom` or an `axiom` launcher. Self-update and the greeter installer work on `Paths.axiomPath` as a git clone. A package manager owns updates, so these should hide or switch when there is no `.git`. Blocks packaging, not the XDG move.
- **Size:** needs a plan
- **Found:** 2026-10-15, while moving config and state to the XDG folders

### Old config/state folders are kept in the repo after the XDG move
- **Where:** `services/DataMigrationManager.qml`, `components/methods/DataDirs.qml` (`legacy`)
- **What:** After moving an install over, `config/user/`, `config/state/` and `config/themes/generated/` are left in place (with `MOVED.md`) so a rollback still finds them. Once rolling back past the move is no longer supported, delete them (or offer to), and drop the legacy layout code.
- **Size:** small
- **Found:** 2026-10-15, while moving config and state to the XDG folders

### Disk usage shifts onto the wrong path when one is missing
- **Where:** `services/SystemManager.qml` (`_df`)
- **What:** `df` is run once for every requested path and its output lines are matched to the paths by position. A path that doesn't exist (a `diskPath` typed wrong, an unmounted drive) gets no line, only an error on stderr, so every path after it shows the next path's usage and the last one shows none. Run `df` per path, or add `--output=target` and match lines to paths by that.
- **Size:** small
- **Found:** 2026-10-15, while auditing the folder picker commit

### Text input warnings when the desktop takes the keyboard
- **Where:** `components/surfaces/desktop/DesktopWindow.qml` (`WlrLayershell.keyboardFocus`)
- **What:** With a typing module (Notes) on the desktop, clicking into it and back to windows logs bursts of `Trying to disable` from `qt.qpa.wayland.textinput` (`QWaylandTextInputv3::disableSurface`; 174 in one session). Typing and handing focus back work. Likely Qt's text-input-v3 noise when focus moves between surfaces; not yet checked whether an edge menu's Notes logs the same.
- **Size:** small
- **Found:** 2026-10-14, while letting typing modules go on the desktop

### `CornerMerge.opening` reads a missing container
- **Where:** `components/bar/CornerMerge.qml` (`_placed`, `opening`)
- **What:** Reloads log `TypeError: Cannot read property 'length' of null` at the `opening` binding. `_placed` checks `container !== null`, but `container` (`bar.pillBarStart`/`pillBarEnd`) can be unset or not yet laid out, and `opening` then reads `root.container.length`. Guard `_placed` with `!!root.container` (and check the end reach doesn't flash while it's missing).
- **Size:** trivial
- **Found:** 2026-10-14, while fixing pill-bar joins for popouts reaching a corner

### `Bar` reader holds the edges enum and breaks reader naming
- **Where:** `config/Bar.qml` (`enum Location`, the `Bars` reader)
- **What:** The `Bars` section's reader is named `Bar` (other readers are named for their section, with a `Config` suffix where needed), and the same file declares the `Location` edge enum (`Bar.Top`, `Bar.Left`, …) that docks, OSDs, popouts and edge menus use. About 302 `Bar.` references in 57 files, 204 of them the enum. Plan: move the enum to a new `Edge` singleton in config/ (`Edge.Top`), then rename the reader (e.g. `BarsConfig`). `gen_docs.py` needs no change; add the old names to `RETIRED` in `scripts/check_docs.py`, and force a reload afterwards (testing.md › Reloads and logs).
- **Size:** needs a plan
- **Found:** 2026-10-13, while assessing reader renames for the docs makeover

### `BlurManager.paused` warns on every reload
- **Where:** `services/BlurManager.qml` (`paused`), `services/UpdatesManager.qml` (`checking`), `services/SelfUpdateManager.qml`, `services/HyprlandManager.qml` (`activeWindowId`)
- **What:** Every config reload logs `Unable to assign [undefined] to bool` at the `paused` declaration (and, seen 2026-10-14, at `UpdatesManager.checking`, also a readonly bool on a singleton: likely the same cause; seen 2026-10-16 as `Unable to assign [undefined] to QString` at `HyprlandManager.activeWindowId`, a readonly string). The binding itself evaluates to a boolean (a temporary probe logged `boolean false`), and a constant `paused: false` still warned, so it isn't the expression: something in Quickshell's reload of this singleton assigns it. Harmless (the value is right afterwards), but it's noise in every `scripts/log.sh`. Next step: check whether Quickshell carries readonly properties across a reload, or whether making `paused` a plain function helps.
- **Size:** small
- **Found:** 2026-10-13, while checking reload logs during the docs makeover

### Binding loops in bar popout placement
- **Where:** `components/hosts/popout/EdgePlacement.qml`, `components/hosts/popout/PillBarJoin.qml`, `components/hosts/popout/BarPopouts.qml`, `components/hosts/popout/AttachedSurface.qml`, `components/hosts/popout/SubPopout.qml`
- **What:** Opening bar popouts on a floating-pills bar logs binding loops, dozens per session: `property "_wall"` (PillBarJoin, created at EdgePlacement.qml:345), `property "joinReach"` (EdgePlacement), `property "surfaceX"` / `property "surfaceY"` (BarPopouts' window), `property "_spec"` (AttachedSurface) and `property "place"` / `property "alignedBoxStart"` (SubPopout). They're in every qs instance's log back to 2026-10-13, before the corner-priority change. The values settle (no visible glitch reported), but a loop can leave a stale value for a frame and buries real warnings. Likely one cycle: the placement reads the pill's join reach, which reads the placement's wall. (`_surfaceFromEdge`'s loop is gone: it now comes from the layout's `attachAt`, not the drawn surface.) Not reproduced on 2026-10-16 (popouts from a floating-pills bar, and one joining a perpendicular pill bar, on Hyprland and in nested sway): it may have gone with later placement changes. Delete this entry if it doesn't come back.
- **Size:** needs a plan
- **Found:** 2026-10-14, while reviewing verify.sh output for the agent-setup changes

### Schema root `description` duplicates the annotation docs
- **Where:** `config/json/config.schema.json` (root `description`)
- **What:** A 3 KB description restates the `x-*` annotations and is already incomplete (no `x-control`, `x-hypr*` or `x-scope`). The complete list is `docs/dev/core/schema-annotations.md`. Trim it to one line pointing there.
- **Size:** trivial
- **Found:** 2026-10-13, while splitting architecture.md

### `Compositor.requiredSettings` has no developer doc
- **Where:** `config/HyprlandConfig.qml` (`requiredSettings`), `docs/dev/hyprland/config-modes.md`
- **What:** It's in the schema and the generated reference (`docs/dev/config/Hyprland.md`), but no hand-written doc explains what it does. Add a section to `config-modes.md`. (`wallpaperDaemon` moved to `Appearance.wallpaperDaemon`, covered in `wallpaper-and-schedules.md`.)
- **Size:** trivial
- **Found:** 2026-10-13, while splitting architecture.md
