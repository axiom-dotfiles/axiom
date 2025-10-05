// TraySubmenuWrapper.qml
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.config

/**
 * Secondary popout wrapper for system tray submenus
 * Positions submenu to the right/left of the parent menu item with slide animation
 */
Item {
  id: root

  required property ShellScreen screen
  required property var parentPopup  // Reference to the main tray popout window

  property var currentAnchor: null
  property var currentData: null
  property bool occupied: false
  property bool isClosing: false

  property Item currentItem: loader.item ?? null

  // Gap between parent menu and submenu content (connector thickness)
  property int connectorGap: 4

  // Determine if we should slide to the right or left based on available space
  readonly property bool slideToRight: {
    if (!currentData || !currentAnchor) return true;
    
    // Get the parent popup's global position
    let parentGlobalX = currentAnchor.x;
    let parentWidth = currentAnchor.width;
    let submenuWidth = submenuPopup.contentWidth + connectorGap;
    
    // Check if there's space on the right
    let rightEdge = parentGlobalX + parentWidth + submenuWidth;
    return rightEdge <= Display.resolutionWidth - Appearance.screenMargin;
  }

  function closePopout() {
    if (isClosing)
      return;
    isClosing = true;
    closeDelayTimer.restart();
  }

  function openPopout(anchor, data) {
    if (isClosing)
      return;
    currentAnchor = anchor;
    currentData = data;
    occupied = true;
  }

  Timer {
    id: closeDelayTimer
    interval: Widget.animationDuration
    repeat: false
    onTriggered: {
      root.occupied = false;
      root.isClosing = false;
      root.currentAnchor = null;
      root.currentData = null;
    }
  }

  PopupWindow {
    id: submenuPopup
    visible: root.occupied && loader.status === Loader.Ready
    color: "transparent"

    // Content dimensions
    readonly property int contentWidth: root.currentItem?.implicitWidth ?? 200
    readonly property int contentHeight: root.currentItem?.implicitHeight ?? 100

    // Total size including connector gap
    implicitWidth: contentWidth + root.connectorGap
    implicitHeight: contentHeight

    anchor {
      window: root.currentAnchor

      rect {
        x: {
          if (!root.currentData)
            return 0;
          
          if (root.slideToRight) {
            // Slide to the right: position at right edge of parent (behind)
            // Start aligned with parent's right edge minus our width
            return root.currentAnchor.width - submenuPopup.implicitWidth;
          } else {
            // Slide to the left: position at left edge of parent (behind)
            return 0;
          }
        }

        y: {
          if (!root.currentData)
            return 0;
          
          // Align with the parent menu item within the popup
          let itemY = root.currentData.anchorY ?? 0;
          let parentGlobalY = root.currentAnchor.y;
          let relativeY = itemY - parentGlobalY;
          
          // Offset by margin to align properly with item
          let targetY = relativeY - 8;
          
          // Clamp within parent bounds
          if (targetY < 0) {
            targetY = 0;
          }
          if (targetY + submenuPopup.implicitHeight > root.currentAnchor.height) {
            targetY = root.currentAnchor.height - submenuPopup.implicitHeight;
          }
          
          return targetY;
        }

        width: 1
        height: 1
      }
    }

    SlideAnimation {
      id: slideContainer
      anchors.fill: parent

      active: root.occupied && !root.isClosing
      slideFromLeft: root.slideToRight   // Slide from left when expanding right
      slideFromRight: !root.slideToRight  // Slide from right when expanding left
      animationDuration: Widget.animationDuration
      enableFade: false

      // Main content container
      Rectangle {
        id: contentContainer
        color: Theme.background
        radius: Appearance.borderRadius
        border.color: Theme.foreground
        border.width: Appearance.borderWidth

        // Position with gap from the connector edge
        x: root.slideToRight ? root.connectorGap - Appearance.borderRadius : Appearance.borderRadius
        y: 0

        width: parent.width - root.connectorGap
        height: parent.height

        Loader {
          id: loader
          anchors.fill: parent
          anchors.margins: Widget.spacing

          active: root.occupied
          asynchronous: false

          sourceComponent: submenuComponent

          onLoaded: {
            if (item && root.currentData) {
              item.wrapper = root;
            }
          }
        }
      }

      // Connector rectangle bridging to parent menu
      Rectangle {
        id: connector
        color: Theme.background

        x: root.slideToRight ? 0 : parent.width - root.connectorGap
        y: 0

        width: root.connectorGap
        height: parent.height
      }
    }
  }

  Component {
    id: submenuComponent
    TraySubmenuPopout {
      wrapper: root
      menuItem: root.currentData?.menuItem ?? null
    }
  }
}
