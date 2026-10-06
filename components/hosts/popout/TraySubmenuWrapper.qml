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
 * level with the hovered item and slid out of the parent. Another
 * submenu of the same menu switches in place (SwitchStill).
 * Open/close/queue state and dismiss timing come from PopoutWrapperBase —
 * this file only adds submenu-specific positioning and animation.
 */
Item {
  id: outer

  required property ShellScreen screen
  required property bool openToLeft

  property alias popupWindow: submenuPopup

  PopoutWrapperBase {
    id: root
    anchors.fill: parent

    property int connectorGap: Appearance.borderRadius * 2

    currentItem: loader.item ?? null
    // Loaded, with its entries in (they arrive over DBus, TrayMenuList)
    readonly property bool contentReady: loader.status === Loader.Ready && (root.currentItem?.contentReady ?? true)

    // Another submenu of the same menu (a sibling item's, or one drilled
    // into) switches in place: the box glides level with its item and
    // resizes, the old entries fading out over the new (SwitchStill)
    canSwitchTo: (anchor, data) => anchor === root.currentAnchor && (root.contentReady || still.switching)
    prepareSwitch: done => still.prepare(root.currentItem, done)

    // Every payload builds afresh, so a switch waits for its own entries
    onCurrentDataChanged: {
      if (root.occupied) {
        loader.sourceComponent = null;
        loader.sourceComponent = submenu;
      }
    }

    // The box at its content's size and level with its item, and as drawn:
    // animated to them once it shows (not on opening), and held as it was
    // while a switch waits for its entries
    readonly property real targetBoxWidth: submenuPopup.contentWidth + surface.contentInset * 2
    readonly property real targetBoxHeight: submenuPopup.contentHeight + surface.contentInset * 2
    property real shownBoxWidth: still.holding ? still.held.width : root.targetBoxWidth
    property real shownBoxHeight: still.holding ? still.held.height : root.targetBoxHeight
    property real shownY: still.holding ? still.held.y : submenuPopup.attachY
    property bool _settled: false
    function _updateSettled() {
      if (!root.occupied || !(root.contentReady || still.switching))
        root._settled = false;
      else
        Qt.callLater(() => root._settled = root.occupied && (root.contentReady || still.switching));
    }
    Behavior on shownBoxWidth {
      enabled: root._settled
      NumberAnimation {
        duration: Appearance.animFast
        easing.type: Appearance.easing
      }
    }
    Behavior on shownBoxHeight {
      enabled: root._settled
      NumberAnimation {
        duration: Appearance.animFast
        easing.type: Appearance.easing
      }
    }
    Behavior on shownY {
      enabled: root._settled
      NumberAnimation {
        duration: Appearance.animFast
        easing.type: Appearance.easing
      }
    }

    // The largest surface since it opened, which the window keeps room for
    property real _peakWidth: 0
    property real _peakHeight: 0
    function _notePeak() {
      if (!root.occupied || !root.contentReady)
        return;
      root._peakWidth = Math.max(root._peakWidth, submenuPopup.surfaceWidth);
      root._peakHeight = Math.max(root._peakHeight, submenuPopup.surfaceHeight);
    }
    onContentReadyChanged: {
      _notePeak();
      _updateSettled();
    }
    onOccupiedChanged: {
      if (!root.occupied) {
        root._peakWidth = 0;
        root._peakHeight = 0;
        still.end();
      }
      _updateSettled();
    }

    PopupWindow {
      id: submenuPopup

      visible: root.occupied && (root.contentReady || still.switching) && !ShellManager.captureFrozen
      color: "transparent"

      // TrayMenuList sizes itself to its entries, within its limits
      readonly property int contentWidth: root.currentItem?.implicitWidth ?? 0
      readonly property int contentHeight: root.currentItem?.implicitHeight ?? 0
      // The surface at the target box size (it's drawn at the shown one)
      readonly property real surfaceWidth: surface.implicitWidth - root.shownBoxWidth + root.targetBoxWidth
      readonly property real surfaceHeight: surface.implicitHeight - root.shownBoxHeight + root.targetBoxHeight
      onSurfaceWidthChanged: root._notePeak()
      onSurfaceHeightChanged: root._notePeak()

      // Room for the shadow or glow the surface casts (SurfaceShadow) on
      // its free sides: away from the parent, above and below
      readonly property real shadowRoom: BarStyle.shadowReach

      // The parent popout's content box, in the anchor window's
      // coordinates. Its free sides are the outer edge of the parent's
      // stroke (AttachedSurface.boxRect).
      readonly property rect attachRect: root.currentData?.attachRect ?? Qt.rect(0, 0, 0, 0)

      // Line our first menu item up with the hovered one: the fillet
      // margin, then the loader inset
      readonly property real firstItemOffset: surface.startMargin + surface.contentInset
      // Keep both fillets on the straight part of the parent's side, clear
      // of its rounded corners (or its fillets into the bar)
      readonly property real minY: attachRect.y + Appearance.borderRadius
      readonly property real maxY: attachRect.y + attachRect.height - Appearance.borderRadius - surfaceHeight
      readonly property real attachY: Math.max(minY, Math.min((root.currentData?.anchorY ?? 0) - firstItemOffset, maxY))

      // Resizing or moving a popup while it shows is a round trip to the
      // compositor, so the window doesn't follow the surface: it spans
      // everywhere a submenu of this menu can sit (the parent's side, or
      // the tallest surface since it opened, from minY), as wide as the
      // widest, and the surface glides and resizes within it
      implicitWidth: Math.max(root._peakWidth, surfaceWidth) + shadowRoom
      implicitHeight: Math.max(attachRect.height - Appearance.borderRadius * 2, root._peakHeight, surfaceHeight) + shadowRoom * 2

      // Overlap the parent's side stroke with our attach-edge stroke, the
      // same way bar/edge popouts overlap the bar or border stroke
      // (backfill grows the window towards the parent, past the attach edge)
      readonly property real attachX: outer.openToLeft ? attachRect.x + Appearance.borderWidth + surface.backfill - implicitWidth : attachRect.x + attachRect.width - Appearance.borderWidth - surface.backfill

      anchor {
        window: root.currentAnchor
        rect {
          x: submenuPopup.attachX
          y: submenuPopup.minY - submenuPopup.shadowRoom
          width: 1
          height: 1
        }
      }

      // Only the surface takes input
      mask: Region {
        item: surface
      }

      AttachedSurface {
        id: surface
        x: outer.openToLeft ? submenuPopup.width - width : 0
        y: root.shownY - submenuPopup.minY + submenuPopup.shadowRoom
        width: implicitWidth
        height: implicitHeight

        edge: outer.openToLeft ? Bar.Right : Bar.Left
        castShadow: true
        active: root.occupied && !root.isClosing && (root.contentReady || still.switching)
        connectorGap: root.connectorGap
        boxWidth: root.shownBoxWidth
        boxHeight: root.shownBoxHeight
        // The parent's side stroke leaves an anti-aliased fringe on its
        // inner side: cover it (see AttachedSurface.backfill)
        backfill: 1

        // The content keeps its target size while the box animates to it,
        // hung from the box's top, and cut to the box
        Item {
          id: clipBox
          anchors.fill: parent
          clip: true

          Loader {
            id: loader
            x: surface.contentInset
            y: surface.contentInset
            width: submenuPopup.contentWidth
            height: submenuPopup.contentHeight
            opacity: still.contentOpacity
            active: root.occupied
            asynchronous: false
            sourceComponent: submenu

            onLoaded: root.updateDismissTimer()
          }

          // The entries switched away from, held where they were while
          // the box glides on
          SwitchStill {
            id: still
            contentReady: root.contentReady
            snapshot: () => ({
                  "y": root.shownY,
                  "width": root.shownBoxWidth,
                  "height": root.shownBoxHeight
                })
            x: surface.contentInset
            y: surface.contentInset + (held?.y ?? 0) - root.shownY
          }
        }
      }
    }

    Component {
      id: submenu
      TraySubmenu {
        wrapper: root
        menuItem: root.currentData?.menuItem
        maxWidth: (outer.screen?.width ?? 2000) * 0.3
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
