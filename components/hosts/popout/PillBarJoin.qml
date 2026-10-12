pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

import qs.config
import qs.services

// A surface's end joining a pill bar on a perpendicular screen edge: its
// end runs flush onto that bar's far side with no fillet (its host joins
// it straight, `straightJoinStart`/`End`), and the bar's pill at this
// edge's end runs out to the surface's far wall and squares there
// (BarContainer.setEndReach: the end pill stretched, or a stub grown where
// the bar has none there), the wall running straight up into it. Inside
// the border, or on the bare edge without it, alike.
PillStretch {
  id: root

  required property ShellScreen screen
  // The surface's own edge, and the perpendicular one it joins (Bar.Location)
  property int edge: Bar.Top
  property int side: Bar.Left
  // Whether the surface's end joins it, and is out (not loading or gone)
  property bool joined: false
  property bool showing: false
  // How far in from the surface's screen edge its joined end covers the
  // pill bar's far stroke, to its far wall's stroke (AttachedSurface.joinCover
  // from that edge, joined straight)
  property real joinReach: 0

  readonly property var _panel: ShellManager.barOn(root.screen?.name ?? "", root.side)
  // A pill bar showing there, with no integrated menu's strip on that edge
  // between: what a surface reaching that edge joins (BarPopouts' and
  // EdgePlacement's `joinable`)
  readonly property bool available: !!root._panel?.visible && (root._panel.barConfig?.pills ?? false) && EdgeMenuManager.zoneOn(root.screen?.name ?? "", Bar.edgeName(root.side)) === 0

  // Along that bar, this edge is its start (left, top) or its end
  readonly property bool _atStart: root.edge === Bar.Left || root.edge === Bar.Top
  readonly property bool _vertical: root.edge === Bar.Left || root.edge === Bar.Right
  // Where the joined end reaches along that bar (its coordinates), past
  // the join's fillet; null while the surface doesn't show
  readonly property var _reach: {
    const origin = root.container?.blurOrigin;
    if (!origin || !root.showing)
      return null;
    const span = (root._vertical ? root.screen?.width : root.screen?.height) ?? 0;
    return (root._atStart ? root.joinReach : span - root.joinReach) - (root._vertical ? origin.x : origin.y);
  }

  container: root.joined && root.available ? root._panel.container : null
  // Out to the wall's outer edge, squared there
  endReach: root._reach === null ? null : {
    "atStart": root._atStart,
    "to": root._atStart ? root._reach + Appearance.borderWidth / 2 : root._reach - Appearance.borderWidth / 2,
    "square": true
  }
  // Its far stroke left open under a translucent surface, inside the wall
  // (whose stroke carries on into the pill's there)
  opening: root._reach === null || !Appearance.translucent ? null : {
    "start": root._atStart ? 0 : root._reach + Appearance.borderWidth / 2,
    "end": root._atStart ? root._reach - Appearance.borderWidth / 2 : root.container.length
  }
}
