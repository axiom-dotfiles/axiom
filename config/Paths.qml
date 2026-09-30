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
  // $XDG_RUNTIME_DIR, the user's own 0700 tmpfs (always there, unlike
  // runtimePath, which is made by whatever writes into it)
  readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
  // Scratch files that go with the session: unsaved chat attachments,
  // clipboard thumbnails, copy-only screenshots, album art
  readonly property string runtimePath: root.runtimeDir + "/axiom/"

  // A path from config or the user: trimmed, a leading ~ as home, no
  // trailing slash ("~/Pictures/" -> "/home/<user>/Pictures")
  function expandHome(path) {
    return String(path ?? "").trim().replace(/^~(?=\/|$)/, Quickshell.env("HOME")).replace(/(.)\/+$/, "$1");
  }

  // A path to show: home as ~ ("/home/<user>/x" -> "~/x")
  function shortenHome(path) {
    const home = Quickshell.env("HOME");
    return path === home || String(path).startsWith(home + "/") ? "~" + String(path).slice(home.length) : String(path);
  }
}
