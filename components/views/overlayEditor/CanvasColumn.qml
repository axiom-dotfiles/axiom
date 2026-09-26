pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components.reusable

// One column of the page on the canvas: a full-size header (grip to carry
// the column, remove), then its cells flowing as in OverlayColumn, drawn
// at `scaleFactor`. The body is a drop target for cells and modules; an
// accent bar shows where a drop would go.
Item {
  id: root

  required property var dragLayer
  required property int column
  required property var columnConfig
  required property real scaleFactor
  // Height of the drop zone below the cells
  property real endZone: Widget.height * 1.5
  readonly property var cells: root.columnConfig?.cells ?? []
  // Unscaled, from OverlayConfig.columnFlow
  readonly property var flow: OverlayConfig.columnFlow(root.cells)
  readonly property real headerHeight: Widget.height
  readonly property bool carried: root.dragLayer.draggingKind === "column-move" && root.dragLayer.dragging.column === root.column

  implicitWidth: Math.max(root.flow.width * root.scaleFactor, Widget.height * 2)
  opacity: root.carried ? 0.3 : 1

  // Header: the grip is the whole title, so it's easy to grab
  Rectangle {
    id: header
    width: root.width
    height: root.headerHeight
    radius: Appearance.borderRadius
    color: headerHover.hovered || root.carried ? Theme.backgroundHighlight : "transparent"

    HoverHandler {
      id: headerHover
    }

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: 4
      spacing: 4

      StyledIcon {
        text: "drag_pan"
        opacity: 0.6
      }
      StyledText {
        Layout.fillWidth: true
        text: I18n.tr("Column {0}", root.column + 1)
        font.bold: true
        elide: Text.ElideRight
        textSize: Appearance.fontSize - 1
      }
      SquareIconButton {
        size: Widget.height - 6
        iconText: "close"
        iconSize: Appearance.fontSize - 1
        backgroundColor: "transparent"
        hoverColor: Theme.error
        tooltipText: I18n.tr("Remove column")
        visible: headerHover.hovered
        onClicked: root.dragLayer.editor.removeColumn(root.column)
      }
    }

    DragArea {
      id: headerArea
      anchors.fill: parent
      anchors.rightMargin: Widget.height
      onDragStarted: (x, y) => root.dragLayer.begin({
          "kind": "column-move",
          "column": root.column,
          "icon": "view_column",
          "label": I18n.tr("Column {0}", root.column + 1)
        }, headerArea, x, y)
      onDragMoved: (x, y) => root.dragLayer.move(headerArea, x, y)
      onDropped: root.dragLayer.end()
      onDragCanceled: root.dragLayer.cancel()
    }
  }

  // The cells, and the drop target (down to the bottom, so a drop below
  // the last cell appends)
  Item {
    id: body

    readonly property string targetKind: "column"
    readonly property int column: root.column
    readonly property bool hovered: root.dragLayer.hoverTarget === body

    // Before the first cell, in reading order, that the point is before
    // (above its row, or left of its middle within the row)
    function indexAt(point) {
      const p = root.dragLayer.mapToItem(body, point.x, point.y);
      const s = root.scaleFactor;
      const rects = root.flow.rects;
      for (let i = 0; i < rects.length; i++) {
        const r = rects[i];
        const rowBottom = Math.max(...rects.filter(o => o.row === r.row).map(o => o.y + o.height));
        if (p.y < r.y * s)
          return i;
        if (p.y < rowBottom * s && p.x < (r.x + r.width / 2) * s)
          return i;
      }
      return rects.length;
    }

    // The insertion bar's rect for a drop at `index` before a cell, kept
    // in the space between cells (the end zone shows a drop at the end)
    function barRect(index) {
      const s = root.scaleFactor;
      const rects = root.flow.rects;
      const gap = OverlayConfig.cardSpacing * s;
      if (index < 0 || index >= rects.length)
        return Qt.rect(0, 0, 0, 0);
      const r = rects[index];
      // First in its row: a bar across the top of the row
      if (r.x === 0) {
        const y = index === 0 ? -Widget.spacing / 2 : r.y * s - gap / 2;
        return Qt.rect(0, y - 1.5, root.flow.width * s, 3);
      }
      return Qt.rect(r.x * s - gap / 2 - 1.5, r.y * s, 3, r.height * s);
    }

    readonly property bool atEnd: body.hovered && root.dragLayer.hoverIndex >= root.cells.length

    y: root.headerHeight + Widget.spacing
    width: root.width
    height: root.height - body.y

    Component.onCompleted: root.dragLayer.registerTarget(body)
    Component.onDestruction: root.dragLayer.unregisterTarget(body)

    // Below the cells: a drop here adds at the end of the column. The
    // canvas leaves room for it under every column.
    Rectangle {
      y: root.flow.height * root.scaleFactor + Widget.spacing
      width: body.width
      height: root.endZone
      radius: Appearance.borderRadius
      visible: root.dragLayer.carryingModule || root.dragLayer.carryingCell
      color: body.atEnd ? Qt.alpha(Theme.accent, 0.2) : "transparent"
      border.color: body.atEnd ? Theme.accent : Qt.alpha(Theme.accent, 0.35)
      border.width: 1

      StyledIcon {
        anchors.centerIn: parent
        text: "add"
        textColor: body.atEnd ? Theme.accent : Theme.foreground
        textSize: Appearance.fontSize + 2
        opacity: body.atEnd ? 1 : 0.5
      }
    }

    // Keyed by count: edits update the cells in place
    Repeater {
      model: root.cells.length

      CanvasCell {
        id: cellItem
        required property int index
        readonly property var r: root.flow.rects[cellItem.index] ?? {
          "x": 0,
          "y": 0,
          "width": 0,
          "height": 0
        }
        dragLayer: root.dragLayer
        column: root.column
        cell: cellItem.index
        cellConfig: root.cells[cellItem.index]
        scaleFactor: root.scaleFactor
        x: cellItem.r.x * root.scaleFactor
        y: cellItem.r.y * root.scaleFactor
        width: cellItem.r.width * root.scaleFactor
        height: cellItem.r.height * root.scaleFactor
      }
    }

    Rectangle {
      readonly property rect r: body.barRect(root.dragLayer.hoverIndex)
      visible: body.hovered && !body.atEnd
      z: 3
      x: r.x
      y: r.y
      width: r.width
      height: r.height
      radius: 2
      color: Theme.accent
    }
  }
}
