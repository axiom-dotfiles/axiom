pragma ComponentBehavior: Bound
import Quickshell

import qs.components.surfaces.polkit

// The polkit prompt (PolkitManager's open request), on every screen: each
// dims, and the one focused when the request came in shows the card
Scope {
  Variants {
    model: Quickshell.screens
    delegate: PolkitWindow {
      required property ShellScreen modelData
      screen: modelData
    }
  }
}
