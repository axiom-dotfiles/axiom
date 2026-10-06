# Contributing

## Structure
```bash
shell.qml     # entrypoint: one top-level item per surface, plus services only reached by IPC
shell/        # top-level pieces instantiated by shell.qml
components/
  methods/    # pure singleton helpers (unit-tested)
  reusable/   # generic styled widgets, no feature-specific logic
  forms/      # schema-driven form widgets
  content/    # every loadable panel (overlay modules, bar popouts), loaded by name
  hosts/      # where content appears: bar/edge popouts, overlay cards and pages
  views/      # overlay pages, pieces in subfolders
  bar/        # the bar; bar/widgets/ = bar widget types
  surfaces/   # standalone windows (launcher, lockscreen, toasts, power menu, ...)
services/     # *Manager singletons owning state and side effects
config/       # config readers, the config schema, themes, translations
assets/       # static assets
examples/     # example setups (partial configs) applied from Settings → Maintenance
scripts/      # scripts run by the shell (theming, wallpaper, updates) and development tools
tests/        # unit tests (qmltestrunner) and script tests, run by scripts/check_all.sh and CI
```

## Conventions
- Import project code through the `qs.` namespace (`import qs.services`), never relative paths.
- Dependencies point one way: pure `methods/` → config readers → services (every process, file write and poll) → UI.
- New settings go in `config/json/config.schema.json` with a default, plus a reader property; the settings UI is generated from the schema. Prefer a schema annotation (`x-group`, `x-order`, `x-icon`, …) over a list kept in QML.
- Reuse the shared pieces (docs/architecture.md, "Shared UI pieces") instead of drawing another card, row, chip or drag; a pattern that appears twice becomes one.
- User-visible text is English, wrapped in `I18n.tr("...")` with placeholders for values; run `scripts/check_i18n.py` (and `--untranslated`) after changing text.
- Every animation duration is `Appearance.animFast`/`animNormal`/`animSlow`; outer edges use `Appearance.borderRadius`, anything inside `Widget.radius`; icons are Material Symbols names in `StyledIcon`.

## Example setups
- Build the setup in the shell, then copy only the parts `components/methods/ConfigExamples.qml` lists (`sections`) into `examples/<name>.json`, with a `_example` header: `{ "title": "…", "description": "…" }`.
- Leave out anything personal or machine-bound: no wallpapers, calendar accounts, chat providers or apps, and every `monitor` empty (the primary).
- `tests/tst_ConfigExamples.qml` loads every example the way the shell does, so `scripts/run_tests.sh ConfigExamples` tells you whether it's valid.

## Checks
- Format changed QML with `/usr/lib/qt6/bin/qmlformat -i` (see `.qmlformat.ini`; the `qmlformat` on PATH is Qt5's).
- Run `scripts/check_structure.py` after adding, renaming or moving files: types and popouts load by file name, so it catches a missing file or import before the shell does.
- Run `scripts/check_all.sh` before opening a pull request. It runs what CI runs: structure, qmlformat, qmllint (against `scripts/qmllint-baseline.json`), the unit tests in `tests/`, shellcheck, the script tests and the translation check. Changing a migration step or a `components/methods/` helper? Add a test for it.
- The checks don't run the shell: after saving, read `scripts/log.sh` (a clean reload is `Reloading configuration...` + `Configuration Loaded`).

[docs/architecture.md](docs/architecture.md) holds the mechanics of every service and surface, plus the index of shared UI pieces. Read the relevant section before changing a feature, and update it when you change how one works.
