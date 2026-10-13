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

## Rules
The project's rules live in [AGENTS.md](AGENTS.md), plus an `AGENTS.md` in directories with local rules (`services/`, `config/`, `components/content/`, …). They're written for people and coding agents alike, and kept in one place so they don't drift between copies: read them before your first change. Step-by-step recipes for adding the common kinds of things (a bar widget, an overlay module, a setting, a service, …) are in [docs/recipes/](docs/recipes/).

## Example setups
- Build the setup in the shell, then Settings → Maintenance → Share → Export (keybinds, apps and commands switched off unless the example needs a command). It writes `~/axiom-<name>-<date>-<time>.json` holding only the look (the schema's `x-scope`), minus defaults; move it to `examples/<name>.json` and fill in its `_example` header: `{ "title": "…", "description": "…" }`.
- Monitors, wallpapers, accounts and paths are `machine` scope, so they're never in an export; don't add them by hand.
- `tests/tst_ConfigExamples.qml` loads every example the way the shell does, so `scripts/run_tests.sh ConfigExamples` tells you whether it's valid.

## Checks
- Format changed QML with `scripts/dev/verify.sh` or `scripts/check_qmlformat.sh --fix` (Qt 6's qmlformat, `.qmlformat.ini`; the `qmlformat` on PATH is Qt5's). Both write in place: `qmlformat -i` replaces the file, and the running shell stops reloading it (`docs/dev/testing.md`).
- Run `scripts/check_structure.py` after adding, renaming or moving files: types and popouts load by file name, so it catches a missing file or import before the shell does.
- Once per clone, `git config core.hooksPath .githooks`: the pre-commit hook regenerates `docs/dev/config/` and `docs/dev/generated/` (`scripts/gen_docs.py`) from what you commit, so they never go stale. Don't edit those by hand.
- While working, `scripts/dev/verify.sh` checks just what you changed and shows the shell's log.
- Found a bug you're not fixing? Add it to `docs/dev/issues.md` (format at the top).
- Run `scripts/check_all.sh` before opening a pull request. It runs what CI runs: structure, generated docs, docs (`scripts/check_docs.py`), qmlformat, qmllint (against `scripts/qmllint-baseline.json`), the unit tests in `tests/`, shellcheck, the script tests and the translation check. Changing a migration step or a `components/methods/` helper? Add a test for it.
- The checks don't run the shell: after saving, read `scripts/log.sh` (a clean reload is `Reloading configuration...` + `Configuration Loaded`).

[docs/dev/](docs/dev/README.md) holds the mechanics of every service and surface, one doc per topic, plus the index of shared UI pieces. Read the relevant doc before changing a feature, and update it when you change how one works.
