pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components.reusable

// A large value with its unit, and a small label underneath
ColumnLayout {
  id: root

  property string value: ""
  property string unit: ""
  property string label: ""
  property color valueColor: Theme.foreground
  property int valueSize: Appearance.fontSize * 2

  spacing: 0

  RowLayout {
    spacing: 2
    StyledText {
      text: root.value
      textColor: root.valueColor
      textSize: root.valueSize
      font.bold: true
    }
    StyledText {
      visible: root.unit !== ""
      Layout.alignment: Qt.AlignBaseline
      text: root.unit
      opacity: 0.7
    }
  }

  StyledText {
    visible: root.label !== ""
    Layout.fillWidth: true
    text: root.label
    elide: Text.ElideRight
    textSize: Appearance.fontSize - 2
    opacity: 0.6
  }
}
