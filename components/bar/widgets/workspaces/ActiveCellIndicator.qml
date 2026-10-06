pragma ComponentBehavior: Bound
import QtQuick

import qs.config

// The active workspace's box (or underline) in a bar switcher's row of
// cells, drawn once under them and sliding from cell to cell as the
// active workspace changes, where the cells would each recolour. The
// cells it stands in for leave theirs out (WorkspaceCell's `indicated`).
// Placed by the active cell's index, as every cell before it is at its
// rest length.
Item {
  id: root

  required property var barConfig
  // Bar.cellColors for the active state
  required property var look
  // The active cell's index in the row, or -1 when none shows
  required property int index
  required property real thickness
  required property real restLength
  // The active cell's length (twice the rest with `wideActive`)
  required property real activeLength
  required property real spacing
  property real radius: 0

  readonly property bool isVertical: barConfig.vertical
  readonly property bool boxed: ["filled", "tinted", "outline"].includes(barConfig.widgetStyle)
  // Whether there's anything to slide: a box, or an underline
  readonly property bool slides: boxed || barConfig.widgetStyle === "underline"
  readonly property real _along: Math.max(0, index) * (restLength + spacing)

  // Slides only between cells, never in from the start when it first shows
  property bool _placed: false
  onIndexChanged: {
    if (index < 0)
      _placed = false;
    else
      Qt.callLater(() => root._placed = root.index >= 0);
  }
  Component.onCompleted: Qt.callLater(() => root._placed = root.index >= 0)

  visible: slides && index >= 0
  x: isVertical ? 0 : _along
  y: isVertical ? _along : 0
  width: isVertical ? thickness : activeLength
  height: isVertical ? activeLength : thickness

  Behavior on x {
    enabled: root._placed
    NumberAnimation {
      duration: Appearance.animNormal
      easing.type: Appearance.easing
    }
  }
  Behavior on y {
    enabled: root._placed
    NumberAnimation {
      duration: Appearance.animNormal
      easing.type: Appearance.easing
    }
  }

  Rectangle {
    anchors.fill: parent
    visible: root.boxed
    radius: root.radius
    color: root.look.fill
    border.color: root.look.stroke
    border.width: root.barConfig.widgetStyle === "outline" ? root.barConfig.outlineWidth : 0
  }

  // As WorkspaceCell's underline
  Rectangle {
    readonly property real lineWidth: root.barConfig.lineWidth
    readonly property bool farSide: (root.barConfig.lineSide === "inner") !== (root.barConfig.right || root.barConfig.bottom)

    visible: root.barConfig.widgetStyle === "underline"
    color: root.look.indicator
    radius: lineWidth / 2
    x: root.isVertical && farSide ? root.width - lineWidth : 0
    y: !root.isVertical && farSide ? root.height - lineWidth : 0
    width: root.isVertical ? lineWidth : root.width
    height: root.isVertical ? root.height : lineWidth
  }
}
