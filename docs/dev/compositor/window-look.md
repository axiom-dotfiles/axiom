# Window look

> **Files:** `config/WindowLookConfig.qml`, `services/CompositorConfigManager.qml`, `services/HyprlandConfigWriter.qml`, `components/methods/CompositorLayer.qml`, `components/methods/HyprLua.qml`, `services/HyprlandManager.qml`, `components/views/settings/TranslucencyStatus.qml`
> **Config:** `WindowLook.*` (borders and their colors, `shape`, `matchShell`, `borderSize`, `rounding`, gaps, `blur`, `opacity`, `windowBlur`)
> **Related:** [The compositor](README.md), [Contract](contract.md), [Config modes](config-modes.md), [Translucency and blur](../theming/translucency-blur.md), [Lockscreen](../features/lockscreen.md)

The themed window look axiom gives the compositor: borders, shape, gaps, blur and window opacity. The settings are compositor-neutral (`WindowLook`, Settings › Compositor). `CompositorLayer.look()` decides the parts once; each backend's config writer turns it into its own text, in every mode ([config modes](config-modes.md)); on Hyprland that is one `hl.config`.

### What it covers
- The section is `WindowLook` (`WindowLookConfig.look`; `Hyprland.look` before config version 56). It is `x-scope: look`, so exports, examples and imports carry it. It isn't `x-takeover`.
- Each part's fields carry `x-showIf: { "/$supports.window<Part>": true }`, so a compositor without that part hides them.
- It holds:
  - themed borders: `activeColor`/`inactiveColor` (theme color names; empty follows the theme's `borderFocus`/`border`)
  - the shape: border width and corner rounding, axiom's (`Appearance.borderWidth`/`borderRadius`) while `matchShell`, else `borderSize`/`rounding`. Hyprland's managed options held these before config version 58.
  - `WindowLookConfig` resolves both (`activeBorder`, `inactiveBorder`, `borderWidth`, `radius`), so every backend gets the same values
  - `gaps_in`/`gaps_out`
  - Hyprland's blur (`blur`: `decoration.blur.*`). Its size and passes are the one strength that windows and axiom's surfaces share.
  - window opacity (`opacity`).
- `CompositorLayer.look()` decides which parts are on and their values (colors, shape, gaps), the same spec every backend gets ([contract](contract.md)).
- All of it becomes one `hl.config` (`HyprLua.lookLua`, from that spec).
  - The blur and opacity fields are `x-hypr` fields, each gated by `x-hyprIf` on its part, so `configTable` writes them.

### Blur and windows
- With the blur part on, Hyprland's blur stays enabled while axiom's surfaces blur, even if `windowBlur` is off.
- The `axiom-no-window-blur` rule (redefined on or off) then keeps windows and their popups unblurred.
- `CompositorManager.blur` reads the blur in effect (`refreshOptions`). It is used by:
  - the Translucency card's status (`views/settings/TranslucencyStatus`, that card's `x-intro`)
  - the lock screen's frost.

### Where it's applied
- Every part shows in every mode. A managed config writes them through `M.look()`, like the rest of the layer.
- It is a live part ([config modes](config-modes.md) › Live parts): evaluated at runtime as it changes and after every reload in the file modes, so it wins over the user's own lines while it's on, and a part turned off reloads the compositor's config (`CompositorConfigManager._undoLive`).
- `HyprlandManager.refreshOptions()` waits for queued Lua, so `gapsOut` reads what the look set, and Automatic bars follow it.
