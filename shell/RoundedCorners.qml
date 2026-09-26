import QtQuick
import Quickshell

import qs.config
import qs.components.surfaces.border

Scope {
  Variants {
    // Appearance.screenBorder switches the frame off entirely
    model: Appearance.screenBorder ? Quickshell.screens : []
    delegate: RoundedBorders {
      required property ShellScreen modelData
      screen: modelData
    }
  }
}
