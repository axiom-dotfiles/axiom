pragma ComponentBehavior: Bound
import QtQuick
import qs.config

// A small pill holding a count (or any short label), for a button's or
// an icon's corner: StyledRectButton's badge, the notification bell's
Rectangle {
  id: root

  property string text: ""
  property color textColor: Theme.background

  implicitWidth: Math.max(14, label.implicitWidth + 6)
  implicitHeight: 14
  radius: height / 2
  color: Theme.error

  StyledText {
    id: label
    anchors.centerIn: parent
    text: root.text
    textSize: Appearance.fontSize - 4
    textColor: root.textColor
  }
}
