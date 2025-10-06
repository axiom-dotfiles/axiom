import QtQuick
import QtQuick.Layouts
import qs.config
Item {
  id: cell
  default property alias content: container.data
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
    }
  }
}
