pragma ComponentBehavior: Bound
import QtQuick
import qs.components.hosts.overlay

// A view assembled from config: its columns laid out side by side
BaseView {
  id: root

  // viewConfig: { type: "Custom", name, columns: [...] }
  property var columns: root.viewConfig?.columns ?? []
  // Fill cells grow to the tallest column; the page itself doesn't grow
  readonly property real tallest: Math.max(0, ...root.columns.map(column => root.grid.columnFlow(column?.cells).height))

  Repeater {
    model: root.columns

    OverlayColumn {
      required property var modelData
      columnConfig: modelData
      grid: root.grid
      target: ({
          "height": root.tallest
        })
    }
  }
}
