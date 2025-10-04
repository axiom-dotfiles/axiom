pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import qs.config
import qs.components.widgets.bar

Scope {
  id: root

  property int barHeight: Bar.extent
  property int barWidth: Bar.vertical ? Bar.extent : 0
  property color backgroundColor: Theme.background
  property color foregroundColor: Theme.foreground

  Variants {
    model: Bar.bars
    delegate: BarPanel {
      required property var modelData
      barConfig: {
        console.log(`=== Initializing Bar on ${modelData.display}  ===`);
        console.log("Configuration:", JSON.stringify(modelData));
        return modelData
      }
    }
  }
}
