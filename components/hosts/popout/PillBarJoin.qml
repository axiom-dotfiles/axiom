pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

import qs.config
import qs.services

// A surface's end joining a pill bar on a perpendicular screen edge: its
// end sits on that bar's far stroke, and the bar's pill at this edge's end
// runs out along the surface (BarContainer.setEndReach: the end pill
// stretched, or a stub grown where the bar has none there). Where the
// bar's own pill already runs on past the surface's wall (`filleted`),
// the end curves into its far stroke with a fillet, as into a solid bar's
// stroke, the pill carried on past the fillet; otherwise the pill (or
// stub) runs only to the surface's far wall and squares there, the wall
// running straight up into it (the host joins it straight). Inside the
// border, or on the bare edge without it, alike.
PillStretch {
  id: root

  required property ShellScreen screen
  // The surface's own edge, and the perpendicular one it joins (Bar.Location)
  property int edge: Bar.Top
  property int side: Bar.Left
  // Whether the surface's end joins it, and is out (not loading or gone)
  property bool joined: false
  property bool showing: false
  // How far in from the surface's screen edge its joined end reaches the
  // pill bar's far stroke at its far wall (AttachedSurface.joinWall from
  // that edge)
  property real joinReach: 0

  readonly property var _panel: ShellManager.barOn(root.screen?.name ?? "", root.side)
  // A pill bar showing there, with no integrated menu's strip on that edge
  // between: what a surface reaching that edge joins (BarPopouts' and
  // EdgePlacement's `joinable`)
  readonly property bool available: !!root._panel?.visible && (root._panel.barConfig?.pills ?? false) && EdgeMenuManager.zoneOn(root.screen?.name ?? "", Bar.edgeName(root.side)) === 0

  // Along that bar, this edge is its start (left, top) or its end
  readonly property bool _atStart: root.edge === Bar.Left || root.edge === Bar.Top
  readonly property bool _vertical: root.edge === Bar.Left || root.edge === Bar.Right
  readonly property real _radius: Appearance.borderRadius
  // Where the surface's far wall meets that bar (its coordinates); null
  // while the surface doesn't show
  readonly property var _wall: {
    const origin = root._panel?.container?.blurOrigin;
    if (!origin || !root.showing || !root.joined || !root.available)
      return null;
    const span = (root._vertical ? root.screen?.width : root.screen?.height) ?? 0;
    return (root._atStart ? root.joinReach : span - root.joinReach) - (root._vertical ? origin.x : origin.y);
  }
  // Whether one of the bar's own pills (as laid out, before any surface
  // stretches it) lies past the wall, starting far enough beyond it for
  // the fillet and its own corner, and reaching near enough to it (within
  // that and pillMerge) to be carried on past the fillet: the end then
  // curves into it rather than squaring a stub at the wall
  readonly property bool filleted: {
    if (root._wall === null)
      return false;
    const merge = root._panel.barConfig.pillMerge ?? 0;
    const need = root._radius * 2;
    return (root._panel.container._sectionPills ?? []).some(p => root._atStart ? p.start + p.length >= root._wall + need && p.start <= root._wall + need + merge : p.start <= root._wall - need && p.start + p.length >= root._wall - need - merge);
  }
  // Where the joined end covers that bar's far stroke to: the fillet's
  // tip, or the wall
  readonly property var _reach: root._wall === null ? null : !root.filleted ? root._wall : root._atStart ? root._wall + root._radius : root._wall - root._radius

  container: root.joined && root.available ? root._panel.container : null
  // Filleted, past the fillet by the pill's own corner; else out to the
  // wall's outer edge, squared there
  endReach: root._reach === null ? null : root.filleted ? {
    "atStart": root._atStart,
    "to": root._atStart ? root._reach + root._radius : root._reach - root._radius
  } : {
    "atStart": root._atStart,
    "to": root._atStart ? root._reach + Appearance.borderWidth / 2 : root._reach - Appearance.borderWidth / 2,
    "square": true
  }
  // Its far stroke left open under the surface (and its fillet, which the
  // bar's shadow then follows round, BarContainer._shadowHoles; or inside
  // the wall, whose stroke carries on into the pill's there): opaque or
  // not, as the two are separate windows whose stacking isn't the bar's to
  // choose. Whole pixels where filleted (BarContainer.solidJoinOpening).
  opening: {
    if (root._reach === null)
      return null;
    if (!root.filleted)
      return {
        "start": root._atStart ? 0 : root._reach + Appearance.borderWidth / 2,
        "end": root._atStart ? root._reach - Appearance.borderWidth / 2 : root.container.length,
        "keepFill": true
      };
    const start = root._atStart ? 0 : Math.ceil(root._reach);
    const end = root._atStart ? Math.floor(root._reach) : root.container.length;
    return {
      "start": start,
      "end": end,
      "keepFill": true,
      "fillet": Math.max(0, Math.min(root._radius, end - start)),
      "filletAtEnd": root._atStart
    };
  }
}
