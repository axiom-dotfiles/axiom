pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// A focus grab, for surfaces that close (or drop keyboard focus) on a click
// outside them: while `active`, keyboard focus stays in `windows` and a
// click anywhere else ends the grab (`cleared`). Hyprland's focus grab
// (HyprlandGrab) where the compositor has one (CompositorManager.supports.
// focusGrab); elsewhere the grab ends once keyboard focus has left every
// one of `windows` (a click on another window or surface takes it), which
// only works for windows that take keyboard focus. Not a singleton: each
// surface makes its own.
Scope {
  id: root

  property var windows: []
  property bool active: false
  signal cleared

  readonly property bool _native: CompositorManager.supports.focusGrab === true

  LazyLoader {
    active: root._native
    HyprlandGrab {
      windows: root.windows
      active: root.active
      onCleared: root.cleared()
    }
  }

  // --- Without a native grab: watch keyboard focus ---

  // Whether one of the windows has had keyboard focus since the grab began
  property bool _held: false
  readonly property bool _focused: !root._native && root.active && root.windows.some(w => w?._backingWindow?.active === true)

  on_FocusedChanged: {
    if (root._focused)
      root._held = true;
    else if (root._held)
      _lost.restart();
  }
  onActiveChanged: {
    if (!root.active) {
      root._held = false;
      _lost.stop();
    }
  }

  // Focus moving between two of the windows passes through none
  Timer {
    id: _lost
    interval: 100
    onTriggered: {
      if (root.active && root._held && !root._focused) {
        root._held = false;
        root.cleared();
      }
    }
  }
}
