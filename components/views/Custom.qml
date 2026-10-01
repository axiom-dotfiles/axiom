pragma ComponentBehavior: Bound
import QtQuick
import qs.components.hosts.overlay

// A view assembled from config: its modules, each in its place on a grid
// of quarter cards.
BaseView {
  id: root

  // viewConfig: { type: "Custom", name, icon, modules: [...] }
  property var modules: root.viewConfig?.modules ?? []

  ModuleGrid {
    modules: root.modules
    grid: root.grid
  }
}
