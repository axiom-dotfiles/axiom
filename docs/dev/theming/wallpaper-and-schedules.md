# Wallpaper and schedules

> **Files:** `services/WallpaperManager.qml`, `services/ThemeManager.qml`, `services/DailySchedule.qml`, `components/methods/Schedules.qml`, `shell/Wallpaper.qml`, `components/surfaces/wallpaper/WallpaperWindow.qml`, `scripts/setWallpaper.sh`, `components/content/WallpaperPicker.qml`, `components/content/ThemePicker.qml`, `components/forms/SettingRows.qml`
> **Config:** `Appearance.wallpaper`, `Appearance.wallpapers`, `Appearance.wallpaperBackend`, `Appearance.wallpaperMode`, `Appearance.wallpaperRotation.*`, `Appearance.variantWallpapers.*`, `Appearance.themeSchedule.*`
> **Related:** [Themes](themes.md), [Night light](night-light.md)

How the wallpaper is drawn, and everything that changes the look on its own: wallpaper rotation, light/dark wallpapers, and the light/dark theme schedule.

### Wallpaper backend (ThemeManager `setWallpaper`)
- `Appearance.wallpaperBackend`:
  - `quickshell` (the default): drawn by `shell/Wallpaper` straight from config, one Background-layer `surfaces/wallpaper/WallpaperWindow` per screen, crossfading.
  - `awww`: runs `setWallpaper.sh`. Hyprland's `wallpaperDaemon` starts it only then.
- Batch writes go through `ThemeManager.setWallpapers(map)` → `ConfigManager.setWallpapers` (one save).

### WallpaperManager: wallpaper modes
- `Appearance.wallpaperMode`:
  - `fixed`;
  - `rotate`: `wallpaperRotation` with `interval` minutes, `random`/`sequential` order (via `methods/Schedules.nextWallpaper`) and `sameOnAll`. The last change time is a `PersistentProperties`, checked every 30 s. Triggers: IPC `wallpaper next`, bind `nextWallpaper`, launcher `/nextwallpaper`.
  - `variant`: `variantWallpapers.dark`/`light` on every monitor, following `Appearance.darkMode`.
- Regenerating the theme:
  - automatic changes regenerate only while a generated theme is active;
  - picks by hand (`pick(url, monitor, variant)`, from `WallpaperPicker`) always do.
- Created from `shell.qml`'s `_services`.

### Theme schedule
- `Appearance.themeSchedule`: light from `lightAt`, dark from `darkAt`.
- Runs through a `services/DailySchedule`:
  - it fires `due(inWindow)` only on edges: the window opens or closes, the schedule is turned on, or the times are moved across now;
  - so a switch by hand lasts until the next edge;
  - its last state survives reloads.
- The night light uses the same `DailySchedule` (see [Night light](night-light.md)).

### Editing (Themes page)
- The Themes page edits all of it inline:
  - `WallpaperPicker`'s Fixed/Rotate/Light-Dark switch;
  - `ThemePicker`'s Auto.
- Through `forms/SettingRows`: dotted-path `SchemaField` rows saved by `SettingsManager.commitValues`.
