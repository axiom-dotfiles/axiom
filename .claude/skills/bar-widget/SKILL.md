---
name: bar-widget
description: Add a new bar widget type to axiom (a QML file in components/bar/widgets plus its schema entry). Use when the user asks to add a bar widget, a new widget for the bar, a bar module, or something that should show on the bar.
---

Follow `docs/recipes/bar-widget.md` exactly: read it first, then the files it says to copy from.
The file name, the schema `type` const and the `$ref` in `definitions.BarWidget.oneOf` must all match; sizes come from `barConfig`, never `Widget.*`; a popout anchor is gated by `EdgeMenusConfig.opensOwnPopout(root.properties)`.
Finish with `scripts/dev/verify.sh` and fix everything it reports.
