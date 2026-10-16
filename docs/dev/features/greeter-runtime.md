# Greeter: runtime (bundle, session, greeter mode, login)

> **Files:** `greeter.qml`, `shell/Greeter.qml`, `shell/GreeterPreview.qml`, `components/surfaces/greeter/GreeterSurface.qml`, `components/surfaces/greeter/GreeterWindow.qml`, `components/surfaces/greeter/GreeterPreviewWindow.qml`, `services/GreetdManager.qml`, `services/GreeterManager.qml`, `components/methods/GreeterBundle.qml`, `components/methods/GreeterUsers.qml`, `components/methods/GreeterSessions.qml`, `components/content/Login.qml`, `components/content/Session.qml`, `components/content/KeyboardLayout.qml`, `components/content/Power.qml`, `components/content/parts/LoginField.qml`, `scripts/greeter/greeter-session.sh`, `scripts/greeter/hyprland.lua`
> **Config:** `Greeter.*` (reader `GreeterConfig`), plus the sections exported in the bundle
> **Related:** [Greeter install](greeter-install.md), [Lockscreen](lockscreen.md), [Themes](../theming/themes.md), [Config manager](../core/config-manager.md), [Monitors](../hyprland/monitors.md), [Schema annotations](../core/schema-annotations.md)

This doc covers what runs at the login screen and the data it reads: the bundle the user's axiom exports, the greetd session script, greeter mode (`Paths.greeter`), `GreetdManager`'s login API, and the greeter's surfaces and modules. Installing the root-owned copy is in [greeter-install.md](greeter-install.md).

### Who owns what
- **`GreeterManager`:** axiom as greetd's login screen, seen from the user's side (install, bundle, status). It is created from `shell.qml`'s `_services`.
- **`GreetdManager`:** the login in the greeter itself. Only greeter-side code references it.

### The bundle
- `GreeterBundle.exportConfig` (pure) builds the bundle from:
  - the `Greeter`, `Appearance`, `General`, `Weather` and `Lockscreen` sections;
  - `Hyprland.mode` and `monitors.profiles`;
  - in managed mode, the `Hyprland.managed` options marked `x-greeter` (keyboard, mouse, touchpad, cursor);
  - `theme.json` (`ThemeManager.currentTheme`);
  - each wallpaper showing (`ThemeManager.shownWallpapers`, exported as fixed ones in `fixed` mode, so the greeter shows what the desktop does), copied to `wallpapers/<md5 of its url>.<ext>` (cp + mv, stale ones removed). The bundle's `Appearance` names these copies.
- **How it's written:** one `sh` (`GreeterManager._writeBundle`).
  - Each JSON goes through a temp file and a rename.
  - Then `chmod -R go+rX`, so greetd's user can read it whatever the umask.
- **When it's written:**
  - while the greeter is installed and the bundle writable, a second after any of it changes; a failed write is retried on the next change;
  - right after an install or update succeeds, so the greeter never starts before its bundle exists;
  - JSON only, to the staging folder before an install or update.
- Changing the login screen therefore needs no root. Only code changes need Update.

### Running it (session script)
- `greeter-session.sh`, greetd's command, starts `start-hyprland` on `scripts/greeter/hyprland.lua` (logo off, numlock on, no animations).
- That Lua's start hook runs `greeter-session.sh shell`, which runs `AXIOM_GREETER=1 qs -p <copy>/greeter.qml`.
  - If that fails, it runs once more with `AXIOM_GREETER_SAFE=1`; qs exits non-zero on a broken load.
  - Then `hyprctl dispatch 'hl.dsp.exit()'`.
- **Fallback:** if qs failed twice, or there is no Hyprland, the session runs `agreety --cmd '${SHELL:-/bin/sh}'`, so a login is always possible.
  - The failure marker lives in `$XDG_RUNTIME_DIR`, else the greeter's `state/`, never in `/tmp`.
  - The command is quoted so the session's own `sh` expands it to the login shell of whoever logs in.

### Greeter mode
- **How it's detected:** `AXIOM_GREETER=1` sets `Paths.greeter`. `ConfigManager.greeter` reads the environment again itself, since `ConfigManager` reads no reader.
- **What it builds:** `greeter.qml` builds only `shell/Greeter`, a `GreeterWindow` per screen.
  - `AXIOM_GREETER_WINDOWED=1` builds one `FloatingWindow` instead, for looking at it from a session.
  - `AXIOM_GREETER_DIR` points it at a scratch folder.
- **Config:** `ConfigManager` loads `GreeterBundle.pick([bundle, fallback/])`.
  - It takes the first that parses and passes migrate, prune, defaults and validate.
  - A bundle from a newer axiom is still tried, with its unknown keys pruned.
  - If none passes, it uses schema defaults, logging why each was skipped.
  - It never writes, watches or polls.
- **Theme:** `ThemeManager` reads the `theme.json` beside the config named by `ConfigManager.greeterSource` (the bundle's, else `fallback/`'s), so safe mode never loads a bundle theme.
  - It generates, links and runs nothing.
- **State:** `Paths.statePath` / `userStatePath` point at the greeter's `state/`.
- **Startup:** singletons are lazy, so nothing else from the session starts.
- (Rule: in greeter mode nothing writes config, generates or runs integrations; AGENTS.md › Greeter.)

### GreetdManager
Built on `Quickshell.Services.Greetd`.
- **Users:** `users` comes from `methods/GreeterUsers`: `/etc/passwd` within `/etc/login.defs`' UID range, login shells only.
- **Sessions:** `sessions` comes from `methods/GreeterSessions`: `wayland-sessions/*.desktop` in each data dir (`Paths.dataSearchDirs`: `$XDG_DATA_HOME`, then `$XDG_DATA_DIRS`; the first file of a name wins, as `GreeterSessions.files` picks), with Exec split per the desktop entry spec and field codes dropped.
- **Selecting a user:** `selectUser(name)`. A typed name not in the list is still tried. Selecting loads the user's last session.
- **Logging in:**
  - `submit(response)` creates the session, with the password pending for greetd's first question.
  - Later questions (an OTP) become `prompt` / `promptEcho`.
  - `cancel()` and `failed` are also exposed.
  - The session launches with `XDG_SESSION_TYPE` / `XDG_CURRENT_DESKTOP` / `XDG_SESSION_DESKTOP`.
  - It remembers the user (with `rememberUser`) and their session.
- **Other:**
  - `power(action)` through `systemctl`.
  - Keyboard layouts through `CompositorManager.withKeyboard` and `cycleKeyboardLayout`.
  - `avatarOf(name)` from AccountsService's icons.
- **At start** (but not when windowed):
  - it evals `HyprLua.greeterLua`: the profiles' `monitorsLua` in every mode, plus one `hl.config` of the `x-greeter` options in managed mode;
  - it sets the cursor (`HyprlandManager.setCursor`).

### Surfaces and modules
- **`surfaces/greeter/GreeterSurface`** is a `ScreenLayoutView`, the same view the lock screen uses ([lockscreen.md](lockscreen.md#layout)).
  - Its host is `{ kind: "greeter", target, preview, key, bare, passwordBorder, greetingBorder }`.
  - The target is `Greeter.monitor`'s screen. Other screens follow `otherScreens`.
  - With no Login module reported (`ShellManager.requiredFields`), it draws a `content/parts/LoginField` of its own.
- **Greeter-only modules:**
  - `Login` (`x-required`): a `LoginField` holding a `StyledComboEntry` of users (can be typed over), a `PasswordEntry`, and the user's picture.
    - In a slot too short to stack them, the two fields go side by side.
    - In a slot shorter than one field, they shrink to fit.
  - `Session`: in a slot shorter than its card, just the field, with no card.
  - `Power`: restart and shut down ask twice. It is also on the lock screen.
  - `KeyboardLayout`.
- **Display modules** that list `greeter` in `x-hosts`: ClockCalendar, Greeting, Weather, Battery, Network, Palette, ColorSwatch.
- **Inert outside the greeter:** every greeter module is inert unless `host.kind === "greeter" && !host.preview && Paths.greeter`, so the user's session never talks to greetd.
- **Host filtering:** `ScreenLayoutView` draws only modules whose `x-hosts` list the host's `kind`.
  - Validation accepts any module in a `ScreenLayout`.
  - The bundle's folder is writable by any of the user's programs.
  - So the filter is what stops a hand-made bundle from putting a launcher on the login screen.
- **Preview:** "Show on screen" (`GreeterManager.editor`, a `ScreenLayoutEditor`) shows `GreeterPreviewWindow`, built by `shell/GreeterPreview`.

### Testing
- Look at the greeter in a window: `AXIOM_GREETER=1 AXIOM_GREETER_WINDOWED=1 AXIOM_GREETER_DIR=<scratch> qs -p "$PWD/greeter.qml"`.
- Stop only that instance with `qs kill`. Never restart greetd: it ends the session.
