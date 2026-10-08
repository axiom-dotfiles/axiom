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
