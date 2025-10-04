pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import qs.config
import qs.components.widgets.bar as Components

Scope {
  id: root

  property int barHeight: Bar.extent
  property int barWidth: Bar.vertical ? Bar.extent : 0
  property color backgroundColor: Theme.background
  property color foregroundColor: Theme.foreground

  Variants {
    model: Quickshell.screens
    delegate: Component {
      Components.BarPanel {
        barConfig: Display.primary === modelData.name ? Bar : Bar.nonPrimary
      }
    }
  }
}
