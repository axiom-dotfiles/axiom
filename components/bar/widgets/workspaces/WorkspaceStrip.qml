pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Hyprland

import qs.services
import qs.config
import qs.components.methods
import qs.components.reusable

// The standard layout's switcher: workspaces 1..count in a row (horizontal
// bar) or column (vertical bar); click one to go there, scroll to step
// through them.
Item {
  id: root
  property var screen
  property var barConfig
  property var properties

  readonly property bool isVertical: barConfig.vertical

  readonly property color activeColor: Theme.resolveColor(properties.activeColor)
  readonly property color occupiedColor: Theme.resolveColor(properties.occupiedColor)
  readonly property color emptyColor: Theme.resolveColor(properties.emptyColor)
  readonly property color textColor: Theme.resolveColor(properties.textColor)

  readonly property HyprlandMonitor monitor: Hyprland.monitorFor(root.screen)
  readonly property int activeId: root.monitor?.activeWorkspace?.id ?? -1
  readonly property int base: HyprlandManager.workspaceBase(root.monitor)

  // A string, so the cells are only rebuilt when the set of workspaces
  // shown changes, not on every Hyprland event
  readonly property string _idsKey: {
    const ids = [];
    for (const id of HyprlandManager.workspaceIds(root.monitor)) {
      const ws = root.wsById(id);
      if (root.properties.monitorOnly && ws?.monitor && root.monitor && ws.monitor.id !== root.monitor.id)
        continue;
      if (!root.properties.showEmpty && id !== root.activeId && !root.hasWindows(ws))
        continue;
      ids.push(id);
    }
    return ids.join(",");
  }
  readonly property var ids: root._idsKey === "" ? [] : root._idsKey.split(",").map(Number)

  implicitWidth: cells.implicitWidth
  implicitHeight: cells.implicitHeight

  function wsById(id) {
    const arr = Hyprland.workspaces.values;
    for (let i = 0; i < arr.length; i++) {
      if (arr[i].id === id)
        return arr[i];
    }
    return null;
  }

  function hasWindows(ws) {
    return (ws?.toplevels?.values?.length ?? 0) > 0;
  }

  // Next/previous shown workspace, wrapping at the ends
  function step(direction) {
    if (root.ids.length === 0)
      return;
    const current = root.ids.indexOf(root.activeId);
    const next = current < 0 ? (direction > 0 ? 0 : root.ids.length - 1) : (current + direction + root.ids.length) % root.ids.length;
    HyprlandManager.goToWorkspace(root.ids[next], "go", root.monitor);
  }

  WheelHandler {
    enabled: root.properties.scrollToSwitch
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    property real _accumulated: 0
    onWheel: event => {
      _accumulated += event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
      if (Math.abs(_accumulated) < 120)
        return;
      root.step(_accumulated > 0 ? -1 : 1);
      _accumulated = 0;
    }
  }

  Grid {
    id: cells
    anchors.centerIn: parent
    flow: root.isVertical ? Grid.TopToBottom : Grid.LeftToRight
    rows: root.isVertical ? Math.max(1, root.ids.length) : 1
    columns: root.isVertical ? 1 : Math.max(1, root.ids.length)
    spacing: root.properties.spacing

    Repeater {
      model: root.ids.length

      Rectangle {
        id: cell
        required property int index
        readonly property int wsId: root.ids[index] ?? 0
        readonly property HyprlandWorkspace ws: root.wsById(wsId)
        readonly property bool isActive: wsId === root.activeId
        readonly property bool occupied: root.hasWindows(ws)
        readonly property real length: root.barConfig.widgetSize * (isActive && root.properties.wideActive ? 2 : 1)
        readonly property var biggestWindow: root.properties.showAppIcons && occupied ? HyprlandManager.biggestWindowForWorkspace(wsId) : null
        readonly property string iconPath: biggestWindow ? IconResolver.resolveWindowIcon(biggestWindow.class, biggestWindow.title) : ""

        width: root.isVertical ? root.barConfig.widgetSize : length
        height: root.isVertical ? length : root.barConfig.widgetSize
        radius: root.barConfig.radius
        color: isActive ? root.activeColor : cellArea.containsMouse ? Theme.backgroundHighlight : occupied ? root.occupiedColor : root.emptyColor

        Image {
          anchors.centerIn: parent
          width: root.barConfig.widgetSize * 0.65
          height: width
          sourceSize: Qt.size(64, 64)
          source: cell.iconPath
          visible: cell.iconPath !== ""
        }

        StyledText {
          anchors.centerIn: parent
          visible: root.properties.labels === "numbers" && cell.iconPath === ""
          text: root.properties.relativeNumbers ? cell.wsId - root.base + 1 : cell.wsId
          textColor: cell.isActive || cell.occupied ? root.textColor : Theme.foreground
          textSize: root.barConfig.fontSize - 1
        }

        MouseArea {
          id: cellArea
          anchors.fill: parent
          enabled: root.properties.clickToSwitch
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: HyprlandManager.goToWorkspace(cell.wsId, "go", root.monitor)
        }

        Behavior on width {
          NumberAnimation {
            duration: Appearance.animFast
            easing.type: Easing.OutCubic
          }
        }
        Behavior on height {
          NumberAnimation {
            duration: Appearance.animFast
            easing.type: Easing.OutCubic
          }
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
