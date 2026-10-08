pragma ComponentBehavior: Bound
import QtQuick

// A copy of an AttachedSurface's shape, its geometry bound live to the
// source's (sliding with it: its own slide runs with the source's
// `active`): its fill alone, or with `mirrorStroke`. The blur window draws
// one per surface (shell/BlurBacking); a bar's pills cast their shadow
// from black ones (BarContainer).
AttachedSurface {
  id: root

  required property AttachedSurface source

  mirror: true
  width: root.source.width
  height: root.source.height
  edge: root.source.edge
  active: root.source.active
  animationDuration: root.source.animationDuration
  boxWidth: root.source.boxWidth
  boxHeight: root.source.boxHeight
  boxStart: root.source.boxStart
  connectorGap: root.source.connectorGap
  joinStart: root.source.joinStart
  joinEnd: root.source.joinEnd
  flushStart: root.source.flushStart
  flushEnd: root.source.flushEnd
  flushStartThrough: root.source.flushStartThrough
  flushEndThrough: root.source.flushEndThrough
  detached: root.source.detached
  detachedOffset: root.source.detachedOffset
  backfill: root.source.backfill
  joinBackfill: root.source.joinBackfill
  straight: root.source.straight
  straightJoins: root.source.straightJoins
  startCornerRadius: root.source.startCornerRadius
  endCornerRadius: root.source.endCornerRadius
  startNearRadius: root.source.startNearRadius
  endNearRadius: root.source.endNearRadius
  fillColor: root.source.fillColor
}
