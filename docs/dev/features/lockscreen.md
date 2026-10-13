# Lockscreen

> **Files:** `services/LockManager.qml`, `services/AuthManager.qml`, `shell/Lockscreen.qml`, `components/surfaces/lockscreen/LockSurface.qml`, `components/surfaces/lockscreen/LockPreviewWindow.qml`, `components/surfaces/screenlayout/ScreenLayoutView.qml`, `components/content/Password.qml`, `components/content/parts/PasswordField.qml`, `components/content/parts/FocusKeeper.qml`, `components/reusable/PasswordEntry.qml`, `components/content/Greeting.qml`, `services/ScreenLayoutEditor.qml`, `components/views/layouts/LockscreenTarget.qml`, `config/LockscreenConfig.qml`
> **Config:** `Lockscreen.mode`, `Lockscreen.lockCommand`, `Lockscreen.blurWallpaper`, `Lockscreen.layout` (reader `LockscreenConfig`)
> **Related:** [Idle](idle.md), [Greeter runtime](greeter-runtime.md), [Desktop](desktop.md), [Layouts editor](../overlay/layouts-editor.md), [Grid canvas](../overlay/grid-canvas.md), [Themes](../theming/themes.md), [Shell targeting](../core/shell-manager-targeting.md)

This doc covers the three lock modes, how the built-in lock screen's layout of modules works (grid, hosts, password, background), and how it is edited and previewed. (Rule: CLAUDE.md › UI conventions › Lockscreen; never lock the session while testing.)

### Locking
- `LockManager.lock()` is the one way to lock.
  - Lock buttons call it through `ShellManager.sessionAction("lock")`.
  - Idle daemons call it through the `lockscreen` IPC target.
- `lock()` ends a running preview first.

### Modes (`Lockscreen.mode`)

#### `quickshell` (default)
- The built-in locker, `shell/Lockscreen.qml`.
  - A `WlSessionLock` (Wayland `ext-session-lock-v1`, the protocol hyprlock uses).
  - One `WlSessionLockSurface` per screen, showing `surfaces/lockscreen/LockSurface.qml`.
- While locked, the compositor shows only the lock surfaces and sends them all input.
- If qs dies, the session stays locked (Hyprland's fallback). `misc:allow_session_lock_restore` lets a restarted qs take the lock back.
- The locked state lives in a `PersistentProperties`, so a QML reload comes back locked.
- **Only `AuthManager.authenticationSucceeded` (PAM, `login` stack) unlocks.**
  - There is no IPC unlock.
  - Nothing on the surface may run commands.

#### `hyprlock`
- `ThemeManager.generateHyprlockConfig()` writes `$XDG_STATE_HOME/axiom/hyprlock.conf` from `scripts/templates/hyprlock_template.conf`. It fills in theme colors, font, wallpaper, blur and the translated greeting.
- It regenerates on theme, wallpaper, font or language changes, and on switching to this mode.
- Locking runs `hyprlock -c` with that file.
- The user's own `hyprlock.conf` is never touched.

#### `none`
- Axiom provides no locker and no IPC target, so an idle daemon pointed at axiom can't loop through `loginctl lock-session`.
- Lock buttons run `Lockscreen.lockCommand`.

#### hypridle
- `Idle.enabled` has axiom run hypridle with its own config ([idle.md](idle.md)).
- A user's own hypridle:
  - For the first two modes it uses `lock_cmd = qs -c axiom ipc call lockscreen lock` and `before_sleep_cmd = loginctl lock-session`.
  - For `none` it has no axiom references.

### Layout
- **Where it lives:** `Lockscreen.layout`, marked `x-settings: false`.
- **Where it's edited:** the Layouts page's Lock screen row.
- **What a real lock shows:** only `LockscreenConfig.layout`, the saved layout. Unsaved drafts never reach a real lock.

#### Grid
- Overlay modules sit on a bounded grid of `columns` × `rows` units (16 × 9 by default), placed absolutely from the top left. The grid is a `ScreenLayout`, shared with the greeter.
- **`fineGrid` ("Double grid")** splits each unit in two each way. `GridPlacement.screenGrid(layout)` gives the grid in the units places use.
  - Turning it on or off rescales every place (`GridPlacement.scalePlace`, in `ScreenLayoutEditor.updateLayoutField`). Merging rounds each edge, so modules that met still meet.
  - The `GridEditor`'s `sizeScale` doubles new modules' default sizes.
- **Fitting to the screen:** `LockSurface` fits the grid to each screen inside a `cardSpacing` margin. It is built on `surfaces/screenlayout/ScreenLayoutView`, which holds the background, dim and fitted grid it shares with `GreeterSurface`. The fit uses:
  - an `OverlayGrid` whose `fixedUnit` is `GridPlacement.latticeUnit`; the axis with less room decides;
  - a `ModuleGrid` with `extent` set to the lattice (or to what the modules reach, if more) and `stretch` set to the screen.
  So the units stretch to fill a screen of another shape, and placements keep their relative spot.
- The editor draws the lattice inside a screen outline (`LockscreenTarget.screenBox`).

#### Hosts
- Modules get `host: { kind: "lockscreen", target, preview, key, bare, passwordBorder, greetingBorder }`.
- **`bare`** is `!moduleBorders`: no card box.
  - Unlike a bare edge menu module, it keeps its padding (`SlotContext.pad`), since nothing else pads it.
- **`Password` and `Greeting`** ignore `bare` here. Their boxes follow the layout's own `passwordBorder` / `greetingBorder` (off by default).
- **Which modules may go here:** only module types whose `x-hosts` list `lockscreen`.
  - Display-only modules.
  - NowPlaying (media transport) and VolumeDials.
  - Power: suspend, restart, shut down through `ShellManager.sessionAction`; restart and shut down ask twice.
  - Nothing that launches, dispatches, kills, writes files or shows private content.
- A new module stays off the lock screen unless it is added there deliberately.

#### Password
- **What it is:** the `Password` module (`x-hosts: ["lockscreen"]`, `x-required`) draws `content/parts/PasswordField`. The field talks to `AuthManager`.
- **When it's live:** the field keeps keyboard focus only when `active`, which means on the `target` screen of a real lock (`host.target && !host.preview`). Anywhere else it is inert.
- **Required-field report:** the module reports itself to `ShellManager.reportRequiredField(host.key, true)`.
  - Each surface's key comes from `ShellManager.newSurfaceKey(kind)` and is never reused.
  - Keys used to be screen names. A monitor that dropped out and came back while turning off then had its old surface's teardown clear the new surface's report, which flickered the fallback in.
- **Fallback field:** a surface whose key has no report shows a `PasswordField` of its own, so a hand-edited or broken layout can never lock anyone out.
  - It appears a tick after loading, near the bottom, over the modules.
- **Stable layout:** the field never moves or grows with its messages (`reusable/PasswordEntry`).
  - The message line's room is kept (`reserveMessage`).
  - The busy bar runs over the field's bottom edge.
- **Short slots:** a slot too short for the message line (one row on a doubled grid) changes the layout, as the greeter's `Login` does:
  - the card padding is dropped;
  - the field shrinks to fit;
  - the message shows as the empty field's placeholder (`inlineMessage`).
- **Focus** comes back through `content/parts/FocusKeeper` (also used by `LoginField`).
  - It waits while a clicked control is pressed, because a button that loses focus mid-press drops its click (the calendar arrows did).
- `AuthManager` answers PAM's prompts without showing them.

#### Other screens (`otherScreens`)
- `layout`: shows the modules without `Password`.
- `background`: shows only the background.

#### Background
- `background` is one of:
  - `wallpaper`: `Appearance.wallpaperFor(screen)`, blurred by a `MultiEffect` when `Lockscreen.blurWallpaper` is on. hyprlock's config follows the same setting.
  - `color`: `backgroundColor`.
- Either way it sits under a black layer at `dim`%.

#### Greeting module
- `content/Greeting` works on any host. It draws a line of text fitted to its slot (`Text.Fit`).
- Placeholders:
  - `{name}`
  - `{user}`
  - `{greeting}`: a `SystemClock` at hour precision, running only while the text uses it.
- Empty text means the translated "Hey {0}".
- On the real greeter the names are `GreetdManager.selectedUser`'s. With no user selected yet it shows "Welcome".

### Editing and preview
- **The editor:** `LockManager.editor` is a `services/ScreenLayoutEditor`, a non-singleton shared with the greeter. It holds:
  - the draft, a `ConfigDraft` of `["Lockscreen", "layout"]`, so it never fights the settings page's draft over `mode`;
  - its `GridEditor` (`layout`);
  - `problems`, `updateLayoutField`, `ensureLoaded` / `saveChanges` / `resetChanges`;
  - the preview.
- **Show on screen** (`startPreview()`):
  - It closes the overlay and shows `surfaces/lockscreen/LockPreviewWindow` on the target screen. The screen is fixed when the preview starts (`previewScreen`).
  - That window is on the Overlay layer, with exclusive keyboard focus, and holds `LockSurface { preview: true }` showing the draft.
  - Nothing is locked, and the field is inert (it lets Escape through).
  - Escape or a click on the background (`stopPreview()`) reopens the overlay on Layouts.

### Testing
- Look at the lock screen through `LockManager.startPreview()`, called from a temporary `IpcHandler` in `shell.qml`; revert the handler afterwards.
- Put demo layouts on the draft only, then `resetChanges`.
- Test `LockSurface` in a hidden window, never by locking for real: only the user can type the password.
