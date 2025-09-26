pragma Singleton
import QtQuick
import "lib/ConfigLoader.js" as Loader

QtObject {
  property var configData: Loader.loadConfig()

  readonly property string primary: configData.Display.primary ?? "DP-1"
  readonly property int resolutionWidth: configData.Display.resolutionWidth ?? 1920
  readonly property int resolutionHeight: configData.Display.resolutionHeight ?? 1080
  readonly property var monitors: configData.Display.monitors ?? []

  // Helper functions
  function aspectRatio() {
    return resolutionWidth / resolutionHeight;
  }

  function isUltrawide() {
    return aspectRatio() > 2.0;
  }
}
