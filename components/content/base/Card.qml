import QtQuick
import qs.config

// Base for overlay modules (what BaseWidget is for bar modules): the card
// box filling its cell slot. Modules set only what differs, e.g. `color`,
// and pick their internal layout from `shape` / `compact` (see
// OverlaySlot, which sets `slotRect`).
Rectangle {
  // This module's `properties` from config (schema defaults filled in)
  property var properties: ({})
  // Set by the card host, for content that can also be a popout (see Panel)
  property bool embedded: true
  // The slot this module fills, in half-card units: [col, row, colSpan, rowSpan]
  property var slotRect: [0, 0, 2, 2]
  // Where the card is shown: { kind: "overlay" } or { kind: "edgeMenu", id }
  property var host: ({
      "kind": "overlay"
    })

  readonly property int cols: slotRect[2]
  readonly property int rows: slotRect[3]
  // "square" | "horizontal" | "vertical"
  readonly property string shape: OverlayConfig.slotShape(slotRect)
  // A quarter-card slot: room for the key figure only
  readonly property bool compact: cols <= 1 && rows <= 1
  // Inner padding modules lay their content out within
  readonly property real pad: compact ? OverlayConfig.cardPadding * 0.75 : OverlayConfig.cardPadding * 1.5

  anchors.fill: parent
  color: Theme.background
  border.color: Theme.foreground
  border.width: Appearance.borderWidth
  radius: Appearance.borderRadius
  clip: true
}
