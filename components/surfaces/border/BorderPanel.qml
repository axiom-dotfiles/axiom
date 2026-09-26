import QtQuick
import Quickshell

PanelWindow {
  id: root
  required property string edge // "top", "bottom", "left", "right"
  required property int frameWidth
  required property int innerBorderRadius
  required property color frameColor
  required property color innerStrokeColor
  required property int strokeWidth

  Component.onCompleted: {}

  property int inset: innerBorderRadius
  property bool isHorizontal: edge === "top" || edge === "bottom"
  property bool isVertical: edge === "left" || edge === "right"

  anchors {
    left: edge === "left" || edge === "top" || edge === "bottom"
    right: edge === "right" || edge === "top" || edge === "bottom"
    top: edge === "top" || edge === "left" || edge === "right"
    bottom: edge === "bottom" || edge === "left" || edge === "right"
  }

  implicitWidth: isVertical ? frameWidth : 0
  implicitHeight: isHorizontal ? frameWidth : 0

  exclusiveZone: frameWidth
  aboveWindows: true
  // WlrLayershell.layer: WlrLayer.Overlay
  color: "transparent"
  mask: Region {}

  Rectangle {
    anchors.fill: parent
    color: root.frameColor
  }

  Rectangle {
    color: root.innerStrokeColor

    anchors {
      left: root.isHorizontal ? parent.left : undefined
      right: root.isHorizontal ? parent.right : undefined
      leftMargin: root.isHorizontal ? (root.frameWidth + root.inset) : 0
      rightMargin: root.isHorizontal ? (root.frameWidth + root.inset) : 0

      top: root.isVertical ? parent.top : undefined
      bottom: root.isVertical ? parent.bottom : undefined
      topMargin: root.isVertical ? root.inset : 0
      bottomMargin: root.isVertical ? root.inset : 0
    }

    x: root.edge === "left" ? (root.frameWidth - root.strokeWidth) : (root.isVertical ? 0 : null)
    y: root.edge === "top" ? (root.frameWidth - root.strokeWidth) : (root.isHorizontal ? 0 : null)

    implicitWidth: root.isVertical ? root.strokeWidth : (parent.width - (root.frameWidth + root.inset))
    implicitHeight: root.isHorizontal ? root.strokeWidth : (parent.height - root.inset)
  }
}
