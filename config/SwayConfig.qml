pragma Singleton
import QtQuick
import qs.services

// Reader for the Sway section: sway's own options in the managed config
// (SwayConfigWriter; each field by its x-sway annotation). Named
// SwayConfig after the section, read whole.
QtObject {
  readonly property var _c: ConfigManager.config.Sway

  readonly property string _optionsJson: JSON.stringify(_c)
  readonly property var options: JSON.parse(_optionsJson)
}
