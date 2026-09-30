pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

import qs.components.surfaces.launcher
import qs.config

Scope {
  Variants {
    model: General.screensFor(LauncherConfig.monitors)
    delegate: Launcher {
      required property ShellScreen modelData
      screen: modelData
    }
  }
}
