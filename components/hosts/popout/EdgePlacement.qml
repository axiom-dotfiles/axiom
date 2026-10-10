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
// or a detached box past a transparent bar.
//
// Along the edge everything is in the host's edge coordinates: 0 at the
// perpendicular edges' inner side, `length` long (the bar's pills are
// shifted into them). Across it, in px from the screen edge.
QtObject {
  id: root

  required property ShellScreen screen
  // A Bar.Location
  property int edge: Bar.Top
  // Held off the edge (a `detached` OSD, edge menu or dock): it follows
  // no bar
  property bool held: false
  property int connectorGap: Appearance.borderRadius * 2
  // The edge's length, and how far the host's window reaches onto the
  // perpendicular strokes past each end (where joined ends sit)
  property real length: 0
  property real strokeInset: 0

  // The box: its centre (picks the pill), where its content would start
  // and its length, its joined ends (EdgeAttach.joins), and the range an
  // unjoined box keeps within (its fillets' room included)
  property real centre: 0
  property real aligned: 0
  property real contentLength: 0
  property bool joinStart: false
  property bool joinEnd: false
  property real lo: 0
  property real hi: 0
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
  readonly property bool stretchReady: root._stretch.ready && root._startPillStretch.ready && root._endPillStretch.ready

  readonly property bool vertical: root.edge === Bar.Left || root.edge === Bar.Right
  readonly property string edgeName: Bar.edgeName(root.edge)
  readonly property bool bareEdge: BarManager.screenEdgeOpen(root.screen, root.edge)
  // Room for a side wall's fillet at an end that isn't joined (none on a
  // bare edge, which it runs straight off)
  readonly property real filletMargin: root.bareEdge ? 0 : EdgeAttach.filletMargin(root.connectorGap, Appearance.borderWidth, Appearance.borderRadius)
  // The least room a box keeps from an end it doesn't join: its fillet's,
  // past the corner into the perpendicular edge (the frame's inner corner,
  // or a pill joined to this edge), whose arc a fillet's run along the
  // stroke would draw a straight stub beside
  readonly property real endRoom: root.filletMargin + (Appearance.screenBorder && !root.bareEdge ? Appearance.borderRadius : 0)

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
  // Along the edge, bar-window coordinates are the host's plus the shift.
  // The bar window reaches onto the perpendicular strokes and the host's
  // sits inside them, taken as the same at both ends (as BarPopouts does
  // for the perpendicular borders).
  readonly property real barShift: root.container ? (root.container.length - root.length) / 2 : 0
  // Its pills (or islands), in edge coordinates
  readonly property var pills: root.pillBar ? (root.container?.pillRects ?? []).map(p => Object.assign({}, p, {
      "start": p.start - root.barShift
    })) : []

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
    "joinFrom": -root.strokeInset,
    "joinTo": root.length + root.strokeInset,
    "lo": root.lo,
    "hi": root.hi,
    "islandFrom": (root.barConfig?.islandStart ?? 0) - root.barShift,
    "islandTo": (root.container?.islandEnd ?? root.length) - root.barShift,
    "straight": root.bareEdge,
    "straightMerged": !Appearance.screenBorder,
    "pillGrows": true,
    "gap": root.connectorGap,
    "stroke": Appearance.borderWidth,
    "radius": Appearance.borderRadius
  })
  readonly property bool merged: root.place.mode === "merged"
  // Its pill stretch, reaching on to a joined submenu's wall
  readonly property var stretch: EdgeAttach.reachStretch(root.place.stretch, root.onPill ? root.place.pill : null, root.reach === null ? null : Math.max(-root.strokeInset, Math.min(root.reach, root.length + root.strokeInset)))
  // Standing on a pill's or island's far stroke
  readonly property bool onPill: root.place.mode === "pill" || root.place.mode === "island"
  // A box of its own: held, or on a bar with nothing to grow out of (a
  // transparent one, a floating one showing no islands)
  readonly property bool detached: root.held || (root.followsBar && !root.pillBar) || (root.island && root.place.mode === "plain")
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

  // Whether a perpendicular edge ("top", …) has a stroke to join: the
  // border or a solid bar (`joinable`), not any other bar, nor an
  // integrated menu's strip
  function joinable(name) {
    const bar = BarManager.edgesFor(root.screen)[name];
    return (!bar || bar.joinable || root.endPill(Bar.locationOf(name)) !== null) && EdgeMenuManager.zoneOn(root.screen?.name ?? "", name) === 0;
  }

  // With `joinsPills`, a pill bar on a perpendicular edge (a Bar.Location) is
  // joinable too where its pill at this edge's end joins this edge: the
  // box's end joins that pill's far stroke as a solid bar's, the pill
  // stretched across to carry the join's fillet (endStretch). Inside the
  // border only: without it the join would run straight off the screen
  // edge, past the pill's stroke.
  property bool joinsPills: false
  // That pill ({ container, index, start, length }, bar coordinates), or null
  function endPill(location) {
    if (!root.joinsPills || root.held || !Appearance.screenBorder)
      return null;
    const panel = ShellManager.barOn(root.screen?.name ?? "", location);
    if (!panel?.visible || !panel.barConfig.pills || panel.barConfig.island)
      return null;
    const pills = panel.container?.pillRects ?? [];
    // Along that bar, this edge is its start (left, top) or its end
    const atStart = root.edge === Bar.Left || root.edge === Bar.Top;
    const index = atStart ? 0 : pills.length - 1;
    const pill = pills[index];
    if (!pill || !(atStart ? pill.joinStart : pill.joinEnd))
      return null;
    return {
      "container": panel.container,
      "index": index,
      "start": pill.start,
      "length": pill.length
    };
  }
  // How far in from this edge (screen px) a joined end covers the stroke
  // it joins, its fillet included (the host's AttachedSurface.joinCover
  // from its window's attach edge), for the pill stretch
  property real joinReach: 0
  readonly property var _startPill: root.joinStart ? root.endPill(root.vertical ? Bar.Top : Bar.Left) : null
  readonly property var _endPill: root.joinEnd ? root.endPill(root.vertical ? Bar.Bottom : Bar.Right) : null
  // Where a joined end reaches along its pill's bar (in its coordinates),
  // past the join's fillet; null while the box doesn't show
  function _reachOn(pill) {
    const origin = pill?.container?.blurOrigin;
    if (!origin || !root.showing)
      return null;
    const span = (root.vertical ? root.screen?.width : root.screen?.height) ?? 0;
    return (root._far ? span - root.joinReach : root.joinReach) - (root.vertical ? origin.x : origin.y);
  }
  readonly property bool _far: root.edge === Bar.Right || root.edge === Bar.Bottom
  // A joined end's pill stretched from this edge to past the join's
  // fillet, with room for the pill's corner beyond
  function _endStretch(pill) {
    const reach = root._reachOn(pill);
    if (reach === null)
      return null;
    const end = pill.start + pill.length;
    return {
      "index": pill.index,
      "start": root._far ? Math.min(pill.start, reach - Appearance.borderRadius) : pill.start,
      "end": root._far ? end : Math.max(end, reach + Appearance.borderRadius),
      "squareStart": false,
      "squareEnd": false
    };
  }
  // ...and its far stroke left open under a translucent box, as far as
  // the join covers it
  function _endOpening(pill) {
    const reach = root._reachOn(pill);
    if (reach === null || !Appearance.translucent)
      return null;
    return {
      "start": root._far ? reach : pill.start,
      "end": root._far ? pill.start + pill.length : reach
    };
  }
  property PillStretch _startPillStretch: PillStretch {
    container: root._startPill?.container ?? null
    owner: root.owner + ":joinStart"
    open: root.open
    stretch: root._endStretch(root._startPill)
    opening: root._endOpening(root._startPill)
  }
  property PillStretch _endPillStretch: PillStretch {
    container: root._endPill?.container ?? null
    owner: root.owner + ":joinEnd"
    open: root.open
    stretch: root._endStretch(root._endPill)
    opening: root._endOpening(root._endPill)
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
