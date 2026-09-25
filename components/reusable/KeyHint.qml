import QtQuick

import qs.config

// A key in a controls hint: a keycap and what it does, e.g. [↵] open
Row {
  id: root

  property string key: ""
  property string label: ""

  spacing: 5

  Rectangle {
    anchors.verticalCenter: parent.verticalCenter
    width: Math.max(height, keyText.implicitWidth + 8)
    height: keyText.implicitHeight + 4
    radius: Appearance.borderRadius / 2
    color: Theme.backgroundAlt
    border.color: Theme.border
    border.width: 1

    StyledText {
      id: keyText
      anchors.centerIn: parent
      text: root.key
      textColor: Theme.foregroundAlt
      textSize: Appearance.fontSize - 4
    }
  }

  StyledText {
    anchors.verticalCenter: parent.verticalCenter
    text: root.label
    textColor: Theme.foregroundInactive
    textSize: Appearance.fontSize - 3
  }
}
