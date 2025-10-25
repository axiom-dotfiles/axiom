// BarPreview.qml
pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components.reusable
import qs.components.widgets.bar
import qs.components.widgets.overlay.columns

BaseView {
  id: view

  Rectangle {
    implicitWidth: barPreview.implicitWidth + 40
    implicitHeight: barPreview.implicitHeight + 40
    color: Theme.backgroundAlt
    radius: Menu.cardBorderRadius
    border.color: Theme.border
    border.width: Menu.cardBorderWidth

    StandaloneBar {
      id: barPreview
      anchors.centerIn: parent
      barConfig: Bar.bars[0]
      screen: view.screen
      Component.onCompleted: {
        console.log("Generating bar preview with config: ", JSON.stringify(barConfig));
      }
    }
  }
}
