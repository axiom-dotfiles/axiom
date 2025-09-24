import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

import qs.services
import qs.config
import qs.components.methods

Rectangle {
  id: root

  // Colors
  property color gridBgColor: Theme.backgroundAlt
  property color gridBorderColor: Theme.border

  // Grid configuration
  property real overviewScale: 0.15
  property int gridSize: 5
  property int workspaceSpacing: 10
  property real padding: 20

  // Computed properties
  property var activeWorkspace: WorkspaceUtils.getActiveWorkspaceId()
  property real workspaceWidth: ((Hyprland.focusedMonitor?.width ?? 1920) * overviewScale)
  property real workspaceHeight: ((Hyprland.focusedMonitor?.height ?? 1080) * overviewScale)

  signal workspaceClicked(int workspaceId)

  implicitWidth: (workspaceWidth * gridSize) + (workspaceSpacing * (gridSize - 1)) + (padding * 2)
  implicitHeight: (workspaceHeight * gridSize) + (workspaceSpacing * (gridSize - 1)) + (padding * 2)

  color: gridBgColor
  radius: 8
  border.width: 2
  border.color: gridBorderColor

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
        workspaceId: index + 1
        width: root.workspaceWidth
        height: root.workspaceHeight
        isActive: workspaceId === root.activeWorkspace

        property var gridPos: WindowUtils.getWorkspacePosition(workspaceId, root.gridSize)
        x: gridPos.col * (root.workspaceWidth + root.workspaceSpacing)
        y: gridPos.row * (root.workspaceHeight + root.workspaceSpacing)

        onClicked: {
          root.workspaceClicked(workspaceId);
        }
      }
    }
  }

  // Window container - overlays on top of workspace cells
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

        // Calculate grid position from workspace ID
        property int wsId: modelData?.workspace?.id ?? 1
        property var gridPos: WindowUtils.getWorkspacePosition(wsId, root.gridSize)

        // Only show windows in the visible 5x5 grid (workspaces 1-25)
        visible: WorkspaceUtils.isWorkspaceVisible(wsId)

        offsetX: gridPos.col * (root.workspaceWidth + root.workspaceSpacing)
        offsetY: gridPos.row * (root.workspaceHeight + root.workspaceSpacing)

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

        onWindowResized: {
          // TODO: Implement window resize functionality
        }
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
