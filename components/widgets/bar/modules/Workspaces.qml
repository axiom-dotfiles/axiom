import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland

import qs.services
import qs.config

Item {
  id: root
  property var screen
  property var popouts
  property var panel
  property var barConfig

  property bool isVertical: barConfig.vertical

  property color activeColor: Theme.accent
  property color inactiveColor: Theme.foregroundAlt
  property color emptyColor: Theme.backgroundAlt

  property HyprlandMonitor monitor: Hyprland.monitorFor(root.screen)

  // Base ID for this monitor's 25-workspace range - calculate from monitor index
  readonly property int workspaceBase: {
    if (!monitor) return 1;
    
    const monitors = Hyprland.monitors.values;
    for (let i = 0; i < monitors.length; i++) {
      if (monitors[i].id === monitor.id) {
        return i * 25 + 1;
      }
    }
    return 1;
  }

  // Get workspaces for THIS monitor only
  readonly property var monitorWorkspaces: {
    if (!monitor) return [];
    
    const all = Hyprland.workspaces.values;
    const filtered = [];
    for (let i = 0; i < all.length; i++) {
      if (all[i].monitor && all[i].monitor.id === monitor.id) {
        filtered.push(all[i].id);
      }
    }
    filtered.sort((a, b) => a - b);
    return filtered;
  }

  // Dynamic group calculation based on orientation
  readonly property int groupBase: {
    if (!monitor || !monitor.activeWorkspace) return 1;
    
    const id = monitor.activeWorkspace.id;
    const relativeId = id - workspaceBase + 1;
    
    if (isVertical) {
      return ((relativeId - 1) % 5) + 1;
    } else {
      return Math.floor((relativeId - 1) / 5) * 5 + 1;
    }
  }

  readonly property int groupSize: 5

  implicitWidth: isVertical ? Widget.height : (groupSize * Widget.height + (groupSize - 1) * 6)
  implicitHeight: isVertical ? (groupSize * Widget.height + (groupSize - 1) * 6) : Widget.height

  function wsById(id) {
    const arr = Hyprland.workspaces.values;
    for (let i = 0; i < arr.length; i++) {
      if (arr[i].id === id) return arr[i];
    }
    return null;
  }

  function formatIconVertical(relativeIndex) {
    const col = (relativeIndex - 1) % 5;
    switch(col) {
      case 0: return "";
      case 1: return "";
      case 2: return "";
      case 3: return "";
      case 4: return "";
      default: return "";
    }
  }

  Item {
    id: clippedContainer
    anchors.fill: parent
    clip: true

    GridLayout {
      id: mainGrid
      columns: 5
      rows: 5
      columnSpacing: 6
      rowSpacing: 6

      x: {
        if (isVertical) {
          const columnIndex = groupBase - 1;
          return -(columnIndex * (Widget.height + 6));
        }
        return 0;
      }

      y: {
        if (!isVertical) {
          const rowIndex = Math.floor((groupBase - 1) / 5);
          return -(rowIndex * (Widget.height + 6));
        }
        return 0;
      }

      Repeater {
        model: 25
        delegate: workspaceDelegate
      }
    }
  }

  MouseArea {
    id: hoverArea
    anchors.fill: parent
    hoverEnabled: true
    onEntered: if (root.popouts) showTimer.restart()
    onExited: showTimer.stop()
  }

  Timer {
    id: showTimer
    interval: 10
    onTriggered: {
      if (root.popouts && root.panel) {
        let parentPosition = root.mapToItem(null, 0, 0);
        root.popouts.safeOpenPopout(root.panel, "workspace-grid", {
          monitor: root.monitor,
          anchorX: parentPosition.x,
          anchorY: parentPosition.y,
          anchorWidth: root.width,
          anchorHeight: root.height,
          workspaceBase: root.workspaceBase
        });
      }
    }
  }

  Component {
    id: workspaceDelegate
    Rectangle {
      readonly property int relativeIndex: index + 1
      readonly property int realId: root.workspaceBase + index
      readonly property HyprlandWorkspace ws: root.wsById(realId)
      readonly property bool isActive: root.monitor && root.monitor.activeWorkspace && root.monitor.activeWorkspace.id === realId
      readonly property bool hasWindows: ws && ws.toplevels && ws.toplevels.values.length > 0

      Layout.preferredWidth: Widget.height
      Layout.preferredHeight: Widget.height

      radius: Appearance.borderRadius
      color: isActive ? root.activeColor : hasWindows ? root.inactiveColor : root.emptyColor

      Text {
        anchors.centerIn: parent
        text: root.formatIconVertical(relativeIndex)
        font.family: Appearance.fontFamily
        font.pixelSize: Appearance.fontSize * 1.2
        visible: isActive
        color: Theme.background
      }

      Behavior on color { ColorAnimation { duration: 50 } }
      Behavior on opacity { NumberAnimation { duration: 150 } }

      MouseArea {
        anchors.fill: parent
        onClicked: {
          if (Hyprland.dispatch) {
            Hyprland.dispatch("workspace", realId.toString());
          }
        }
      }
    }
  }
}
