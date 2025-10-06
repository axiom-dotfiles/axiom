pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

import qs.config
import qs.components.widgets.overlay
import qs.components.widgets.overlay.views

// TODO: build from a reusable fullscreen panel
PanelWindow {
  id: overlay

  required property var screen

  property bool isPrimaryScreen: screen.name === Display.primary
  property bool isOpen: false
  property bool enabled: overlay.isPrimaryScreen
  property real slideOffset: isOpen ? 0 : -height

  anchors {
    left: true
    right: true
    top: true
    bottom: true
  }

  // TODO: implement
  // margins {
  //   left: 50
  //   right: 50
  //   top: 50
  //   bottom: 50
  // }

  color: "transparent"
  focusable: true
  visible: false
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.exclusiveZone: -1

  function open() {
    visible = true;
    isOpen = true;
  }

  function close() {
    isOpen = false;
    hideTimer.start();
  }

  function toggle() {
    if (isOpen) {
      close();
    } else {
      open();
    }
  }

  Timer {
    id: hideTimer
    interval: 300
    repeat: false
    onTriggered: {
      overlay.visible = false;
    }
  }

  IpcHandler {
    target: "overlay"
    enabled: overlay.isPrimaryScreen

    function open() {
      overlay.open();
    }

    function close() {
      overlay.close();
    }

    function toggle() {
      overlay.toggle();
    }
  }

  HyprlandFocusGrab {
    id: grab
    active: overlay.visible && overlay.isPrimaryScreen
    windows: [overlay]
    onCleared: {
      if (!overlay.isOpen) {
        grab.active = true;
      }
    }
  }

  Item {
    id: slideContainer
    anchors.fill: parent

    transform: Translate {
      y: overlay.slideOffset
      Behavior on y {
        NumberAnimation {
          duration: Widget.animationDuration
          easing.type: Easing.InOutQuad
        }
      }
    }

    Rectangle {
      anchors.fill: parent
      color: Theme.background
    }

    // TODO: insert a wrapper here to handle
    // loading multiple different views and
    // navigation between them

    Rectangle {
      anchors.centerIn: parent
      implicitWidth: Menu.cardUnit * Menu.columns + Menu.cardSpacing * (Menu.columns + 1)
      implicitHeight: Menu.cardUnit * 2 + Menu.cardSpacing * 3
      radius: Menu.cardBorderRadius
      color: Theme.backgroundAlt

      Loader {
        id: viewLoader
        anchors.fill: parent
        sourceComponent: OverView {
          screen: overlay.screen
        }
      }
    }
  }
}
