---
name: settings-card
description: Add a hand-built settings card or intro (x-card / x-intro / x-cardFolds in components/views/settings/). Use when the user asks for a custom settings card, a status card with actions, a list editor in settings, or a status line above a settings section.
---

Follow `docs/recipes/settings-card.md` exactly: read it first, then the files it says to copy from.
`x-card: "<Name>"` loads `<Name>Card.qml`, `x-intro: "<Name>"` loads `<Name>.qml`; check_structure doesn't verify them, so confirm the file exists. Edits go through SettingsManager's draft.
Finish with `scripts/dev/verify.sh` and fix everything it reports.
