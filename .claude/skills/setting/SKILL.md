---
name: setting
description: Add a new config setting (key) to an existing axiom config section, with its schema entry, default and reader property. Use when the user says "add a setting", "add an option for X", "make X configurable", "new config key", or "expose X in settings".
---

Follow `docs/recipes/setting.md` exactly: read it first, then the files it says to copy from.
Every key needs a `default` and a reader property `_c.<key>` with no `??` fallback. Consumers read the reader, never `ConfigManager.config`. A key in a look-scoped section that names a monitor, path, account or command needs `x-scope: machine`/`personal`. Renaming an existing key is a migration (`docs/recipes/migration.md`), not this.
Finish with `scripts/dev/verify.sh` and fix everything it reports.
