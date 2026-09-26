import QtQuick

import qs.config
import qs.components.reusable

// A workspace's number badge on the overview board, drawn over its windows
Rectangle {
  id: root

  property int number: 1
  // The monitor's active workspace
  property bool current: false
  // The cell's corner radius; the badge sits clear of its border (the
  // thicker, active one) and of the corner's curve
  property real cornerRadius: Appearance.borderRadius
  readonly property real _edge: Appearance.borderWidth * 2 + 2
  // Its inset from the cell's corner (placed by OverviewGrid): past the
  // border along the edges, and far enough in that the pill's end circle
  // stays inside the corner's inner arc
  readonly property real margin: {
    const r = height / 2;
    const inner = root.cornerRadius - root._edge;
    const corner = root.cornerRadius - r - (inner - r) / Math.SQRT2;
    return Math.max(root._edge, corner);
  }

  width: Math.max(height, label.implicitWidth + 10)
  height: label.implicitHeight + 4
  radius: height / 2
  color: root.current ? Theme.accent : Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.75)

  StyledText {
    id: label
    anchors.centerIn: parent
    text: root.number
    textSize: Appearance.fontSize - 2
    textColor: root.current ? Theme.background : Theme.foreground
    font.bold: root.current
  }
}
