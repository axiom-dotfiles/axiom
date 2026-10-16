# Hyprland config writer

> **Files:** `services/HyprlandConfigWriter.qml`, `services/HyprlandRuntimeLayer.qml`, `config/HyprlandConfig.qml`, `components/methods/HyprConfigLua.qml`, `components/methods/HyprLua.qml`, `components/methods/BindKeys.qml`, `config/InputConfig.qml`, `config/SessionConfig.qml`, `scripts/claim_hyprland.sh`
> **Config:** `Compositor.mode`, `Compositor.requiredSettings`, `Input.*`, `Session.*`, `Keybinds.binds`, `Hyprland.managed`, `WindowLook`, `Monitors.profiles`, `Workspaces.strips`
> **Related:** [Config modes](../compositor/config-modes.md), [Managed takeover](managed-takeover.md), [Window look](../compositor/window-look.md), [Bind merge](bind-merge.md), [Keybinds](keybinds.md), [Monitors](monitors.md), [Workspace strips](workspace-strips.md)

Hyprland's config writer (`HyprlandConfigWriter`, `HyprlandManager.configWriter`, which owns `HyprlandRuntimeLayer`, and a `ConfigTakeover` and `UserBindMerge` on its scripts): what axiom's layer is in Hyprland's Lua, for each mode. The modes themselves, leaving one and the live parts are neutral: [Config modes](../compositor/config-modes.md). Read both before touching anything axiom writes into Hyprland.

### One Lua layer
- It needs Hyprland's Lua config (0.55+). Axiom's own evals and dispatches are all Lua (`hl.*`), sent as [IPC](ipc.md) describes. The stubs are in `/usr/share/hypr/stubs/hl.meta.lua`.
- One Lua layer covers:
  - binds (`binds[]`: an IPC `action` or `exec`, `description` "Axiom: …"; see [Keybinds](keybinds.md))
  - required settings: `allow_session_lock_restore`, a named rule suppressing `maximize` requests, and a `workspaces` animation
  - the [window look](../compositor/window-look.md) and blur
  - monitor profiles ([Monitors](monitors.md))
  - strips ([Workspace strips](workspace-strips.md))

### `detached`
- It is evaluated at startup and on every `configreloaded` (`HyprlandRuntimeLayer`).
- It skips keys Hyprland's binds show taken (`HyprlandManager.withBinds`, read after unbinding its own). `components/methods/BindKeys` provides `keyId`, `runtimeBinds`, and `userKeyCounts` for KeybindManager.
- The keys it bound live in Hyprland's Lua state (`AXIOM_RUNTIME_KEYS`):
  - a Hyprland reload resets them, along with the binds
  - they survive a qs reload
  - they are unbound before the binds are read.
- The runtime layer starts over when Hyprland reloads while it reads the binds (`noteReload()` counts them). A plan from another config would record that config's keys in `AXIOM_RUNTIME_KEYS`, and `clear()` would then unbind them.

### `included`
- `moduleText(spec)` (`HyprConfigLua.moduleLua`) goes to `$XDG_STATE_HOME/axiom/hyprland.lua`.
- The user loads that module with `includeLines`.

### `managed`
- `managedText(spec)` (`HyprConfigLua.managedLua`) becomes `~/.config/hypr/hyprland.lua` itself, plus the `managed` options.
- Taking the user's existing config over (`claim_hyprland.sh`) is described in [Managed takeover](managed-takeover.md).

### Include and autostart lines
- `includeLines` (included) and `autostartLines` (included and detached) are hookup targets:
  - `autostartLines` is one line marked `-- axiom`, like install.sh's.
  - Managed mode starts axiom itself.
  - Both start it with `startCommand`, which is `qs -p … -n`. Its `--no-duplicate` exits at once if axiom already runs, as install.sh's `qs -n -c axiom` does.
- The targets are `includeTarget` (at the top of hyprland.lua) and `autostartTarget` (at the end). Any `qs -c axiom` / `qs -p …axiom` line counts as done.
- `IntegrationHookupManager` runs them under the keys `compositorInclude` (both lines) and `compositorAutostart` ([Config modes](../compositor/config-modes.md)).

### Is the file loaded?
- An `AXIOM_INCLUDED` global tells axiom the file is loaded.
- `checkLoaded` evals a check of it; when it isn't set, the runtime layer stands in and `problem` says why.

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
  - `Session.env`: written after `HyprLua.recommendedEnv` while `Session.recommendedEnv` is on, so the user's values win
  - `Session.autostart`: written after axiom's in the start hook
  - the cursor (`Input.cursor`): `XCURSOR_*` and `hyprctl setcursor` at start.

### Input
- `Input` (reader `InputConfig`) is in the layer in every mode, as `M.input()` after `M.look()`: one `hl.config` of the parts that are on (`CompositorLayer.input`, `HyprLua.inputLua`). Its fields carry `x-hypr` paths gated by `x-hyprIf` on their part, so a part on writes all its fields, defaults too.
- Like the look, it is evaluated at runtime as it changes and after every reload, and a part turned off reloads Hyprland's config ([Config modes](../compositor/config-modes.md) › Live parts).
- The cursor theme is set with `setcursor` (`HyprlandManager.setCursor`).
- Before config version 59 these were `managed` options (the part switches were turned on there).

### Service creation
- `HyprlandConfigWriter` is created with `HyprlandManager` (its `configWriter`), so only under Hyprland.

### Testing
- Never switch the user's real config to `managed` to test it. (Rule: AGENTS.md › Never, while testing.)
- Test `claim_hyprland.sh` on scratch dirs, as `tests/scripts/test_scripts.py` does.
- The Lua comes from `HyprConfigLua` (pure): `tests/tst_HyprConfigLua.qml` renders the included, managed and given-back files to `tests/.out/`, where `scripts/run_tests.sh` checks them with `luac -p`. Add a case there when changing what a file holds.
