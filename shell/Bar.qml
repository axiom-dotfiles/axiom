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
    // PanelWindow instead of rebuilding it. A remade bar still lands inside
    // the border's strip correctly: its layer rule's `order` has Hyprland
    // arrange it first (HyprlandManager._addLayerRules), once the rules are
    // in (layerRulesReady).
    model: HyprlandManager.layerRulesReady ? Bar.bars.map(b => b.id) : []
    delegate: BarPanel {
      required property string modelData
      barConfig: Bar.bars.find(b => b.id === modelData) ?? barConfig
    }
  }
}
