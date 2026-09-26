pragma ComponentBehavior: Bound
import QtQuick
import qs.config

// One column of a Custom view: its cells flow left to right, wrapping at
// the widest cell, so smaller cells can sit side by side under a wide one
// (OverlayConfig.columnFlow computes the same arrangement for the editor)
Item {
  id: root

  // { cells: [...] }
  required property var columnConfig
  required property OverlayGrid grid
  // Where the modules are shown, handed to each as `host`
  property var host: ({
      "kind": "overlay"
    })

  implicitWidth: root.grid.columnFlow(root.columnConfig.cells).width
  implicitHeight: flow.implicitHeight

  Flow {
    id: flow
    width: root.implicitWidth
    spacing: OverlayConfig.cardSpacing

    Repeater {
      model: root.columnConfig.cells ?? []

      OverlayCell {
        required property var modelData
        cellConfig: modelData
        grid: root.grid
        host: root.host
      }
    }
  }
}
