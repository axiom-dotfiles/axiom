pragma Singleton
import QtQuick
import qs.services

// Reader for the Widget section: sizing for panels, cards, popouts and
// controls. Bars size their own widgets (Bar.enrichBarConfig).
QtObject {
  readonly property var _c: ConfigManager.config.Widget

  readonly property int height: _c.height
  readonly property int padding: _c.padding
  readonly property int spacing: _c.spacing
  // Corners of what sits inside something (cards, controls, rows, bar
  // widgets); outer edges use Appearance.borderRadius
  readonly property int radius: _c.overrideRadius ? _c.radius : Appearance.borderRadius
}
