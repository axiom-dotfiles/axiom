pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.components.methods

// One overlay's card grid, sized to its screen: the card unit is what fits
// the free space (OverlayConfig.fitCardsHigh / fitCardsWide), capped at the
// reference cardUnit, then scaled by the user's Overlay size. Each
// OverlayPanel has its own, so every monitor gets cards that fit it; pages
// that still overflow are shrunk by OverlayPages.
QtObject {
  id: root

  // The space a page may take, set by the panel
  property real availableWidth: 0
  property real availableHeight: 0
  // A card size of its own (an edge menu's, its screen's overlay's), used
  // as is instead of what fits; 0 fits the space
  property int fixedUnit: 0

  readonly property int unit: root.fixedUnit > 0 ? root.fixedUnit : OverlayConfig.cardUnitFor(root.availableWidth, root.availableHeight)

  function span(n) {
    return OverlayConfig.span(n, root.unit);
  }

  // One grid unit across and down, and the whole grid, for modules
  // reaching `bounds` (see GridPlacement.trackSizes)
  function sizes(bounds, stretch) {
    return GridPlacement.trackSizes(bounds, root.unit, stretch);
  }
}
