pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Hyprland

import qs.services
import qs.config
import qs.components.methods
import qs.components.reusable
import qs.components.content.base

// The Workspaces bar widget's popout in the grid layout: the monitor's
// whole columns × rows grid, with the row (or column, on a vertical bar)
// the bar shows at full strength. Cells match the bar's (size, colors,
// labels, app icons, click to switch: the widget's `properties`), so it
// reads as the bar row expanded.
Panel {
  id: root

  // From the widget's payload (BarPopouts copies it onto these, and the
  // widget's options onto `properties`, once the popout has loaded: until
  // then `properties` is empty, hence the few `??` below)
  property HyprlandMonitor monitor: null
  property bool vertical: false
  property real cellSize: Widget.height
  // The bar's, so the cells match its row
  property real radius: Widget.radius
  property int fontSize: Appearance.fontSize

  readonly property color activeColor: Theme.resolveColor(root.properties.activeColor)
  readonly property color occupiedColor: Theme.resolveColor(root.properties.occupiedColor)
  readonly property color emptyColor: Theme.resolveColor(root.properties.emptyColor)
  readonly property color textColor: Theme.resolveColor(root.properties.textColor)
  readonly property int base: HyprlandManager.workspaceBase(root.monitor)
  // Not `cols`/`rows`: those are Panel's slot size
  readonly property int gridColumns: WorkspacesConfig.columns
  readonly property int gridRows: WorkspacesConfig.rows
  readonly property int activeId: root.monitor?.activeWorkspace?.id ?? -1
  readonly property int activeIndex: {
    const index = root.activeId - root.base;
    return index >= 0 && index < root.gridColumns * root.gridRows ? index : 0;
  }

  implicitWidth: grid.implicitWidth + margins * 2

  function wsById(id) {
    return Hyprland.workspaces.values.find(ws => ws.id === id) ?? null;
  }

  Grid {
    id: grid
    columns: root.gridColumns
    spacing: root.properties.spacing ?? 0

    Repeater {
      model: root.gridColumns * root.gridRows

      Rectangle {
        id: wsCell
        required property int index

        readonly property int wsId: root.base + index
        readonly property var workspace: root.wsById(wsId)
        readonly property bool isActive: wsId === root.activeId
        readonly property bool hasWindows: (workspace?.toplevels?.values?.length ?? 0) > 0
        // In the row (or column) the bar shows
        readonly property bool inBar: root.vertical ? index % root.gridColumns === root.activeIndex % root.gridColumns : Math.floor(index / root.gridColumns) === Math.floor(root.activeIndex / root.gridColumns)
        readonly property var windowData: root.properties.showAppIcons && hasWindows ? HyprlandManager.biggestWindowForWorkspace(wsId) : null
        readonly property string iconPath: windowData ? IconResolver.resolveWindowIcon(windowData.class, windowData.title) : ""

        width: root.cellSize
        height: root.cellSize
        radius: root.radius
        color: isActive ? root.activeColor : cellArea.containsMouse ? Theme.backgroundHighlight : hasWindows ? root.occupiedColor : root.emptyColor
        opacity: inBar ? 1.0 : 0.85

        Image {
          anchors.centerIn: parent
          width: parent.width * 0.65
          height: width
          sourceSize: Qt.size(64, 64)
          source: wsCell.iconPath
          visible: wsCell.iconPath !== ""
        }

        // The workspace id, or its place in the grid counted from 1, as on the bar
        StyledText {
          anchors.centerIn: parent
          visible: root.properties.labels === "numbers" && wsCell.iconPath === ""
          text: root.properties.relativeNumbers ? wsCell.index + 1 : wsCell.wsId
          textColor: wsCell.isActive || wsCell.hasWindows ? root.textColor : Theme.foreground
          textSize: root.fontSize - 1
        }

        MouseArea {
          id: cellArea
          anchors.fill: parent
          hoverEnabled: true
          enabled: root.properties.clickToSwitch ?? false
          cursorShape: Qt.PointingHandCursor
          onClicked: HyprlandManager.goToWorkspace(wsCell.wsId, "go", root.monitor)
        }

        Behavior on color {
          ColorAnimation {
            duration: Appearance.animNormal
          }
        }

        Behavior on opacity {
          NumberAnimation {
            duration: Appearance.animNormal
          }
        }
      }
    }
  }
}
