---
name: methods-helper
description: Add a pure helper singleton in axiom's components/methods/ with its qmltestrunner test (tests/tst_<Name>.qml). Use when the user says "add a helper", "pure function for X", "extract this logic into methods", "unit-testable helper", or for geometry/parsing/formatting logic with no side effects.
---

Follow `docs/recipes/methods-helper.md` exactly: read it first, then the files it says to copy from (`components/methods/ColorTemperature.qml` + `tests/tst_ColorTemperature.qml`).
Import only `QtQuick` (and other methods helpers): no Quickshell, `qs.services` or `qs.config`, no files, processes or timers. Every helper gets a `tests/tst_<Name>.qml`. The JS engine has no `flatMap`, `Object.fromEntries` or `Intl`.
Finish with `scripts/run_tests.sh <Name>` and `scripts/dev/verify.sh`, and fix everything they report.
