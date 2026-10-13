---
name: launcher-command
description: Add a slash command to the launcher (an entry in services/LauncherCommands.qml). Use when the user asks for a new launcher command, a /command, or a way to do something from the launcher.
---

Follow `docs/recipes/launcher-command.md` exactly: read it first, then the files it says to copy from.
`description` is a function returning `I18n.tr(…)`; the work happens in a service; return `false` from `run` to keep the launcher open; add it to the `docs/usage.md` launcher table.
Finish with `scripts/dev/verify.sh` and fix everything it reports.
