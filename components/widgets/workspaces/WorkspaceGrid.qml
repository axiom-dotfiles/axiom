pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

import qs.services
import qs.config
import qs.components.methods

Rectangle {
  id: root
  required property var screen

  // Colors
  property color gridBgColor: Theme.background
  property color gridBorderColor: Theme.border

  // Grid configuration
  property real overviewScale: 0.15
  property int gridSize: 5
  property int workspaceSpacing: 10
  property real padding: 20

  property int monitorIndex: {
    for (let i = 0; i < Hyprland.monitors.values.length; i++) {
      if (Hyprland.monitors.values[i]?.name === monitorName) {
        return i;
      }
    }
    return 0;
  }
  
  property int workspaceOffset: monitorIndex * 25

  // Computed properties
  property var activeWorkspace: WorkspaceUtils.getActiveWorkspaceId()

  property real workspaceWidth: ((screen?.width ?? Hyprland.focusedMonitor?.width ?? 1920) * overviewScale)
  property real workspaceHeight: ((screen?.height ?? Hyprland.focusedMonitor?.height ?? 1080) * overviewScale)
  property string monitorName: screen?.name ?? Hyprland.focusedMonitor?.name ?? ""

  signal workspaceClicked(int workspaceId)

  implicitWidth: (workspaceWidth * gridSize) + (workspaceSpacing * (gridSize - 1)) + (padding * 2)
  implicitHeight: (workspaceHeight * gridSize) + (workspaceSpacing * (gridSize - 1)) + (padding * 2)

  color: gridBgColor
  radius: 8
  border.width: 2
  border.color: gridBorderColor

  Component.onCompleted: {
    console.log("WorkspaceGrid created for monitor:", monitorName, "index:", monitorIndex, "offset:", workspaceOffset);
  }

  // Container for all workspace cells
  Item {
    id: workspaceContainer
    anchors.centerIn: parent
    width: (root.workspaceWidth * root.gridSize) + (root.workspaceSpacing * (root.gridSize - 1))
    height: (root.workspaceHeight * root.gridSize) + (root.workspaceSpacing * (root.gridSize - 1))

    // Create all 25 workspace cells
    Repeater {
      model: 25

      WorkspaceCell {
        required property int index

        workspaceId: index + 1 + root.workspaceOffset
        width: root.workspaceWidth
        height: root.workspaceHeight
        isActive: workspaceId === root.activeWorkspace

        property var gridPos: WindowUtils.getWorkspacePosition(index + 1, root.gridSize)
        x: gridPos.col * (root.workspaceWidth + root.workspaceSpacing)
        y: gridPos.row * (root.workspaceHeight + root.workspaceSpacing)

        onClicked: {
          root.workspaceClicked(workspaceId);
        }
      }
    }
  }

  Item {
    id: windowContainer
    anchors.centerIn: parent
    width: workspaceContainer.width
    height: workspaceContainer.height
    z: 1000

    Repeater {
      model: HyprlandData.windowList

      delegate: DraggableWindow {
        required property var modelData
        required property int index

        windowData: modelData
        overviewScale: root.overviewScale
        gridSize: root.gridSize
        workspaceWidth: root.workspaceWidth
        workspaceHeight: root.workspaceHeight
        workspaceSpacing: root.workspaceSpacing
        workspaceOffset: root.workspaceOffset

        monitorActualWidth: root.screen?.width ?? 1920
        monitorActualHeight: root.screen?.height ?? 1080

        property int wsId: modelData?.workspace?.id ?? 1
        property int localWsId: ((wsId - 1) % 25) + 1
        property var windowMonitor: Hyprland.monitors.values[modelData?.monitor ?? 0]
        property var gridPos: WindowUtils.getWorkspacePosition(localWsId, root.gridSize)

        // FIXED: Check if window's monitor matches THIS grid's monitor
        visible: WorkspaceUtils.isWorkspaceVisible(localWsId) && (windowMonitor?.name === root.monitorName)

        offsetX: gridPos.col * (root.workspaceWidth + root.workspaceSpacing)
        offsetY: gridPos.row * (root.workspaceHeight + root.workspaceSpacing)

        Component.onCompleted: {
          console.log("Window on monitor:", windowMonitor?.name ?? "unknown", "Grid monitor:", root.monitorName, "visible:", visible);
        }

        onWindowDropped: targetWorkspace => {
          if (modelData?.workspace?.id && targetWorkspace !== modelData.workspace.id) {
            WindowUtils.moveWindowToWorkspace(modelData.address, targetWorkspace);
            HyprlandData.updateAll();
          }
        }

        onWindowClicked: {
          if (modelData?.workspace?.id) {
            root.workspaceClicked(modelData.workspace.id);
            WorkspaceUtils.focusWorkspace(modelData.address);
          }
        }

        onWindowClosed: {
          if (modelData?.address) {
            WindowUtils.closeWindow(modelData.address);
            HyprlandData.updateAll();
          }
        }

        onWindowResized:
        // TODO: Implement window resize functionality
        {}
      }
    }
  }

  // TODO: Add special workspace boxes here for scratchpads
  // SpecialWorkspaceContainer {
  //   anchors.left: parent.right
  //   anchors.leftMargin: 20
  //   anchors.verticalCenter: parent.verticalCenter
  // }
}
