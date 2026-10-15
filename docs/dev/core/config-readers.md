# Config readers

> **Files:** `config/*.qml` (e.g. `config/General.qml`, `config/Appearance.qml`, `config/Bar.qml`, `config/Theme.qml`, `config/Paths.qml`)
> **Config:** one reader per section
> **Related:** [Config manager](config-manager.md), [Schema annotations](schema-annotations.md), [Themes](../theming/themes.md)

Typed, read-only views of config sections. (Rule: AGENTS.md › Config, reader naming and no `??` fallbacks; › Layering.)

### What a reader is
- `pragma Singleton`, but a reader, not an owner: one per config section, exposing `readonly property` values from `ConfigManager.config`.
- No `??` fallbacks: schema defaults are already filled in.
- UI reads colors and settings from readers (`Theme.background`, `Widget.padding`), never `ConfigManager.config` directly.
- Readers whose section name collides with a type get a `Config` suffix (`Popouts`, `Overlay`, `Icons`, `OSD`, `Launcher`, `Notifications`, …).

### Readers
- **`General`**: `displayName`, `primaryMonitor`, `monitors` / `screens`, and:
  - `outputs`: the connected monitors.
    - It is `Quickshell.screens` without Qt's nameless placeholder and Hyprland's headless `FALLBACK`, which stand in while no monitor is connected.
    - A window left on a stand-in when monitors return is moved off a screen Qt then frees, and qs crashed configuring it.
  - `screensNamed(name)`: that screen, else the primary, else the first.
  - `screensFor(mode, name)`: see [Shell manager and screen targeting](shell-manager-targeting.md).
- **`Idle`**: hypridle ([Idle](../features/idle.md)).
- **`PolkitConfig`**: [Polkit](../features/polkit.md).
- **`GreeterConfig`**: [Greeter install](../features/greeter-install.md).
- **`Appearance`**: theme, font, shape, motion tokens.
- **`Widget`**: sizes for controls and panels outside the bar.
- **`Bar`**: from `Bars`.
  - The first bar is primary.
  - `edgeName(location)` gives a `Bar.Location` as `"top"`…`"right"`.
- **`PopoutsConfig`**: open/dismiss delays and edge trigger size, shared by bar and edge popouts.
- **`OSDConfig`**: the OSDs; see [OSD](../features/osd.md).
- **`LauncherConfig`**: launcher placement, size and providers.
- **`Apps`**: the terminal, file manager and browser that binds and the launcher open.
- **`Screenshots`**: the screenshot and recording folders, `~` expanded, empty for `ScreenshotManager`'s defaults ([Screenshots and screen recording](../features/screenshots-recording.md)).
- **`NotificationsConfig`**: the toasts' corner and gaps; see [Notifications](../features/notifications.md).
- **`OverlayConfig`**: views and card-grid constants.
- **`EdgeMenusConfig`**: edge menus.
- **`IconsConfig`**, **`ChatConfig`**, **`ThemeIntegrations`**.
- **`CalendarConfig`**:
  - accounts with their ids filled in
  - `calendars` flattened with resolved colors
  - `shownCalendars` / `writableCalendars`, `newEventCalendar`
  - `colors` by calendar id
  - `timeFormat` from `use24Hour`.
- **`Paths`**: derived filesystem paths, not configurable.
  - What ships in the repo (`Quickshell.shellDir`): `axiomPath`, `resourcePath`, `themePath`, `scriptsPath`. Read-only.
  - What axiom writes, the XDG folders from `ConfigManager.dataDirs`: `userConfigPath`, `statePath`, `userStatePath`, `userDataPath`, `defaultNotesPath`, `generatedThemesPath`, plus `themeFile(name)` for a theme's file by name. See [Where files live](config-manager.md#where-files-live).
  - Also `greeter` and the greeter's folders ([Greeter runtime](../features/greeter-runtime.md)).
- **`Theme`**: below.

### Theme
- `config/Theme.qml` exposes the base16 palette (`base00`–`base0F`).
- Semantic aliases (`background`, `accent`, `error`, …) resolve through `_themeData.semantic`.
- `stringToColorMap` + `resolveColor(name)` give dynamic lookup by string, for a color name that comes from JSON/config rather than a static binding.
