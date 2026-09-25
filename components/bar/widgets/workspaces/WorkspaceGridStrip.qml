pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Hyprland

import qs.services
import qs.config
import qs.components.methods
import qs.components.hosts.popout
import qs.components.reusable

// The grid layout's switcher: this monitor's columns × rows workspaces, of
// which the bar shows the active row (horizontal bar) or column (vertical
// bar), and the popout the whole grid.
Item {
  id: root
  property var screen
  property var popouts
  property var panel
  property var barConfig
  property var properties

  readonly property bool isVertical: barConfig.vertical

  readonly property color activeColor: Theme.resolveColor(properties.activeColor)
  readonly property color occupiedColor: Theme.resolveColor(properties.occupiedColor)
  readonly property color emptyColor: Theme.resolveColor(properties.emptyColor)
  readonly property color iconColor: Theme.resolveColor(properties.textColor)

  readonly property HyprlandMonitor monitor: Hyprland.monitorFor(root.screen)
  readonly property int base: HyprlandManager.workspaceBase(root.monitor)
  readonly property int columns: WorkspacesConfig.columns
  readonly property int rows: WorkspacesConfig.rows
  readonly property int activeId: root.monitor?.activeWorkspace?.id ?? -1
  // The active workspace's place in the grid (the first cell when the
  // monitor is on a workspace outside it)
  readonly property int activeIndex: {
    const index = root.activeId - root.base;
    return index >= 0 && index < root.columns * root.rows ? index : 0;
  }
  readonly property int activeRow: Math.floor(root.activeIndex / root.columns)
  readonly property int activeColumn: root.activeIndex % root.columns

  readonly property real cell: root.barConfig.widgetSize
  readonly property real spacing: Widget.spacing / 2
  // Cells the bar shows: a row, or a column on a vertical bar
  readonly property int shown: root.isVertical ? root.rows : root.columns

  implicitWidth: root.isVertical ? root.cell : root.shown * root.cell + (root.shown - 1) * root.spacing
  implicitHeight: root.isVertical ? root.shown * root.cell + (root.shown - 1) * root.spacing : root.cell

  function wsById(id) {
    const arr = Hyprland.workspaces.values;
    for (let i = 0; i < arr.length; i++) {
      if (arr[i].id === id)
        return arr[i];
    }
    return null;
  }

  // Where the shown row (or column) sits among `count`: double arrows at the
  // ends, single ones between, a dot in the middle
  function positionGlyph(position, count) {
    const middle = (count - 1) / 2;
    if (position === middle)
      return "square";
    if (root.isVertical)
      return position === 0 ? "keyboard_double_arrow_left" : position === count - 1 ? "keyboard_double_arrow_right" : position < middle ? "keyboard_arrow_left" : "keyboard_arrow_right";
    return position === 0 ? "keyboard_double_arrow_up" : position === count - 1 ? "keyboard_double_arrow_down" : position < middle ? "keyboard_arrow_up" : "keyboard_arrow_down";
  }

  WheelHandler {
    enabled: root.properties.scrollToSwitch
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    property real _accumulated: 0
    onWheel: event => {
      _accumulated += event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
      if (Math.abs(_accumulated) < 120)
        return;
      const forward = _accumulated < 0;
      HyprlandManager.stepWorkspace(root.isVertical ? (forward ? "down" : "up") : (forward ? "right" : "left"), "go");
      _accumulated = 0;
    }
  }

  // The whole grid, shifted so the active row (or column) is in view
  Item {
    anchors.fill: parent
    clip: true

    Grid {
      columns: root.columns
      spacing: root.spacing
      x: root.isVertical ? -root.activeColumn * (root.cell + root.spacing) : 0
      y: root.isVertical ? 0 : -root.activeRow * (root.cell + root.spacing)

      Repeater {
        model: root.columns * root.rows

        Rectangle {
          id: cellBox
          required property int index
          readonly property int wsId: root.base + index
          readonly property HyprlandWorkspace ws: root.wsById(wsId)
          readonly property bool isActive: wsId === root.activeId
          readonly property bool hasWindows: (ws?.toplevels?.values?.length ?? 0) > 0
          // The active arrow takes the active cell's place
          readonly property bool showsArrow: isActive && root.properties.showActiveIcon
          readonly property var biggestWindow: root.properties.showAppIcons && hasWindows && !showsArrow ? HyprlandManager.biggestWindowForWorkspace(wsId) : null
          readonly property string iconPath: biggestWindow ? IconResolver.resolveWindowIcon(biggestWindow.class, biggestWindow.title) : ""

          width: root.cell
          height: root.cell
          radius: Appearance.borderRadius
          color: isActive ? root.activeColor : cellArea.containsMouse ? Theme.backgroundHighlight : hasWindows ? root.occupiedColor : root.emptyColor

          StyledIcon {
            anchors.centerIn: parent
            text: root.isVertical ? root.positionGlyph(root.activeColumn, root.columns) : root.positionGlyph(root.activeRow, root.rows)
            font.pixelSize: Appearance.fontSize * 1.2
            visible: cellBox.showsArrow
            color: root.iconColor
          }

          Image {
            anchors.centerIn: parent
            width: root.cell * 0.65
            height: width
            sourceSize: Qt.size(64, 64)
            source: cellBox.iconPath
            visible: cellBox.iconPath !== ""
          }

          // Its place in the grid, counted from 1
          StyledText {
            anchors.centerIn: parent
            visible: root.properties.labels === "numbers" && !cellBox.showsArrow && cellBox.iconPath === ""
            text: cellBox.index + 1
            textColor: cellBox.isActive || cellBox.hasWindows ? root.iconColor : Theme.foreground
            textSize: Appearance.fontSize - 1
          }

          MouseArea {
            id: cellArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: root.properties.clickToSwitch
            cursorShape: Qt.PointingHandCursor
            onClicked: HyprlandManager.goToWorkspace(cellBox.wsId)
          }

          Behavior on color {
            ColorAnimation {
              duration: Appearance.animFast
            }
          }
        }
      }
    }
  }

  PopoutAnchor {
    popouts: root.popouts
    panel: root.panel
    popoutName: "WorkspaceGrid"
    active: root.properties.showPopout
    extraData: ({
        monitor: root.monitor,
        vertical: root.isVertical,
        cellSize: root.cell,
        properties: root.properties
      })
  }
}
