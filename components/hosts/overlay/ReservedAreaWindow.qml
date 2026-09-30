pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland

import qs.config
import qs.services

// A full-screen Overlay-layer window placed inside the border's and bars'
// reserved area (the overlay, the onboarder). Normal exclusion with no zone
// of its own puts it inside that area, wherever the bars are, so its content
// centers in the free space and the bars stay reachable; the -borderWidth
// margin lines it up with their inner stroke (as EdgePopout). A bare screen
// edge (no border, no bar) has no stroke to land on: it meets the edge. The
// window is transparent: a ScreenBackdrop dims the monitor under it.
PanelWindow {
  id: root

  anchors {
    left: true
    right: true
    top: true
    bottom: true
  }

  // A transparent bar reserves Hyprland's gaps_out less than its extent
  // (see BarPanel) and has no stroke to land on: sit at its invisible
  // inner edge instead, past the reserved space by that gap
  readonly property var _edges: Bar.edgesFor(root.screen)
  function _margin(side, location) {
    if (Bar.screenEdgeOpen(root.screen, location))
      return 0;
    if (root._edges[side]?.background === "transparent")
      return HyprlandManager.gapsOut[side] ?? 0;
    return -Appearance.borderWidth;
  }
  margins {
    left: root._margin("left", Bar.Left)
    right: root._margin("right", Bar.Right)
    top: root._margin("top", Bar.Top)
    bottom: root._margin("bottom", Bar.Bottom)
  }

  color: "transparent"
  focusable: true
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
  WlrLayershell.layer: WlrLayer.Overlay
  exclusionMode: ExclusionMode.Normal
  exclusiveZone: 0
}
