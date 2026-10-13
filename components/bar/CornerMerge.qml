pragma ComponentBehavior: Bound
import QtQuick

import qs.config
import qs.components.hosts.popout

// One end of a side pill bar that makes way for a pill bar at its corner
// (BarEnds "pillBar"), with its end pill joined there: that bar's end pill
// (grown if the bar has none there, BarContainer.setEndReach) runs on past
// this pill's join fillet, straight off its own end, its far stroke left
// open where this pill joins it, so the two read as one with a single
// concave corner, as against a solid bar.
PillStretch {
  id: root
  // A BarContainer (typed var: its own members are read)
  required property var bar
  required property bool atStart

  readonly property var _rects: root.bar.pillRects
  readonly property var _pill: root.atStart ? root._rects[0] : root._rects[root._rects.length - 1]
  // Only a side bar makes way for one of its kind (the pill bar there is
  // BarContainer.barAt's)
  readonly property bool _joins: root.bar.isVertical && !!root._pill && (root.atStart ? root._pill.joinStart : root._pill.joinEnd)
  readonly property var _origin: root.bar.blurOrigin
  readonly property var _otherOrigin: root.container?.blurOrigin ?? null
  readonly property bool _placed: root.container !== null && root._origin !== null && root._otherOrigin !== null
  // On a right bar the other bar's end is its far one
  readonly property bool _right: root.bar.barConfig.right
  // Its pills' far edge, across the screen
  readonly property real _far: !root._origin ? 0 : root._right ? root._origin.x + root.bar.width - root.bar.barConfig.pillDepth : root._origin.x + root.bar.barConfig.pillDepth
  readonly property real _radius: Appearance.borderRadius

  owner: "corner:" + root.bar.barConfig.id + (root.atStart ? ":start" : ":end")
  open: true
  container: root._joins ? (root.atStart ? root.bar.pillBarStart : root.bar.pillBarEnd) : null
  // Past the join's fillet, with room for the other pill's own corner
  endReach: root._placed ? {
    "atStart": !root._right,
    "to": (root._right ? root._far - 2 * root._radius : root._far + 2 * root._radius) - root._otherOrigin.x,
    "straight": true
  } : null
  // Its far stroke, from where the join's fillet meets it on to its end,
  // the other bar's shadow following round that fillet
  // (BarContainer._shadowHoles)
  opening: root._placed ? {
    "start": root._right ? root._far - root._radius + 1 - root._otherOrigin.x : 0,
    "end": root._right ? root.container.length : root._far + root._radius - 1 - root._otherOrigin.x,
    "keepFill": true,
    "fillet": root._radius - 1,
    "filletAtEnd": !root._right
  } : null
}
