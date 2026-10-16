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

  // Each window's keyboard focus: its content's `Window.active` (attached,
  // which follows the item into whichever backing window it's in). Not
  // Quickshell's `_backingWindow`: it doesn't notify, and a PanelWindow
  // (an interface around the real window) has none
  Instantiator {
    id: _watchers
    model: root._native ? [] : root.windows

    delegate: QtObject {
      id: watcher

      required property var modelData
      // Read once: the attached object is the content item's for good
      property var attached: null
      readonly property bool focused: watcher.attached?.active === true
      onFocusedChanged: root._recheck()

      Component.onCompleted: watcher.attached = watcher.modelData?.contentItem?.Window ?? null
    }

    onObjectAdded: root._recheck()
    onObjectRemoved: root._recheck()
  }

  // Whether one of the windows has keyboard focus while the grab is on
  property bool _focused: false
  // Whether one of the windows has had keyboard focus since the grab began
  property bool _held: false

  function _recheck() {
    let focused = false;
    for (let i = 0; i < _watchers.count; i++)
      focused = focused || root._focusedOf(_watchers.objectAt(i));
    root._focused = !root._native && root.active && focused;
  }

  // A watcher's `focused` (untyped: objectAt hands back a QObject)
  function _focusedOf(watcher) {
    return watcher?.focused === true;
  }

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
    root._recheck();
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
