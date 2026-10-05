pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Hyprland

import qs.services
import qs.config
import qs.components.content.base
import qs.components.bar.widgets.workspaces

// The Workspaces bar widget's popout on a strip monitor: each of the
// monitor's workspaces with windows (and the active one) as its number
// cell followed by its windows in strip order (StripWindows), one line
// per workspace across the bar. Cells are the bar's (WorkspaceCell, in its
// widget style and the widget's colors): click a number to go to that
// workspace, a window to focus it.
Panel {
  id: root

  // From the widget's payload (BarPopouts copies it onto these, and the
  // widget's options onto `properties`, once the popout has loaded: until
  // then `properties` is empty, hence the few `??` below)
  property HyprlandMonitor monitor: null
  property bool vertical: false
  property bool stripVertical: false
  property real cellSize: Widget.height
  // Along the bar (narrower than cellSize for dots without a box)
  property real cellLength: cellSize
  // The bar's config, so the cells take its widget style
  property var barConfig: null
  // The bar's inner spacing, so the gaps match its row
  property real cellSpacing: Widget.spacing
  // The bar's, so the cells match its row
  property real radius: Widget.radius

  readonly property color activeColor: Theme.resolveColor(root.properties.activeColor)
  readonly property color occupiedColor: Theme.resolveColor(root.properties.occupiedColor)
  readonly property color textColor: Theme.resolveColor(root.properties.textColor)
  readonly property int base: HyprlandManager.workspaceBase(root.monitor)
  readonly property int activeId: root.monitor?.activeWorkspace?.id ?? -1
  // A string, so the lines are only rebuilt when the set of workspaces
  // shown changes, not on every Hyprland event
  readonly property string _idsKey: HyprlandManager.workspaceIds(root.monitor).filter(id => id === root.activeId || HyprlandManager.windowList.some(w => w.workspace?.id === id)).join(",")
  readonly property var ids: root._idsKey === "" ? [] : root._idsKey.split(",").map(Number)

  implicitWidth: lines.implicitWidth + margins * 2

  // The payload and `properties` land just after creation (BarPopouts'
  // onLoaded), so the cells first bind to fallbacks: animate only once
  // they've settled, or the opening cells fade in from the wrong color
  property bool _settled: false
  Component.onCompleted: Qt.callLater(() => root._settled = true)

  // Lines stacked across the bar: rows under a horizontal bar, columns
  // beside a vertical one
  Grid {
    id: lines
    rows: root.vertical ? 1 : Math.max(1, root.ids.length)
    columns: root.vertical ? Math.max(1, root.ids.length) : 1
    spacing: root.cellSpacing

    Repeater {
      // None until the payload brings the bar's style
      model: root.barConfig ? root.ids.length : 0

      Grid {
        id: line
        required property int index
        readonly property int wsId: root.ids[index] ?? 0
        readonly property bool isActive: wsId === root.activeId

        rows: root.vertical ? 2 : 1
        columns: root.vertical ? 1 : 2
        spacing: root.cellSpacing

        WorkspaceCell {
          barConfig: root.barConfig
          isActive: line.isActive
          look: Bar.cellColors(root.barConfig, line.isActive ? root.activeColor : root.occupiedColor, root.textColor, line.isActive ? "active" : "occupied")
          thickness: root.cellSize
          length: root.cellLength
          radius: root.radius
          labels: root.properties.labels
          // The workspace id, or its number on this monitor, as on the bar
          label: root.properties.relativeNumbers ? line.wsId - root.base + 1 : line.wsId
          clickable: root.properties.clickToSwitch ?? false
          animated: root._settled
          onClicked: HyprlandManager.goToWorkspace(line.wsId, "go", root.monitor)
        }

        StripWindows {
          barConfig: root.barConfig
          workspaceId: line.wsId
          stripVertical: root.stripVertical
          isVertical: root.vertical
          thickness: root.cellSize
          cellLength: root.cellSize
          radius: root.radius
          activeColor: root.activeColor
          occupiedColor: root.occupiedColor
          textColor: root.textColor
          clickable: root.properties.clickToSwitch ?? false
          animated: root._settled
        }
      }
    }
  }
}
