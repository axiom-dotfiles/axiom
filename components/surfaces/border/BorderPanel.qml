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
  // The frame's own colour, for the ends of a strip whose frameColor is
  // transparent (see endFills)
  required property color endFillColor
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

  // On a solid bar's edge the strip is transparent, but a strip that runs
  // into the corners (the first mapped of two that meet) also owns the
  // stroke's row past the bar there, outside the corner piece: fill it
  Repeater {
    model: root.frameColor.a < 1 ? [true, false] : []

    delegate: Rectangle {
      required property bool modelData
      readonly property bool atStart: modelData
      readonly property int along: root.frameWidth - root.strokeWidth
      color: root.endFillColor
      width: root.horizontal ? along : root.strokeWidth
      height: root.horizontal ? root.strokeWidth : along
      x: root.horizontal ? (atStart ? 0 : parent.width - width) : (root.edge === "left" ? along : 0)
      y: root.horizontal ? (root.edge === "top" ? along : 0) : (atStart ? 0 : parent.height - height)
    }
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
