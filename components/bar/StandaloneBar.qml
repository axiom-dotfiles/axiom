pragma ComponentBehavior: Bound

import QtQuick

Item {
  id: root

  required property var barConfig

  property var panel: null
  property var screen: null

  property alias barContainer: container

  implicitWidth: barConfig.vertical ? barConfig.extent : 300
  implicitHeight: barConfig.vertical ? 300 : barConfig.extent

  BarContainer {
    id: container
    anchors.fill: parent
    barConfig: root.barConfig
    panel: root.panel
    screen: root.screen
  }
}
