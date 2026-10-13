# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A [Quickshell](https://quickshell.org) desktop shell config (QML) for Hyprland (0.55+, Lua config), named "axiom": bar, notifications, lockscreen, launcher, overlay pages, edge menus, docks, OSD, power menu, workspace overview, screen border. No build step: `qs` interprets the QML at runtime.

This file holds only the rules. **The mechanics of every service and surface are in `docs/dev/`**, one short doc per topic (index: `docs/dev/README.md`). Each doc opens with its files, config and related docs. Read the relevant doc before changing a feature, and update it when you change how one works. Some directories have their own `CLAUDE.md` with local rules.

## Where to look

**Adding something of a known kind?** Follow its recipe in `docs/recipes/` (also skills in `.claude/skills/`): `bar-widget`, `bar-popout`, `overlay-module`, `overlay-view`, `settings-card`, `launcher-command`, `setting`, `config-section`, `migration`, `service`, `theme-integration`, `methods-helper`. Each names the files to touch and an existing file to copy.

| Task / area | Read |
|---|---|
| Any service, polling, `acquire`/`release` | `docs/dev/core/services-pattern.md` |
| Config loading, writes, drafts, previews | `docs/dev/core/config-manager.md`, `config-readers.md` |
| Schema `x-*` annotations (complete list) | `docs/dev/core/schema-annotations.md` |
| Settings page, saved configs, import/export | `docs/dev/core/settings-page.md`, `saved-configs-sharing.md` |
| A new editor (draft, selection, inspector) | `docs/dev/core/editors-pattern.md` |
| Before drawing any card, row, chip, drag | `docs/dev/core/shared-ui-pieces.md` |
| Bar, bar widgets, bar look | `docs/dev/bar/` |
| Popouts, edge surfaces, joins, collisions | `docs/dev/popouts/` (start at `surface-context.md`) |
| Overlay pages, modules, Layouts editor | `docs/dev/overlay/` |
| Edge menus | `docs/dev/edge-menus/` |
| Hyprland modes, binds, monitors, workspaces | `docs/dev/hyprland/` |
| Themes, integrations, wallpaper, blur | `docs/dev/theming/` |
| A feature (launcher, lockscreen, greeter, dock, OSD, chat, notes, calendar, …) | `docs/dev/features/<feature>.md` |
| Looking at or debugging the live shell | `docs/dev/testing.md` |
| Known problems not fixed yet (check before working in an area) | `docs/dev/issues.md` |
| **What a setting is, its default, who reads it** | `docs/dev/config/<Section>.md` (generated; `grep -rn 'Section.key' docs/dev/config/`) |
| A bar widget / overlay module / view type's settings | `docs/dev/config/{BarWidgets,OverlayModules,OverlayViews}/<Type>.md` (generated) |
| A service's or reader's public API | `docs/dev/generated/api/<Name>.md` (generated) |
| Which file does X / every IPC target | `docs/dev/generated/files.md`, `docs/dev/generated/ipc.md` (generated) |

**Found a problem outside the task?** Don't fix it unasked and don't only mention it: add an entry to `docs/dev/issues.md` (its format is at the top), and tell the user you did. Remove an entry in the change that fixes it.

## Running / reloading

- **After any change run `scripts/dev/verify.sh`** (formats, checks, regenerates docs, runs the affected tests, shows the shell's log; `--all` runs every CI check) until it prints `verify ok`. **To look at something**: `scripts/dev/shot.sh page <ViewType>` / `launcher [text]` / `ipc <target> <open> [close]` prints a screenshot's path.
- The shell runs detached; never start/stop it from this session. Saving a file it has loaded hot-reloads it. qs watches by inode: after `sed -i`, `qmlformat -i` or `git checkout`, see `docs/dev/testing.md` to force a reload.
- **Logs**: `scripts/log.sh` (warnings/errors since the last reload; `--debug` adds `console.log`, `--all`, `-f`, `-g PATTERN`). A clean reload is just `Reloading configuration...` + `Configuration Loaded`. stdout/journalctl show nothing. `console.log` for tracing, `console.warn` only for real problems.
- A settings category has no IPC: add a temporary `IpcHandler` calling `SettingsManager.openCategory(name)` to `shell.qml` (never inside a singleton), and revert it in place.
- `config/user/config.json` is owned by the settings UI but may be edited directly to test. `ConfigManager` watches it; an invalid file never replaces the running config (the last good one stays and `savesBlocked` refuses saves until it's fixed).
- New singletons are picked up by a hot reload (qs 0.3.1). A new *directory* imported only from URL-loaded files isn't scanned until qs restarts (`module "qs.…" is not installed`): ask the user to restart.
- URL-loaded files (bar widgets, content, views) only see sibling types because some loaded file imports their directory by name (`BarWidgetHost` → `qs.components.bar.widgets`, `BarPopouts`/`OverlaySlot` → `qs.components.content`, `OverlayPanel` → `qs.components.views`).
- File reads go through `FileManager.read`; `XMLHttpRequest` is only for HTTP. Rewrite watched JSON (`config/i18n/*.json`, config.json) atomically (temp file + rename): a half-written file gets read.

## Never, while testing

- Lock the built-in locker (only the user can type the password). Test `LockSurface` in a hidden window.
- Simulate cursor movement to verify UI. Check logs and reason through bindings instead.
- Switch the real Hyprland config into or out of `managed` mode, or out of `included` (leaving one gives hyprland.lua back or empties the module; test `claim_hyprland.sh` on scratch dirs), Keep a monitor layout, `apply` a self-update on the live repo, delete the real config.json (use `ipc call onboarding goTo <n>`), or enable `Idle` on the live config without asking (it replaces the user's hypridle).
- Apply a theme integration's hookup to the real configs (run `integration_hookup.py` with a scratch `HOME`/`XDG_CONFIG_HOME`).
- Install, update or remove the greeter for real, or restart greetd (it ends the session). Test `scripts/greeter/greeter_install.sh` with a scratch `AXIOM_GREETER_ROOT`, and look at the greeter with `AXIOM_GREETER=1 AXIOM_GREETER_WINDOWED=1 AXIOM_GREETER_DIR=<scratch> qs -p "$PWD/greeter.qml"` (a window; `qs kill` only that instance).
- The user's `~/.config/hypr/user/` is a symlink to `~/repos/dotfiles/hypr/user`.

## Checks

All run in CI; `scripts/dev/verify.sh --all` (= `scripts/check_all.sh`) runs every one, and `scripts/dev/verify.sh` the ones a change touches. None of them run the shell, so still read the log. Rules they don't enforce for you:
- `scripts/check_structure.py` doesn't check `x-card`/`x-intro` files: check those exist yourself. Run it after adding, renaming or moving QML files.
- `scripts/run_tests.sh [Name…]` (`tests/tst_<Name>.qml`; schema defaults and `ConfigMigration` are `tst_Config`): add a case when changing a methods helper or a migration step.
- `scripts/check_qmllint.py` fails on warnings not in `scripts/qmllint-baseline.json`. Fix new warnings; `--update-baseline` only for Quickshell type-info gaps, or when it reports baselined warnings gone.
- `scripts/check_i18n.py --fill` after changing user-visible text or a schema title/description.
- `scripts/check_docs.py` fails on a hand-written doc citing a path or `Singleton.member` that's gone: fix the doc with the code.
- `docs/dev/config/` and `docs/dev/generated/` come from `scripts/gen_docs.py` (verify.sh and the pre-commit hook rebuild them; CI fails when stale). Never edit them by hand.

## Formatting

- verify.sh formats changed QML (Qt 6's qmlformat, `.qmlformat.ini`), writing in place. Don't use `qmlformat -i` (it replaces the inode); the `qmlformat` on PATH is Qt5's and fails silently.
- The QML JS engine has no `Array.prototype.flatMap` (use `[].concat(...arr.map(...))`), no `Object.fromEntries` (use `reduce`) and no `Intl`.
- Each QML file has a short purpose comment above its root object (`check_structure` enforces it; it feeds `docs/dev/generated/files.md`).
- A config read grep can't see (by key name, a whole object handed to a helper) gets a `// reads: Section.path, …` comment (`*` matches any part) so the config reference finds it.

## Layout

```
shell.qml       entrypoint: one top-level Item per surface, plus `_services` (services only reached by IPC)
shell/          top-level pieces, one per surface
components/
  methods/      pure singleton helpers (no files, processes, dispatches or qs.* imports; unit-tested)
  reusable/     generic Styled* widgets, no feature logic
  forms/        schema-driven form widgets (SchemaField, SchemaPropertiesForm, …)
  content/      loadable panels, by name: overlay module types and bar popouts (base/: Card, Panel, TitledCard; parts/: helpers)
  hosts/        where content appears: popout/ (bar + edge popouts, submenus) and overlay/ (pages, the module grid, slots)
  views/        overlay pages by view type, with their pieces in subfolders
  bar/          the bar; widgets/ = bar widget types
  surfaces/     standalone windows (launcher, lockscreen, toasts, dock, onboarding, screenshot, …)
services/       pragma Singleton managers: state and side effects
config/         config reader singletons; json/ (schema, theme defaults, emoji), themes/, i18n/, user/ (live config, gitignored), state/
scripts/        external scripts (theming, wallpaper, self-update, Hyprland claim) and the dev checks
tests/          qmltestrunner tests, fixtures, tests/scripts/
docs/dev/       developer docs, one per topic
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
- **Anything polled goes through `acquire(owner, request)` / `release(owner)`** (a `ConsumerRegistry`): fetched once for all consumers, at the shortest interval asked (or a configured one), not at all with none. Acquire in `Component.onCompleted` (again when the config-derived request changes; identical requests are no-ops), release in `onDestruction`. Which services work this way: `docs/dev/core/services-pattern.md`.
- **Config writes** go only through `ConfigManager.setTheme` / `setWallpaper(s)` / `saveConfig` / `commit(object)` (validates first; returns false and changes nothing if rejected), or `SettingsManager.setValue` / `commitValue(s)` from UI. Never mutate `ConfigManager.config` and expect it to persist.
- **Editors** (settings, bar, overlay, edge menus, keybinds, monitors, screen layouts) edit a `ConfigDraft`; unsaved edits show live through `ConfigManager.setPreview(section, value)` and readers read `previews.X ?? config.X`. Selection lives in the manager and changes through its `select*()` (`selectBar`, `selectView`, `selectMenu`, `selectProfile`); views don't assign it. See `docs/dev/core/editors-pattern.md`.
- Secrets (chat API keys, calendar passwords) never go in config.json or argv: `SecretsManager`, written through stdin. Clipboard history is never written to disk; only clips the user pins are (`config/state/clipboardPins.json`).
- Workspace switching and window focusing always go through `HyprlandManager.goToWorkspace` / `stepWorkspace` / `nthWorkspace` / `focusWindow`, never a direct `hl.dsp.focus`. Axiom's own `hyprctl eval`/dispatch calls are Lua (`hl.*`).
- State that must survive a QML reload lives in a `PersistentProperties` (JSON for arrays); small persisted state goes in `config/state/*.json` or `$XDG_STATE_HOME/axiom/`.

## Config

- `config/json/config.schema.json` is the single source of truth: shape, defaults, and the generated settings page. Adding a setting = a schema entry with a `default` + a reader property. Changing the layout of existing config = bump `version` + a `ConfigMigration` step + a test. **Edit the schema before the migration**: a migration saved first hot-reloads against the old schema and loses the user's values.
- Every default is filled at load (`docs/dev/core/config-manager.md`), so **readers use no `??` fallbacks**.
- Readers are named for their section, with a `Config` suffix where the name is a type (`OSDConfig`, `OverlayConfig`, `LauncherConfig`, …). `Paths` holds derived paths. A reader that also exposes the config as saved says so (`Bar.savedBars`, `ChatConfig.savedProviders`).
- **Schema annotations drive the UI; prefer a new annotation to a hand-kept list in QML.** The complete list is `docs/dev/core/schema-annotations.md`. The ones with rules attached:
  - `x-scope` (`look`/`personal`/`machine`, inherited, root `machine`) is what an example, import or export carries: a new setting inside a look section that names a monitor, path, account or command needs `machine`/`personal`.
  - `x-takeover` marks a setting that takes something over on this PC (Hyprland mode, locker, idle, polkit, greeter): loading or importing a config never changes it, only its own card does.
  - `x-hosts` on overlay modules: the lock screen and the greeter are opt-in hosts (see UI conventions).
  - `oneOf`s are discriminated by `type` (bar widgets, overlay views and modules).
- An empty monitor means the primary monitor everywhere (`General.screensNamed`), except in `General.primaryMonitor` itself.
- **Theme**: `Theme.base00`–`base0F` plus semantic names; `Theme.resolveColor(name)` for names from config. `config/json/theme-defaults.json` fills what a theme omits. Theme integrations write only their own `axiom.*` file; only the hookup's Apply (on the user's click) edits a user's config (`scripts/CLAUDE.md`).
- **Animation**: every `duration:` is `Appearance.animFast` / `animNormal` / `animSlow`, never a literal, eased with `Appearance.easing` (a property's Behavior is `Glide on x {}` / `ColorGlide`); looping animations gate `running` on `Appearance.animations`. Only behaviour timings (cursor blink, timeouts, polling) are literals. Bar geometry animates what's drawn, never what's measured (`docs/dev/bar/composition.md`); content changing in place cross-fades through `CrossFade`.

## Translation

- English source text, inline: `I18n.tr("Text")`, with placeholders for values (`I18n.tr("{0} updates", count)`), never template-string sentences.
- Dates through `I18n.formatDate(date, I18n.dateFormat("longDate" | …))`, never `Qt.formatDateTime`.
- Schema forms translate their own titles, descriptions and options. Keys chosen at runtime are declared in a comment as `I18n.tr("…")` so the checker sees them.
- A language is `config/i18n/<code>.json`. Logs, validation errors and migration notes stay English.

## UI conventions

- **Reuse before building.** Check `docs/dev/core/shared-ui-pieces.md` before drawing a card, heading, chip, list row, dot, divider, drag or inspector; a second copy of a pattern becomes a shared piece.
- **Data-driven surfaces.** `Bars`, `Overlay.views`, `EdgeMenus`, `Dock.docks` and `OSD.osds` are arrays in config; surfaces are `Variants`/Repeaters over them, keyed by stable ids.
- **Loaded by name.** A bar widget is `bar/widgets/<type>.qml`; a popout or overlay module is `content/<Name>.qml`; a view is `views/<type>.qml`. A new one = the file + its schema `oneOf` entry. Directory rules: the `CLAUDE.md` in `components/bar/widgets/`, `components/content/`, `components/views/`.
- **Overlay lifetime.** Only the current page and its neighbours exist, and only while the overlay is open. Acquire in `Component.onCompleted`, release in `onDestruction`, keep lasting state in a service.
- **Repeater models and `acquire()` requests come from config and tool availability only, never live values.** For derived item sets, model by a count or a joined string key. A model re-evaluated on every sample once pushed qs past 25 GB.
- **Adding a module to a live config**: confirm the schema reloaded first (a config validated against a stale schema falls back to defaults), add one at a time and watch qs's RSS.
- **Radii**: `Appearance.borderRadius` only for outer edges (border, bars, pills, popout surfaces, the overlay box, windows); `Widget.radius` for anything inside.
- **Rounded clipping** (images, captures, anything cut to rounded corners) is Quickshell.Widgets' `ClippingRectangle` (set its `color`: it defaults to white), not a MultiEffect mask.
- **Icons** are Material Symbols names drawn by `reusable/StyledIcon`; an icon never shares a Text with a label.
- **Layer ordering** (bars, border, popouts, dock, edge menus, backdrop, screenshot) is set by Hyprland layer rules in `HyprlandManager.layerRulesLua`; read `docs/dev/bar/layering-and-corners.md` and `docs/dev/popouts/` before changing how surfaces sit on an edge. Bars and the border must never draw over a fullscreen window (`docs/dev/testing.md`).
- **Popout geometry** comes only from `methods/SurfaceContext` (via `EdgePlacement`/`EdgeSurface`): a new case is a `SurfaceContext` rule + a `tst_SurfaceContext` row, never a rule in a host. See `components/hosts/popout/CLAUDE.md`.
- **Popout collisions**: every popout holds a `PopoutClaim` in `PopoutManager` and never checks the others itself; an open popout never moves. See `docs/dev/popouts/registry.md`.
- **Screen targeting**: surfaces are built on `General.screensFor(mode, name)` (or `General.outputs`, never `Quickshell.screens`: it holds stand-ins while no monitor is connected); only `ShellManager.isTarget(screen, mode)` answers shortcuts, IPC and OSD events. IPC handlers are `enabled` on the target instance only.
- **Launcher**: every provider returns the same row shape (`docs/dev/features/launcher.md`); a new command is an entry in `services/LauncherCommands.qml`. `/config` can never edit `Bars` or `Overlay.views`.
- **Greeter** (`docs/dev/features/greeter-runtime.md`): reads only the exported bundle (data, never code). In greeter mode (`Paths.greeter`) nothing writes config, generates or runs integrations: a new side effect reachable from it checks `Paths.greeter`. Greeter modules are inert unless `host.kind === "greeter" && !host.preview && Paths.greeter`; only `GreetdManager` talks to greetd.
- **Lockscreen**: `LockManager.lock()` is the only way to lock; in `quickshell` mode only PAM success (`AuthManager`) unlocks, never IPC. `lockscreen` goes in a module's `x-hosts` only if it launches, dispatches and writes nothing and shows nothing private; the one exception is `Power` (`ShellManager.sessionAction`, never logout). The surface keeps a fallback password field for a layout without one.

## QML pitfalls (each has bitten)

- `StyledTextEntry` writes every keystroke back to `text`, dropping any binding: push the value in (on selection/draft changes, unless focused) and act on its `textEdited` (typing only, never a value pushed in). A field that commits on focus loss commits only if `typed`, or text it was left showing lands on whatever it edits by then.
- An object literal as a property value needs parentheses: `payload: ({ … })`; `payload: { … }` is a code block.
- Assigning a bound property (`currentIndex = i`) breaks its binding: change the source it's bound to instead.
- A derived type must not redeclare a property its base declares (it shadows the base's, e.g. an alias).
- `visible: visibleChildren.length > 0` locks itself hidden (children read invisible with their parent); use `children.length` or a flag.
- Signal parameters or properties typed `Item` that callers read custom members of trip qmllint (`missing-property`): type them `var`.
- A function-valued property (`labelOf: x => …`) works as a hook.
- A `MultiEffect` handed a visible item's own layer (`layer.enabled` source) pads that layer and redraws the item shrunk and offset; handed a `ShaderEffectSource` with `autoPaddingEnabled`, it stretches it. Shadows of visible surfaces go through `OutsideShadow` (explicit padding).
- In a URL-loaded file, an inline `component A` using another inline `component B` of the same file fails with "A is not a type": inline B's body.

## Naming

- Services `*Manager`; readers per section; hosts say what they host (`BarWidgetHost`, `OverlaySlot`, `BarPopouts`); content by module type / popout name.
- Qt control stand-ins are `Styled*`; composites are named for what they are.
- Surface windows get a `Window` suffix when their shell entry shares the name (`shell/PowerMenu` → `PowerMenuWindow`).
- Root ids are `root`.
- Bar widget and content names may overlap (schema types), but no file may see both.

## Known housekeeping

- `views/settings/ChatProvidersCard` creates its own `ChatRequest` for Test/Fetch models (documented exception to services owning processes).
