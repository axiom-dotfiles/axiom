pragma ComponentBehavior: Bound
import QtQuick
import qs.components.hosts.overlay

// A view assembled from config: its modules, each in its place on a grid
// of quarter cards. With `stretch` the grid grows to fill the overlay.
BaseView {
  id: root

  // viewConfig: { type: "Custom", name, stretch, modules: [...] }
  property var modules: root.viewConfig?.modules ?? []
  property bool stretch: root.viewConfig?.stretch ?? false

  ModuleGrid {
    modules: root.modules
    grid: root.grid
    stretch: root.stretch ? {
      "width": root.grid.availableWidth,
      "height": root.grid.availableHeight
    } : null
  }
}
