import QtQuick
import Quickshell.Wayland

import qs.services
import qs.config

Rectangle {
  id: root

  // Colors
  property color bgColor: Theme.backgroundAlt
  property color borderColor: Theme.border
  property color borderActiveColor: Theme.accent
  property color borderHoverColor: Theme.accentAlt
  property color textColor: Theme.foreground
  property color xwaylandIndicatorColor: Theme.accentAlt

  // Window data
  property var windowData: null
  property var toplevel: null
  property string iconPath: ""
  property string windowTitle: windowData?.title ?? windowData?.class ?? "Unknown"

  // Display properties
  property real windowOpacity: 0.9
  property real borderWidth: 2
  property real borderRadius: 4
  property bool showScreencopy: true
  property bool showIcon: true
  property bool showTitle: true
  property bool isActive: false
  property bool isHovered: false
  property bool isXwayland: windowData?.xwayland ?? false

  color: bgColor
  radius: borderRadius
  border.width: borderWidth
  border.color: isActive ? borderActiveColor : (isHovered ? borderHoverColor : borderColor)
  opacity: windowOpacity
  clip: true

  ScreencopyView {
    id: screencopy
    anchors.fill: parent
    anchors.margins: root.borderWidth
    captureSource: root.toplevel
    visible: root.showScreencopy && captureSource !== null
  }

  Column {
    anchors.centerIn: parent
    spacing: 4
    visible: !screencopy.visible || root.showIcon

    Image {
      id: windowIcon
      source: root.iconPath
      width: Math.min(parent.parent.width * 0.4, 50)
      height: width
      fillMode: Image.PreserveAspectFit
      smooth: true
      anchors.horizontalCenter: parent.horizontalCenter
      visible: true
    }

    Text {
      text: root.windowTitle
      font.family: "VictorMono Nerd Font"
      font.pixelSize: 10
      color: root.textColor
      opacity: 1
      width: root.width - 8
      elide: Text.ElideRight
      horizontalAlignment: Text.AlignHCenter
      visible: root.showTitle
    }
  }

  Rectangle {
    visible: root.isXwayland && !screencopy.visible
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.margins: 4
    width: 16
    height: 16
    radius: 8
    color: root.xwaylandIndicatorColor
    opacity: 0.5

    Text {
      anchors.centerIn: parent
      text: "X"
      font.family: "VictorMono Nerd Font"
      font.pixelSize: 10
      font.bold: true
      color: Theme.backgroundAlt
    }
  }
}
