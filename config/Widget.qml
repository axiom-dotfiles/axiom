pragma Singleton
import QtQuick

import qs.services

QtObject {
  readonly property int height: ConfigManager.config.Widget.height ?? 24
  readonly property int padding: ConfigManager.config.Widget.padding ?? 8
  readonly property int spacing: ConfigManager.config.Widget.spacing ?? 4
  readonly property int containerWidth: ConfigManager.config.Widget.containerWidth ?? 8 // TODO: move to Config
  readonly property bool workspacePopoutIcons: ConfigManager.config.Widget.workspacePopoutIcons ?? true
  readonly property bool animations: ConfigManager.config.Widget.animations ?? true
  readonly property int animationDuration: ConfigManager.config.Widget.animationDuration ?? 200
}
