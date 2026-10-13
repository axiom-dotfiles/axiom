# Desktop

> **Files:** `services/DesktopManager.qml`, `config/DesktopConfig.qml`, `shell/Desktop.qml`, `components/surfaces/desktop/DesktopWindow.qml`, `components/surfaces/screenlayout/ScreenLayoutView.qml`, `services/ScreenLayoutEditor.qml`, `components/views/layouts/DesktopTarget.qml`
> **Config:** `Desktop.all`, `Desktop.primary`, `Desktop.monitors[]` (reader `DesktopConfig`)
> **Related:** [Lockscreen](lockscreen.md), [Layouts editor](../overlay/layouts-editor.md), [Clock and time zones](clock-timezones.md), [Saved configs](../core/saved-configs-sharing.md), [Edge menus hosts](../edge-menus/hosts.md), [Dock](dock.md)

Overlay modules drawn on the desktop, under the windows. Read this doc for desktop layouts, the desktop window, which modules may go on it, and how the Layouts page edits it.

### Layouts
- `Desktop.all`, `Desktop.primary` and `Desktop.monitors[]` are each a `DesktopLayout` with these fields:
  - `enabled`
  - `monitor` (in `monitors` only)
  - `columns`, `rows`, `fineGrid`
  - `moduleBorders` (off by default: modules sit straight on the wallpaper)
  - `modules`.
- **Which layout a screen shows** (`DesktopConfig.sourceFor`/`layoutFor`), each only while enabled:
  1. its own layout from `monitors`, by connector name; a monitor whose own layout is turned off shows nothing;
  2. otherwise `primary`, on the primary monitor (`DesktopConfig.primaryName`, as surfaces place on it);
  3. otherwise `all`.
- **Scope:** `all` and `primary` are `x-scope: look`, `monitors` is `machine`, so an example or export carries only the first two. See [saved configs](../core/saved-configs-sharing.md).
- **Default:** a Stacked Clock on the primary monitor.

### DesktopManager
- `editor`: the Layouts editor's draft of the `Desktop` section.
- `selectedTarget` / `selectTarget`: which layout it edits.
- `targets`: the picker's entries.
- `insetsFor`: each screen's room.

### Surface
- **Window:** `shell/Desktop` builds `surfaces/desktop/DesktopWindow` on each screen whose layout has modules, once the layer rules are in.
  - It is a Bottom-layer `PanelWindow` named `axiom-desktop`, with `no_anim` because it fades itself in.
  - It sits over the Background wallpaper and under every window, so fullscreen windows cover it.
- **Input:**
  - It takes no keyboard focus.
  - Its input mask is its modules' rects (`ScreenLayoutView.moduleRects`), so clicks on the rest of the desktop go through.
- **Content:** a `ScreenLayoutView`.
  - `showBackdrop: false`: its backdrop only feeds the frosting (`hideSource`).
  - `frost` is on only with `moduleBorders`.
- **Insets** come from `DesktopManager.insetsFor(screen)`. Per side, it takes the larger of:
  - `EdgeMenuManager.reservedOn` (border, bars, integrated menus);
  - Hyprland's live `reserved`, which includes docks (`DockManager.reservedOf`);
  - plus `gaps_out` on top of that.
  The grid therefore lines up with where tiled windows start, and refits when a bar moves.
- **Host:** `{ kind: "desktop", screen, bare }`.
  - Bare modules keep their padding (`SlotContext`).
  - ClockCalendar's events are read-only on the desktop.

### Modules
- Allowed: the modules whose `x-hosts` list `desktop`. These are display modules and ones that only take clicks: NowPlaying, VolumeDials, SystemGraphs, Disks, TopProcesses, Updates, QuickActions, Greeting, ClockCalendar, Clock, Weather, Battery, Network, Favourites, Palette, ColorSwatch.
- Not allowed: anything that needs typing (Notes, Chat, Calendar's and Agenda's editors).
- The Clock module (styles, time zones) is in [clock-timezones.md](clock-timezones.md).

### Editing
- **Where:** the Desktop row on the [Layouts page](../overlay/layouts-editor.md), above Lock screen.
- **The draft:** the row edits `DesktopManager.editor`, a `ScreenLayoutEditor` drafting the whole `Desktop` section.
  - `layoutOf` picks the selected target's layout. `selectedTarget` is `"all"`, `"primary"` or a monitor name.
  - The grid's history starts over on a target switch, through `scope`.
  - `layoutsOf` lists every layout, for `problems`.
- **Live preview:** `previewSection: "Desktop"` shows the draft on the desktop while it differs from the saved config (`DesktopConfig.desktop` reads the preview). So there is no Show on screen button.
- **Picker:** the side panel lists, each with what it shows (`DesktopManager.targets`, `statusOf`):
  1. All monitors;
  2. the primary monitor;
  3. each monitor, plugged-in ones first, then those with a layout of their own.
- **Per-monitor layouts:**
  - A monitor without its own layout has nothing to edit until Give it its own layout (`createForTarget`), which copies what it showed.
  - Remove its own layout (`removeTarget`) hands it back to the primary's or all's layout.
  - The on/off switch is `setEnabled`.
- **Fit line:** `DesktopTarget`'s fit line gives the room on the target's screen (`screenFor`: its monitor, else the primary).
