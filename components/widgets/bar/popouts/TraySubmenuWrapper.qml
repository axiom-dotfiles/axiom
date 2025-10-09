// TraySubmenuWrapper.qml
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.config
import qs.components.widgets.bar
import qs.components.reusable

/**
 * Popout wrapper for submenus
 * Positions to the right of parent menu items with slide animation
 * If there is no space to the right it will open to the left instead
 */
// TODO: merge with Popouts.qml and EdgePopout.qml to make a generic popouts for everything
// Needs a bit of a refactor as well it is quite messy
// commenting here later; maybe not merge them, but certainly refactors for all of them
Item {
  id: root

  required property ShellScreen screen
  required property bool openToLeft

  property alias popupWindow: submenuPopup

  property var currentData: null
  property bool occupied: false
  property bool isClosing: false
  property Item currentItem: loader.item ?? null
  property var currentAnchor: null
  property int connectorGap: 4

  property int minWidth: 100
  property int maxWidth: 600

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
    console.log("Opening submenu at: ", data?.anchorX, data?.anchorY, " with width ", data?.anchorWidth);
    console.log("Anchor:", anchor);
    console.log("Data:", data);

    if (isClosing)
      return;
    currentAnchor = anchor;
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
    interval: Appearance.animationDuration
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

    property int offset: Widget.padding * 4 - Appearance.borderWidth
    property int baseX: root.currentData?.anchorX ?? 0
    property int openLeftX: baseX - submenuPopup.contentWidth - root.connectorGap - offset + Widget.padding * 3
    property int openRightX: baseX + (root.currentData?.anchorWidth ?? 0) + offset
    property int finalX: root.openToLeft ? openLeftX : openRightX
    property int finalY: 0

    anchor {
      window: root.currentAnchor
      rect {
        x: finalX
        y: (root.currentData?.anchorY ?? 0)
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
      animationDuration: Appearance.animationDuration
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

        color: Theme.bg0
        x: root.openToLeft ? (parent.width - root.connectorGap) : 0
        y: 0
        width: root.connectorGap
        height: parent.height
      }
      // close enough for now on these
      Rectangle {
        id: topCorner
        anchors.top: connector.top
        anchors.left: connector.left
        anchors.right: connector.right
        width: connector.width
        height: Appearance.borderRadius
        color: "transparent"
        CornerPiece {
          isLeft: true
          isTop: false
        }
      }

      Rectangle {
        id: bottomCorner
        anchors.bottom: connector.bottom
        anchors.left: connector.left
        anchors.right: connector.right
        width: connector.width
        height: Appearance.borderRadius
        color: "transparent"
        CornerPiece {
          isLeft: true
          isTop: false
        }
      }
    }
  }
}
