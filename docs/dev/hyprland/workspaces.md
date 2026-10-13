# Workspaces (layout, navigation, the bar widget)

> **Files:** `config/WorkspacesConfig.qml`, `services/HyprlandManager.qml`, `components/methods/WorkspaceGeometry.qml`, `components/bar/widgets/Workspaces.qml`, `components/bar/widgets/workspaces/`, `components/surfaces/workspaces/`
> **Config:** `Workspaces.*` (`layout`, `count`, `columns`, `rows`, …)
> **Related:** [Workspace strips](workspace-strips.md), [Keybinds](keybinds.md), [Bar composition](../bar/composition.md), [Shared UI pieces](../core/shared-ui-pieces.md)

One workspace layout serves everything that shows workspaces or moves between them:
- the `Workspaces` bar widget, with its `WorkspaceGrid` and `WorkspaceStrips` popouts
- the workspace overview (`surfaces/workspaces/`)
- the `WorkspacesMap` module
- the launcher's `/ws`
- the `workspaces` IPC target.

### Layouts
- `standard`: ids 1..`count`, shared by every monitor.
- `perMonitor`: each monitor gets its own block of `count` ids.
- `grid`: each monitor gets a block of `columns × rows` ids.
- Blocks are numbered in a stable monitor order (`WorkspaceGeometry.orderMonitors`: the primary first, then by output identity). `WorkspacesConfig.baseFor(index)` gives a block's first id.
- Nothing else holds a workspace count or grid size.

### Ids
- `HyprlandManager.workspaceBase(monitor)` / `workspaceIds(monitor)` give a monitor's ids.
- The overview lays them out `boardColumns × boardRows`. In the standard layout it shows windows from every monitor, each placed against its own monitor's origin.

### Navigation
- Everything goes through `HyprlandManager`, so every switch slides the same way:
  - `goToWorkspace(id, mode, monitor)`
  - `stepWorkspace(direction, mode)`
  - `nthWorkspace(n, mode)`
  - `focusWindow`, for focusing a window on another workspace (used by the overview, dock, launcher and notifications).
- Never dispatch `hl.dsp.focus({ workspace })` or `{ window }` directly. (Rule: CLAUDE.md › Services.)
- `mode` is `go`, `move` or `moveSilent`.
- Surfaces on a monitor pass their `monitor`; the focused monitor is the default. In a grid, an id outside that monitor's block is refused.
- **In a grid** a move only reaches the monitor's own ids.
  - It goes sideways first, then vertically, sliding along each axis in turn (`animate`).
  - Each leg of a two-leg trip takes `_legSpeed` of the configured time.
- **The slide** briefly overrides Hyprland's `workspaces` animation, then puts it back. The animation is read with `hyprctl animations` at startup and on config reload.
- Keybinds call `qs -c axiom ipc call workspaces …` rather than scripts of their own.

### Layout changes (remap)
- Hyprland's workspaces stay where they are when the layout or size changes, so `HyprlandManager` remaps them.
  - `_remapWorkspaces` runs 200 ms after `perMonitorBlocks`/`size` change, starting from the layout it last applied.
- `WorkspaceGeometry.remapWorkspaces` (pure, tested) sends each workspace's windows to the same place in its own monitor's new ids.
  - The first monitor in monitor order keeps a contested id; the rest take free ones, merging only when none is free.
  - It picks each monitor's new active workspace.
- One Lua chunk does the move, with the `workspaces` animation off:
  1. windows go to `name:axiom-remap-<id>`, created on their own monitor, so a chain like 10 → 11, 11 → 12 can't merge
  2. every monitor goes to `name:axiom-remap-mon-<i>`, so its old (maybe empty) workspace is gone before its id is reused
  3. windows go to their ids
  4. monitors go to theirs, the focused one last.
- IPC `workspaces reconcile` runs the remap for the current layout, re-homing workspaces left outside their monitor's ids.

### The bar widget
- `bar/widgets/Workspaces.qml` loads a strip by layout:
  - standard: `workspaces/WorkspaceStrip`
  - grid: `workspaces/WorkspaceGridStrip`, showing the active row (or column, on a vertical bar).
- With `wideActive`, both strips make the active `WorkspaceCell` twice as long.
- **Cells.** Both strips lay their cells out with `workspaces/WorkspaceCellRow`.
  - It holds every shown workspace, or one grid row.
  - `glyphOf` gives the grid's position arrow.
- **Active cell.** The active cell's box is one `workspaces/ActiveCellIndicator` sliding along the row.
  - It is drawn between the cells' two parts (`WorkspaceCell`'s `part`): the boxes at rest are under it, the labels and icons over it.
  - A step past an end (`HyprlandManager.workspaceWrapped`, or the strip's own wheel wrap) sends it out of that end and in at the other.
- **Cross-fades.**
  - The grid strip cross-fades (`CrossFade`) to another row or column; the old one keeps its active cell while it fades.
  - `ActiveStrip` cross-fades to the windows of the next workspace.
- **Pinned start.** The widget keeps its start put while its box resizes (`pinStart`, which `BarWidgetHost` reads), so its cells don't drift as the strip after them comes and goes.
- **Options.** The strips share one schema definition. Layout-only options hide themselves with `x-showIf: { "/Workspaces.layout": … }`.
- **Grid popout.** In a grid, the widget hands its `properties` and its bar's config to the `WorkspaceGrid` popout. Its cells are the strip's own `WorkspaceCell`s, with the same:
  - size, spacing and corners
  - widget style and colors
  - labels (grid position) and app icons
  - click to switch.
- On strip monitors the widget also shows the active workspace's windows ([Workspace strips](workspace-strips.md)).
