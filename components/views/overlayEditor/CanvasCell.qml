pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.components.reusable

// One cell on the canvas: its layout's slots as SlotTiles, drawn at
// `scaleFactor`, and on hover a grip to carry the whole cell (click it to
// select the cell itself). Positioned by CanvasColumn.
Item {
  id: root

  required property var dragLayer
  required property int column
  required property int cell
  // { layout, slots }
  required property var cellConfig
  required property real scaleFactor

  // A string, so the tiles are only rebuilt when the layout changes
  readonly property string layoutName: root.cellConfig?.layout ?? "Single"
  readonly property var layoutData: OverlayConfig.layouts[root.layoutName] ?? {
    "cols": 2,
    "rows": 2,
    "slots": {}
  }
  readonly property var slotNames: Object.keys(root.layoutData.slots)
  readonly property real step: (OverlayConfig.halfUnit + OverlayConfig.cardSpacing) * root.scaleFactor
  readonly property bool selected: root.dragLayer.editor.isSelected(root.column, root.cell, "")
  readonly property bool carried: root.dragLayer.draggingKind === "cell-move" && root.dragLayer.dragging.column === root.column && root.dragLayer.dragging.cell === root.cell
  readonly property bool showGrip: root.dragLayer.dragging === null && (hover.hovered || root.selected || root.dragLayer.editor.isCellSelected(root.column, root.cell))

  opacity: root.carried ? 0.3 : 1

  HoverHandler {
    id: hover
  }

  // The selected cell (or the cell of the selected slot)
  Rectangle {
    anchors.fill: parent
    // Just outside the cell, well inside the space between cells
    anchors.margins: -Math.min(3, OverlayConfig.cardSpacing * root.scaleFactor / 3)
    radius: Appearance.borderRadius + 2
    color: "transparent"
    visible: root.dragLayer.editor.isCellSelected(root.column, root.cell)
    border.color: Theme.accent
    border.width: root.selected ? 2 : 1
    opacity: root.selected ? 1 : 0.45
  }

  Repeater {
    model: root.slotNames

    SlotTile {
      id: tile
      required property string modelData
      dragLayer: root.dragLayer
      column: root.column
      cell: root.cell
      slot: tile.modelData
      rect: root.layoutData.slots[tile.modelData]
      module: root.cellConfig?.slots?.[tile.modelData] ?? null
      x: tile.rect[0] * root.step
      y: tile.rect[1] * root.step
      width: OverlayConfig.span(tile.rect[2]) * root.scaleFactor
      height: OverlayConfig.span(tile.rect[3]) * root.scaleFactor
    }
  }

  // Marks a cell that fills free room (shown at its own size here)
  Rectangle {
    visible: root.cellConfig?.fill === true
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.margins: 4
    z: 2
    width: Widget.height * 0.8
    height: width
    radius: Appearance.borderRadius
    color: Theme.accent

    StyledIcon {
      anchors.centerIn: parent
      text: "expand_content"
      textColor: Theme.background
      textSize: Appearance.fontSize - 1
    }
  }

  // Carries the cell; a click selects it
  Rectangle {
    id: grip
    x: 4
    y: 4
    z: 2
    width: gripRow.implicitWidth + 8
    height: Widget.height * 0.8
    radius: Appearance.borderRadius
    color: root.selected ? Theme.accent : Theme.backgroundHighlight
    border.color: root.selected ? Theme.accent : Theme.border
    border.width: 1
    visible: root.showGrip || root.carried
    opacity: gripArea.containsMouse || root.selected ? 1 : 0.85

    Row {
      id: gripRow
      anchors.centerIn: parent
      spacing: 4

      StyledIcon {
        text: "drag_indicator"
        textColor: root.selected ? Theme.background : Theme.foreground
        textSize: Appearance.fontSize - 1
      }
      StyledText {
        // Only while there's room for it next to the grip
        visible: root.width > Appearance.fontSize * 9
        text: root.dragLayer.layoutLabel(root.layoutName)
        textColor: root.selected ? Theme.background : Theme.foreground
        textSize: Appearance.fontSize - 3
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    DragArea {
      id: gripArea
      anchors.fill: parent
      onDragStarted: (x, y) => root.dragLayer.begin({
          "kind": "cell-move",
          "layout": root.layoutName,
          "column": root.column,
          "cell": root.cell,
          "icon": "view_quilt",
          "label": root.dragLayer.layoutLabel(root.layoutName)
        }, gripArea, x, y)
      onDragMoved: (x, y) => root.dragLayer.move(gripArea, x, y)
      onDropped: root.dragLayer.end()
      onDragCanceled: root.dragLayer.cancel()
      onTapped: root.dragLayer.editor.select(root.column, root.cell, "")
    }
  }
}
