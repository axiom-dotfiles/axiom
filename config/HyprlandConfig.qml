pragma Singleton
import QtQuick
import qs.services

// Reader for the Hyprland section: what axiom writes into Hyprland
// (HyprlandConfigManager). Named HyprlandConfig because `Hyprland` is
// Quickshell's singleton.
QtObject {
  readonly property var _c: ConfigManager.config.Hyprland

  // The managed hyprland.lua's own settings (layout, input, ...)
  readonly property string _managedJson: JSON.stringify(_c.managed)
  readonly property var managed: JSON.parse(_managedJson)
}
