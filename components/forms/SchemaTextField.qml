pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components.reusable

// i18n: keys from callers and the schema (titles, descriptions, type labels)
ColumnLayout {
  id: root
  required property string label
  required property string currentConfigValue
  property string value: root.currentConfigValue
  property string placeholderText: ""
  property string description: ""
  property var pattern: null
  property int minLength: 0
  property int maxLength: 999
  // A growing text area (`x-multiline`), e.g. for a system prompt
  property bool multiline: false

  onCurrentConfigValueChanged: {
    if (textEntry.text !== root.currentConfigValue)
      textEntry.text = root.currentConfigValue;
    if (textArea.text !== root.currentConfigValue)
      textArea.text = root.currentConfigValue;
  }

  function _accept(text) {
    if (text.length >= root.minLength && text.length <= root.maxLength) {
      if (root.pattern === null || new RegExp(root.pattern).test(text)) {
        root.value = text;
      }
    }
  }

  Layout.fillWidth: true
  spacing: 4

  StyledText {
    text: I18n.tr(root.label)
    Layout.fillWidth: true
  }

  StyledTextEntry {
    id: textEntry
    visible: !root.multiline
    Layout.fillWidth: true
    Layout.preferredHeight: Widget.height
    text: root.currentConfigValue
    placeholderText: root.placeholderText

    input.onTextChanged: root._accept(input.text)
  }

  StyledTextArea {
    id: textArea
    visible: root.multiline
    Layout.fillWidth: true
    expandable: true
    // Enter is a new line here: nothing to submit
    newlineOnEnter: true
    text: root.currentConfigValue
    placeholderText: root.placeholderText

    input.onTextChanged: {
      if (root.multiline)
        root._accept(input.text);
    }
  }

  StyledText {
    visible: root.description !== ""
    text: I18n.tr(root.description)
    opacity: 0.7
    textSize: Appearance.fontSize - 2
    wrapMode: Text.WordWrap
    Layout.fillWidth: true
  }
}
