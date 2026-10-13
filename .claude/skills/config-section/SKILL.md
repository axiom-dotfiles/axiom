---
name: config-section
description: Add a new top-level config section to axiom's schema plus its reader singleton in config/. Use when the user says "new config section", "add a section for X settings", "new settings category for a feature", or a new feature needs its own settings.
---

Follow `docs/recipes/config-section.md` exactly: read it first, then the files it says to copy from.
The section needs `x-category` (one of the root's `x-categories`), `additionalProperties: false` and a `default` on every key. The reader is `<Section>.qml` (or `<Section>Config.qml` when the name is also a type) with `readonly property var _c: ConfigManager.config.<Section>`. Edit the schema before writing the section into the live config.
Finish with `scripts/dev/verify.sh` and fix everything it reports.
