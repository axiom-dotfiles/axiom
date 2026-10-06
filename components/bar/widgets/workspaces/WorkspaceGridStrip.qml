pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Hyprland

import qs.services
import qs.config
import qs.components.methods
import qs.components.reusable
import qs.components.hosts.popout

// The grid layout's switcher: this monitor's columns × rows workspaces, of
// which the bar shows the active row (horizontal bar) or column (vertical
// bar), and the popout the whole grid. As in the standard layout's
// switcher, the active cell is twice as long with `wideActive`, and on a
// strip monitor the active workspace's windows follow in strip order
// (ActiveStrip), where scrolling scrolls the strip. Moving to another row
// (column) cross-fades the bar's to it.
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
  // The row (column on a vertical bar) the bar shows
  readonly property int activeLine: root.isVertical ? root.activeColumn : root.activeRow
  // The workspace whose cell is hovered, which its box (drawn apart from
  // it) shows
  property int hoveredId: -1

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

  // A workspace's place in the grid, or -1 outside it
  function placeOf(id) {
    const place = id - root.base;
    return place >= 0 && place < root.columns * root.rows ? place : -1;
  }

  // Bar.cellColors for a workspace's cell, active or at rest
  function cellLook(id, active) {
    const ws = root.wsById(id);
    const occupied = (ws?.toplevels.values.length ?? 0) > 0;
    return Bar.cellColors(root.barConfig, active ? root.activeColor : occupied ? root.occupiedColor : root.emptyColor, active || occupied ? root.iconColor : Theme.foreground, active ? "active" : occupied ? "occupied" : "empty");
  }

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
    CrossFade {
      value: root.activeLine
      delegate: shownLine
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

  // A row (column) of the grid: the cells' boxes at rest, the active one's
  // sliding over them, then their labels and icons over both
  Component {
    id: shownLine

    Item {
      id: line
      // The row (column)
      required property var value
      // The active workspace while it's in this line or outside the grid:
      // a line fading out keeps showing the one it had (`_kept`)
      readonly property bool _holds: {
        const place = root.placeOf(root.activeId);
        return place < 0 || (root.isVertical ? place % root.columns : Math.floor(place / root.columns)) === line.value;
      }
      property int _kept: -1
      readonly property int activeHere: _holds ? root.activeId : _kept
      onActiveHereChanged: _kept = activeHere
      Component.onCompleted: _kept = activeHere
      readonly property bool wide: root.properties.wideActive

      implicitWidth: cells.implicitWidth
      implicitHeight: cells.implicitHeight

      function placeAt(index) {
        return root.isVertical ? index * root.columns + line.value : line.value * root.columns + index;
      }

      Connections {
        target: HyprlandManager
        function onWorkspaceWrapped(monitor, alongRow, forward) {
          if (monitor === (root.monitor?.name ?? "") && alongRow !== root.isVertical)
            indicator.expectWrap(forward);
        }
      }

      Grid {
        rows: cells.rows
        columns: cells.columns
        spacing: cells.spacing

        Repeater {
          model: root.shown

          WorkspaceCell {
            required property int index
            readonly property int wsId: root.base + line.placeAt(index)

            part: "background"
            barConfig: root.barConfig
            isActive: wsId === line.activeHere
            indicated: indicator.slides
            lit: wsId === root.hoveredId
            look: root.cellLook(wsId, isActive && !indicator.slides)
            thickness: root.cell
            restLength: root.cellLength
            length: root.cellLength * (isActive && line.wide ? 2 : 1)
            radius: root.cellRadius
          }
        }
      }

      ActiveCellIndicator {
        id: indicator
        barConfig: root.barConfig
        look: Bar.cellColors(root.barConfig, root.activeColor, root.iconColor, "active")
        // None while the monitor is on a workspace outside the grid
        readonly property int _place: root.placeOf(line.activeHere)
        index: _place < 0 ? -1 : root.isVertical ? Math.floor(_place / root.columns) : _place % root.columns
        thickness: root.cell
        restLength: root.cellLength
        activeLength: root.cellLength * (line.wide ? 2 : 1)
        spacing: root.spacing
        radius: root.cellRadius
      }

      Grid {
        id: cells
        rows: root.isVertical ? root.shown : 1
        columns: root.isVertical ? 1 : root.shown
        spacing: root.spacing

        Repeater {
          model: root.shown

          WorkspaceCell {
            required property int index
            // Its place in the grid
            readonly property int place: line.placeAt(index)
            readonly property int wsId: root.base + place
            readonly property HyprlandWorkspace ws: root.wsById(wsId)
            readonly property bool hasWindows: (ws?.toplevels.values.length ?? 0) > 0
            // The active arrow takes the active cell's place
            readonly property bool showsArrow: isActive && root.properties.showActiveIcon
            readonly property var biggestWindow: root.properties.showAppIcons && hasWindows && !showsArrow ? HyprlandManager.biggestWindowForWorkspace(wsId) : null

            part: "content"
            barConfig: root.barConfig
            isActive: wsId === line.activeHere
            look: root.cellLook(wsId, isActive)
            thickness: root.cell
            restLength: root.cellLength
            length: root.cellLength * (isActive && line.wide ? 2 : 1)
            radius: root.cellRadius
            labels: root.properties.labels
            // The workspace id, or its place in the grid counted from 1
            label: root.properties.relativeNumbers ? place + 1 : wsId
            glyph: showsArrow ? root.positionGlyph(line.value, root.isVertical ? root.columns : root.rows) : ""
            iconPath: biggestWindow ? IconResolver.resolveWindowIcon(biggestWindow.class, biggestWindow.title) : ""
            clickable: root.properties.clickToSwitch
            onClicked: HyprlandManager.goToWorkspace(wsId, "go", root.monitor)
            onHoveredChanged: {
              if (hovered)
                root.hoveredId = wsId;
              else if (root.hoveredId === wsId)
                root.hoveredId = -1;
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
