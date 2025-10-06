pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

import qs.config

Item {
  id: cell

  property alias topLeft: topLeftContainer.data
  property alias topRight: topRightContainer.data
  property alias bottomLeft: bottomLeftContainer.data
  property alias bottomRight: bottomRightContainer.data

  implicitWidth: cellLayout.implicitWidth
  implicitHeight: cellLayout.implicitHeight

  GridLayout {
    id: cellLayout
    Layout.preferredHeight: Menu.cardUnit
    Layout.preferredWidth: Menu.cardUnit
    columnSpacing: Menu.cardSpacing
    rowSpacing: Menu.cardSpacing
    columns: 2
    rows: 2

    Item {
      id: topLeftContainer
      Layout.preferredWidth: (Menu.cardUnit - Menu.cardSpacing) / 2
      Layout.preferredHeight: (Menu.cardUnit - Menu.cardSpacing) / 2
    }
    Item {
      id: topRightContainer
      Layout.preferredWidth: (Menu.cardUnit - Menu.cardSpacing) / 2
      Layout.preferredHeight: (Menu.cardUnit - Menu.cardSpacing) / 2
    }
    Item {
      id: bottomLeftContainer
      Layout.preferredWidth: (Menu.cardUnit - Menu.cardSpacing) / 2
      Layout.preferredHeight: (Menu.cardUnit - Menu.cardSpacing) / 2
    }
    Item {
      id: bottomRightContainer
      Layout.preferredWidth: (Menu.cardUnit - Menu.cardSpacing) / 2
      Layout.preferredHeight: (Menu.cardUnit - Menu.cardSpacing) / 2
    }
  }
}
