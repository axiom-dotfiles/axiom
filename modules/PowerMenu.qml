import Quickshell

import qs.components.widgets.powermenu

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
