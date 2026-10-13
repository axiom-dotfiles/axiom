# Recipe: a new service (`*Manager`)

> **Use when:** a feature needs state, a process, polling, file writes or Hyprland dispatches. UI never does those itself.
> **Copy from:**
> - `services/TailscaleManager.qml`: polled state through a `ConsumerRegistry`; its consumer is `components/bar/widgets/Tailscale.qml`.
> - `services/IdleInhibitManager.qml`: an IPC handler, and state kept across reloads in `PersistentProperties`.
> **Docs:** [services-pattern](../dev/core/services-pattern.md), `services/AGENTS.md`, generated API `docs/dev/generated/api/<Name>.md`

## Files to touch
1. `services/<Name>Manager.qml`: a `pragma Singleton` (`QtObject`, or Quickshell's `Singleton` when it holds child objects like `PersistentProperties`).
2. Its consumers: widgets, modules, other services.
3. `shell.qml` → `_services`: only if nothing else references it (e.g. it exists only for IPC or a background job).
4. `docs/usage.md` → the IPC targets table, if it has an `IpcHandler`.

## Skeleton
```qml
pragma Singleton
import QtQuick
import Quickshell.Io

// One or two sentences: what this owns and who uses it.
QtObject {
  id: root

  // Public state: readonly where consumers must not write it
  property bool available: false
  property string state: ""

  // request: { interval } (ms)
  function acquire(owner, request) {
    _registry.acquire(owner, {
      "interval": request?.interval ?? 10000
    });
  }

  function release(owner) {
    _registry.release(owner);
  }

  function refresh() {
    if (!_check.running)
      _check.running = true;
  }

  // -- Private --
  property ConsumerRegistry _registry: ConsumerRegistry {}
  readonly property int _interval: _registry.active ? Math.max(5000, Math.min(..._registry.requests.map(r => r.interval))) : 10000

  property Timer _timer: Timer {
    interval: root._interval
    running: root._registry.active
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  property Process _check: Process {
    command: ["sh", "-c", "command -v foo >/dev/null || exit 127; foo status --json"]
    stdout: StdioCollector {
      onStreamFinished: {
        let status = null;
        try {
          status = JSON.parse(text);
        } catch (e) {}
        root.state = status?.State ?? "";
      }
    }
    onExited: exitCode => root.available = exitCode !== 127
  }

  property IpcHandler _ipc: IpcHandler {
    target: "foo"

    function refresh(): void {
      root.refresh();
    }

    function status(): string {
      return root.state;
    }
  }
}
```
Consumer (the request comes from config only, never from live values):
```qml
  readonly property var fooRequest: ({
      "interval": root.properties.interval
    })
  onFooRequestChanged: FooManager.acquire(root, fooRequest)
  Component.onCompleted: FooManager.acquire(root, fooRequest)
  Component.onDestruction: FooManager.release(root)
```

## Steps
1. Name it `<Domain>Manager`. Never shadow a Quickshell singleton (`NetworkingManager`, not `Networking`).
2. Put the public API first (state, functions, signals) and the private parts after `// -- Private --`, prefixed `_`.
3. **Polled data:** use a private `ConsumerRegistry`.
   - The interval is the shortest one asked for, with a floor.
   - The timer runs only while `_registry.active`, so nothing is fetched with no consumers.
4. **IPC:** a `property IpcHandler _ipc` with typed functions (`(): void`, `(): string`, `(text: string): void`). Per-screen handlers live on the surface instead, `enabled: ShellManager.isTarget(…)`.
5. **Persistence:**
   - State that must survive a QML reload goes in `PersistentProperties` (needs a `Singleton` root, see `IdleInhibitManager`).
   - Small state that must survive a restart goes in `config/state/*.json` or `$XDG_STATE_HOME/axiom/`, written atomically (temp file + rename).
6. **Config:** read it through readers. Write it only through `ConfigManager` / `SettingsManager`.
7. Add it to `shell.qml`'s `_services` if nothing else references it, or it never gets created.

## Gotchas
- **Greeter:** a side effect reachable from the greeter (writes, integrations, network) checks `Paths.greeter` first, as `CalendarManager` does.
- **Secrets** go through `SecretsManager` (stdin), never argv or config.json.
- **Hyprland:** calls are Lua (`hl.*` via `hyprctl eval`). Workspace and window focus go only through `HyprlandManager`'s functions.
- **Requests:**
  - An identical re-`acquire` is a no-op, but a new object every sample churns every binding on `requests`.
  - Build requests from config only. Never key a Repeater model on live values (the 25 GB lesson).
- **`check_structure.py`** errors on a `<Name>Manager.` reference with no `services/<Name>Manager.qml`, and on near-miss names.
- **Hot reload:** a new singleton is picked up on reload. A service that holds a `Process` restarts it on every reload, so make `refresh()` idempotent.
- **Showing `show`:** `show` is a qs IPC keyword (`ipc call foo show` lists functions), so don't name a function `show`.

## Verify
- `scripts/dev/verify.sh`: structure, formatting, generated API and IPC docs, and the log since the reload.
- `qs -c axiom ipc call <target> <function>` for each IPC function. `docs/dev/generated/ipc.md` lists it after `scripts/gen_docs.py`.
- `scripts/log.sh --debug` while a consumer is shown: the process runs at the expected interval and stops when the consumer goes.

## Docs to update
- `docs/dev/features/<feature>.md` (new or existing) and its line in `docs/dev/README.md`. If it's polled, add it to the polled list in `docs/dev/core/services-pattern.md`.
- `docs/usage.md` → IPC targets table, for a new IPC target.
