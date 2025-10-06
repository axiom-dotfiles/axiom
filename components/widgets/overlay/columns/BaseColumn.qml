pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components.widgets.overlay.layouts
import qs.components.widgets.overlay.modules

ColumnLayout {
  spacing: Menu.cardSpacing
  Cell2x2 {
    topLeftCell: Cpu {}
    topRightCell: Gpu {}
    bottomLeftCell: Memory {}
    bottomRightCell: Storage {}
  }

  // CellVert1x1 {
  //   rightCell: Rectangle {
  //     color: Theme.accent
  //     anchors.fill: parent
  //     radius: Appearance.borderRadius
  //   }
  //   leftCell: Rectangle {
  //     color: Theme.accentAlt
  //     anchors.fill: parent
  //     radius: Appearance.borderRadius
  //   }
  // }

  // CellHoriz2x1 {
  //   topLeft: Rectangle {
  //     color: Theme.accent
  //     anchors.fill: parent
  //     radius: Appearance.borderRadius
  //   }
  //   topRight: Rectangle {
  //     color: Theme.accent
  //     anchors.fill: parent
  //     radius: Appearance.borderRadius
  //   }
  //   bottomCell: Rectangle {
  //     color: Theme.accentAlt
  //     anchors.fill: parent
  //     radius: Appearance.borderRadius
  //   }
  // }

  Cell {
    cell: Media {}
  }
}
