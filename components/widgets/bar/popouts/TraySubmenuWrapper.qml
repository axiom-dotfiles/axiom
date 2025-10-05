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
Item {
  id: root

  required property ShellScreen screen
  required property QtObject parentPopup

  property var currentData: null
  property bool occupied: false
  property bool isClosing: false
  property Item currentItem: loader.item ?? null
  property int connectorGap: 4

  readonly property bool openToLeft: {
    if (!currentData)
      return false;

    const anchorX = currentData.anchorX ?? 0;
    const anchorWidth = currentData.anchorWidth ?? 0;
    const submenuWidth = submenuPopup.contentWidth + connectorGap;
    const screenRightEdge = screen.width;

    const absoluteAnchorX = anchorX < 0 ? screenRightEdge + anchorX : anchorX;
    const rightEdge = absoluteAnchorX + anchorWidth + Widget.padding * 2 + Appearance.borderWidth;

    return (rightEdge + submenuWidth) > screenRightEdge;
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
      root.currentData = null;
    }
  }

  PopupWindow {
    id: submenuPopup

    visible: root.occupied && loader.status === Loader.Ready
    screen: root.screen
    color: "transparent"

    readonly property int contentWidth: root.currentItem?.implicitWidth ?? 200
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

        // x: root.openToLeft ? 0 : (root.connectorGap - Appearance.borderRadius)
        x: root.openToLeft ? Appearance.borderWidth : (root.connectorGap - Appearance.borderRadius)
        y: 0
        // width: parent.width - root.connectorGap
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
