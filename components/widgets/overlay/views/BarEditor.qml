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
    implicitWidth: barPreview.implicitWidth
    implicitHeight: barPreview.implicitHeight * 0.75
    //scale: 0.75
    color: Theme.backgroundAlt
    radius: Menu.cardBorderRadius
    border.color: Theme.border
    border.width: Menu.cardBorderWidth

    StandaloneBar {
      id: barPreview
      anchors.centerIn: parent
      barConfig: Bar.bars[0]
      screen: view.screen
      scale: 0.75
      panel: null
      popouts: null
      implicitHeight: view.screen ? view.screen.height : 300
      Component.onCompleted: {
        console.log("Generating bar preview with config: ", JSON.stringify(barConfig));
      }
    }
  }
}
