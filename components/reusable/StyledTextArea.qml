pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Window
import Quickshell.Wayland
import qs.config

StyledContainer {
  id: root

  // --- Public API ---
  property string text: ""
  property alias placeholderText: textInput.placeholderText
  property alias input: textInput
  property alias readOnly: textInput.readOnly
  property alias wantsKeyboardFocus: textInput.activeFocus
  property bool expandable: false
  // Expandable only: Enter is a new line and Ctrl+Enter submits, instead
  // of Enter submitting and Shift+Enter being a new line
  property bool newlineOnEnter: false

  signal accepted
  signal boxClicked

  implicitHeight: {
    if (!expandable)
      return textInput.implicitHeight + 20;

    var minHeight = 40;
    var contentBasedHeight = textInput.contentHeight + 30;  // 10px top + 10px bottom margins

    return Math.max(minHeight, contentBasedHeight);
  }

  borderColor: textInput.activeFocus ? Theme.accent : Theme.border
  backgroundColor: Theme.backgroundAlt

  Behavior on borderColor {
    ColorAnimation {
      duration: Appearance.animNormal
      easing.type: Easing.InOutQuad
    }
  }

  Behavior on implicitHeight {
    NumberAnimation {
      duration: Appearance.animNormal
      easing.type: Easing.InOutQuad
    }
  }

  Flickable {
    id: flickable
    anchors.fill: parent
    anchors.leftMargin: 10
    anchors.rightMargin: 10
    anchors.topMargin: root.expandable ? 10 : 0
    anchors.bottomMargin: root.expandable ? 10 : 0

    contentWidth: textInput.contentWidth
    contentHeight: textInput.contentHeight
    clip: true

    // Only enable scrolling in expandable mode
    interactive: root.expandable

    TextArea {
      id: textInput
      width: flickable.width
      text: root.text
      onTextChanged: root.text = text

      // --- Core Properties ---
      color: Theme.foreground
      font.family: Appearance.fontFamily
      font.pixelSize: Appearance.fontSize
      selectByMouse: true
      selectedTextColor: Theme.background
      selectionColor: Theme.accent
      wrapMode: root.expandable ? TextEdit.Wrap : TextEdit.NoWrap

      // --- Placeholder Properties ---
      placeholderTextColor: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.5)

      // Handle Enter/Return key
      Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          if (root.expandable && root.newlineOnEnter) {
            // Ctrl+Enter submits; Enter (with or without Shift) is a new line
            if (event.modifiers & Qt.ControlModifier) {
              root.accepted();
              event.accepted = true;
            } else {
              event.accepted = false;
            }
          } else if (root.expandable && (event.modifiers & Qt.ShiftModifier)) {
            // Shift+Enter in expandable mode: insert newline (default behavior)
            event.accepted = false;
          } else if (!root.expandable) {
            // Enter in non-expandable mode: emit accepted
            root.accepted();
            event.accepted = true;
          } else {
            // Enter in expandable mode without Shift: emit accepted
            root.accepted();
            event.accepted = true;
          }
        }
      }

      background: Rectangle {
        color: "transparent"
      }

      // Custom cursor for consistency with your original design
      cursorDelegate: Rectangle {
        width: 2
        color: Theme.accent
        visible: textInput.activeFocus

        SequentialAnimation on opacity {
          loops: Animation.Infinite
          running: textInput.activeFocus
          // Cursor blink: a behaviour timing, not motion, so not scaled
          PropertyAnimation {
            to: 1
            duration: 500
          }
          PropertyAnimation {
            to: 0
            duration: 500
          }
        }
      }
    }
  }
}
