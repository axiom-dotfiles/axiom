pragma Singleton
import QtQuick

import qs.services

QtObject {
  property string theme: ConfigManager.config.Appearance.theme ?? "gruvbox-dark"
  property bool darkMode: ConfigManager.config.Appearance.darkMode ?? true
  readonly property int borderRadius: ConfigManager.config.Appearance.borderRadius ?? 4
  readonly property int borderWidth: ConfigManager.config.Appearance.borderWidth ?? 1
  readonly property int screenMargin: ConfigManager.config.Appearance.screenMargin ?? 6
  readonly property string fontFamily: ConfigManager.config.Appearance.fontFamily ?? "monospace"
  readonly property int fontSize: ConfigManager.config.Appearance.fontSize ?? 12
  readonly property int fontSizeLarge: ConfigManager.config.Appearance.fontSize + 4
  readonly property bool autoThemeSwitch: ConfigManager.config.Appearance.autoThemeSwitch ?? false
  readonly property string generatedThemeSource: ConfigManager.config.Appearance.generatedThemeSource ?? "pywal"
  readonly property int containerWidth: ConfigManager.config.Appearance.containerWidth ?? 8
  readonly property bool workspacePopoutIcons: ConfigManager.config.Appearance.workspacePopoutIcons ?? true
  readonly property int animationDuration: ConfigManager.config.Appearance.animationDuration ?? 200
}
