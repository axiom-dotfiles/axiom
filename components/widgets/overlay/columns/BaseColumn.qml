pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config

import qs.components.widgets.common
import qs.components.widgets.overlay.layouts
import qs.components.widgets.overlay.modules

ColumnLayout {
  spacing: Menu.cardSpacing

  property int requiredVerticalCells: topCell.requiredVerticalCells + bottomCell.requiredVerticalCells
  property int requiredHorizontalCells: Math.max(topCell.requiredHorizontalCells, bottomCell.requiredHorizontalCells)

  // Cell2x2 {
  //   id: topCell
  //   topLeftCell: Cpu {}
  //   topRightCell: Gpu {}
  //   bottomLeftCell: Memory {}
  //   bottomRightCell: Storage {}
  // }

  CellVert2x1 {
    id: topCell
    topLeftCell: Cpu {}
    bottomLeftCell: Storage {}
    rightCell: Rectangle {
      anchors.fill: parent
      color: Theme.background
      radius: Menu.cardBorderRadius
      border.color: Theme.foreground
      border.width: 3
      PipewireVolumeBar {
        anchors.centerIn: parent
        targetApplication: "youtube-music"
        orientation: Qt.Vertical
        iconSource: ""
      }
    }
  }

  Cell {
    id: bottomCell
    cell: Media {}
  }
}
