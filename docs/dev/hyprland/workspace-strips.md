# Workspace strips (Hyprland scrolling layout)

> **Files:** `config/WorkspacesConfig.qml`, `components/methods/HyprLua.qml` (`stripsLua`, `stripsRuntimeLua`), `services/HyprlandManager.qml` (`stripWindows`, `stepStrip`), `components/methods/WorkspaceGeometry.qml`, `components/bar/widgets/workspaces/ActiveStrip.qml`, `components/bar/widgets/workspaces/StripWindows.qml`
> **Config:** `Workspaces.strips`, `Workspaces.stripColumnWidth`, `Workspaces.stripFollowFocus`
> **Related:** [Workspaces](workspaces.md), [Config modes](config-modes.md), [Keybinds](keybinds.md), [Onboarding](../features/onboarding.md)

Monitors on Hyprland's `scrolling` layout: how they're configured, how the Lua reaches Hyprland in each mode, and how the bar, overview and binds follow them. On niri every output is a strip (`supports.stripsAlways`): the strip list is hidden, `stripColumnWidth` is niri's `default-column-width`, and the rest below (order, bar, overview, binds) holds as it does here ([niri backend](../compositor/niri-backend.md)).

### Config
- `strips` lists monitors as `{ monitor, direction }`:
  - `*` means every monitor, and a named entry wins over it
  - an empty monitor means the primary monitor.
- `stripColumnWidth`/`stripFollowFocus` show only while there are strips (`x-showIf` `{ notEmpty: true }`). They are `x-hypr` fields, like `managed`'s, written through `configTable`.
- `WorkspacesConfig.strips` resolves the monitors and keeps each monitor's first entry.
- `stripDirection(screenName)` is `horizontal`, `vertical`, or `""` (tiles).

### Lua (`HyprLua.stripsLua`, the same in every mode)
- A `*` strip makes `scrolling` the layout everywhere, with its `scrolling.direction`: horizontal is `right`, vertical is `down`.
- Each named monitor gets a `hl.workspace_rule` on `m[<name>]` with `layout = "scrolling"` and its direction in `layout_opts`. This wins over the `*` strip.
- **Included / managed:** `M.strips()` runs from `setup()`.
  - It runs after managed's `hl.config`, so it wins over `general.layout`.
  - `general.layout` only offers dwindle and master; scrolling belongs to the strips.
- **Detached:** it runs in the runtime eval, wrapped by `HyprLua.stripsRuntimeLua` to apply once per Hyprland load (workspace rules add up rather than replace).
  - `AXIOM_STRIPS` names the strips applied. It lives in Hyprland's Lua state, so a Hyprland reload resets it and a shell reload keeps it.
  - Different strips can't be taken back, so a change reloads Hyprland's config. Its `configreloaded` then applies the new strips over the user's config alone.

### Window order
- Where the compositor says which column a window is in and its place there (niri: the window's `column` and `tile`), that's the order. Hyprland reports no columns, so there strip order comes from the windows' places (`WorkspaceGeometry.stripOrder`):
  - tiled windows along the strip
  - a column's windows across it
  - floating windows last.
- `CompositorManager.stripWindows(id, vertical)` returns that order.

### Bar
- On a strip monitor, both workspace switchers follow their workspaces (all of them, or the shown grid row) with `workspaces/ActiveStrip`:
  - a divider: a `SeparatorMark` in the bar's `separatorStyle`, or a line when that's none
  - then the active workspace's windows, in strip order.
- The windows are drawn by `workspaces/StripWindows`: bar cells with app icons (sized by the widget's `appIconSize` when set), the last focused one active, and a click focuses.
- **Wheel.** The wheel scrolls the strip a column at a time (`CompositorManager.stepStrip`: `layout("move ±col")`).
  - It acts on the focused monitor only, since layout messages act on the focused workspace.
  - It needs windows on the workspace; Hyprland refuses it on an empty one.
  - Hyprland focuses the column it moves to and warps the cursor there.
- **Popout.** `WorkspaceStrip`'s popout on a strip monitor is `WorkspaceStrips`: each occupied workspace (plus the active one) as its number cell, then its `StripWindows`.
- **One workspace.** With one workspace shown on a strip monitor (a size of 1, or down to the active one without `showEmpty` or with dynamic workspaces), the switchers show the windows alone (`stripOnly`: no number cell, no divider) while the workspace has any. With size 1, or one dynamic workspace, there's no popout. Every compositor.

### Overview
- The overview squeezes a strip workspace's tiled windows into its cell along the strip (`WorkspaceGeometry.stripRects`), so off-screen columns show.
- A tiled window dropped on a strip workspace lands as a new column after the nearest one (`stripDropTarget`). `placeWindow` focuses the target, after which scrolling opens it.

### Binds and onboarding
- The Keybinds page's Strips preset is listed while there are strips. It binds:
  - the `strip*` dispatcher actions: `swapcol`, `colresize ±conf`, `fit visible`
  - `SUPER + mouse_down`/`mouse_up` to focus right/left (`focusDir`), which moves along the strip.
- The onboarder's Workspaces page offers tiling, horizontal strips or vertical strips on every monitor, plus the list for per-monitor strips.
