pragma ComponentBehavior: Bound
import QtQuick
import Qt5Compat.GraphicalEffects
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

  margins {
    left: Bar.extent
    right: Appearance.screenMargin - Appearance.borderWidth
    top: Appearance.screenMargin - Appearance.borderWidth
    bottom: Appearance.screenMargin - Appearance.borderWidth
  }

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
          duration: Appearance.animationDuration * 1.5
          easing.type: Easing.InOutQuad
        }
      }
    }

    Rectangle {
      id: background
      anchors.fill: parent
      border.color: Theme.foreground
      border.width: Math.max(Menu.cardBorderWidth, 2)
      radius: Menu.cardBorderRadius
      color: Appearance.darkMode ? Theme.background : Theme.foreground
      opacity: 0.85
    }

    // TODO: insert a wrapper here to handle
    // loading multiple different views and
    // navigation between them

    OverlayTabWrapper {
      anchors.centerIn: parent
      screen: overlay.screen
    }

    // Rectangle {
    //   anchors.centerIn: parent
    //   implicitHeight: viewLoader.item ? viewLoader.item.implicitHeight + Menu.cardSpacing * 2 : 0
    //   implicitWidth: viewLoader.item ? viewLoader.item.implicitWidth + Menu.cardSpacing * 2 : 0
    //   radius: Menu.cardBorderRadius
    //   color: Theme.backgroundAlt
    //   border.color: Theme.foreground
    //   border.width: Menu.cardBorderWidth
    //
    //   Loader {
    //     id: viewLoader
    //     anchors.centerIn: parent
    //     sourceComponent: KeybindView {
    //       screen: overlay.screen
    //     }
    //   }
    // }
  }
}
