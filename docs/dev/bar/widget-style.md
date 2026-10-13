# Bar widget classes, style and colors

> **Files:** `components/bar/widgets/BarIconWidget.qml`, `components/bar/widgets/BarWidget.qml`, `components/bar/widgets/AudioLevelWidget.qml`, `components/reusable/BaseWidget.qml`, `components/methods/BarWidgetStyle.qml`, `components/methods/BarAutoColors.qml`, `config/Bar.qml`, `config/BarStyle.qml`, `components/bar/widgets/workspaces/WorkspaceCell.qml`
> **Config:** `BarStyle.*`, per bar `widgetStyle`, `widgetTextColor`, `overrideWidgetStyle`/`overrideAccents`/`overrideShadow`, `overrideFontSize`/`overrideRadius`, widget color fields with `x-autoColor`
> **Related:** [Bar composition](composition.md), [Widget shapes and runs](widget-shapes-runs.md), [Schema annotations](../core/schema-annotations.md)

The base classes bar widgets extend, where their sizes come from, and how their colors are worked out: widget style, Auto colors, the shared look groups, and the Workspaces cells.

### Widget base classes
- **`bar/widgets/BarIconWidget.qml`** is the base for icon + label widgets.
  - It takes the `BarWidgetHost` inputs `barConfig`/`panel`/`screen`/`properties`, orientation and the configured colors.
  - Override `backgroundColor` for states. `hidden` collapses a widget with nothing to show.
  - It owns their pointer handling:
    - `clickable` + `acceptedButtons` → `clicked(button)`. The widget dims while pressed, and clicking is off while it is hidden.
    - `scrollable` → `scrolled(steps)`.
    - `hovered` is what an edge menu opened by a Button stays open for.
    - `dim` is for fades of the widget's own.
- **`AudioLevelWidget`** is shared by Volume and Microphone.
- **`bar/widgets/BarWidget.qml`** is the base for widgets that draw their own content. It has the same inputs plus `isVertical`.
- **`reusable/BaseWidget`** is the sizing and background wrapper under both.

### Sizes come from the bar
- (Rule: `components/bar/widgets/AGENTS.md`, "Sized by the bar".)
- `Bar.enrichBarConfig` derives `extent` from `widgetSize`, plus padding and whatever covers the bar.
- It resolves `fontSize` and `radius` from the bar's `overrideFontSize`/`overrideRadius`, else from Appearance's values and `Widget.radius`.

### Widget style
- Widgets don't draw their own backgrounds. Each reports two things:
  - `hasBackground`: on by default for `BarIconWidget`, opt-in on `BarWidget`.
  - `accentColor`: its color for its current state, e.g. a critical battery or a muted mic. This used to be the background.
- They draw in `colors` = `Bar.widgetColors(barConfig, accent, foregroundName)`, which gives `{ fill, stroke, indicator, text, icon }`.
  - The pure `methods/BarWidgetStyle` works these out from the bar's `widgetStyle`: filled, tinted, outline, underline, colored icons or plain.
  - `widgetTextColor` overrides the automatic text color.
- Colors that are content rather than a background stay the widget's own: workspace cells, separators, badges, the DND icon.

### Auto colors
- A widget color field with an `x-autoColor` role is Auto when empty, which is its default.
- `Bar.enrichBarConfig` fills Auto fields in the widgets it hands out (`Bar.withAutoColors`; the fields per type are in `Bar.autoColorFields`). Widgets just resolve `properties.X`.
- The pure `methods/BarAutoColors` picks colors along the bar's shown widgets, every section in order. The roles are:
  - **`accent`:** the widget's own color, a base08–0F accent unlike its neighbours'. Fixed colors count as neighbours too. Every accent is used before any repeats, and an accent is kept apart from the widget's own warning/critical colors.
  - **`alt`:** a second state, as unlike its accent as possible.
  - **`warning`/`critical`:** the theme's `warning`/`error`.
  - **`off` and `neutral`:** the subtlest of base01–04 that still stands out. They are for an off state, or for a box whose content has its own colors (the tray's and Workspaces').
- Each color must stand out (WCAG contrast) from what it's seen on: the bar, or a filled merged run's `groupColor`.
  - A fill only has to show (contrast 1.3).
  - Text, strokes and icons have to read (contrast 3).
- Text colors are not Auto. Workspaces' cells are not Auto either, except the active one.

### Look groups (`BarStyle`)
- A bar's widget style, accents and shadow come from the `BarStyle` section (Look & Feel, reader `BarStyle`).
- A bar can override each group separately: `overrideWidgetStyle` / `overrideAccents` / `overrideShadow`. The bar's own copies of the fields show only when its override is on.
- `Bar.lookOf` fills the groups in before `enrichBarConfig`. `Bar.lookGroups` maps each flag to the keys of its `x-group`.
- The section's fields and the bar's copies are kept identical by `tst_Config`'s `test_bar_look_fields_match_bar_style`.

### Workspaces cells
- Workspaces sits on a background like the rest (`backgroundColor`). Its box is Auto (`neutral`).
- Its cells (`workspaces/WorkspaceCell`) are inset by `widgetSpacing` inside that box.
- Cells draw in the same style through `Bar.cellColors` → `BarWidgetStyle.cell`, which gives `{ fill, stroke, indicator, content }` from the cell's state color.
  - **Filled, tinted or outlined** styles draw boxes.
  - **Styles with no box** (underline, colored icons, plain) draw the cell's number or a dot straight on the bar. The dot becomes a pill when wide, with the cells narrowed to fit.
    - For underline, each cell is underlined itself and the widget's own line is off.
    - An empty cell's content is the bar text, faded.
    - Plain tells the states apart by fading alone.
