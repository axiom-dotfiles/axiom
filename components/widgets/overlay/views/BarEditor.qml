// BarPreview.qml
pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components.reusable
import qs.components.widgets.bar
import qs.components.widgets.overlay.columns

BaseView {
  id: view
  property var screen

  Rectangle {
    // anchors.fill: parent
    implicitHeight: barPreview.implicitHeight * 0.75
    implicitWidth: 40
    color: Theme.backgroundAlt
    radius: Menu.cardBorderRadius
    // border.color: Theme.foreground
    // border.width: 2

    StandaloneBar {
      id: barPreview
      anchors.centerIn: parent
      barConfig: Bar.bars[0]
      screen: view.screen
      scale: 0.75
      panel: null
      popouts: null
      implicitHeight: view.screen ? view.screen.height : 300
      implicitWidth: barConfig.extent
    }
  }
  BarEditor {
    property var screen: view.screen
    property var barConfigs: Bar.bars
  }
  BarEditor {
    property var screen: view.screen
    property var barConfigs: Bar.bars
  }
}
