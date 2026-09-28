pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.components.methods

/*
 * What changes the look on its own (ThemeManager sets it):
 * - Appearance.wallpaperMode "rotate": a new wallpaper from the folder every
 *   `rotationInterval` minutes (random or in order, one for all monitors or
 *   one each). The time of the last change survives QML reloads.
 * - "variant": the light or dark wallpaper, whichever the active theme's
 *   variant is, on every monitor.
 * - Appearance.themeScheduled: the theme's light variant from `lightAt`, its
 *   dark one from `darkAt` (DailySchedule; a switch by hand lasts until the
 *   next of those).
 * A generated theme follows a wallpaper changed this way (the primary
 * monitor's); a pick by hand always generates, as the picker does.
 * Created from shell.qml's `_services`.
 *
 *   qs -c axiom ipc call wallpaper next
 */
Singleton {
  id: root

  readonly property string mode: Appearance.wallpaperMode

  // A pick by hand from a wallpaper picker: `monitor`'s wallpaper, or in
  // "variant" mode the variant's
  function pick(url, monitor, variant) {
    if (root.mode === "variant") {
      root.setVariantWallpaper(variant || (Appearance.darkMode ? "dark" : "light"), url);
      return;
    }
    _run.lastRotated = Date.now();
    ThemeManager.setWallpaperAndGenerate(url, monitor);
  }

  // The light or dark wallpaper ("dark" | "light"); shown at once when it's
  // the current variant's
  function setVariantWallpaper(variant, url) {
    if (variant === (Appearance.darkMode ? "dark" : "light"))
      root._show(root._everywhere(url.toString()), true);
    const values = {};
    values["Appearance.variantWallpapers." + variant] = url.toString();
    SettingsManager.commitValues(values);
  }

  // The next wallpaper of the rotation now, in whichever mode, and the timer
  // starts over
  function next() {
    const list = root._wallpaperList();
    if (list.length === 0) {
      console.log("[WallpaperManager] No wallpapers in", Appearance.wallpaperPath);
      return;
    }
    _run.lastRotated = Date.now();
    const order = Appearance.rotationOrder;
    const screens = Quickshell.screens.map(screen => screen.name);
    if (Appearance.rotationSameOnAll) {
      root._show(root._everywhere(Schedules.nextWallpaper(list, Appearance.wallpaperFor(General.primaryMonitor), order, [], Math.random())), false);
      return;
    }
    const taken = [];
    const wallpapers = {};
    for (const monitor of screens) {
      const url = Schedules.nextWallpaper(list, Appearance.wallpaperFor(monitor), order, taken, Math.random());
      taken.push(url);
      wallpapers[monitor] = url;
    }
    root._show(wallpapers, false);
  }

  // --- Private ---

  PersistentProperties {
    id: _run
    reloadableId: "axiomWallpaper"
    // ms since the epoch; 0 until the first rotation or start
    property real lastRotated: 0
  }

  function _everywhere(url) {
    return Quickshell.screens.reduce((map, screen) => {
      map[screen.name] = url;
      return map;
    }, {});
  }

  // Sets them, and regenerates the themes from the primary's when asked or
  // when a generated theme is showing
  function _show(wallpapers, generate) {
    if (!ThemeManager.setWallpapers(wallpapers)) {
      // In place already, but a generated theme may be from another one (a
      // switch that landed mid-generation)
      ThemeManager.syncGeneratedTheme();
      return;
    }
    const primary = wallpapers[General.primaryMonitor] ?? Appearance.wallpaper;
    if (primary && (generate || Appearance.theme.startsWith("generated/")))
      ThemeManager.generateThemesFromWallpaper(primary);
  }

  function _wallpaperList() {
    const model = ThemeManager.wallpaperModel;
    const list = [];
    for (let i = 0; i < model.count; i++)
      list.push(model.get(i, "fileUrl").toString());
    return list;
  }

  // --- Rotation ---
  onModeChanged: if (root.mode === "rotate")
    _run.lastRotated = Date.now()

  property Timer _rotation: Timer {
    interval: 30000
    repeat: true
    running: root.mode === "rotate"
    onTriggered: {
      if (Date.now() - _run.lastRotated >= Appearance.rotationInterval * 60000)
        root.next();
    }
  }

  // --- Light and dark wallpapers ---
  // A string, so config reloads that change nothing don't re-apply it.
  // It changes during a config reload (a new theme's variant), so the save
  // waits until that's done.
  readonly property string _variantWallpaper: root.mode === "variant" ? (Appearance.darkMode ? Appearance.darkWallpaper : Appearance.lightWallpaper) : ""
  on_VariantWallpaperChanged: Qt.callLater(root._showVariant)

  function _showVariant() {
    if (root._variantWallpaper)
      root._show(root._everywhere(root._variantWallpaper), false);
  }

  // --- Light and dark by time ---
  property var _pendingLight: null

  function _setLight(light) {
    // The theme list isn't read yet: once it is
    if (!ThemeManager.currentFamily) {
      root._pendingLight = light;
      return;
    }
    root._pendingLight = null;
    ThemeManager.setLightMode(light);
  }

  property Connections _families: Connections {
    target: ThemeManager
    function onCurrentFamilyChanged() {
      if (root._pendingLight !== null && ThemeManager.currentFamily)
        root._setLight(root._pendingLight);
    }
  }

  property DailySchedule _themeSchedule: DailySchedule {
    name: "theme"
    enabled: Appearance.themeScheduled
    startAt: Appearance.lightAt
    endAt: Appearance.darkAt
    onDue: light => root._setLight(light)
  }

  property IpcHandler _ipc: IpcHandler {
    target: "wallpaper"

    function next(): void {
      root.next();
    }
  }

  Component.onCompleted: {
    if (_run.lastRotated === 0)
      _run.lastRotated = Date.now();
    // Variant wallpapers set while qs wasn't running
    Qt.callLater(root._showVariant);
  }
}
