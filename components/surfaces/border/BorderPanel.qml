pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland

// One edge of the screen border (RoundedBorders): a strip that reserves
// `frameWidth` and draws the frame with its inner stroke, which stops short
// of the corners by `innerBorderRadius` where the corner pieces take over.
// Input passes through it.
PanelWindow {
  id: root

  // "top" | "bottom" | "left" | "right"
  required property string edge
  required property int frameWidth
  required property int innerBorderRadius
  required property color frameColor
  required property color innerStrokeColor
  required property int strokeWidth

  readonly property bool horizontal: edge === "top" || edge === "bottom"

  anchors {
    left: root.edge !== "right"
    right: root.edge !== "left"
    top: root.edge !== "bottom"
    bottom: root.edge !== "top"
  }

  implicitWidth: root.horizontal ? 0 : root.frameWidth
  implicitHeight: root.horizontal ? root.frameWidth : 0

  exclusiveZone: root.frameWidth
  aboveWindows: true
  WlrLayershell.namespace: "axiom-border"
  color: "transparent"
  mask: Region {}

  Rectangle {
    anchors.fill: parent
    color: root.frameColor
  }

  // The inner stroke, on the strip's screen-facing side
  Rectangle {
    color: root.innerStrokeColor

    anchors {
      left: root.horizontal ? parent.left : undefined
      right: root.horizontal ? parent.right : undefined
      leftMargin: root.frameWidth + root.innerBorderRadius
      rightMargin: root.frameWidth + root.innerBorderRadius

      top: root.horizontal ? undefined : parent.top
      bottom: root.horizontal ? undefined : parent.bottom
      topMargin: root.innerBorderRadius
      bottomMargin: root.innerBorderRadius
    }

    x: root.edge === "left" ? root.frameWidth - root.strokeWidth : 0
    y: root.edge === "top" ? root.frameWidth - root.strokeWidth : 0
    // Across the strip; the anchors stretch it along
    implicitWidth: root.strokeWidth
    implicitHeight: root.strokeWidth
  }
}
