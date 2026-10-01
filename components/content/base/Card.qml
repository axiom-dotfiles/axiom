pragma ComponentBehavior: Bound
import QtQuick
import qs.config

// Base for overlay modules (what BaseWidget is for bar modules): the card
// box filling its cell slot. Modules set only what differs, e.g. `color`,
// and pick their internal layout from `shape` / `compact` (see
// OverlaySlot, which sets `slotRect`).
Rectangle {
  id: root

  // This module's `properties` from config (schema defaults filled in)
  property var properties: ({})
  // Set by the card host, for content that can also be a popout (see Panel)
  property bool embedded: true
  // The slot this module fills, in grid units (four to a card): [col, row,
  // colSpan, rowSpan]
  property var slotRect: [0, 0, 4, 4]
  // Where the card is shown: { kind: "overlay" } or { kind: "edgeMenu", id,
  // bare }
  property var host: ({
      "kind": "overlay"
    })
  // Derived from the slot (see SlotContext): no card box (an edge menu
  // with moduleBorders off), the span in grid units, "square" |
  // "horizontal" | "vertical", a quarter card or less (room for the key
  // figure only), and the inner padding modules lay their content out within
  readonly property alias bare: slot.bare
  readonly property alias cols: slot.cols
  readonly property alias rows: slot.rows
  readonly property alias shape: slot.shape
  readonly property alias compact: slot.compact
  readonly property alias pad: slot.pad

  property SlotContext _slot: SlotContext {
    id: slot
    slotRect: root.slotRect
    host: root.host
    embedded: root.embedded
  }

  anchors.fill: parent
  color: bare ? "transparent" : Theme.background
  border.color: Theme.border
  border.width: bare ? 0 : Appearance.borderWidth
  radius: Widget.radius
  clip: true
}
