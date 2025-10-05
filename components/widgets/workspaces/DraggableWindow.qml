pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

import qs.services
import qs.config
import qs.components.methods

Item {
  id: root

  // Colors
  property color windowBgColor: Theme.backgroundAlt
  property color windowBorderColor: Theme.border
  property color windowBorderActiveColor: Theme.accent
  property color windowHoverBorderColor: Theme.accentAlt
  property color textColor: Theme.foreground

  // Animation properties
  property int animationDuration: Widget.animations ? Widget.animationDuration : 0
  property int hoverAnimationDuration: 150
  property real dragScale: 1.05
  property real dragOpacity: 0.8

  // Core properties
  property var windowData: null
  property real overviewScale: 0.15
  property int gridSize: 5
  property real workspaceWidth: 0
  property real workspaceHeight: 0
  property real workspaceSpacing: 0
  property real offsetX: 0
  property real offsetY: 0

  // Computed properties
  property var toplevel: WindowUtils.getToplevelFromAddress(windowData?.address)
  property string iconPath: IconResolver.resolveWindowIcon(windowData?.class, windowData?.title)
  property string windowTitle: windowData?.title ?? windowData?.class ?? "Unknown"
  property bool isFloating: windowData?.floating ?? false
  property bool isFocused: (windowData?.focusHistoryID ?? 999) === 0

  // Signals
  signal windowDropped(int targetWorkspace)
  signal windowClicked
  signal windowClosed
  signal windowResized

  // Calculate position and size
  property var constraints: WindowUtils.calculateWindowConstraints(windowData, overviewScale, workspaceWidth, workspaceHeight)

  x: offsetX + constraints.x
  y: offsetY + constraints.y
  implicitWidth: constraints.width
  implicitHeight: constraints.height

  visible: windowData !== null && windowData !== undefined
  z: dragHandler.active ? 1000 : (isFloating ? 100 : 10)

  // Animations
  Behavior on x {
    enabled: !dragHandler.active
    NumberAnimation {
      duration: root.animationDuration
      easing.type: Easing.OutCubic
    }
  }

  Behavior on y {
    enabled: !dragHandler.active
    NumberAnimation {
      duration: root.animationDuration
      easing.type: Easing.OutCubic
    }
  }

  // Window preview
  WindowPreview {
    id: windowPreview
    anchors.fill: parent

    windowData: root.windowData
    toplevel: root.toplevel
    iconPath: root.iconPath
    windowTitle: root.windowTitle

    bgColor: root.windowBgColor
    borderColor: root.windowBorderColor
    borderActiveColor: root.windowBorderActiveColor
    borderHoverColor: root.windowHoverBorderColor
    textColor: root.textColor

    isActive: root.isFocused
    isHovered: mouseArea.containsMouse
    windowOpacity: root.isFloating ? 0.95 : 0.9
    borderRadius: 4 * root.overviewScale
  }

  // Mouse interaction
  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
    cursorShape: dragHandler.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor

    onClicked: mouse => {
      if (mouse.button === Qt.LeftButton) {
        root.windowClicked();
      } else if (mouse.button === Qt.MiddleButton) {
        root.windowClosed();
      } else if (mouse.button === Qt.RightButton) {
        root.windowResized();
      }
    }
  }

  // Drag handler
  DragHandler {
    id: dragHandler
    target: root

    onActiveChanged: {
      if (!active) {
        let targetWorkspace = WindowUtils.getTargetWorkspaceFromPosition(root.x, root.y, root.width, root.height, workspaceWidth, workspaceHeight, workspaceSpacing, gridSize);

        if (windowData?.workspace?.id && targetWorkspace !== windowData.workspace.id) {
          root.windowDropped(targetWorkspace);
        } else {
          // Snap back to original position
          root.x = Qt.binding(() => root.offsetX + root.constraints.x);
          root.y = Qt.binding(() => root.offsetY + root.constraints.y);
        }
      }
    }
  }

  // Visual feedback during drag
  states: [
    State {
      name: "dragging"
      when: dragHandler.active
      PropertyChanges {
        target: windowPreview
        scale: root.dragScale
        opacity: root.dragOpacity
      }
    }
  ]

  transitions: Transition {
    NumberAnimation {
      properties: "scale,opacity"
      duration: root.hoverAnimationDuration
      easing.type: Easing.OutCubic
    }
  }
}
