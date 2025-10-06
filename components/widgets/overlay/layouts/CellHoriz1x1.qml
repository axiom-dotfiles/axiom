import QtQuick
import QtQuick.Layouts
import qs.config
Item {
  id: cell
  property alias left: leftContainer.data
  property alias right: rightContainer.data
  implicitWidth: cellLayout.implicitWidth
  implicitHeight: cellLayout.implicitHeight
  GridLayout {
    id: cellLayout
    Layout.preferredHeight: Menu.cardUnit
    Layout.preferredWidth: Menu.cardUnit
    columnSpacing: Menu.cardSpacing
    columns: 2
    rows: 1
    Item {
      id: leftContainer
      Layout.preferredWidth: (Menu.cardUnit - Menu.cardSpacing) / 2
      Layout.preferredHeight: Menu.cardUnit
    }
    Item {
      id: rightContainer
      Layout.preferredWidth: (Menu.cardUnit - Menu.cardSpacing) / 2
      Layout.preferredHeight: Menu.cardUnit
    }
  }
}
