pragma Singleton
import QtQuick
import "lib/ConfigLoader.js" as Loader

import qs.config

QtObject {
  id: root

  // Load configuration from JSON
  property var configData: Loader.loadConfig()

  // User settings
  readonly property string userName: configData.Config.userName ?? "user"
  readonly property int workspaceCount: configData.Config.workspaceCount ?? 5
  readonly property bool singleMonitor: configData.Config.singleMonitor ?? true
  readonly property var customIconOverrides: configData.Config.customIconOverrides ?? {}

  // Computed properties
  readonly property int orientation: Bar.vertical ? Qt.Vertical : Qt.Horizontal
  readonly property int containerOffset: Widget.containerWidth + Appearance.borderWidth

  function reload() {
    root.configData = Loader.loadConfig();
    console.log("Configuration reloaded");
  }
}
