pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components.reusable

ColumnLayout {
  id: root
  required property string label
  required property string value
  property string placeholderText: ""
  property string description: ""
  property var pattern: null
  property int minLength: 0
  property int maxLength: 999

  Layout.fillWidth: true
  spacing: 4

  StyledText {
    text: root.label
    Layout.fillWidth: true
  }

  StyledTextEntry {
    Layout.fillWidth: true
    Layout.preferredHeight: Widget.height
    text: root.value
    placeholderText: root.placeholderText

    input.onTextChanged: {
      if (input.text.length >= root.minLength && input.text.length <= root.maxLength) {
        if (root.pattern === null || new RegExp(root.pattern).test(input.text)) {
          root.valueChanged();
        }
      }
    }
  }

  StyledText {
    visible: root.description !== ""
    text: root.description
    opacity: 0.7
    textSize: Appearance.fontSize - 2
    wrapMode: Text.WordWrap
    Layout.fillWidth: true
  }
}
