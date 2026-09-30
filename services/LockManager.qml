pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

import qs.config

// The one way to lock the session, whatever locks it (Lockscreen.mode):
//   "quickshell"  the built-in locker (shell/Lockscreen.qml: Wayland
//                 session lock + PAM through AuthManager)
//   "hyprlock"    hyprlock, with a config ThemeManager generates from the
//                 axiom theme
//   "none"        the user's own locker: runs Lockscreen.lockCommand
// Lock buttons call lock(); idle daemons call the `lockscreen` IPC target
// (`qs -c axiom ipc call lockscreen lock`), which exists only when axiom
// provides the locker, so "none" can't loop through loginctl lock-session.
QtObject {
  id: root

  readonly property string mode: LockscreenConfig.mode
  // Where ThemeManager writes the themed hyprlock config
  readonly property string hyprlockConfigPath: Paths.userStatePath + "hyprlock.conf"

  // The built-in lock is up (set by shell/Lockscreen.qml, which owns it)
  property bool builtinLocked: false

  // For the built-in locker
  signal lockRequested
  // Any lock started: menus and popups can close
  signal lockStarted

  function lock() {
    switch (root.mode) {
    case "quickshell":
      root.lockRequested();
      break;
    case "hyprlock":
      // Generated first if a theme change hasn't written it yet
      if (FileManager.read("file://" + root.hyprlockConfigPath))
        root._runHyprlock();
      else
        ThemeManager.generateHyprlockConfig(root._runHyprlock);
      break;
    default:
      if (LockscreenConfig.lockCommand)
        Quickshell.execDetached(["sh", "-c", LockscreenConfig.lockCommand]);
    }
    root.lockStarted();
  }

  function _runHyprlock() {
    Quickshell.execDetached(["sh", "-c", 'pidof hyprlock >/dev/null || exec hyprlock -c "$1"', "sh", root.hyprlockConfigPath]);
  }

  // Switching to hyprlock writes its config straight away
  onModeChanged: if (mode === "hyprlock")
    ThemeManager.generateHyprlockConfig()
  Component.onCompleted: if (mode === "hyprlock")
    ThemeManager.generateHyprlockConfig()

  property IpcHandler _ipc: IpcHandler {
    target: "lockscreen"
    enabled: root.mode !== "none"

    function lock(): void {
      root.lock();
    }
  }
}
