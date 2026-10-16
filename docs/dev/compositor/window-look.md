# Window look

> **Files:** `config/WindowLookConfig.qml`, `config/Bar.qml`, `services/CompositorConfigManager.qml`, `services/HyprlandConfigWriter.qml`, `components/methods/CompositorLayer.qml`, `components/methods/HyprLua.qml`, `services/HyprlandManager.qml`, `components/views/settings/TranslucencyStatus.qml`
> **Config:** `WindowLook.*` (borders and their colors, `shape`, `matchShell`, `borderSize`, `rounding`, gaps, `blur`, `opacity`, `windowBlur`)
> **Related:** [The compositor](README.md), [Contract](contract.md), [Config modes](config-modes.md), [Translucency and blur](../theming/translucency-blur.md), [Lockscreen](../features/lockscreen.md)

The themed window look axiom gives the compositor: borders, shape, gaps, blur and window opacity. The settings are compositor-neutral (`WindowLook`, Settings › Compositor). `CompositorLayer.look()` decides the parts once; each backend's config writer turns it into its own text, in every mode ([config modes](config-modes.md)); on Hyprland that is one `hl.config`.

### What it covers
- The section is `WindowLook` (`WindowLookConfig.look`; `Hyprland.look` before config version 56). It is `x-scope: look`, so exports, examples and imports carry it. It isn't `x-takeover`.
- Each part's fields carry `x-enabledIf: { "/$supports.window<Part>": true }`, so a compositor without that part shows them greyed out with why ([schema annotations](../core/schema-annotations.md)); fields one compositor alone has also need `"/$compositor"`.
- It holds:
  - themed borders: `activeColor`/`inactiveColor` (theme color names; empty follows the theme's `borderFocus`/`border`)
  - the shape: border width and corner rounding, axiom's (`Appearance.borderWidth`/`borderRadius`) while `matchShell`, else `borderSize`/`rounding`. Hyprland's managed options held these before config version 58.
  - `WindowLookConfig` resolves both (`activeBorder`, `inactiveBorder`, `borderWidth`, `radius`), so every backend gets the same values
  - `gaps_in`/`gaps_out`
  - Hyprland's blur (`blur`: `decoration.blur.*`). Its size and passes are the one strength that windows and axiom's surfaces share.
  - the blur behind axiom's surfaces (`surfaceBlur*`, [translucency](../theming/translucency-blur.md))
  - window shadows (`shadow`, `shadowSize`, `shadowPower` on Hyprland, `shadowColor`: empty is the compositor's own) and dimming of unfocused windows (`dim`, `dimStrength`). Hyprland's managed options held these before config version 63; they now apply in every mode.
  - while `shadowMatchShell` (the default), the shadow is axiom's: Bar style's (`BarStyle.shadow`, its color as `Bar.shadowBaseColor` gives it, alpha included, and `shadowSize`), falling `shadowSize / 4` downward for a shadow and evenly for a glow, as `SurfaceShadow` casts it. Bar style's none casts none: the part is then off (`WindowLookConfig.shadowOn`). `WindowLookConfig` resolves it (`shadowOn`, `shadowSize`, `shadowColor`, `shadowAlpha`, `shadowOffset`) and `CompositorConfigManager.spec` hands it to `look()` as `opts.shadow`; the spec's color is `rrggbbaa` (and `rgb`/`alpha` apart). Matching axiom's, the spec says `soft`: Hyprland's shadow is the full color at the window's edge, held by its falloff, where a gaussian (axiom's, SwayFX's) is half and fades, so Hyprland draws it at `HyprLua.softShadowAlpha` (0.4) of its alpha; SwayFX takes it as it is.
  - window opacity (`opacity`).
- `CompositorLayer.look()` decides which parts are on and their values (colors, shape, gaps), the same spec every backend gets ([contract](contract.md)).
- All of it becomes one `hl.config` (`HyprLua.lookLua`, from that spec).
  - The blur and opacity fields are `x-hypr` fields, each gated by `x-hyprIf` on its part, so `configTable` writes them. The shadow and dim come from the spec (`decoration.shadow.*`, the offset as the sequence `{ 0, y }`: Hyprland refuses `{ x = …, y = … }` for a vec2; `dim_inactive`/`dim_strength`), as the borders do, the color resolved first (`WindowLookConfig.shadowColor`).

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
