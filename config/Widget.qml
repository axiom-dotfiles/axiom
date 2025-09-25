pragma Singleton
import QtQuick
import "lib/ConfigLoader.js" as Loader

QtObject {
  property var configData: Loader.loadConfig()

  readonly property int height: configData.Widget.height ?? 24
  readonly property int padding: configData.Widget.padding ?? 8
  readonly property int spacing: configData.Widget.spacing ?? 4
  readonly property int containerWidth: configData.Widget.containerWidth ?? 8 // TODO: move to Config
  readonly property bool workspacePopoutIcons: configData.Widget.workspacePopoutIcons ?? true
  readonly property bool animations: configData.Widget.animations ?? true
  readonly property int animationDuration: configData.Widget.animationDuration ?? 200
}
