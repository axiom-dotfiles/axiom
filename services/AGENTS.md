# Services (`services/`)

One `pragma Singleton QtObject` per domain, named `*Manager`: state and every side effect (processes, dispatches, file writes, polling). Docs: `docs/dev/core/services-pattern.md`, plus the feature's doc in `docs/dev/features/`. Each service's public API: `docs/dev/generated/api/<Name>.md` (generated; rerun `scripts/gen_docs.py` after changing public members or an `IpcHandler`).

**Recipe:** `docs/recipes/service.md` / `docs/recipes/launcher-command.md`; verify with `scripts/dev/verify.sh`.

- Expose readonly properties, signals and functions; private members start with `_`. Don't shadow Quickshell singletons (`NetworkingManager`, not `Networking`). `check_structure.py` errors on a `FooManager.` reference with no file.
- **Polled data**: `acquire(owner, request)` / `release(owner)` wrapping a private `ConsumerRegistry`; the interval is the shortest asked (with a floor), the Timer runs only while `_registry.active`. Copy `TailscaleManager.qml`. Requests come from config only.
- **IPC**: `property IpcHandler _ipc: IpcHandler { target: "…"; function x(): void { … } }` with typed returns (copy `IdleInhibitManager.qml`); add the target to the `docs/usage.md` IPC table. A service reached only by IPC is created from `shell.qml`'s `_services`.
- Config writes only through `ConfigManager` / `SettingsManager` (root `AGENTS.md` › Services). Editors own a `ConfigDraft` and their selection (`select*()`).
- Side effects reachable from the greeter check `Paths.greeter` first (greeter mode writes nothing and runs no integrations).
- State that must survive a QML reload: `PersistentProperties`; small persisted state: `config/state/*.json` or `$XDG_STATE_HOME/axiom/`, written atomically.
- Secrets only through `SecretsManager` (stdin, never argv or config.json).
- Hyprland calls are Lua (`hl.*`); workspace and window focus only through `HyprlandManager`.
- Launcher commands: `LauncherCommands.qml` entries (`name`, `aliases`, `glyph`, `usage`, `description: () => I18n.tr(…)`, `available`, `status`, `options`, `run(arg, value)`); copy the `nightlight` entry. See `docs/dev/features/launcher.md`.
