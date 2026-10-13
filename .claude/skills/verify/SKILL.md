---
name: verify
description: Check a change to axiom the way CI will and see what the live shell logged. Use after editing QML, the schema or scripts, before saying a change is done, or when asked to "verify", "check my changes", "run the checks", "does it work", "take a screenshot of …".
---

Run `scripts/dev/verify.sh` and fix everything it reports, then run it again until it prints `verify ok`. Read the shell log section: any new `WARN`/`ERROR` from a file you touched is yours to fix.
For something visible, look at it with `scripts/dev/shot.sh page <ViewType>` (or `launcher [text]`, `ipc <target> <open> [close]`) and Read the PNG it prints. Never move the cursor.
Before committing, `scripts/dev/verify.sh --all` runs every CI check. See `docs/dev/testing.md`.
