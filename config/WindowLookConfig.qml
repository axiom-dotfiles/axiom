pragma Singleton
import QtQuick
import qs.services

// Reader for the WindowLook section: settings that make windows match
// axiom ({ borders, shape, gaps, gapsIn, gapsOut, blur…, opacity… }),
// applied by the compositor's backend (on Hyprland, HyprlandConfigManager's
// look layer). Named WindowLookConfig as the section is a whole object.
QtObject {
  id: root

  readonly property var _c: ConfigManager.config.WindowLook

  // Goes through a string so a reload that leaves it unchanged doesn't
  // apply it again
  readonly property string _lookJson: JSON.stringify(_c)
  readonly property var look: JSON.parse(_lookJson)
}
