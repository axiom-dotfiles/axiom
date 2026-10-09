pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.components.hosts.overlay

// A view assembled from config: its modules, each in its place on a grid
// of quarter cards (eighths with a double grid, `fineGrid`: laid out at
// its card size, OverlayConfig.pageUnit).
BaseView {
  id: root

  // viewConfig: { type: "Custom", name, icon, fineGrid, modules: [...] }
  property var modules: root.viewConfig?.modules ?? []

  property OverlayGrid fineGrid: OverlayGrid {
    availableWidth: root.grid?.availableWidth ?? 0
    availableHeight: root.grid?.availableHeight ?? 0
    fixedUnit: OverlayConfig.pageUnit(root.viewConfig, root.grid?.unit ?? 0)
  }

  ModuleGrid {
    modules: root.modules
    grid: root.viewConfig?.fineGrid ? root.fineGrid : root.grid
  }
}
