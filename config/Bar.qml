pragma Singleton
import QtQuick

import qs.services
import qs.config

QtObject {
  enum Location {
    Top,
    Bottom,
    Left,
    Right
  }
  // Firsty entry is primary bar
  // this will be very easily expandable for unlimited fully configurable bars in the future
  // but proof of concept for now
  readonly property bool enabled: ConfigManager.config.Bar[0].enabled ?? true
  readonly property int extent: ConfigManager.config.Bar[0].extent ?? 30
  readonly property bool autoHide: ConfigManager.config.Bar[0].autoHide ?? false
  readonly property int location: Bar.getLocationFromString(ConfigManager.config.Bar[0].location ?? "Top")
  readonly property QtObject widgets: ConfigManager.config.Bar[0]?.widgets ?? null

  readonly property QtObject nonPrimary: QtObject {
    property bool enabled: ConfigManager.config.Bar[1]?.enabled ?? Bar.enabled
    property int extent: ConfigManager.config.Bar[1]?.extent ?? Bar.extent
    property bool autoHide: ConfigManager.config.Bar[1]?.autoHide ?? Bar.autoHide
    property int location: Bar.getLocationFromString(ConfigManager.config.Bar[1]?.location ?? Bar.location)
    property var widgets: ConfigManager.config.Bar[1]?.widgets ?? Bar.widgets

    property bool vertical: location === Bar.Left || location === Bar.Right
    property bool left: location === Bar.Left
    property bool right: location === Bar.Right
    property bool top: location === Bar.Top
    property bool bottom: location === Bar.Bottom
  }

  // Computed convenience properties
  readonly property bool vertical: location === Bar.Left || location === Bar.Right
  readonly property bool left: location === Bar.Left
  readonly property bool right: location === Bar.Right
  readonly property bool top: location === Bar.Top
  readonly property bool bottom: location === Bar.Bottom

  function getLocationFromString(locStr) {
    switch (locStr) {
    case "Top":
      return Bar.Top;
    case "Bottom":
      return Bar.Bottom;
    case "Left":
      return Bar.Left;
    case "Right":
      return Bar.Right;
    default:
      console.warn("Invalid bar location in config:", locStr, "defaulting to Left");
      return Bar.Left;
    }
  }
}
