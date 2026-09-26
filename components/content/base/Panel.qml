pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

import qs.config
import qs.components.reusable

// Content that lays out as a column and can be shown by either host: a bar
// popout (sized to its content, with the popout's box) or an overlay card
// (`embedded`: fills the slot, with the card's box). Children go into the
// margin-inset column. Content sets `margins`/`spacing`, and implicitWidth
// (plus implicitHeight if it isn't just the column's).
Item {
  id: root

  // -- From the host --
  // The bar popout wrapper, when a popout shows this (null in a card)
  property var wrapper: null
  // In an overlay card: fill the slot, draw the card box, and let lists
  // fill the height instead of their popout cap
  property bool embedded: false
  // Card only: this module's `properties` from config, and its slot
  // ([col, row, colSpan, rowSpan] in half-card units, see Card)
  property var properties: ({})
  property var slotRect: [0, 0, 2, 2]
  // Card only: where it's shown, { kind: "overlay" } or { kind: "edgeMenu", id }
  property var host: ({
      "kind": "overlay"
    })
  readonly property int cols: slotRect[2]
  readonly property int rows: slotRect[3]
  readonly property string shape: OverlayConfig.slotShape(slotRect)
  readonly property bool compact: embedded && cols <= 1 && rows <= 1
  readonly property real pad: compact ? OverlayConfig.cardPadding * 0.75 : OverlayConfig.cardPadding * 1.5

  // Bar popout only: keep the keyboard (and a focus grab) while a text
  // field is up; a click outside the popout calls focusLost()
  property bool wantsKeyboardFocus: false
  signal focusLost

  // Pointer over the content; `hovered` (what the popout wrapper reads) can
  // add more reasons to stay open, e.g. a drag in progress
  readonly property bool pointerInside: hoverHandler.hovered
  property bool hovered: pointerInside

  // What a quarter-card slot shows instead of the column (e.g. a
  // CompactFigure); without one, a compact card shows the column as usual
  property Component compactContent: null
  // Drawn under the content, filling the box (e.g. a blurred cover)
  property Component background: null
  readonly property bool _showCompact: root.compact && root.compactContent !== null

  // The box's corner radius, for backgrounds that follow its shape
  readonly property real boxRadius: root.embedded ? Appearance.borderRadius : Appearance.borderRadius + 2

  property int margins: 16
  property alias spacing: column.spacing
  readonly property alias body: column
  default property alias content: column.data

  implicitHeight: column.implicitHeight + margins * 2
  // A card sizes this to its slot (the Loader fills it); a popout sizes
  // itself to the content
  width: root.embedded ? (parent?.width ?? implicitWidth) : implicitWidth
  height: root.embedded ? (parent?.height ?? implicitHeight) : implicitHeight

  Rectangle {
    anchors.fill: parent
    color: Theme.background
    border.color: root.embedded ? Theme.foreground : "transparent"
    border.width: root.embedded ? Appearance.borderWidth : 0
    radius: root.boxRadius
    clip: true

    HoverHandler {
      id: hoverHandler
    }

    Loader {
      anchors.fill: parent
      active: root.background !== null
      sourceComponent: root.background
    }

    Loader {
      anchors.centerIn: parent
      active: root._showCompact
      sourceComponent: root.compactContent
    }

    ColumnLayout {
      id: column
      visible: !root._showCompact
      anchors.fill: parent
      anchors.margins: root.embedded ? root.pad : root.margins
      spacing: Widget.spacing
    }
  }
}
