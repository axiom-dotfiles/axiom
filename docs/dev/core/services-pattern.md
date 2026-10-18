# Services pattern

> **Files:** `services/*.qml`, `services/ConsumerRegistry.qml`, `services/CommandManager.qml`, `services/SystemManager.qml`, `services/UpdatesManager.qml`, `services/InstanceManager.qml`, `components/methods/ShellInstances.qml`, `scripts/restart.sh`, `shell.qml`
> **Config:** none of its own
> **Related:** [Config manager](config-manager.md), [Config readers](config-readers.md), [Editors pattern](editors-pattern.md), [Shell manager and screen targeting](shell-manager-targeting.md)

How `services/` is built: one singleton per domain, owning state and side effects, and the shared acquire/release pattern for anything polled. Read this before adding or changing a service.

### Shape
- Every file is `pragma Singleton QtObject`: one global instance per name, imported as `qs.services`.
- (Rule: AGENTS.md › Services, for naming, `_services` and singleton shadowing.)
- A service with an IPC target that nothing else references is created from `shell.qml`'s `_services` (e.g. BatteryManager, CompositorConfigManager).

### Polled data: acquire / release
(Rule: AGENTS.md › Services, "Anything polled".)
- **SystemManager**: CPU/memory/temp/GPU/disk stats.
  - Reference-counted through a `ConsumerRegistry` (shared with UpdatesManager; identical re-registrations are no-ops).
  - Consumers call `acquire(owner, {interval, metrics, diskPaths})` / `release(owner)`.
  - Polls only the union of requested metrics: sysfs/procfs `FileView` reads, no processes on the hot path.
  - Stops entirely with no consumers.
  - With `history: true` it keeps 60-sample ring buffers (see [Writing modules](../overlay/writing-modules.md)).
- **UpdatesManager**: pending package (and, on Arch, AUR) updates shared by every Updates widget (same acquire/release pattern).
  - How it checks is the distribution's `Packages.updates` entry (`checkupdates` on Arch, `dnf check-update` on Fedora); on one with none, `supported` is false and nothing runs (the widget hides, the card says so).
  - Only one check may run at a time: concurrent `checkupdates` runs share its temp db and fail.
  - `upgrade(command, terminal)` runs the upgrade in a terminal (one at a time, `upgrading`) and checks again when it closes.
- **Other polled services:**
  - `CalendarManager`: `acquire(owner)` with no request; its interval is the Calendar section's. See [Calendar](../features/calendar.md).
  - `WeatherManager`: takes no request (its settings are global).
  - `TailscaleManager`: `available`, `backendState`/`connected`, `tailnetName`, `ip`.
  - `CommandManager`: `outputs[command]`, shared by identical commands (e.g. a Button's label).
- **Widget side:** hold the request in a `readonly property var …Request` built from `properties`; acquire it in `Component.onCompleted` and in `on…RequestChanged`; release in `onDestruction`.

### CommandManager: services keep no Process
- `CommandManager.runDetached(command)` runs a widget's click commands.
- `run(command, callback, input)` runs a service's one-off command.
  - callback is `(exitCode, stdout, stderr)`
  - `input` goes to stdin.
- So services keep no `Process` of their own for one-off commands.

### Other domain services
They follow the same pattern:
- **AudioManager**: also every write to a Pipewire node (`setNodesVolume` / `setNodesMuted`).
  - `matchStreams(apps, other, excluded)` is the OSD app bars' playback stream matching.
  - Recording streams are left out: an app's mic capture shares its name.
- **BatteryManager**: also the power profile, and `level` against the `Battery` section's thresholds (`BatteryConfig`; the Battery widget and module colour from it).
  - Sends the low battery notifications, once per drop into low and then critical, whatever bars exist.
  - Created from `shell.qml`'s `_services` so it runs without a widget.
- **KeyboardLayoutManager**, **MediaManager** (MPRIS), **CompositorManager** (the compositor, through its backend `HyprlandManager`: [compositor/](../compositor/README.md)), **StateManager**, **BarManager**, **LauncherManager**, **SettingsManager**, **SavedConfigsManager**, **AuthManager**, **LockManager**.

### One axiom per display
- **Restarting** is `scripts/restart.sh` (`Paths.restartCommand`), what every compositor's `restartShell` bind runs (SwayConf, NiriConf, HyprConfigLua; `bind_merge_common.py` reads it, and the old `qs kill …; qs … -d`, back as `restartShell`). It ends every axiom of the install on the display (SIGTERM, SIGKILL after 3 s) and starts one with `-n`. A lock per display drops a restart fired while one runs, and is held until the new one shows in `qs list`. Plain `qs kill` ends only one instance (the oldest, maybe already quitting) and returns before it has quit, so a bind fired twice left two, and every restart after kept two.
- **InstanceManager** (from `_services`, not in the greeter) lists the install's instances on its display (`qs list -j`) at start and 5 s later. `ShellInstances.decide` keeps the newest (launch time, then pid, so every instance decides alike): it ends the others, an older one quits. A `console.warn` names what it ended.
- `qs list` / `qs kill` match the display (`WAYLAND_DISPLAY`), so a nested axiom (`scripts/dev/nested.sh`) and the live one never end each other.

Feature services each have their own doc under `docs/dev/features/`, `docs/dev/hyprland/` and `docs/dev/theming/` (see the index).
