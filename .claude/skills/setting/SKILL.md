---
name: setting
description: Add a new config setting (key) to an existing axiom config section, with its schema entry, default and reader property. Use when the user says "add a setting", "add an option for X", "make X configurable", "new config key", or "expose X in settings".
---

Read `docs/recipes/setting.md` and follow it exactly: it names the files to touch, the files to copy from, the traps (Gotchas) and how to verify.
Finish when its Verify steps pass and `scripts/dev/verify.sh` prints `verify ok`.
