---
name: theme-integration
description: Add a new axiom theme integration that themes another app (scripts/theme_<key>.sh, template, ThemeIntegrations schema switch with x-hookup, reader property, tests). Use when the user says "theme X too", "add a theme integration for X", "make X follow the axiom theme", or "support X colors".
---

Follow `docs/recipes/theme-integration.md` exactly: read it first, then the files it says to copy from (`scripts/theme_alacritty.sh`, its template, and the `alacritty` schema entry).
The script writes only its own `axiom.*` file; only the hookup's Apply (`integration_hookup.py`, on the user's click) edits the user's config. Never apply a hookup to the real configs (use a scratch `HOME`/`XDG_CONFIG_HOME`). Add `FORMATS`/`STUBS` entries in `tests/scripts/test_scripts.py`.
Finish with `shellcheck -x -S warning scripts/theme_<key>.sh`, `python3 tests/scripts/test_scripts.py ThemeIntegrations HookupScript` and `scripts/dev/verify.sh`, and fix everything they report.
