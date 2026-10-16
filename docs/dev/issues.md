# Known issues

> **Files:** this file only
> **Config:** none
> **Related:** [Developer docs](README.md), [testing](testing.md)

Problems found while working on something else: not fixed yet, but recorded so they aren't lost. **Add an entry whenever you find a problem outside the task at hand** rather than fixing it unasked or only mentioning it. Remove the entry in the change that fixes it. Before starting work in an area, check here for what's already known about it.

Each entry is a `###` heading plus these four bullets, in this order (`scripts/check_docs.py` checks the shape and that cited paths and members exist):

```
### <Short title>
- **Where:** `path/File.qml` (symbol, or several paths)
- **What:** what's wrong and the evidence (log line, grep count, failing case); quote a log warning's message in backticks so verify.sh marks it known
- **Size:** trivial | small | needs a plan
- **Found:** YYYY-MM-DD, while <task>
```

## Open

### No sway or niri backend yet
- **Where:** `services/CompositorManager.qml` (`backend`), `docs/dev/compositor/sway-backend.md`
- **What:** Everything goes through `CompositorManager`, but only Hyprland has a backend. Under sway or niri, axiom runs with none: the bar, launcher and notifications work, but workspaces, windows, the dock's running apps, the keyboard layout and the window look are empty or do nothing. The plan for sway is in `sway-backend.md`; `scripts/dev/nested.sh` runs it nested.
- **Size:** needs a plan
- **Found:** 2026-10-16, while decoupling the shell from Hyprland

### Floating bars sit flush on the border without a backend
- **Where:** `config/Bar.qml` (`enrichBarConfig`: `floatGap`), `services/CompositorManager.qml` (`gapsOut`)
- **What:** A floating bar's automatic gap (`floatGap` -1) is the compositor's outer gaps (`CompositorManager.gapsOut`). With no backend (sway or niri today) `gapsOut` is all 0, so a floating bar sits flush against the border, as seen in nested sway. The sway backend's `gapsOut` (from `gaps outer`, `sway-backend.md`) should fix it there; decide what the gap is with no backend at all (a fixed default, or `Appearance.screenMargin`).
- **Size:** small
- **Found:** 2026-10-16, while testing layer order in nested sway

### Blur and transparency on other compositors
- **Where:** `services/BlurManager.qml` (`_wanted`), `config/json/config.schema.json` (`Appearance` blur settings, `"/$supports.blur"`), `services/CompositorManager.qml` (`supports`)
- **What:** Axiom's surfaces blur only where the compositor blurs its layers (`supports.blur`: Hyprland's layer rules). Elsewhere the blur settings are hidden and translucent surfaces fill themselves, so a surface over another (the launcher over a dock) shows it through its fill. SwayFX (`layer_effects`) and niri (layer rules) may blur layers by namespace too: the blur window (`axiom-blur-backing`) is all they'd need to blur. Its strength would then be axiom's to set outside Hyprland (likely one blur-strength option there).
- **Size:** needs a plan
- **Found:** 2026-10-16, while placing layers without Hyprland

### The greeter runs its own Hyprland session
- **Where:** `scripts/greeter/greeter-session.sh`, `services/GreetdManager.qml` (`_applyHyprland`)
- **What:** The greeter runs its own Hyprland session (`start-hyprland`, `hyprctl dispatch exit`), whatever compositor the user's session uses. Decide whether it keeps Hyprland or moves to cage/sway. (The onboarding's binds table and Welcome copy no longer assume Hyprland.)
- **Size:** small
- **Found:** 2026-10-16, while decoupling the shell from Hyprland

### Layer origins ignore what axiom doesn't place, even on Hyprland
- **Where:** `components/hosts/popout/LayerOrigin.qml` (`origin`, `settled`), `services/LayerManager.qml` (`rects`)
- **What:** Origins now come only from `LayerArrange`, on Hyprland too. Another app's exclusive layer (a second panel) or a monitor's `addreserved` moves axiom's windows without moving their computed origins, so blur shapes, border joins and popout footprints land off by that much. `LayerManager` only logs the difference (`LayerManager: differs from the compositor`). `LayerOrigin.settled` also lost its 400 ms timeout: a window whose screen isn't in `General.outputs` never gets an origin, so its edge popout never claims or shows. Decide whether a window prefers the compositor's rect where `withLayerRects` gives one, and give `settled` a fallback again.
- **Size:** small
- **Found:** 2026-10-16, while auditing the layer-placement branch

### Two exclusive-focus surfaces at once without a native grab
- **Where:** `services/FocusGrab.qml` (`exclusive`), `components/hosts/overlay/OverlayPanel.qml`, `components/hosts/popout/BarPopouts.qml`, `components/hosts/popout/EdgePopout.qml`
- **What:** Without `supports.focusGrab`, every active grab's surface asks for `WlrKeyboardFocus.Exclusive`. With the overlay open (exclusive the whole time) and a popout with a text field opened over it, two surfaces on the Overlay layer ask for exclusive focus. Which one gets the keyboard is up to the compositor and wasn't checked in nested sway or niri: typing into a popout over the overlay may go to the overlay. Not seen yet; check it in `scripts/dev/nested.sh sway`.
- **Size:** small
- **Found:** 2026-10-16, while auditing the layer-placement branch

### Missing app icons warn in the log
- **Where:** `services/LauncherManager.qml` (`Quickshell.iconPath`), `services/DockManager.qml`
- **What:** An app whose `.desktop` icon isn't in the icon theme (here `xdg-desktop-portal-gtk`'s `applications-system-symbolic`) logs `Could not load icon` at each size it's drawn, though the fallback icon shows. Noise in `scripts/log.sh`; either skip hidden/`NoDisplay` entries or resolve the name before handing it to an Image.
- **Size:** trivial
- **Found:** 2026-10-16, while auditing the layer-placement branch

### The python venv and bytecode are written into the repo
- **Where:** `scripts/setup_venv.sh`, `scripts/venv_python.sh`
- **What:** The venv for `generate_theme.py`/`calendar_sync.py` is made at `<repo>/.venv`, and python leaves `__pycache__/` in `scripts/`. A packaged (read-only) install can't do either. Put the venv in `$XDG_DATA_HOME/axiom/venv` (or use the system python when the requirements already import), and set `PYTHONDONTWRITEBYTECODE=1`. Blocks packaging, not the XDG move.
- **Size:** small
- **Found:** 2026-10-15, while moving config and state to the XDG folders

### Hyprland starts axiom by its repo path, and self-update assumes git
- **Where:** `services/HyprlandConfigManager.qml` (`shellCommand`), `services/SelfUpdateManager.qml`, `scripts/greeter/greeter_install.sh`
- **What:** `shellCommand` is `qs -p '<repo>'`, which a package would want as `qs -c axiom` or an `axiom` launcher. Self-update and the greeter installer work on `Paths.axiomPath` as a git clone. A package manager owns updates, so these should hide or switch when there is no `.git`. Blocks packaging, not the XDG move.
- **Size:** needs a plan
- **Found:** 2026-10-15, while moving config and state to the XDG folders

### Old config/state folders are kept in the repo after the XDG move
- **Where:** `services/DataMigrationManager.qml`, `components/methods/DataDirs.qml` (`legacy`)
- **What:** After moving an install over, `config/user/`, `config/state/` and `config/themes/generated/` are left in place (with `MOVED.md`) so a rollback still finds them. Once rolling back past the move is no longer supported, delete them (or offer to), and drop the legacy layout code.
- **Size:** small
- **Found:** 2026-10-15, while moving config and state to the XDG folders

### Disk usage shifts onto the wrong path when one is missing
- **Where:** `services/SystemManager.qml` (`_df`)
- **What:** `df` is run once for every requested path and its output lines are matched to the paths by position. A path that doesn't exist (a `diskPath` typed wrong, an unmounted drive) gets no line, only an error on stderr, so every path after it shows the next path's usage and the last one shows none. Run `df` per path, or add `--output=target` and match lines to paths by that.
- **Size:** small
- **Found:** 2026-10-15, while auditing the folder picker commit

### Text input warnings when the desktop takes the keyboard
- **Where:** `components/surfaces/desktop/DesktopWindow.qml` (`WlrLayershell.keyboardFocus`)
- **What:** With a typing module (Notes) on the desktop, clicking into it and back to windows logs bursts of `Trying to disable` from `qt.qpa.wayland.textinput` (`QWaylandTextInputv3::disableSurface`; 174 in one session). Typing and handing focus back work. Likely Qt's text-input-v3 noise when focus moves between surfaces; not yet checked whether an edge menu's Notes logs the same.
- **Size:** small
- **Found:** 2026-10-14, while letting typing modules go on the desktop

### `CornerMerge.opening` reads a missing container
- **Where:** `components/bar/CornerMerge.qml` (`_placed`, `opening`)
- **What:** Reloads log `TypeError: Cannot read property 'length' of null` at the `opening` binding. `_placed` checks `container !== null`, but `container` (`bar.pillBarStart`/`pillBarEnd`) can be unset or not yet laid out, and `opening` then reads `root.container.length`. Guard `_placed` with `!!root.container` (and check the end reach doesn't flash while it's missing).
- **Size:** trivial
- **Found:** 2026-10-14, while fixing pill-bar joins for popouts reaching a corner

### `Bar` reader holds the edges enum and breaks reader naming
- **Where:** `config/Bar.qml` (`enum Location`, the `Bars` reader)
- **What:** The `Bars` section's reader is named `Bar` (other readers are named for their section, with a `Config` suffix where needed), and the same file declares the `Location` edge enum (`Bar.Top`, `Bar.Left`, …) that docks, OSDs, popouts and edge menus use. About 302 `Bar.` references in 57 files, 204 of them the enum. Plan: move the enum to a new `Edge` singleton in config/ (`Edge.Top`), then rename the reader (e.g. `BarsConfig`). `gen_docs.py` needs no change; add the old names to `RETIRED` in `scripts/check_docs.py`, and force a reload afterwards (testing.md › Reloads and logs).
- **Size:** needs a plan
- **Found:** 2026-10-13, while assessing reader renames for the docs makeover

### `BlurManager.paused` warns on every reload
- **Where:** `services/BlurManager.qml` (`paused`), `services/UpdatesManager.qml` (`checking`), `services/SelfUpdateManager.qml`, `services/HyprlandManager.qml` (`activeWindowId`)
- **What:** Every config reload logs `Unable to assign [undefined] to bool` at the `paused` declaration (and, seen 2026-10-14, at `UpdatesManager.checking`, also a readonly bool on a singleton: likely the same cause; seen 2026-10-16 as `Unable to assign [undefined] to QString` at `HyprlandManager.activeWindowId`, a readonly string). The binding itself evaluates to a boolean (a temporary probe logged `boolean false`), and a constant `paused: false` still warned, so it isn't the expression: something in Quickshell's reload of this singleton assigns it. Harmless (the value is right afterwards), but it's noise in every `scripts/log.sh`. Next step: check whether Quickshell carries readonly properties across a reload, or whether making `paused` a plain function helps.
- **Size:** small
- **Found:** 2026-10-13, while checking reload logs during the docs makeover

### Binding loops in bar popout placement
- **Where:** `components/hosts/popout/EdgePlacement.qml`, `components/hosts/popout/PillBarJoin.qml`, `components/hosts/popout/BarPopouts.qml`, `components/hosts/popout/AttachedSurface.qml`, `components/hosts/popout/SubPopout.qml`
- **What:** Opening bar popouts on a floating-pills bar logs binding loops, dozens per session: `property "_wall"` (PillBarJoin, created at EdgePlacement.qml:345), `property "joinReach"` (EdgePlacement), `property "surfaceX"` / `property "surfaceY"` (BarPopouts' window), `property "_spec"` (AttachedSurface) and `property "place"` / `property "alignedBoxStart"` (SubPopout). They're in every qs instance's log back to 2026-10-13, before the corner-priority change. The values settle (no visible glitch reported), but a loop can leave a stale value for a frame and buries real warnings. Likely one cycle: the placement reads the pill's join reach, which reads the placement's wall. (`_surfaceFromEdge`'s loop is gone: it now comes from the layout's `attachAt`, not the drawn surface.) Not reproduced on 2026-10-16 (popouts from a floating-pills bar, and one joining a perpendicular pill bar, on Hyprland and in nested sway): it may have gone with later placement changes. Delete this entry if it doesn't come back.
- **Size:** needs a plan
- **Found:** 2026-10-14, while reviewing verify.sh output for the agent-setup changes

### Schema root `description` duplicates the annotation docs
- **Where:** `config/json/config.schema.json` (root `description`)
- **What:** A 3 KB description restates the `x-*` annotations and is already incomplete (no `x-control`, `x-hypr*` or `x-scope`). The complete list is `docs/dev/core/schema-annotations.md`. Trim it to one line pointing there.
- **Size:** trivial
- **Found:** 2026-10-13, while splitting architecture.md

### `Hyprland.requiredSettings` has no developer doc
- **Where:** `config/HyprlandConfig.qml` (`requiredSettings`), `docs/dev/hyprland/config-modes.md`
- **What:** It's in the schema and the generated reference (`docs/dev/config/Hyprland.md`), but no hand-written doc explains what it does. Add a section to `config-modes.md`. (`wallpaperDaemon` moved to `Appearance.wallpaperDaemon`, covered in `wallpaper-and-schedules.md`.)
- **Size:** trivial
- **Found:** 2026-10-13, while splitting architecture.md
