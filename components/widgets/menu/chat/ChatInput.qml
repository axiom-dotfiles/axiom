// components/widgets/menu/chat/ChatInput.qml
import QtQuick
import QtQuick.Layouts

import Quickshell.Wayland

import qs.services
import qs.components.reusable

RowLayout {
  id: control
  width: parent.width
  spacing: 10

  property bool wantsKeyboardFocus: textEntry.wantsKeyboardFocus

  StyledTextEntry {
    id: textEntry
    Layout.fillWidth: true
    placeholderText: "Type a message or use / for commands..."
    onAccepted: control.submit()
    onTextChanged: {
      Chat.updateCommandState(text)}
  }

  StyledTextButton {
    id: submitButton
    text: "🤓"
    enabled: !Chat.waitingForResponse && textEntry.text.trim().length > 0
    opacity: enabled ? 1.0 : 0.5
    onClicked: control.submit()

    Behavior on opacity { OpacityAnimator { duration: 150 } }
  }

  function submit() {
    if (!submitButton.enabled) return;
    Chat.sendMessage(textEntry.text);
    textEntry.text = "";
    textEntry.forceActiveFocus();
  }
}
