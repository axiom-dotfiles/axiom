pragma ComponentBehavior: Bound
import Quickshell

import qs.components.widgets.overlay

Scope {
  Variants {
    model: Quickshell.screens
    delegate: OverlayPanel {
      property var modelData: modelData
      screen: modelData
    }
  }
}
