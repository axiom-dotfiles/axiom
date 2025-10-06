pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components.widgets.overlay.layouts
import qs.components.widgets.overlay.modules
import qs.components.widgets.overlay.columns

RowLayout {
  spacing: Menu.cardSpacing

  property int requiredVerticalCells: Math.max(columnOne.requiredVerticalCells, columnTwo.requiredVerticalCells)
  property int requiredHorizontalCells: columnOne.requiredHorizontalCells + columnTwo.requiredHorizontalCells

  ColorsFirst { id: columnOne }
  ColorsSecond { id: columnTwo }
}
