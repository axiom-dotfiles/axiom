---
name: migration
description: Write an axiom config migration step (ConfigMigration _vMToVN, version bump, tst_Config test) for renaming, moving or reshaping config keys. Use when the user says "rename a config key", "move setting X", "change the config layout", "migrate old configs", or "bump the config version".
---

Follow `docs/recipes/migration.md` exactly: read it first, then the files it says to copy from.
Edit the schema (new shape and `version` default) BEFORE saving ConfigMigration.qml, or the live shell migrates against the old schema and loses the user's values. Bump `currentVersion` to match. Make the step idempotent and guard odd types, and add a `test_vN_…` case in `tests/tst_Config.qml`. For modules, walk the `modules` arrays directly (as `_v36ToV37` does).
Finish with `scripts/run_tests.sh Config ConfigExamples` and `scripts/dev/verify.sh`, and fix everything they report.
