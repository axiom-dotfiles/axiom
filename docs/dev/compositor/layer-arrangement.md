# How compositors arrange and stack layers

> **Files:** `components/methods/LayerStack.qml`, `tests/tst_LayerStack.qml`, `components/methods/HyprLua.qml`, `components/hosts/popout/LayerOrigin.qml`, `services/BlurManager.qml`
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
