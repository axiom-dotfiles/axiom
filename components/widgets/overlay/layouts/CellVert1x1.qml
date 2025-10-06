import QtQuick
import QtQuick.Layouts
import qs.config
Item {
  id: cell

  readonly property int requiredVerticalCells: 1
  readonly property int requiredHorizontalCells: 1

  property alias leftCell: leftContainer.data
  property alias rightCell: rightContainer.data

  implicitWidth: cellLayout.implicitWidth
  implicitHeight: cellLayout.implicitHeight

  GridLayout {
    id: cellLayout
    Layout.preferredHeight: Menu.cardUnit
    Layout.preferredWidth: Menu.cardUnit
    columnSpacing: Menu.cardSpacing
    columns: 2
    rows: 2
    Item {
      id: leftContainer
      Layout.rowSpan: 2
      Layout.preferredWidth: (Menu.cardUnit - Menu.cardSpacing) / 2
      Layout.preferredHeight: Menu.cardUnit
      clip: true
    }
    Item {
      id: rightContainer
      Layout.rowSpan: 2
      Layout.preferredWidth: (Menu.cardUnit - Menu.cardSpacing) / 2
      Layout.preferredHeight: Menu.cardUnit
      clip: true
    }
  }
}

