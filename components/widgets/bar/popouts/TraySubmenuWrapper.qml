// TraySubmenuWrapper.qml
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.config
import qs.components.widgets.bar

/**
 * Popout wrapper for submenus
 * Positions to the right of parent menu items with slide animation
 * If there is no space to the right it will open to the left instead
 */
// TODO: merge with Popouts.qml and EdgePopout.qml to make a generic popouts for everything
Item {
  id: root

  required property ShellScreen screen
  required property QtObject parentPopup
  required property bool openToLeft

  property var currentData: null
  property bool occupied: false
  property bool isClosing: false
  property Item currentItem: loader.item ?? null
  property int connectorGap: 4
  
  property int minWidth: 200
  property int maxWidth: 400

  // Queue for safe reopening
  property var pendingOpenData: null
  property bool hasPendingOpen: false

  function closePopout() {
    if (isClosing)
      return;
    isClosing = true;
    closeDelayTimer.restart();
  }

  function openPopout(anchor, data) {
    if (isClosing)
      return;
    currentData = data;
    occupied = true;
  }

  /**
   * Safe open function that ensures any existing popup is fully closed
   * before opening a new one. Can be used for both initial opens and reopens.
   */
  function safeOpenPopout(anchor, data) {
    if (occupied && !isClosing) {
      // Store the pending open request
      pendingOpenData = data;
      hasPendingOpen = true;
      // Close current popup
      closePopout();
    } else if (!occupied && !isClosing) {
      // No popup open, open immediately
      openPopout(anchor, data);
    } else {
      // Already closing, queue the open
      pendingOpenData = data;
      hasPendingOpen = true;
    }
  }

  Timer {
    id: closeDelayTimer
    interval: Widget.animationDuration
    repeat: false
    onTriggered: {
      root.occupied = false;
      root.isClosing = false;
      root.currentData = null;

      // Check if there's a pending open request
      if (root.hasPendingOpen) {
        root.hasPendingOpen = false;
        const data = root.pendingOpenData;
        root.pendingOpenData = null;
        // Open the new popup
        root.openPopout(null, data);
      }
    }
  }

  PopupWindow {
    id: submenuPopup

    visible: root.occupied && loader.status === Loader.Ready
    color: "transparent"

    readonly property int contentWidth: {
      const itemWidth = root.currentItem?.implicitWidth ?? root.minWidth;
      return Math.max(root.minWidth, Math.min(root.maxWidth, itemWidth));
    }
    readonly property int contentHeight: root.currentItem?.implicitHeight ?? 100

    implicitWidth: contentWidth + root.connectorGap
    implicitHeight: contentHeight

    anchor {
      window: root.parentPopup
      rect {
        x: {
          const baseX = (root.currentData?.anchorX ?? 0);
          const anchorWidth = (root.currentData?.anchorWidth ?? 0);
          const offset = Widget.padding * 2 + Appearance.borderWidth;

          if (root.openToLeft) {
            return baseX - submenuPopup.contentWidth - root.connectorGap - offset;
          } else {
            return baseX + anchorWidth + offset;
          }
        }
        y: root.currentData?.anchorY ?? 0
        width: 1
        height: 1
      }
    }

    SlideAnimation {
      id: slideContainer
      anchors.fill: parent

      active: root.occupied && !root.isClosing
      slideFromRight: root.openToLeft
      slideFromLeft: !root.openToLeft
      slideFromTop: false
      slideFromBottom: false
      animationDuration: Widget.animationDuration
      enableFade: false

      Rectangle {
        id: contentContainer

        color: Theme.background
        radius: Appearance.borderRadius
        border.color: Theme.foreground
        border.width: Appearance.borderWidth

        x: root.openToLeft ? Appearance.borderWidth : (root.connectorGap - Appearance.borderRadius)
        y: 0
        width: parent.width - root.connectorGap + (root.openToLeft ? Appearance.borderWidth + Appearance.borderRadius : 0)
        height: parent.height

        Loader {
          id: loader
          anchors.fill: parent
          anchors.margins: Widget.spacing
          active: root.occupied
          asynchronous: false

          sourceComponent: Component {
            TraySubmenuPopout {
              wrapper: root
              menuItem: root.currentData?.menuItem
            }
          }
        }
      }

      Rectangle {
        id: connector

        color: Theme.background
        x: root.openToLeft ? (parent.width - root.connectorGap) : 0
        y: 0
        width: root.connectorGap
        height: parent.height
      }
    }
  }
}
