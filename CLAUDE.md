# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A [Quickshell](https://quickshell.org) desktop shell config (QML) for Hyprland (0.55+, Lua config), named "axiom": bar, notifications, lockscreen, launcher, overlay pages, edge menus, docks, OSD, power menu, workspace overview, screen border. No build step: `qs` interprets the QML at runtime.

**`docs/architecture.md` has the detailed mechanics of every service and surface** (chat, notes, screenshots, monitors, Hyprland modes, docks, edge menus, popouts, launcher, …), the schema annotations and settings page, the shared pattern every editor follows ("Editors"), and the index of reusable pieces ("Shared UI pieces"). Read the relevant section before changing a feature, and update it when you change how one works. This file holds only the rules.

## Running / reloading

- The shell runs detached; never start/stop it from this session. Saving a file it has loaded hot-reloads it.
- **Logs**: `scripts/log.sh` (warnings/errors since the last reload; `--debug` adds `console.log`, `--all`, `-f`, `-g PATTERN`). A clean reload is just `Reloading configuration...` + `Configuration Loaded`. stdout/journalctl show nothing. `console.log` for tracing, `console.warn` only for real problems.
- **Seeing a page**: `qs -c axiom ipc call overlay page <ViewType>` then `grim -o <monitor>` (crop with `magick`), then `ipc call overlay close`. A settings category has no IPC: add a temporary `IpcHandler` calling `SettingsManager.openCategory(name)` to `shell.qml` (not inside a singleton, where it never registers), and revert it.
- `config/user/config.json` is owned by the settings UI but may be edited directly to test. `ConfigManager` watches it; an invalid file never replaces the running config (the last good one stays and `savesBlocked` refuses saves until it's fixed).
- New singletons are picked up by a hot reload (qs 0.3.1). A new *directory* imported only from URL-loaded files isn't scanned until qs restarts (`module "qs.…" is not installed`): ask the user to restart.
- URL-loaded files (bar widgets, content, views) only see sibling types because some loaded file imports their directory by name (`BarWidgetHost` → `qs.components.bar.widgets`, `BarPopouts`/`OverlaySlot` → `qs.components.content`, `OverlayPanel` → `qs.components.views`).
- File reads go through `FileManager.read`; `XMLHttpRequest` is only for HTTP. Rewrite watched JSON (`config/i18n/*.json`, config.json) atomically (temp file + rename): a half-written file gets read.

## Never, while testing

- Lock the built-in locker (only the user can type the password). Test `LockSurface` in a hidden window.
- Simulate cursor movement to verify UI. Check logs and reason through bindings instead.
- Switch the real Hyprland config to `managed` mode (test `claim_hyprland.sh` on scratch dirs), Keep a monitor layout, `apply` a self-update on the live repo, delete the real config.json (use `ipc call onboarding goTo <n>`), or enable `Idle` on the live config without asking (it replaces the user's hypridle).
- The user's `~/.config/hypr/user/` is a symlink to `~/repos/dotfiles/hypr/user`.

## Checks

All run in CI (`.github/workflows/checks.yml`); `scripts/check_all.sh` runs every one. None of them run the shell, so still check `scripts/log.sh` after a save.
- `scripts/check_structure.py`: **run after adding, renaming or moving QML files.** Schema types and `popoutName`s have files, URL-loaded dirs are imported, `qs.*` imports resolve, singleton names aren't typos, no file sees two same-named types, every file has its pragma.
- `scripts/run_tests.sh [Name…]`: qmltestrunner tests `tests/tst_<Name>.qml` for `components/methods/`, the schema defaults and `ConfigMigration` (`tests/fixtures/configs/v1.json`). Add a case when changing a methods helper or a migration step. Generated Lua is checked with `luac -p` (`*.run.lua` also run).
- `scripts/check_qmllint.py`: fails on warnings not in `scripts/qmllint-baseline.json`. Fix new warnings; `--update-baseline` only for Quickshell type-info gaps, or when it reports baselined warnings gone.
- `scripts/check_qmlformat.sh [--fix]`, `shellcheck -x -S warning`, `tests/scripts/test_scripts.py` (themes, `theme_*.sh`, `self_update.sh`, `generate_theme.py`).
- `scripts/check_i18n.py` after changing any user-visible text or schema title/description.

## Formatting

- `/usr/lib/qt6/bin/qmlformat -i` on changed `.qml` files (`.qmlformat.ini`: 2 spaces, no column limit). The `qmlformat` on PATH is Qt5's and fails silently.
- The QML JS engine has no `Array.prototype.flatMap` (use `[].concat(...arr.map(...))`) and no `Object.fromEntries` (use `reduce`).

## Layout

```
shell.qml       entrypoint: one top-level Item per surface, plus `_services` (services only reached by IPC)
shell/          top-level pieces, one per surface
components/
  methods/      pure singleton helpers (no files, processes, dispatches or qs.* imports; unit-tested)
  reusable/     generic Styled* widgets, no feature logic
  forms/        schema-driven form widgets (SchemaField, SchemaPropertiesForm, …)
  content/      loadable panels, by name: overlay module types and bar popouts (base/: Card, Panel, TitledCard; parts/: helpers)
  hosts/        where content appears: popout/ (bar + edge popouts) and overlay/ (pages, the module grid, slots)
  views/        overlay pages by view type, with their pieces in subfolders
  bar/          the bar; widgets/ = bar widget types
  surfaces/     standalone windows (launcher, lockscreen, toasts, dock, onboarding, screenshot, …)
services/       pragma Singleton managers: state and side effects
config/         config reader singletons; json/ (schema, theme defaults, emoji), themes/, i18n/, user/ (live config, gitignored), state/
scripts/        external scripts (theming, wallpaper, self-update, Hyprland claim) and the dev checks
tests/          qmltestrunner tests, fixtures, tests/scripts/
```

Imports use the `qs.` namespace (`import qs.services`, `import qs.components.bar`), never relative paths; there are no qmldir files. Files start with `pragma ComponentBehavior: Bound` or `pragma Singleton`.

## Layering

Dependencies point one way:
- **`components/methods/`**: pure.
- **Data owners** load and watch files: `ConfigManager` (config.json, schema), `ThemeManager` (active theme, theme defaults), `I18n`. ConfigManager reads no reader.
- **`config/` readers** read only the owners and each other.
- **Services** use readers and methods, and own every side effect: processes, dispatches, file writes, polling.
- **UI** uses everything below it, but runs no polling Process or repeating Timer of its own and never reads `ConfigManager.config` directly.

## Services

- One `pragma Singleton QtObject` per domain, named `*Manager`, exposing readonly properties, signals and functions. Non-singleton helpers are named for what they are (`ConfigDraft`, `GridEditor`, `ConsumerRegistry`, `WeatherSource`, `ChatRequest`, `DailySchedule`).
- Don't shadow Quickshell singletons: `NetworkingManager`, `BluetoothManager`, not `Networking`/`Bluetooth`.
- A service with an IPC target that nothing else references is created from `shell.qml`'s `_services`.
- **Anything polled goes through `acquire(owner, request)` / `release(owner)`** (a `ConsumerRegistry`): fetched once for all consumers, at the shortest interval asked (or a configured one: WeatherManager's comes from `WeatherConfig`), not at all with none. Acquire in `Component.onCompleted` (again when the config-derived request changes; identical requests are no-ops), release in `onDestruction`. SystemManager, UpdatesManager, WeatherManager, TailscaleManager and CommandManager (any shell command's output) work this way.
- **Config writes** go only through `ConfigManager.setTheme` / `setWallpaper(s)` / `saveConfig` / `commit(object)` (validates first; returns false and changes nothing if rejected), or `SettingsManager.setValue` / `commitValue(s)` from UI. Never mutate `ConfigManager.config` and expect it to persist.
- **Editors** (settings, bar, overlay, edge menus, keybinds, monitors) edit a `ConfigDraft` (a working copy of one config path; `save()` merges onto the latest config). Unsaved edits show live through `ConfigManager.setPreview(section, value)`; readers read `previews.X ?? config.X`. Selection lives in the manager and changes through its `select*()` (`selectBar`, `selectView`, `selectMenu`, `selectProfile`), which keeps what depends on it valid; views don't assign it.
- Secrets (chat API keys) never go in config.json or argv: `SecretsManager`, written through stdin. Clipboard history is never written to disk.
- Workspace switching and window focusing always go through `HyprlandManager.goToWorkspace` / `stepWorkspace` / `nthWorkspace` / `focusWindow`, never a direct `hl.dsp.focus`. Axiom's own `hyprctl eval`/dispatch calls are Lua (`hl.*`).
- State that must survive a QML reload lives in a `PersistentProperties` (JSON for arrays); small persisted state goes in `config/state/*.json` or `$XDG_STATE_HOME/axiom/`.

## Config

- `config/json/config.schema.json` is the single source of truth: shape, defaults, and the generated settings page. Adding a setting = a schema entry with a `default` + a reader property. Changing the layout of existing config = bump `version` + a `ConfigMigration` step + a test.
- Load pipeline: parse → `ConfigMigration.migrate` → `SchemaValidation.pruneUnknown` → `applyDefaults` → validate. Every default is filled, so **readers use no `??` fallbacks**.
- Readers are named for their section, with a `Config` suffix where the name is a type (`OSDConfig`, `OverlayConfig`, `LauncherConfig`, `NotificationsConfig`, `PopoutConfig`, `IconConfig`, `ChatConfig`, `WorkspacesConfig`, `LockscreenConfig`, …). `Paths` holds derived paths. A reader that also exposes the config as saved says so (`Bar.savedBars`, `ChatConfig.savedProviders`).
- Schema annotations drive the UI; prefer a new annotation to a hand-kept list in QML: `x-settings: false` (hide), `x-category` (ordered, with icons, by the root's `x-categories`), `x-group`/`x-order` (settings cards and order; also the bar and edge menu editors' field groups), `x-card`/`x-intro` (hand-built `views/settings/<Name>Card.qml` / `<Name>.qml`; `x-cardFolds` if the card folds), `x-beside` (a field shares a line with the one before it on its settings card), `x-showIf` (sibling value, or `/Dotted.path` from the root), `x-applyOnSave`, `x-options` (`colors`, `screens`, `languages`, …; `x-emptyLabel`, `x-allScreens`, `x-suggestions`), `x-unit`, `x-control`, `x-multiline`, `x-icon` (bar widgets, overlay modules and views), `x-defaultSize`/`x-hosts`/`x-required` on overlay modules (the lock screen is an opt-in host), `x-tool` (tool pages), `x-auto` (an integer's automatic value), `x-control: readonly`, `x-hypr*` for Hyprland options. `oneOf`s are discriminated by `type` (bar widgets, overlay views and modules).
- An empty monitor means the primary monitor everywhere (`General.screensNamed`), except in `General.primaryMonitor` itself.
- **Theme**: `Theme.base00`–`base0F` plus semantic names; `Theme.resolveColor(name)` for names from config. `config/json/theme-defaults.json` fills what a theme omits. Theme integrations (`scripts/theme_<key>.sh`) write only their own `axiom.*` file and never edit a user's config.
- **Animation**: every `duration:` is `Appearance.animFast` / `animNormal` / `animSlow`, never a literal; looping animations gate `running` on `Appearance.animations`. Only behaviour timings (cursor blink, timeouts, polling) are literals.

## Translation

- English source text, inline: `I18n.tr("Text")`, with placeholders for values (`I18n.tr("{0} updates", count)`), never template-string sentences.
- Dates through `I18n.formatDate(date, I18n.dateFormat("longDate" | …))`, never `Qt.formatDateTime`.
- Schema forms translate their own titles, descriptions and options. Keys chosen at runtime are declared in a comment as `I18n.tr("…")` so the checker sees them.
- A language is `config/i18n/<code>.json`. Logs, validation errors and migration notes stay English.

## UI conventions

- **Reuse before building.** Check the shared pieces (docs/architecture.md, "Shared UI pieces") before drawing a card, heading, chip, list row, dot, divider, drag or inspector; a second copy of a pattern becomes a shared piece.
- **Data-driven surfaces.** `Bars`, `Overlay.views`, `EdgeMenus`, `Dock.docks` and `OSD.osds` are arrays in config; surfaces are `Variants`/Repeaters over them, keyed by stable ids.
- **Loaded by name.** A bar widget is `bar/widgets/<type>.qml`; a popout or overlay module is `content/<Name>.qml`; a view is `views/<type>.qml`. A new one = the file + its schema `oneOf` entry (modules with a `place` property and, if a card is the wrong size to start at, `x-defaultSize`; sizes are in grid units, four to a card). Modules take any size: each sets `fullMinWidth`/`fullMinHeight` (px) and shows its compact figure below them. A widget opens a popout with a `PopoutAnchor { popoutName }`.
- **Content roots.** `Card` (free-form card) or `Panel` (a column, usable both as a bar popout and as a card: `embedded` is true in a card). Both expose `properties`, `slotRect`, `cols`/`rows`, `shape`, `compact`, `pad`, `host`; modules adapt their layout to `shape`/`compact`.
- **Overlay lifetime.** Only the current page and its neighbours exist, and only while the overlay is open. Acquire in `Component.onCompleted`, release in `onDestruction`, keep lasting state in a service.
- **Repeater models and `acquire()` requests come from config and tool availability only, never live values.** For derived item sets, model by a count or a joined string key. A model re-evaluated on every sample once pushed qs past 25 GB.
- **Adding a module to a live config**: confirm the schema reloaded first (a config validated against a stale schema falls back to defaults), add one at a time and watch qs's RSS.
- **Bar widgets are sized by their bar**: cross size `barConfig.widgetSize`; padding, spacing, font size and radius from `barConfig`, never `Widget.*` (which is for controls and panels outside the bar). Icon + label widgets extend `bar/widgets/BarIconWidget.qml`.
- **Radii**: `Appearance.borderRadius` only for outer edges (border, bars, pills, popout surfaces, the overlay box, windows); `Widget.radius` for anything inside.
- **Rounded clipping** (images, captures, anything cut to rounded corners) is Quickshell.Widgets' `ClippingRectangle` (set its `color`: it defaults to white), not a MultiEffect mask.
- **Icons** are Material Symbols names drawn by `reusable/StyledIcon`; an icon never shares a Text with a label.
- **Layer ordering** (bars, border, popouts, dock, edge menus, backdrop, screenshot) is set by Hyprland layer rules in `HyprlandManager.layerRulesLua`; see docs/architecture.md (Popouts) before changing how surfaces sit on an edge.
- **Edge collisions**: surfaces on one screen edge give way by rank (dock < OSD < floating edge menu) through `ShellManager.setEdgeClaim` / `edgeOutranked`; a new surface on an edge takes a rank there instead of checking the others itself.
- **Screen targeting**: surfaces are built on `General.screensFor(mode)`; only `ShellManager.isTarget(screen, mode)` answers shortcuts, IPC and OSD events. IPC handlers are `enabled` on the target instance only.
- **Launcher**: every provider returns rows `{ kind, image, glyph, title, usage, subtitle, hint, complete, run(shift) }`; a new command is an entry in `services/LauncherCommands.qml`. `/config` can never edit `Bars` or `Overlay.views`.
- **Lockscreen**: `LockManager.lock()` is the only way to lock. In `quickshell` mode only PAM success (`AuthManager`) unlocks: no IPC unlock, and nothing on the lock surface may run commands. Its modules are the ones whose `x-hosts` list `lockscreen`: add it only to a module that launches, dispatches and writes nothing and shows nothing private. The surface keeps a fallback password field for a layout without one.

## QML pitfalls (each has bitten)

- `StyledTextEntry` writes every keystroke back to `text`, dropping any binding: push the value in (on selection/draft changes, unless focused) and act on `onTextChanged` while focused.
- An object literal as a property value needs parentheses: `payload: ({ … })`; `payload: { … }` is a code block.
- Assigning a bound property (`currentIndex = i`) breaks its binding: change the source it's bound to instead.
- A derived type must not redeclare a property its base declares (it shadows the base's, e.g. an alias).
- `visible: visibleChildren.length > 0` locks itself hidden (children read invisible with their parent); use `children.length` or a flag.
- Signal parameters or properties typed `Item` that callers read custom members of trip qmllint (`missing-property`): type them `var`.
- A function-valued property (`labelOf: x => …`) works as a hook.

## Naming

- Services `*Manager`; readers per section; hosts say what they host (`BarWidgetHost`, `OverlaySlot`, `BarPopouts`); content by module type / popout name.
- Qt control stand-ins are `Styled*`; composites are named for what they are.
- Surface windows get a `Window` suffix when their shell entry shares the name (`shell/PowerMenu` → `PowerMenuWindow`).
- Root ids are `root`.
- Bar widget and content names may overlap (schema types), but no file may see both.

## Known housekeeping

- `views/settings/ChatProvidersCard` creates its own `ChatRequest` for Test/Fetch models (documented exception to services owning processes).
- The key recorder doesn't tell keypad keys apart or map AltGr.
