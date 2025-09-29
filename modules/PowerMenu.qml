import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.components.reusable
import qs.components.widgets.powermenu
import qs.config
import qs.services

Scope {
  Variants {
    model: Quickshell.screens
    delegate: PowerMenu {
      property var modelData: modelData
      id: powerMenu
      screen: modelData
    }
  }
}
