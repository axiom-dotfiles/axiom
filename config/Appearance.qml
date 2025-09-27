pragma Singleton
import QtQuick
import "lib/ConfigLoader.js" as Loader

QtObject {
  property var configData: Loader.loadConfig()

  property string theme: configData.Appearance.theme ?? "gruvbox-dark"
  property bool darkMode: configData.Appearance.darkMode ?? true
  readonly property int borderRadius: configData.Appearance.borderRadius ?? 4
  readonly property int borderWidth: configData.Appearance.borderWidth ?? 1
  readonly property int screenMargin: configData.Appearance.screenMargin ?? 6
  readonly property string fontFamily: configData.Appearance.fontFamily ?? "monospace"
  readonly property int fontSize: configData.Appearance.fontSize ?? 12
  readonly property int fontSizeLarge: configData.Appearance.fontSize + 4
  readonly property bool autoThemeSwitch: configData.Appearance.autoThemeSwitch ?? false
  readonly property string generatedThemeSource: configData.Appearance.generatedThemeSource ?? "pywal"
}
