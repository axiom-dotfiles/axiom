import QtQuick
import QtQuick.Layouts
import qs.config
Item {
  id: cell
  property alias top: topContainer.data
  property alias bottom: bottomContainer.data
  implicitWidth: cellLayout.implicitWidth
  implicitHeight: cellLayout.implicitHeight
  GridLayout {
    id: cellLayout
    Layout.preferredHeight: Menu.cardUnit
    Layout.preferredWidth: Menu.cardUnit
    rowSpacing: Menu.cardSpacing
    columns: 1
    rows: 2
    Item {
      id: topContainer
      Layout.preferredWidth: Menu.cardUnit
      Layout.preferredHeight: (Menu.cardUnit - Menu.cardSpacing) / 2
    }
    Item {
      id: bottomContainer
      Layout.preferredWidth: Menu.cardUnit
      Layout.preferredHeight: (Menu.cardUnit - Menu.cardSpacing) / 2
    }
  }
}
