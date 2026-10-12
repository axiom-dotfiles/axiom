pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

import qs.config
import qs.services

// A stretch of an edge's stroke a surface covers (`span`: { edge, start,
// end }, screen px along that edge, as ShellManager.setBorderOpening takes
// it, or null) left open on a solid bar there that draws its own inner
// stroke (border off, `innerStroke`): opaque or not, as the bar and the
// surface are separate windows whose stacking isn't the bar's to choose,
// the bar's fill showing there as the surface's (BarContainer.openings,
// as BarPopouts does for its box). With `fillet`, the radius its joined
// end curves into that stroke with (AttachedSurface.joinFillet), from the
// surface's own edge (`edge`), which that bar's shadow follows round.
PillStretch {
  id: root

  required property ShellScreen screen
  property var span: null
  property string edge: "top"
  property real fillet: -1

  readonly property var _panel: root.span ? ShellManager.barOn(root.screen?.name ?? "", Bar.locationOf(root.span.edge)) : null

  container: root._panel?.visible && (root._panel.barConfig?.innerStroke ?? false) ? root._panel.container : null
  // Whole pixels, the stroke kept on any part one (BarContainer.solidJoinOpening)
  opening: {
    const origin = root.container?.blurOrigin ?? null;
    if (!origin)
      return null;
    const at = root.span.edge === "left" || root.span.edge === "right" ? origin.y : origin.x;
    const start = Math.ceil(root.span.start - at);
    const end = Math.floor(root.span.end - at);
    if (end <= start)
      return null;
    return root.fillet < 0 ? {
      "start": start,
      "end": end
    } : {
      "start": start,
      "end": end,
      "fillet": Math.max(0, Math.min(root.fillet, end - start)),
      "filletAtEnd": root.edge !== "right" && root.edge !== "bottom"
    };
  }
}
