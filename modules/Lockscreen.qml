import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

import qs.components.reusable
import qs.components.widgets.lockscreen
import qs.config
import qs.services

Scope {
  Variants {
    model: Quickshell.screens
    delegate: Lockscreen {
      id: lockScreen
      screen: modelData
    }
  }
}
