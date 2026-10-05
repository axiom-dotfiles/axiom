pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.config

// A password field with what an authenticator shows under it: a message,
// a sliding bar while it checks, and a shake when it fails. It knows no
// authenticator: the lock screen's PasswordField and the polkit prompt
// wire it to theirs (`accepted`, `shake()`).
Item {
  id: root

  // The TextInput, for focus and text
  readonly property TextField input: entry.input
  property string placeholder: ""
  property bool centered: true
  property bool readOnly: false
  // Shows what's typed instead of dots
  property bool reveal: false
  property string message: ""
  property bool messageIsError: false
  property bool wrapMessage: false
  // Checking: the sliding bar shows
  property bool busy: false
  // The field's own height (the greeter's login box shrinks it to a short
  // slot)
  property real fieldHeight: Widget.height + Widget.padding

  signal accepted

  implicitHeight: body.implicitHeight

  function shake() {
    shakeAnimation.restart();
  }

  Column {
    id: body
    width: parent.width
    anchors.verticalCenter: parent.verticalCenter
    spacing: Widget.padding / 2

    StyledTextEntry {
      id: entry
      width: parent.width
      height: root.fieldHeight
      placeholderText: root.placeholder
      input.passwordCharacter: "•"
      input.passwordMaskDelay: 0
      input.horizontalAlignment: root.centered ? Text.AlignHCenter : Text.AlignLeft
      readOnly: root.readOnly
      onAccepted: root.accepted()
    }

    // Imperatively: the alias'd TextInput ignores a declarative echoMode
    Binding {
      target: entry.input
      property: "echoMode"
      value: root.reveal ? TextInput.Normal : TextInput.Password
    }

    StyledText {
      width: parent.width
      visible: text !== ""
      text: root.message
      textColor: root.messageIsError ? Theme.error : Theme.foregroundAlt
      textSize: Appearance.fontSize - 2
      horizontalAlignment: root.centered ? Text.AlignHCenter : Text.AlignLeft
      wrapMode: root.wrapMessage ? Text.WordWrap : Text.NoWrap
      elide: root.wrapMessage ? Text.ElideNone : Text.ElideRight
    }

    Item {
      width: parent.width
      height: 4
      visible: root.busy

      StyledContainer {
        width: parent.width * 0.3
        height: parent.height
        backgroundColor: Theme.accent

        SequentialAnimation on x {
          loops: Animation.Infinite
          running: root.busy && Appearance.animations

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
    id: shakeAnimation

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
