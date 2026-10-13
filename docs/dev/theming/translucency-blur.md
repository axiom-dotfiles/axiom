# Translucency and blur

> **Files:** `config/Appearance.qml`, `services/BlurManager.qml`, `components/methods/HyprLua.qml`, `services/HyprlandConfigManager.qml`, `components/views/settings/TranslucencyStatus.qml`, `components/surfaces/screenlayout/ScreenLayoutView.qml`
> **Config:** `Appearance.surface.*` (`opacity`, `blur`, `throughWindows`, `blurBackdrops`, `pauseFullscreen`)
> **Related:** [Blur window and openings](blur-window-openings.md), [Window look](../hyprland/window-look.md), [Popout registry](../popouts/registry.md)

The translucency setting, how fills apply it, the Hyprland layer rules axiom writes for blur, and per-screen and fullscreen behaviour. How chrome surfaces share one blurred backing window is in [Blur window and openings](blur-window-openings.md).

### The setting
- Look & Feel → Translucency, `Appearance.surface`:
  - `opacity`: 60–100%. 100 is solid and blurs nothing.
  - `blur`, `throughWindows`, `blurBackdrops`;
  - `pauseFullscreen` (`x-scope: machine`).
- The strength isn't axiom's. Hyprland has one blur, for windows and layers alike, set by the window look's blur part (Hyprland → Window look, see [Window look](../hyprland/window-look.md)) or the user's own config.
- The card's intro (`TranslucencyStatus`):
  - warns that transparency and blur are experimental;
  - while blurring, shows the blur in effect;
  - with Hyprland's blur off (nothing blurs then), offers to set it.
- Reader properties: `Appearance.surfaceAlpha`, `translucent`, `blur`, `blurThroughWindows`, `blurBackdrops`, `blurThreshold` (0.5), `shadowAlphaMax`.

### Fills
- Every surface fill goes through `Appearance.fill(color)` at the shared pieces' draw sites:
  - `AttachedSurface`, `FloatingPopout`, `CornerPiece`, `BorderPanel`;
  - the bar's background and islands, the overlay's box and navigator;
  - edge menus, docks, power menu, overview, polkit and monitor prompts;
  - `StyledContainer`, `Card`/`Panel`, buttons, inputs, `ActionTile`, `DropdownSurface`.
- Outer and nested fills alike, so nested fills stack: a card on a 60% panel reads about 84%.
- Accent colors and hover tints are left alone.

### Hyprland layer rules
Written by `HyprLua.blurLua` (HyprlandConfigManager's `_blurLua`, `M.blur()` in the module). The named layer rules are always written, `enabled` or not, since a rule is taken back by redefining it (no reload).
- `axiom-blur`, on the namespaces that blur themselves (`HyprLua.blurSurfaces`: the blur window, the overlay, the floating launcher and switcher, notifications, …):
  - `blur_popups`, and `ignore_alpha` at the threshold. The big transparent windows need it; shadows are capped under the threshold while blurring (`Bar.shadowColor`).
  - `xray` is always written, off with `throughWindows`. Left out, a layer takes `decoration.blur.xray`, which the window look turns on.
- `axiom-blur-popups`, on the chrome's own namespaces (`HyprLua.blurChrome`), for their popups alone (tooltips, the dock's menu):
  - Hyprland blurs a layer's popups whether or not the layer blurs, never with xray, and with its `ignore_alpha`.
  - So a bar popout, a popup drawn transparent over the blur window, blurs only under its content.
- `axiom-blur-backdrops`, on `axiom-backdrop` and polkit (whose window holds its dim), at any alpha.
- `axiom-blur-no-anim`: `no_anim` on `HyprLua.blurBacked`, the windows the blur window draws for, while it does.
  - They slide themselves. Hyprland fading or popping one in (its `layers`/`fade` animations, read as it maps) would leave its stroke and content behind the fill, blur and shadow drawn for it, which it doesn't animate.
- That's all it writes: the strength is Hyprland's own blur.
- The module file holds the setting as saved (`_surfacesBlur(true)`). At runtime it's `BlurManager.active`, evaluated over the file after every reload.

### No reload per step
- The window look and the blur are HyprlandConfigManager's `_liveInputs`.
- In every mode a change is only evaluated at runtime (`_applyLook`, which also runs after every reload); the file catches up on its next write.
- Turning a look part off rewrites the file (an eval can't take a setting back).

### Per screen
`BlurManager.backsOn(screen, onOverlay)`:
- A surface on the Overlay layer (bar popouts and submenus, edge popouts, OSDs) fills itself, translucent, while the overlay is open on its screen, since the overlay covers the blur window.
  - It reads its host's `onOverlayLayer`, which its submenu follows (not while it slides under a bar).
- A surface on Top (bars, the border, docks, integrated menus) leaves the blur window while a fullscreen window shows there, since that fades the Top layer out.
  - The blur window itself then rises to the Overlay layer on that screen (`overFullscreen`, order 9 keeping it under the surfaces there), so what shows over a fullscreen window still blurs.

### Paused over fullscreen
- `pauseFullscreen` (on by default): while any screen shows a fullscreen window, `BlurManager.active` is false:
  - the blur window goes and the chrome fills itself;
  - the rules are taken back at runtime, as is Hyprland's blur where the window look kept it on for the surfaces alone (the module file keeps the saved setting).
- On the screens showing one, surfaces fill solid (`opaqueOn`): `AttachedSurface.opaque`, `BlurManager.fillOn` for floating popouts, `StyledContainer.solid` for toasts.
- Elsewhere they stay translucent.

### Stacking
- The chrome's fills all live in the one blur window (Top, order 9), under every chrome window.
- A chrome surface that stood over another one in a higher layer (the attached launcher, an Overlay-layer edge popout, over a dock) no longer hides it with its fill: what's in between shows through.
- So popouts never overlap: what one covers gives way (see [Popout registry](../popouts/registry.md)).
- While the blur window backs surfaces, an edge popout slides out only once its window's origin is known (`LayerOrigin.settled`, or a moment's timeout), so its first frames never fill and shadow themselves beside backed ones.

### Lock screen and greeter
- No compositor blur reaches a session-lock surface, so `ScreenLayoutView` frosts its own background under the modules while the shell blurs (`frosted`):
  - the backdrop is blurred at about Hyprland's strength (`hyprBlur`);
  - the lock surface reads it from `HyprlandManager.blur`; the greeter leaves it at Hyprland's defaults;
  - masked by the modules at the blur threshold.
- Not when the wallpaper is blurred already.
