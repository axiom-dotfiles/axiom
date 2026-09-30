pragma ComponentBehavior: Bound
import QtQuick

import qs.config
import qs.services
import qs.components.hosts.overlay

// An edge menu's modules: its columns side by side, as on a Custom overlay
// page, with cards of the menu's own cardSize, every cell grown by its
// `extraWidth`/`extraHeight`. Along the edge it's capped at `maxLength` and
// scrolls past that.
Item {
  id: root

  required property var menu
  required property bool vertical
  // Room along the edge
  property real maxLength: 0

  // Columns re-read only when they actually change, so an unrelated config
  // save doesn't rebuild every module
  readonly property string _columnsKey: JSON.stringify(root.menu.columns)
  property var columns: []
  on_ColumnsKeyChanged: root.columns = JSON.parse(root._columnsKey)
  Component.onCompleted: root.columns = JSON.parse(root._columnsKey)

  // `bare`: the menu hides its modules' card boxes (moduleBorders off)
  readonly property var host: ({
      "kind": "edgeMenu",
      "id": root.menu.id,
      "bare": !root.menu.moduleBorders
    })

  OverlayGrid {
    id: grid
    fixedUnit: root.menu.cardSize
  }

  // `extraWidth` and `extraHeight` grow every cell (OverlayConfig.columnFlow's
  // `extra`): the columns share the width, each gets all the height. Fill
  // cells (its `target`) then take all the room along the edge (on a
  // top/bottom edge the spare width is shared by the columns holding a
  // fillWidth cell) and fillHeight cells grow across it to the thickest
  // column. `anyFill` (the menu takes its whole edge) counts only cells
  // filling along the edge: fillHeight on a left/right edge, fillWidth on
  // a top/bottom one.
  readonly property var _natural: root.columns.map(column => grid.columnFlow(column?.cells))
  readonly property string _alongKey: root.vertical ? "fillHeight" : "fillWidth"
  readonly property var _fillColumns: root.columns.map(column => (column?.cells ?? []).some(cell => cell?.[root._alongKey] === true))
  readonly property bool anyFill: root._fillColumns.includes(true)
  readonly property int _fillCount: root._fillColumns.filter(fills => fills).length
  readonly property real extraWidth: root.columns.length > 0 ? Math.max(0, root.menu.extraWidth) : 0
  readonly property real extraHeight: root.columns.length > 0 ? Math.max(0, root.menu.extraHeight) : 0
  readonly property real _columnExtraWidth: root.extraWidth / Math.max(1, root.columns.length)
  readonly property var _extra: ({
      "width": root._columnExtraWidth,
      "height": root.extraHeight
    })
  readonly property real _sideBySide: root._natural.reduce((sum, flow) => sum + flow.width, 0) + root.extraWidth + Math.max(0, root.columns.length - 1) * OverlayConfig.cardSpacing
  readonly property real _thickest: Math.max(0, ...root._natural.map(flow => flow.height)) + root.extraHeight
  // Along the edge before fill cells grow or the cap applies
  readonly property real naturalLength: root.vertical ? root._thickest : root._sideBySide
  readonly property real _spareLength: root.anyFill && root.maxLength > root.naturalLength ? root.maxLength - root.naturalLength : 0
  function targetFor(index) {
    if (!root._natural[index])
      return null;
    if (root.vertical)
      return {
        "height": root.naturalLength + root._spareLength
      };
    return {
      "width": root._natural[index].width + root._columnExtraWidth + (root._fillColumns[index] ? root._spareLength / root._fillCount : 0),
      "height": root._thickest
    };
  }

  readonly property real contentLength: root.vertical ? row.implicitHeight : row.implicitWidth
  readonly property real length: root.maxLength > 0 ? Math.min(root.contentLength, root.maxLength) : root.contentLength

  // Escape closes the menu once it has the keyboard (both hosts take it
  // on demand, when clicked)
  focus: true
  Keys.onEscapePressed: EdgeMenuManager.close(root.menu.id)

  implicitWidth: root.vertical ? row.implicitWidth : root.length
  implicitHeight: root.vertical ? root.length : row.implicitHeight

  Flickable {
    anchors.fill: parent
    contentWidth: row.implicitWidth
    contentHeight: row.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    interactive: root.contentLength > root.length

    Row {
      id: row
      spacing: OverlayConfig.cardSpacing

      Repeater {
        model: root.columns.length

        OverlayColumn {
          required property int index
          columnConfig: root.columns[index]
          grid: grid
          target: root.targetFor(index)
          extra: root._extra
          host: root.host
        }
      }
    }
  }
}
