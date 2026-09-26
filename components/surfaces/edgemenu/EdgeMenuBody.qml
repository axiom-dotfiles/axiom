pragma ComponentBehavior: Bound
import QtQuick

import qs.config
import qs.services
import qs.components.hosts.overlay

// An edge menu's modules: its columns side by side, as on a Custom overlay
// page, with cards of the menu's own cardSize. Along the edge it's capped
// at `maxLength` and scrolls past that.
Item {
  id: root

  required property var menu
  required property bool vertical
  // Room along the edge
  property real maxLength: 0

  // Columns re-read only when they actually change, so an unrelated config
  // save doesn't rebuild every module
  readonly property string _columnsKey: JSON.stringify(root.menu?.columns ?? [])
  property var columns: []
  on_ColumnsKeyChanged: root.columns = JSON.parse(root._columnsKey)
  Component.onCompleted: root.columns = JSON.parse(root._columnsKey)

  readonly property var host: ({
      "kind": "edgeMenu",
      "id": root.menu?.id ?? ""
    })

  OverlayGrid {
    id: grid
    fixedUnit: root.menu?.cardSize ?? OverlayConfig.minCardUnit
  }

  // Fill cells (see OverlayConfig.columnFlow): with any, the menu takes all
  // the room along its edge. On a left/right edge that's column height; on
  // a top/bottom one the spare width is shared by the columns holding one.
  // Across the edge they grow to the thickest column.
  readonly property var _natural: root.columns.map(column => grid.columnFlow(column?.cells))
  readonly property var _fillColumns: root.columns.map(column => (column?.cells ?? []).some(cell => cell?.fill === true))
  readonly property bool anyFill: root._fillColumns.includes(true)
  readonly property real _naturalLength: root.vertical ? Math.max(0, ...root._natural.map(flow => flow.height)) : root._natural.reduce((sum, flow) => sum + flow.width, 0) + Math.max(0, root.columns.length - 1) * OverlayConfig.cardSpacing
  readonly property real _spare: root.anyFill && root.maxLength > root._naturalLength ? root.maxLength - root._naturalLength : 0
  readonly property int _fillCount: root._fillColumns.filter(fills => fills).length
  function targetFor(index) {
    const natural = root._natural[index];
    if (!natural)
      return null;
    if (root.vertical)
      return {
        "height": root._naturalLength + root._spare
      };
    return {
      "width": natural.width + (root._fillColumns[index] ? root._spare / root._fillCount : 0),
      "height": Math.max(0, ...root._natural.map(flow => flow.height))
    };
  }

  readonly property real contentLength: root.vertical ? row.implicitHeight : row.implicitWidth
  readonly property real length: root.maxLength > 0 ? Math.min(root.contentLength, root.maxLength) : root.contentLength

  // Escape closes the menu once it has the keyboard (both hosts take it
  // on demand, when clicked)
  focus: true
  Keys.onEscapePressed: EdgeMenuManager.close(root.menu?.id ?? "")

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
          host: root.host
        }
      }
    }
  }
}
