pragma Singleton
import QtQuick

import qs.services

QtObject {
  readonly property int height: ConfigManager.config.Widget.height ?? 24
  readonly property int padding: ConfigManager.config.Widget.padding ?? 8
  readonly property int spacing: ConfigManager.config.Widget.spacing ?? 4
}
