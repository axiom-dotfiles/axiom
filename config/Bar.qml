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
  readonly property var bars: {
    const configs = ConfigManager.config.Bar || [];
    const result = [];

    for (let i = 0; i < configs.length; i++) {
      const barConfig = configs[i];
      console.log("bar location:", barConfig.location);
      const loc = Bar.getLocationFromString(barConfig.location ?? "Top");

      result.push({
        "id": barConfig.id || "",
        "primary": barConfig.primary ?? (i === 0),
        "enabled": barConfig.enabled ?? true,
        "display": barConfig.display || "",
        "extent": barConfig.extent ?? Bar.extent,
        "spacing": barConfig.spacing ?? Bar.spacing,
        "location": loc,
        "autoHide": barConfig.autoHide ?? false,
        "widgets": barConfig.widgets || null,
        "vertical": loc === Bar.Left || loc === Bar.Right,
        "left": loc === Bar.Left,
        "right": loc === Bar.Right,
        "top": loc === Bar.Top,
        "bottom": loc === Bar.Bottom
      });
    }

    // Ensuer primary bar is first
    return result.sort((a, b) => (a.primary === b.primary) ? 0 : a.primary ? -1 : 1);
  }
  // Global convenience properties for first bar
  readonly property bool enabled: Bar.bars[0]?.enabled ?? true
  readonly property int extent: Bar.bars[0]?.extent ?? 30
  readonly property bool autoHide: Bar.bars[0]?.autoHide ?? false
  readonly property int location: Bar.getLocationFromString(Bar.bars[0]?.location ?? "Top")
  readonly property var widgets: Bar.bars[0]?.widgets ?? null
  readonly property int spacing: Bar.bars[0]?.spacing ?? 6

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
