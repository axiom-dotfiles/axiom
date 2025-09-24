import QtQuick
import QtQuick.Controls

import qs.components.methods
import qs.config

Item {
  id: root

  property string command: ""
  property string iconName: ""
  property color backgroundColor: Theme.background
  property color hoverColor: "#3a3a4e"
  property color pressedColor: "#4a4a5e"
  property color textColor: "#ffffff"
  property int radius: 10

  implicitWidth: 150
  implicitHeight: 50

  // Execute command when clicked
  onClicked: {
    if (command) {
      Qt.openUrlExternally("file:///usr/bin/env");
      // For actual execution, you might need to use a process launcher
      // This is a placeholder - adjust based on your quickshell setup
      console.log("Executing:", command);
      // You may need to use a Process component from quickshell
    }
  }

  background: Rectangle {
    radius: root.radius
    color: root.pressed ? root.pressedColor : root.hovered ? root.hoverColor : root.backgroundColor

    Behavior on color {
      ColorAnimation {
        duration: 150
      }
    }

    border.color: Qt.lighter(color, 1.2)
    border.width: 1
  }

  contentItem: Row {
    spacing: 8
    anchors.centerIn: parent

    Rectangle {
      visible: root.iconName !== ""
      width: 24
      height: 24
      radius: 4
      color: "transparent"
      border.color: root.textColor
      border.width: 1
      anchors.verticalCenter: parent.verticalCenter

      Text {
        anchors.centerIn: parent
        text: root.iconName ? root.iconName[0] : ""
        color: root.textColor
        font.pixelSize: 14
      }
    }

    Text {
      text: root.text
      color: root.textColor
      font.pixelSize: 14
      font.weight: Font.Medium
      verticalAlignment: Text.AlignVCenter
      anchors.verticalCenter: parent.verticalCenter
    }
  }
}
