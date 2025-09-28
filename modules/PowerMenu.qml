// In powermenu/PowerMenu.qml
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io

import qs.components.reusable
import qs.config

PanelWindow {
  id: rootWindow

  property int buttonSize: 200
  property int iconSize: 60
  property int gridSpacing: 20
  property real backgroundDim: 0.5

  property string iconLock: ""
  property string iconLogout: ""
  property string iconPoweroff: ""
  property string iconSuspend: ""
  property string iconReboot: ""
  property string iconHibernate: ""


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

  property bool shown: false

  function toggle() {
    shown = !shown;
    if (shown) {
      forceActiveFocus();
    }
  }

  IpcHandler {
    target: "powermenu"
    function toggle() { rootWindow.toggle() }
    function show() { if (!rootWindow.shown) rootWindow.toggle() }
    function hide() { if (rootWindow.shown) rootWindow.toggle() }
  }

  HyprlandFocusGrab {
    id: grab
    active: rootWindow.shown
    windows: [rootWindow]
    onCleared: rootWindow.shown = false
  }

  visible: shown
  onClosed: shown = false
  Keys.onEscapePressed: rootWindow.toggle()

  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, rootWindow.backgroundDim)
    MouseArea {
        anchors.fill: parent
        onClicked: rootWindow.toggle()
    }
  }

  // Main container
  StyledContainer {
    id: menuContainer
    anchors.centerIn: parent
    width: gridLayout.implicitWidth + 40
    height: gridLayout.implicitHeight + 40

    containerColor: Theme.background
    containerBorderColor: Theme.border
    containerBorderWidth: Appearance.borderWidth

    GridLayout {
      id: gridLayout
      anchors.centerIn: parent
      columns: 3
      rowSpacing: gridSpacing
      columnSpacing: gridSpacing

      Component {
        id: iconButtonComponent
        Rectangle {
          id: iconButton
          property string icon: ""
          property alias mouseArea: buttonMouseArea
          signal clicked
          
          implicitWidth: rootWindow.buttonSize
          implicitHeight: rootWindow.buttonSize
          
          color: buttonMouseArea.containsMouse ? Theme.accent : Theme.backgroundHighlight
          border.color: Theme.border
          border.width: Appearance.borderWidth
          radius: Appearance.borderRadius
          
          Behavior on color {
            ColorAnimation { duration: 150; easing.type: Easing.InOutQuad }
          }
          
          StyledText {
            anchors.centerIn: parent
            text: iconButton.icon
            textColor: buttonMouseArea.containsMouse ? Theme.background : Theme.foreground
            textSize: rootWindow.iconSize
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
          }
          
          MouseArea {
            id: buttonMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: iconButton.clicked()
          }
        }
      }

      // Lock button
      Loader {
        sourceComponent: iconButtonComponent
        onLoaded: {
          item.icon = iconLock
          item.clicked.connect(function() {
            Ipc.send("lockscreen", "lock")
            rootWindow.toggle()
          })
        }
      }

      // Logout button
      Loader {
        sourceComponent: iconButtonComponent
        onLoaded: {
          item.icon = iconLogout
          item.clicked.connect(function() {
            Quickshell.execute("loginctl terminate-session $XDG_SESSION_ID")
          })
        }
      }

      // Power Off button
      Loader {
        sourceComponent: iconButtonComponent
        onLoaded: {
          item.icon = iconPoweroff
          item.clicked.connect(function() {
            Quickshell.execute("systemctl poweroff")
          })
        }
      }

      // Suspend button
      Loader {
        sourceComponent: iconButtonComponent
        onLoaded: {
          item.icon = iconSuspend
          item.clicked.connect(function() {
            Quickshell.execute("systemctl suspend")
            rootWindow.toggle()
          })
        }
      }

      // Reboot button
      Loader {
        sourceComponent: iconButtonComponent
        onLoaded: {
          item.icon = iconReboot
          item.clicked.connect(function() {
            Quickshell.execute("systemctl reboot")
          })
        }
      }

      // Hibernate button
      Loader {
        sourceComponent: iconButtonComponent
        onLoaded: {
          item.icon = iconHibernate
          item.clicked.connect(function() {
            Quickshell.execute("systemctl hibernate")
            rootWindow.toggle()
          })
        }
      }
    }
  }
}
