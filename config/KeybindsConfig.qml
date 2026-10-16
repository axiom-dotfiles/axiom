pragma Singleton
import QtQuick
import qs.services

// Reader for the Keybinds section: axiom's own binds, edited on the
// Keybinds page (KeybindManager) and applied by the compositor's config
// writer (on Hyprland, HyprlandConfigManager)
QtObject {
  id: root

  readonly property var _c: ConfigManager.config.Keybinds

  // [{ key, action, argument, call, compositor, description, … }]. Goes
  // through a string so a reload that leaves the list unchanged doesn't
  // re-apply the binds.
  readonly property string _bindsJson: JSON.stringify(_c.binds)
  readonly property var binds: JSON.parse(_bindsJson)
}
