# Overlay pages and the module grid

> **Files:** `shell/Overlay.qml`, `components/hosts/overlay/OverlayPanel.qml`, `components/hosts/overlay/OverlayPages.qml`, `components/hosts/overlay/OverlayGrid.qml`, `components/hosts/overlay/ModuleGrid.qml`, `components/hosts/overlay/OverlaySlot.qml`, `components/hosts/overlay/OverlayPageNavigator.qml`, `components/views/BaseView.qml`, `components/views/Custom.qml`, `components/methods/GridPlacement.qml`, `config/OverlayConfig.qml`
> **Config:** `Overlay.views`, `Overlay.size`
> **Related:** [Content roots](content-roots.md), [Writing modules](writing-modules.md), [Layouts editor](layouts-editor.md), [Edge menus](../edge-menus/overview.md)

How the overlay turns `Overlay.views` into pages, and a page's modules into a grid of slots: views, the pure grid maths in `GridPlacement`, per-screen card sizing and what is loaded when. Read this before touching a view, the grid or overlay loading.

### Views, modules and places
- `Overlay.views` in the schema drives the overlay's pages, just as `Bars` drives the bar.
- A Custom view is a grid of modules, each with a `place` `{ x, y, w, h }` in **grid units, four to a card** (a quarter card each).
- With `fineGrid` ("Double grid") there are eight units to a card:
  - `Custom.qml` lays the page out at `OverlayConfig.pageUnit`, `GridPlacement.fineUnit`: two of its units and their gap span one card unit exactly.
  - `OverlayManager.fitOf` and the onboarding fit use it too.
  - Toggling it rescales the places (`GridPlacement.scalePlace`), as for edge menus and screen layouts.
- Everything loads by naming convention, so there are no lookup tables.
- Views and modules are `oneOf`s discriminated by `type`, like `BarWidget`.

### View (`OverlayPages` → `OverlayView`)
- `components/views/<type>.qml`, a `BaseView` that receives the screen's `grid` and its `viewConfig`.
- `BaseView` gives hand-built pages their sizes: `pageHeight` (two cards), `cardPageWidth`, `sideWidth`.
- `Custom` (`views/Custom.qml`) is one `ModuleGrid` of its `modules`, with its own `icon` in the navigator (`OverlayConfig.pageIcon`; empty is the type's).
- Tool pages (`x-tool`), hand-built with their pieces in `views/<page>/`: `Settings`, `BarEditor`, `Themes`, `Keybinds`, `Monitors`, `CalendarPage`.
  - `CalendarPage`: the month with its events, the selected day's `DayPane`, and the calendars to switch on and off. It is not named `Calendar`, which `views/Themes`' import of `content/` would see twice.
  - The Themes page is described in [Themes](../theming/themes.md).
- `Layouts` (the layouts editor, `views/layouts/`) is pinned, not in config: see [Layouts editor](layouts-editor.md).
- `ShellManager.showOverlayPage(type)` switches the overlay to a page. `qs -c axiom ipc call overlay page <type or name>` opens it on one.

### Grid maths (`methods/GridPlacement`)
Pure, tested by `tst_GridPlacement`.
- `unitOf(card)`: a unit's size, `(card - 3 × spacing) / 4` (110 px at the reference 500).
- `span(n)`: n units plus the gaps between, so `span(4)` is a card and `span(2)` half of one.
- `bounds(modules)`: how far they reach.
- `canPlace` / `overlaps`: keep modules apart (holes are fine).
- `firstFree(modules, w, h)`: finds a spot in reading order, else beside (or below a wide grid).
- `normalize`: shifts a grid so its top left module sits at 0, 0.
- `trackSizes(bounds, unit, stretch)`: one unit's width and height and the grid's size, growing either axis evenly into `stretch` room (never shrinking).
- `rectPx(place, sizes)`: places a module.
- `fitScale`: how much an overlay's room shrinks a page.
- Edge menu geometry (see [Edge menu hosts](../edge-menus/hosts.md)):
  - `menuLattice` / `latticeOf`: the cells a menu sits on along its edge. As many as fit between the frame's pads, centred there, moved `gridOffset` px.
  - `menuCell` / `alongStart` / `menuAlong`: where its modules start (centred on the lattice, `offset` cells on, kept on it).
  - `offsetFor` / `offsetRange`: the offset for a cell, and those that keep it on the lattice.
  - `unitsAlong`, `menuPlacement` (where they sit on the screen, in px), `menuOnScreen` (its box and modules' rects there), `menuReservedDepth`, `screenBox`.
- The layouts canvas (see [Grid canvas](grid-canvas.md)):
  - `canvasExtent`: the units drawn around the grid, and the `view` fitted (a menu's screen and a unit round it, in fractions, so the screen stays put while modules move on it).
  - `canvasFit`: the view's scale and origin in the area.
  - `canvasRect` / `canvasScreenRect`.
  - `canvasDropPlace`: where a carried module lands, held by the unit it was grabbed by.
  - `edgeBand` / `edgeBar`.

### Host (`hosts/overlay/ModuleGrid`)
- Sizes itself from `grid.sizes(bounds, stretch)`.
- Places one clipped `OverlaySlot` per module (keyed by count), passing `GridPlacement.rectOf(place)` as the module's `slotRect`.
- Warns once for a module that overlaps another.
- Growing modules are laid out here too: see [Growing and expanding](grow-expand.md).

### Module (`OverlaySlot`)
- Loads `content/<type>.qml`, filling its place. Its root is `Card` or `Panel`: see [Content roots](content-roots.md).
- `OverlaySlot` imports `qs.components.content` so that `qs` scans the URL-loaded content; without it, their own `qs.*` imports fail with "not installed".
- Adding a module type: see [Writing modules](writing-modules.md).

### Sizing (per screen)
- The card size is per screen, not a constant.
- Each `OverlayPanel` has an `OverlayGrid` (`hosts/overlay/`) whose `unit` is what fits the page area above the navigator:
  - `min(height / fitCardsHigh, width / fitCardsWide)`
  - capped at the reference `OverlayConfig.cardUnit` (500)
  - times `Overlay.size`%
  - never below `minCardUnit`.
- It reports its room to `OverlayManager.reportArea` (the layouts editor's "fits" line).
- Views receive it as `grid` (`BaseView`) and size everything from `grid.unit` / `grid.span(n)` / `grid.sizes(bounds, stretch)`, passing plain numbers down to content.
- `OverlayConfig.span` without a unit, and `OverlayConfig.gridUnit`, are the reference size.
- A page that still doesn't fit is shrunk as a whole by `OverlayPages.fitScale` (Item.scale, last resort).
- `cardSpacing` / `cardPadding` don't scale.

### Loading
- One overlay per screen in `General.screens` (`shell/Overlay.qml`): a transparent `OverlayPanel` inside the reserved area, placed by its base `ReservedAreaWindow` (shared with the onboarder).
- Under it, `reusable/ScreenBackdrop` dims the whole monitor under the bars and border.
  - A Top-layer surface kept under them by a Hyprland `order` layer rule that `HyprlandManager` adds at startup and on config reload.
  - The workspace overview and launcher use it too.
- Its `HyprlandFocusGrab` also whitelists `ShellManager.grabPartnersFor(screen)`. The bars, bar popouts and submenus register themselves there (`registerGrabPartner(window, screenName)`), so they keep working while it's open.
- Only the current page and its neighbours (navigation wraps) are instantiated, and only while the overlay is open (`OverlayPages.isLoaded` → `OverlayPage.loaded`). (Rule: CLAUDE.md › UI conventions, Overlay lifetime.)
- Page order (`OverlayPages.buildViewsModel`; `viewsModel[i].index` is the view's place in config):
  1. the user's own (Custom) pages, in config order;
  2. the tool pages (view types with `x-tool`: Settings, BarEditor, Themes, Keybinds, Monitors, CalendarPage), in config order;
  3. the pinned Layouts page.
- A view with `visible: false` stays in config but isn't shown.

### Navigator
- `OverlayPageNavigator`, under the pages, shows a tab per page with a sliding accent pill.
- Tabs come from `OverlayPages.pages`: icon, name and `tool` from `OverlayConfig.viewIcon` / `viewLabel` / `isTool`, shared with the layouts editor.
- Tool tabs follow a divider as icons only (named in a tooltip), even when current.
- When all names don't fit, the other tabs drop to icons too.
