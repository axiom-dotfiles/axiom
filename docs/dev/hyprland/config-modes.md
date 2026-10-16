# Hyprland config modes

> **Files:** `services/HyprlandConfigManager.qml`, `services/HyprlandRuntimeLayer.qml`, `config/HyprlandConfig.qml`, `components/methods/HyprConfigLua.qml`, `components/methods/HyprLua.qml`, `components/methods/HyprBinds.qml`, `config/CompositorConfig.qml`, `components/views/settings/CompositorStatusCard.qml`, `scripts/claim_hyprland.sh`
> **Config:** `Compositor.mode`, `Compositor.requiredSettings`, `Hyprland.binds`, `Hyprland.managed`, `WindowLook`, `Hyprland.monitors`, `Workspaces.strips`
> **Related:** [Managed takeover](managed-takeover.md), [Window look](window-look.md), [Bind merge](bind-merge.md), [Keybinds](keybinds.md), [Monitors](monitors.md), [Workspace strips](workspace-strips.md)

How axiom sets up Hyprland (`HyprlandConfigManager`, which owns `HyprlandRuntimeLayer`, `HyprlandTakeover` and `HyprlandBindMerge`), and the three `mode`s it can do it in: `detached`, `included` and `managed`. Read this before touching anything axiom writes into Hyprland.

### One Lua layer
- It needs Hyprland's Lua config (0.55+). Axiom's own evals and dispatches are all Lua (`hl.*`), sent as [IPC](ipc.md) describes. The stubs are in `/usr/share/hypr/stubs/hl.meta.lua`.
- One Lua layer covers:
  - binds (`binds[]`: an IPC `action` or `exec`, `description` "Axiom: …"; see [Keybinds](keybinds.md))
  - required settings: `allow_session_lock_restore`, a named rule suppressing `maximize` requests, and a `workspaces` animation
  - the [window look](window-look.md) and blur
  - monitor profiles ([Monitors](monitors.md))
  - strips ([Workspace strips](workspace-strips.md))
- `mode` picks how that layer gets to Hyprland.

### `detached`
- It is evaluated at startup and on every `configreloaded` (`HyprlandRuntimeLayer`).
- It skips keys Hyprland's binds show taken (`HyprlandManager.withBinds`, read after unbinding its own). `components/methods/HyprBinds` provides `keyId`, `runtimeBinds`, and `userKeyCounts` for KeybindManager.
- The keys it bound live in Hyprland's Lua state (`AXIOM_RUNTIME_KEYS`):
  - a Hyprland reload resets them, along with the binds
  - they survive a qs reload
  - they are unbound before the binds are read.

### `included`
- `moduleLua()` goes to `$XDG_STATE_HOME/axiom/hyprland.lua`.
- The user loads that module with `includeLines`.

### `managed`
- `managedLua()` becomes `~/.config/hypr/hyprland.lua` itself, plus the `managed` options.
- Taking the user's existing config over (`claim_hyprland.sh`) is described in [Managed takeover](managed-takeover.md).

### Writing files
- Both file modes write only on change, then reload Hyprland (Hyprland doesn't watch `dofile`d files).
- `_writeFile` re-reads the file before each write (`blockLoading`). A FileView skips a `setText` of the text it last wrote, and the file may no longer hold that text after a release.

### Include and autostart lines
- `includeLines` (included) and `autostartLines` (included and detached) are hookup targets:
  - `autostartLines` is one line marked `-- axiom`, like install.sh's.
  - Managed mode starts axiom itself.
  - Both start it with `startCommand`, which is `qs -p … -n`. Its `--no-duplicate` exits at once if axiom already runs, as install.sh's `qs -n -c axiom` does.
- The targets are `includeTarget` (at the top of hyprland.lua) and `autostartTarget` (at the end). Any `qs -c axiom` / `qs -p …axiom` line counts as done.
- `IntegrationHookupManager` runs them under the keys `hyprlandInclude` (both lines) and `hyprlandAutostart`. The onboarder's Hyprland page therefore offers Apply with a backup, as a theme integration does ([Theme integrations](../theming/theme-integrations.md)).

### Is the file loaded?
- An `AXIOM_INCLUDED` global tells axiom the file is loaded.
- When it isn't, the runtime layer stands in and `problem` says why.

### Status card and saving
- The settings page's Compositor section starts with `CompositorStatusCard`, built from:
  - `status`: `runtime` | `loaded` | `fallback` | `pending`
  - `problem`
- A mode picked there waits for Save (`x-applyOnSave`). The card outlines what saving will do, including the leave steps below.
- It predicts a managed takeover with `checkManaged()`, a dry run of the takeover (`HyprlandTakeover.claim`). `managedCheck` is `ours` | `adopt` | `stock` | `released` | `new` | `blocked` (`managedBlockedBy` `link` or `git`).

### Leaving a mode
- `_leave` gives back what a mode took, for a switch made while axiom runs.
  - `_appliedMode` is `""` until the first `apply()`, so a load never gives anything back.
  - Leaving managed runs `claim_hyprland.sh release` ([Managed takeover](managed-takeover.md#release)).
- Leaving included, or leaving managed for detached, empties the module if it exists (`HyprConfigLua.emptyModuleLua`).
  - Every part becomes a no-op, so a hyprland.lua still loading the module gets nothing.
  - Otherwise the old layer would stay in Hyprland's config, and the runtime layer can't undo it because it only adds (a strip removed in detached mode stayed a strip).
- `_reload()` reloads once more when asked while a reload runs, so a file written meanwhile isn't missed.
- Detached waits for a release (`_releasing`) before applying its runtime layer.
- The runtime layer (`HyprlandRuntimeLayer`) starts over when Hyprland reloads while it reads the binds (`noteReload()` counts them). A plan from another config would record that config's keys in `AXIOM_RUNTIME_KEYS`, and `clear()` would then unbind them.

### Managed options (`HyprLua`)
- The `managed` options become one `hl.config({...})` through `components/methods/HyprLua` (pure), driven by schema annotations:
  - `x-hypr`: the option's dotted path, or a list of paths
  - `x-hyprScale`: integers shown scaled (0.01 for a percent)
  - `x-hyprValue`: `int`, `number` (numeric enums), `emptyIsDefault`, or `color` (a theme color name, with `x-hyprAlpha`)
  - `x-hyprIf`: a boolean sibling gates it
  - `x-hyprAlways`
- A field is written only when it differs from its default (Hyprland's own), so a new option is just a schema entry.
- `managed` stays flat (the settings page nests one level); its cards come from `x-group`/`x-order`.
- Not mapped through annotations:
  - `animationPreset`, written after `axiom.setup()`:
    - `hyprland` writes nothing
    - `axiom` follows `Appearance.animFast/Normal/Slow` and turns animations off with motion
    - `snappy` / `bouncy` / `lightning`
    - `custom` comes from `curves`/`customAnimations`
  - `env`: written after `HyprLua.recommendedEnv` while `recommendedEnv` is on, so the user's values win
  - `autostart`: written after axiom's in the start hook
  - the cursor.

### Service creation
- `HyprlandConfigManager` is created from `shell.qml`'s `_services`, since no other service references it.

### Testing
- Never switch the user's real config to `managed` to test it. (Rule: AGENTS.md › Never, while testing.)
- Test `claim_hyprland.sh` on scratch dirs, as `tests/scripts/test_scripts.py` does.
- The Lua comes from `HyprConfigLua` (pure): `tests/tst_HyprConfigLua.qml` renders the included, managed and given-back files to `tests/.out/`, where `scripts/run_tests.sh` checks them with `luac -p`. Add a case there when changing what a file holds.
