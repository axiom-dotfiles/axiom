pragma Singleton
import QtQuick
import qs.services

// Reader for the BarStyle section: how every bar draws its widgets,
// accents and shadow, unless it overrides a group of them
// (Bar.enrichBarConfig)
QtObject {
  // The section's values by key, as a bar's own would be
  readonly property var values: ConfigManager.config.BarStyle
}
