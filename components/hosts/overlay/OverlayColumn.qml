pragma ComponentBehavior: Bound
import QtQuick
import qs.config

// One column of a Custom view (or an edge menu): its cells flow left to
// right, wrapping at the widest cell, so smaller cells can sit side by side
// under a wide one. Placed from OverlayConfig.columnFlow, which the editor
// uses too.
Item {
  id: root

  // { cells: [...] }
  required property var columnConfig
  required property OverlayGrid grid
  // Where the modules are shown, handed to each as `host`
  property var host: ({
      "kind": "overlay"
    })

  // Room for fill cells to grow into ({ width, height }, see
  // OverlayConfig.columnFlow); null keeps every cell its own size
  property var target: null

  readonly property var flow: root.grid.columnFlow(root.columnConfig.cells, root.target)

  implicitWidth: root.flow.width
  implicitHeight: root.flow.height

  Repeater {
    model: root.columnConfig.cells ?? []

    OverlayCell {
      required property var modelData
      required property int index
      readonly property var rect: root.flow.rects[index] ?? null
      cellConfig: modelData
      grid: root.grid
      host: root.host
      x: rect?.x ?? 0
      y: rect?.y ?? 0
      width: rect?.width ?? implicitWidth
      height: rect?.height ?? implicitHeight
    }
  }
}
