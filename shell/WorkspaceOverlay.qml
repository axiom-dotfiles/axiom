import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.config
import qs.components.reusable
import qs.components.surfaces.workspaces

// The workspace overview: this monitor's 5×5 workspace grid with its
// windows, full screen. Drag a window to move it (onto a side of another
// window), right-drag to resize, middle-click to close.
Scope {
  id: root
  objectName: "workspaceOverlay"

  property bool overlayVisible: false
  // Screen it opens on: the one under the cursor, fixed when it opens
  property string openScreen: ""

  function open() {
    if (root.overlayVisible)
      return;
    HyprlandManager.withHoveredScreen(name => {
      root.openScreen = name;
      root.overlayVisible = true;
      HyprlandManager.updateAll();
    });
  }

  function toggle() {
    if (root.overlayVisible)
      root.overlayVisible = false;
    else
      root.open();
  }

  Connections {
    target: ShellManager
    function onToggleWorkspaceOverlay() {
      root.toggle();
    }
  }

  IpcHandler {
    target: "workspaceOverlay"

    function toggle(): void {
      root.toggle();
    }

    function show(): void {
      root.open();
    }

    function hide(): void {
      root.overlayVisible = false;
    }
  }

  // On every monitor, whatever General > Monitors says: it opens on the
  // hovered one
  Variants {
    model: Quickshell.screens

    delegate: PanelWindow {
      id: overlayWindow
      required property var modelData

      // The dim background, under the bars and border
      ScreenBackdrop {
        screen: overlayWindow.modelData
        shown: overlayWindow.shown
        fillColor: Theme.base00
        fillOpacity: WorkspaceOverlayConfig.backdrop
      }

      readonly property bool shown: root.overlayVisible && modelData.name === root.openScreen
      // Room the controls hint takes under the grid
      readonly property real hintSpace: hint.visible ? hint.height + Widget.spacing : 0

      screen: modelData
      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }
      // Over everything, so window coordinates are the monitor's (the
      // cursor goes back to them after a drop)
      exclusionMode: ExclusionMode.Ignore
      visible: overlayWindow.shown || content.opacity > 0
      color: "transparent"

      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "axiom-workspaces"
      // OnDemand, not Exclusive: an exclusive layer makes Hyprland refuse
      // focus to every window, so focusing one (a click, a drop's target)
      // would only switch the workspace, and closing would refocus the old
      // window and switch back. The focus grab keeps the keyboard here.
      WlrLayershell.keyboardFocus: overlayWindow.shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

      HyprlandFocusGrab {
        id: grab
        // Off for a moment to take the grab back after a drop moved focus
        property bool rearming: false
        active: overlayWindow.shown && !grab.rearming
        windows: [overlayWindow]
        onCleared: {
          if (overview.recentAction()) {
            grab.rearming = true;
            Qt.callLater(() => grab.rearming = false);
          } else {
            root.overlayVisible = false;
          }
        }
      }

      Item {
        id: content
        anchors.fill: parent
        opacity: overlayWindow.shown ? 1 : 0
        focus: overlayWindow.shown

        Behavior on opacity {
          NumberAnimation {
            duration: Appearance.animNormal
            easing.type: Appearance.easing
          }
        }

        Keys.onEscapePressed: {
          if (!overview.cancelInteraction())
            root.overlayVisible = false;
        }

        // The empty background (the backdrop shows through it): a click
        // on it closes
        MouseArea {
          anchors.fill: parent
          onClicked: root.overlayVisible = false
        }

        OverviewGrid {
          id: overview
          anchors.centerIn: parent
          anchors.verticalCenterOffset: -overlayWindow.hintSpace / 2
          screen: overlayWindow.modelData
          // Through the fade out too, or the previews drop their frames
          // (and show the app icon) while still on screen
          active: overlayWindow.visible
          availableWidth: parent.width * WorkspaceOverlayConfig.size
          availableHeight: parent.height * WorkspaceOverlayConfig.size - overlayWindow.hintSpace

          onCloseRequested: root.overlayVisible = false
        }

        StyledText {
          id: hint
          visible: WorkspaceOverlayConfig.showHint
          anchors.top: overview.bottom
          anchors.topMargin: Widget.spacing
          anchors.horizontalCenter: parent.horizontalCenter
          text: I18n.tr("Click to go · Drag to move · Right-drag to resize · Middle-click to close")
          textColor: Theme.foregroundAlt
          textSize: Appearance.fontSize - 1
        }
      }
    }
  }
}
