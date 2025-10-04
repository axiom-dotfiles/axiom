pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import qs.config

Item {
  id: root

  required property bool vertical
  property alias model: repeater.model
  property int spacing: Widget.spacing
  property int alignment: Qt.AlignHCenter

  implicitWidth: layout.implicitWidth
  implicitHeight: layout.implicitHeight

  // Rectangle {
  //   anchors.fill: parent
  //   color: "red"
  // }

  GridLayout {
    id: layout

    columns: root.vertical ? 1 : repeater.count
    rows: root.vertical ? repeater.count : 1
    columnSpacing: root.vertical ? 0 : root.spacing
    rowSpacing: root.vertical ? root.spacing : 0

    Repeater {
      id: repeater
      delegate: Loader {
        id: widgetLoader
        required property var modelData
        source: modelData.component
        
        Layout.alignment: modelData.alignment || root.alignment
        Component.onCompleted: {
          console.log("Created widget with config:", JSON.stringify(modelData));
          // dump anything for debugging
          console.log("modelData:", modelData);
          console.log("modelData.component:", modelData.component);
          console.log("modelData.properties:", modelData.properties);
          console.log("item:", item);
          console.log("loader height:", height, "width:", width);
          
          // widgetLoader.setSource(modelData.component, modelData.properties || {})
        }

        // onLoaded: {
        //   if (item && modelData.properties) {
        //     for (let prop in modelData.properties) {
        //       if (item.hasOwnProperty(prop)) {
        //         item[prop] = modelData.properties[prop];
        //       }
        //     }
        //   }
        // }
      }
    }
  }
}
