// SchemaSwitch.qml
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components.reusable

RowLayout {
  id: root
  required property string label
  required property bool checked
  property string description: ""

  signal toggled(bool newValue)

  Layout.fillWidth: true
  spacing: Widget.spacing

  StyledText {
    text: root.label
    Layout.fillWidth: true
  }

  StyledSwitch {
    checked: root.checked
    onToggled: root.toggled(checked)
  }

  StyledText {
    visible: root.description !== ""
    text: root.description
    opacity: 0.7
    textSize: Appearance.fontSize - 2
    wrapMode: Text.WordWrap
    Layout.fillWidth: true
    Layout.columnSpan: 2
  }
}
