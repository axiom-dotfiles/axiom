# Known issues

> **Files:** this file only
> **Config:** none
> **Related:** [Developer docs](README.md), [testing](testing.md)

Problems found while working on something else: not fixed yet, but recorded so they aren't lost. **Add an entry whenever you find a problem outside the task at hand** rather than fixing it unasked or only mentioning it. Remove the entry in the change that fixes it. Before starting work in an area, check here for what's already known about it.

Each entry is a `###` heading plus these four bullets, in this order (`scripts/check_docs.py` checks the shape and that cited paths and members exist):

```
### <Short title>
- **Where:** `path/File.qml` (symbol, or several paths)
- **What:** what's wrong and the evidence (log line, grep count, failing case); quote a log warning's message in backticks so verify.sh marks it known (one from Qt or Quickshell that names no file: quote its category too, `quickshell.I3.ipc`)
- **Size:** trivial | small | needs a plan
- **Found:** YYYY-MM-DD, while <task>
```

## Open

### niri's overview drop moves a window's whole column
- **Where:** `services/NiriManager.qml` (`placeWindow`)
- **What:** Dropped beside or into another column on its own workspace (`reinsert`), a window is moved with `MoveColumnToIndex`, which moves the focused column: a window sharing its column with others takes them along. A drop onto another workspace moves only the window (`MoveWindowToWorkspace` by id). Expelling it from its column first (`ExpelWindowFromColumn`, which shifts the column indexes) would fix it; needs trying in `scripts/dev/nested.sh niri`.
- **Size:** small
- **Found:** 2026-10-17, while auditing the niri branch for merge

### A niri module refused in detached mode is only logged
- **Where:** `services/NiriConfigWriter.qml` (`runtimeApply`), `services/CompositorConfigManager.qml` (`problem`)
- **What:** In the file modes a module `niri validate` refuses sets `CompositorConfigManager.problem` (the Compositor card shows it). The detached mode's module (also the file modes' fallback) is checked the same way, but a refusal is only a `[NiriConfigWriter] niri refuses the config axiom made` warning in the log: the card says nothing, and niri keeps the module before. A raw bind niri refuses is the likely cause.
- **Size:** small
- **Found:** 2026-10-17, while auditing the niri branch for merge

### Hyprland's own options are several cards that don't say they're Hyprland's
- **Where:** `config/json/config.schema.json` (`Hyprland.managed`: its `x-group`s), `components/methods/SchemaLayout.qml` (`groups`)
- **What:** Sway's and niri's own options are one card each, titled by the compositor. Hyprland's managed options are split by `x-group` into Layout, Decoration, Animations, Windows and Behaviour cards beside the compositor-neutral ones (Windows and focus, Mouse & cursor), and nothing on them says they're Hyprland's. Either one Hyprland card (about 30 rows), or group titles naming it.
- **Size:** small
- **Found:** 2026-10-17, while making niri's options one card

### SwayFX blurs a floating popout's shadow halo
- **Where:** `components/hosts/popout/FloatingPopout.qml` (its `SurfaceShadow`), `components/methods/LayerStack.qml` (`blurSurfaces`: `floating-popout`)
- **What:** The floating popout blurs its own window and casts its shadow inside it. SwayFX's `blur_ignore_transparent` blurs every pixel that isn't fully clear, so its shadow shows as a frosted band (Hyprland's `ignore_alpha` leaves it out). The chrome's shadows are cast from a window apart on SwayFX (`axiom-shadows`); this one would need the same, or its shadow off there.
- **Size:** small
- **Found:** 2026-10-17, while fixing the chrome's shadows on SwayFX

### A greeter installed before v63 drops the monitor and keyboard layout
- **Where:** `components/methods/GreeterBundle.qml` (`exportConfig`), `services/GreeterManager.qml`
- **What:** An installed greeter on older code reads a v63 bundle without migrating it and prunes `Compositor`, `Monitors` and `Input` as unknown, so until the greeter is updated the login screen loses the monitor layout and, in managed mode, `kbLayout`/`kbOptions` (a password typed on the wrong layout). The outdated notice says to update, but not that it's required. Exporting the legacy `Hyprland.monitors`/`managed` keys for a while, or a firmer notice, would cover it.
- **Size:** small
- **Found:** 2026-10-16, while auditing the sway branch for merge

### Migrations read a missing key as off where the old managed config wrote a default
- **Where:** `components/methods/ConfigMigration.qml` (`_v57ToV58`, `_v58ToV59`, `_v62ToV63`)
- **What:** Each step moves what's present. A hand-trimmed config (the UI saves every default) loses what the managed file always wrote: no `Hyprland.managed` means no border 2/rounding 8; a missing `dimInactive` (old default on) leaves dim off; missing keyboard keys turn repeat 50/300 back to the compositor's; `shadowThemed` without `shadowColor` becomes the compositor's color, not `base00`. In managed mode a missing key could be read as its old default.
- **Size:** small
- **Found:** 2026-10-16, while auditing the sway branch for merge

### Corner rounding is greyed out on plain sway with no note
- **Where:** `components/forms/SchemaField.qml` (`disabledNote`)
- **What:** `WindowLook.rounding` needs `/$supports.windowRounding` (SwayFX only), but the note is suppressed for a row shown by a sibling switch, and `shape` itself isn't greyed, so nothing says why. Suppress the note only when the sibling is blocked by the same key.
- **Size:** trivial
- **Found:** 2026-10-16, while auditing the sway branch for merge

### SwayFX remaps the chrome on a fresh qs start
- **Where:** `services/SwayManager.qml` (`surfacesReady`), `shell/BlurBacking.qml`
- **What:** `surfacesReady` is always true, so bars, border and docks map at once, while the held blur window (order 9) and the shadow window beside it (`axiom-shadows`, order 8) wait for `supports.blur`, known only from the `get_version` reply. Mapped after them, they make LayerManager map each lower-ordered window again. Hot reloads keep the variant, so only a fresh start does it. Waiting for `ready` would fix it, but hides the chrome until sway answers.
- **Size:** small
- **Found:** 2026-10-16, while auditing the sway branch for merge

### The blur window's Top/Overlay switch may land over the bars on SwayFX
- **Where:** `shell/BlurBacking.qml`, `shell/BlurBackingWindow.qml`
- **What:** The blur window changes `stackLayer` while a fullscreen window shows; LayerManager keeps its place in the order. If SwayFX puts a window that changed layer on top of its new layer, then after fullscreen ends it draws over the bars. Needs a look in `scripts/dev/nested.sh sway` with SwayFX.
- **Size:** small
- **Found:** 2026-10-16, while auditing the sway branch for merge

### Hyprland's key capture watchdog can end a later capture
- **Where:** `services/HyprlandManager.qml` (`captureKeys`)
- **What:** Each capture enters the one `axiom_record` submap with a 30 s `hl.timer` leaving it; a second capture within those 30 s is cut short by the first's timer. Sway's got a mode name per capture (796b16e); Hyprland's needs the same or a timer handle it removes.
- **Size:** trivial
- **Found:** 2026-10-16, while auditing the sway branch for merge

### Monitor VRR offers Hyprland's modes on sway
- **Where:** `components/views/monitors/MonitorInspector.qml`, `components/methods/SwayConf.qml` (`outputCommand`)
- **What:** VRR offers Off/On/Fullscreen only/Fullscreen games and video; sway has on or off, so the fullscreen ones turn adaptive sync on everywhere. A capability (`monitorVrrModes`) would offer only Off/On without it.
- **Size:** trivial
- **Found:** 2026-10-16, while auditing the sway branch for merge

### A fullscreen window re-sends the whole live layer
- **Where:** `services/CompositorConfigManager.qml` (`_liveInputs`)
- **What:** `BlurManager.active` flips as a fullscreen window opens or closes and is in `_liveInputs`, so each flip re-sends the whole look and input (Hyprland's `hl.config({ input = … })`, sway's `[all] border pixel`, `gaps … all set`), not just the blur rules: a user's runtime tweak (`border toggle`, `gaps current plus`) is undone whenever anything goes fullscreen. A blur-only change should send only the blur lines.
- **Size:** small
- **Found:** 2026-10-16, while auditing the sway branch for merge

### Any change of the mode to managed approves the takeover
- **Where:** `services/CompositorConfigManager.qml` (`onModeChanged`)
- **What:** Picking managed while axiom runs counts as approval, which includes editing config.json by hand or a sync tool writing it, not only the card's Save that `docs/dev/compositor/config-modes.md` describes. Imports keep `x-takeover`, so only direct edits reach it. Approving from SettingsManager's save only, or saying so in the doc.
- **Size:** small
- **Found:** 2026-10-16, while auditing the sway branch for merge

### Sway's bind reading misses blocks and quoted outputs
- **Where:** `components/methods/SwayConf.qml` (`configBinds`), `services/SwayConfigWriter.qml` (`monitorPattern`)
- **What:** `bindsym { … }` blocks (the head applies to each inner line) aren't read, so axiom's runtime `bindsym --no-warn` overrides those keys; binds inside `bar { … }` count as main-mode binds. The monitor-rule check misses `output "Make Model Serial" …` and `output X { … }`.
- **Size:** small
- **Found:** 2026-10-16, while auditing the sway branch for merge

### Unreadable sway config means axiom binds over the user's keys
- **Where:** `services/RuntimeLayer.qml` (`_start`)
- **What:** When `sway_config_text.py` fails (it logs `Can't read your sway config`) the layer treats the user as binding nothing, and binds with `--no-warn` over their keys after every reload. Hyprland's layer does the same. Binding nothing (look and input only) with a problem shown would be safer, at the cost of axiom's binds.
- **Size:** small
- **Found:** 2026-10-16, while auditing the sway branch for merge

### claim_sway.sh doesn't check its own edits
- **Where:** `scripts/claim_sway.sh` (`adopt_lines`)
- **What:** `adopted:` is printed even when commenting out failed (its result isn't checked); `$dir` goes unescaped into a sed replacement with `|` as the delimiter, so a path holding `|`, `&` or `\` breaks it; quoted relative includes, and all but the first path of a multi-path `include`, aren't made absolute.
- **Size:** small
- **Found:** 2026-10-16, while auditing the sway branch for merge

### Turning sway's window opacity off reloads sway
- **Where:** `services/CompositorConfigManager.qml` (`_appliedParts`)
- **What:** Opacity counts as an applied part, so turning it off reloads the config (see "Changing a setting under sway can flash the screen"), though SwayManager already sets every window back to 1 itself. A part the backend takes back itself shouldn't count.
- **Size:** trivial
- **Found:** 2026-10-16, while auditing the sway branch for merge

### The onboarding's Compositor page names Hyprland
- **Where:** `components/surfaces/onboarding/pages/CompositorPage.qml`, `services/OnboardingManager.qml` (`detectCompositor`)
- **What:** It gates on `CompositorManager.kind !== "hyprland"` and reads `HyprlandManager.withVersion` (and the page shows Hyprland's legacy notice) rather than a capability, and calls `CompositorManager.backend?.unsupportedHint` from UI. A writer hook (`legacyConfig`, `configProblem`) and a CompositorManager passthrough would keep it neutral.
- **Size:** small
- **Found:** 2026-10-16, while auditing the sway branch for merge

### SwayFX's corner radius reaches only windows opened later
- **Where:** `components/methods/SwayConf.qml` (`fxLines`)
- **What:** `corner_radius` sent at runtime sets SwayFX 0.6's global only (its per-window reset runs only while the config loads), and it has no per-window command, so a changed rounding shows on new windows while open ones keep theirs until sway reloads its config. A fix would need a reload, which takes back the rest of the runtime look.
- **Size:** small
- **Found:** 2026-10-16, while fixing SwayFX's blur on unfocused windows

### Changing a setting under sway can flash the screen
- **Where:** `services/LayerManager.qml` (`_sequence`), `components/hosts/popout/LayerSlot.qml`, `services/MonitorManager.qml`
- **What:** Reported on sway: changing a setting flashes the whole settings page. Two causes fixed: the border's shadow window wasn't held, so turning the shadow on remapped every surface ordered under it (`LayerManager: mapping … again, in its place` for the backdrop, bars, border and dock, the backdrop dimming the overlay flashing with them), and a sway reload (any save rewriting axiom's file) reset the outputs to the config's, dropping the monitor profile. Not reproduced with an ordinary setting since (a save then logs no remap and no overlay resize). Without `layerOrder`, a bar remade by a change of kind still remaps everything after it, by design. If it still happens, note which setting and look for those log lines.
- **Size:** small
- **Found:** 2026-10-16, while auditing the sway branch

### Sway's special workspaces are floating scratchpad windows
- **Where:** `services/SwayManager.qml` (`toggleSpecial`, `moveToSpecial`), `components/methods/SwayState.qml` (`specialToggle`)
- **What:** Hyprland's special workspace is a tiled workspace drawn over the current one; sway has none, so a special group is marked scratchpad windows, and sway's scratchpad makes every window floating, centred and stacked on the others (a group of three shows as three overlapping windows). Options: keep the scratchpad and lay the group's windows out in a grid on show (`move position` / `resize set` per window, over the workspace like Hyprland's), or a hidden named workspace per group (tiles, but replaces the view instead of overlaying it). A group name holding `,` or `;` also breaks its `nop axiom special` bind (sway splits the command there).
- **Size:** needs a plan
- **Found:** 2026-10-16, while auditing the sway branch

### Smart gaps make sway's gaps and reserved space wrong
- **Where:** `components/methods/SwayState.qml` (`output`, `configInfo`), `services/SwayManager.qml` (`gapsOut`)
- **What:** With `Sway.smartGaps` on (`smart_gaps on`), a workspace with one window has no gaps, but `gapsOut` still reports the configured ones, and `output().reserved` (the workspace rect less those gaps) comes out short by them. Bars and edge menus placed from `gapsOut` and the dock's `reserved` are then off by the gap on such a workspace. Needs per-workspace gaps (whether the active workspace has one tiled window).
- **Size:** small
- **Found:** 2026-10-16, while auditing the sway branch

### Overview drops on sway nest split containers
- **Where:** `services/SwayManager.qml` (`placeWindow`)
- **What:** A drop next to a window runs `split h|v` on the target every time, which wraps it in a new container even when its parent already splits that way, so repeated drops nest containers sway then draws as such (tabbed/stacked parents behave oddly). Split only when the parent's layout differs (the tree has it).
- **Size:** small
- **Found:** 2026-10-16, while auditing the sway branch

### Detached sway keeps the floating modifier after the mouse binds go
- **Where:** `services/SwayRuntimeLayer.qml`, `components/methods/SwayConf.qml` (`unbindLines`, `floatingModifier`)
- **What:** The runtime layer sends `floating_modifier` for the drag/resize binds but its unbind commands don't take it back, so removing them in detached mode leaves sway's floating modifier set until sway reloads. It also overrides a `floating_modifier` of the user's own config, which `BindKeys.runtimeBinds` doesn't see as a taken key.
- **Size:** small
- **Found:** 2026-10-16, while auditing the sway branch

### `noWarps` off maps to sway's `mouse_warping output`
- **Where:** `config/json/config.schema.json` (`WindowBehaviour.noWarps`, `x-swayMap`)
- **What:** Hyprland with `cursor.no_warps` off moves the cursor to a window focused by keybind; sway's `mouse_warping output` only moves it when focus changes output (`container` would match Hyprland). Decide which sway value matches what the setting promises.
- **Size:** trivial
- **Found:** 2026-10-16, while auditing the sway branch

### Quickshell's I3 socket warns on every reload
- **Where:** `services/SwayManager.qml` (Quickshell.I3)
- **What:** Under sway every reload of the shell logs `I3 event socket disconnected` twice (category `quickshell.I3.ipc`), from the old generation's sockets closing. Events still arrive afterwards (checked in nested sway). Quickshell's, not axiom's; nothing to fix here unless it starts dropping events.
- **Size:** trivial
- **Found:** 2026-10-16, while writing the sway backend

### Qt text-input warnings under sway and niri
- **Where:** `components/reusable/StyledTextEntry.qml` (the text fields; Qt's own wayland text-input)
- **What:** Under sway and niri the log fills with `Trying to disable` / `Trying to enable` warnings from `qt.qpa.wayland.textinput` (`QWaylandTextInputv3::disableSurface`) as keyboard focus moves between axiom's surfaces. Seen live on sway and niri (2026-10-17), never under Hyprland; typing still works. Likely Qt's text-input-v3 handling with several layer surfaces taking focus.
- **Size:** small
- **Found:** 2026-10-16, while consolidating compositor settings

### Floating bars sit flush on the border without a backend
- **Where:** `config/Bar.qml` (`enrichBarConfig`: `floatGap`), `services/CompositorManager.qml` (`gapsOut`)
- **What:** A floating bar's automatic gap (`floatGap` -1) is the compositor's outer gaps (`CompositorManager.gapsOut`). With no backend (an unknown compositor) `gapsOut` is all 0, so a floating bar sits flush against the border. Sway's and niri's backends read their gaps from the config (`SwayState.configInfo`, `scripts/niri_config.py info`); decide what the gap is with no backend at all (a fixed default, or `Appearance.screenMargin`).
- **Size:** small
- **Found:** 2026-10-16, while testing layer order in nested sway

### Blur behind axiom on niri
- **Where:** `services/NiriManager.qml` (`supports`), `shell/BlurBackingWindow.qml`, `components/methods/SurfaceOutline.qml`
- **What:** niri has no `blur` capability yet, so axiom's surfaces are solid there and the translucency setting is greyed out. niri blurs a layer surface's whole rect (a layer rule), not by its pixels' alpha as Hyprland and SwayFX do, so the full-screen blur window can't be blurred that way. It does take a region per surface (`ext-background-effect-v1`, Quickshell's `BackgroundEffect.blurRegion`): checked in nested niri 26.04, a rounded `Region` blurs exactly. What's missing is each `BlurShape` as a region: rects with their radius, the border frame as the screen less its inner rect, an attached surface as its box (`SurfaceOutline` metrics) with its fillets. Then `supports.blur`, with that region on the blur window.
- **Size:** needs a plan
- **Found:** 2026-10-17, while adding the niri backend

### niri reports no space reserved by bars, nor where tiled windows are
- **Where:** `components/methods/NiriState.qml` (`outputs`, `windows`)
- **What:** niri's IPC gives no layer surface geometry and, in 26.04, no position for a tiled window (`tile_pos_in_workspace_view` is null; only floating windows have one). So an output's `reserved` is 0 (the dock centres on the whole screen, not its work area), and tiled windows are laid out from their column and place in it from the output's edge, without niri's scroll (`windowGeometry` stays off: no screenshot window mode; the dock hides behind a window's `cover`, its column or the whole output, which ignores struts, reserved space and `center-focused-column`).
- **Size:** small
- **Found:** 2026-10-17, while adding the niri backend

### niri's flags can't be turned off from axiom
- **Where:** `components/methods/NiriConf.qml` (`_niriArgs`), `config/json/config.schema.json` (`x-niriValue: "flag"`)
- **What:** A niri flag (`tap`, `natural-scroll`, `numlock`, `focus-follows-mouse`) is on by being there and has no `false`; axiom writes one on and leaves it out off. Off in axiom while the user's own config has it on, it stays on.
- **Size:** small
- **Found:** 2026-10-17, while adding the niri backend

### Nested niri freezes while its window is hidden
- **Where:** `scripts/dev/nested.sh` (niri)
- **What:** niri's nested (winit) backend stops its event loop while its window isn't shown on the host (another workspace): its IPC times out and the axiom inside it hangs waiting on it, so a `qs ipc` call never returns. Keep the nested window visible while testing; it carries on once shown again.
- **Size:** trivial
- **Found:** 2026-10-17, while testing the niri backend

### The greeter runs its own Hyprland session
- **Where:** `scripts/greeter/greeter-session.sh`, `services/GreetdManager.qml` (`_applyHyprland`)
- **What:** The greeter runs its own Hyprland session (`start-hyprland`, `hyprctl dispatch exit`), whatever compositor the user's session uses. Decide whether it keeps Hyprland or moves to cage/sway. (The onboarding's binds table and Welcome copy no longer assume Hyprland.)
- **Size:** small
- **Found:** 2026-10-16, while decoupling the shell from Hyprland

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

### Python bytecode is written into the repo
- **Where:** `scripts/bind_merge_common.py`, `scripts/niri_kdl.py`
- **What:** Scripts that import a sibling module (the bind mergers, the niri config scripts) leave `__pycache__/` in `scripts/`, which a packaged (read-only) install can't write. Set `PYTHONDONTWRITEBYTECODE=1` where the shell runs python. Blocks packaging, not the XDG move.
- **Size:** small
- **Found:** 2026-10-15, while moving config and state to the XDG folders

### Hyprland starts axiom by its repo path, and self-update assumes git
- **Where:** `services/HyprlandConfigWriter.qml` (`shellCommand`), `services/SelfUpdateManager.qml`, `scripts/greeter/greeter_install.sh`
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

### `Compositor.requiredSettings` has no developer doc
- **Where:** `config/HyprlandConfig.qml` (`requiredSettings`), `docs/dev/hyprland/config-modes.md`
- **What:** It's in the schema and the generated reference (`docs/dev/config/Hyprland.md`), but no hand-written doc explains what it does. Add a section to `config-modes.md`. (`wallpaperDaemon` moved to `Appearance.wallpaperDaemon`, covered in `wallpaper-and-schedules.md`.)
- **Size:** trivial
- **Found:** 2026-10-13, while splitting architecture.md
