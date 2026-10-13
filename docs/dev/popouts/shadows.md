# Popout shadow and glow

> **Files:** `components/hosts/popout/SurfaceShadow.qml`, `components/hosts/popout/OutsideShadow.qml`, `components/hosts/popout/AttachedSurface.qml`, `components/hosts/popout/SlideAnimation.qml`, `components/methods/SurfaceContext.qml`, `components/bar/BarContainer.qml`
> **Config:** `BarStyle.shadow`, `BarStyle.shadowColor`, `BarStyle.shadowSize`
> **Related:** [Surface context](surface-context.md), [Submenus](submenus.md), [Translucency and blur](../theming/translucency-blur.md), [Blur window and openings](../theming/blur-window-openings.md), [Bar layering and corners](../bar/layering-and-corners.md)

Every surface with an exposed border casts the shell's shadow or glow. It uses the `BarStyle` section's `shadow`/`shadowColor`/`shadowSize`, as the bars and border do. Read this before touching how any popout, dock or submenu casts its shadow. (Rule: AGENTS.md › QML pitfalls, `MultiEffect` and `OutsideShadow`.)

### How it is drawn
- **`hosts/popout/SurfaceShadow`:** a `MultiEffect`.
  - It is kept only outside the surface's shape (`cut`), so none of it shows through a translucent fill.
  - `cut` covers only pixels the surface covers fully. Under the surface's anti-aliased edge the shadow stays; otherwise a pixel's gap shows.
- **While the blur window backs a surface,** the blur window casts the shadow instead. See [Translucency and blur](../theming/translucency-blur.md).
- **Drawn under its target** by `hosts/popout/OutsideShadow`, which captures the target with room for the shadow.
- **`holes`:** the parts OutsideShadow leaves out are:
  - where surfaces joined to the target sit;
  - the bar's open popouts (its stretches);
  - for the border's own shadow window, `ShellManager.borderOpenings`.
    - A joined end's opening carries its `fillet` (`EdgeAttach.joinOpening`).
    - That window leaves it out only as far as its curve, as a bar's `OutsideShadow.fillets` does.
- **Never on the surface's own layer:** never use a `layer.effect` on a visible surface's own layer, or hand that layer directly to a `MultiEffect`. Its padding would redraw that surface in the padded rect.

### Which look it casts
- **Each surface casts what it grows out of casts** (`SurfaceContext.shadow`). This is handed to `AttachedSurface.shadowLook`/`shadowEdge`/`shadowFalls`.
  - So joined shapes land in one `BlurBacking` group, and one shadow runs round them.
- **By what it grows out of:**
  - **Out of a bar** (its pills, islands, a merged box's outer edge, or a solid bar's own stroke with the border off): it takes the bar's look and fall (`SurfaceContext.barShadowFalls`). `BarContainer` casts the bar's own shadow with the same rule:
    - pills joined to the border spread evenly;
    - anything else falls.
  - **Out of the border's stroke:** BarStyle's look, spreading evenly as the border's does. A shadow shifted along a stroke it joins would cover that stroke.
  - **Off a bare edge:** falling.
  - **Free-standing (`detached`):** it falls away from its edge.
  - **A submenu:** casts its parent's look (`host.popupSurface`).
- **A glow always spreads evenly.**

### Who casts it
- **`AttachedSurface.castShadow`:**
  - bar popouts and submenus
  - edge popouts: OSDs, floating edge menus, the attached launcher
  - docks
- **The dock's detached box.**
- **`FloatingPopout`:** a copy of its box sits behind it and casts. This covers the floating launcher and the window switcher.
- **Not a bar's own pills:** their bar's layer casts their shadow.
- **Only the outline casts it,** not the content.

### Room for it
- **Overflow:** `SlideAnimation.overflow` lets the shadow draw past the surface on every side except the one it slides from.
  - That side's clip still hides the surface until it's out.
  - It also keeps the glow off the bar the surface grows from.
- **Window room:** each window keeps its look's reach of room for the shadow (`AttachedSurface.shadowReach`):
  - `BarPopouts.spareAcross`
  - `EdgePopout`'s depth
  - the dock's depth
  - the submenu's `shadowRoom`
- **Submenu boxes:** unbacked, a parent's own shadow also leaves out its submenu's box (`AttachedSurface.shadowHoles`, from `SubPopout`'s `submenuBox`).
