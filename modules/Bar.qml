pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import qs.services
import qs.config
import qs.components.widgets.bar as Components

Scope {
  id: root

  property int barHeight: Bar.height
  property int barWidth: Bar.vertical ? Bar.height : 0
  property color backgroundColor: Theme.background
  property color foregroundColor: Theme.foreground

  Variants {
    model: Quickshell.screens
    delegate: Component {
      Components.BarPanel {
        barHeight: root.barHeight
        barWidth: root.barWidth
      }
    }
  }
}
