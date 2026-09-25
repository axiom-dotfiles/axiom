pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import qs.config
import qs.components.bar

Scope {
  id: root

  property int barHeight: Bar.extent
  property int barWidth: Bar.vertical ? Bar.extent : 0
  property color backgroundColor: Theme.background
  property color foregroundColor: Theme.foreground

  Variants {
    // Keyed on the stable bar id so a config reload rebinds the existing
    // PanelWindow instead of rebuilding it. A remade bar still lands inside
    // the border's strip correctly: its layer rule's `order` has Hyprland
    // arrange it first (HyprlandManager._addLayerRules).
    model: Bar.bars.map(b => b.id)
    delegate: BarPanel {
      required property string modelData
      barConfig: Bar.bars.find(b => b.id === modelData) ?? barConfig
    }
  }
}
