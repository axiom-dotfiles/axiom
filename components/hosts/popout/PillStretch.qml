pragma ComponentBehavior: Bound
import QtQuick

// Puts a surface's pill (or island) stretch (EdgeAttach.place's `stretch`)
// on the bar it stands on (`container`, a BarContainer) under its own
// owner key, and takes it off again when it clears, the bar changes or
// this goes. Written by hand rather than by a Binding: its restore on
// deactivation brought back a stale stretch.
QtObject {
  id: root

  property var container: null
  property var stretch: null
  // Where the surface covers the pill's (or island's) far stroke, along
  // the bar ({ start, end }), left open there (BarContainer.setOpening)
  property var opening: null
  // Unique per surface on a bar (a bar has one popout host, and any number
  // of edge popouts on its edge)
  required property string owner

  // Whether its surface is to show (open, not closing): set by the host
  property bool open: false
  // Whether the pill has grown out to the stretch, so the surface may slide
  // out onto it: it grows first, as it draws back only after the surface
  // has gone. Once ready it holds while the surface stays open, so a
  // stretch changing meanwhile (a switch in place, a resize) never pulls
  // the surface back.
  readonly property bool ready: root._latched || (root._armed && root._readyNow)
  readonly property bool _readyNow: !root.stretch || !root.container || root.container.carries(root.stretch)
  // Open for a turn of the event loop: a host's stretch comes in with its
  // content, in the same pass that opens it, so it's judged only after
  property bool _armed: false
  property bool _latched: false
  function _relatch() {
    // Gone meanwhile
    if (!root)
      return;
    if (!root.open) {
      root._armed = false;
      root._latched = false;
    } else if (root._armed && root._readyNow) {
      root._latched = true;
    }
  }
  onOpenChanged: {
    if (!root.open) {
      root._relatch();
      return;
    }
    Qt.callLater(() => {
      if (!root || !root.open)
        return;
      root._armed = true;
      root._relatch();
    });
  }
  // Later: it changes while `ready` is being evaluated
  on_ReadyNowChanged: Qt.callLater(root._relatch)

  property var _target: null
  function _clear() {
    try {
      root._target?.setStretch(root.owner, null);
      root._target?.setOpening(root.owner, null);
    } catch (e) {
      // The bar went first (a reload)
    }
    root._target = null;
  }
  function _push() {
    const target = root.stretch || root.opening ? root.container : null;
    if (root._target !== target)
      root._clear();
    if (!target)
      return;
    root._target = target;
    target.setStretch(root.owner, root.stretch);
    target.setOpening(root.owner, root.opening);
  }
  onStretchChanged: root._push()
  onOpeningChanged: root._push()
  onContainerChanged: root._push()
  Component.onDestruction: root._clear()
}
