pragma Singleton
import QtQuick
import qs.services
import qs.components.methods

// Reader for the Lockscreen section: which locker locks the session, and
// what the built-in one shows (`layout`, as saved: the lock never shows
// the layouts editor's unsaved draft, LockManager.localLayout).
// Named LockscreenConfig because `Lockscreen` is the shell entry type.
QtObject {
  id: root

  readonly property var _c: ConfigManager.config.Lockscreen

  // "quickshell" (built-in) | "hyprlock" (themed by axiom) | "none"
  readonly property string mode: _c.mode
  // What lock buttons run in "none" mode
  readonly property string lockCommand: _c.lockCommand
  readonly property bool blurWallpaper: _c.blurWallpaper

  // The built-in lock screen: { columns, rows (its grid, fitted to each
  // monitor; fineGrid splits its units in two), otherScreens ("layout":
  // the modules without the password | "background"), background
  // ("wallpaper" | "color"), backgroundColor, dim (%), moduleBorders,
  // modules }. LockSurface takes it whole, so the layouts editor's preview
  // can hand it the draft instead
  readonly property var layout: _c.layout
  // A layout's grid in the units its places use: columns × rows, each
  // split in two with `fineGrid`. { cols, rows }
  function gridOf(layout) {
    const scale = layout?.fineGrid ? 2 : 1;
    return {
      "cols": (layout?.columns ?? 0) * scale,
      "rows": (layout?.rows ?? 0) * scale
    };
  }

  // Its own fields in groups (`x-group`), for the layouts editor
  readonly property var fieldGroups: SchemaLayout.objectGroups(ConfigManager.configSchema.properties.Lockscreen.properties.layout, ["modules"])
}
