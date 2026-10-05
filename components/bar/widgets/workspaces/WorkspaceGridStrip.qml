pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Hyprland

import qs.services
import qs.config
import qs.components.methods
import qs.components.hosts.popout

// The grid layout's switcher: this monitor's columns × rows workspaces, of
// which the bar shows the active row (horizontal bar) or column (vertical
// bar), and the popout the whole grid. As in the standard layout's
// switcher, the active cell is twice as long with `wideActive`, and on a
// strip monitor the active workspace's windows follow in strip order
// (ActiveStrip), where scrolling scrolls the strip.
Item {
  id: root
  property var screen
  property var popouts
  property var panel
  property var barConfig
  property var properties
  // Room kept to the widget's background across the bar
  property real inset: 0

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
  // "horizontal" | "vertical" on a strip monitor, else ""
  readonly property string stripDirection: WorkspacesConfig.stripDirection(root.screen?.name ?? "")
  // The active workspace's place in the grid (the first cell when the
  // monitor is on a workspace outside it)
  readonly property int activeIndex: {
    const index = root.activeId - root.base;
    return index >= 0 && index < root.columns * root.rows ? index : 0;
  }
  readonly property int activeRow: Math.floor(root.activeIndex / root.columns)
  readonly property int activeColumn: root.activeIndex % root.columns

  // A cell's size on the bar (inside the background), and its corners
  // within the background's
  readonly property real cell: root.barConfig.widgetSize - root.inset * 2
  readonly property real cellRadius: Math.max(0, root.barConfig.radius - root.inset)
  readonly property real spacing: root.barConfig.widgetSpacing
  // Along the bar: square, or narrower for dots straight on the bar
  readonly property real cellLength: ["filled", "tinted", "outline"].includes(root.barConfig.widgetStyle) || root.properties.labels !== "dots" || root.properties.showAppIcons ? root.cell : Math.round(root.cell * 0.6)
  // Cells the bar shows: a row, or a column on a vertical bar
  readonly property int shown: root.isVertical ? root.rows : root.columns

  implicitWidth: layout.implicitWidth
  implicitHeight: layout.implicitHeight

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
      return "circle";
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
      if (root.stripDirection !== "")
        HyprlandManager.stepStrip(forward ? 1 : -1, root.monitor);
      else
        HyprlandManager.stepWorkspace(root.isVertical ? (forward ? "down" : "up") : (forward ? "right" : "left"), "go");
      _accumulated = 0;
    }
  }

  Grid {
    id: layout
    rows: root.isVertical ? 2 : 1
    columns: root.isVertical ? 1 : 2
    spacing: root.spacing

    // The active row (or column) of the grid
    Grid {
      rows: root.isVertical ? root.shown : 1
      columns: root.isVertical ? 1 : root.shown
      spacing: root.spacing

      Repeater {
        model: root.shown

        WorkspaceCell {
          required property int index
          // Its place in the grid
          readonly property int place: root.isVertical ? index * root.columns + root.activeColumn : root.activeRow * root.columns + index
          readonly property int wsId: root.base + place
          readonly property HyprlandWorkspace ws: root.wsById(wsId)
          readonly property bool hasWindows: (ws?.toplevels.values.length ?? 0) > 0
          // The active arrow takes the active cell's place
          readonly property bool showsArrow: isActive && root.properties.showActiveIcon
          readonly property var biggestWindow: root.properties.showAppIcons && hasWindows && !showsArrow ? HyprlandManager.biggestWindowForWorkspace(wsId) : null

          barConfig: root.barConfig
          isActive: wsId === root.activeId
          look: Bar.cellColors(root.barConfig, isActive ? root.activeColor : hasWindows ? root.occupiedColor : root.emptyColor, isActive || hasWindows ? root.iconColor : Theme.foreground, isActive ? "active" : hasWindows ? "occupied" : "empty")
          thickness: root.cell
          restLength: root.cellLength
          length: root.cellLength * (isActive && root.properties.wideActive ? 2 : 1)
          radius: root.cellRadius
          labels: root.properties.labels
          // The workspace id, or its place in the grid counted from 1
          label: root.properties.relativeNumbers ? place + 1 : wsId
          glyph: showsArrow ? (root.isVertical ? root.positionGlyph(root.activeColumn, root.columns) : root.positionGlyph(root.activeRow, root.rows)) : ""
          iconPath: biggestWindow ? IconResolver.resolveWindowIcon(biggestWindow.class, biggestWindow.title) : ""
          clickable: root.properties.clickToSwitch
          onClicked: HyprlandManager.goToWorkspace(wsId, "go", root.monitor)
        }
      }
    }

    Loader {
      active: root.stripDirection !== ""
      visible: (item as ActiveStrip)?.hasWindows ?? false

      sourceComponent: ActiveStrip {
        barConfig: root.barConfig
        workspaceId: root.activeId
        stripVertical: root.stripDirection === "vertical"
        cell: root.cell
        cellRadius: root.cellRadius
        activeColor: root.activeColor
        occupiedColor: root.occupiedColor
        textColor: root.iconColor
        clickable: root.properties.clickToSwitch
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
        // The cells' own size and corners, as on the bar
        cellSize: root.cell,
        cellLength: root.cellLength,
        barConfig: root.barConfig,
        cellSpacing: root.spacing,
        radius: root.cellRadius,
        fontSize: root.barConfig.fontSize,
        properties: root.properties
      })
  }
}
