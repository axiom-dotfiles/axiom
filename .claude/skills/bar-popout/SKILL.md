---
name: bar-popout
description: Add a popout panel that a bar widget opens on hover (components/content/<Name>.qml with a PopoutAnchor). Use when the user asks for a hover popout, a panel or dropdown from a bar widget, or details shown when hovering the bar.
---

Follow `docs/recipes/bar-popout.md` exactly: read it first, then the files it says to copy from.
Declare a property for every `extraData` key (they're copied onto same-named properties); use a literal `popoutName: "<Name>"`; the service owns the data.
Finish with `scripts/dev/verify.sh` and fix everything it reports.
