# Pure helpers (`components/methods/`)

`pragma Singleton` `QtObject`s with pure functions: no files, processes, dispatches, timers or `qs.*` imports. `scripts/run_tests.sh` builds them as a `--pure` module tree, so anything importing Quickshell is left out of tests.

**Recipe:** `docs/recipes/methods-helper.md` / `docs/recipes/migration.md`; verify with `scripts/dev/verify.sh`.

- **Every helper has a test**: `tests/tst_<Name>.qml` (`import QtQuick; import QtTest; import qs.components.methods; TestCase { name: "<Name>"; function test_x() { compare(…) } }`). Copy `ColorTemperature.qml` + `tst_ColorTemperature.qml` or `TimeZones.qml` + `tst_TimeZones.qml`. Fixtures through `RepoFiles`.
- Add a test case whenever you change a helper's behaviour; run `scripts/run_tests.sh <Name>`.
- JS engine gaps: no `flatMap` (`[].concat(...arr.map(...))`), no `Object.fromEntries` (`reduce`), no `Intl`.
- Geometry rules (`SurfaceContext`, `EdgeAttach`, `PopoutGeometry`, `BarEnds`, `GridPlacement`) are the single source for their decisions: a new case is a rule here plus a test row, not a special case in a host. See `docs/dev/popouts/`.
- `ConfigMigration.qml` is **frozen at v75**: the axiom binary runs a copy of it (`backend/internal/migrate/legacy/legacy.js`) and the shared fixtures check both. Never change it ([migration recipe](../../docs/recipes/migration.md)). What it used to say, for reading old steps: a layout change = bump `currentVersion` and the schema's `version` default together (schema first), add `if (version < N) result = _vMToVN(result, changes)` and an idempotent `_vMToVN` (`migrate()` deep-clones first, so a step may edit `config` in place and return it) (copy `_v52ToV53`; helpers `_eachWidget`, `_renameKey`, `_addBinds`; for modules, walk the `modules` arrays directly as `_v36ToV37` does), push English notes onto `changes`, and add a `test_vN_…` case in `tests/tst_Config.qml`.
