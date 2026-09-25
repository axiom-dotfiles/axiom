pragma Singleton
import QtQuick
import qs.services

// Reader for the PowerMenu section. Named PowerMenuConfig because
// `PowerMenu` is the surface type.
QtObject {
  readonly property var _c: ConfigManager.config.PowerMenu

  // "general" | "primaryBar" | "focused" | "all" (see General.screensFor)
  readonly property string monitors: _c.monitors
  // Session actions shown, in order
  readonly property var actions: _c.actions
  // Destructive actions ask for a second press
  readonly property bool confirm: _c.confirm
  readonly property int tileSize: _c.tileSize
  readonly property bool showHeader: _c.showHeader
  readonly property bool showHint: _c.showHint
  // Dim the screen behind it
  readonly property bool showBackdrop: _c.showBackdrop
  // 0-1 opacity of the backdrop
  readonly property real backdrop: _c.backdrop / 100
}
