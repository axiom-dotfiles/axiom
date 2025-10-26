pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config

import qs.components.widgets.overlay.modules.barEditor

ColumnLayout {
  spacing: Menu.cardSpacing

  // required property var screen
  // required property var barConfigs
  property int requiredVerticalCells: 2

  Item {
    id: cell

    implicitHeight: screen.height * 0.75
    implicitWidth: Menu.cardUnit

    BarConfig {
      id: barConfig
      barConfigs: barConfigs
      screen: screen
    }
  }
}

