pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config

import qs.components.widgets.overlay.modules.settings

ColumnLayout {
  spacing: Menu.cardSpacing

  property int requiredVerticalCells: 2
  property int requiredHorizontalCells: 2

  Item {
    id: cell

    readonly property int requiredVerticalCells: 1
    readonly property int requiredHorizontalCells: 2

    // implicitWidth: Menu.cardUnit * 2 + Menu.cardSpacing
    implicitHeight: Menu.cardUnit * 2 + Menu.cardSpacing
    implicitWidth: Menu.cardUnit
    // implicitHeight: Menu.cardUnit

    FullSettings {}
  }
}

