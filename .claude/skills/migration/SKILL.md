---
name: migration
description: Write an axiom config migration step (a format-2 step in backend/internal/migrate/steps, version bump, Go test) for renaming, moving or reshaping config keys. Use when the user says "rename a config key", "move setting X", "change the config layout", "migrate old configs", or "bump the config version".
---

Read `docs/recipes/migration.md` and follow it exactly: it names the files to touch, the files to copy from, the traps (Gotchas) and how to verify.
Finish when its Verify steps pass and `scripts/dev/verify.sh` prints `verify ok`.
