pragma Singleton
import QtQuick
import qs.services

// Reader for the Appearance section. Values are always present: schema
// defaults are filled in by ConfigManager at load time.
QtObject {
  id: root

  readonly property var _c: ConfigManager.config.Appearance

  // --- Theme (UI-owned, set on the overlay's Themes page) ---
  readonly property string theme: _c.theme
  // From the active theme, not config: a theme is dark or light
  readonly property bool darkMode: ThemeManager.currentTheme.variant !== "light"
  // The primary monitor's wallpaper (the lockscreen's)
  readonly property string wallpaper: _c.wallpaper
  // Monitor name -> wallpaper URL, set per monitor on the Themes page
  readonly property var wallpapers: _c.wallpapers
  function wallpaperFor(monitor) {
    return root.wallpapers[monitor] || root.wallpaper;
  }
  // As configured (for display), and with ~ expanded, no trailing slash
  // "quickshell" (shell/Wallpaper draws it) | "awww" (setWallpaper.sh)
  readonly property string wallpaperBackend: _c.wallpaperBackend
  readonly property string wallpaperFolder: _c.wallpaperFolder
  readonly property string wallpaperPath: Paths.expandHome(_c.wallpaperFolder)
  // "fixed" | "rotate" (wallpaperRotation) | "variant" (variantWallpapers),
  // driven by WallpaperManager
  readonly property string wallpaperMode: _c.wallpaperMode
  readonly property int rotationInterval: _c.wallpaperRotation.interval
  // "random" | "sequential"
  readonly property string rotationOrder: _c.wallpaperRotation.order
  readonly property bool rotationSameOnAll: _c.wallpaperRotation.sameOnAll
  // { dark, light }: file URLs, "" for none
  readonly property string darkWallpaper: _c.variantWallpapers.dark
  readonly property string lightWallpaper: _c.variantWallpapers.light

  // --- Light/dark by time of day (WallpaperManager) ---
  readonly property bool themeScheduled: _c.themeSchedule.enabled
  readonly property string lightAt: _c.themeSchedule.lightAt
  readonly property string darkAt: _c.themeSchedule.darkAt

  // --- Font ---
  readonly property string fontFamily: _c.font.family
  readonly property int fontSize: _c.font.size
  readonly property int fontSizeLarge: fontSize + 4
  // Icons are Material Symbols names drawn in this font (StyledIcon), so
  // they don't depend on the text font
  readonly property string iconFamily: "Material Symbols Rounded"

  // --- Shape ---
  readonly property int borderRadius: _c.shape.radius
  readonly property int borderWidth: _c.shape.borderWidth
  readonly property bool screenBorder: _c.shape.screenBorder
  // The frame can't be thinner than its own outline (a narrower one would
  // draw the stroke over the screen edge); without a frame it's just a gap
  readonly property int screenMargin: screenBorder ? Math.max(borderWidth, _c.shape.screenMargin) : _c.shape.screenMargin

  // --- Translucency ---
  // How solid the shell's surfaces are (0.6–1). Every surface fill goes
  // through fill(), outer and nested alike, so nested fills stack: a card
  // on a 60% panel reads about 84%.
  readonly property real surfaceAlpha: _c.surface.opacity / 100
  readonly property bool translucent: surfaceAlpha < 1
  // Hyprland blurs behind them (HyprlandConfigManager's blur rules, which
  // leave out pixels under blurThreshold: shadows, dims, fades), with its
  // own blur (the window look's blur part, or the user's config)
  readonly property bool blur: translucent && _c.surface.blur
  readonly property bool blurBackdrops: blur && _c.surface.blurBackdrops
  // Blurring what's under each surface, windows included, rather than the
  // wallpaper alone (xray), which every surface shares
  readonly property bool blurThroughWindows: _c.surface.throughWindows
  // Nothing blurs while a fullscreen window is open (BlurManager.active)
  readonly property bool blurPauseFullscreen: _c.surface.pauseFullscreen
  readonly property real blurThreshold: 0.5
  // A shadow's darkest alpha while blurring: under the threshold, so its
  // halo isn't blurred (the blur window casts the chrome's, and Hyprland
  // blurs the chrome's popups)
  readonly property real shadowAlphaMax: blur ? 0.45 : 1

  // A surface fill (a theme color) at the surface opacity
  function fill(color) {
    return translucent ? Qt.alpha(color, color.a * surfaceAlpha) : color;
  }

  // --- Motion ---
  // Every animation in the shell uses one of these durations, so the
  // single speed setting (and the on/off switch) applies uniformly.
  // Use `duration: Appearance.animNormal` — never a literal.
  readonly property bool animations: _c.motion.enabled
  readonly property real _motionScale: animations ? 100 / _c.motion.speed : 0
  readonly property int animFast: Math.round(100 * _motionScale)    // hover, colour, small state changes
  readonly property int animNormal: Math.round(150 * _motionScale)  // slides, popouts, expanding sections
  readonly property int animSlow: Math.round(300 * _motionScale)    // large panels, lockscreen, pulses
  readonly property int easing: Easing.OutCubic
}
