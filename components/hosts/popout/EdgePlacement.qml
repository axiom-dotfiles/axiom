pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

import qs.config
import qs.services
import qs.components.methods

// Where a surface growing out of a screen edge (an EdgePopout, a dock)
// goes along it, and what it meets there: the border's or a solid bar's
// stroke, a bare screen edge, or, unless held off the edge, any other bar
// on it, met as a bar popout meets it (EdgeAttach.place): out of a pill or
// a floating bar's island (stretched to carry it while it shows, through
// PillStretch), grown from a pill bar's outer edge when it shows no pills,
// or a detached box past a transparent bar. What each end meets, and what
// follows from it (joins, walls, room, straight joins, openings), and how
// it casts its shadow, are SurfaceContext's, as for bar popouts.
//
// Along the edge everything is in the host's edge coordinates: 0 at the
// perpendicular edges' inner side (where windows start there), `length`
// long (the bar's pills are shifted into them). Across it, in px from the
// screen edge.
QtObject {
  id: root

  required property ShellScreen screen
  // A Bar.Location
  property int edge: Bar.Top
  // Held off the edge (a `detached` OSD, edge menu or dock, or a surface
  // over a fullscreen window): it follows no bar, joins nothing, and keeps
  // `gaps` from the frame lines (BarManager.detachedGaps, `gap` -1 Auto)
  property bool held: false
  property int gap: -1
  readonly property var gaps: root.held ? BarManager.detachedGaps(root.screen, root.edge, root.gap) : null
  property int connectorGap: Appearance.connectorGap
  // The edge's length between the perpendicular edges' inner sides
  property real length: 0

  // The box: its centre (picks the pill), where its content would start
  // and its length, and its joined ends (EdgeAttach.joins, from `joinable`
  // and `insetStart`/`insetEnd`)
  property real centre: 0
  property real aligned: 0
  property real contentLength: 0
  property bool joinStart: false
  property bool joinEnd: false
  // The part of the surface (from its start) over the pill's or island's
  // stroke, left open there (AttachedSurface.coverStart/coverLength);
  // a negative length is the whole surface
  property real coverStart: 0
  property real coverLength: -1
  // Where along the edge (edge coordinates) a joined submenu's outer wall
  // runs straight up into the pill or island it stands on, which reaches
  // on to it (EdgeAttach.reachStretch), else null
  property var reach: null
  // Where along the edge (edge coordinates) a submenu joined to the box's
  // side covers the stroke it stands on beside the box ({ start, end }),
  // left open there too, else null
  property var submenuSpan: null

  // Its pill stretch: a key unique per surface on a bar, and whether it
  // shows (not while the content loads or unloads, the box a placeholder)
  required property string owner
  property bool showing: false
  // Whether the surface is to show (open, not closing), and whether the
  // pill has grown out to carry it: the surface slides out once it has
  // (PillStretch.ready)
  property bool open: false
  readonly property bool stretchReady: root._stretch.ready && root._startPill.ready && root._endPill.ready

  readonly property bool vertical: root.edge === Bar.Left || root.edge === Bar.Right
  readonly property string edgeName: Bar.edgeName(root.edge)
  readonly property int startSide: root.vertical ? Bar.Top : Bar.Left
  readonly property int endSide: root.vertical ? Bar.Bottom : Bar.Right
  readonly property bool bareEdge: BarManager.screenEdgeOpen(root.screen, root.edge)
  // Room for a side wall's fillet at an end that isn't joined (none on a
  // bare edge, which it runs straight off)
  readonly property real filletMargin: SurfaceContext.filletMargin(root.bareEdge, root.connectorGap, Appearance.borderWidth, Appearance.borderRadius)
  // The least room a box keeps from an end it doesn't join
  // (SurfaceContext.endRoom)
  readonly property real endRoom: SurfaceContext.endRoom(root.bareEdge, Appearance.screenBorder, root.connectorGap, Appearance.borderWidth, Appearance.borderRadius)

  // The bar on the edge, whatever it is (an enriched bar entry), or null
  readonly property var ownBar: BarManager.edgesFor(root.screen)[root.edgeName] ?? null
  // A bar other than a solid one on the edge (BarPanel), while it shows:
  // a bar inside the border hides under fullscreen windows
  readonly property var barPanel: {
    const panel = ShellManager.barOn(root.screen?.name ?? "", root.edge);
    return panel?.visible && !panel.barConfig.solid ? panel : null;
  }
  readonly property var barConfig: root.barPanel?.barConfig ?? null
  readonly property bool followsBar: !root.held && root.barConfig !== null
  // The bar's BarContainer
  readonly property var container: root.barPanel?.container ?? null
  readonly property bool island: root.followsBar && (root.barConfig?.island ?? false)
  readonly property bool pillBar: root.followsBar && ((root.barConfig?.pills ?? false) || root.island)
  // The bar's outer edge: on the border's stroke inside the border, its
  // frame line less its extent
  readonly property real barOuter: root.barConfig ? EdgeMenuManager.frameLineOn(root.screen, root.edge) - root.barConfig.extent : 0
  // A pill's (or island's) far stroke, from the bar's outer edge
  readonly property real pillFoot: root.pillBar ? (root.island ? root.barConfig.extent : root.barConfig.pillDepth) - Appearance.borderWidth : 0
  // Along the edge, bar-window coordinates are the host's plus the shift:
  // the host's window starts where windows do at its start
  // (EdgeMenuManager.reservedOn), the bar's past the bar it makes way for
  // there, or before the bars that make way for it and onto the stroke
  // (BarManager.barStartOn)
  readonly property real barShift: root.container ? EdgeMenuManager.reservedOn(root.screen, root.startSide) - BarManager.barStartOn(root.screen, root.edge, true) : 0
  // Its pills (or islands), in edge coordinates
  readonly property var pills: root.pillBar ? (root.container?.pillRects ?? []).map(p => Object.assign({}, p, {
      "start": p.start - root.barShift
    })) : []
  // Where a floating bar's islands may reach, in edge coordinates
  readonly property real islandFrom: (root.container?.islandFrom ?? 0) - root.barShift
  readonly property real islandTo: (root.container?.islandEnd ?? root.length) - root.barShift
  // Standing on an island (place's mode is "island"), decided without the
  // box's length, which may be capped by what it decides
  readonly property bool atIsland: root.island && root.pills.length > 0

  // --- Its ends (SurfaceContext.end) ---
  // What each end meets, and what that makes it: whether it may join it,
  // how far the window reaches onto its stroke, whether it's a wall, a
  // straight join, and who draws the stroke a joined end covers. Detached
  // past a transparent bar, it joins nothing (an island's ends neither:
  // a side runs flush into the island).
  readonly property var startEnd: root._endAt(root.startSide)
  readonly property var endEnd: root._endAt(root.endSide)
  function _endAt(side) {
    return SurfaceContext.end(BarManager.surfaceEnd(root.screen, side), {
      "held": root.held,
      "detached": root.followsBar && !root.pillBar,
      "ownIsland": root.island,
      "ownEndHeld": false,
      "stroke": Appearance.borderWidth
    });
  }
  readonly property bool joinableStart: root.startEnd.joins
  readonly property bool joinableEnd: root.endEnd.joins
  // How far the window reaches onto the perpendicular strokes past each
  // end, where a joined end sits (as a bar's inside the border does)
  readonly property real strokeInsetStart: root.startEnd.strokeInset
  readonly property real strokeInsetEnd: root.endEnd.strokeInset
  // Where windows start past a perpendicular edge, and where a frame line
  // plus `gap` lies, in from where this window's edge coordinates start
  // there (what's reserved there)
  function _wallInset(side) {
    return Math.max(0, SurfaceContext.wallLine(EdgeMenuManager.frameLineOn(root.screen, side), EdgeMenuManager.reservedOn(root.screen, side), HyprlandManager.gapsOut[Bar.edgeName(side)] ?? 0) - EdgeMenuManager.reservedOn(root.screen, side));
  }
  function heldInset(side, gap) {
    return EdgeMenuManager.heldInset(root.screen, side, gap);
  }
  // The least room the box keeps from each end it doesn't join: held, its
  // gaps from the frame lines there; at a wall, up to where windows start
  // (its fillet curving on past); else its fillet's past the corner
  readonly property real insetStart: root.gaps ? root.heldInset(root.startSide, root.gaps.start) : root.startEnd.wall ? root._wallInset(root.startSide) : root.endRoom
  readonly property real insetEnd: root.gaps ? root.heldInset(root.endSide, root.gaps.end) : root.endEnd.wall ? root._wallInset(root.endSide) : root.endRoom
  // How far the window reaches past each end into what's reserved there,
  // for a fillet curving on past a wall: no further than the frame's
  // inner corner, so the fillet's run along the stroke is cut short of
  // where the stroke curves away
  function _reachPast(side, end, inset) {
    if (!end.wall)
      return 0;
    const corner = Appearance.screenBorder ? Appearance.screenMargin + Appearance.borderRadius : 0;
    return Math.max(0, Math.min(root.filletMargin - inset, EdgeMenuManager.reservedOn(root.screen, side) - corner));
  }
  readonly property real reachStart: root._reachPast(root.startSide, root.startEnd, root.insetStart)
  readonly property real reachEnd: root._reachPast(root.endSide, root.endEnd, root.insetEnd)
  // Joined ends run straight off a bare screen edge, or into a pill bar's
  // stub where its pill doesn't already run on past the wall
  // (PillBarJoin.filleted)
  readonly property bool straightJoinStart: root.startEnd.straight || root.pillStraightStart
  readonly property bool straightJoinEnd: root.endEnd.straight || root.pillStraightEnd

  readonly property var place: EdgeAttach.place({
    "pills": root.pills,
    "pillBar": root.pillBar && !root.island,
    "island": root.island,
    "merge": root.barConfig?.pillMerge ?? 0,
    "centre": root.centre,
    "aligned": root.aligned,
    "length": root.contentLength,
    "joinStart": root.joinStart,
    "joinEnd": root.joinEnd,
    "joinFrom": -root.strokeInsetStart,
    "joinTo": root.length + root.strokeInsetEnd,
    "lo": root.insetStart,
    "hi": root.length - root.insetEnd,
    "wallFrom": root.startEnd.wall ? root.insetStart : undefined,
    "wallTo": root.endEnd.wall ? root.length - root.insetEnd : undefined,
    "islandFrom": root.islandFrom,
    "islandTo": root.islandTo,
    "straight": root.bareEdge,
    "straightMerged": !Appearance.screenBorder,
    "pillGrows": true,
    // Joining the perpendicular edges, it joins them from its pill, which
    // stretches to the bar's ends and joins them too
    "pillJoins": true,
    "pillFrom": -root.barShift,
    "pillTo": (root.container?.length ?? root.length) - root.barShift,
    "gap": root.connectorGap,
    "stroke": Appearance.borderWidth,
    "radius": Appearance.borderRadius
  })
  readonly property bool merged: root.place.mode === "merged"
  // Its pill stretch, reaching on to a joined submenu's wall
  readonly property var stretch: EdgeAttach.reachStretch(root.place.stretch, root.onPill ? root.place.pill : null, root.reach === null ? null : Math.max(-root.strokeInsetStart, Math.min(root.reach, root.length + root.strokeInsetEnd)))
  // Standing on a pill's or island's far stroke
  readonly property bool onPill: root.place.mode === "pill" || root.place.mode === "island"
  // A box of its own (SurfaceContext.detached): held, or on a bar with
  // nothing to grow out of (a transparent one, a floating one showing no
  // islands)
  readonly property bool detached: SurfaceContext.detached(root.held, root.barConfig, root.place.mode)
  // Runs straight off its attach edge: a bare screen edge, or without the
  // border, the outer edge a merged box grows from
  readonly property bool straight: root.merged ? !Appearance.screenBorder : root.place.mode === "plain" && root.bareEdge
  // Extra box depth at the attach edge that a merged box's content keeps
  // clear of where the pills would be by
  readonly property real attachClearance: root.merged ? root.pillFoot : 0
  // Following the bar, where the attach edge goes: the bar's outer edge
  // when merged, a pill's or island's far stroke, or a transparent bar's
  // inner edge (the box a connector gap past it, as a bar popout's is, and
  // no nearer than the windows: see Bar.detachedPush)
  readonly property real barAttach: {
    if (!root.followsBar)
      return 0;
    if (root.merged)
      return root.barOuter;
    if (root.onPill)
      return root.barOuter + root.pillFoot;
    return root.barOuter + root.barConfig.extent + Bar.detachedPush(root.barConfig, HyprlandManager.gapsOut[root.edgeName] ?? 0, root.connectorGap);
  }
  // A fillet sharing a wall's room with its island's (or pill's) corner
  // takes less of it (EdgeAttach), else the full room (-1):
  // AttachedSurface.startFilletMargin/endFilletMargin
  readonly property real startFilletMargin: root.place.startMargin > 0 && root.place.startMargin < root.filletMargin ? root.place.startMargin : -1
  readonly property real endFilletMargin: root.place.endMargin > 0 && root.place.endMargin < root.filletMargin ? root.place.endMargin : -1
  // On a pill's far stroke the surface covers that stroke's inner fringe
  readonly property int backfill: !root.detached && root.onPill ? 1 : 0

  // --- Its shadow (SurfaceContext.shadow) ---
  // What it grows out of: its bar (pills, islands, a merged box's outer
  // edge, a solid bar's own stroke with the border off), the border, or a
  // bare edge. AttachedSurface's shadowLook/shadowEdge/shadowFalls.
  readonly property var shadow: SurfaceContext.shadow({
    "edge": root.edge,
    "detached": root.detached,
    "border": Appearance.screenBorder,
    "bar": root.ownBar,
    "onBar": !root.held && (root.onPill || root.merged || (root.ownBar?.innerStroke ?? false))
  })
  readonly property var shadowLook: root.shadow.look === "bar" ? root.ownBar : BarStyle.values

  // --- Its fill (BlurManager) ---
  // Whether its window is on the Overlay layer, and where it is on screen
  // (LayerOrigin.origin, null until known): the blur window draws its fill
  // and casts its shadow where it backs that layer on its screen; else it
  // fills itself, solid while blur is paused for a fullscreen window there
  property bool onOverlayLayer: true
  property var origin: null
  readonly property bool backed: BlurManager.backsOn(root.screen, root.onOverlayLayer) && root.origin !== null
  readonly property bool opaque: BlurManager.opaqueOn(root.screen)

  // --- The strokes it covers (StrokeOpening) ---
  // The surface (its AttachedSurface, positioned in its window from the
  // window's origin) and whether its openings show: out, and granted
  property var attachedSurface: null
  property bool opens: false
  readonly property real _span: (root.vertical ? root.screen?.width : root.screen?.height) ?? 0
  // Along its own edge, the stroke it stands on: the border's, or with the
  // border off a solid bar's own (not a pill's or island's, PillStretch
  // below; nor a bare edge's)
  readonly property var ownSink: root.detached || root.onPill || (root.barPanel && !root.merged) ? null : root.merged ? (Appearance.screenBorder ? "border" : null) : root.bareEdge ? null : Appearance.screenBorder ? "border" : "solidBar"
  function _edgeSpan(start, end) {
    return {
      "screen": root.screen?.name ?? "",
      "edge": root.edgeName,
      "start": EdgeMenuManager.reservedOn(root.screen, root.startSide) + start,
      "end": EdgeMenuManager.reservedOn(root.screen, root.startSide) + end
    };
  }
  readonly property var _coverSpan: {
    if (!root.opens || !root.attachedSurface)
      return null;
    const start = root.place.surfaceStart + root.coverStart;
    const length = root.coverLength < 0 ? root.place.surfaceLength : root.coverLength;
    return length > 0 ? root._edgeSpan(start, start + length) : null;
  }
  // At a joined end, the perpendicular edge's stroke its end covers, from
  // where its window is on screen, its fillet included
  function _joinSpan(atStart) {
    const s = root.attachedSurface;
    if (!root.opens || !s || !root.origin)
      return null;
    const from = root.vertical ? root.origin.x + s.x : root.origin.y + s.y;
    return Object.assign({
      "screen": root.screen?.name ?? ""
    }, EdgeAttach.joinOpening(root.edgeName, atStart, from, root.vertical ? s.width : s.height, atStart ? s.joinShown : s.joinShownEnd, root._span, atStart ? s.joinFillet : s.joinFilletEnd));
  }
  property StrokeOpening _ownOpening: StrokeOpening {
    screen: root.screen
    owner: root.owner + ":stroke"
    sink: root.ownSink
    span: root._coverSpan
  }
  property StrokeOpening _submenuOpening: StrokeOpening {
    screen: root.screen
    owner: root.owner + ":submenuStroke"
    sink: root.ownSink
    span: root.opens && root.submenuSpan ? root._edgeSpan(root.submenuSpan.start, root.submenuSpan.end) : null
  }
  property StrokeOpening _startOpening: StrokeOpening {
    screen: root.screen
    owner: root.owner + ":joinStartStroke"
    sink: root.startEnd.sink
    span: root.attachedSurface?.joinStart ? root._joinSpan(true) : null
  }
  property StrokeOpening _endOpening: StrokeOpening {
    screen: root.screen
    owner: root.owner + ":joinEndStroke"
    sink: root.endEnd.sink
    span: root.attachedSurface?.joinEnd ? root._joinSpan(false) : null
  }

  // How far in from this edge (screen px) a joined end covers the stroke
  // it joins, its fillet included (the host's AttachedSurface.joinCover
  // from its window's attach edge), for the pill stretch
  property real joinReach: 0
  // Whether each end joins a pill bar, which it runs straight into
  readonly property bool pillJoinStart: root._startPill.joined
  readonly property bool pillJoinEnd: root._endPill.joined
  // ...straight, squared into a stub, where its pill doesn't already run
  // on past the wall (PillBarJoin.filleted)
  readonly property bool pillStraightStart: root._startPill.joined && !root._startPill.filleted
  readonly property bool pillStraightEnd: root._endPill.joined && !root._endPill.filleted
  property PillBarJoin _startPill: PillBarJoin {
    screen: root.screen
    edge: root.edge
    side: root.startSide
    owner: root.owner + ":joinStart"
    open: root.open
    joined: root.joinStart && root.startEnd.sink === "pillBar"
    showing: root.showing
    joinReach: root.joinReach
  }
  property PillBarJoin _endPill: PillBarJoin {
    screen: root.screen
    edge: root.edge
    side: root.endSide
    owner: root.owner + ":joinEnd"
    open: root.open
    joined: root.joinEnd && root.endEnd.sink === "pillBar"
    showing: root.showing
    joinReach: root.joinReach
  }

  // The pill (or island) stretched to carry the box's fillets while it
  // shows, in bar coordinates
  property PillStretch _stretch: PillStretch {
    container: root.container
    owner: root.owner
    open: root.open
    stretch: root.showing && root.stretch ? Object.assign({}, root.stretch, {
      "start": root.stretch.start + root.barShift,
      "end": root.stretch.end + root.barShift
    }) : null
    // The pill's or island's far stroke left open under a translucent box
    opening: root.showing && root.onPill && Appearance.translucent ? {
      "start": root.place.surfaceStart + root.coverStart + root.barShift,
      "end": root.place.surfaceStart + root.coverStart + (root.coverLength < 0 ? root.place.surfaceLength : root.coverLength) + root.barShift
    } : null
  }
  property PillStretch _submenuStretch: PillStretch {
    container: root.container
    owner: root.owner + ":submenu"
    opening: root.showing && root.onPill && Appearance.translucent && root.submenuSpan ? {
      "start": root.submenuSpan.start + root.barShift,
      "end": root.submenuSpan.end + root.barShift
    } : null
  }
}
