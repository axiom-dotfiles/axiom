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

  readonly property HyprlandMonitor monitor: wrapper?.currentData?.monitor ?? null
  readonly property bool vertical: wrapper?.currentData?.vertical ?? false
  readonly property real cell: wrapper?.currentData?.cellSize ?? Widget.height
  // The widget's options
  readonly property var options: wrapper?.currentData?.properties ?? ({})
  readonly property color activeColor: Theme.resolveColor(options.activeColor ?? "accent")
  readonly property color occupiedColor: Theme.resolveColor(options.occupiedColor ?? "border")
  readonly property color emptyColor: Theme.resolveColor(options.emptyColor ?? "backgroundAlt")
  readonly property color textColor: Theme.resolveColor(options.textColor ?? "background")
  readonly property int base: HyprlandManager.workspaceBase(root.monitor)
  readonly property int columns: WorkspacesConfig.columns
  readonly property int rows: WorkspacesConfig.rows
  readonly property int activeId: root.monitor?.activeWorkspace?.id ?? -1
  readonly property int activeIndex: {
    const index = root.activeId - root.base;
    return index >= 0 && index < root.columns * root.rows ? index : 0;
  }
  readonly property real cellSpacing: Widget.spacing / 2

  margins: 10
  implicitWidth: grid.implicitWidth + margins * 2

  function wsById(id) {
    const arr = Hyprland.workspaces.values;
    for (let i = 0; i < arr.length; i++) {
      if (arr[i].id === id)
        return arr[i];
    }
    return null;
  }

  Grid {
    id: grid
    columns: root.columns
    spacing: root.cellSpacing

    Repeater {
      model: root.columns * root.rows

      Rectangle {
        id: wsCell
        required property int index

        readonly property int wsId: root.base + index
        readonly property var workspace: root.wsById(wsId)
        readonly property bool isActive: wsId === root.activeId
        readonly property bool hasWindows: (workspace?.toplevels?.values?.length ?? 0) > 0
        // In the row (or column) the bar shows
        readonly property bool inBar: root.vertical ? index % root.columns === root.activeIndex % root.columns : Math.floor(index / root.columns) === Math.floor(root.activeIndex / root.columns)
        readonly property var windowData: root.options.showAppIcons && hasWindows ? HyprlandManager.biggestWindowForWorkspace(wsId) : null
        readonly property string iconPath: windowData ? IconResolver.resolveWindowIcon(windowData.class, windowData.title) : ""

        width: root.cell
        height: root.cell
        radius: Appearance.borderRadius
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

        // Its place in the grid, counted from 1, as on the bar
        StyledText {
          anchors.centerIn: parent
          visible: root.options.labels === "numbers" && wsCell.iconPath === ""
          text: wsCell.index + 1
          textColor: wsCell.isActive || wsCell.hasWindows ? root.textColor : Theme.foreground
          textSize: Appearance.fontSize - 1
        }

        MouseArea {
          id: cellArea
          anchors.fill: parent
          hoverEnabled: true
          enabled: root.options.clickToSwitch ?? true
          cursorShape: Qt.PointingHandCursor
          onClicked: HyprlandManager.goToWorkspace(wsCell.wsId)
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
