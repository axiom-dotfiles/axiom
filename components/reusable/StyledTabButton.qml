// qs/components/reusable/StyledTabButton.qml
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import qs.config

TabButton {
  id: button

  property color activeColor: Theme.accent
  property color inactiveColor: Theme.foregroundAlt

  Layout.fillWidth: true
  Layout.fillHeight: true

  contentItem: Text {
    text: button.text
    font.family: Appearance.fontFamily
    font.pixelSize: Appearance.fontSize - 2
    color: button.checked ? button.activeColor : Theme.foregroundAlt
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
  }

  Behavior on width {
    NumberAnimation {
      duration: 150
    }
  }

  background: Rectangle {
    color: button.checked ? Theme.backgroundHighlight : "transparent"
    radius: Appearance.borderRadius

    Rectangle {
      anchors.bottom: parent.bottom
      anchors.horizontalCenter: parent.horizontalCenter
      width: parent.width * 0.8
      height: 2
      color: button.activeColor
      visible: button.checked
      radius: 1
      Behavior on width {
        NumberAnimation {
          duration: 150
        }
      }
    }

    // Behavior on color {
    //     ColorAnimation { duration: 150 }
    // }

    Behavior on width {
      NumberAnimation {
        duration: 150
      }
    }

    Behavior on height {
      NumberAnimation {
        duration: 150
      }
    }
  }
}
