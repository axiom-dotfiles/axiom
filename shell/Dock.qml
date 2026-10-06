pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

import qs.config
import qs.services
import qs.components.surfaces.dock

// The docks (DockConfig), one per enabled entry, each on the screens its
// `monitors` puts it on: on the focused monitor only, it's rebuilt on the
// one focus moves to. Keyed by id, so editing a dock's settings updates it
// in place instead of rebuilding it. The settings card's Show is a
// preview copy over the overlay (DockManager.preview), on the screen it
// would show on.
Scope {
  Variants {
    // Once the layer rules are in (HyprlandManager.layerRulesReady)
    model: HyprlandManager.layerRulesReady ? DockConfig.shownIds : []

    delegate: Scope {
      id: entry
      required property string modelData
      readonly property var dock: DockConfig.dockById(modelData)

      Variants {
        model: entry.dock ? DockConfig.screensOf(entry.dock).filter(screen => ShellManager.showsOn(screen, entry.dock.monitors, entry.dock.monitor)) : []

        delegate: DockWindow {
          required property ShellScreen modelData
          screen: modelData
          dock: entry.dock
        }
      }
    }
  }

  LazyLoader {
    id: preview
    readonly property var screen: Quickshell.screens.find(screen => screen.name === DockManager.previewScreen) ?? null
    active: HyprlandManager.layerRulesReady && DockManager.previewActive && preview.screen !== null

    DockWindow {
      screen: preview.screen
      dock: DockManager.previewDock
      preview: true
    }
  }
}
