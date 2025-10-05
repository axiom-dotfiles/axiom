pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

import qs.services
import qs.config
import qs.components.widgets.bar
import qs.components.widgets.bar.popouts

// This is somewhere I would argue a little repeated code for an entire all-in-one solution

/**
 * Popout wrapper for bar widgets
 * Handles positioning, animation, and content loading for popouts that emerge from the bar
 */
Item {
  id: root

  required property ShellScreen screen
  required property var barConfig
  required property QtObject panel

  property var currentAnchor: null
  property var currentData: null
  property string currentName: ""
  property bool occupied: false
  property bool isClosing: false

  property Item currentItem: loader.item ?? null

  // Gap between bar and main content (connector thickness)
  property int connectorGap: 4

  function closePopout() {
    if (isClosing)
      return;
    isClosing = true;
    closeDelayTimer.restart();
  }

  function openPopout(anchor, name, data) {
    if (isClosing)
      return;
    currentAnchor = anchor;
    currentData = data;
    currentName = name;
    occupied = true;
  }

  function changeContent(name, data) {
    if (isClosing)
      return;
    currentData = data;
    currentName = name;

    // Update the loaded item's properties with new data
    if (loader.item && data) {
      for (let key in data) {
        if (loader.item.hasOwnProperty(key)) {
          loader.item[key] = data[key];
        }
      }
    }
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
      root.currentName = "";
    }
  }

  PopupWindow {
    id: mainPopup
    visible: root.occupied && loader.status === Loader.Ready
    screen: root.screen
    color: "transparent"

    // Content dimensions
    readonly property int contentWidth: root.currentItem?.implicitWidth ?? 200
    readonly property int contentHeight: root.currentItem?.implicitHeight ?? 100

    // Total size including connector gap
    implicitWidth: {
      if (root.barConfig.vertical) {
        return contentWidth + root.connectorGap;
      }
      return contentWidth;
    }

    implicitHeight: {
      if (root.barConfig.vertical) {
        return contentHeight;
      }
      return contentHeight + root.connectorGap;
    }

    anchor {
      window: root.currentAnchor

      rect {
        x: {
          if (!root.currentData)
            return 0;

          if (root.barConfig.left) {
            // Start at bar edge (extent from screen edge)
            return root.barConfig.extent;
          } else if (root.barConfig.right) {
            // Position so animation slides from right
            return (root.currentData.anchorX ?? 0) - mainPopup.implicitWidth - Widget.padding + Appearance.borderWidth;
          } else {
            // Top/Bottom: center horizontally with anchor
            let anchorCenter = (root.currentData.anchorX ?? 0) + (root.currentData.anchorWidth ?? 0) / 2;
            let popoutCenter = mainPopup.implicitWidth / 2;
            let targetX = anchorCenter - popoutCenter;

            // Clamp to screen bounds
            return Math.max(Appearance.screenMargin, Math.min(targetX, Display.resolutionWidth - mainPopup.implicitWidth - Appearance.screenMargin));
          }
        }

        y: {
          if (!root.currentData)
            return 0;

          if (root.barConfig.top) {
            return root.barConfig.extent;
          } else if (root.barConfig.bottom) {
            return (root.currentData.anchorY ?? 0) - mainPopup.implicitHeight - Widget.padding + Appearance.borderWidth;
          } else {
            // Left/Right: center vertically with anchor
            let anchorCenter = (root.currentData.anchorY ?? 0) + (root.currentData.anchorHeight ?? 0) / 2;
            let popoutCenter = mainPopup.implicitHeight / 2;
            let targetY = anchorCenter - popoutCenter;

            // Clamp to screen bounds
            return Math.max(Appearance.screenMargin, Math.min(targetY, Display.resolutionHeight - mainPopup.implicitHeight - Appearance.screenMargin));
          }
        }

        width: 1
        height: 1
      }
    }

    SlideAnimation {
      id: slideContainer
      anchors.fill: parent

      active: root.occupied && !root.isClosing
      slideFromRight: root.barConfig.right
      slideFromLeft: root.barConfig.left
      slideFromTop: root.barConfig.top
      slideFromBottom: root.barConfig.bottom
      animationDuration: Widget.animationDuration
      enableFade: false

      Rectangle {
        id: topCorner
      }

      // Main content container
      Rectangle {
        id: contentContainer
        color: Theme.background
        radius: Appearance.borderRadius
        border.color: Theme.foreground
        border.width: Appearance.borderWidth

        // Position with gap from bar edge
        x: {
          if (root.barConfig.left)
            return root.connectorGap - Appearance.borderRadius;
          if (root.barConfig.right)
            return parent.width - (mainPopup.contentWidth + root.connectorGap) + Appearance.borderRadius;
          return 0;
        }

        y: {
          if (root.barConfig.top)
            return root.connectorGap - Appearance.borderRadius;
          if (root.barConfig.bottom)
            return parent.height - (mainPopup.contentHeight + root.connectorGap) + Appearance.borderRadius;
          return 0;
        }

        width: root.barConfig.vertical ? parent.width - root.connectorGap : parent.width
        height: root.barConfig.vertical ? parent.height : parent.height - root.connectorGap

        Loader {
          id: loader
          anchors.fill: parent
          anchors.margins: Widget.spacing

          active: root.occupied
          asynchronous: false

          sourceComponent: {
            switch (root.currentName) {
            case "workspace-grid":
              return workspaceGridComponent;
            case "media-player":
              return mediaPlayerComponent;
            case "system-tray-menu":
              return systemTrayComponent;
            default:
              return null;
            }
          }

          onLoaded: {
            if (item) {
              item.wrapper = root;
              if (root.currentData) {
                // Pass through any additional data properties
                for (let key in root.currentData) {
                  if (item.hasOwnProperty(key)) {
                    item[key] = root.currentData[key];
                  }
                }
              }
            }
          }
        }
      }

      Rectangle {
        id: connector
        color: Theme.background

        x: root.barConfig.left ? 0 : root.barConfig.right ? parent.width - root.connectorGap : 0
        y: root.barConfig.top ? 0 : root.barConfig.bottom ? parent.height - root.connectorGap : 0

        width: root.barConfig.vertical ? root.connectorGap : parent.width
        height: root.barConfig.vertical ? parent.height : root.connectorGap

        // TODO: Add inverted corner shapepaths here for smooth bar connection
      }
    }
  }

  Component {
    id: workspaceGridComponent
    WorkspacePopout {
      wrapper: root
    }
  }

  Component {
    id: systemTrayComponent
    SystemTrayPopout {
      wrapper: root
    }
  }

  Component {
    id: mediaPlayerComponent
    Item {} // Placeholder
  }
}
