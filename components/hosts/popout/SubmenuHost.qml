pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

import qs.config
import qs.components.reusable

// A popout host's submenu (SubPopout, one level deep) and everything the
// two share, the same for a bar popout and an edge popout: what the
// submenu meets on the box's side (SubmenuSide), how far it stretches the
// box past its top or bottom (parentStretch, drawn animated), the box at
// rest it attaches to, and what it leaves open in the box's strokes and
// shadow (submenuHole, submenuBox, submenuJoinSpan), which the host's
// EdgeSurface and EdgePlacement take. The submenu reads it as its `slot`.
Item {
  id: root

  // The popout host (BarPopouts, EdgePopout: a PopoutWrapperBase), whose
  // window's size picks the side a submenu opens on
  required property var wrapper
  required property ShellScreen screen
  // The host's surface (an EdgeSurface: the submenu casts its shadow as
  // it does), the box's content box in its
  // window, and where that window is on screen: null until known, or where
  // it most likely is (for the submenu's footprint)
  required property var popupSurface
  property rect boxRect: Qt.rect(0, 0, 0, 0)
  property var popupScreenOrigin: null
  property point popupScreenPlaced: Qt.point(0, 0)
  // Glide the stretch (once the host's box has settled)
  property bool animate: false

  // The host's EdgePlacement, and how far its coordinates are from its
  // window's along the edge: what the submenu meets on the box's side
  // (SubmenuSide) follows from it. The stroke the box grows from reaches
  // (x in the window) as far as its pill or island as the box stretches
  // it, else the perpendicular strokes.
  required property var geometry
  property real windowShift: 0
  // (read null-safe: the first evaluation, as the host is built, may
  // come before its placement's)
  readonly property var _place: root.geometry?.place ?? null
  readonly property var _pill: root.geometry?.onPill ? (root._place?.stretch ?? root._place?.pill ?? null) : null
  readonly property real _strokeFrom: root._pill ? root._pill.start : (root.geometry?.strokeFrom ?? 0)
  readonly property real _strokeTo: root._pill ? (root._pill.end ?? root._pill.start + root._pill.length) : (root.geometry?.strokeTo ?? 0)

  readonly property int edge: root.geometry.edge
  readonly property bool vertical: root.edge === Bar.Left || root.edge === Bar.Right
  readonly property SubmenuSide side: SubmenuSide {
    edge: root.edge
    detached: root.geometry.detached
    straight: root.geometry.straight
    attachLine: root.edge === Bar.Bottom ? root.popupSurface.y + root.popupSurface.height - root.popupSurface.backfill : root.popupSurface.y + root.popupSurface.backfill
    backfill: root.popupSurface.backfill
    strokeFrom: root._strokeFrom + root.windowShift
    strokeTo: root._strokeTo + root.windowShift
    joinStart: root._place?.joinStart ?? false
    joinEnd: root._place?.joinEnd ?? false
    boxCentreX: root.boxRect.x + root.boxRect.width / 2
    boxCentreY: root.boxRect.y + root.boxRect.height / 2
    windowWidth: root.wrapper.window?.width ?? 0
    windowHeight: root.wrapper.window?.height ?? 0
    stretch: root.stretch
  }
  readonly property bool openToLeft: root.side.openToLeft
  // Joined at the bar side, the stroke the box's wall there ran flush into
  // carries on past it, under the submenu
  readonly property bool sideJoined: root.side.joined

  // The submenu, opened by a PopoutAnchor in the host's content (its
  // window's popoutHost)
  readonly property SubPopout submenu: sub
  readonly property bool open: sub.occupied
  SubPopout {
    id: sub
    screen: root.screen
    openToLeft: root.openToLeft
    host: root.wrapper
    slot: root
  }

  // What an open submenu asks of the box (SubPopout.parentStretch: { top,
  // bottom, squareTop, squareBottom, joined, joinReach }), along y in both
  // orientations: submenus open to the left or right. It reaches past the
  // box's top or bottom to carry one longer than its side, and squares its
  // corner where one runs flush to its end, as a pill does for a popout.
  readonly property var stretch: root.wrapper.occupied ? sub.parentStretch : null
  property real shownStretchTop: root.stretch?.top ?? 0
  property real shownStretchBottom: root.stretch?.bottom ?? 0
  Glide on shownStretchTop {
    enabled: root.animate
  }
  Glide on shownStretchBottom {
    enabled: root.animate
  }
  // Across a top or bottom edge's box (along a side edge's, the box
  // reaches past its content's ends instead): as asked, and as drawn
  readonly property real stretchAcross: root.vertical ? 0 : (root.stretch?.top ?? 0) + (root.stretch?.bottom ?? 0)
  readonly property real shownStretchAcross: root.vertical ? 0 : root.shownStretchTop + root.shownStretchBottom
  // The box at rest, without the stretch: what the submenu attaches to
  readonly property rect attachBox: Qt.rect(root.boxRect.x, root.boxRect.y + root.shownStretchTop, root.boxRect.width, root.boxRect.height - root.shownStretchTop - root.shownStretchBottom)
  // How far down from attachBox's top `item` (in the content) is, the box
  // at rest
  function anchorOffsetOf(item) {
    return item.mapToItem(root.popupSurface.contentBox, 0, 0).y - root.shownStretchTop;
  }

  // Set by the submenu, in the host's window: the stroke it covers on the
  // box's side, its box (which the box's own shadow leaves out), and,
  // joined to the box's bar side, the stretch of the stroke it joins that
  // it covers beside the box ({ start, end }, x)
  property var submenuHole: null
  property var submenuBox: null
  property var submenuJoinSpan: null
  // The hole a submenu leaves in the box's side follows it sliding, in
  // its own window: shown in the host's only once that one commits again
  onSubmenuHoleChanged: nudge.burst()
  FrameNudge {
    id: nudge
    parent: root.wrapper.window?.contentItem ?? null
  }

  // ...and for the host's EdgePlacement, in its coordinates along the
  // edge: where a joined submenu's outer wall runs straight up into the
  // pill or island the box stands on (EdgeAttach.reachStretch), and the
  // stretch of that stroke it covers beside the box
  readonly property var joinReach: root.stretch?.joinReach != null ? root.stretch.joinReach - root.windowShift : null
  readonly property var joinSpan: root.submenuJoinSpan ? {
    "start": root.submenuJoinSpan.start - root.windowShift,
    "end": root.submenuJoinSpan.end - root.windowShift
  } : null

  // For the host's surface: its stroke holes (the submenu's opening in the
  // box's side, and joined at the bar side, the fillet there) and the
  // submenu's box, which its own shadow isn't cast on
  readonly property var strokeHoles: root.popupSurface.submenuHoles(root.submenuHole, root.sideJoined, root.openToLeft)
  readonly property var shadowHoles: root.submenuBox ? [Qt.rect(root.submenuBox.x - root.popupSurface.x, root.submenuBox.y - root.popupSurface.y, root.submenuBox.width, root.submenuBox.height)] : []
}
