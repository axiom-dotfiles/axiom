pragma Singleton
import QtQuick

import qs.services

QtObject {
  readonly property string primary: ConfigManager.config.Display.primary ?? "DP-1"
  readonly property int resolutionWidth: ConfigManager.config.Display.resolutionWidth ?? 1920
  readonly property int resolutionHeight: ConfigManager.config.Display.resolutionHeight ?? 1080
  readonly property var monitors: ConfigManager.config.Display.monitors ?? []

  readonly property int aspectRatio: resolutionWidth / resolutionHeight

  function isUltrawide() {
    return aspectRatio() > 2.0;
  }
}
