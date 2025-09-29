import Quickshell

import qs.components.widgets.lockscreen

Scope {
  Variants {
    model: Quickshell.screens
    delegate: Lockscreen {
      property var modelData: modelData
      id: lockScreen
      screen: modelData
    }
  }
}
