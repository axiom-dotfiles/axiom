import QtQuick
import QtQuick.Layouts
import qs.config
Item {
  id: cell

  readonly property int requiredVerticalCells: 1
  readonly property int requiredHorizontalCells: 1

  property alias topCell: topContainer.data
  property alias bottomCell: bottomContainer.data

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
      id: topContainer
      Layout.columnSpan: 2
      Layout.preferredWidth: Menu.cardUnit
      Layout.preferredHeight: (Menu.cardUnit - Menu.cardSpacing) / 2
      clip: true
    }
    Item {
      id: bottomContainer
      Layout.columnSpan: 2
      Layout.preferredWidth: Menu.cardUnit
      Layout.preferredHeight: (Menu.cardUnit - Menu.cardSpacing) / 2
      clip: true
    }
  }
}
