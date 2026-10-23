# The axiom binary

> **Files:** `backend/`, `config/json/backend.json`, `scripts/check_go.sh`, `scripts/generate.sh`, `scripts/dev/fixtures.py`
> **Related:** [Config manager](../core/config-manager.md), [Packaging](../packaging.md), [Testing](../testing.md)

`axiom` is one Go binary (source in `backend/`, rules in `backend/AGENTS.md`). It is being brought in in stages; this page says what exists now and grows with it.

### What it is for
- The **parent process** of the shell (`axiom run`) and the greeter (`axiom greeter`): it starts quickshell, restarts it when it crashes, and keeps one instance per display.
- The **owner of config.json**: loading, migrating, validating and writing, with the shell as a client over a unix socket (NDJSON JSON-RPC 2.0).
- The **command line**: `axiom config …`, named commands and `axiom ipc <target> <fn>` passthrough to the shell.
- Later, the side effects that need a Wayland connection (idle, gamma, clipboard).

### What exists now
- **`axiom run [--dev] [--tree DIR]`**: the daemon for `$WAYLAND_DISPLAY`.
  - It takes the display's instance lock and builds the schema from the tree (`config/schema/`).
  - It opens the config, writes both for the shell into `$XDG_RUNTIME_DIR/axiom/<display>/`, serves the socket there, and supervises `qs -p <tree>`.
  - Supervision: restart with a growing delay after a crash, give up after 5 crashes in a minute, stop an orphan an earlier daemon left.
  - It holds an idle connection to its compositor (`wire.Watch`) and stops when the compositor closes it: a daemon outliving its session would hold the display's lock, and the next session's `axiom run` would find it taken.
  - The shell gets `AXIOM_SOCKET`, `AXIOM_SCHEMA`, `AXIOM_CONFIG`, `AXIOM_TREE` (and `AXIOM_INCOMPATIBLE` when the tree's schema isn't the binary's).
  - `--dev`: logs to the terminal, rebuilds the schema within 100 ms of a YAML edit (pushing `schema.changed`), and re-execs when the binary is rebuilt. Without it the schema is read once, at the start: a YAML change reaches a running shell only through a restart, and a tree whose schema isn't the binary's runs read-only (`AXIOM_INCOMPATIBLE`).
- **`axiom greeter [--tree DIR] [--dir DIR] [--safe]`**: the login screen's parent (`greeter-session.sh` runs it as greetd's user). It loads the exported bundle, else the install's snapshot, else the defaults, through the same pipeline (`backend/internal/greeter`), writes it to `$XDG_RUNTIME_DIR/axiom/greeter-<display>/` and execs `qs -p <tree>/greeter.qml` on it: no daemon, no socket ([Greeter runtime](../features/greeter-runtime.md)).
- **The config store** (`backend/internal/store`):
  - The one writer of config.json, holding `config.json.lock`.
  - Loading: format 1 through the frozen migrations and the conversion to format 2 (the file kept as `config.format1.json`), then the format-2 steps (`migrate/steps`), with defaults written on a first run. A file that doesn't load blocks saves until fixed. Edits made outside are watched; the store's own writes are recognised.
  - Writing: path ops (keys and `{id}` selectors, never positions), validation, and takeover settings refused without `takeover`.
  - Writes are atomic and keep a symlinked config a symlink.
- **The shell's side:**
  - `BackendManager` (the connection, hello, reconnect).
  - `ConfigManager`: the config read from the snapshot and pushes. Writes are checked against the schema in JS, applied at once and sent to the daemon, whose answer stands.
  - `IpcTarget` (every IPC target, registered with the daemon).
  - `LockManager` reporting the lock.
  - A shell started by hand, without `AXIOM_SOCKET`, shows only a notice with the line that starts it (`NoParentNotice`).
- **IPC through the daemon:**
  - `axiom ipc <target> <fn> [args]`, `axiom ipc list`, and named commands (`axiom launcher toggle`, `axiom volume up`, …, checked against `docs/dev/generated/ipc.md`).
  - The shell's registered targets are called over its connection; their signatures come from `qs ipc show`. Others go through `qs ipc --pid <shell> call`.
- **`axiom lock`:** exits 0 only once the compositor has acknowledged the session lock (`WlSessionLock.secure`). Otherwise it starts the shell locked, then fails. A shell that dies while locked is restarted at once, locking first. Nothing unlocks but PAM; `lockscreen` takes only `lock`. With `Lockscreen.mode` `none` it runs `Lockscreen.lockCommand`, never `loginctl lock-session` (which loops back to axiom).
- **The rest of the CLI:**
  - `axiom ping|restart|quit`, `axiom daemon status|reexec|logs`
  - `axiom config path|get|set|reset|validate|status`: online, or `--offline` against the file under the writer lock
  - `axiom schema build|check|hash`, `axiom debug wayland-globals`, `axiom version`
- **Re-exec** (`axiom daemon reexec`, or `--dev` on a rebuild): the new image takes over the instance lock, the writer lock, the socket and the shell (still its child). It trusts the handoff only when the inherited lock really is this display's held lock.

### Wayland
The daemon will talk Wayland itself for idle, gamma, clipboard and typing (branch 2). For now `backend/internal/wayland/wire` speaks the wire protocol far enough to list a compositor's globals: [what each compositor offers](wayland.md).

### Building and checking
- `cd backend && go build ./cmd/axiom` builds it (pure Go, `CGO_ENABLED=0` works).
- `scripts/check_go.sh` runs what CI's go job runs; `--fix` regenerates and formats. `scripts/dev/verify.sh` runs it when `backend/` or an embedded file changed.
- The embedded copies under `backend/internal/assets/data/` are generated and gitignored, the schema among them (built from `config/schema/` by `go generate`, since the binary can't build what it embeds before it compiles): edit `config/json/…` and the YAML. A fresh clone runs `scripts/generate.sh` once before `go build`.

### Security
Code handling sockets, locks, runtime directories, atomic writes, the child's environment or the lock screen is security-relevant: every rule it enforces has a test, and a change to it is reviewed against this list.
- The runtime directory must be a real directory owned by the user with mode 0700; `$XDG_RUNTIME_DIR` is required, never replaced by `/tmp`.
- A lock is taken before anything it guards is touched (a stale socket is removed only while holding the instance lock).
- Every socket connection's peer must be the same user (`SO_PEERCRED`).
- Writes are atomic (temp file, fsync, rename, fsync the directory) and never follow a planted symlink.
- Nothing unlocks the lock screen but PAM: no RPC, CLI or IPC path exists for it.

### Shared fixtures
Behaviour implemented on both sides (the JS helpers and Go) is tested from one set of cases under `tests/fixtures/shared/`, read by both `go test` and qmltestrunner (`tests/tst_Shared.qml`), with expected output stored as exact bytes. The directory is generated and gitignored: `scripts/generate.sh --fixtures` records it when what it's made from changed (`fixtures.py ensure`, a stamp of the inputs), and CI records it before the tests.
- **A case** is `<suite>/<test>/<name>.json` (`{op, args}`) plus `<name>.expected.json`: the output as 2-space JSON in JS key order with a trailing newline (`Shared.canonical`). `index.json` lists every case (qmltestrunner can't list folders).
- **Arguments** larger than 2 KB are stored once in `blobs/<hash>.json` and referenced as `{"$blob": hash}`; a schema argument is `{"$fixtureSchema": "legacy-v75", "pointer": "/definitions/…"}`, naming a frozen copy in `schemas/` (the binary's frozen copy, `backend/internal/migrate/legacy/schema-v75.json`).
- **Ops** are named by family: `legacy.*` (ConfigMigration and the whole load), `schema.*` (SchemaValidation), `share.*` (ConfigExamples). `tests/Shared.qml` maps each op onto its JS helper; the Go side maps the same names onto its packages.
- **Recording:** `scripts/dev/fixtures.py record` runs tst_Config, tst_ConfigExamples, tst_SchemaValidation and tst_Shared with recording on. The tests call the helpers through `Shared`, which logs every call (arguments and output bytes), so the tests' inline cases become fixtures without being copied by hand. tst_Shared adds the **corpus**: the defaults of every past schema version (from HEAD's history, so every clone records the same) and the old config fixtures and examples, loaded as ConfigManager loads them.
- **Owners:** the `legacy`, `schema`, `share` and `corpus` suites come from the JS helpers. The `legacy` ones are made from frozen code and the frozen schema, so recording again gives the same bytes. Suites only Go implements are written by Go's tests. `fixtures.py check` (CI) checks the index and the blobs.
- **One known difference:** V4's `JSON.stringify` writes a lone surrogate unescaped (it predates ES2019); Go escapes it (`\udXXX`). No JS-owned case holds one (recording refuses it).
