# Contributing

## Organization Strategy

### Structure
```bash
shell.qml     # entrypoint: one top-level item per module
shell/        # top-level pieces instantiated by shell.qml
components/
  methods/    # pure singleton helpers
  reusable/   # generic styled widgets, no feature-specific logic
  forms/      # schema-driven form widgets
  content/    # every loadable panel (overlay modules, bar popouts), loaded by name
  hosts/      # where content appears: bar/edge popouts, overlay cards and pages
  views/      # overlay pages
  bar/        # the bar; bar/widgets/ = bar widget types
  surfaces/   # standalone windows (launcher, lockscreen, toasts, power menu, ...)
services/     # singletons owning global state and side effects
config/       # config reader singletons, the config schema, themes, translations
assets/       # static assets
scripts/      # scripts run by the shell (theming, wallpaper) and development tools
tests/        # unit tests (qmltestrunner) and script tests, run by scripts/check_all.sh and CI
```

### Conventions
- Import project code through the `qs.` namespace (`import qs.services`).
- New settings go in `config/json/config.schema.json` with a default, plus a reader property; the settings UI is generated from the schema.
- User-visible text is English, wrapped in `I18n.tr("...")`; run `scripts/check_i18n.py` (and `--untranslated`) after changing text.
- Run `scripts/check_structure.py` after adding, renaming or moving files: types and popouts load by file name, so it catches a missing file or import before the shell does.
- Format changed QML with `/usr/lib/qt6/bin/qmlformat -i` (see `.qmlformat.ini`).
- Run `scripts/check_all.sh` before opening a pull request. It runs what CI runs: structure, qmlformat, qmllint (against `scripts/qmllint-baseline.json`), the unit tests in `tests/`, shellcheck and the script tests. Changing a migration step or a `components/methods/` helper? Add a test for it.

See [CLAUDE.md](CLAUDE.md) for the architecture in detail.
