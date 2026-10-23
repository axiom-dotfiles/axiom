# Saved configs, examples, import and export

> **Files:** `services/SavedConfigsManager.qml`, `components/methods/ConfigExamples.qml`, `components/views/Settings/SavedConfigsCard.qml`, `services/ConfigManager.qml`, `services/FilePickerManager.qml`, `examples/*.json`
> **Config:** whole config, filtered by `x-scope`; snapshots in `~/.config/axiom/saved/`; `~/.local/state/axiom/ui/savedconfigs.json`
> **Related:** [Schema annotations](schema-annotations.md), [Config manager](config-manager.md), [Launcher](../features/launcher.md) (`/config` save/restore), [Shell manager](shell-manager-targeting.md)

Snapshots of the config, the shipped example setups, and sharing a config through export/import. All of them carry only what `x-scope` says (snapshots also the `x-snapshot` wallpaper setup), so loading one never changes another machine setting, and never an `x-takeover` one. Tests: `tst_ConfigExamples`.

### Where it shows
- The Maintenance category's own card `SavedConfigsCard` (its `x-categories` `card`, wide, last).
- It shows `SavedConfigsManager`'s snapshots in `~/.config/axiom/saved/`.
- Below them: sharing (Share: Export, Import…) and the example setups in `examples/` (`SavedConfigsManager.examples`).
- The launcher's `/config` can also save and restore snapshots: see [Launcher](../features/launcher.md).

### What a shared file carries: `x-scope`
Inherited down the schema; the root is `machine`.

| Scope | What | Export / import | Snapshot |
|---|---|---|---|
| `look` | the layout and style sections, the theme, font, shape and motion, the launcher's and notifications' look, each surface's Module size (`moduleScale`: a ratio over the card size), compositor animations and decoration, cursor theme, the theme schedule | always | ✅ |
| `personal` | how big the UI is (`Widget.scale`, `cardSize`, `density`: a shared look keeps its proportions at your size), preferences (notification, idle, night light, input, window behaviour, launcher search, chat, calendar, notes), `Keybinds.binds`, `Apps.pinned`, a dock's own `pinned`, Favourites' apps, OSD app bars | its own switch, off by default | ✅ |
| `commands` | anything that runs as you: every command field, `Apps` terminal/file manager/browser, `Updates` terminal and upgrade, idle listeners, exec and raw binds | its own switch, off by default, warned | ✅ |
| `machine` | monitor names, wallpapers, accounts, paths, hardware, services, takeovers, and every section not marked | never | wallpaper setup only (`x-snapshot`) |

- `x-scopeIf: { when, scope }` on an array's items gives an item its own scope by what it holds (`when` as `x-showIf`, over the item's keys): an `exec`/`raw` bind is `commands`, an `app` OSD bar `personal`. Such an item is left out where its scope isn't carried, and applying keeps the user's own after the file's.
- `x-monitorRef` (`"off"` | `"drop"`) on a per-monitor part's `monitor` (bars, docks, OSDs, edge menus, strips, a monitor's own desktop): an export writes the monitor by its place (`#1` leftmost, `#2`, …, `@primary`, `*` for all, `monitorOrder`), and applying puts it on the user's monitor in that place. With no monitor there, the part is turned off (`off`) or left out (`drop`), so nothing piles up on the primary. One monitor to two adds nothing: what shows everywhere is `monitors: all`.

### ConfigExamples (pure)
Walks a value along the schema.
- `pick(config, schema, carry, monitors)`: keeps the carried leaves (`carry`: `[]`, `["personal"]`, `["commands"]` or `everything`, both), writing monitors by place with `monitors`.
- `apply(current, example, schema, carry, monitors)`: takes the example's carried parts.
  - An array is taken outright, so nothing of the old layout stays.
  - Inside the carried parts it keeps the user's other values from the same item. It matches by `id`, then `name`; an item with neither but a `type` (a bar widget, a module) as the same nth item of that type (the second `SystemStats` is the user's second `SystemStats`, wherever it moved); anything else by position (machine values only); else it falls back to the default.
  - Position matching is machine-only because a personal value such as a command must not land on another button. A match by type counts like one by id: an item of the same type is the same widget.
  - A setting that serves every widget or module of a feature (accounts, a helper, a location) belongs in the feature's top-level section (`Weather`, `ClaudeUsage`, `Updates`, …, in the Modules category), not in each widget's `properties`: sections are matched by name, so it never depends on where the widget sits.
- `sparse(config, schema)`: drops what loading fills back in.
- `keepTakeovers(config, current, paths)`: puts back the current value of every `x-takeover` setting.
  - `takeoverPaths(schema)` is kept as `ConfigManager.takeoverPaths`: `Compositor.mode`, `Lockscreen.mode`, `Greeter.enabled`, `Idle.enabled`, `Polkit.enabled`.
  - `ConfigManager.restoreConfig` applies it to everything it loads: a snapshot, the defaults, an example, an import.
  - Those settings take something over (hyprland.lua, the session's locker, hypridle, the polkit agent, greetd), so only their own cards switch them, doing the takeover or giving it back.
- `snapshot(config, schema)`: what a saved snapshot holds: `pick(…, everything)` plus the `x-snapshot` settings (`snapshotPaths`): the wallpapers, wallpaper folder and mode, rotation and light/dark wallpapers. These are machine settings, but a snapshot restores on the PC it was saved on.
- `keepMovedKeys(config, held, current, version)`: `movedKeys` lists the settings that became part of a shared file at a version (v58, v63: the window look out of `Hyprland.managed`; v71: the settings moved out of `machine`). For a file older than that, each one the file doesn't hold (`held`: migrated, not filled) keeps the running config's value instead of its default.
- `snapshotFiles(config, schema)` and `withSnapshot(config, saved, schema, existing)`: restore the `x-snapshot` settings; a `file://` URL comes back only while its file exists, and a wallpaper is never blanked (otherwise the current one stays).

### Loading an example or import
- `applyExample(name)`, `confirmImport(personal, commands)` and `applyShared(name, path, title)` (a [community setup](../features/community-setups.md), personal parts and commands always off, no confirm row):
  1. Load the file (`_load`) through `ConfigManager.normalizeConfig`, so any version migrates, then `ConfigExamples.keepMovedKeys` (restoring a snapshot does the same).
  2. Save the running config as `before-<name>`.
  3. Once that is written, restore `ConfigExamples.apply`.
  4. `applied(name)` is signalled, or `applyFailed(name)` if the backup or the restore failed (`status` says why).
  5. The result is saved as its own snapshot and made active: `example-<name>`, `import-<title>`, or the shared file's (`community-<id>`), deferred out of the backup's write so `applied` handlers can change the config first. The saved configs list then shows it as Current, with Overwrite and the unsaved dot; the prefixes keep it from replacing one of the user's snapshots. Its `_example.source` names what was applied, which `activeSource` gives while it's the active one ("" once the user saves over it, or for one they saved). Restore defaults saves none.
- An import or shared file is checked first (`_readShared`): it needs a `version`, and one from a newer axiom is refused.
- `browseImport()` opens the desktop's file picker for a JSON file ([File picker](file-picker.md)).
  - The chosen file becomes `importing`, with title and description from its `_example` header, for the page's confirm row. It offers a switch for its personal parts (`hasPersonal`) and one for its commands (`hasCommands`) only when it holds them; both start off.

### Saving and restoring a snapshot
- `save(name)` writes `~/.config/axiom/saved/<name>.json` in the export format (`_example` header + `version` + `sparse(snapshot(config))`). A snapshot can be shared, or imported elsewhere, as it is.
- `restore(name)`:
  1. Loads the file through `normalizeConfig`. Older whole-config snapshots load too, and only their snapshot parts are taken.
  2. Checks which of its `snapshotFiles` exist with `find … -maxdepth 0`.
  3. Restores `withSnapshot(apply(current, saved, schema, everything), saved, schema, existing)`.
  - Monitors, accounts, theme integrations and other machine settings stay as they are. No backup is made.
- `restoreDefaults()` applies the schema defaults like an example (with personal parts and commands), after a `before-defaults` backup.

### Export
- `exportConfig(personal, commands, places)` writes `~/axiom-[<active>-]<date>-<time>.json`, with monitors by place unless `places` is false (the community export, until its check takes them: [issues](../issues.md)).
- Contents: `_example` + `version` + the sparse pick. It applies as the whole pick would (`tst_ConfigExamples`' round trips).
- Exports and examples are one format.

### Adding an example setup
- Build the setup in the shell, then Settings → Maintenance → Share → Export, with both switches off unless the example needs a command. It writes `~/axiom-<name>-<date>-<time>.json`, holding only the look (`x-scope`) minus defaults.
- Move it to `examples/<name>.json` and fill in its `_example` header: `{ "title": "…", "description": "…" }`.
- Wallpapers, accounts and paths are `machine` scope, so they're never in an export, and monitors only by place: don't add them by hand.
- `scripts/run_tests.sh ConfigExamples` loads every example the way the shell does.

### Snapshot rows
- `active` is the one last saved or restored, kept in `state/savedconfigs.json`. Only its row offers Overwrite.
- `modified` dots it: the running config's `snapshot()` differs from the saved file's (loaded through `ConfigManager.normalizeConfig`). A machine-only change leaves it off, and so does anything that changes on its own (rotation, light/dark wallpapers and schedule), which never writes the config.
