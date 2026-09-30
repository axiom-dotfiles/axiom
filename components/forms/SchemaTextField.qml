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
  property string description: ""
  property var pattern: null
  // A growing text area (`x-multiline`), e.g. for a system prompt
  property bool multiline: false
  // Values offered as chips under the field (`x-suggestions`); a click
  // puts one in the field, or adds it to a comma-separated list
  property var suggestions: []
  property bool commaList: false

  onCurrentConfigValueChanged: {
    if (textEntry.text !== root.currentConfigValue)
      textEntry.text = root.currentConfigValue;
    if (textArea.text !== root.currentConfigValue)
      textArea.text = root.currentConfigValue;
  }

  function _accept(text) {
    if (root.pattern === null || new RegExp(root.pattern).test(text))
      root.value = text;
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

    input.onTextChanged: {
      if (root.multiline)
        root._accept(input.text);
    }
  }

  Flow {
    visible: !root.multiline && root.suggestions.length > 0
    Layout.fillWidth: true
    spacing: Widget.spacing / 2

    Repeater {
      model: root.multiline ? [] : root.suggestions

      delegate: StyledTextButton {
        required property string modelData
        implicitHeight: Widget.height - 8
        text: modelData
        onClicked: {
          if (!root.commaList) {
            textEntry.text = modelData;
            return;
          }
          const items = textEntry.text.split(",").map(v => v.trim()).filter(v => v !== "");
          if (!items.includes(modelData))
            textEntry.text = items.concat([modelData]).join(", ");
        }
      }
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
