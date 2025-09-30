import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

import qs.components.reusable
import qs.components.widgets.menu
import qs.config
import qs.services

PanelWindow {
  id: rootWindow

  required property var screen
  property bool isPrimaryScreen: screen.name === Display.primary

  property int containerWidth: 400
  property bool isLocked: false
  property bool showMediaControl: MprisController.isPlaying
  property real slideOffset: isLocked ? 0 : -height

  Component.onCompleted: {
    console.log("Lockscreen initialized on screen:", screen.name);
    ShellManager.lockScreen.connect(function() {
      rootWindow.lock();
    });
  }

  anchors {
    left: true
    right: true
    top: true
    bottom: true
  }
  color: "transparent"
  focusable: true

  WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.exclusiveZone: -1

  function lock() {
  visible = true;
  isLocked = true;
  
  if (isPrimaryScreen) {
    passwordInput.text = "";
    Authentication.clearMessage();
    passwordInput.forceActiveFocus();
  }
}

  function unlock() {
    isLocked = false;
    if (isPrimaryScreen) {
      passwordInput.input.text = "";
      Authentication.clearMessage();
    }
    hideTimer.start();
  }

  Timer {
    id: hideTimer
    interval: 300
    repeat: false
    onTriggered: {
      if (!rootWindow.isLocked) {
        rootWindow.visible = false;
      }
    }
  }

  IpcHandler {
    target: "lockscreen"

    function lock() {
      rootWindow.lock();
    }

    function unlock() {
      rootWindow.unlock();
    }

    function toggle() {
      if (rootWindow.isLocked) {
        rootWindow.unlock();
      } else {
        rootWindow.lock();
      }
    }
  }

  visible: false  // Start hidden
  onClosed: {
    Authentication.cancel();
  }

  HyprlandFocusGrab {
    id: grab
    active: rootWindow.isLocked && rootWindow.isPrimaryScreen
    windows: [rootWindow]
    onCleared: {
      if (rootWindow.isLocked) {
        grab.active = true;
      }
    }
  }

  Connections {
    target: Authentication

    function onAuthenticationSucceeded() {
      if (rootWindow.isLocked) {
        rootWindow.unlock();
      }
    }

    function onAuthenticationFailed(reason) {
      if (rootWindow.isLocked && rootWindow.isPrimaryScreen) {
        passwordInput.input.text = "";
        passwordInput.input.forceActiveFocus();
        shakeAnimation.start();
      }
    }

    function onAuthenticationError(error) {
      if (rootWindow.isLocked && rootWindow.isPrimaryScreen) {
        passwordInput.input.text = "";
        passwordInput.input.forceActiveFocus();
      }
    }
  }

  Item {
    id: slideContainer
    anchors.fill: parent

    transform: Translate {
      y: rootWindow.slideOffset
      Behavior on y {
        NumberAnimation {
          duration: 300
          easing.type: Easing.InOutQuad
        }
      }
    }

    Rectangle {
      anchors.fill: parent
      color: Theme.background

      Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.4
      }
    }

    Item {
      id: lockContainer
      width: rootWindow.containerWidth
      height: mainColumn.height
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.verticalCenter: parent.verticalCenter
      anchors.verticalCenterOffset: -parent.height / 8

      visible: true
      Component.onCompleted: {
        console.log("LockContainer initialized on screen:", rootWindow.screen.name);
        console.log("Primary Screen? ", rootWindow.isPrimaryScreen);
      }

      SequentialAnimation {
        id: shakeAnimation
        loops: 1
        PropertyAnimation {
          target: lockContainer
          property: "anchors.horizontalCenterOffset"
          from: 0
          to: 20
          duration: 50
        }
        PropertyAnimation {
          target: lockContainer
          property: "anchors.horizontalCenterOffset"
          from: 20
          to: -20
          duration: 100
        }
        PropertyAnimation {
          target: lockContainer
          property: "anchors.horizontalCenterOffset"
          from: -20
          to: 20
          duration: 100
        }
        PropertyAnimation {
          target: lockContainer
          property: "anchors.horizontalCenterOffset"
          from: 20
          to: 0
          duration: 50
        }
      }

      ColumnLayout {
        id: mainColumn
        width: parent.width
        spacing: Appearance.screenMargin

        StyledText {
          text: "hey " + Config.userName
          textSize: Appearance.fontSize * 3
          textColor: Theme.foreground
          horizontalAlignment: Text.AlignHCenter
          Layout.fillWidth: true
        }

        Item {
          id: mediaContainer

          property bool showMedia: true
          property alias mediaControl: mediaControlLoader.item
          property int animationDuration: 300

          Layout.fillWidth: true
          Layout.preferredHeight: showMedia ? mediaControlLoader.height : 0
          clip: true

          Behavior on Layout.preferredHeight {
            NumberAnimation {
              duration: mediaContainer.animationDuration
              easing.type: Easing.InOutQuad
            }
          }

          Loader {
            id: mediaControlLoader
            width: parent.width
            active: true
            opacity: mediaContainer.showMedia ? 1 : 0

            Behavior on opacity {
              NumberAnimation {
                duration: mediaContainer.animationDuration
              }
            }

            sourceComponent: Rectangle {
              id: mediaRoot
              width: parent.width
              height: mediaControl.implicitHeight
              color: Theme.accent
              radius: 8

              MediaControl {
                id: mediaControl
                implicitHeight: MprisController.isPlaying ? 100 : 0
                visible: MprisController.isPlaying ? true : false
                anchors.fill: parent
                containerColor: parent.color
                showProgressBar: false
              }
            }
          }
        }

        Column {
          Layout.fillWidth: true
          spacing: Widget.padding

          StyledTextEntry {
            id: passwordInput
            placeholderText: "Enter password..."
            width: parent.width
            input.passwordCharacter: "•"
            input.passwordMaskDelay: 0
            input.horizontalAlignment: Text.AlignHCenter
            enabled: !Authentication.isAuthenticating

            focus: true

            Component.onCompleted: {
              input.echoMode = 2;
              if (rootWindow.isLocked && rootWindow.isPrimaryScreen) {
                input.forceActiveFocus();
              }
            }

            Keys.onEscapePressed: {
              text = "";
              Authentication.clearMessage();
            }

            Keys.onPressed: event => {
              if (event.key === Qt.Key_C && event.modifiers & Qt.ControlModifier) {
                input.text = "";
                Authentication.clearMessage();
                event.accepted = true;
              }
            }

            onAccepted: {
              if (input.text.length > 0 && !Authentication.isAuthenticating) {
                Authentication.authenticate(input.text, null);
                input.text = "";
              }
            }
          }

          // Authentication message
          StyledText {
            id: messageText
            text: Authentication.message
            textColor: Authentication.messageIsError ? Theme.error : Theme.foregroundAlt
            textSize: Appearance.fontSize - 2
            horizontalAlignment: Text.AlignHCenter
            width: parent.width
            visible: Authentication.message !== ""

            Behavior on opacity {
              NumberAnimation {
                duration: 150
                easing.type: Easing.InOutQuad
              }
            }
          }

          // Loading indicator during authentication
          Item {
            width: parent.width
            height: 4
            visible: Authentication.isAuthenticating

            Rectangle {
              id: progressBar
              width: parent.width * 0.3
              height: parent.height
              color: Theme.accent
              radius: 2

              SequentialAnimation on x {
                loops: Animation.Infinite
                running: Authentication.isAuthenticating

                NumberAnimation {
                  from: 0
                  to: lockContainer.width * 0.7
                  duration: 1000
                  easing.type: Easing.InOutQuad
                }
                NumberAnimation {
                  from: lockContainer.width * 0.7
                  to: 0
                  duration: 1000
                  easing.type: Easing.InOutQuad
                }
              }
            }
          }
        }
      }
    }
  }
}
