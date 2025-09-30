pragma Singleton
import QtQuick

import qs.services

QtObject {
  readonly property int height: ConfigManager.config.Bar.height ?? 30
  // readonly property alias height: ConfigManager.config.Bar.height
  readonly property bool vertical: ConfigManager.config.Bar.vertical ?? false
  readonly property bool rightSide: ConfigManager.config.Bar.rightSide ?? false
  readonly property bool bottom: ConfigManager.config.Bar.bottom ?? false
  readonly property bool autoHide: ConfigManager.config.Bar.autoHide ?? false
  readonly property bool showOnAllMonitors: ConfigManager.config.Bar.showOnAllMonitors ?? false
}
