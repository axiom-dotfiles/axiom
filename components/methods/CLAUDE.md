# Pure helpers (`components/methods/`)

`pragma Singleton` `QtObject`s with pure functions: no files, processes, dispatches, timers or `qs.*` imports. `scripts/run_tests.sh` builds them as a `--pure` module tree, so anything importing Quickshell is left out of tests.

- **Every helper has a test**: `tests/tst_<Name>.qml` (`import QtQuick; import QtTest; import qs.components.methods; TestCase { name: "<Name>"; function test_x() { compare(…) } }`). Copy `ColorTemperature.qml` + `tst_ColorTemperature.qml` or `TimeZones.qml` + `tst_TimeZones.qml`. Fixtures through `RepoFiles`.
- Add a test case whenever you change a helper's behaviour; run `scripts/run_tests.sh <Name>`.
- JS engine gaps: no `flatMap` (`[].concat(...arr.map(...))`), no `Object.fromEntries` (`reduce`), no `Intl`.
- Geometry rules (`SurfaceContext`, `EdgeAttach`, `PopoutGeometry`, `BarEnds`, `GridPlacement`) are the single source for their decisions: a new case is a rule here plus a test row, not a special case in a host. See `docs/dev/popouts/`.
- `ConfigMigration.qml`: a layout change = bump `currentVersion` and the schema's `version` default together (schema first), add `if (version < N) result = _vMToVN(result, changes)` and an idempotent, non-mutating `_vMToVN` (copy `_v52ToV53`; helpers `_eachWidget`, `_eachModule`, `_renameKey`, `_addBinds`), push English notes onto `changes`, and add a `test_vN_…` case in `tests/tst_Config.qml`.
