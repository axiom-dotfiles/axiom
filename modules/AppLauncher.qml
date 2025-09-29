import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io

import qs.components.reusable
import qs.components.widgets.applauncher
import qs.config

Scope {
  Variants {
    model: Quickshell.screens
    delegate: Launcher {
      property var modelData: modelData
      id: appLauncher
      screen: modelData
    }
  }
}
