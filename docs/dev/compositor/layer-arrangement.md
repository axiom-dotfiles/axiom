# How compositors arrange and stack layers

> **Files:** `components/methods/LayerStack.qml`, `tests/tst_LayerStack.qml`, `components/methods/LayerArrange.qml`, `tests/tst_LayerArrange.qml`, `services/LayerManager.qml`, `components/hosts/popout/LayerOrigin.qml`, `components/methods/HyprLua.qml`
> **Config:** none
> **Related:** [The compositor](README.md), [Backend contract](contract.md), [Layer stacking](../generated/layers.md), [Bars and the border](../bar/layering-and-corners.md)

What a compositor does with axiom's layer-shell windows: which one reserves its space first, which is drawn on top, and where each one ends up. Axiom works this out for itself, on every compositor, rather than asking Hyprland. Read this before changing how a window reserves space or maps.

### Measured (2026-10-16)
Probed in nested sway and niri: coloured, overlapping layer windows, a screenshot inside the session. Both gave identical results.
- **One sequence per output.** Within a layer, surfaces are arranged and drawn in the order they mapped, across all edges at once. A surface takes the usable area as it is at its turn: a top strip mapped before a left strip spans the full width and owns both top corners. The left strip starts below it.
- **Remapping goes to the end.** Toggling a `PanelWindow`'s `visible` off and on puts it after everything mapped meanwhile, both in arrangement and in drawing.
- **Margins count.** A surface's margin on its anchored edge adds to its exclusive zone. Zone 20 with margin 10 leaves 30 px for the next surface.
- **Exclusive surfaces first.** Every surface with an exclusive zone is arranged before any without one, whatever their map order. Non-exclusive surfaces are placed in what's left; `ExclusionMode.Ignore` surfaces get the whole output.
- **Drawn last is on top.** The surface mapped later is drawn over the earlier one.

### Hyprland
- A layer rule's `order` (`LayerStack.layers`, made into rules by `HyprLua.layerRulesLua`) sorts the surfaces before map order applies. Higher is arranged first *and* drawn first (underneath). That's the same as having mapped earlier, so mapping the surfaces in that order on sway and niri reproduces Hyprland's result.
- Hyprland reads `order` only as a surface maps, so a window whose namespace changes is remade.
- Hyprland also counts what it reserves for itself (`addreserved` on a monitor) and other apps' layers. Axiom's own calculation doesn't see either.

### How axiom places its layers
- Every window whose position matters (bars, border strips, docks, integrated edge menus, edge popouts) has a `hosts/popout/LayerOrigin`. It reports how the window asks to be laid out to `LayerManager`: output, layer, anchors, margins, requested size (0 where it's stretched between two anchors), zone (`Ignore` is -1; `Auto` is its size across the edge), and whether it's mapped.
- `LayerManager` gives each window a map sequence number as it maps (dropped as it unmaps, so a remap goes to the end) and runs `methods/LayerArrange.arrange` over them all. That uses `LayerStack.orderOf` first where the compositor sorts by it (`supports.layerOrder`), then the map order. Windows that reserve nothing and aren't mapped yet are placed too, where they'd go.
- `LayerOrigin.origin` is the window's rect from that; `placed` falls back to an estimate on its edge while there's none.
- **The Hyprland check.** Shortly after the rects change or a layer maps, `LayerManager` compares every mapped window's computed rect with Hyprland's layer list (`withLayerRects`), and logs each one with no match in its namespace: `scripts/log.sh --debug -g LayerManager`. `tests/fixtures/layers/` holds captured setups that `tst_LayerArrange` checks against Hyprland's own result. When a mismatch shows up, capture its input as another fixture and fix `LayerArrange`.

### Mapping in order
- The windows with a fixed place in the stack (bars, border strips and corners, the border's shadow window, docks, integrated edge menus) bind `visible` to a `hosts/popout/LayerSlot`'s `shown` and hand it what used to decide it as `wanted`.
- `LayerManager` runs `LayerStack.sequence` over them. On each output and layer, a window shows once every wanted window ordered before it has mapped (and had 50 ms to be drawn), so they map highest order first. This happens on every compositor, Hyprland included.
- **Without `supports.layerOrder`**, a mapped window that a window ordered before it mapped after is out of place. It's hidden until it has unmapped, then shown again, and so lands after it. That happens, for example, when a bar is remade by a change of kind, which also changes its namespace. Each such remap is logged: `LayerManager: mapping … again, in its place`.
- A window that only maps while open (an integrated edge menu) would put everything after it out of place each time it opens. Such windows are `held`: without `layerOrder` they stay mapped while not wanted, drawing and reserving nothing (`LayerSlot.idle`).
