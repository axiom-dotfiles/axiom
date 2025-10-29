pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config

import qs.components.widgets.overlay.modules.barEditor

ColumnLayout {
  id: root
  spacing: Menu.cardSpacing

  // required property var screen
  property int requiredVerticalCells: 2

  // Component.onCompleted: {
  //   console.log("BarConfig:", JSON.stringify(barConfigs));
  // }

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

