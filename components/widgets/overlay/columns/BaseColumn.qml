pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components.widgets.overlay.layouts
import qs.components.widgets.overlay.modules

ColumnLayout {
  spacing: Menu.cardSpacing

  property int requiredVerticalCells: topCell.requiredVerticalCells + bottomCell.requiredVerticalCells
  property int requiredHorizontalCells: Math.max(topCell.requiredHorizontalCells, bottomCell.requiredHorizontalCells)

  Cell2x2 {
    id: topCell
    topLeftCell: Cpu {}
    topRightCell: Gpu {}
    bottomLeftCell: Memory {}
    bottomRightCell: Storage {}
  }

  Cell {
    id: bottomCell
    cell: Media {}
  }
}
