// BarPanel.qml
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick

import qs.config
import qs.components.widgets.bar.popouts
import qs.components.reusable

PanelWindow {
  id: root

  required property var barConfig

  screen: Quickshell.screens.find(s => s.name === barConfig.display) || null
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.exclusiveZone: barConfig.autoHide ? 0 : barConfig.extent - Appearance.screenMargin + Appearance.borderWidth
  WlrLayershell.namespace: "axiom-bar"

  anchors {
    top: (barConfig.top || barConfig.vertical)
    bottom: (barConfig.bottom || barConfig.vertical)
    left: (barConfig.left || !barConfig.vertical)
    right: (barConfig.right || !barConfig.vertical)
  }

  visible: barConfig.enabled

  implicitHeight: barConfig.vertical ? 0 : barConfig.extent
  implicitWidth: barConfig.vertical ? barConfig.extent : 0

  Component.onCompleted: {
    console.log("========== BAR PANEL ==========");
    console.log("  > Screen:", barConfig.display, "->", screen ? "Found" : "Not Found");
    console.log("  > Panel width:", width, "height:", height);
    console.log("  > Visible:", visible);
    console.log("  > implicitWidth:", implicitWidth, "implicitHeight:", implicitHeight);
    console.log("================================");
  }

  Popouts {
    id: popouts
    barConfig: root.barConfig
    panel: root
    screen: root.screen
  }

  // Use the standalone Bar component
  StandaloneBar {
    id: bar
    anchors.fill: parent
    barConfig: root.barConfig
    popouts: popouts
    panel: root
    screen: root.screen
  }
}
