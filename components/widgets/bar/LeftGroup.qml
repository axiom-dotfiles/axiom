pragma ComponentBehavior: Bound

import QtQuick

import qs.services
import qs.config
import qs.components.widgets.bar.modules as Widgets

WidgetGroup {
  id: root

  property var screen
  property bool showMedia: false

  model: [
    {
      component: windowComponent,
      properties: {
        orientation: Bar.vertical ? Qt.Vertical : Qt.Horizontal
      }
    }
  ]

  Component {
    id: windowComponent
    Widgets.Window {
      property int orientation: Qt.Horizontal
    }
  }
}
