pragma Singleton
import QtQuick
import qs.services

// Reader for the BarStyle section: how every bar draws its widgets,
// accents and shadow, unless it overrides a group of them
// (Bar.enrichBarConfig)
QtObject {
  // The section's values by key, as a bar's own would be
  readonly property var values: ConfigManager.config.BarStyle
  // Whether surfaces cast the shadow or glow, and how far past them it
  // reaches (its blur and offset), which their windows keep room for
  readonly property bool shadowed: values.shadow !== "none"
  readonly property int shadowReach: shadowed ? Math.ceil(values.shadowSize * 1.25) : 0
}
