# Dock

> **Files:** `services/DockManager.qml`, `config/DockConfig.qml`, `shell/Dock.qml`, `components/surfaces/dock/DockWindow.qml`, `components/surfaces/dock/DockMenu.qml`, `components/methods/DockLayout.qml`, `components/views/settings/DockListCard.qml`
> **Config:** `Dock.*` (reader `DockConfig`); entries are `definitions/DockEntry`
> **Related:** [Held off an edge](../popouts/held-off-edge.md), [Edge attach](../popouts/edge-attach.md), [Popout registry](../popouts/registry.md), [Layering and corners](../bar/layering-and-corners.md), [OSD](osd.md)

App docks on screen edges: pinned and running apps, magnification, hover and intellihide, placement against bars and the border, and the settings preview.

### Config
- The `Dock` section, read by `DockConfig`.
- `enabled` is off by default.
- `docks` is `[DockEntry]`.
- Docks are edited on `views/settings/DockListCard`, the section's `x-card`, in its own `Dock` settings category.

### Building (shell/Dock)
- `shell/Dock` builds one `surfaces/dock/DockWindow` per enabled dock, per screen it shows on.
- The screens come from the dock's `monitors`, the same way as an OSD's (`DockConfig.screensOf`, filtered by `ShellManager.showsOn`).
- On "focused" the dock is rebuilt on whichever monitor focus moves to.

### Items (DockManager + methods/DockLayout)
- `itemsFor(dock, screen)` groups `HyprlandManager.windowList` by app.
  - The app key (`appKey`) is `DesktopEntries.heuristicLookup(class)`, else the window class.
- `methods/DockLayout` is pure:
  - **`buildItems`:** pinned items first, then running ones when `showRunning` is on.
  - **`inScope`:** `windowScope` is `all` | `monitor` | `workspace`.
  - **`clickTarget`:** focus the most recent window; cycle through them when one is already focused.
  - **`magnifiedSizes`.**
  - **`covered`.**
- Delegates are keyed by the joined item keys.
- **Pinning from the dock** saves at once through `SettingsManager.commitValues`:
  - right-click `DockMenu`;
  - dragging icons;
  - dragging an icon off the dock unpins it.

### The window
- `DockWindow` is a Top-layer `axiom-dock` strip, as deep as the magnified icons, masked to the box.
- **Layer order:** its layer rule's `order = -7` arranges it after the border and bars, floating and transparent ones included.
  - It sits inside them, and never shortens the bars on other edges.
  - It is blurred.
- **Fullscreen:** a fullscreen window covers it, and its hover trigger is off then.
- **Put away** (`away`):
  - while the overlay is open on its screen, unless the dock reserves its strip;
  - while any popout covers it. Its `PopoutClaim`, a resident, has yielded (see [Popout registry](../popouts/registry.md)).
  - A reserving dock keeps its zone while put away.

### Placement
**Held** (`detached`, the default):
- A plain box, `gap` away from the frame lines on its edge and at its ends.
- Uses `boxOffset` and `startInset` / `endInset`.
- See [Held off an edge](../popouts/held-off-edge.md).

**Attached:** it meets its edge exactly as an `EdgePopout` does (`EdgeAttach`, see [Edge attach](../popouts/edge-attach.md)). That means one of:
- an `AttachedSurface` growing out of the border's or a solid bar's stroke (`edgeMargin` from `attachAt`);
- straight off a bare edge;
- joining a perpendicular stroke at an end;
- standing on, or merged around, a pill bar's pills;
- out of a floating bar's island, stretching the island while it shows;
- a detached box past a transparent bar.

Along the edge:
- its window reaches onto the perpendicular strokes (`strokeInset`);
- the icons sit where they want (`place.contentStart`), and the surface grows around them.

### Visibility
- **`always`:** `reserveSpace` sets its zone.
- **`hover`:** an `EdgeTrigger`.
- **`intellihide`:**
  - Hover, plus shown while no window covers it (`obscured`).
  - What counts as covering: a window on the monitor's workspace, or on its open special workspace (`HyprlandManager.specialWorkspaceId`; monitors are refreshed on `activespecial`).
  - Coverage is computed from the monitor's `reserved`, via `lastIpcObject`.

### Zones and what reaches past it
- A dock reports what it reserves (`setZone` / `zoneOn`, per screen edge).
- Anything that the dock would otherwise push in reaches past it instead:
  - **`EdgePopout`s:** the OSD and floating edge menus, on the dock's own edge and at both ends.
  - **The border's corner pieces** (`RoundedBorders.cornerMargin`).
- **Layer orders that put them over the dock:**
  - The `axiom-edge-popout` layer rule is `order = -10`. It draws floating edge menus over the dock, and over the overlay and the OSD.
  - The OSD's `axiom-osd` (`overNamespace`) is `order = -9`. It draws the OSD over the dock and over the overlay.
- **Retiling:** Hyprland sends no event when windows retile around a changed zone. So `refreshSoon()` re-reads monitors and windows after layer and zone changes. Layer events are only listened to while a dock is built.

### Entry points
- IPC `dock`: `open` / `close` / `toggle <id>`.
  - An empty id means every dock.
  - There is no `show`, because qs's CLI takes that word.
- Bind action `dock`.

### Settings preview
- The settings card's Show button is a preview: `DockManager.preview(entry)`, with the entry as edited, saved or not.
- **Why a second window:** the dock is put away under the overlay that the card sits in. So `shell/Dock` builds a second `DockWindow` with `preview: true`:
  - on the screen the dock would show on (`previewScreen`, `ShellManager.targetFor`);
  - an Overlay-layer `axiom-dock-preview`, whose layer rule is `order = -9`, after the overlay's panel;
  - with no trigger, zone, input or IPC;
  - reaching back past the docks' zones on its edge, to where a dock sits.
- It slides in, holds for 2 s and slides out.
- Meanwhile the dock's own copy there hides its content (`previewing`) and keeps its zone.
- **Exception:** an always-shown dock that reserves its strip is visible beside the overlay, so it isn't slid out. The preview is dropped at once and the dock shows again.
