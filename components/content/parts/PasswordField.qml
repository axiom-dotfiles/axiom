pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.services
import qs.components.reusable

// The lock screen's password field: what the Password module draws, and
// LockSurface's own when no Password module shows. Only an `active` field
// (the target screen's, on a real lock) talks to AuthManager and holds the
// keyboard; any other is inert, so a preview or a stray copy can't
// authenticate. PAM's messages show under it, and a failure shakes it.
Item {
  id: root

  property bool active: false
  // Shown in the empty field ("" for Enter password...)
  property string placeholder: ""
  property bool centered: true
  // PAM's prompts, failures and errors under the field
  property bool showMessages: true

  implicitHeight: body.implicitHeight

  function takeFocus() {
    if (root.active)
      entry.input.forceActiveFocus();
  }

  Component.onCompleted: {
    if (root.active)
      AuthManager.clearMessage();
    root.takeFocus();
  }
  onActiveChanged: root.takeFocus()

  // Typing always lands here: the lock surface takes every key, and no
  // other lock screen module takes text
  Connections {
    target: root.Window.window
    enabled: root.active

    function onActiveFocusItemChanged() {
      if (!entry.input.activeFocus)
        Qt.callLater(root.takeFocus);
    }
  }

  Connections {
    target: AuthManager
    enabled: root.active

    function onAuthenticationFailed(reason) {
      entry.input.text = "";
      root.takeFocus();
      shake.restart();
    }

    function onAuthenticationError(error) {
      entry.input.text = "";
      root.takeFocus();
    }
  }

  Column {
    id: body
    width: parent.width
    anchors.verticalCenter: parent.verticalCenter
    spacing: Widget.padding / 2

    StyledTextEntry {
      id: entry
      width: parent.width
      height: Widget.height + Widget.padding
      placeholderText: root.placeholder || I18n.tr("Enter password...")
      input.passwordCharacter: "•"
      input.passwordMaskDelay: 0
      input.horizontalAlignment: root.centered ? Text.AlignHCenter : Text.AlignLeft
      readOnly: !root.active
      enabled: !root.active || !AuthManager.isAuthenticating
      // Imperatively: the alias'd TextInput ignores a declarative echoMode
      Component.onCompleted: input.echoMode = TextInput.Password

      // An inert field lets Escape through (the preview closes on it)
      Keys.onEscapePressed: event => {
        if (!root.active) {
          event.accepted = false;
          return;
        }
        input.text = "";
        AuthManager.clearMessage();
      }

      Keys.onPressed: event => {
        if (event.key === Qt.Key_C && event.modifiers & Qt.ControlModifier) {
          input.text = "";
          AuthManager.clearMessage();
          event.accepted = true;
        }
      }

      onAccepted: {
        if (root.active && input.text.length > 0 && !AuthManager.isAuthenticating) {
          AuthManager.authenticate(input.text);
          input.text = "";
        }
      }
    }

    StyledText {
      width: parent.width
      visible: root.active && root.showMessages && AuthManager.message !== ""
      text: AuthManager.message
      textColor: AuthManager.messageIsError ? Theme.error : Theme.foregroundAlt
      textSize: Appearance.fontSize - 2
      horizontalAlignment: root.centered ? Text.AlignHCenter : Text.AlignLeft
      elide: Text.ElideRight
    }

    // While PAM is checking
    Item {
      width: parent.width
      height: 4
      visible: root.active && AuthManager.isAuthenticating

      StyledContainer {
        width: parent.width * 0.3
        height: parent.height
        backgroundColor: Theme.accent

        SequentialAnimation on x {
          loops: Animation.Infinite
          running: root.active && AuthManager.isAuthenticating && Appearance.animations

          NumberAnimation {
            from: 0
            to: root.width * 0.7
            duration: Appearance.animSlow * 3
            easing.type: Easing.InOutQuad
          }
          NumberAnimation {
            from: root.width * 0.7
            to: 0
            duration: Appearance.animSlow * 3
            easing.type: Easing.InOutQuad
          }
        }
      }
    }
  }

  SequentialAnimation {
    id: shake

    NumberAnimation {
      target: body
      property: "x"
      to: 20
      duration: Appearance.animFast
    }
    NumberAnimation {
      target: body
      property: "x"
      to: -20
      duration: Appearance.animFast
    }
    NumberAnimation {
      target: body
      property: "x"
      to: 20
      duration: Appearance.animFast
    }
    NumberAnimation {
      target: body
      property: "x"
      to: 0
      duration: Appearance.animFast
    }
  }
}
