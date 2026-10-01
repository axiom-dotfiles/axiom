pragma ComponentBehavior: Bound
import QtQuick
import qs.config

// What Card and Panel derive from their slot, in one place: its size in
// grid units (four to a card), shape, whether it's a quarter card or less,
// bare, and the
// padding content lays out within
QtObject {
  // [col, row, colSpan, rowSpan] in grid units, four to a card
  property var slotRect: [0, 0, 4, 4]
  // { kind: "overlay" } or { kind: "edgeMenu", id, bare }
  property var host: ({
      "kind": "overlay"
    })
  // Shown as a card (false: a bar popout, which is never compact or bare)
  property bool embedded: true

  readonly property int cols: slotRect[2]
  readonly property int rows: slotRect[3]
  // "square" | "horizontal" | "vertical"
  readonly property string shape: OverlayConfig.slotShape(slotRect)
  // A quarter card or smaller: room for the key figure only
  readonly property bool compact: embedded && cols <= 2 && rows <= 2
  // No card box (an edge menu with moduleBorders off)
  readonly property bool bare: embedded && (host?.bare ?? false)
  readonly property real pad: OverlayConfig.cardPad(compact, bare)
}
