---
name: overlay-module
description: Add a new overlay module (a card type for overlay pages and edge menus: components/content/<Type>.qml plus its schema entry). Use when the user asks for a new module, card, tile or widget for the overlay, an edge menu, the desktop or the lock screen.
---

Follow `docs/recipes/overlay-module.md` exactly: read it first, then the files it says to copy from.
Schema entry with `place` and its `$ref` in `definitions.OverlayModule.oneOf`; set `fullMinWidth`/`fullMinHeight` and `compactContent` so it works at any size; acquire in `Component.onCompleted`, release in `onDestruction`. Lockscreen/greeter hosts only under their rules.
Finish with `scripts/dev/verify.sh` and fix everything it reports.
