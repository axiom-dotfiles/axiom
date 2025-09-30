pragma Singleton
import QtQuick

import qs.config
import qs.services

QtObject {
  id: root

  // --- Configurable ---
  readonly property string userName: ConfigManager.config.Config.userName ?? "user"
  readonly property int workspaceCount: ConfigManager.config.Config.workspaceCount ?? 5
  readonly property bool singleMonitor: ConfigManager.config.Config.singleMonitor ?? true
  readonly property var customIconOverrides: ConfigManager.config.Config.customIconOverrides ?? {}

  // --- Computed ---
  readonly property int orientation: Bar.vertical ? Qt.Vertical : Qt.Horizontal
  readonly property int containerOffset: Widget.containerWidth + Appearance.borderWidth

  // todo - make this dynamic and fix
  property string wallpaper: ""
  property string homeDirectory: "/home/" + root.userName + "/"
  property string themePath: root.homeDirectory + ".config/quickshell/axiom/config/themes/"
  property string generatedThemePath: themePath + "generated/"
  readonly property string scriptsPath: root.homeDirectory + ".config/quickshell/axiom/scripts/"
  readonly property string walCachePath: root.homeDirectory + ".cache/wal/schemes/"
  readonly property string cachePath: root.homeDirectory + ".cache/quickshell/axiom/generated/"
}
