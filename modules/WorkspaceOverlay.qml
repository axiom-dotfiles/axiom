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
  
  // Shared visibility state
  property bool overlayVisible: false
  
  IpcHandler {
    target: "workspaceOverlay"
    
    function toggle(): void {
      console.log("Toggling workspace overlay");
      root.overlayVisible = !root.overlayVisible;
      if (root.overlayVisible) {
        HyprlandData.updateAll();
      }
      console.log("Overlay visible:", root.overlayVisible);
    }
    
    function show(): void {
      root.overlayVisible = true;
      HyprlandData.updateAll();
    }
    
    function hide(): void {
      root.overlayVisible = false;
    }
  }
  
  // Single focus grab for all windows
  HyprlandFocusGrab {
    active: root.overlayVisible
    
    onCleared: {
      if (!active) {
        root.overlayVisible = false;
      }
    }
  }
  
  // Create a PanelWindow for each screen
  Variants {
    model: Quickshell.screens
    
    delegate: PanelWindow {
      id: overlayWindow
      required property var modelData
      
      screen: modelData
      
      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }
      
      visible: root.overlayVisible
      focusable: visible
      color: "transparent"
      
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
      
      Component.onCompleted: {
        console.log("Created overlay window for screen:", modelData?.name ?? "unknown");
      }
      
      // Keyboard handling
      Item {
        anchors.fill: parent
        focus: overlayWindow.focusable
        
        Keys.onPressed: event => {
          if (event.key === Qt.Key_Escape) {
            root.overlayVisible = false;
            event.accepted = true;
          }
        }
      }
      
      Rectangle {
        anchors.fill: parent
        anchors.topMargin: Bar.vertical ? Appearance.screenMargin : Appearance.borderWidth
        anchors.bottomMargin: Bar.bottom ? Appearance.borderWidth : Appearance.screenMargin
        anchors.rightMargin: Bar.right ? Appearance.borderWidth : Appearance.screenMargin
        anchors.leftMargin: Bar.vertical ? Appearance.borderWidth : Appearance.screenMargin
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
            root.overlayVisible = false;
          }
        }
      }
      
      WorkspaceGrid {
        id: workspaceGrid
        anchors.centerIn: parent
        overviewScale: root.overviewScale
        screen: overlayWindow.screen
        
        onWorkspaceClicked: workspaceId => {
          root.overlayVisible = false;
          WorkspaceUtils.focusWorkspace(workspaceId);
        }
      }
    }
  }
}
