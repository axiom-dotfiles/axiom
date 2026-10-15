# Hyprland window look

> **Files:** `services/HyprlandConfigManager.qml`, `components/methods/HyprLua.qml`, `services/HyprlandManager.qml`, `components/views/settings/TranslucencyStatus.qml`
> **Config:** `Hyprland.look.*` (borders, `shape`, gaps, `blur`, `opacity`, `windowBlur`)
> **Related:** [Config modes](config-modes.md), [Translucency and blur](../theming/translucency-blur.md), [Lockscreen](../features/lockscreen.md)

The themed window look axiom gives Hyprland: borders, shape, gaps, blur and window opacity. It is written as one `hl.config` in every mode.

### What it covers
- The section is `Hyprland.look`. It is `x-scope: look` inside a machine-scoped section, so exports, examples and imports carry it. It isn't `x-takeover`.
- It holds:
  - themed borders
  - axiom's shape: `decoration.rounding`/`general.border_size` from `Appearance`
  - `gaps_in`/`gaps_out`
  - Hyprland's blur (`blur`: `decoration.blur.*`). Its size and passes are the one strength that windows and axiom's surfaces share.
  - window opacity (`opacity`).
- All of it becomes one `hl.config` (`HyprLua.lookLua`).
  - The blur and opacity fields are `x-hypr` fields, each gated by `x-hyprIf` on its part, so `configTable` writes them.

### Blur and windows
- With the blur part on, Hyprland's blur stays enabled while axiom's surfaces blur, even if `windowBlur` is off.
- The `axiom-no-window-blur` rule (redefined on or off) then keeps windows and their popups unblurred.
- `HyprlandManager.blur` reads the blur in effect (`refreshOptions`). It is used by:
  - the Translucency card's status (`views/settings/TranslucencyStatus`, that card's `x-intro`)
  - the lock screen's frost.

### Where it's applied
- Every part shows in every mode. A managed config writes them through `M.look()`, like the rest of the layer.
- In the file modes it is also evaluated after every `configreloaded` (`_applyLook`), so it wins over the user's own lines while it's on. Detached, the runtime layer evaluates it with the rest. Both take its lines from `_runtimeLookLua`, which records what it applied.
- A runtime eval can't take a setting back.
  - `_undoLook` reloads Hyprland's config when a part was turned off since it was evaluated (`_droppedLookParts`).
  - What was evaluated is recorded in `_lookState.applied`, a `PersistentProperties`.
  - The file modes reload anyway, by rewriting their file.
- `HyprlandManager.refreshOptions()` waits for queued Lua, so `gapsOut` reads what the look set, and Automatic bars follow it.
- In managed mode, the `managed` options' `rounding`/`borderSize` are written only while `shape` is off.
