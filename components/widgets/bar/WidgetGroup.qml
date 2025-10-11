pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import qs.config

Item {
  id: root

  required property var barConfig
  property var popouts
  property var panel
  property var screen
  property alias model: repeater.model

  property int spacing: root.barConfig.spacing
  property int alignment: Qt.AlignHCenter

  implicitWidth: layout.implicitWidth
  implicitHeight: layout.implicitHeight

  GridLayout {
    id: layout

    columns: root.barConfig.vertical ? 1 : repeater.count
    rows: root.barConfig.vertical ? repeater.count : 1
    columnSpacing: root.barConfig.vertical ? 0 : root.spacing
    rowSpacing: root.barConfig.vertical ? root.spacing : 0

    Repeater {
      id: repeater
      delegate: Loader {
        id: widgetLoader
        Layout.alignment: modelData.alignment || root.alignment
        required property var modelData
        
        // This module handles rotation and sizing
        // allowing the widget definitions to be stupid simple
        sourceComponent: BarModule {
          barConfig: root.barConfig
          properties: widgetLoader.modelData.properties || {}
          componentPath: widgetLoader.modelData.component
          popouts: root.popouts
          panel: root.panel
          screen: root.screen
        }
      }
    }
  }
}
