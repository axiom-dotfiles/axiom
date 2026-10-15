# The compositor (detection, the facade, gating)

> **Files:** `services/CompositorManager.qml`, `services/HyprlandManager.qml`, `services/FocusGrab.qml`, `components/methods/HyprState.qml`, `components/methods/SchemaLayout.qml`, `services/SettingsManager.qml`
> **Config:** `WindowLook.*`, `Workspaces.*`
> **Related:** [Backend contract](contract.md), [Sway backend](sway-backend.md), [Hyprland IPC](../hyprland/ipc.md), [Workspaces](../hyprland/workspaces.md), [Schema annotations](../core/schema-annotations.md)

How axiom reaches the compositor it runs under. Read this before anything that reads windows, outputs or workspaces, switches workspace, focuses a window, or does something only one compositor can.

### Detection
- `CompositorManager.kind` is `"hyprland"`, `"sway"`, `"niri"` or `""` (unknown), from `HYPRLAND_INSTANCE_SIGNATURE` / `SWAYSOCK` / `NIRI_SOCKET`.
- `AXIOM_COMPOSITOR` overrides it for testing (`none` gives `""`).
- `CompositorManager.backend` is that compositor's backend singleton (`HyprlandManager`), or null. Only the one picked is created.

### The facade
- **Everything outside the backends goes through `CompositorManager`**: the window, output and workspace lists, focus, workspace switching, the keyboard layout, the cursor, the gaps, the blur, logging out. `check_structure.py` refuses `HyprlandManager.` anywhere else, except in the Hyprland-only features (below).
- The state comes in [neutral shapes](contract.md#shapes): plain snapshots rebuilt on events, the same from every backend. Never hand a compositor's own objects (`lastIpcObject`, `HyprlandMonitor`) past the backend.
- Logic that doesn't depend on the compositor lives in `CompositorManager`, so each backend only has primitives:
  - the workspace layout: `goToWorkspace`, `stepWorkspace`, `nthWorkspace`, `workspaceBase`, `workspaceIds`, `stepStrip`
  - the remap on a layout change (`WorkspaceGeometry.remapWorkspaces`)
  - the `workspaces` IPC target
  - `focusWindow` (switching workspace first), `hasFullscreen`, `stripWindows`, `withHoveredScreen`.
- With no backend everything is empty and does nothing, so an unknown compositor still gets the bar, launcher and notifications. The facade's defaults are what "unsupported" looks like.

### Capabilities
- `CompositorManager.supports` maps each capability to true or false. The keys are listed in [contract.md › Capabilities](contract.md#capabilities). A backend lists what it does; anything it doesn't list is false.
- `AXIOM_COMPOSITOR_OFF=focusGrab,layerOrder` turns capabilities off, so a fallback can be tried on a compositor that has the real thing.
- **Gate a compositor-specific feature on a capability, not on `kind`.** Only code that is Hyprland's by nature checks `kind === "hyprland"` (the greeter's Hyprland session, the onboarding's Hyprland check).

### Hyprland-only features
- These talk to `HyprlandManager` directly (`runLua`, `withOutputs`, `withBinds`, `setCursor`), each gated on its capability:
  - `HyprlandConfigManager` (config modes, the look layer; `live`)
  - `MonitorManager` (`monitors`)
  - `KeybindManager` (`keybinds`)
  - `WindowSwitcherManager` (`switcher`)
  - `GreetdManager`, `OnboardingManager`
- Nothing here may write Hyprland's config unless `supports.configModes` is set: under another compositor, managed mode would otherwise rewrite `~/.config/hypr/hyprland.lua`.

### Hiding what a compositor can't do
- **Settings.** An `x-showIf` key starting with `/$` reads the compositor, not the config ([schema-annotations](../core/schema-annotations.md)):
  - `"/$supports.<capability>": true`
  - `"/$compositor": "sway"`
- A section whose own `x-showIf` fails drops out of its category (`SchemaLayout.categories`): the `Hyprland` section needs `configModes`. The `WindowLook` fields each need their part (`windowBorders`, `windowShape`, `windowGaps`, `windowBlur`, `windowOpacity`).
- **Pages.** A view type's `x-needs` names the capability it needs (Keybinds: `keybinds`, Monitors: `monitors`). `OverlayPages` leaves the page out, and the launcher's `/keybinds` and `/monitors` aren't listed.
- **Onboarding.** The Hyprland and Monitors pages need `configModes`.

### Focus grab
- Surfaces that close on an outside click use `FocusGrab` (`windows`, `active`, `cleared`), never `HyprlandGrab`.
  - With `supports.focusGrab` it loads Hyprland's grab.
  - Otherwise it clears once keyboard focus has left every one of its windows for 100 ms. This only works for windows that take keyboard focus. A popout that closes on an outside click without taking focus needs a click-catcher: [sway-backend](sway-backend.md) › Open questions.

### The window look
- `WindowLook` is compositor-neutral config, edited under Settings › Compositor.
- On Hyprland, `HyprlandConfigManager` evaluates it into its Lua layer ([window-look](../hyprland/window-look.md)).
- A backend without config modes gets it through its `applyLook({ look, activeColor, inactiveColor, borderWidth, radius })`. `CompositorManager` calls that at startup, on a change, and after `configReloaded`.

### Adding a backend
- [Recipe: compositor backend](../../recipes/compositor-backend.md). The first one planned is sway ([sway-backend](sway-backend.md)).
