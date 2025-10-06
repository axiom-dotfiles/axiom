import QtQuick
import QtQuick.Layouts
import qs.config
Item {
  id: cell

  readonly property int requiredVerticalCells: 1
  readonly property int requiredHorizontalCells: 1

  default property alias cell: container.data

  implicitWidth: cellLayout.implicitWidth
  implicitHeight: cellLayout.implicitHeight

  GridLayout {
    id: cellLayout
    Layout.preferredHeight: Menu.cardUnit
    Layout.preferredWidth: Menu.cardUnit
    columns: 1
    rows: 1
    Item {
      id: container
      Layout.preferredWidth: Menu.cardUnit
      Layout.preferredHeight: Menu.cardUnit
      clip: true
    }
  }
}
