
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

import qs.config

Item {
  id: cell

  readonly property int requiredVerticalCells: 1
  readonly property int requiredHorizontalCells: 2

  property alias topCell: topContainer.data
  property alias bottomleftCell: bottomLeftContainer.data
  property alias bottomRightCell: bottomRightContainer.data

  implicitWidth: cellLayout.implicitWidth
  implicitHeight: cellLayout.implicitHeight

  GridLayout {
    id: cellLayout
    Layout.preferredHeight: Menu.cardUnit
    Layout.preferredWidth: Menu.cardUnit * 2 + Menu.cardSpacing
    columnSpacing: Menu.cardSpacing
    rowSpacing: Menu.cardSpacing
    columns: 2
    rows: 2

    Item {
      id: topContainer
      Layout.columnSpan: 2
      Layout.preferredWidth: Menu.cardUnit * 2 + Menu.cardSpacing
      Layout.preferredHeight: (Menu.cardUnit - Menu.cardSpacing) * 2 + Menu.cardSpacing
    }
    Item {
      id: bottomLeftContainer
      Layout.preferredWidth: (Menu.cardUnit - Menu.cardSpacing)
      Layout.preferredHeight: (Menu.cardUnit - Menu.cardSpacing)
    }
    Item {
      id: bottomRightContainer
      Layout.preferredWidth: (Menu.cardUnit - Menu.cardSpacing)
      Layout.preferredHeight: (Menu.cardUnit - Menu.cardSpacing)
    }
  }
}

