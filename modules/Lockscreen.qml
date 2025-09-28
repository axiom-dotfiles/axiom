import QtQuick
import QtQuick.Layouts
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

  property int containerWidth: 400
  property bool isLocked: false
  property bool showMediaControl: MprisController.isPlaying
  property real slideOffset: isLocked ? 0 : -height
  
  Component.onCompleted: {
    console.log("Media is playing:", MprisController.isPlaying);
  }

  screen: Quickshell.screens[0]
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
    passwordInput.input.text = "";
    Authentication.clearMessage();
    passwordInput.input.forceActiveFocus();
  }

  function unlock() {
    isLocked = false;
    passwordInput.input.text = "";
    Authentication.clearMessage();
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

  visible: false
  onClosed: {
    Authentication.cancel();
  }

  HyprlandFocusGrab {
    id: grab
    active: rootWindow.isLocked
    windows: [rootWindow]
    onCleared: {
      if (rootWindow.isLocked) {
        grab.active = true;
      }
    }
  }

  // Authentication connections
  Connections {
    target: Authentication
    
    function onAuthenticationSucceeded() {
      if (rootWindow.isLocked) {
        rootWindow.unlock();
      }
    }
    
    function onAuthenticationFailed(reason) {
      if (rootWindow.isLocked) {
        passwordInput.input.text = "";
        passwordInput.input.forceActiveFocus();
        shakeAnimation.start();
      }
    }
    
    function onAuthenticationError(error) {
      if (rootWindow.isLocked) {
        passwordInput.input.text = "";
        passwordInput.input.forceActiveFocus();
      }
    }
  }

  // Main content with slide animation
  Item {
    id: slideContainer
    anchors.fill: parent
    
    // Slide animation
    transform: Translate {
      y: slideOffset
      Behavior on y {
        NumberAnimation {
          duration: 300
          easing.type: Easing.InOutQuad
        }
      }
    }

    // Background with strong blur effect
    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.98)
      
      // Additional darkening layer for better visibility
      Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.3
      }
    }

    // Main container
    Item {
      id: lockContainer
      width: containerWidth
      height: mainColumn.height
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.verticalCenter: parent.verticalCenter
      anchors.verticalCenterOffset: -parent.height / 8

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

        MediaControl {
          id: mediaControl
          Layout.fillWidth: true
          visible: rootWindow.showMediaControl
          containerColor: Theme.accent
          showProgressBar: false
        }

        Column {
          width: parent.width
          spacing: Appearance.padding

          StyledTextEntry {
            id: passwordInput
            placeholderText: "Enter password ..."
            width: parent.width
            input.passwordCharacter: "*"
            input.passwordMaskDelay: 0
            input.horizontalAlignment: Text.AlignHCenter
            enabled: !Authentication.isAuthenticating
            
            Component.onCompleted: {
              input.echoMode = 2;
            }
            
            focus: rootWindow.isLocked

            Keys.onEscapePressed: {
              input.text = "";
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
              }
            }
          }

          // Authentication message
          StyledText {
            id: messageText
            text: Authentication.message
            textColor: Authentication.messageIsError ? Theme.critical : Theme.foregroundAlt
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
