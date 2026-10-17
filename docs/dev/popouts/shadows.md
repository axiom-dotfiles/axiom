# Popout shadow

> **Files:** `components/hosts/popout/SurfaceShadow.qml`, `components/hosts/popout/OutsideShadow.qml`, `components/hosts/popout/AttachedSurface.qml`, `components/hosts/popout/SlideAnimation.qml`, `components/methods/SurfaceContext.qml`, `components/bar/BarContainer.qml`
> **Config:** `BarStyle.shadow`, `BarStyle.shadowColor`, `BarStyle.shadowSize`
> **Related:** [Surface context](surface-context.md), [Submenus](submenus.md), [Translucency and blur](../theming/translucency-blur.md), [Blur window and openings](../theming/blur-window-openings.md), [Bar layering and corners](../bar/layering-and-corners.md)

Every surface with an exposed border casts the shell's shadow. It uses the `BarStyle` section's `shadow` (on or off), `shadowColor` (Auto: the accent) and `shadowSize`, as the bars and border do. It always spreads evenly, so it never slides onto a stroke the surface joins. Read this before touching how any popout, dock or submenu casts its shadow. (Rule: AGENTS.md › QML pitfalls, `MultiEffect` and `OutsideShadow`.)

### How it is drawn
- **`hosts/popout/SurfaceShadow`:** a `MultiEffect`.
  - It is kept only outside the surface's shape (`cut`), so none of it shows through a translucent fill.
  - `cut` covers only pixels the surface covers fully. Under the surface's anti-aliased edge the shadow stays; otherwise a pixel's gap shows.
- **While the blur window backs a surface,** the blur window casts the shadow instead. See [Translucency and blur](../theming/translucency-blur.md).
- **Drawn under its target** by `hosts/popout/OutsideShadow`, which captures the target with room for the shadow.
- **`holes`:** the parts OutsideShadow leaves out are:
  - where surfaces joined to the target sit;
  - for an attached surface, the stroke it grows out of, beside it as well as under it (not on a bare edge). Its window is over that stroke's, so a shadow there dims the stroke. It is darkest under the surface's soft edge, which made a 1px seam where the two strokes meet;
  - the bar's open popouts (its stretches);
  - for the border's own shadow window, `ShellManager.borderOpenings`.
    - A joined end's opening carries its fillet (`startFillet`/`endFillet`, `EdgeAttach.joinOpening`), and a surface's own cover its attach-side fillets at both ends.
    - That window leaves it out only as far as its curve, as a bar's `OutsideShadow.fillets` does.
- **Never on the surface's own layer:** never use a `layer.effect` on a visible surface's own layer, or hand that layer directly to a `MultiEffect`. Its padding would redraw that surface in the padded rect.

### Which look it casts
- **Each surface casts what it grows out of casts** (`SurfaceContext.shadow`). This is handed to `AttachedSurface.shadowLook`.
  - So joined shapes land in one `BlurBacking` group, and one shadow runs round them.
- **By what it grows out of:**
  - **Out of a bar** (its pills, islands, a merged box's outer edge, or a solid bar's own stroke with the border off): the bar's look (a bar may have its own, `Bars[].overrideShadow`).
  - **Out of the border's stroke, off a bare edge, or free-standing (`detached`):** BarStyle's.
  - **A submenu:** casts its parent's look (`host.popupSurface`).

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
  - It also keeps the shadow off the bar the surface grows from.
- **Window room:** each window keeps its look's reach of room for the shadow (`AttachedSurface.shadowReach`):
  - `BarPopouts.spareAcross`
  - `EdgePopout`'s depth
  - the dock's depth
  - the submenu's `shadowRoom`
- **Submenu boxes:** unbacked, a parent's own shadow also leaves out its submenu's box (`AttachedSurface.shadowHoles`, from `SubPopout`'s `submenuBox`).
