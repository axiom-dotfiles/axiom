---
name: service
description: Add a new axiom service singleton (services/<Name>Manager.qml) that owns state and side effects, optionally polled through ConsumerRegistry acquire/release and with an IPC handler. Use when the user says "new service", "new manager", "poll X", "run a command periodically", "add an IPC target", or a feature needs a process, file writes or Hyprland calls.
---

Follow `docs/recipes/service.md` exactly: read it first, then the files it says to copy from (`services/TailscaleManager.qml`, `services/IdleInhibitManager.qml`).
Name it `*Manager`, never shadowing a Quickshell singleton. Anything polled goes through a private `ConsumerRegistry`, with consumers calling `acquire` in `Component.onCompleted` and `release` in `onDestruction`, and requests built from config only. Add it to `shell.qml`'s `_services` if nothing else references it. Greeter-reachable side effects check `Paths.greeter`.
Finish with `scripts/dev/verify.sh` and fix everything it reports.
