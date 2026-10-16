pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland

import qs.services

// The window switcher's keys where the compositor can't report their
// release (no supports.switcherRelease: sway fires a release bind only when
// no other key came between). While the switcher is open this invisible
// pixel takes the keyboard, so letting go of the held modifier picks the
// window, Escape cancels and Return picks; the switcher binds themselves
// still reach the compositor, which runs binds before the focused surface.
PanelWindow {
  id: root

  visible: WindowSwitcherManager.active
  anchors {
    left: true
    top: true
  }
  implicitWidth: 1
  implicitHeight: 1
  exclusionMode: ExclusionMode.Ignore
  color: "transparent"
  mask: Region {}
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "axiom-switcher-keys"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

  Item {
    anchors.fill: parent
    focus: true

    Keys.onReleased: event => {
      if ([Qt.Key_Alt, Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R, Qt.Key_Control].includes(event.key))
        WindowSwitcherManager.commit();
    }
    Keys.onPressed: event => {
      if (event.key === Qt.Key_Escape)
        WindowSwitcherManager.cancel();
      else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
        WindowSwitcherManager.commit();
    }
  }
}
