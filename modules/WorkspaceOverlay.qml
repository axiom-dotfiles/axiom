import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

import qs.services
import qs.config
import qs.components.methods
import qs.components.widgets.workspaces

Scope {
  id: root
  objectName: "workspaceOverlay"

  // Configuration
  property int gridSize: 5
  property int totalWorkspaces: 25
  property real overviewScale: 0.15

  // Colors
  property color overlayBgColor: Qt.rgba(0, 0, 0, 0.7)

  // Animation
  property int fadeAnimationDuration: 200

  IpcHandler {
    target: "workspaceOverlay"

    function toggle(): void {
      console.log("Toggling workspace overlay");
      overlayWindow.visible = !overlayWindow.visible;
      if (overlayWindow.visible) {
        HyprlandData.updateAll();
      }
    }

    function show(): void {
      overlayWindow.visible = true;
      HyprlandData.updateAll();
    }

    function hide(): void {
      overlayWindow.visible = false;
    }
  }

  PanelWindow {
    id: overlayWindow

    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }

    visible: false
    focusable: visible
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Keyboard handling
    Item {
      anchors.fill: parent
      focus: overlayWindow.focusable

      Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
          overlayWindow.visible = false;
          event.accepted = true;
        }
        // else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
        //   let workspaceId = event.key - Qt.Key_0;
        //   WorkspaceUtils.focusWorkspace(workspaceId);
        //   overlayWindow.visible = false;
        //   event.accepted = true;
        // }
      }
    }

    // Focus management
    HyprlandFocusGrab {
      windows: [overlayWindow]
      active: overlayWindow.visible

      onCleared: {
        if (!active) {
          overlayWindow.visible = false;
        }
      }
    }

    Rectangle {
      anchors.fill: parent
      anchors.topMargin: Bar.vertical ? Widget.containerWidth : Appearance.borderWidth
      anchors.bottomMargin: Bar.bottom ? Appearance.borderWidth : Widget.containerWidth
      anchors.rightMargin: Bar.rightSide ? Appearance.borderWidth : Widget.containerWidth
      anchors.leftMargin: Bar.vertical ? Appearance.borderWidth : Widget.containerWidth
      radius: Appearance.borderRadius
      color: root.overlayBgColor

      Behavior on opacity {
        NumberAnimation {
          duration: root.fadeAnimationDuration
          easing.type: Easing.InOutQuad
        }
      }

      MouseArea {
        anchors.fill: parent
        onClicked: {
          overlayWindow.visible = false;
        }
      }
    }

    // Main overlay content
    WorkspaceGrid {
      id: workspaceGrid
      anchors.centerIn: parent
      overviewScale: root.overviewScale

      onWorkspaceClicked: workspaceId => {
        overlayWindow.visible = false;
        WorkspaceUtils.focusWorkspace(workspaceId);
      }
    }
  }
}
