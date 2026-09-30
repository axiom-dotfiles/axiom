pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config

// A section's title in the accent, with an optional muted description under
// it (FieldGroup, the theme list)
ColumnLayout {
  id: root

  property string title: ""
  property string description: ""

  Layout.fillWidth: true
  spacing: 2

  StyledText {
    Layout.fillWidth: true
    text: root.title
    textColor: Theme.accent
    textSize: Appearance.fontSize + 1
    font.bold: true
  }

  StyledText {
    visible: root.description !== ""
    Layout.fillWidth: true
    text: root.description
    opacity: 0.7
    textSize: Appearance.fontSize - 2
    wrapMode: Text.WordWrap
  }
}
