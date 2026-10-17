# AGENTS.md

The rules for working on axiom, for contributors and coding agents alike. `CLAUDE.md` only imports this file.

## What this is

A [Quickshell](https://quickshell.org) desktop shell config (QML) for Hyprland (0.55+, Lua config), named "axiom": bar, notifications, lockscreen, launcher, overlay pages, edge menus, docks, OSD, power menu, workspace overview, screen border. No build step: `qs` interprets the QML at runtime.

This file holds only the rules. **The mechanics of every service and surface are in `docs/dev/`**, one short doc per topic (index: `docs/dev/README.md`). Each doc opens with its files, config and related docs. Read the relevant doc before changing a feature, and update it when you change how one works. Some directories have their own `AGENTS.md` with local rules.

## Where to look

**Adding something of a known kind?** Follow its recipe in `docs/recipes/` (also skills in `.claude/skills/`): `bar-widget`, `bar-popout`, `overlay-module`, `overlay-view`, `settings-card`, `launcher-command`, `setting`, `config-section`, `migration`, `service`, `theme-integration`, `methods-helper`, `compositor-backend`. Each names the files to touch and an existing file to copy.

| Task / area | Read |
|---|---|
| Any service, polling, `acquire`/`release` | `docs/dev/core/services-pattern.md` |
| Config loading, writes, drafts, previews, where files live (XDG) | `docs/dev/core/config-manager.md`, `config-readers.md` |
| Schema `x-*` annotations (complete list) | `docs/dev/core/schema-annotations.md` |
| Settings page, saved configs, import/export | `docs/dev/core/settings-page.md`, `saved-configs-sharing.md` |
| A new editor (draft, selection, inspector) | `docs/dev/core/editors-pattern.md` |
| Before drawing any card, row, chip, drag | `docs/dev/core/shared-ui-pieces.md` |
| Bar, bar widgets, bar look | `docs/dev/bar/` |
| Popouts, edge surfaces, joins, collisions | `docs/dev/popouts/` (start at `surface-context.md`) |
| Overlay pages, modules, Layouts editor | `docs/dev/overlay/` |
| Edge menus | `docs/dev/edge-menus/` |
| Windows, outputs, workspaces, focus; what a compositor supports; sway/niri | `docs/dev/compositor/` |
| Config modes (detached / included / managed), the config writer | `docs/dev/compositor/config-modes.md` |
| Hyprland's writer, binds, monitors, workspaces | `docs/dev/hyprland/` |
| Themes, integrations, wallpaper, blur | `docs/dev/theming/` |
| A feature (launcher, lockscreen, greeter, dock, OSD, chat, notes, calendar, …) | `docs/dev/features/<feature>.md` |
| Looking at or debugging the live shell | `docs/dev/testing.md` |
| Known problems not fixed yet (check before working in an area) | `docs/dev/issues.md` |
| **What a setting is, its default, who reads it** | `docs/dev/config/<Section>.md` (generated; `grep -rn 'Section.key' docs/dev/config/`) |
| A bar widget / overlay module / view type's settings | `docs/dev/config/{BarWidgets,OverlayModules,OverlayViews}/<Type>.md` (generated) |
| A service's or reader's public API | `docs/dev/generated/api/<Name>.md` (generated) |
| Which file does X | `grep -n '<word>' docs/dev/generated/files.md` (generated, ~700 lines: grep it, never read it whole) |
| Every IPC target / every layer's stacking order | `docs/dev/generated/ipc.md`, `docs/dev/generated/layers.md` (generated) |

**Found a problem outside the task?** Don't fix it unasked and don't only mention it: add an entry to `docs/dev/issues.md` (its format is at the top), and tell the user you did. Quote a log warning's message in backticks under **What** so `verify.sh` marks that line `(known: …)`. Remove an entry in the change that fixes it.

## Running / reloading

- **After any change run `scripts/dev/verify.sh`** (formats, checks, regenerates docs, runs the affected tests, shows the shell's log with known issues marked, lists the docs describing what you changed; `--all` runs every CI check) until it prints `verify ok`. Read the docs it lists if behaviour changed. **To look at something**: `scripts/dev/shot.sh page <ViewType>` / `launcher [text]` / `ipc <target> <open> [close]` prints a screenshot's path.
- The shell runs detached; never start/stop it from this session. Saving a file it has loaded hot-reloads it. qs watches by inode: after `sed -i`, `qmlformat -i` or `git checkout`, see `docs/dev/testing.md` to force a reload. A second axiom runs only nested, under another compositor, through `scripts/dev/nested.sh <sway|niri>` (scratch folders, its own D-Bus; `docs/dev/compositor/sway-backend.md`).
- **Logs**: `scripts/log.sh` (warnings/errors since the last reload; `--debug` adds `console.log`, `--all`, `-f`, `-g PATTERN`). A clean reload is just `Reloading configuration...` + `Configuration Loaded`. stdout/journalctl show nothing. `console.log` for tracing, `console.warn` only for real problems.
- A settings category has no IPC: add a temporary `IpcHandler` calling `SettingsManager.openCategory(name)` to `shell.qml` (never inside a singleton), and revert it in place.
- `~/.config/axiom/config.json` is owned by the settings UI but may be edited directly to test. `ConfigManager` watches it; an invalid file never replaces the running config (the last good one stays and `savesBlocked` refuses saves until it's fixed).
- New singletons are picked up by a hot reload (qs 0.3.1). A new *directory* imported only from URL-loaded files isn't scanned until qs restarts (`module "qs.…" is not installed`): ask the user to restart.
- URL-loaded files (bar widgets, content, views) only see sibling types because some loaded file imports their directory by name (`BarWidgetHost` → `qs.components.bar.widgets`, `BarPopouts`/`OverlaySlot` → `qs.components.content`, `OverlayPanel` → `qs.components.views`).
- File reads go through `FileManager.read`; `XMLHttpRequest` is only for HTTP. Rewrite watched JSON (`config/i18n/*.json`, config.json) atomically (temp file + rename): a half-written file gets read.

## Never, while testing

Enforced by `.claude/hooks/guard.py` (a PreToolUse hook in `.claude/settings.json`, plus its `permissions.deny`; tests: `tests/scripts/test_guard.py`). A refusal names the rule it breaks: don't work around it, ask the user. Add a rule there when you add one here.

- Lock the built-in locker (only the user can type the password). Test `LockSurface` in a hidden window.
- Simulate cursor movement to verify UI. Check logs and reason through bindings instead.
- Switch the real compositor config (Hyprland's or sway's, `Compositor.mode`) into or out of `managed` mode, or out of `included` (leaving one gives the config back or empties the module; test the `claim_*.sh` and `merge_*_binds.py remove` scripts on scratch dirs), allow a takeover for the user (`CompositorConfigManager.allowTakeover`, the card's Allow), Keep a monitor layout, `apply` a self-update on the live repo, delete the real config.json (use `ipc call onboarding goTo <n>`), or enable `Idle` on the live config without asking (it replaces the user's hypridle).
- Apply a theme integration's hookup to the real configs (run `integration_hookup.py` with a scratch `HOME`/`XDG_CONFIG_HOME`).
- Install, update or remove the greeter for real, or restart greetd (it ends the session). Test `scripts/greeter/greeter_install.sh` with a scratch `AXIOM_GREETER_ROOT`, and look at the greeter with `AXIOM_GREETER=1 AXIOM_GREETER_WINDOWED=1 AXIOM_GREETER_DIR=<scratch> qs -p "$PWD/greeter.qml"` (a window; `qs kill` only that instance).
- The user's `~/.config/hypr/user/` is a symlink to `~/repos/dotfiles/hypr/user`.

## Checks

All run in CI; `scripts/dev/verify.sh --all` (= `scripts/check_all.sh`) runs every one, and `scripts/dev/verify.sh` the ones a change touches. None of them run the shell, so still read the log. Rules they don't enforce for you:
- `scripts/check_structure.py` doesn't check `x-card`/`x-intro` files: check those exist yourself. Run it after adding, renaming or moving QML files.
- `scripts/run_tests.sh [Name…]` (`tests/tst_<Name>.qml`; schema defaults and `ConfigMigration` are `tst_Config`): add a case when changing a methods helper or a migration step.
- `scripts/check_qmllint.py` fails on warnings not in `scripts/qmllint-baseline.json`. Fix new warnings; `--update-baseline` only for Quickshell type-info gaps, or when it reports baselined warnings gone.
- `scripts/check_i18n.py --fill` after changing user-visible text or a schema title/description, then translate the empty entries it added; `--prune` drops entries no longer used. It writes the files atomically in their one format (2-space JSON); edit them some other way and it reports `format` (`--format` fixes it).
- `scripts/check_docs.py` fails on a hand-written doc citing a path or `Singleton.member` that's gone: fix the doc with the code.
- `docs/dev/config/` and `docs/dev/generated/` come from `scripts/gen_docs.py` (verify.sh and the pre-commit hook rebuild them; CI fails when stale; verify.sh warns when the hook isn't set up: `git config core.hooksPath .githooks`). Never edit them by hand.
- `scripts/check_doc_drift.py` (warnings only) lists docs whose `Files:` changed in 5+ commits since the doc did: they may describe old code. Reread one against the code before relying on it, and touch it (fix or confirm) to reset the count.

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
config/         config reader singletons; json/ (schema, theme defaults, emoji), themes/, i18n/ (user data and state live in the XDG folders: docs/dev/core/config-manager.md)
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
- **A decision a methods helper makes** (`BarEnds`, `SurfaceContext`, `EdgeAttach`, `GridPlacement`, …) is read from its output, never worked out again in a host from `vertical`, a location or a kind: a new case is a rule in the helper plus a test row.

## Services

- One `pragma Singleton QtObject` per domain, named `*Manager`, exposing readonly properties, signals and functions. Non-singleton helpers are named for what they are (`ConfigDraft`, `GridEditor`, `ConsumerRegistry`, `WeatherSource`, `ChatRequest`, `DailySchedule`).
- Don't shadow Quickshell singletons: `NetworkingManager`, `BluetoothManager`, not `Networking`/`Bluetooth`.
- A service with an IPC target that nothing else references is created from `shell.qml`'s `_services`.
- **Anything polled goes through `acquire(owner, request)` / `release(owner)`** (a `ConsumerRegistry`): fetched once for all consumers, at the shortest interval asked (or a configured one), not at all with none. Acquire in `Component.onCompleted` (again when the config-derived request changes; identical requests are no-ops), release in `onDestruction`. Which services work this way: `docs/dev/core/services-pattern.md`.
- **Config writes** go only through `ConfigManager.setTheme` / `setWallpaper(s)` / `saveConfig` / `commit(object)` (validates first; returns false and changes nothing if rejected), or `SettingsManager.setValue` / `commitValue(s)` from UI. Never mutate `ConfigManager.config` and expect it to persist.
- **Editors** (settings, bar, overlay, edge menus, keybinds, monitors, screen layouts) edit a `ConfigDraft`; unsaved edits show live through `ConfigManager.setPreview(section, value)` and readers read `previews.X ?? config.X`. Selection lives in the manager and changes through its `select*()` (`selectBar`, `selectView`, `selectMenu`, `selectProfile`); views don't assign it. See `docs/dev/core/editors-pattern.md`.
- Secrets (chat API keys, calendar passwords) never go in config.json or argv: `SecretsManager`, written through stdin. Clipboard history is never written to disk; only clips the user pins are (`~/.local/state/axiom/ui/clipboardPins.json`).
- **The compositor is reached only through `CompositorManager`** (`docs/dev/compositor/README.md`): its windows, outputs and workspaces (neutral shapes, never a compositor's own objects), its signals, and every workspace switch and window focus (`goToWorkspace` / `stepWorkspace` / `nthWorkspace` / `focusWindow`, never a direct dispatch). Its backend (`HyprlandManager`) is the only one talking to the compositor; only the `Hyprland*` services import `Quickshell.Hyprland` or send Lua (`hl.*`), and only the Hyprland-only features (config modes, Keybinds, Monitors, the switcher) use `HyprlandManager` directly (`check_structure` enforces both).
- **Gate on a capability, not a compositor**: `CompositorManager.supports.<key>` in code, `"/$supports.<key>": true` in a schema `x-showIf`, `x-needs` on a page type. Nothing writes Hyprland's config unless `supports.configModes`. Surfaces closing on an outside click use `FocusGrab`.
- State that must survive a QML reload lives in a `PersistentProperties` (JSON for arrays); small persisted state goes in `StateManager` (`~/.local/state/axiom/ui/*.json`) or `Paths.userStatePath`.
- **Nothing is written under `Paths.axiomPath`** (a package installs it read-only): what axiom writes goes in the XDG folders through `Paths.userConfigPath` / `statePath` / `userStatePath` / `userDataPath` / `generatedThemesPath` (`docs/dev/core/config-manager.md` › Where files live).

## Config

- `config/json/config.schema.json` is the single source of truth: shape, defaults, and the generated settings page. Adding a setting = a schema entry with a `default` + a reader property. Changing the layout of existing config = bump `version` + a `ConfigMigration` step + a test. **Edit the schema before the migration**: a migration saved first hot-reloads against the old schema and loses the user's values.
- Every default is filled at load (`docs/dev/core/config-manager.md`), so **readers use no `??` fallbacks**.
- Readers are named for their section, with a `Config` suffix where the name is a type (`OSDConfig`, `OverlayConfig`, `LauncherConfig`, …). `Paths` holds derived paths. A reader that also exposes the config as saved says so (`Bar.savedBars`, `ChatConfig.savedProviders`).
- **Schema annotations drive the UI; prefer a new annotation to a hand-kept list in QML.** The complete list is `docs/dev/core/schema-annotations.md`. The ones with rules attached:
  - `x-scope` (`look`/`personal`/`machine`, inherited, root `machine`) is what an example, import or export carries: a new setting inside a look section that names a monitor, path, account or command needs `machine`/`personal`.
  - `x-takeover` marks a setting that takes something over on this PC (compositor mode, locker, idle, polkit, greeter): loading or importing a config never changes it, only its own card does.
  - `x-hosts` on overlay modules: the lock screen and the greeter are opt-in hosts (see UI conventions).
  - `oneOf`s are discriminated by `type` (bar widgets, overlay views and modules).
- An empty monitor means the primary monitor everywhere (`General.screensNamed`), except in `General.primaryMonitor` itself.
- A path setting may hold `~` (typed, or handed back by a Browse button as `~/…`): it's expanded (`Paths.expandHome`) before it reaches a process or a file read, in its reader or, for widget/module options, the service that uses it. Processes run without a shell, so nothing else expands it.
- **Theme**: `Theme.base00`–`base0F` plus semantic names; `Theme.resolveColor(name)` for names from config. `config/json/theme-defaults.json` fills what a theme omits. Theme integrations write only their own `axiom.*` file; only the hookup's Apply (on the user's click) edits a user's config (`scripts/AGENTS.md`).
- **Animation**: every `duration:` is `Appearance.animFast` / `animNormal` / `animSlow`, never a literal, eased with `Appearance.easing` (a property's Behavior is `Glide on x {}` / `ColorGlide`); looping animations gate `running` on `Appearance.animations`. Only behaviour timings (cursor blink, timeouts, polling) are literals. Bar geometry animates what's drawn, never what's measured (`docs/dev/bar/composition.md`); content changing in place cross-fades through `CrossFade`.

## Translation

- English source text, inline: `I18n.tr("Text")`, with placeholders for values (`I18n.tr("{0} updates", count)`), never template-string sentences.
- Dates through `I18n.formatDate(date, I18n.dateFormat("longDate" | …))`, never `Qt.formatDateTime`.
- Schema forms translate their own titles, descriptions and options. Keys chosen at runtime are declared in a comment as `I18n.tr("…")` so the checker sees them.
- A language is `config/i18n/<code>.json`. Logs, validation errors and migration notes stay English.

## UI conventions

- **Reuse before building.** Check `docs/dev/core/shared-ui-pieces.md` before drawing a card, heading, chip, list row, dot, divider, drag or inspector; a second copy of a pattern becomes a shared piece.
- **Data-driven surfaces.** `Bars`, `Overlay.views`, `EdgeMenus`, `Dock.docks` and `OSD.osds` are arrays in config; surfaces are `Variants`/Repeaters over them, keyed by stable ids.
- **Loaded by name.** A bar widget is `bar/widgets/<type>.qml`; a popout or overlay module is `content/<Name>.qml`; a view is `views/<type>.qml`. A new one = the file + its schema `oneOf` entry. Directory rules: the `AGENTS.md` in `components/bar/widgets/`, `components/content/`, `components/views/`.
- **Repeater models and `acquire()` requests come from config and tool availability only, never live values.** For derived item sets, model by a count or a joined string key. A model re-evaluated on every sample once pushed qs past 25 GB.
- **Radii**: `Appearance.borderRadius` only for outer edges (border, bars, pills, popout surfaces, the overlay box, windows); `Widget.radius` for anything inside.
- **Rounded clipping** (images, captures, anything cut to rounded corners) is Quickshell.Widgets' `ClippingRectangle` (set its `color`: it defaults to white), not a MultiEffect mask.
- **Icons** are Material Symbols names drawn by `reusable/StyledIcon`; an icon never shares a Text with a label.
- **Screen targeting**: surfaces are built on `General.screensFor(mode, name)` (or `General.outputs`, never `Quickshell.screens`: it holds stand-ins while no monitor is connected); only `ShellManager.isTarget(screen, mode)` answers shortcuts, IPC and OSD events. IPC handlers are `enabled` on the target instance only.

Subsystem rules live with their code; each line here is the invariant and where the rest is:
- **Overlay modules**: exist only while their page is shown (acquire/release, lasting state in a service); add them to a live config one at a time: `components/content/AGENTS.md`.
- **Bars, layer ordering, corners**: stacking is `LayerStack.layers` (`docs/dev/generated/layers.md`; axiom places its layers itself: `docs/dev/compositor/layer-arrangement.md`); which bar owns a corner is `BarEnds` alone; bars and the border never draw over fullscreen: `components/bar/AGENTS.md`.
- **Popouts**: geometry only from `methods/SurfaceContext`, collisions only through a `PopoutClaim`, an open popout never moves: `components/hosts/popout/AGENTS.md`.
- **Launcher**: one row shape for every provider; `/config` can never edit `Bars` or `Overlay.views`: `services/AGENTS.md`, `docs/dev/features/launcher.md`.
- **Greeter**: data, never code; a side effect reachable from greeter mode checks `Paths.greeter`: `services/AGENTS.md`, `docs/dev/features/greeter-runtime.md`.
- **Lockscreen**: `LockManager.lock()` only; only PAM unlocks, never IPC; `lockscreen` in `x-hosts` only for modules that do and show nothing risky: `services/AGENTS.md`, `components/content/AGENTS.md`, `docs/dev/features/lockscreen.md`.

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
