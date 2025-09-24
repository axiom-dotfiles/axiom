// TODO split this up or focus struct oriented configuration
// Ideally hotload a json file?
pragma Singleton
import QtQuick
import qs.themes

QtObject {
  // ---- Add more user settings here over time ----
  property string theme: "Gruxbox"   // only setting for now

  readonly property QtObject display: QtObject {
    readonly property string primary: "DP-1"
    property int resolutionWidth: 3440
    property int resolutionHeight: 1440
  }

  // Resolved theme object (auto-updates when 'theme' changes)
  readonly property var currentTheme: ThemeIndex.get(theme)

  property int borderRadius: 4
  property int barHeight: 46

  property int widgetHeight: 30
  property int widgetPadding: 10
  property int widgetSpacing: 6
  property int workspaceCount: 5 // DO NOT CHANGE


  property int borderWidth: 1

  property int screenMargin: 6

  property string fontFamily: "JetBrains Mono Nerd Font"
  property int fontSize: 18

  property bool verticalBar: true
  property bool rightVerticalBar: false
  property bool bottomBar: false
  property int orientation: verticalBar ? Qt.Vertical : Qt.Horizontal

  // property string display: "DP-1"

  property bool singleMonitor: true
  property string userName: "travmonkey"
  property bool workspacePopoutIcons: true

  property int containerWidth: 8


  property var customIconOverrides: ({
    "spotify-client": "file:///opt/spotify/icons/spotify-linux-32.png",
  })
}
