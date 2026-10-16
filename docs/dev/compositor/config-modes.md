# Config modes (detached / included / managed)

> **Files:** `services/CompositorConfigManager.qml`, `services/ConfigTakeover.qml`, `services/UserBindMerge.qml`, `config/CompositorConfig.qml`, `components/methods/CompositorLayer.qml`, `components/views/settings/CompositorStatusCard.qml`, `services/IntegrationHookupManager.qml`, `services/HyprlandConfigWriter.qml`, `services/SwayConfigWriter.qml`, `config/WindowBehaviourConfig.qml`
> **Config:** `Compositor.mode`, `Compositor.requiredSettings`, `WindowBehaviour.*`, `Keybinds.binds`, `Monitors.profiles`, `WindowLook`, `Input`, `Session`, `Workspaces.strips`
> **Related:** [Contract](contract.md), [Window look](window-look.md), [Hyprland's writer](../hyprland/config-modes.md), [Managed takeover](../hyprland/managed-takeover.md), [Sway backend](sway-backend.md)

How axiom sets the compositor up, the same on every compositor with `supports.configModes`. `CompositorConfigManager` drives the three modes; the backend's config writer (`CompositorManager.backend.configWriter`; on Hyprland `HyprlandConfigWriter`, on sway `SwayConfigWriter`: [sway backend](sway-backend.md)) turns axiom's layer into the compositor's own text. Read this before touching anything axiom writes into a compositor's config.

### The layer
- One layer covers: the binds (`Keybinds.binds`), the required settings (`Compositor.requiredSettings`), the [window look](window-look.md), the input (`Input`), the blur behind axiom's surfaces, the monitor profiles (`Monitors.profiles`) and the strips. In managed mode the writer adds `Session`, the shared options (`WindowBehaviour`: focus and the cursor, each field by its `x-hypr`/`x-sway`) and the compositor's own (the `Hyprland` or `Sway` section).
- What the look and the input ask for is decided once, by `CompositorLayer.look` / `.input` (`spec(forFile)`: `{ look, input, surfacesBlur }`), and the writer turns that into text.
- `mode` picks how the layer gets to the compositor:
  - **detached**: evaluated at runtime (`writer.runtimeApply()`), again after every config reload, which drops it
  - **included**: written to a module (`writer.moduleText(spec)` → `includePath`) the user's config loads (`includeLines`)
  - **managed**: written as the compositor's config itself (`writer.managedText(spec)` → `managedPath`), after a takeover (`writer.claim()`), loading the user's own files (`userFiles`) after it.
- Whenever a file isn't loaded (included but the lines are missing, or a takeover refused), the runtime layer stands in and `problem` says why (`writer.notIncludedProblem` / `notManagedProblem` / `blockedProblem`). The writer's `checkLoaded(cb)` tells.

### Writing files
- Both file modes write only on change (`_writeIfChanged`), then reload the compositor (`writer.reload`), which doesn't watch files its config loads.
- `_writeFile` re-reads the file before each write (`blockLoading`). A FileView skips a `setText` of the text it last wrote, and the file may no longer hold that text after a release.
- `_reload()` reloads once more when asked while a reload runs, so a file written meanwhile isn't missed.

### Live parts: the look and the input
- They are evaluated at runtime as they change (`_liveInputs`, debounced), in every mode: a reload on every step of a setting stalls the desktop, and detached, re-applying the whole layer redoes every bind. The file holds them as of its last write.
- After every `configReloaded` in the file modes they are evaluated again (`_applyLive`), so they win over the user's own lines while they're on. Detached, the runtime layer evaluates them with the rest, through the writer's `liveLinesHook`.
- A runtime eval can't take a setting back: a part turned off since it was evaluated reloads the compositor's config (`_undoLive`, `_droppedParts`). What was evaluated is `_liveState.applied` (a `PersistentProperties`): the look's parts the compositor applies (`supports.window<Part>`) and `input:<part>` (with `inputConfig`), so a part it can't apply (blur on sway) never causes a reload.
- The cursor theme is set as it changes (`writer.setCursor`, `_liveState.cursor`); a reload keeps it, so turning the part off leaves it until the session ends.

### Include and autostart lines
- `includeLines` (included) and `autostartLines` (included and detached) are the writer's, as hookup targets `includeTarget` / `autostartTarget`. `IntegrationHookupManager` runs them under the keys `compositorInclude` (both lines) and `compositorAutostart`, so the onboarding offers Apply with a backup, as a theme integration does ([Theme integrations](../theming/theme-integrations.md)).

### Status card and saving
- The settings page's Compositor section starts with `CompositorStatusCard`, built from:
  - `status`: `runtime` | `loaded` | `fallback` | `pending`
  - `problem`
- A mode picked there waits for Save (`x-applyOnSave`). The card outlines what saving will do, including the leave steps below.
- It predicts a takeover with `checkManaged()` (the writer's dry run). `managedCheck` is `ours` | `adopt` | `stock` | `released` | `new` | `blocked` (`managedBlockedBy` `link` or `git`).

### Approving a takeover
- Managed mode takes over a config of the user's only once they've allowed it on that compositor. The approvals are state, not config (`$XDG_STATE_HOME/axiom/ui/takeover.json`, `{ approved: [kind] }`), so a config imported, or carried over from another compositor, with `mode: "managed"` never counts as one.
- Allowed by: picking managed on the Compositor card while axiom runs (a mode change after the first `apply()`), or `allowTakeover()` (the card's Allow takeover, the notification's button).
- Before claiming, `_claimIfApproved` runs the writer's dry run (`checkManaged(callback)`). With nothing of the user's to take over (`ours`, `new`, `stock`, `released`) it approves and claims; `blocked` claims, which reports it. `adopt` waits: `takeoverPending`, `problem` is `approvalProblem`, the runtime layer stands in, and a notification (once per session) offers Allow.
- Never press Allow for the user while testing (AGENTS.md › Never).

### Leaving a mode
- `_leave` gives back what a mode took, for a switch made while axiom runs.
  - `_appliedMode` is `""` until the first `apply()`, so a load never gives anything back.
  - Leaving managed runs the writer's `release()` (on Hyprland, [Managed takeover](../hyprland/managed-takeover.md#release)). Detached waits for it (`_releasing`) before applying its runtime layer.
- Leaving included, or leaving managed for detached, empties the module if it exists (`writer.emptyModuleText`).
  - Every part becomes a no-op, so a config still loading the module gets nothing.
  - Otherwise the old layer would stay in the compositor's config, and the runtime layer can't undo it because it only adds (a strip removed in detached mode stayed a strip).

### The writer (contract)
A backend with `configModes` gives `configWriter`, a singleton with:
- **Files and lines**: `configDir`, `includePath`, `managedPath`, `userDir`, `userFiles`, `includeLines`, `autostartLines`, `includeTarget`, `autostartTarget`, the three `*Problem` texts.
- **Text**: `moduleText(spec)`, `managedText(spec)`, `emptyModuleText`, `liveLines(spec)`, `inputsKey` (the rest of what its text depends on, so a change re-applies it), `isComplete(bind)`.
- **Runtime**: `runtimeApply()`, `runtimeClear()`, `noteReload()`, `skippedKeys`, `liveLinesHook` (set by the manager), `runLive(lines)`, `setCursor(theme, size)`, `checkLoaded(cb)`, `reload(cb)`.
- **Takeover**: `claim()`, `release()`, `checkManaged()`, `findMonitorConflicts()`, `clearConflicts()`, `managedCheck`, `managedBlockedBy`, `managedBlockedRepo`, `monitorConflicts`; signals `claimed(adopted)`, `blocked()`, `released(result)`. Each writer forwards these to a `ConfigTakeover` on its `scripts/claim_<compositor>.sh` (same verbs and results: `check`/`claim`/`release`), and the bind merge to a `UserBindMerge` on its `scripts/merge_<compositor>_binds.py` (same JSON): a new compositor writes the two scripts, not the QML.
- **Bind merge** (with `bindMerge`): `mergeUserBinds(only)`, `previewMerge()`, `merging`, `lastMerge`, `mergeable`, signal `bindsMerged(binds)`.

### Service creation
- `CompositorConfigManager` is created from `shell.qml`'s `_services` with `supports.configModes`. Elsewhere other services may still create it, and it stays inert (`live` is false without a writer).

### Testing
- Never switch the user's real config into or out of `managed` to test it. (Rule: AGENTS.md › Never, while testing.)
- The writer's text comes from pure helpers with tests (on Hyprland `HyprConfigLua`, `tests/tst_HyprConfigLua.qml`).
