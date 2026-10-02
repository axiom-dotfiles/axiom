pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

import qs.config
import qs.services
import qs.components.surfaces.dock

// The docks (DockConfig), one per enabled entry, each on the screens its
// monitor puts it on. Keyed by id, so editing a dock's settings updates it
// in place instead of rebuilding it.
Scope {
  Variants {
    // Once the layer rules are in (HyprlandManager.layerRulesReady)
    model: HyprlandManager.layerRulesReady ? DockConfig.shownIds : []

    delegate: Scope {
      id: entry
      required property string modelData
      readonly property var dock: DockConfig.dockById(modelData)

      Variants {
        model: entry.dock ? DockConfig.screensOf(entry.dock) : []

        delegate: DockWindow {
          required property ShellScreen modelData
          screen: modelData
          dock: entry.dock
        }
      }
    }
  }
}
