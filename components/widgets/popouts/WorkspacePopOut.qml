import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

import qs.services
import qs.config
import qs.components.methods
import qs.components.stolen

Item {
  id: root

  required property var wrapper  // Reference to the popout wrapper
  property string currentName: "workspace-grid"

  // Data passed from the workspace widget
  property var monitor: wrapper.currentData?.monitor
  property int activeWorkspaceId: wrapper.currentData?.activeId ?? 1
  property int currentColumn: ((activeWorkspaceId - 1) % 5)
  readonly property int cell: (Widget.height && Widget.height > 0) ? Widget.height : 28

  // Size of the expanded grid
  // implicitWidth: content.width + 20
  // implicitHeight: content.height + 20
  implicitWidth: (5 * cell + 4 * 6) + 20
  implicitHeight: (5 * cell + 4 * 6) + 20
  width: implicitWidth
  height: implicitHeight

  Rectangle {
    id: content
    anchors.centerIn: parent
    visible: true

    // 5 columns × widget height + spacing
    width: 5 * Widget.height + 4 * 6
    height: 5 * Widget.height + 4 * 6

    color: Theme.background
    border.color: Theme.backgroundAlt
    border.width: 0
    radius: Appearance.borderRadius + 2

    // TODO: Figure out how to not define this here
    HoverHandler {
      id: hoverHandler
      onHoveredChanged: {
        if (hovered) {
          exitTimer.stop();
        } else {
          exitTimer.restart();
        }
      }
    }

    GridLayout {
      anchors.centerIn: parent
      columns: 5
      rows: 5
      columnSpacing: 6
      rowSpacing: 6

      Repeater {
        model: 25

        Rectangle {
          id: wsCell

          readonly property int wsId: index + 1
          readonly property var workspace: root.getWorkspace(wsId)
          readonly property bool isActive: root.monitor?.activeWorkspace?.id === wsId
          readonly property bool hasWindows: workspace?.toplevels?.values?.length > 0
          readonly property bool isCurrentColumn: (wsId - 1) % 5 === root.currentColumn
          readonly property bool showIcons: Widget.workspacePopoutIcons
          property bool hovered: false

          Layout.preferredWidth: Widget.height
          Layout.preferredHeight: Widget.height

          property var iconPath: findIconPath()
          property var windowData: HyprlandData.biggestWindowForWorkspace(wsId)

          function findIconPath() {
            let baseIcon = Quickshell.iconPath(AppSearch.guessIcon(windowData?.class), "image-missing");
            // Check if icon is kitty, and check if it is running nvim, and use nvim icon if so
            if (baseIcon.includes("kitty")) {
              for (let win of HyprlandData.windowList) {
                if (win.class === "kitty" && windowData?.title.toLowerCase().includes("nvim")) {
                  return Quickshell.iconPath("nvim", "image-missing");
                }
              }
            }
            return baseIcon;
          }

          radius: Appearance.borderRadius
          // property color baseColor: isActive ? Theme.accent : hasWindows ? Colors.outline : Theme.backgroundAlt

          color: isActive ? Theme.accent : hovered ? Theme.accentAlt : hasWindows ? Theme.border : Theme.backgroundAlt

          // Highlight the column shown in bar
          border.width: 0
          border.color: Theme.backgroundAlt
          // border.color: hovered ? Theme.accentAlt : Theme.backgroundAlt
          opacity: isCurrentColumn ? 1.0 : 0.85

          transitions: Transition {
            ColorAnimation {
              duration: 100
            }
          }

          Image {
            id: windowIcon
            source: (parent.hasWindows && parent.iconPath) ? parent.iconPath : ""
            width: parent.width * 0.7
            height: parent.height * 0.7
            anchors.centerIn: parent
            visible: Widget.workspacePopoutIcons
          }

          Text {
            anchors.centerIn: parent
            text: parent.wsId
            color: parent.isActive ? Theme.background : Theme.backgroundAlt
            font.pixelSize: 11
            font.family: Appearance.fontFamily
            visible: false
          }

          MouseArea {
            id: boxMouseArea
            anchors.fill: parent
            hoverEnabled: true

            cursorShape: containsMouse ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
              console.log("Click ws", parent.wsId);
              WorkspaceUtils.focusWorkspace(parent.wsId);
            }

            onContainsMouseChanged:
            // Handled by HoverHandler
            {}

            onEntered: {
              parent.hovered = true;
            }

            onExited: {
              parent.hovered = false;
            }
          }

          Behavior on scale {
            NumberAnimation {
              duration: 100
              easing.type: Easing.OutCubic
            }
          }

          Behavior on color {
            ColorAnimation {
              duration: 150
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
  }

  Timer {
    id: exitTimer
    interval: 40
    onTriggered: {
      root.wrapper.closePopout();
    }
  }

  function getWorkspace(id) {
    const arr = Hyprland.workspaces.values;
    for (let i = 0; i < arr.length; i++) {
      if (arr[i].id === id)
        return arr[i];
    }
    return null;
  }
}
