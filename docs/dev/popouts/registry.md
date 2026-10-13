# Popout registry and collisions

> **Files:** `services/PopoutManager.qml`, `components/hosts/popout/PopoutClaim.qml`, `components/methods/PopoutGeometry.qml`, `tests/tst_PopoutGeometry.qml`, `components/methods/SurfaceOutline.qml`, `components/hosts/popout/LayerOrigin.qml`, `components/bar/BarPanel.qml`
> **Config:** none
> **Related:** [Surface context](surface-context.md), [Hosts and switching](hosts-and-switching.md), [Submenus](submenus.md), [Edge menu hosts](../edge-menus/hosts.md)

`services/PopoutManager` knows every popout that is showing, and where. A popout opening closes only what it overlaps, decided by rank. Read this before adding a popout kind or changing which one wins. (Rule: AGENTS.md › UI conventions, "Popout collisions".)

### Claims
- **Who holds a claim:** every bar popout, edge popout (OSDs, floating edge menus, the attached launcher), dock and submenu holds a `hosts/popout/PopoutClaim`.
- **`key` values:**
  - `bar:<id>`
  - `osd:<id>:<screen>`
  - `menu:<id>`
  - `launcher:<screen>`
  - `dock:<id>:<screen>`
  - `<parent>/submenu`
- **Other fields:** `kind`, `screen`, `edge`, `pinned`, `resident`, `parentKey`.
- **When it registers:** while the popout `wants` to show and has a footprint.
- **Footprint:** the rects it covers, in screen px, with fillets and backfill included (`methods/SurfaceOutline.footprint`). It is offset by where its window is:
  - `LayerOrigin.placed`: Hyprland's report, or until that arrives, an estimate on its edge.
  - A bar popout uses its bar's origin (`BarPanel.screenPlaced`).
- **Location report:** `entries`, visible with `qs ipc call popouts list`.

### Ranks
The rules are pure: `methods/PopoutGeometry`, tested by `tests/tst_PopoutGeometry.qml`. Ranks, lowest first:
1. `pinned`: any pinned popout, of any kind, while it isn't `engaged`.
2. `dock`
3. `osd`
4. `bar`
5. `menu`
6. `launcher`

A submenu ranks as its parent.

**Engaged.** An `EdgePopout` is engaged in these cases:
- **Opening:** from the moment it starts opening.
- **Asked for again while open:** via `EdgeMenuManager.engageRequested`. A keybind or bar Button that toggles a covered menu brings it forward rather than closing it.
- **Grace period:** it stays engaged until a grace period passes without the pointer reaching it.
- **Hovered:** while the pointer is on it, on its hover strip, or on what opened it.

While engaged it ranks as its kind, so it opens over a dock. Once let go it drops back to `pinned` and gives way again.

### Resolving
- **`resolve`:** a claim closes only what its footprint overlaps.
  - **Lower and equal ranks** close; the newer one wins.
  - **A higher rank refuses it** (`refused`): it doesn't open. A refused OSD's poke is dropped.
  - **Exempt pairs:** a popout's own submenu, or its parent, never collides with it.
- **Residents** (docks, pinned menus, a menu previewing from its editor) give way instead of closing:
  - `yielded`: hidden, with its pill drawn back.
  - **Coming back:** once nothing above them covers them they return (`resumable`, highest first).
  - **No ping-pong:** one coming back never evicts another of its rank, so two never take turns.
  - **Unpinned while away:** it closes.
- **Showing only once granted:** a host shows only once granted (`PopoutClaim.held`: granted, or closing after it was). The pill it stands on therefore draws back only after its box has slid away.
- **Same-frame handover:** the evicted popouts start closing in the same frame the new one starts opening.
- **Footprint changes:** if a claim's footprint changes while it shows (a resize, a switch in place), it re-resolves and closes anything below it that it grew over.

### An open popout never moves
- A bar popout keeps the anchor rect it opened at; a widget moving or growing meanwhile doesn't drag it.
- It opens where it belongs the next time.
