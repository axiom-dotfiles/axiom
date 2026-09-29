pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

import qs.config
import qs.services

// The floating launcher: a full-screen window with the LauncherPanel in a
// card, centred or in the upper third.
PanelWindow {
  id: root

  property bool shown: false
  // Whether this instance holds the focus grab, and the windows it lets
  // input through to (see SurfaceGroup)
  property bool ownsGrab: true
  property var grabWindows: [root]

  function open(text) {
    panel.reset(text);
    root.shown = true;
  }

  function close() {
    root.shown = false;
  }

  anchors {
    left: true
    right: true
    top: true
    bottom: true
  }
  color: "transparent"
  focusable: true
  // Stays mapped while the card fades out
  visible: shown || card.opacity > 0

  WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "axiom-launcher"

  HyprlandFocusGrab {
    active: root.shown && root.ownsGrab
    windows: root.grabWindows.concat(ShellManager.captureWindows)
    onCleared: root.close()
  }

  // The empty background (Launcher's backdrop, if on, shows through it):
  // a click on it closes
  MouseArea {
    anchors.fill: parent
    onClicked: root.close()
  }

  Rectangle {
    id: card

    // Where the card's tallest extent starts; reversed, it grows upwards
    // from the bottom of that, so the search field stays put
    readonly property real baseY: LauncherConfig.position === "center" ? Math.max(16, (root.height - panel.maxHeight) / 2) : root.height * 0.18

    width: Math.min(LauncherConfig.width, root.width - 32)
    height: panel.implicitHeight
    x: (root.width - width) / 2
    y: panel.reversed ? baseY + panel.maxHeight - height : baseY
    color: Theme.background
    border.color: Theme.border
    border.width: Appearance.borderWidth
    radius: Appearance.borderRadius
    clip: true

    opacity: root.shown ? 1 : 0
    scale: root.shown ? 1 : 0.97
    transformOrigin: panel.reversed ? Item.Bottom : Item.Top
    Behavior on opacity {
      NumberAnimation {
        duration: Appearance.animNormal
        easing.type: Appearance.easing
      }
    }
    Behavior on scale {
      NumberAnimation {
        duration: Appearance.animNormal
        easing.type: Appearance.easing
      }
    }
    Behavior on height {
      NumberAnimation {
        duration: Appearance.animFast
        easing.type: Appearance.easing
      }
    }

    // Swallow clicks so they don't reach the backdrop
    MouseArea {
      anchors.fill: parent
    }

    LauncherPanel {
      id: panel
      // Reversed, it hangs from the card's bottom: the card's height
      // animates, and the panel (and its search field) must not move with it
      y: panel.reversed ? parent.height - height : 0
      width: parent.width
      height: implicitHeight
      shown: root.shown
      onCloseRequested: root.close()
    }
  }
}
