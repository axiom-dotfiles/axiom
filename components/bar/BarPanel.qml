// BarPanel.qml
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick

import qs.config
import qs.services
import qs.components.hosts.popout

PanelWindow {
  id: root

  required property var barConfig

  // An empty monitor means the first screen
  screen: Quickshell.screens.find(s => s.name === barConfig.monitor) ?? Quickshell.screens[0] ?? null
  // A solid bar sits at the screen edge, and the screen border's strip
  // (arranged after it) overlaps its inner part, drawing the bar's inner
  // stroke. A floating bar (transparent or pills, with the border on) sits
  // inside the border instead: on the Overlay layer, whose exclusive zones
  // are arranged after the border's, with its outer edge on the border's
  // stroke so pills can cover it. Overlay draws over fullscreen windows, so
  // it hides while its workspace has one.
  WlrLayershell.layer: barConfig.floating ? WlrLayer.Overlay : WlrLayer.Top
  WlrLayershell.exclusiveZone: root.reservedZone
  // On a transparent or pill bar, how far in from its outer edge it
  // reserves (floating edge menus place themselves against that)
  readonly property int reservedZone: {
    if (!barConfig.reserveSpace)
      return 0;
    // Transparent bars have no inner edge to see: windows start where it
    // would be, so the gap from the widgets to them (inset + Hyprland's own
    // gaps_out, taken off here) matches the gap to the screen edge
    const gap = barConfig.background === "transparent" ? (HyprlandManager.gapsOut[["top", "bottom", "left", "right"][barConfig.location]] ?? 0) : 0;
    // Hyprland counts the -borderWidth margin into the reserved space
    if (barConfig.floating)
      return Math.max(0, barConfig.extent - gap);
    return Math.max(0, (Appearance.screenBorder ? barConfig.extent - Appearance.screenMargin + Appearance.borderWidth : barConfig.extent) - gap);
  }
  WlrLayershell.namespace: "axiom-bar"
  // A popout with a text field up (e.g. a Wi-Fi password) takes the
  // keyboard through the bar, its parent surface
  WlrLayershell.keyboardFocus: popouts.wantsKeyboardFocus ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
  // The bar container paints the background (or not, when transparent)
  color: "transparent"

  anchors {
    top: (barConfig.top || barConfig.vertical)
    bottom: (barConfig.bottom || barConfig.vertical)
    left: (barConfig.left || !barConfig.vertical)
    right: (barConfig.right || !barConfig.vertical)
  }

  // A floating bar reaches onto the border's strokes: its own edge (so
  // pills cover it) and both ends (so a pill at an end can join the
  // perpendicular edge). Margins on the unanchored side are ignored.
  margins {
    top: root.barConfig.floating ? -Appearance.borderWidth : 0
    bottom: root.barConfig.floating ? -Appearance.borderWidth : 0
    left: root.barConfig.floating ? -Appearance.borderWidth : 0
    right: root.barConfig.floating ? -Appearance.borderWidth : 0
  }

  readonly property bool fullscreenBelow: HyprlandManager.hasFullscreen(root.screen?.name ?? "")

  visible: barConfig.enabled && !(barConfig.floating && fullscreenBelow)

  // With pills, room past the bar for the fillet where an end pill meets
  // the perpendicular edge; click-through (see mask), and not reserved
  readonly property int thickness: barConfig.extent + (barConfig.pills ? Appearance.borderRadius : 0)
  implicitHeight: barConfig.vertical ? 0 : thickness
  implicitWidth: barConfig.vertical ? thickness : 0

  mask: Region {
    item: bar
  }

  Component.onCompleted: {
    console.log("========== BAR PANEL ==========");
    console.log("  > Screen:", barConfig.monitor, "->", screen ? "Found" : "Not Found");
    console.log("  > Panel width:", width, "height:", height);
    console.log("  > Visible:", visible);
    console.log("  > implicitWidth:", implicitWidth, "implicitHeight:", implicitHeight);
    console.log("================================");
    ShellManager.registerGrabPartner(root, root.screen?.name);
    ShellManager.registerBar(root);
  }
  // The overlay's focus grab lets input through to the bar (see
  // ShellManager.grabPartners)
  onScreenChanged: ShellManager.registerGrabPartner(root, root.screen?.name)
  Component.onDestruction: {
    ShellManager.unregisterGrabPartner(root);
    ShellManager.unregisterBar(root);
  }

  // The widget area, where the pills are
  readonly property var container: bar.barContainer

  BarPopouts {
    id: popouts
    barConfig: root.barConfig
    panel: root
    screen: root.screen
    layoutSource: bar.barContainer
  }

  // The bar's own extent, at its outer edge. Placed by plain geometry, not
  // conditional anchors: when a bar changes orientation, a `width:
  // undefined` binding resets width to the implicit 300 after the anchors
  // have sized it, and the anchors don't reapply until the window resizes,
  // leaving a 300px bar that hides most of its widgets as overflow.
  StandaloneBar {
    id: bar
    x: root.barConfig.right ? parent.width - width : 0
    y: root.barConfig.bottom ? parent.height - height : 0
    width: root.barConfig.vertical ? root.barConfig.extent : parent.width
    height: root.barConfig.vertical ? parent.height : root.barConfig.extent
    barConfig: root.barConfig
    popouts: popouts
    panel: root
    screen: root.screen
  }
}
