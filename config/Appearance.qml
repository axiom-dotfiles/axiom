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
