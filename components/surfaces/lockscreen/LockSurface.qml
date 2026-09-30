import QtQuick
import QtQuick.Layouts
import Quickshell

import qs.components.reusable
import qs.config
import qs.services

// What one screen shows while the built-in lock is up (the content of a
// WlSessionLockSurface, see shell/Lockscreen.qml). The compositor gives the
// lock surfaces all input and hides everything else, so this needs no
// focus grabs or layer tricks. The password field lives on the target
// screen; the others show the backdrop and greeting only. Nothing here may
// unlock or run commands: only AuthManager's success unlocks.
Item {
  id: root

  required property ShellScreen screen
  readonly property bool isTarget: ShellManager.isTarget(root.screen)

  readonly property real aspectRatio: root.screen ? root.screen.width / root.screen.height : 1.6
  readonly property int containerWidth: root.aspectRatio > 2.0 ? Math.min(width * 0.5, 400) : Math.min(width * 0.6, 400)

  anchors.fill: parent

  Component.onCompleted: {
    AuthManager.clearMessage();
    if (root.isTarget)
      passwordInput.input.forceActiveFocus();
  }

  Connections {
    target: AuthManager

    function onAuthenticationFailed(reason) {
      if (!root.isTarget)
        return;
      passwordInput.input.text = "";
      passwordInput.input.forceActiveFocus();
      shakeAnimation.start();
    }

    function onAuthenticationError(error) {
      if (!root.isTarget)
        return;
      passwordInput.input.text = "";
      passwordInput.input.forceActiveFocus();
    }
  }

  Rectangle {
    anchors.fill: parent
    color: Theme.background

    Rectangle {
      anchors.fill: parent
      color: Theme.base00
      opacity: 0.4
    }
  }

  // Fades in over the backdrop, which is there from the first frame
  Item {
    id: lockContainer
    width: root.containerWidth
    height: mainColumn.height
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: -parent.height / 8
    opacity: 0
    Component.onCompleted: opacity = 1

    Behavior on opacity {
      NumberAnimation {
        duration: Appearance.animSlow
        easing.type: Easing.InOutQuad
      }
    }

    SequentialAnimation {
      id: shakeAnimation
      loops: 1
      PropertyAnimation {
        target: lockContainer
        property: "anchors.horizontalCenterOffset"
        from: 0
        to: 20
        duration: Appearance.animFast
      }
      PropertyAnimation {
        target: lockContainer
        property: "anchors.horizontalCenterOffset"
        from: 20
        to: -20
        duration: Appearance.animFast
      }
      PropertyAnimation {
        target: lockContainer
        property: "anchors.horizontalCenterOffset"
        from: -20
        to: 20
        duration: Appearance.animFast
      }
      PropertyAnimation {
        target: lockContainer
        property: "anchors.horizontalCenterOffset"
        from: 20
        to: 0
        duration: Appearance.animFast
      }
    }

    ColumnLayout {
      id: mainColumn
      width: parent.width
      spacing: Appearance.screenMargin

      StyledText {
        text: I18n.tr("Hey {0}", General.displayName)
        textSize: Appearance.fontSize * 3
        textColor: Theme.foreground
        horizontalAlignment: Text.AlignHCenter
        Layout.fillWidth: true
      }

      // Playing track (display and transport only)
      StyledContainer {
        visible: root.isTarget && LockscreenConfig.showMedia && MediaManager.isPlaying
        Layout.fillWidth: true
        Layout.preferredHeight: 100
        color: Theme.accent
        radius: Widget.radius

        MediaControl {
          anchors.fill: parent
          backgroundColor: parent.color
          showProgressBar: false
        }
      }

      Column {
        visible: root.isTarget
        Layout.fillWidth: true
        spacing: Widget.padding

        StyledTextEntry {
          id: passwordInput
          placeholderText: I18n.tr("Enter password...")
          width: parent.width
          input.passwordCharacter: "•"
          input.passwordMaskDelay: 0
          input.horizontalAlignment: Text.AlignHCenter
          enabled: !AuthManager.isAuthenticating
          focus: root.isTarget
          // Imperatively: the alias'd TextInput ignores a declarative echoMode
          Component.onCompleted: input.echoMode = TextInput.Password

          Keys.onEscapePressed: {
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
            if (input.text.length > 0 && !AuthManager.isAuthenticating) {
              AuthManager.authenticate(input.text);
              input.text = "";
            }
          }
        }

        // PAM's messages: prompts, failures, errors
        StyledText {
          text: AuthManager.message
          textColor: AuthManager.messageIsError ? Theme.error : Theme.foregroundAlt
          textSize: Appearance.fontSize - 2
          horizontalAlignment: Text.AlignHCenter
          width: parent.width
          visible: AuthManager.message !== ""
        }

        // While PAM is checking
        Item {
          width: parent.width
          height: 4
          visible: AuthManager.isAuthenticating

          StyledContainer {
            width: parent.width * 0.3
            height: parent.height
            backgroundColor: Theme.accent

            SequentialAnimation on x {
              loops: Animation.Infinite
              running: AuthManager.isAuthenticating && Appearance.animations

              NumberAnimation {
                from: 0
                to: lockContainer.width * 0.7
                duration: Appearance.animSlow * 3
                easing.type: Easing.InOutQuad
              }
              NumberAnimation {
                from: lockContainer.width * 0.7
                to: 0
                duration: Appearance.animSlow * 3
                easing.type: Easing.InOutQuad
              }
            }
          }
        }
      }
    }
  }
}
