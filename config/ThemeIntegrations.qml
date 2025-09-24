pragma Singleton
import QtQuick
import "lib/ConfigLoader.js" as Loader

QtObject {
  property var configData: Loader.loadConfig()

  readonly property bool gtk: configData.ThemeIntegrations.gtk ?? false
  readonly property bool nvim: configData.ThemeIntegrations.gtk ?? false
  readonly property bool vscode: configData.ThemeIntegrations.gtk ?? false
  readonly property bool alacritty: configData.ThemeIntegrations.gtk ?? false
  readonly property bool kitty: configData.ThemeIntegrations.gtk ?? false
}
