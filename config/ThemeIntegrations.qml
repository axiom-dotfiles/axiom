pragma Singleton
import QtQuick

import qs.services

QtObject {
  readonly property bool gtk: ConfigManager.config.ThemeIntegrations.gtk ?? false
  readonly property bool nvim: ConfigManager.config.ThemeIntegrations.gtk ?? false
  readonly property bool vscode: ConfigManager.config.ThemeIntegrations.gtk ?? false
  readonly property bool alacritty: ConfigManager.config.ThemeIntegrations.gtk ?? false
  readonly property bool kitty: ConfigManager.config.ThemeIntegrations.gtk ?? false
}
