---
name: overlay-view
description: Add a new overlay page type or tool page (components/views/<Type>.qml plus schema, and for tool pages the default, a migration step, a launcher command and docs). Use when the user asks for a new overlay page, view, tool page or editor page.
---

Follow `docs/recipes/overlay-view.md` exactly: read it first, then the files it says to copy from.
A tool page (`x-tool`) also needs the `Overlay.views` default entry, an idempotent migration step with a `tst_Config` test, a way to open it from the launcher, and a `docs/usage.md` row. Schema before migration.
Finish with `scripts/dev/verify.sh` and fix everything it reports.
