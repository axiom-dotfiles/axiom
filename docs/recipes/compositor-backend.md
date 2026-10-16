# Recipe: a compositor backend

> **Use when:** axiom should run under another compositor (sway, niri, …).
> **Copy from:**
> - `services/HyprlandManager.qml`: the Hyprland backend; its members are the contract.
> - `components/methods/HyprState.qml` + `tests/tst_HyprState.qml`: the compositor's replies to neutral shapes, tested on fixtures.
> **Docs:** [The compositor](../dev/compositor/README.md), [contract](../dev/compositor/contract.md), [sway-backend](../dev/compositor/sway-backend.md)

## Files to touch
1. `services/<Name>Manager.qml`: a `pragma Singleton` (Quickshell's `Singleton`) with every member in [contract.md › Backend members](../dev/compositor/contract.md#backend-members) and its `supports`. Only this file talks to the compositor (its socket, its Quickshell module, its CLI).
2. `components/methods/<Name>State.qml` + `tests/tst_<Name>State.qml`: the compositor's replies as the [shapes](../dev/compositor/contract.md#shapes). The service holds no parsing.
3. With config modes: `services/<Name>ConfigWriter.qml` (copy `HyprlandConfigWriter.qml`; members in [config-modes.md › The writer](../dev/compositor/config-modes.md#the-writer-contract)) given as the backend's `configWriter`, and its pure text helper `components/methods/<Name>Conf.qml` + `tests/tst_<Name>Conf.qml`.
4. `services/CompositorManager.qml`: `kind` (its socket's env var, if not there yet) and `backend` (`kind === "<kind>" ? <Name>Manager : …`).
5. `scripts/check_structure.py`: nothing, unless the backend is the only file allowed to import the compositor's Quickshell module (then add a rule like the `Quickshell.Hyprland` one).
6. `docs/dev/compositor/`: a `<kind>-backend.md` with what it supports and how it maps, and a line in `docs/dev/README.md`.

## Gotchas
- **No compositor objects past the backend.** Hand out snapshots. A binding on a list of live objects re-evaluates on every event, and the next backend's objects won't have the same fields.
- **A capability not listed is false.** List only what the backend really does; the facade and the settings hide the rest. Don't gate anything on `kind` outside the backend.
- **The facade keeps the layout logic.** Workspace ids, blocks, steps, wrap and the remap plan are `CompositorManager`'s. A backend that wants to know "which workspace is next" is duplicating it.
- **Workspace ids** are axiom's numbers (`WorkspacesConfig`), not the compositor's internal ids.
- **Setting the compositor up** (binds, window look, input, monitors, the three modes) is a config writer: a `services/<Name>ConfigWriter.qml` singleton given as the backend's `configWriter`, with `configModes` in `supports`, its text from a pure `components/methods/<Name>Conf.qml` with a test ([config modes](../dev/compositor/config-modes.md) › The writer). `CompositorConfigManager` drives the modes; the writer only turns the layer into text and runs it.
- Don't start the backend's processes unless `CompositorManager.kind` picked it: it's created lazily, but anything that names it creates it.

## Verify
- `scripts/run_tests.sh <Name>State`, then `scripts/dev/verify.sh`.
- `scripts/dev/nested.sh <kind>`: the bar's workspaces follow switches, the overview shows windows, the dock lists running apps, the launcher finds windows, and the log is clean.
- Back on the live (Hyprland) shell, the log is still clean: `scripts/log.sh`.
