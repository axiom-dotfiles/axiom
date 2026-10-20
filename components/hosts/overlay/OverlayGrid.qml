pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.components.methods

// One overlay's card grid, sized to its screen: content lays out at the
// same card size everywhere (`unit`, GridPlacement.layoutUnit), and is
// drawn `zoom` times that so a page two cards high fills the screen
// (OverlayConfig.layoutFor, scaled by the card size and the overlay's
// Module size). Each OverlayPanel
// has its own, so every monitor shows the same look at its own size;
// pages that still overflow are shrunk by OverlayPages.
QtObject {
  id: root

  // The drawn px a page may take, set by the panel
  property real availableWidth: 0
  property real availableHeight: 0
  // A card size of its own (an edge menu's, a screen layout's), used
  // as is, undrawn, instead of what fits; 0 fits the space
  property int fixedUnit: 0

  readonly property var _layout: root.fixedUnit > 0 ? null : OverlayConfig.layoutFor(root.availableWidth, root.availableHeight)
  // The card size content lays out at, and the one it's drawn at
  readonly property int unit: root._layout ? root._layout.unit : root.fixedUnit
  readonly property int drawnUnit: root._layout ? root._layout.drawn : root.fixedUnit
  readonly property real zoom: root._layout ? root._layout.zoom : 1
  // The room in layout px, what views size themselves against
  readonly property real roomWidth: root.availableWidth / root.zoom
  readonly property real roomHeight: root.availableHeight / root.zoom

  function span(n) {
    return OverlayConfig.span(n, root.unit);
  }

  // One grid unit across and down, and the whole grid, for modules
  // reaching `bounds` (see GridPlacement.trackSizes)
  function sizes(bounds, stretch) {
    return GridPlacement.trackSizes(bounds, root.unit, stretch);
  }
}
