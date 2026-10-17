# ConfigManager, drafts and previews

> **Files:** `services/ConfigManager.qml`, `services/ConfigDraft.qml`, `components/methods/DataDirs.qml`, `services/DataMigrationManager.qml`, `scripts/migrate_xdg.sh`, `components/methods/ConfigMigration.qml`, `components/methods/SchemaValidation.qml`, `services/SettingsManager.qml`
> **Config:** all of `~/.config/axiom/config.json`
> **Related:** [Config readers](config-readers.md), [Schema annotations](schema-annotations.md), [Editors pattern](editors-pattern.md), [Saved configs and sharing](saved-configs-sharing.md), [Secrets](secrets.md)

The owner of the runtime config: how it is loaded, written, drafted and previewed. Read before writing config from anywhere.

### What it owns
- `_config`: the parsed `~/.config/axiom/config.json`.
- `_configSchema`: `config/json/config.schema.json`.
- Both are loaded eagerly at creation. The active theme's data belongs to ThemeManager, not here.

### Where files live
The repo (`Paths.axiomPath`) is read-only to the shell: a package installs it where it can't write. Everything axiom writes is in the XDG folders, resolved once by `DataDirs.xdg` (each `$XDG_*_HOME` when absolute, else its default) and handed out by `ConfigManager.dataDirs` and `Paths`:

| What | Where | `Paths` |
|---|---|---|
| config.json, `saved/` | `$XDG_CONFIG_HOME/axiom/` | `userConfigPath` |
| `StateManager` files (launcher, look, editors, onboarding, settings, clipboard pins, …) | `$XDG_STATE_HOME/axiom/ui/` (0700) | `statePath` |
| Secrets, chats, notification history, calendar cache, generated hypridle/Hyprland configs, integration outputs | `$XDG_STATE_HOME/axiom/` | `userStatePath` |
| Themes generated from the wallpaper (`generated/<name>`) | `$XDG_STATE_HOME/axiom/themes/` | `generatedThemesPath`, `themeFile(name)` |
| The default notes folder | `$XDG_DATA_HOME/axiom/notes/` | `defaultNotesPath` |

- Files under `userStatePath` keep their names: users' own configs point at several (the Hyprland include, the fzf/nvim/ncspot outputs).
- The greeter has its own folders (`Paths.greeterDir`) and reads none of these.
- **Data others installed** (Wayland sessions, Hyprland's example config and wallpapers, cursor themes) is looked up in `Paths.dataSearchDirs` (`DataDirs.searchDirs`: `$XDG_DATA_HOME`, then `$XDG_DATA_DIRS`, else `/usr/local/share:/usr/share`), never at a fixed `/usr/share` path: NixOS keeps nothing there. `claim_hyprland.sh` does the same in shell.
- **Moving an old install over:** before this layout the config was in the repo's `config/user/`, the UI state and notes in `config/state/`, and generated themes in `config/themes/generated/` (`DataDirs.legacy`). While `config/user/config.json` exists with no `MOVED.md` (`DataDirs.movedMarker`) beside it, `legacyLayout` is true and that session runs on the old folders as before. `DataMigrationManager` then holds saves (`holdSaves`) and runs `scripts/migrate_xdg.sh`. The script copies each folder over without overwriting anything, writes config.json last (in one piece), then writes the marker, and the shell reloads onto the XDG folders. The old folders are kept for a rollback. A failed copy writes no marker, so the next start tries again.

### Load pipeline
1. Parse.
2. `ConfigMigration.migrate`: upgrades old layouts by `version` and writes the result back once. It returns `secrets` (keys a step pulls out of the config, which ConfigManager hands to `SecretsManager`); no current step fills it.
3. `SchemaValidation.pruneUnknown`: drops unknown keys with a warning.
4. `SchemaValidation.applyDefaults`: fills every schema `default`.
5. Validate.

### New entries
Editors create new entries at their definition's defaults with `withDefaults(value, "Bar" | "BarWidget" | "EdgeMenu" | "OverlayView" | "OverlayModule")`.

### Writes
(Rule: AGENTS.md › Services, "Config writes".)
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
