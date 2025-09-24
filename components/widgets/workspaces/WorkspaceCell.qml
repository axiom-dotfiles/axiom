import QtQuick
import QtQuick.Layouts
import Quickshell

import qs.services
import qs.config

Rectangle {
  id: root

  // Colors
  property color cellBgColor: Theme.base00
  property color cellBgHoverColor: Theme.base01
  property color cellBgDragColor: Theme.base02
  property color cellBorderColor: Theme.border
  property color cellBorderActiveColor: Theme.accent
  property color cellTextColor: Theme.foreground

  // Animation properties
  property int colorAnimationDuration: 150
  property int borderAnimationDuration: 150

  // Core properties
  property int workspaceId: 1
  property bool isActive: false
  property real scale: 0.15

  signal clicked

  color: cellBgColor
  radius: 4
  border.width: isActive ? 3 : 1
  border.color: isActive ? cellBorderActiveColor : cellBorderColor

  Behavior on border.color {
    ColorAnimation {
      duration: root.borderAnimationDuration
    }
  }

  Behavior on border.width {
    NumberAnimation {
      duration: root.borderAnimationDuration
    }
  }

  // Optional workspace number label (uncomment if needed)
  /*
  Text {
    anchors.centerIn: parent
    text: root.workspaceId.toString()
    font.family: "VictorMono Nerd Font"
    font.pixelSize: Math.min(root.width, root.height) * 0.3
    font.weight: Font.Bold
    color: root.cellTextColor
    opacity: 0.3
  }
  */

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    onClicked: {
      root.clicked();
    }
  }

  // Drop area for windows
  DropArea {
    id: dropArea
    anchors.fill: parent
    property bool containsDrag: false

    onEntered: {
      containsDrag = true;
      root.color = root.cellBgDragColor;
    }

    onExited: {
      containsDrag = false;
      root.color = root.cellBgColor;
    }

    onDropped: {
      containsDrag = false;
      root.color = root.cellBgColor;
    }
  }

  states: [
    State {
      name: "hovered"
      when: mouseArea.containsMouse && !dropArea.containsDrag
      PropertyChanges {
        target: root
        color: root.cellBgHoverColor
      }
    },
    State {
      name: "dragging"
      when: dropArea.containsDrag
      PropertyChanges {
        target: root
        color: root.cellBgDragColor
        border.color: root.cellBorderActiveColor
      }
    }
  ]

  transitions: Transition {
    ColorAnimation {
      properties: "color"
      duration: root.colorAnimationDuration
    }
  }
}
