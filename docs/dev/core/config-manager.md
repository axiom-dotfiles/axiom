# ConfigManager, drafts and previews

> **Files:** `services/ConfigManager.qml`, `services/ConfigDraft.qml`, `components/methods/ConfigMigration.qml`, `components/methods/SchemaValidation.qml`, `services/SettingsManager.qml`
> **Config:** all of `config/user/config.json`
> **Related:** [Config readers](config-readers.md), [Schema annotations](schema-annotations.md), [Editors pattern](editors-pattern.md), [Saved configs and sharing](saved-configs-sharing.md), [Secrets](secrets.md)

The owner of the runtime config: how it is loaded, written, drafted and previewed. Read before writing config from anywhere.

### What it owns
- `_config`: the parsed `config/user/config.json`.
- `_configSchema`: `config/json/config.schema.json`.
- Both are loaded eagerly at creation. The active theme's data belongs to ThemeManager, not here.

### Load pipeline
1. Parse.
2. `ConfigMigration.migrate`: upgrades old layouts by `version`, writes the result back once, and moves API keys to `SecretsManager`.
3. `SchemaValidation.pruneUnknown`: drops unknown keys with a warning.
4. `SchemaValidation.applyDefaults`: fills every schema `default`.
5. Validate.

### New entries
Editors create new entries at their definition's defaults with `withDefaults(value, "Bar" | "BarWidget" | "EdgeMenu" | "OverlayView" | "OverlayModule")`.

### Writes
(Rule: CLAUDE.md › Services, "Config writes".)
- All writes go through `setTheme()` / `setWallpaper()` / `saveConfig()` / `commit(object)`.
- They validate before writing, then `forceReload()`.
- `commit(object)` is for the draft services: it runs prune/defaults/validate and returns false, changing nothing, if rejected, so drafts stay dirty.
- Never mutate `ConfigManager.config` fields from UI code and expect persistence. Call the setters, or `SettingsManager.setValue(path, value)` from settings UI.

### ConfigDraft
- The editor services each hold a `ConfigDraft` (`services/ConfigDraft.qml`): SettingsManager, BarManager, OverlayManager, EdgeMenuManager, KeybindManager, MonitorManager, plus the `ScreenLayoutEditor` drafts of the desktop, lock screen and greeter layouts.
- A draft is a working copy of one config path:
  - `changed()` after in-place edits
  - `save()` merges onto the latest config via `commit`.
- Shape of an editor built on it: [Editors pattern](editors-pattern.md).

### Previews
- `ConfigManager.previews` (`setPreview(section, value)` / `clearPreview(section)`) holds unsaved edits shown live without being part of `config`, so other saves and disk reloads don't touch them.
- Example: BarManager previews `Bars` while dirty, and `BarManager.bars` reads `previews.Bars ?? config.Bars`.
- Readers that show previews read `previews.X ?? config.X` (`DesktopConfig`, `EdgeMenusConfig`).
