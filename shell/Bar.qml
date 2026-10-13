pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import qs.services
import qs.config
import qs.components.bar

// The bars: one BarPanel per BarManager.bars entry.
Scope {
  id: root

  Variants {
    // Keyed on the stable bar id so a config reload rebinds the existing
    // PanelWindow instead of rebuilding it, and on its layer namespace
    // (Bar.layerNamespace, after a "|"): its kind (solid, shaped,
    // transparent) and orientation pick it, and Hyprland reads its rule's
    // `order` only as a surface maps, so a bar changing either is remade to
    // be arranged in its place: a solid bar outside the border, any other
    // inside it, and a side bar after the top and bottom bars of its kind
    // (BarEnds). A remade bar lands correctly once the rules are in
    // (layerRulesReady).
    model: HyprlandManager.layerRulesReady && General.outputs.length > 0 ? BarManager.bars.map(b => b.id + "|" + Bar.layerNamespace(b)) : []
    delegate: BarPanel {
      required property string modelData
      readonly property string barId: modelData.replace(/\|[^|]*$/, "")
      barConfig: BarManager.bars.find(b => b.id === barId) ?? barConfig
    }
  }
}
