pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import qs.services
import qs.config
import qs.components.bar

Scope {
  id: root

  Variants {
    // Keyed on the stable bar id so a config reload rebinds the existing
    // PanelWindow instead of rebuilding it, and on whether it sits inside
    // the border (`insideBorder`, keyed ":floating" after its layer): that
    // changes its layer namespace, whose rule's `order` Hyprland reads only
    // as a surface maps, so a bar switched to or from solid is
    // remade to land on the right side of the border. A remade bar lands
    // correctly: its rule has Hyprland arrange it first, or after the border
    // when inside it (HyprlandManager._addLayerRules), once the rules are in
    // (layerRulesReady).
    model: HyprlandManager.layerRulesReady && General.outputs.length > 0 ? BarManager.bars.map(b => b.id + (b.insideBorder ? ":floating" : "")) : []
    delegate: BarPanel {
      required property string modelData
      readonly property string barId: modelData.replace(/:floating$/, "")
      barConfig: BarManager.bars.find(b => b.id === barId) ?? barConfig
    }
  }
}
