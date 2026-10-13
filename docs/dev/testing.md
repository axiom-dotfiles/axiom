# Testing and debugging the running shell

> **Files:** `scripts/log.sh`, `scripts/check_all.sh`, `scripts/run_tests.sh`, `scripts/dev/popout_matrix.py`, `tests/`
> **Config:** none
> **Related:** [Developer docs](README.md), [CLAUDE.md](../../CLAUDE.md) (Running / reloading, Never while testing, Checks)

How to look at, exercise and debug the live shell without breaking the user's session, plus where every feature's own testing notes live. What you must never do while testing is in CLAUDE.md › "Never, while testing".

### The loop
- `scripts/dev/verify.sh` after every change: formats the changed QML in place (keeping the inode), runs `check_structure`, regenerates the docs, lints, runs the affected unit tests (a changed `methods/<Name>` runs `tst_<Name>`, a schema or migration change runs `Config` and `ConfigExamples`), shellchecks changed scripts, and prints the shell's log since the reload. `--all` runs `check_all.sh`.
- `scripts/dev/shot.sh` takes a screenshot of a surface and closes it again, printing the PNG's path: `page <ViewType>`, `launcher [text]`, `ipc <target> <open> [close]`, `screen`; `-m MONITOR` (default the focused one), `-w SECONDS`.

### Reloads and logs
- The shell runs detached and hot-reloads files it has loaded. Never start or stop it yourself; a relaunch from a shell once reset config.json to defaults. Ask the user to restart.
- `scripts/log.sh` shows warnings and errors since the last reload. `--debug` adds `console.log`, `--all` covers earlier reloads, `-f` follows, `-g PATTERN` filters. A clean reload is just `Reloading configuration...` + `Configuration Loaded`.
- **qs watches files by inode.** `sed -i`, `/usr/lib/qt6/bin/qmlformat -i`, `git checkout <file>` and `git stash push/pop` all replace the inode. Later edits to that file may then not reload, and the shell silently keeps old code.
  - To force a reload, make a real in-place content change to a file that's still watched (append `// x` with Python's `open(p, 'w')`, then remove it). Rewriting identical content doesn't count.
  - Count `Reloading` lines in `scripts/log.sh --all` before and after to confirm.
  - Revert temporary edits in place, not with `git checkout`.
- A failed reload leaves the old generation running. Force a clean reload before editing config.json.
- To wait for a reload: `timeout 8 bash -c 'until scripts/log.sh | grep -q "Configuration Loaded"; do :; done'`.
- Raw logs: `qs log -c axiom -f` (or `-t 50`); each instance also writes `/run/user/$UID/quickshell/by-id/<instance>/log.log` (plain text; `pgrep -af "qs -c axiom"` finds the instance). stdout and journalctl show nothing.
- If config.json was lost (it falls back to defaults), restore it from a snapshot in `config/user/saved/`.
- **Renaming or deleting a singleton** can leave a reload failing with `Type <Old> unavailable … File not found`: one fired between the edits and kept the old file in its module listing. Force one more reload (above); it rescans and loads. Add the old name to `RETIRED` in `scripts/check_docs.py` so docs still citing it fail.

### Seeing a page or surface
- Overlay pages: `scripts/dev/shot.sh page <ViewType>` does all of this. By hand: `qs -c axiom ipc call overlay page <ViewType>`, then `grim -o <monitor>` (or `grim -g "X,Y WxH"`), crop with `magick`, read the PNG, then `qs -c axiom ipc call overlay close`.
- The overlay only instantiates the current page and its neighbours, so a page's QML errors only reach `scripts/log.sh` once it's been opened like this.
- **`show` is a qs IPC keyword:** `qs -c axiom ipc call <target> show` prints the target's functions instead of calling `show()`. Use `toggle` (or `hide`).
- A temporary `IpcHandler` (for a settings category, a lockscreen preview, a screenshot hook) goes in `shell.qml`, never inside a singleton, where it never registers. It needs `import Quickshell.Io`. Revert it in place afterwards.
- Never simulate cursor movement to verify UI. Reason from logs and bindings; if it really needs interactive checking, ask the user to look.
- Per-feature recipes:
  - Launcher: [launcher.md › Testing](features/launcher.md) (`appLauncher search`, focus stealing).
  - Lock screen: [lockscreen.md › Testing](features/lockscreen.md) (`LockManager.editor.startPreview()`, draft-only demo layouts).
  - Greeter: [greeter-runtime.md › Testing](features/greeter-runtime.md) (windowed greeter) and [greeter-install.md › Testing](features/greeter-install.md) (scratch root).
  - Onboarding: [onboarding.md › Testing](features/onboarding.md) (`ipc call onboarding goTo <n>`).

### Popout and layering checks
- `scripts/dev/popout_matrix.py OUT_DIR [--only layout__variant ...]` shoots every bar layout × border × opacity scenario: [surface-context.md › Testing](popouts/surface-context.md).
  - It rewrites config.json per scenario and installs a temporary IPC hook in shell.qml. Stop it only with SIGINT (`pkill -INT -f popout_matrix.py`); SIGTERM leaves both modified.
  - About 1 min per scenario. Don't edit loaded QML while it runs. Use `log.sh --all` afterwards, since its cleanup reloads.
  - Edge menus opened over IPC close at once unless pinned, so it pins and unpins them.
- **Fullscreen must cover bars and the border.** This is a recurring regression. After changing layer rules (`HyprlandManager.layerRulesLua`), `WlrLayershell.layer` or `aboveWindows`, test a fullscreen window on a normal and on a special workspace.
  - Hyprland hides Top layers over fullscreen by fading them (`m_aboveFullscreen`), not by draw order. A Top layer that *maps* while a fullscreen window is up draws over it, so never map a Top window in response to fullscreen. Keep it mapped and hide its contents.
  - Known Hyprland 0.56.2 bug: on scrolling-layout (strip) monitors, a fullscreen window on a special workspace goes under the bars.

### Config and schema
- Rename or reshape a config key with the schema change first (or both in one edit), then the `ConfigMigration` step. A migration saved before its schema hot-reloads against the old schema, writes the config back and loses the user's values.
- Adding a module to the live config: [writing-modules.md › Testing](overlay/writing-modules.md). Confirm the schema reloaded (the latest `Loading config schema` line in the instance's `log.log` is newer than the schema file's mtime), back up config.json to a scratch dir and restore it afterwards, add one module at a time, and watch qs's RSS.

### JS and QML experiments
- Engine gaps (`flatMap`, `Object.fromEntries`, `Intl`) are in CLAUDE.md › Formatting, the inline-component trap in › QML pitfalls. `toLocaleString(..., { timeZone })` is ignored too: see [clock-timezones](features/clock-timezones.md).
- For quick JS checks, run a scratch `tst_x.qml` with `QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input <dir>`. The plain `qml` tool prints nothing.

### CI locally
- To dry-run the CI `qt` job in a clean container:
  1. Copy the tracked and new files (`git ls-files -co --exclude-standard -z | tar …`) into a scratch dir and `git init` + commit there.
  2. Mount it read-only into `docker run --rm -e CI=true archlinux:latest`.
  3. Run the workflow's pacman line, then copy to a writable dir and run the steps.
- This catches dependencies only the dev machine has (e.g. `Qt5Compat.GraphicalEffects`).

### Feature testing sections
- Hyprland: [config-modes](hyprland/config-modes.md), [managed-takeover](hyprland/managed-takeover.md), [monitors](hyprland/monitors.md)
- Theming: [theme-integrations](theming/theme-integrations.md) (scratch `HOME`/`XDG_CONFIG_HOME` for hookups)
- Services: [self-update](features/self-update.md), [polkit](features/polkit.md), [calendar](features/calendar.md), [idle](features/idle.md)
- Surfaces: [launcher](features/launcher.md), [lockscreen](features/lockscreen.md), [greeter-install](features/greeter-install.md), [greeter-runtime](features/greeter-runtime.md), [onboarding](features/onboarding.md)
- Layout: [surface-context](popouts/surface-context.md), [writing-modules](overlay/writing-modules.md)
