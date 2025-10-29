// components/widgets/menu/chat/ChatInput.qml
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls // Added for TextInput.Wrap enum

import Quickshell.Wayland

import qs.services
import qs.config
import qs.components.reusable

RowLayout {
  id: control
  width: parent.width
  spacing: Widget.padding

  property bool wantsKeyboardFocus: textEntry.wantsKeyboardFocus
  property int desiredButtonHeight: 0

  Component.onCompleted: {
    desiredButtonHeight = textEntry.height;
  }

  StyledTextArea {
    id: textEntry
    expandable: true
    Layout.fillWidth: true
    placeholderText: "Type a message or use / for commands..."
    onAccepted: control.submit()
    onTextChanged: {
      Chat.updateCommandState(text)}
    Component.onCompleted: {
      control.wantsKeyboardFocus = true;
    }
  }

  StyledTextButton {
    id: submitButton
    text: "󰆨"

    Layout.preferredHeight: control.desiredButtonHeight
    Layout.preferredWidth: control.desiredButtonHeight
    Layout.alignment: Qt.AlignBottom

    enabled: !Chat.waitingForResponse && textEntry.text.trim().length > 0
    opacity: enabled ? 1.0 : 0.5
    onClicked: control.submit()

    Behavior on opacity { OpacityAnimator { duration: 150 } }
  }

  function focus() {
    root.wantsKeyboardFocus = true;
    textEntry.forceActiveFocus();
  }
  
  function submit() {
    if (!submitButton.enabled) return;
    Chat.sendMessage(textEntry.text);
    textEntry.text = "";
    textEntry.input.forceActiveFocus();
  }
}
