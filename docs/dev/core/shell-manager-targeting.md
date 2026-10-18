# ShellManager and screen targeting

> **Files:** `services/ShellManager.qml`, `config/General.qml`, `components/reusable/SurfaceGroup.qml`, `components/hosts/overlay/ReservedAreaWindow.qml`
> **Config:** `General.monitors`, `General.primaryMonitor`; each surface's own `monitors` / `monitor` (OSD, overlay, launcher, docks)
> **Related:** [Popout registry](../popouts/registry.md), [Lockscreen](../features/lockscreen.md), [Greeter runtime](../features/greeter-runtime.md), [Polkit](../features/polkit.md), [Screenshots and recording](../features/screenshots-recording.md)

Cross-cutting UI signals (power menu, launcher, overlays) that modules connect to instead of calling each other directly, and which screen answers a shortcut. (Rule: AGENTS.md › UI conventions, "Screen targeting".)

### Monitor modes
- `General.monitors`: `"primary"` | `"focused"` | `"all"`.
- The OSD, overlay and launcher have their own `monitors` setting: `"general"` | `"primary"` | `"focused"` | `"all"`, resolved by `modeFor(mode)`. The power menu uses General's.
- Docks and OSDs also take `"monitor"`: the one their `monitor` names, passed as the `name` argument below.

### Building and targeting
- Surfaces are built on `General.screensFor(mode, name)` (`General.screens` for General's mode).
- Only the instance on `targetFor(mode, name)` answers a shortcut, IPC call or OSD event.
  - Check with `isTarget(screen, mode, name)`.
  - In "focused" and "all" the target is the focused monitor.
- IPC handlers are `enabled` on the target instance only, since a target name can have one handler.

### "all": every monitor at once
- `everywhere(mode)`, `showsOn(screen, mode, name)`.
- A `reusable/SurfaceGroup` per instance opens and closes the others with it (`ShellManager.surfaceShown`).
- Only one focus grab (`HyprlandGrab`) can be active, so only the target's instance holds one, covering every instance's window (`surfaceWindows`).
- The launcher's instances share `LauncherManager.text`.

### Other placement notes
- The workspace overview is built on every screen and opens on the one under the cursor (`CompositorManager.withHoveredScreen`, a cursor position lookup).
- Wallpapers are per monitor (`ThemeManager.wallpaperFor(monitor)`; picked ones are `Appearance.wallpapers[monitor]`, set from the overlay's Themes page); the primary monitor's is also `Appearance.wallpaper`, the fallback for the others. See [Wallpaper and schedules](../theming/wallpaper-and-schedules.md).
- `openModule(types)` opens the overlay page with the biggest module of the first type any page has, else reveals an edge menu with one (false with neither): what a notification click or a service's "show me" uses (Chat, Pomodoro, Stopwatch).
- Which popouts give way to which is PopoutManager's: see [Popout registry](../popouts/registry.md). An integrated edge menu holds no popout claim and takes no part (its exclusive zone pushes the others inwards instead).

### Modal windows
- Every focus grab lets input through to `modalWindows`:
  - the screenshot pickers (`captureWindows`)
  - modal prompts (`registerModal` / `unregisterModal`; the polkit prompt).
- `modalShown`: one of them is up. A grab's `FocusGrab.exclusive` is off meanwhile, so the modal gets the keyboard.

### Stepping aside
- `beginStepAside(owner)` / `endStepAside(owner)` (`steppedAside`) is for a prompt axiom doesn't draw: another polkit agent's window, or a file picker, which opens under the Overlay layer.
- While stepped aside, the overlay and the onboarder (`ReservedAreaWindow`):
  - stay mapped, so their pages and state survive
  - hide their content, take no input or keys (an empty `mask`) and drop their backdrop.
- The overlay's grab is off (and its `cleared` ignored) until the last owner ends it.

### Required fields
- `newSurfaceKey(kind)` / `reportRequiredField(key, present)` / `requiredFields` are the screen layouts' required-field reports.
- The lock screen's Password ([Lockscreen](../features/lockscreen.md)) and the greeter's Login ([Greeter runtime](../features/greeter-runtime.md)).
