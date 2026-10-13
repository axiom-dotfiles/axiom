# Saved configs, examples, import and export

> **Files:** `services/SavedConfigsManager.qml`, `components/methods/ConfigExamples.qml`, `components/views/settings/SavedConfigsSection.qml`, `services/ConfigManager.qml`, `scripts/pick_file.py`, `examples/*.json`
> **Config:** whole config, filtered by `x-scope`; snapshots in `config/user/saved/`; `config/state/savedconfigs.json`
> **Related:** [Schema annotations](schema-annotations.md), [Config manager](config-manager.md), [Launcher](../features/launcher.md) (`/config` save/restore), [Shell manager](shell-manager-targeting.md)

Snapshots of the config, the shipped example setups, and sharing a config through export/import. All of them carry only what `x-scope` says, and never change `x-takeover` settings. Tests: `tst_ConfigExamples`.

### Where it shows
- The Maintenance category's page `SavedConfigsSection` (its `x-categories` `page`).
- It shows `SavedConfigsManager`'s snapshots in `config/user/saved/`.
- Below them: sharing (Share: Export, Import…) and the example setups in `examples/` (`SavedConfigsManager.examples`).
- The launcher's `/config` can also save and restore snapshots: see [Launcher](../features/launcher.md).

### What a shared file carries: `x-scope`
Inherited down the schema; the root is `machine`.
- `look`: the layout and style sections, plus the theme, font, shape and motion.
- `personal`: carried only when asked for.
  - `Apps`, `Hyprland.binds`, a dock's `pinned`, Favourites' apps, widget commands, OSD audio apps.
- `machine`: never carried.
  - Monitor names, wallpapers, accounts, paths, AUR settings, and every other section.

### ConfigExamples (pure)
Walks a value along the schema.
- `pick(config, schema, personal)`: keeps the carried leaves.
- `apply(current, example, schema, personal)`: takes the example's carried parts.
  - An array is taken outright, so nothing of the old layout stays.
  - Inside the carried parts it keeps the user's other values from the same item. It matches by `id`, then `name`, then (machine values only) position, else falls back to the default.
  - Position matching is machine-only because a personal value such as a command must not land on another button.
- `sparse(config, schema)`: drops what loading fills back in.
- `keepTakeovers(config, current, paths)`: puts back the current value of every `x-takeover` setting.
  - `takeoverPaths(schema)` is kept as `ConfigManager.takeoverPaths`: `Hyprland.mode`, `Lockscreen.mode`, `Greeter.enabled`, `Idle.enabled`, `Polkit.enabled`.
  - `ConfigManager.restoreConfig` applies it to everything it loads: a snapshot, the defaults, an example, an import.
  - Those settings take something over (hyprland.lua, the session's locker, hypridle, the polkit agent, greetd), so only their own cards switch them, doing the takeover or giving it back.
- `equalApartFrom`: compares configs while leaving the takeover settings out, without copying either.

### Loading an example or import
- `applyExample(name)` and `confirmImport(personal)`:
  1. Load the file through `ConfigManager.normalizeConfig`, so any version migrates.
  2. Save the running config as `before-<name>`.
  3. Once that is written, restore `ConfigExamples.apply`.
- `browseImport()` runs `scripts/pick_file.py`: xdg-desktop-portal's FileChooser through python-gobject, else zenity/kdialog.
  - The overlay is stepped aside meanwhile (`ShellManager.beginStepAside`): the picker is a window, under the Overlay layer.
  - The chosen file becomes `importing`, with title and description from its `_example` header, for the page's confirm row. The row's switch for personal parts starts off.

### Export
- `exportConfig(personal)` writes `~/axiom-[<active>-]<date>-<time>.json`.
- Contents: `_example` + `version` + the sparse pick. It applies as the whole pick would (`tst_ConfigExamples`' round trips).
- Exports and examples are one format.

### Snapshot rows
- `active` is the one last saved or restored, kept in `state/savedconfigs.json`. Only its row offers Overwrite.
- `modified` dots it: the running config differs from the snapshot. Both pass through `ConfigManager.normalizeConfig` and are compared by `ConfigExamples.equalApartFrom`.
