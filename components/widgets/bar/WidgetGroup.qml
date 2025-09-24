pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import qs.config

Item {
  id: root

  property bool vertical: Bar.vertical
  property alias model: repeater.model
  property int spacing: Widget.spacing
  property int alignment: Qt.AlignHCenter

  implicitWidth: layout.implicitWidth
  implicitHeight: layout.implicitHeight

  GridLayout {
    id: layout

    columns: root.vertical ? 1 : repeater.count
    rows: root.vertical ? repeater.count : 1
    columnSpacing: root.vertical ? 0 : root.spacing
    rowSpacing: root.vertical ? root.spacing : 0

    Repeater {
      id: repeater
      delegate: Loader {
        required property var modelData

        sourceComponent: modelData.component
        Layout.alignment: modelData.alignment || root.alignment

        onLoaded: {
          if (item && modelData.properties) {
            for (let prop in modelData.properties) {
              if (item.hasOwnProperty(prop)) {
                item[prop] = modelData.properties[prop];
              }
            }
          }
        }
      }
    }
  }
}
