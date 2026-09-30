pragma Singleton
import QtQuick
import Quickshell

// Derived, non-configurable filesystem paths (from the environment, not config).
QtObject {
  id: root

  // --- Paths (from the environment, not from any config value) ---
  readonly property string homeDirectory: Quickshell.env("HOME") + "/"
  // Shell root (this repo), always with a trailing slash
  readonly property string axiomPath: Quickshell.shellDir.toString().replace("file://", "").replace(/\/?$/, "/")
  readonly property string themePath: root.axiomPath + "config/themes/"
  readonly property string scriptsPath: root.axiomPath + "scripts/"
  readonly property string configPath: root.axiomPath + "config/"
  readonly property string statePath: root.configPath + "state/"

  readonly property string hyprlandPath: root.homeDirectory + ".config/hypr/"
  // Per-user state outside the repo ($XDG_STATE_HOME/axiom/): secrets,
  // the generated hyprlock config
  readonly property string userStatePath: (Quickshell.env("XDG_STATE_HOME") || root.homeDirectory + ".local/state") + "/axiom/"

  // A path from config or the user: trimmed, a leading ~ as home, no
  // trailing slash ("~/Pictures/" -> "/home/<user>/Pictures")
  function expandHome(path) {
    return String(path ?? "").trim().replace(/^~(?=\/|$)/, Quickshell.env("HOME")).replace(/(.)\/+$/, "$1");
  }
}
