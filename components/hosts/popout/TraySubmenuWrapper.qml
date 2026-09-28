pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.components.content.parts

/**
 * Popout wrapper for tray submenus.
 * Attaches to the side of the parent popout's box (right, or left when
 * openToLeft) with the same AttachedSurface shape as bar/edge popouts,
 * level with the hovered item and slid out of the parent.
 * Open/close/queue state and dismiss timing come from PopoutWrapperBase —
 * this file only adds submenu-specific positioning and animation.
 */
Item {
  id: outer

  required property ShellScreen screen
  required property bool openToLeft

  property alias popupWindow: submenuPopup
  property int minWidth: 100
  property int maxWidth: 600

  PopoutWrapperBase {
    id: root
    anchors.fill: parent

    property int connectorGap: Appearance.borderRadius * 2

    currentItem: loader.item ?? null

    PopupWindow {
      id: submenuPopup

      visible: root.occupied && loader.status === Loader.Ready && (root.currentItem?.contentReady ?? true)
      color: "transparent"

      readonly property int contentWidth: {
        const itemWidth = root.currentItem?.implicitWidth ?? outer.minWidth;
        return Math.max(outer.minWidth, Math.min(outer.maxWidth, itemWidth));
      }
      readonly property int contentHeight: root.currentItem?.implicitHeight ?? 100

      implicitWidth: surface.implicitWidth
      implicitHeight: surface.implicitHeight

      // The parent popout's content box, in the anchor window's
      // coordinates. Its free sides are the outer edge of the parent's
      // stroke (AttachedSurface.boxRect).
      readonly property rect attachRect: root.currentData?.attachRect ?? Qt.rect(0, 0, 0, 0)

      // Overlap the parent's side stroke with our attach-edge stroke, the
      // same way bar/edge popouts overlap the bar or border stroke
      readonly property real attachX: outer.openToLeft ? attachRect.x + Appearance.borderWidth - implicitWidth : attachRect.x + attachRect.width - Appearance.borderWidth

      // Line our first menu item up with the hovered one: the fillet
      // margin, then the loader inset, then TraySubmenu's own
      // background margin + half its 20px layout inset.
      readonly property real firstItemOffset: (root.connectorGap - Appearance.borderWidth) + surface.contentInset + Widget.padding + 10
      // Keep both fillets on the straight part of the parent's side, clear
      // of its rounded corners (or its fillets into the bar)
      readonly property real minY: attachRect.y + Appearance.borderRadius
      readonly property real maxY: attachRect.y + attachRect.height - Appearance.borderRadius - implicitHeight
      readonly property real attachY: Math.max(minY, Math.min((root.currentData?.anchorY ?? 0) - firstItemOffset, maxY))

      anchor {
        window: root.currentAnchor
        rect {
          x: submenuPopup.attachX
          y: submenuPopup.attachY
          width: 1
          height: 1
        }
      }

      AttachedSurface {
        id: surface
        anchors.fill: parent

        edge: outer.openToLeft ? Bar.Right : Bar.Left
        active: root.occupied && !root.isClosing && (root.currentItem?.contentReady ?? true)
        connectorGap: root.connectorGap
        boxWidth: submenuPopup.contentWidth + contentInset * 2
        boxHeight: submenuPopup.contentHeight + contentInset * 2

        Loader {
          id: loader
          anchors.fill: parent
          anchors.margins: surface.contentInset
          active: root.occupied
          asynchronous: false

          sourceComponent: Component {
            TraySubmenu {
              wrapper: root
              menuItem: root.currentData?.menuItem
            }
          }

          onLoaded: root.updateDismissTimer()
        }
      }
    }
  }

  // The overlay's focus grab lets input through to the submenu (see
  // ShellManager.grabPartners)
  Component.onCompleted: ShellManager.registerGrabPartner(submenuPopup, outer.screen?.name)
  onScreenChanged: ShellManager.registerGrabPartner(submenuPopup, outer.screen?.name)
  Component.onDestruction: ShellManager.unregisterGrabPartner(submenuPopup)

  // Thin forwarding so external callers (SystemTray, TraySubmenu)
  // keep using `submenuWrapper.safeOpenPopout(...)` / `closePopout()` /
  // `requestDismiss()` / `occupied` / `popupWindow` exactly as before,
  // without needing to reach into the inner PopoutWrapperBase directly.
  property alias occupied: root.occupied
  property alias currentItem: root.currentItem
  function safeOpenPopout(anchor, data) {
    root.safeOpenPopout(anchor, data);
  }
  function closePopout() {
    root.closePopout();
  }
  function requestDismiss() {
    root.requestDismiss();
  }
}
