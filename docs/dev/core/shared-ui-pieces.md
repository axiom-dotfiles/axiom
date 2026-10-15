# Shared UI pieces

> **Files:** `components/reusable/`, `components/forms/`, `components/content/parts/`, `components/methods/Utils.qml`, `components/methods/Search.qml`, `components/views/settings/FoldingCard.qml`, `components/views/settings/EntryListCard.qml`, `components/views/settings/ScreenSpotPicker.qml`
> **Config:** none
> **Related:** [Editors pattern](editors-pattern.md), [Content roots](../overlay/content-roots.md), [Writing modules](../overlay/writing-modules.md), [Popout surface context](../popouts/surface-context.md), [Translucency and blur](../theming/translucency-blur.md)

An index of reusable pieces. Reach for one of these before drawing your own; when a pattern appears a second time, it becomes one of these. (Rule: AGENTS.md › UI conventions, "Reuse before building".) Every file in `reusable/`, `forms/` and `content/parts/` is named here or in the docs it links to (`scripts/check_docs.py` checks): add a line when you add a piece.

### Text and structure (`reusable/`)
- `StyledText` / `StyledIcon`.
- `SectionHeading`: accent title + muted description.
- `FieldGroup`: a titled card of fields; `headerExtras` beside the heading.
- `StyledContainer`: a themed box (surface opacity or solid, optional border and radius).
- `StyledScrollView`: a ScrollView with the shell's padding and a thin accent scroll bar.
- `KeyHint`: a keycap and what it does (`[↵] open`), for a controls hint.
- `StyledSeparator`: border-coloured divider (accent where a divider is accent by design).
- `StatusChip` (filled status pill), `CountBadge` (a count on a button's or icon's corner; bumps when it changes), `UnsavedDot` (`onAccent` on a selected row).
  - All three are `PopInRectangle`s: set `shown` (not `visible`) and they pop in and out; `pulse()` for a bump.
- `IssueList`: `[{ level, text }]`, errors red, warnings amber.
- `DropdownSurface`: the box of anything that drops down.
- `TileFlow`: equal tiles, as many columns as fit.
- `TypeLibrary`: the editors' libraries of types to add.
  - An A–Z / By category switch over equal tiles of a caller's `delegate`, by label or under a heading per group (`methods/LibraryOrder`).
  - The label and heading come from the caller's `labelOf` / `headingOf` hooks (the editors translate the schema's).
  - The caller keeps `grouped`.
- `KeyedLoader`: rebuilds a form when `key` changes, so rows never write old values onto a new selection.

### Controls (`reusable/`)
- `StyledTextButton`, `StyledIconButton`, `SquareIconButton`, `FlatIconButton`, `StyledRectButton` (icon, hover and press colors, optional `CountBadge`).
- `StyledToolTip`: a hover tooltip in a popup window of its own, so the small layer windows buttons live in don't clip it. Buttons take `tooltipText`.
- `StyledSlider`: trough, fill and handle; `moved` while dragged, `released` at the end; a value pushed in animates.
- `StyledVolumeBar`: a volume bar with its icon, mute and optional percentage (drag, click or scroll); `PipewireVolumeBar` binds one to a Pipewire stream or the system volume (the OSD's).
- `PercentageCircle`: a ring gauge with an icon in the middle.
- `SegmentButton`: a choice, accent when `active`; `Layout.fillWidth: false` in a row of pills.
- `SegmentRow`: a single choice of SegmentButtons on one track, the accent sliding to the active one. Toggles and multi-select chips stay plain rows or Flows.
- `StyledTabBar` (of `StyledTabButton`s): its current tab's highlight slides between tabs.
- `StyledTextEntry`: see the AGENTS.md pitfall (push the value in, act on `textEdited`). `StyledTextArea`: multi-line, optionally growing with its text.
- `PasswordEntry`: a password field with a message, a busy bar and `shake()`.
  - It has no authenticator of its own: the lock screen's `PasswordField`, the greeter's `LoginField` and the polkit prompt wire it.
- `StyledComboEntry`: a choice from a list dropping down under a field, optionally typed.
  - `options` `[{ value, label, icon? }]`, `value` pushed in, `picked(value)`.
  - Used by the greeter's user and session pickers.
- `CodeLine`: text to paste (a command) in a monospace box with Copy.
- `StyledSwitch`.
- `TypePickerPopup`: pick a type, `{ type, label, icon }`.
- `ActionTile`: an icon well over a label. With `opens`, a right click or long press is `opened`.
- `ActionPill`: the wide one, a well beside a name and status. With `opens`, the well toggles and the rest opens.

### Editor lists and drags (`reusable/`)
- `ListEntryRow` (+ `RowAction`, `AddEntryButton`).
- `DragArea`: drag vs tap; with `dragLayer` + `payload` it carries.
- `DragLayer`: one drag, a target registry, and a hit test.
  - `accepts` / `priority` hooks; `priority` defaults to a target's `dropPriority`.
  - Signals: `started` / `moved` / `dropped`.
- `TrashTarget`: a "Drop to remove" pill shown while `active`, `targetKind: "trash"`, above overlapping targets. The layer's `accepts` says what it takes and its `dropped` removes it.
- `DragChip`: a carryable icon + name pill.
- `views/layouts/EntryListTarget`: a list of rows that reorders its own carried rows.
- `InspectorHeader`: icon well, name, place, actions, divider.
- `content/base/SaveResetActions`: an editor's Save/Reset pair. `compact` drops to icons, as `CardHeader` does when its row is too narrow. Items placed in a `CardHeader` sit just after its title.

### Forms (`forms/`)
- `SchemaField`: one schema row, any type. It picks `SchemaSwitch`, `SchemaNumberField` (slider or stepper), `SchemaComboBox`, `SchemaTextField` (commits on Enter, focus loss or a suggestion; a Browse button with `x-control: "folder"`) or `SchemaObjectArray` (a list of `SchemaArrayItem`s): use `SchemaField`, not those, unless you need one alone.
- `SchemaPropertiesForm`: a flat object; `order`.
- `SettingRows`: dotted config paths as rows, saved debounced.
- `OptionsGroup`: an inspector's Options card (problem, form, empty text).
- `IntegrationHookup`: a theme integration's hookup (text to copy, what Apply does, Apply).
- `GreeterSetup`: setting up the login screen (what Install changes, Install/Update/Remove, the commands left to run). Used by Settings' `GreeterStatusCard` and the onboarder.

### Bar pieces (`bar/`)
- `BaseWidget`: the rounded box a bar widget sits in; `IconTextWidget`: an icon and a label along the bar's axis (rotated on a vertical bar).
- `WidgetBackground`: a widget's or merged run's background in the bar's widget style and shape, with the hover outline and editor highlight.
- `SeparatorMark`: a line, dot, slash or chevron divider (the Separator widget's and the bar's `separatorStyle`).
- `methods/BarShapes` (caps and SVG outlines), `methods/BarWidgetStyle` (colors per widget style), `methods/BarAutoColors` (Auto widget colors).

### Workspace pieces
- **Active workspace** (`bar/widgets/workspaces/ActiveCellIndicator`): the active cell's box or underline (`CellUnderline`, shared with `WorkspaceCell`), drawn once under a switcher's row of cells and sliding between them.
  - Lives in `WorkspaceCellRow`; cells it stands in for set `indicated`.
  - Dots-only bars keep the cells' own recolour.
- **Strip windows** (`bar/widgets/workspaces/StripWindows`): a workspace's windows in strip order as bar `WorkspaceCell`s (app icons, the last focused active, click focuses). Used by `ActiveStrip` (both switchers) and the `WorkspaceStrips` popout.
- **Window previews** (`surfaces/workspaces/WindowPreview`): a Hyprland client's capture, rounded.
  - Shows the app icon until it gives a frame.
  - One frame per open unless `live` (or `hovered` / `resizing`).
  - Used by the overview's windows and the switcher's tiles.

### Motion (`reusable/`)
- `Glide` / `ColorGlide` (`Glide on width {}`): a Behavior with the shell's animation, animFast eased by `Appearance.easing`.
  - `duration` for animNormal/animSlow; `enabled` to gate it.
  - A Behavior with another easing or animation is written out.
- `CrossFade`: `value` shown through a `delegate` with `required property var value`; a new copy fades in over the old on change.
  - A copy with `ready` false (an image loading) waits. Used by the cover and track text, weather and OSD icons.
- Everything else animates with Behaviors on `Appearance.animFast` / `animNormal` / `animSlow` and `Appearance.easing`.
  - Gate it with a `_settled` / `_placed` flag (`Qt.callLater` from `Component.onCompleted`) where a first layout would otherwise fly in from 0.
- (Rule: AGENTS.md › Config, "Animation".)

### Small helpers
- **Last found** (`reusable/LastFound`): the last non-null `source`, for an entry looked up by id whose delegates must never be handed null as it's removed (`shell/Dock`, `shell/OSD`).
- **Frame nudge** (`reusable/FrameNudge`): `burst()` makes its window draw and commit a few more frames. For where Hyprland keeps showing a layer's frame from before a change (a bar's stretches, the blur window's shapes).
- **Backdrop** (`reusable/ScreenBackdrop`): a full-screen surface's dim background (overlay, overview, launcher), under the bars and the border.
- **Surface group** (`reusable/SurfaceGroup`): keeps a surface's instances on every monitor in step when its `monitors` mode is `all`.
- **Folding** (`reusable/FoldingColumn`): a column whose height animates open and shut on `open` (not when built), clipped, its content fading with it, with paddings that fold too. `shown` stays true until fully shut, so content can be held until then.

### Blur and joins
- `reusable/CornerPiece`: a concave "inverted corner" filled up to a quarter circle, with its two edges stroked.
- `reusable/HoledItem`: its children with rects cut out (a stroke left open where something joined to it carries on).
- `hosts/popout/BlurShape` + `LayerOrigin`: a chrome surface's shape for the blur window, and where its layer window is on screen.
- See [Translucency and blur](../theming/translucency-blur.md).

### Popouts
- `methods/SurfaceContext`: what a surface growing out of an edge meets at each end, and every rule that follows (joins, walls, room, detached, shadow, openings). See [Surface context](../popouts/surface-context.md).
- `hosts/popout/EdgePlacement`: all of it for a surface on a screen edge (bar popouts, edge popouts, docks).
- `hosts/popout/EdgeSurface`: an `AttachedSurface` wired from an `EdgePlacement`. A host sets only where it is, its box, `active`, colours and content.
- `hosts/popout/SubmenuHost`: a host's submenu and what it shares with it. The host sets `submenuHost`; `PopoutWrapperBase` gives it `submenu`, `openToLeft` and `childOpen`.
- `hosts/popout/ClosedLatch`: a value followed only while its host is closed (a window's layer or namespace).
- `hosts/popout/StrokeOpening`: a stroke a surface covers, left open by whatever draws it.
- `hosts/popout/SubmenuSide`: what a submenu meets on its parent's side.
- `methods/SurfaceOutline`: the shape of anything growing out of an edge (metrics, fill and stroke paths, footprint); `AttachedSurface` draws from it.
- `hosts/popout/PopoutClaim`: a host's place among the popouts; what it overlaps closes, what's above refuses it. See [Popout registry](../popouts/registry.md).
- `hosts/popout/SubPopout`: a popout's submenu.
- `PopoutAnchor`: opens one from anything in a bar or popout; `openOnHover: false` leaves opening to its owner's click.
- `content/Submenu`: a module opening another edge menu as a submenu.

### Settings cards (`views/settings/`)
- `FoldingCard`: fold header + a `FoldingColumn` body.
- `SettingsGroupCard`: generated.
- `EntryListCard`: a list of entries as tabs with a screen picker.
- `ScreenSpotPicker`: a small screen with a spot and preset dots to click; `edgeSpot(edge, along, across)`. Used by docks, OSDs, and the launcher's `LauncherPlace` intro.
- See [Settings page](settings-page.md).

### Content and calendar parts
- **Content parts** (`content/parts/`): see [Content roots](../overlay/content-roots.md) and [Writing modules](../overlay/writing-modules.md). Also `AudioRow` (a mixer line: icon, title, volume slider, percentage, mute) and `TrayMenuList` / `TrayMenuItem` (a tray menu's entries, for the tray popout and its submenus).
- **Calendar parts** (`content/parts/calendar/`): see [Calendar](../features/calendar.md).

### Pure helpers (`methods/`)
- **Search** (`methods/Search`): shared by LauncherManager and EmojiManager.
  - `score(text, q)`: the launcher's 0–100 fuzzy match.
  - `frecency(useRecord, now)`.
  - `looksLikeMath(text)`.
- `methods/ColorTemperature.color(kelvin)`: light's color at a temperature (the night light's button).
- `KeybindFilter.columns(sections, count)`: the masonry split of the Keybinds page and the Cheatsheet module.
- **Utils** (`methods/Utils`):
  - `clone`, `freeId(base, taken, sep)` (`dock2` → `dock3`)
  - `spaceWords` (CamelCase → words), `edgeArrow(edge)`
  - `formatRate` / `rateParts` / `formatSize`, `formatBytes` (a file size, "4.2 MiB")
  - `recordUse`, `truncate`.
- `Paths.expandHome` / `shortenHome`; `KeyNames.modifierLabel`.
