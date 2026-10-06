pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.components.methods
import qs.components.content.parts
import qs.components.reusable

/**
 * Popout wrapper for tray submenus.
 * Attaches to the side of the parent popout's box (right, or left when
 * openToLeft) with the same AttachedSurface shape as bar/edge popouts,
 * level with the hovered item and slid out of the parent. Another
 * submenu of the same menu switches in place (SwitchStill).
 * Along the parent's side it's placed as a bar popout is along a pill
 * (EdgeAttach.place): a side whose fillet has no room before an end of
 * the parent's side runs flush to it where that end is free (the parent
 * squaring its corner there), or joins the stroke the parent grows from
 * at its bar side (a solid bar's, a pill's, the border's), as a popout
 * joins the perpendicular border; a submenu longer than the side
 * stretches the parent (parentStretch, which the parent's BarPopouts
 * draws, a joined submenu's outer fillet on its pill included).
 * Open/close/queue state and dismiss timing come from PopoutWrapperBase —
 * this file only adds submenu-specific positioning and animation.
 */
Item {
  id: outer

  required property ShellScreen screen
  required property bool openToLeft
  // The parent popout (BarPopouts): its box at rest (attachBox), which
  // ends of the side we open on we may run flush to (sideFreeTop/Bottom)
  // or join at its bar side (sideJoinTop/Bottom, at sideJoinLine)
  required property var host

  // What the parent draws for us while we show: how far its box reaches
  // past its top and bottom, whether it squares its corner there, and,
  // joined to its bar side without room for our outer fillet, where along
  // the bar (x in its window) the pill or island we join must reach: our
  // outer wall, running straight up into its squared end
  readonly property var parentStretch: {
    if (!root.occupied || !(root.contentReady || still.switching))
      return null;
    const stretch = root.place.stretch;
    const joined = root.place.joinStart || root.place.joinEnd;
    return {
      "top": stretch ? Math.max(0, root.attachRect.y - stretch.start) : 0,
      "bottom": stretch ? Math.max(0, stretch.end - root.attachEnd) : 0,
      "squareTop": stretch?.squareStart ?? false,
      "squareBottom": stretch?.squareEnd ?? false,
      "joined": joined,
      "joinReach": joined && !root.joinFillets ? root.outerWall : null
    };
  }

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

    // The parent popout's content box at rest, in the anchor window's
    // coordinates, read live (the parent's window may move as it grows).
    // Its free sides are the outer edge of the parent's stroke
    // (AttachedSurface.boxRect).
    readonly property rect attachRect: outer.host?.attachBox ?? Qt.rect(0, 0, 0, 0)
    readonly property real attachEnd: root.attachRect.y + root.attachRect.height

    // Along the parent's side (y in its window), the box with its first
    // item level with the hovered one, as a bar popout is placed along a
    // pill: the content stays there, moved only to stay within reach, or
    // nudged up to an end rather than leave an empty sliver. A side with no
    // room for its fillet runs flush to a free end (the parent's far
    // edge's; on an island or a detached box its bar side's too), or joins
    // the stroke the parent grows from at its bar side, reaching up to it.
    // Any other end (a joined parent's) keeps the fillet clear of the
    // parent's own.
    readonly property real boxLength: submenuPopup.contentHeight + surface.contentInset * 2
    readonly property real _need: EdgeAttach.filletMargin(root.connectorGap, Appearance.borderWidth, Appearance.borderRadius) + Appearance.borderRadius
    readonly property real _joinLine: outer.host?.sideJoinLine ?? 0
    readonly property bool _joinTop: outer.host?.sideJoinTop ?? false
    readonly property bool _joinBottom: outer.host?.sideJoinBottom ?? false
    readonly property real reachTop: root._joinTop ? root._joinLine : root.attachRect.y + (outer.host?.sideFreeTop ? 0 : root._need)
    readonly property real reachBottom: root._joinBottom ? root._joinLine : root.attachEnd - (outer.host?.sideFreeBottom ? 0 : root._need)
    // Longer than the side, it hangs past its far end (up, on a bottom
    // bar), stretching the parent
    readonly property real reachFrom: outer.host?.sideGrowsUp ? Math.min(root.reachTop, root.reachBottom - root.boxLength) : root.reachTop
    readonly property real alignedBoxStart: root.attachRect.y + (root.currentData?.anchorOffset ?? 0) - surface.contentInset
    readonly property var place: EdgeAttach.place({
      "pills": [
        {
          "start": root.attachRect.y,
          "length": root.attachRect.height,
          "joinStart": root._joinTop,
          "joinEnd": root._joinBottom
        }
      ],
      "pillBar": true,
      "island": false,
      "merge": 0,
      "centre": root.alignedBoxStart + root.boxLength / 2,
      "aligned": root.alignedBoxStart,
      "length": root.boxLength,
      "joinFrom": root.reachFrom,
      "joinTo": root.reachBottom,
      "nudge": true,
      "gap": root.connectorGap,
      "stroke": Appearance.borderWidth,
      "radius": Appearance.borderRadius
    })

    // The box at its content's size (grown to a flush end) and placed, and
    // as drawn: animated to them once it shows (not on opening), and held
    // as it was while a switch waits for its entries
    readonly property real targetBoxWidth: submenuPopup.contentWidth + surface.contentInset * 2
    // The box's outer wall (outer edge of its stroke), x in the parent's
    // window: our attach edge lies a stroke inside the parent's side
    readonly property real outerWall: outer.openToLeft ? root.attachRect.x + Appearance.borderWidth - surface.boxStart - root.targetBoxWidth : root.attachRect.x + root.attachRect.width - Appearance.borderWidth + surface.boxStart + root.targetBoxWidth
    // Joined, whether what we join reaches past our outer fillet and the
    // corner beyond it (sideJoinFrom/To); else our wall runs straight up
    // into it, stretched to meet it
    readonly property real _joinRoom: Appearance.borderRadius * 2
    readonly property bool joinFillets: outer.openToLeft ? root.outerWall - root._joinRoom >= (outer.host?.sideJoinFrom ?? 0) : root.outerWall + root._joinRoom <= (outer.host?.sideJoinTo ?? 0)
    readonly property real targetBoxHeight: root.place.end - root.place.start
    property real shownBoxWidth: still.holding ? still.held.width : root.targetBoxWidth
    property real shownBoxHeight: still.holding ? still.held.height : root.targetBoxHeight
    property real shownBoxStart: still.holding ? still.held.start : root.place.start
    property bool _settled: false
    function _updateSettled() {
      if (!root.occupied || !(root.contentReady || still.switching))
        root._settled = false;
      else
        Qt.callLater(() => root._settled = root.occupied && (root.contentReady || still.switching));
    }
    Glide on shownBoxWidth {
      enabled: root._settled
    }
    Glide on shownBoxHeight {
      enabled: root._settled
    }
    Glide on shownBoxStart {
      enabled: root._settled
    }

    // The widest surface since it opened, and the furthest it reached past
    // either end of the parent's side, which the window keeps room for
    property real _peakWidth: 0
    property real _peakFrom: 0
    property real _peakTo: 0
    function _notePeak() {
      if (!root.occupied || !root.contentReady)
        return;
      root._peakWidth = Math.max(root._peakWidth, submenuPopup.surfaceWidth);
      root._peakFrom = Math.min(root._peakFrom, submenuPopup.surfaceFrom);
      root._peakTo = Math.max(root._peakTo, submenuPopup.surfaceTo);
    }
    onContentReadyChanged: {
      _notePeak();
      _updateSettled();
    }
    onOccupiedChanged: {
      if (!root.occupied) {
        root._peakWidth = 0;
        root._peakFrom = 0;
        root._peakTo = 0;
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
      // The surface at the target box size and place (it's drawn at the
      // shown one), along the side from the parent's box top
      readonly property real surfaceWidth: surface.implicitWidth - root.shownBoxWidth + root.targetBoxWidth
      readonly property real surfaceFrom: root.place.surfaceStart - root.attachRect.y
      readonly property real surfaceTo: surfaceFrom + root.place.surfaceLength
      onSurfaceWidthChanged: root._notePeak()
      onSurfaceFromChanged: root._notePeak()
      onSurfaceToChanged: root._notePeak()

      // Room for the shadow or glow the surface casts (SurfaceShadow) on
      // its free sides: away from the parent, above and below
      readonly property real shadowRoom: BarStyle.shadowReach
      // None past the bar side we may join, so it doesn't fall over the
      // bar (as the parent's slide clips its own there)
      // (but the parent's backfill row, which a joined surface covers)
      readonly property real joinBackfill: outer.host?.sideJoinBackfill ?? 0
      readonly property real roomTop: outer.host?.sideJoinTop ? joinBackfill : shadowRoom
      readonly property real roomBottom: outer.host?.sideJoinBottom ? joinBackfill : shadowRoom

      // Resizing or moving a popup while it shows is a round trip to the
      // compositor, so the window doesn't follow the surface: it spans
      // everywhere a submenu of this menu can sit (the parent's side, and
      // as far past it as any surface since it opened), as wide as the
      // widest, and the surface glides and resizes within it
      readonly property real windowFrom: Math.min(root._peakFrom, surfaceFrom)
      readonly property real windowTo: Math.max(root.attachRect.height, root._peakTo, surfaceTo)
      implicitWidth: Math.max(root._peakWidth, surfaceWidth) + shadowRoom
      implicitHeight: windowTo - windowFrom + roomTop + roomBottom

      // Overlap the parent's side stroke with our attach-edge stroke, the
      // same way bar/edge popouts overlap the bar or border stroke
      // (backfill grows the window towards the parent, past the attach edge)
      readonly property real attachX: outer.openToLeft ? root.attachRect.x + Appearance.borderWidth + surface.backfill - implicitWidth : root.attachRect.x + root.attachRect.width - Appearance.borderWidth - surface.backfill

      anchor {
        window: root.currentAnchor
        rect {
          x: submenuPopup.attachX
          y: root.attachRect.y + submenuPopup.windowFrom - submenuPopup.roomTop
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
        y: root.shownBoxStart - surface.startMargin - root.attachRect.y - submenuPopup.windowFrom + submenuPopup.roomTop
        width: implicitWidth
        height: implicitHeight

        edge: outer.openToLeft ? Bar.Right : Bar.Left
        castShadow: true
        active: root.occupied && !root.isClosing && (root.contentReady || still.switching)
        connectorGap: root.connectorGap
        boxWidth: root.shownBoxWidth
        boxHeight: root.shownBoxHeight
        // A side with no room for its fillet before a free end of the
        // parent's side runs straight on to it
        flushStart: root.place.flushStart
        flushEnd: root.place.flushEnd
        // At the parent's bar side, on the stroke it grows from
        joinStart: root.place.joinStart
        joinEnd: root.place.joinEnd
        straightJoins: (outer.host?.sideStraightJoin ?? false) || !root.joinFillets
        // The parent's side stroke leaves an anti-aliased fringe on its
        // inner side: cover it (see AttachedSurface.backfill)
        backfill: 1
        joinBackfill: submenuPopup.joinBackfill

        // The content keeps its target size while the box animates to it,
        // where it wants to be along the side (EdgeAttach.place's
        // contentStart), however far the box grows past it, and cut to the
        // box
        Item {
          id: clipBox
          anchors.fill: parent
          clip: true

          Loader {
            id: loader
            x: surface.contentInset
            y: surface.contentInset + root.place.contentStart - root.shownBoxStart
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
                  "start": root.shownBoxStart,
                  "width": root.shownBoxWidth,
                  "height": root.shownBoxHeight,
                  "along": root.place.contentStart
                })
            x: surface.contentInset
            y: surface.contentInset + (held?.along ?? 0) - root.shownBoxStart
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

  // What the tray menu (content/SystemTray) uses of the inner
  // PopoutWrapperBase; TraySubmenu is handed that one itself
  property alias occupied: root.occupied
  // The submenu already open (the pointer back on its item) stays as it
  // is rather than being rebuilt
  function safeOpenPopout(anchor, data) {
    if (root.isOpen && anchor === root.currentAnchor && data?.menuItem === root.currentData?.menuItem) {
      root.updateDismissTimer();
      return;
    }
    root.safeOpenPopout(anchor, data);
  }
  function closePopout() {
    root.closePopout();
  }
}
