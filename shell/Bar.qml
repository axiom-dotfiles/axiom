pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import qs.config
import qs.services
import qs.components.bar

Scope {
  id: root

  Variants {
    // Keyed on the stable bar id so a config reload rebinds the existing
    // PanelWindow instead of rebuilding it, and on whether it floats: that
    // changes its layer namespace, whose rule's `order` Hyprland reads only
    // as a surface maps, so a bar switched between solid and floating is
    // remade to land on the right side of the border. A remade bar lands
    // correctly: its rule has Hyprland arrange it first, or after the border
    // when floating (HyprlandManager._addLayerRules), once the rules are in
    // (layerRulesReady).
    model: HyprlandManager.layerRulesReady ? Bar.bars.map(b => b.id + (b.floating ? ":floating" : "")) : []
    delegate: BarPanel {
      required property string modelData
      readonly property string barId: modelData.replace(/:floating$/, "")
      barConfig: Bar.bars.find(b => b.id === barId) ?? barConfig
    }
  }
}
