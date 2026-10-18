# Saved configs, examples, import and export

> **Files:** `services/SavedConfigsManager.qml`, `components/methods/ConfigExamples.qml`, `components/views/settings/SavedConfigsSection.qml`, `services/ConfigManager.qml`, `services/FilePickerManager.qml`, `examples/*.json`
> **Config:** whole config, filtered by `x-scope`; snapshots in `~/.config/axiom/saved/`; `~/.local/state/axiom/ui/savedconfigs.json`
> **Related:** [Schema annotations](schema-annotations.md), [Config manager](config-manager.md), [Launcher](../features/launcher.md) (`/config` save/restore), [Shell manager](shell-manager-targeting.md)

Snapshots of the config, the shipped example setups, and sharing a config through export/import. All of them carry only what `x-scope` says (snapshots also the `x-snapshot` wallpaper setup), so loading one never changes another machine setting, and never an `x-takeover` one. Tests: `tst_ConfigExamples`.

### Where it shows
- The Maintenance category's page `SavedConfigsSection` (its `x-categories` `page`).
- It shows `SavedConfigsManager`'s snapshots in `~/.config/axiom/saved/`.
- Below them: sharing (Share: Export, Import…) and the example setups in `examples/` (`SavedConfigsManager.examples`).
- The launcher's `/config` can also save and restore snapshots: see [Launcher](../features/launcher.md).

### What a shared file carries: `x-scope`
Inherited down the schema; the root is `machine`.
- `look`: the layout and style sections, plus the theme, font, shape and motion.
- `personal`: carried only when asked for.
  - `Apps`, `Keybinds.binds`, a dock's `pinned`, Favourites' apps, widget commands, OSD audio apps.
- `machine`: never carried.
  - Monitor names, wallpapers, accounts, paths, AUR settings, and every other section.

### ConfigExamples (pure)
Walks a value along the schema.
- `pick(config, schema, personal)`: keeps the carried leaves.
- `apply(current, example, schema, personal)`: takes the example's carried parts.
  - An array is taken outright, so nothing of the old layout stays.
  - Inside the carried parts it keeps the user's other values from the same item. It matches by `id`, then `name`; an item with neither but a `type` (a bar widget, a module) as the same nth item of that type (the second `SystemStats` is the user's second `SystemStats`, wherever it moved); anything else by position (machine values only); else it falls back to the default.
  - Position matching is machine-only because a personal value such as a command must not land on another button. A match by type counts like one by id: an item of the same type is the same widget.
  - A setting that serves every widget or module of a feature (accounts, a helper, a location) belongs in the feature's top-level section (`Weather`, `ClaudeUsage`, `Updates`, …, in the Modules category), not in each widget's `properties`: sections are matched by name, so it never depends on where the widget sits.
- `sparse(config, schema)`: drops what loading fills back in.
- `keepTakeovers(config, current, paths)`: puts back the current value of every `x-takeover` setting.
  - `takeoverPaths(schema)` is kept as `ConfigManager.takeoverPaths`: `Compositor.mode`, `Lockscreen.mode`, `Greeter.enabled`, `Idle.enabled`, `Polkit.enabled`.
  - `ConfigManager.restoreConfig` applies it to everything it loads: a snapshot, the defaults, an example, an import.
  - Those settings take something over (hyprland.lua, the session's locker, hypridle, the polkit agent, greetd), so only their own cards switch them, doing the takeover or giving it back.
- `snapshot(config, schema)`: what a saved snapshot holds: `pick(…, true)` plus the `x-snapshot` settings (`snapshotPaths`): the wallpapers, wallpaper folder and mode, rotation, light/dark wallpapers and the theme schedule. These are machine settings, but a snapshot restores on the PC it was saved on.
- `snapshotFiles(config, schema)` and `withSnapshot(config, saved, schema, existing)`: restore the `x-snapshot` settings; a `file://` URL comes back only while its file exists, and a wallpaper is never blanked (otherwise the current one stays).

### Loading an example or import
- `applyExample(name)` and `confirmImport(personal)`:
  1. Load the file (`_load`) through `ConfigManager.normalizeConfig`, so any version migrates. A file older than the window look's move out of `Hyprland.managed` (v58, v63) never held those settings, so `ConfigExamples.keepMovedLook` keeps the running config's (restoring a snapshot does the same).
  2. Save the running config as `before-<name>`.
  3. Once that is written, restore `ConfigExamples.apply`.
- `browseImport()` opens the desktop's file picker for a JSON file ([File picker](file-picker.md)).
  - The chosen file becomes `importing`, with title and description from its `_example` header, for the page's confirm row. The row's switch for personal parts starts off.

### Saving and restoring a snapshot
- `save(name)` writes `~/.config/axiom/saved/<name>.json` in the export format (`_example` header + `version` + `sparse(snapshot(config))`). A snapshot can be shared, or imported elsewhere, as it is.
- `restore(name)`:
  1. Loads the file through `normalizeConfig`. Older whole-config snapshots load too, and only their snapshot parts are taken.
  2. Checks which of its `snapshotFiles` exist with `find … -maxdepth 0`.
  3. Restores `withSnapshot(apply(current, saved, schema, true), saved, schema, existing)`.
  - Monitors, accounts, theme integrations and other machine settings stay as they are. No backup is made.
- `restoreDefaults()` applies the schema defaults like an example (with personal parts), after a `before-defaults` backup.

### Export
- `exportConfig(personal)` writes `~/axiom-[<active>-]<date>-<time>.json`.
- Contents: `_example` + `version` + the sparse pick. It applies as the whole pick would (`tst_ConfigExamples`' round trips).
- Exports and examples are one format.

### Adding an example setup
- Build the setup in the shell, then Settings → Maintenance → Share → Export, with keybinds, apps and commands off unless the example needs a command. It writes `~/axiom-<name>-<date>-<time>.json`, holding only the look (`x-scope`) minus defaults.
- Move it to `examples/<name>.json` and fill in its `_example` header: `{ "title": "…", "description": "…" }`.
- Monitors, wallpapers, accounts and paths are `machine` scope, so they're never in an export: don't add them by hand.
- `scripts/run_tests.sh ConfigExamples` loads every example the way the shell does.

### Snapshot rows
- `active` is the one last saved or restored, kept in `state/savedconfigs.json`. Only its row offers Overwrite.
- `modified` dots it: the running config's `snapshot()` differs from the saved file's (loaded through `ConfigManager.normalizeConfig`). A machine-only change leaves it off, and so does anything that changes on its own (rotation, light/dark wallpapers and schedule), which never writes the config.
