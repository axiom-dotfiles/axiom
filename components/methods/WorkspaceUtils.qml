pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

import qs.config

Singleton {
  id: root

  function focusWorkspace(index) {
    focusWorkspaceProcess.command = [Config.hyprlandPath + "scripts/gotoWorkspace.sh", String(index)]
    focusWorkspaceProcess.running = true
  }

  function moveToWorkspace(workspaceId) {
    Hyprland.dispatch(`movetoworkspace ${workspaceId}`);
  }

  function isWorkspaceVisible(workspaceId) {
    return workspaceId >= 1 && workspaceId <= 25;
  }

  function getActiveWorkspaceId() {
    return Hyprland.focusedMonitor?.activeWorkspace?.id ?? 1;
  }

  Process {
    id: focusWorkspaceProcess
    command: [Config.hyprlandPath + "scripts/gotoWorkspace.sh", ""]
  }
}
