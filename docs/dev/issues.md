# Known issues

> **Files:** this file only
> **Config:** none
> **Related:** [Developer docs](README.md), [testing](testing.md)

Problems found while working on something else: not fixed yet, but recorded so they aren't lost. **Add an entry whenever you find a problem outside the task at hand** rather than fixing it unasked or only mentioning it. Remove the entry in the change that fixes it. Before starting work in an area, check here for what's already known about it.

Each entry is a `###` heading plus these four bullets, in this order (`scripts/check_docs.py` checks the shape and that cited paths and members exist):

```
### <Short title>
- **Where:** `path/File.qml` (symbol, or several paths)
- **What:** what's wrong and the evidence (log line, grep count, failing case)
- **Size:** trivial | small | needs a plan
- **Found:** YYYY-MM-DD, while <task>
```

## Open

### `Bar` reader holds the edges enum and breaks reader naming
- **Where:** `config/Bar.qml` (`enum Location`, the `Bars` reader)
- **What:** The `Bars` section's reader is named `Bar` (other readers are named for their section, with a `Config` suffix where needed), and the same file declares the `Location` edge enum (`Bar.Top`, `Bar.Left`, …) that docks, OSDs, popouts and edge menus use. About 302 `Bar.` references in 57 files, 204 of them the enum. Plan: move the enum to a new `Edge` singleton in config/ (`Edge.Top`), then rename the reader (e.g. `BarsConfig`). `gen_docs.py` needs no change; add the old names to `RETIRED` in `scripts/check_docs.py`, and force a reload afterwards (testing.md › Reloads and logs).
- **Size:** needs a plan
- **Found:** 2026-10-13, while assessing reader renames for the docs makeover

### `Quickshell.screens` used outside `General`
- **Where:** `services/SettingsManager.qml`, `services/WallpaperManager.qml`, `services/DesktopManager.qml`, `services/ThemeManager.qml`, `services/HyprlandManager.qml`, `services/BrightnessManager.qml`, `components/content/WallpaperPicker.qml`, `components/surfaces/onboarding/pages/MonitorsPage.qml`, `shell/Greeter.qml`, `shell/Lockscreen.qml`, `shell/GreeterPreview.qml`
- **What:** AGENTS.md › Screen targeting says build on `General.outputs` / `General.screensFor`, never `Quickshell.screens` (it holds stand-ins while no monitor is connected); 14 uses remain (`grep -rn 'Quickshell\.screens' --include='*.qml' . | grep -v config/General.qml`). The three in `shell/` pick a fallback screen for a window that must exist even with no monitor, and are probably deliberate (say so in a comment); the rest should move to `General.outputs`.
- **Size:** small
- **Found:** 2026-10-13, while fixing `BlurManager.paused`

### `BlurManager.paused` warns on every reload
- **Where:** `services/BlurManager.qml` (`paused`)
- **What:** Every config reload logs `Unable to assign [undefined] to bool` at the `paused` declaration. The binding itself evaluates to a boolean (a temporary probe logged `boolean false`), and a constant `paused: false` still warned, so it isn't the expression: something in Quickshell's reload of this singleton assigns it. Harmless (the value is right afterwards), but it's noise in every `scripts/log.sh`. Next step: check whether Quickshell carries readonly properties across a reload, or whether making `paused` a plain function helps.
- **Size:** small
- **Found:** 2026-10-13, while checking reload logs during the docs makeover

### Schema root `description` duplicates the annotation docs
- **Where:** `config/json/config.schema.json` (root `description`)
- **What:** A 3 KB description restates the `x-*` annotations and is already incomplete (no `x-control`, `x-hypr*` or `x-scope`). The complete list is `docs/dev/core/schema-annotations.md`. Trim it to one line pointing there.
- **Size:** trivial
- **Found:** 2026-10-13, while splitting architecture.md

### `Hyprland.requiredSettings` and `wallpaperDaemon` have no developer doc
- **Where:** `config/HyprlandConfig.qml` (`requiredSettings`, `wallpaperDaemon`), `docs/dev/hyprland/config-modes.md`
- **What:** Both settings are in the schema and the generated reference (`docs/dev/config/Hyprland.md`) but no hand-written doc explains what they do; `wallpaperDaemon` only gets a passing mention in `docs/dev/theming/wallpaper-and-schedules.md`. Add a section to `config-modes.md`.
- **Size:** trivial
- **Found:** 2026-10-13, while splitting architecture.md
