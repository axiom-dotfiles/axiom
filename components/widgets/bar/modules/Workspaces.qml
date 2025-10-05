import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland

import qs.services
import qs.config

Item {
  id: root
  required property var screen
  property var popouts: null
  property var panel: null  // Reference to the parent panel for popout anchoring

  // Orientation support
  property int orientation: Config.orientation
  property bool isVertical: orientation === Qt.Vertical

  property color activeColor: Theme.accent
  property color inactiveColor: Theme.foregroundAlt
  property color emptyColor: Theme.backgroundAlt

  readonly property HyprlandMonitor monitor: Hyprland.monitorFor(root.screen)
  // readonly property HyprlandWorkspace focusedWorkspace: Hyprland.workspaces.focused

  // Dynamic group calculation based on orientation
  readonly property int groupBase: {
    const id = monitor.activeWorkspace ? monitor.activeWorkspace.id : 1;
    if (isVertical) {
      // For vertical: show the column that contains the active workspace
      return ((id - 1) % 5) + 1;
    } else {
      // For horizontal: groups are 1-5 | 6-10 | 11-15 | etc
      return Math.floor((id - 1) / 5) * 5 + 1;
    }
  }

  readonly property int groupSize: 5

  // Size for the clipped view in the bar
  implicitWidth: isVertical ? Widget.height : (groupSize * Widget.height + (groupSize - 1) * 6)
  implicitHeight: isVertical ? (groupSize * Widget.height + (groupSize - 1) * 6) : Widget.height

  function wsById(id) {
    const arr = Hyprland.workspaces.values;
    for (let i = 0; i < arr.length; i++) {
      if (arr[i].id === id)
        return arr[i];
    }
    return null;
  }

  function formatIconVertical(index) {
    index = parseInt(index) - 1;
    const col = index % 5;
    const workspaceStartCol = 1 % 5;

    if (col === workspaceStartCol - 1) {
      return "";  // or "↙" - leftmost column
    } else if (col === workspaceStartCol + 0) {
      return "";  // or "↓" - second column
    } else if (col === workspaceStartCol + 1) {
      return "";  // or "↘" - middle column
    } else if (col === workspaceStartCol + 2) {
      return "";  // or "→" - fourth column
    } else if (col === workspaceStartCol + 3) {
      return "";  // or "↗" - rightmost column
    }
  }

  // Main clipped container that shows only the relevant column/row
  Item {
    id: clippedContainer
    anchors.fill: parent
    clip: true  // Clip the full grid to show only what we need

    // Full 5x5 grid, but positioned so only the relevant part shows
    GridLayout {
      id: mainGrid
      columns: 5
      rows: 5
      columnSpacing: 6
      rowSpacing: 6

      // Position the grid so the right column/row is visible
      x: {
        if (isVertical) {
          // Show only the specific column
          const columnIndex = groupBase - 1;  // 0-4
          return -(columnIndex * (Widget.height + 6));
        } else {
          return 0;  // Show all columns for horizontal
        }
      }

      y: {
        if (!isVertical) {
          // Show only the specific row
          const rowIndex = Math.floor((groupBase - 1) / 5);  // 0-4
          return -(rowIndex * (Widget.height + 6));
        } else {
          return 0;  // Show all rows for vertical
        }
      }

      Repeater {
        model: 25
        delegate: workspaceDelegate
      }
    }
  }

  // Mouse area for hover detection
  MouseArea {
    id: hoverArea
    anchors.fill: parent
    hoverEnabled: true

    onEntered: {
      if (root.popouts) {
        showTimer.restart();
      }
    }

    onExited: {
      showTimer.stop();
    }
  }

  property var position: root.mapToItem(null, 0, 0)

  // Timer to show popout after hover
  Timer {
    id: showTimer
    interval: 10
    onTriggered: {
      if (root.popouts && root.panel) {
        console.log("anchor", root.parent.x, root.parent.y, root.width, root.height);
        root.popouts.openPopout(root.panel, "workspace-grid", {
          monitor: root.monitor,
          anchorX: root.parent.x,
          anchorY: root.parent.y,
          anchorWidth: root.width,
          anchorHeight: root.height
        });
      }
    }
  }

  // Workspace delegate component used in the bar grid
  Component {
    id: workspaceDelegate
    Rectangle {
      readonly property int realId: index + 1
      readonly property HyprlandWorkspace ws: root.wsById(realId)
      readonly property bool isActive: monitor.activeWorkspace && monitor.activeWorkspace.id === realId
      readonly property bool hasWindows: ws && ws.toplevels && ws.toplevels.values.length > 0

      Layout.preferredWidth: Widget.height
      Layout.preferredHeight: Widget.height

      radius: Appearance.borderRadius
      color: isActive ? root.activeColor : hasWindows ? root.inactiveColor : root.emptyColor

      Text {
        anchors.centerIn: parent
        text: root.formatIconVertical(realId)
        font.family: Appearance.fontFamily
        font.pixelSize: Appearance.fontSize * 1.2
        visible: isActive
      }

      Behavior on color {
        ColorAnimation {
          duration: 50
        }
      }

      Behavior on opacity {
        NumberAnimation {
          duration: 150
        }
      }
    }
  }
}
