pragma Singleton
import QtQuick
import qs.services

// Reader for the Niri section: niri's own options in the managed config
// (NiriConfigWriter; each field by its x-niri annotation). Named
// NiriConfig after the section, read whole.
QtObject {
  readonly property var _c: ConfigManager.config.Niri

  readonly property string _optionsJson: JSON.stringify(_c)
  readonly property var options: JSON.parse(_optionsJson)
}
