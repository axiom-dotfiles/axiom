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
}
