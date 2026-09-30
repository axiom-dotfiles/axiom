pragma ComponentBehavior: Bound
import Quickshell

import qs.config
import qs.components.surfaces.border

// The screen border on every screen (Appearance.screenBorder)
Scope {
  Variants {
    model: Appearance.screenBorder ? Quickshell.screens : []
    delegate: RoundedBorders {
      id: border
      required property ShellScreen modelData
      screen: border.modelData
    }
  }
}
