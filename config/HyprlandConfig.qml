pragma Singleton
import QtQuick
import qs.services

// Reader for the Hyprland section: how axiom sets Hyprland up
// (HyprlandConfigManager). Named HyprlandConfig because `Hyprland` is
// Quickshell's singleton.
QtObject {
  readonly property var _c: ConfigManager.config.Hyprland

  // "detached" | "included" | "managed"
  readonly property string mode: _c.mode
  readonly property bool requiredSettings: _c.requiredSettings
  readonly property bool theme: _c.theme
  readonly property bool blur: _c.blur
  readonly property bool wallpaperDaemon: _c.wallpaperDaemon
  // [{ key, action, argument, description }]. Goes through a string so a
  // reload that leaves the list unchanged doesn't re-apply the binds.
  readonly property string _bindsJson: JSON.stringify(_c.binds)
  readonly property var binds: JSON.parse(_bindsJson)
  // Monitor profiles ({ name, outputs: [MonitorRule] }), edited on the
  // Monitors page (MonitorManager)
  readonly property string _monitorsJson: JSON.stringify(_c.monitors.profiles)
  readonly property var monitorProfiles: JSON.parse(_monitorsJson)
  // The managed hyprland.lua's own settings (layout, gaps, input, ...)
  readonly property string _managedJson: JSON.stringify(_c.managed)
  readonly property var managed: JSON.parse(_managedJson)
}
