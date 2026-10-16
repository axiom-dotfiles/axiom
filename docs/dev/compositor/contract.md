# Backend contract

> **Files:** `services/CompositorManager.qml`, `services/HyprlandManager.qml`, `components/methods/HyprState.qml`, `tests/tst_HyprState.qml`
> **Config:** none
> **Related:** [The compositor](README.md), [Sway backend](sway-backend.md)

What a compositor backend (`HyprlandManager`, and the ones to come) gives `CompositorManager`. `CompositorManager`'s own defaults (empty lists, `""`, no-ops, `null` callbacks) are what a member the backend can't fill looks like.

### Shapes
Plain JS objects, rebuilt as the compositor reports changes. Converters sit in a pure helper with a test (`HyprState.window`, `output`, `workspace`; `tst_HyprState`).

- **Window**: `{ id, appId, initialAppId, title, workspaceId, workspaceName, output, floating, fullscreen, maximized, hidden, focusRank, x, y, w, h }`.
  - `id` is a string, stable while the window lives (Hyprland: its `"0x…"` address).
  - `output` is the output's name.
  - `fullscreen` means real fullscreen. A maximized window is `maximized`; it leaves reserved space alone.
  - `focusRank` 0 is the focused window, higher means used less recently. Undefined when unknown.
  - The geometry is global, in logical pixels.
  - Only mapped windows are listed.
- **Output**: `{ name, description, x, y, width, height, scale, focused, activeWorkspaceId, specialWorkspaceId, reserved: { top, right, bottom, left } }`.
  - `width`/`height` are logical.
  - `activeWorkspaceId` is -1 while unknown.
  - `specialWorkspaceId` is 0 when none is open.
  - `description` is what `MonitorLayout.outputId` keys a stable identity on.
- **Workspace**: `{ id, name, output, windowCount, active, focused }`.
  - `id` is the number axiom's layout uses (`WorkspacesConfig`).
- **Keyboard** (`withKeyboard`): `{ layouts: ["us", "de"], index, keymap }`, or null.
- **Layer rects** (`withLayerRects`): `{ [output]: { w, h, layers: [{ namespace, x, y, w, h }] } }`, or null. Only a check: axiom places its layers itself (`LayerManager`), and logs where this differs.

### Backend members
- **State**: `windows`, `outputs`, `workspaces`, `focusedOutput`, `activeWindowId`, `gapsOut` (`{ top, right, bottom, left }`), `blur` (`{ enabled, size, passes }`), `splitWidthMultiplier`, `surfacesReady`, `supports`, `travelingTo` (the workspace a multi-leg switch has reached, -1 when none is under way).
- **Signals**: `layersChanged`, `outputsHotplugged`, `configReloaded`, `keyboardLayoutChanged`, `windowFocused(appId)`. The facade re-emits them.
- **Windows**: `activateWindow(id)` (focus where it is), `closeWindow(id)`, `placeWindow(…)` and `resizeWindow(…)` (the overview), `toplevelFor(id)` (a `Quickshell.Wayland` toplevel, for previews).
- **Workspaces**:
  - `travel(output, legs, mode, focusId)`: focus `output` first when it's set, go through each `{ id, axis }` leg in turn, and arrive with `mode` (`go` | `move`) or by focusing window `focusId`.
    - A backend that can't slide goes straight to the last leg.
    - The facade only asks for legs with `supports.workspaceSlide`.
  - `sendWindowToWorkspace(id)` (moveSilent)
  - `scrollStrip(direction)`
  - `applyRemap(plan, outputNames)`
  - `refresh()`
- **Session and input**: `withKeyboard(cb)`, `cycleKeyboardLayout(direction, cb)`, `withCursorPos(cb)`, `warpCursorToLayer(…)`, `withLayerRects(cb)`, `exitSession()`, `dpmsCommand(on)` (a shell command, for the idle daemon).
- **Look**: `applyLook({ look, activeColor, inactiveColor, borderWidth, radius })`. Only for backends without `configModes`.

### Capabilities
`supports` keys (absent means false):

| Key | What it gates |
|---|---|
| `configModes` | the Hyprland settings section, `HyprlandConfigManager`, the onboarding's Hyprland and Monitors pages |
| `keybinds` | the Keybinds page (`x-needs`), `KeybindManager` |
| `monitors` | the Monitors page, `MonitorManager` |
| `switcher` | Alt+Tab driven by compositor keys (`WindowSwitcherManager`) |
| `strips` | the strip settings, scrolling a strip |
| `focusGrab` | the native grab in `FocusGrab` |
| `layerOrder` | the compositor stacks and arranges axiom's layers by `LayerStack.layers` itself (layer rules). Without it `LayerManager` maps them in that order and maps again any that land out of place ([layer arrangement](layer-arrangement.md)) |
| `blur` | the compositor blurs axiom's translucent surfaces |
| `cursorPos`, `cursorWarp` | `withCursorPos`, `warpCursorToLayer` |
| `windowGeometry` | window positions and sizes are real: without it the screenshot's window mode is left out (`ScreenshotManager.kinds`; a `window` request takes a region) and no window obscures a dock (`DockManager.obscured`). The overview still draws windows where they say they are |
| `workspaceSlide` | `travel` legs slide |
| `windowBorders`, `windowShape`, `windowGaps`, `windowBlur`, `windowOpacity` | the `WindowLook` parts shown and applied |
